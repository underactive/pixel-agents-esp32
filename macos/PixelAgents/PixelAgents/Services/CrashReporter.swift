import Foundation

/// Lightweight crash reporter that writes breadcrumbs to disk before the process dies.
/// On next launch, check `previousCrashInfo` for details about the last crash.
enum CrashReporter {

    /// Most recent breadcrumb — updated at key points so we know what the app was doing.
    nonisolated(unsafe) static var lastAction: String = "launch"

    static let logDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/PixelAgents")
    static let crashFile = logDir.appendingPathComponent("crash.log")

    // MARK: - Setup

    /// Install signal and exception handlers. Call once at launch.
    static func install() {
        try? FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true)

        // Clear any previous crash file — it's been consumed by `previousCrashInfo`.
        try? FileManager.default.removeItem(at: crashFile)

        // Cache the path as a C string for signal-safe file writing
        _crashPathC = strdup(crashFile.path)

        NSSetUncaughtExceptionHandler(crashExceptionHandler)

        for sig: Int32 in [SIGSEGV, SIGABRT, SIGBUS, SIGFPE, SIGILL, SIGTRAP] {
            signal(sig, crashSignalHandler)
        }
    }

    // MARK: - Previous Crash

    /// Returns info about the previous crash, or nil if the last run exited cleanly.
    static var previousCrashInfo: String? {
        guard FileManager.default.fileExists(atPath: crashFile.path) else { return nil }
        return try? String(contentsOf: crashFile, encoding: .utf8)
    }

    // MARK: - Internals

    /// C string path for signal-safe writing.
    nonisolated(unsafe) static var _crashPathC: UnsafeMutablePointer<CChar>?

    /// Write crash info using only signal-safe POSIX calls.
    static func writeCrashSignalSafe(_ reason: UnsafePointer<CChar>) {
        guard let path = _crashPathC else { return }
        let fd = open(path, O_WRONLY | O_CREAT | O_TRUNC, 0o644)
        guard fd >= 0 else { return }

        func writeStr(_ s: UnsafePointer<CChar>) {
            _ = Darwin.write(fd, s, strlen(s))
        }

        writeStr("reason: ")
        writeStr(reason)
        writeStr("\nlastAction: ")
        // lastAction is a Swift String — reading it in a signal handler is technically
        // unsafe, but it's our best-effort breadcrumb and only read once during crash.
        CrashReporter.lastAction.withCString { writeStr($0) }
        writeStr("\n")
        Darwin.close(fd)
    }
}

// MARK: - Top-level handlers (required for C function pointer compatibility)

private func crashExceptionHandler(_ exception: NSException) {
    let reason = "NSException: \(exception.name.rawValue) — \(exception.reason ?? "?")"
    reason.withCString { CrashReporter.writeCrashSignalSafe($0) }
}

private func crashSignalHandler(_ sig: Int32) {
    let name: String
    switch sig {
    case SIGSEGV: name = "SIGSEGV"
    case SIGABRT: name = "SIGABRT"
    case SIGBUS:  name = "SIGBUS"
    case SIGFPE:  name = "SIGFPE"
    case SIGILL:  name = "SIGILL"
    case SIGTRAP: name = "SIGTRAP"
    default:      name = "SIG\(sig)"
    }
    name.withCString { CrashReporter.writeCrashSignalSafe($0) }

    // Re-raise with default handler so the OS generates a crash report too
    signal(sig, SIG_DFL)
    raise(sig)
}
