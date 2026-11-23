import Foundation

/// Append-only log in the app's Documents directory, so a build running on a real
/// device can be inspected after the fact by pulling the file off with
/// `devicectl device copy from`.
///
/// This exists because the live routes do not work here: `os_log` is not mirrored to
/// stderr under a `devicectl … --console` attach, and that attach ends as soon as the
/// app is suspended — which any test involving a ~60s token expiry requires. The
/// pattern follows `AuthManager.logDiagnostic`, which already wrote `auth_error.log`
/// for the same reason.
enum DiagnosticLog {
    /// Written next to `auth_error.log`; `filename` keeps concerns separable.
    static func append(_ line: String, to filename: String) {
        let stamped = "[\(ISO8601DateFormatter().string(from: Date()))] \(line)\n"
        guard
            let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
            let data = stamped.data(using: .utf8)
        else { return }
        let url = dir.appendingPathComponent(filename)
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            handle.seekToEndOfFile()
            handle.write(data)
        } else {
            try? data.write(to: url)
        }
    }
}
