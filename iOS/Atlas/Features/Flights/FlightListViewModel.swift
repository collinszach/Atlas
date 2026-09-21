import Foundation

@MainActor
@Observable
final class FlightListViewModel {
    var flights: [TransportLeg] = []
    var searchText = ""
    var isLoading = false
    var error: String? = nil

    var filtered: [TransportLeg] {
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return flights }
        return flights.filter { leg in
            [leg.flightNumber, leg.airline, leg.originIata, leg.destIata, leg.originCity, leg.destCity]
                .compactMap { $0?.lowercased() }
                .contains { $0.contains(q) }
        }
    }

    var totalDistanceKm: Double {
        flights.compactMap(\.distanceKm).reduce(0, +)
    }

    func load(api: APIClient) async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            flights = try await api.flights()
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Optimistic removal; reloads from the server if the delete fails.
    func delete(id: String, api: APIClient) async {
        let previous = flights
        flights.removeAll { $0.id == id }
        do {
            try await api.deleteFlight(id: id)
        } catch {
            flights = previous
            self.error = error.localizedDescription
        }
    }
}
