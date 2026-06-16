import Foundation

struct LoggedFlight: Identifiable {
    let id: String
    let leg: TransportLeg
    let trip: Trip
}

@MainActor
@Observable
final class TripListViewModel {
    var flights: [LoggedFlight] = []
    var isLoading = false
    var error: String? = nil

    // Legacy stubs — kept so any surviving call-sites compile
    var trips: [Trip] = []
    var selectedStatus: TripStatus? = nil
    var searchText = ""
    var filtered: [Trip] { trips }

    func load(api: APIClient, reset: Bool = false) async {
        guard !isLoading else { return }
        if reset { flights = [] }
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            let pairs = try await api.allFlights()
            flights = pairs.map { LoggedFlight(id: $0.leg.id, leg: $0.leg, trip: $0.trip) }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func changeFilter(to status: TripStatus?, api: APIClient) async {
        selectedStatus = status
        await load(api: api, reset: true)
    }
}
