import Foundation

@MainActor
@Observable
final class TripWriteViewModel {
    var isLoading = false
    var error: String? = nil

    func createTrip(title: String, status: TripStatus, api: APIClient) async throws -> Trip {
        isLoading = true
        error = nil
        defer { isLoading = false }
        return try await api.createTrip(body: TripCreate(title: title, status: status))
    }

    func updateTrip(trip: Trip, title: String, status: TripStatus, startDate: String?, endDate: String?, description: String, tags: [String], api: APIClient) async throws -> Trip {
        isLoading = true
        error = nil
        defer { isLoading = false }
        let body = TripUpdate(
            title: title,
            status: status,
            startDate: startDate,
            endDate: endDate,
            description: description.isEmpty ? nil : description,
            tags: tags
        )
        return try await api.updateTrip(id: trip.id, body: body)
    }

    func deleteTrip(id: String, api: APIClient) async throws {
        isLoading = true
        error = nil
        defer { isLoading = false }
        try await api.deleteTrip(id: id)
    }
}
