import Foundation

@MainActor
@Observable
final class StatsViewModel {
    var stats: StatsResponse? = nil
    var isLoading = true
    var error: String? = nil

    func load(api: APIClient) async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            stats = try await api.stats()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
