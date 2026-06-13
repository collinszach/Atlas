import Foundation
import CoreLocation

@MainActor
@Observable
final class SkyViewModel {
    var aircraft: [OverheadAircraft] = []
    var isLoading = false
    var error: String? = nil
    var lastSource: String? = nil
    var radiusKm: Double = 30

    var special: [OverheadAircraft] {
        aircraft.filter { !$0.matches.isEmpty }
    }

    func load(api: APIClient, coordinate: CLLocationCoordinate2D) async {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            let result = try await api.fetchOverhead(lat: coordinate.latitude, lon: coordinate.longitude, radiusKm: radiusKm)
            aircraft = result.sorted { ($0.distanceKm ?? .greatestFiniteMagnitude) < ($1.distanceKm ?? .greatestFiniteMagnitude) }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func loadPreferenceRadius(api: APIClient) async {
        do {
            let prefs = try await api.getSkywatchPreferences()
            radiusKm = prefs.radiusKm
        } catch {
            // Preferences are optional context for the radar; ignore failures here.
        }
    }
}

extension OverheadAircraft {
    var coordinate: CLLocationCoordinate2D? {
        guard let lat, let lon else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    var displayName: String {
        callsign?.trimmingCharacters(in: .whitespaces).nilIfEmpty ?? registration?.nilIfEmpty ?? hex.uppercased()
    }

    var isEmergency: Bool {
        guard let squawk else { return false }
        return ["7500", "7600", "7700"].contains(squawk)
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
