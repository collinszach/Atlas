import Foundation
import MapKit

@MainActor
@Observable
final class DestinationWriteViewModel {
    var searchResults: [MKMapItem] = []
    var isSearching = false
    var isSubmitting = false
    var error: String? = nil

    private var searchTask: Task<Void, Never>?

    func search(query: String) {
        searchTask?.cancel()
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchResults = []
            return
        }
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            await performSearch(query: query)
        }
    }

    private func performSearch(query: String) async {
        isSearching = true
        defer { isSearching = false }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = [.address, .pointOfInterest]
        do {
            let search = MKLocalSearch(request: request)
            let response = try await search.start()
            searchResults = response.mapItems
        } catch {
            searchResults = []
        }
    }

    func addDestination(
        tripId: String,
        place: MKMapItem,
        arrivalDate: Date?,
        departureDate: Date?,
        rating: Int?,
        orderIndex: Int,
        api: APIClient
    ) async throws -> Destination {
        isSubmitting = true
        error = nil
        defer { isSubmitting = false }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        let body = DestinationCreate(
            city: place.name ?? place.placemark.locality ?? "Unknown",
            countryCode: place.placemark.isoCountryCode ?? "",
            countryName: place.placemark.country ?? "",
            region: place.placemark.administrativeArea,
            latitude: place.placemark.coordinate.latitude,
            longitude: place.placemark.coordinate.longitude,
            arrivalDate: arrivalDate.map { f.string(from: $0) },
            departureDate: departureDate.map { f.string(from: $0) },
            rating: rating,
            notes: nil,
            orderIndex: orderIndex
        )
        return try await api.addDestination(tripId: tripId, body: body)
    }

    func deleteDestination(id: String, api: APIClient) async throws {
        try await api.deleteDestination(id: id)
    }
}

func flagEmoji(for isoCode: String) -> String {
    isoCode.uppercased().unicodeScalars
        .compactMap { UnicodeScalar(127397 + $0.value) }
        .map { String($0) }
        .joined()
}
