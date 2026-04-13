import Foundation

@MainActor
@Observable
final class TripDetailViewModel {
    var destinations: [Destination] = []
    var transport: [TransportLeg] = []
    var isLoading = false
    var error: String? = nil

    func load(tripId: String, api: APIClient) async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            async let d = api.destinations(tripId: tripId)
            async let t = api.transportLegs(tripId: tripId)
            (destinations, transport) = try await (d, t)
        } catch {
            self.error = error.localizedDescription
        }
    }
}
