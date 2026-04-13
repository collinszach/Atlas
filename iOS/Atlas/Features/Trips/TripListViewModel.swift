import Foundation

@MainActor
@Observable
final class TripListViewModel {
    var trips: [Trip] = []
    var isLoading = false
    var error: String? = nil
    var selectedStatus: TripStatus? = nil
    var searchText = ""
    private var hasMore = true
    private var currentPage = 1

    var filtered: [Trip] {
        guard !searchText.isEmpty else { return trips }
        let q = searchText.lowercased()
        return trips.filter { $0.title.lowercased().contains(q) }
    }

    func load(api: APIClient, reset: Bool = false) async {
        guard !isLoading else { return }
        if reset {
            trips = []
            currentPage = 1
            hasMore = true
        }
        guard hasMore else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            let response = try await api.trips(page: currentPage, status: selectedStatus)
            if reset { trips = response.items }
            else { trips.append(contentsOf: response.items) }
            hasMore = trips.count < response.total
            currentPage += 1
        } catch {
            self.error = error.localizedDescription
        }
    }

    func changeFilter(to status: TripStatus?, api: APIClient) async {
        selectedStatus = status
        await load(api: api, reset: true)
    }
}
