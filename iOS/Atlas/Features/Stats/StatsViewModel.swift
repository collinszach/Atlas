import Foundation

@MainActor
@Observable
final class StatsViewModel {
    var stats: StatsResponse? = nil
    var timeline: [TimelineTrip] = []
    var isLoading = true
    var error: String? = nil

    func load(api: APIClient) async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            async let s = api.stats()
            async let t = api.statsTimeline()
            (stats, timeline) = try await (s, t)
        } catch {
            self.error = error.localizedDescription
        }
    }
}
