import Foundation

/// Watches ~/.claude/projects/ for active JSONL transcript files and reads new lines incrementally.
final class TranscriptWatcher {
    private let projectsDir: URL
    private var fileOffsets: [String: UInt64] = [:]
    private var fsEventStream: FSEventStreamRef?
    private var onFilesChanged: (() -> Void)?

    /// Time window: only transcripts modified within this many seconds are considered active.
    private let recencyWindow: TimeInterval = 300 // 5 minutes

    init() {
        self.projectsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects")
    }

    // MARK: - FSEvents monitoring

    /// Start FSEvents monitoring on the projects directory.
    func startMonitoring(onChanged: @escaping () -> Void) {
        self.onFilesChanged = onChanged
        guard FileManager.default.fileExists(atPath: projectsDir.path) else { return }

        var context = FSEventStreamContext()
        context.info = Unmanaged.passUnretained(self).toOpaque()

        let pathsToWatch = [projectsDir.path] as CFArray
        let flags: FSEventStreamCreateFlags =
            UInt32(kFSEventStreamCreateFlagUseCFTypes) |
            UInt32(kFSEventStreamCreateFlagFileEvents) |
            UInt32(kFSEventStreamCreateFlagNoDefer)

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
            0.25, // latency: match 4Hz cadence
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

    /// Find active JSONL transcript files (modified within the last 5 minutes).
    func findActiveTranscripts() -> [URL] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: projectsDir.path) else { return [] }

        var results: [URL] = []
        let cutoff = Date().addingTimeInterval(-recencyWindow)

        guard let subdirs = try? fm.contentsOfDirectory(
            at: projectsDir,
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
                results.append(file)
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

    /// Reset all file offsets (on reconnect or transport change).
    func resetOffsets() {
        fileOffsets.removeAll()
    }
}
