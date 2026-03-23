import Foundation

/// Watches Claude Code, Codex CLI, Gemini CLI, and Cursor directories for active transcript files
/// and reads new lines/messages incrementally.
final class TranscriptWatcher {
    private let claudeProjectsDir: URL
    private let codexSessionsDir: URL
    private let geminiTmpDir: URL
    private let cursorProjectsDir: URL
    private var fileOffsets: [String: UInt64] = [:]
    /// Tracks last-seen message count per Gemini JSON session file (monolithic JSON, not JSONL).
    private var geminiMessageCounts: [String: Int] = [:]
    /// Tracks last-known file size per Gemini session to skip re-parsing unchanged files.
    private var geminiFileSizes: [String: UInt64] = [:]
    private var fsEventStream: FSEventStreamRef?
    private var onFilesChanged: (() -> Void)?

    /// Time window: only transcripts modified within this many seconds are considered active.
    private let recencyWindow: TimeInterval = 300 // 5 minutes

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        self.claudeProjectsDir = home.appendingPathComponent(".claude/projects")
        self.codexSessionsDir = home.appendingPathComponent(".codex/sessions")
        self.geminiTmpDir = home.appendingPathComponent(".gemini/tmp")
        self.cursorProjectsDir = home.appendingPathComponent(".cursor/projects")
    }

    deinit {
        stopMonitoring()
    }

    // MARK: - FSEvents monitoring

    /// Start FSEvents monitoring on both transcript directories.
    func startMonitoring(onChanged: @escaping () -> Void) {
        self.onFilesChanged = onChanged

        var paths: [String] = []
        if FileManager.default.fileExists(atPath: claudeProjectsDir.path) {
            paths.append(claudeProjectsDir.path)
        }
        if FileManager.default.fileExists(atPath: codexSessionsDir.path) {
            paths.append(codexSessionsDir.path)
        }
        if FileManager.default.fileExists(atPath: geminiTmpDir.path) {
            paths.append(geminiTmpDir.path)
        }
        if FileManager.default.fileExists(atPath: cursorProjectsDir.path) {
            paths.append(cursorProjectsDir.path)
        }
        guard !paths.isEmpty else { return }

        var context = FSEventStreamContext()
        context.info = Unmanaged.passUnretained(self).toOpaque()

        let pathsToWatch = paths as CFArray
        let flags: FSEventStreamCreateFlags =
            UInt32(kFSEventStreamCreateFlagUseCFTypes)

        guard let stream = FSEventStreamCreate(
            nil,
            { (_, info, _, _, _, _) in
                guard let info = info else { return }
                let watcher = Unmanaged<TranscriptWatcher>.fromOpaque(info).takeUnretainedValue()
                watcher.onFilesChanged?()
            },
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            1.0, // coalesce events over 1s — directory-level notifications
            flags
        ) else { return }

        FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
        FSEventStreamStart(stream)
        self.fsEventStream = stream
    }

    /// Stop FSEvents monitoring.
    func stopMonitoring() {
        if let stream = fsEventStream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            fsEventStream = nil
        }
    }

    // MARK: - Transcript discovery

    /// Find active transcript files from all sources (modified within the last 5 minutes).
    func findActiveTranscripts() -> [(URL, TranscriptSource)] {
        var results: [(URL, TranscriptSource)] = []
        results.append(contentsOf: findClaudeTranscripts())
        results.append(contentsOf: findCodexTranscripts())
        results.append(contentsOf: findGeminiTranscripts())
        results.append(contentsOf: findCursorTranscripts())

        // Prune fileOffsets and gemini tracking for files no longer active
        let activePaths = Set(results.map { $0.0.path })
        fileOffsets = fileOffsets.filter { activePaths.contains($0.key) }
        geminiMessageCounts = geminiMessageCounts.filter { activePaths.contains($0.key) }
        geminiFileSizes = geminiFileSizes.filter { activePaths.contains($0.key) }

        return results
    }

    /// Find active Claude Code transcripts in ~/.claude/projects/
    private func findClaudeTranscripts() -> [(URL, TranscriptSource)] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: claudeProjectsDir.path) else { return [] }

        var results: [(URL, TranscriptSource)] = []
        let cutoff = Date().addingTimeInterval(-recencyWindow)

        guard let subdirs = try? fm.contentsOfDirectory(
            at: claudeProjectsDir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return [] }

        for subdir in subdirs {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: subdir.path, isDirectory: &isDir), isDir.boolValue else { continue }

            guard let files = try? fm.contentsOfDirectory(
                at: subdir,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for file in files {
                guard file.pathExtension == "jsonl" else { continue }
                guard let attrs = try? file.resourceValues(forKeys: [.contentModificationDateKey]),
                      let modDate = attrs.contentModificationDate,
                      modDate > cutoff else { continue }
                results.append((file, .claude))
            }
        }

        return results
    }

    /// Find active Codex CLI rollout files in ~/.codex/sessions/YYYY/MM/DD/
    private func findCodexTranscripts() -> [(URL, TranscriptSource)] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: codexSessionsDir.path) else { return [] }

        var results: [(URL, TranscriptSource)] = []
        let cutoff = Date().addingTimeInterval(-recencyWindow)

        // Walk YYYY/MM/DD directory structure
        guard let yearDirs = try? fm.contentsOfDirectory(
            at: codexSessionsDir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return [] }

        for yearDir in yearDirs {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: yearDir.path, isDirectory: &isDir), isDir.boolValue else { continue }

            guard let monthDirs = try? fm.contentsOfDirectory(
                at: yearDir,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else { continue }

            for monthDir in monthDirs {
                guard fm.fileExists(atPath: monthDir.path, isDirectory: &isDir), isDir.boolValue else { continue }

                guard let dayDirs = try? fm.contentsOfDirectory(
                    at: monthDir,
                    includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles]
                ) else { continue }

                for dayDir in dayDirs {
                    guard fm.fileExists(atPath: dayDir.path, isDirectory: &isDir), isDir.boolValue else { continue }

                    guard let files = try? fm.contentsOfDirectory(
                        at: dayDir,
                        includingPropertiesForKeys: [.contentModificationDateKey],
                        options: [.skipsHiddenFiles]
                    ) else { continue }

                    for file in files {
                        guard file.pathExtension == "jsonl",
                              file.lastPathComponent.hasPrefix("rollout-") else { continue }
                        guard let attrs = try? file.resourceValues(forKeys: [.contentModificationDateKey]),
                              let modDate = attrs.contentModificationDate,
                              modDate > cutoff else { continue }
                        results.append((file, .codex))
                    }
                }
            }
        }

        return results
    }

    /// Find active Gemini CLI session files in ~/.gemini/tmp/*/chats/session-*.json
    private func findGeminiTranscripts() -> [(URL, TranscriptSource)] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: geminiTmpDir.path) else { return [] }

        var results: [(URL, TranscriptSource)] = []
        let cutoff = Date().addingTimeInterval(-recencyWindow)

        // Walk project slug dirs
        guard let projectDirs = try? fm.contentsOfDirectory(
            at: geminiTmpDir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return [] }

        for projectDir in projectDirs {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: projectDir.path, isDirectory: &isDir), isDir.boolValue else { continue }

            let chatsDir = projectDir.appendingPathComponent("chats")
            guard fm.fileExists(atPath: chatsDir.path, isDirectory: &isDir), isDir.boolValue else { continue }

            guard let files = try? fm.contentsOfDirectory(
                at: chatsDir,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for file in files {
                guard file.pathExtension == "json",
                      file.lastPathComponent.hasPrefix("session-") else { continue }
                guard let attrs = try? file.resourceValues(forKeys: [.contentModificationDateKey]),
                      let modDate = attrs.contentModificationDate,
                      modDate > cutoff else { continue }
                results.append((file, .gemini))
            }
        }

        return results
    }

    /// Find active Cursor agent transcripts in ~/.cursor/projects/*/agent-transcripts/*/
    private func findCursorTranscripts() -> [(URL, TranscriptSource)] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: cursorProjectsDir.path) else { return [] }

        var results: [(URL, TranscriptSource)] = []
        let cutoff = Date().addingTimeInterval(-recencyWindow)

        // Walk project dirs
        guard let projectDirs = try? fm.contentsOfDirectory(
            at: cursorProjectsDir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return [] }

        for projectDir in projectDirs {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: projectDir.path, isDirectory: &isDir), isDir.boolValue else { continue }

            let transcriptsDir = projectDir.appendingPathComponent("agent-transcripts")
            guard fm.fileExists(atPath: transcriptsDir.path, isDirectory: &isDir), isDir.boolValue else { continue }

            // Each session is a UUID-named directory containing a .jsonl file
            guard let sessionDirs = try? fm.contentsOfDirectory(
                at: transcriptsDir,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else { continue }

            for sessionDir in sessionDirs {
                guard fm.fileExists(atPath: sessionDir.path, isDirectory: &isDir), isDir.boolValue else { continue }

                guard let files = try? fm.contentsOfDirectory(
                    at: sessionDir,
                    includingPropertiesForKeys: [.contentModificationDateKey],
                    options: [.skipsHiddenFiles]
                ) else { continue }

                for file in files {
                    guard file.pathExtension == "jsonl" else { continue }
                    guard let attrs = try? file.resourceValues(forKeys: [.contentModificationDateKey]),
                          let modDate = attrs.contentModificationDate,
                          modDate > cutoff else { continue }
                    results.append((file, .cursor))
                }
            }
        }

        return results
    }

    // MARK: - Incremental reading

    /// Read new JSONL lines from a file since last read. Returns parsed JSON dicts.
    func readNewLines(from path: URL) -> [[String: Any]] {
        let key = path.path
        let fm = FileManager.default

        guard let attrs = try? fm.attributesOfItem(atPath: key),
              let fileSize = attrs[.size] as? UInt64 else { return [] }

        let currentOffset = fileOffsets[key] ?? 0
        guard fileSize > currentOffset else { return [] }

        guard let handle = FileHandle(forReadingAtPath: key) else { return [] }
        defer { handle.closeFile() }

        handle.seek(toFileOffset: currentOffset)
        let data = handle.readDataToEndOfFile()
        fileOffsets[key] = handle.offsetInFile

        guard let text = String(data: data, encoding: .utf8) else { return [] }

        var records: [[String: Any]] = []
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            guard let lineData = trimmed.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any]
            else { continue }
            records.append(json)
        }

        return records
    }

    /// Read new messages from a Gemini CLI session JSON file.
    ///
    /// Gemini sessions are monolithic JSON files (not JSONL) containing a `messages` array.
    /// We track the last-seen message count per file and only return messages past that index.
    /// File size is checked first to skip re-parsing unchanged files.
    func readNewGeminiMessages(from path: URL) -> [[String: Any]] {
        let key = path.path
        let fm = FileManager.default

        guard let attrs = try? fm.attributesOfItem(atPath: key),
              let fileSize = attrs[.size] as? UInt64 else { return [] }

        // Skip re-parsing if file hasn't changed
        if fileSize == geminiFileSizes[key] { return [] }
        geminiFileSizes[key] = fileSize

        guard let data = fm.contents(atPath: key),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let messages = json["messages"] as? [[String: Any]] else { return [] }

        let lastCount = geminiMessageCounts[key] ?? 0
        guard messages.count > lastCount else { return [] }

        geminiMessageCounts[key] = messages.count
        return Array(messages[lastCount...])
    }

    /// Reset all file offsets and Gemini tracking state (on reconnect or transport change).
    func resetOffsets() {
        fileOffsets.removeAll()
        geminiMessageCounts.removeAll()
        geminiFileSizes.removeAll()
    }
}
