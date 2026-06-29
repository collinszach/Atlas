import Foundation
import AVFoundation

/// A single LiveATC feed entry. `streamUrl` is a LiveATC `.pls` playlist URL
/// (e.g. https://www.liveatc.net/play/kjfk_twr.pls) which is resolved to the
/// underlying audio stream at play time.
/// Data source: LiveATC.net (https://www.liveatc.net/) — public ATC audio feeds.
struct ATCFeed: Codable, Hashable, Identifiable {
    let label: String
    let streamUrl: String

    var id: String { streamUrl }
}

@MainActor
@Observable
final class ATCFeedStore {
    static let shared = ATCFeedStore()

    private var byIcao: [String: [ATCFeed]] = [:]

    private init() { load() }

    private func load() {
        guard let url = Bundle.main.url(forResource: "atc_feeds", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: [ATCFeed]].self, from: data) else {
            return
        }
        byIcao = decoded
    }

    func feeds(forICAO icao: String) -> [ATCFeed] {
        byIcao[icao.uppercased()] ?? []
    }
}

enum ATCPlayerError: Error {
    case badPlaylist
    case timeout
}

/// LiveATC rejects requests without a browser-like User-Agent (HTTP 403), so both
/// the `.pls` fetch and the audio stream must send these headers.
private enum LiveATCHeaders {
    static let fields: [String: String] = [
        "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15",
        "Referer": "https://www.liveatc.net/"
    ]
}

/// Streams a LiveATC feed via `AVPlayer`. Configures the shared audio session
/// for `.playback` so audio continues when the app is backgrounded or locked
/// (requires the "audio" UIBackgroundMode). Stream failures surface as a
/// non-fatal `errorMessage` rather than crashing.
@MainActor
@Observable
final class ATCPlayer {
    static let shared = ATCPlayer()

    private(set) var currentFeedID: String?
    private(set) var currentTitle: String?
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private var player: AVPlayer?
    private var failObserver: NSObjectProtocol?
    private var loadTask: Task<Void, Never>?

    private init() {}

    var isPlaying: Bool { currentFeedID != nil }

    func isPlaying(feedID: String) -> Bool { currentFeedID == feedID }

    func toggle(_ feed: ATCFeed) {
        if isPlaying(feedID: feed.id) {
            stop()
        } else if let url = URL(string: feed.streamUrl) {
            play(url: url, title: feed.label)
        }
    }

    func play(url: URL, title: String) {
        stop()
        isLoading = true
        errorMessage = nil
        currentTitle = title
        currentFeedID = url.absoluteString

        loadTask = Task { [weak self] in
            guard let self else { return }
            do {
                try self.configureSession()
                let stream = try await self.resolveStreamURL(from: url)
                if Task.isCancelled { return }
                let asset = AVURLAsset(
                    url: stream,
                    options: ["AVURLAssetHTTPHeaderFieldsKey": LiveATCHeaders.fields]
                )
                let item = AVPlayerItem(asset: asset)
                let p = AVPlayer(playerItem: item)
                self.player = p
                self.observeFailure(item: item)
                p.play()
                try await self.waitUntilPlaying(player: p, timeout: 12)
                self.isLoading = false
            } catch is CancellationError {
                // Superseded by a newer request or an explicit stop — no-op.
            } catch {
                self.fail("Couldn’t connect to this feed. It may be offline.")
            }
        }
    }

    func stop() {
        loadTask?.cancel()
        loadTask = nil
        teardown()
        errorMessage = nil
    }

    private func fail(_ message: String) {
        teardown()
        errorMessage = message
    }

    private func teardown() {
        if let failObserver {
            NotificationCenter.default.removeObserver(failObserver)
        }
        failObserver = nil
        player?.pause()
        player = nil
        isLoading = false
        currentFeedID = nil
        currentTitle = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func configureSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default)
        try session.setActive(true)
    }

    /// Resolves a LiveATC `.pls` playlist to the underlying stream URL by parsing
    /// the first `FileN=` entry. Non-`.pls` URLs are returned unchanged.
    private func resolveStreamURL(from url: URL) async throws -> URL {
        guard url.pathExtension.lowercased() == "pls" else { return url }
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        for (k, v) in LiveATCHeaders.fields { request.setValue(v, forHTTPHeaderField: k) }
        let (data, _) = try await URLSession.shared.data(for: request)
        guard let text = String(data: data, encoding: .utf8) else {
            throw ATCPlayerError.badPlaylist
        }
        for rawLine in text.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard line.lowercased().hasPrefix("file"),
                  let eq = line.firstIndex(of: "=") else { continue }
            let value = line[line.index(after: eq)...].trimmingCharacters(in: .whitespaces)
            if let resolved = URL(string: value) { return resolved }
        }
        throw ATCPlayerError.badPlaylist
    }

    private func waitUntilPlaying(player: AVPlayer, timeout: TimeInterval) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if Task.isCancelled { throw CancellationError() }
            if let error = player.currentItem?.error { throw error }
            if player.timeControlStatus == .playing { return }
            try await Task.sleep(for: .milliseconds(300))
        }
        throw ATCPlayerError.timeout
    }

    private func observeFailure(item: AVPlayerItem) {
        failObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime, object: item, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.fail("This feed stopped unexpectedly.") }
        }
    }
}
