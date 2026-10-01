import Foundation

/// Small persistent log so the user can show what happened during a background (Shortcuts) run.
enum DiagnosticsLog {
    private static let maxLines = 400
    private static let queue = DispatchQueue(label: "baoboiii.log")

    static var fileURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("nhat-ky.txt")
    }

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd/MM HH:mm:ss.SSS"
        return f
    }()

    static func log(_ message: String) {
        let line = "\(formatter.string(from: Date()))  \(message)\n"
        queue.async {
            let url = fileURL
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            var text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            text += line
            let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
            if lines.count > maxLines {
                text = lines.suffix(maxLines).joined(separator: "\n")
            }
            try? text.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    /// Waits for pending writes (call before the process may be suspended).
    static func flush() {
        queue.sync {}
    }

    static func read() -> String {
        flush()
        return (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
    }

    static func clear() {
        queue.sync { try? FileManager.default.removeItem(at: fileURL) }
    }
}

/// Measures elapsed time for log lines.
struct Stopwatch {
    private let start = Date()
    var ms: Int { Int(Date().timeIntervalSince(start) * 1000) }
}

/// Runs `operation`, throwing `BaoboiiiError.stepTimeout(step)` if it takes longer than `seconds`.
/// Returns immediately on timeout even if the operation ignores cancellation (e.g. synchronous Vision work).
func withTimeout<T>(_ seconds: Double, step: String, _ operation: @escaping () async throws -> T) async throws -> T {
    let gate = OnceGate()
    return try await withCheckedThrowingContinuation { continuation in
        let work = Task {
            do {
                let value = try await operation()
                if gate.claim() { continuation.resume(returning: value) }
            } catch {
                if gate.claim() { continuation.resume(throwing: error) }
            }
        }
        Task {
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            if gate.claim() {
                work.cancel()
                DiagnosticsLog.log("⏱ Hết giờ ở bước: \(step) (\(Int(seconds))s)")
                continuation.resume(throwing: BaoboiiiError.stepTimeout(step))
            }
        }
    }
}

private final class OnceGate: @unchecked Sendable {
    private let lock = NSLock()
    private var done = false

    func claim() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if done { return false }
        done = true
        return true
    }
}
