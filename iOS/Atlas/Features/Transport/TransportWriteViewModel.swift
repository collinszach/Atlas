import Foundation

@MainActor
@Observable
final class TransportWriteViewModel {
    var isSubmitting = false
    var error: String? = nil
    var isEnriching = false
    var enrichError: String? = nil

    /// Calls enrich-flight endpoint. Returns nil and sets enrichError on failure.
    func enrich(flightNumber: String, date: String, api: APIClient) async -> FlightEnrichResponse? {
        isEnriching = true
        enrichError = nil
        defer { isEnriching = false }
        do {
            return try await api.enrichFlight(flightNumber: flightNumber, date: date)
        } catch {
            enrichError = error.localizedDescription
            return nil
        }
    }

    func createTransportLeg(tripId: String, body: TransportCreate, api: APIClient) async throws -> TransportLeg {
        isSubmitting = true
        error = nil
        defer { isSubmitting = false }
        return try await api.createTransportLeg(tripId: tripId, body: body)
    }

    func deleteTransportLeg(id: String, api: APIClient) async throws {
        try await api.deleteTransportLeg(id: id)
    }
}
