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

    /// Hexes the user has tapped "Watch" on — persisted in UserDefaults.
    var followedHexes: Set<String> = {
        let stored = UserDefaults.standard.stringArray(forKey: "skywatch_followed_hexes") ?? []
        return Set(stored)
    }()

    var special: [OverheadAircraft] {
        aircraft.filter { !$0.matches.isEmpty || $0.isEmergency }
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
            // Preferences are optional context; ignore failures.
        }
    }

    func toggleFollow(_ hex: String) {
        if followedHexes.contains(hex) {
            followedHexes.remove(hex)
        } else {
            followedHexes.insert(hex)
        }
        UserDefaults.standard.set(Array(followedHexes), forKey: "skywatch_followed_hexes")
    }

    func isFollowed(_ hex: String) -> Bool { followedHexes.contains(hex) }
}

// MARK: - OverheadAircraft computed helpers

extension OverheadAircraft {
    var coordinate: CLLocationCoordinate2D? {
        guard let lat, let lon else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    var displayName: String {
        let cs = callsign?.trimmingCharacters(in: .whitespaces).nilIfEmpty
        if let airline {
            let number = cs.map { String($0.drop(while: \.isLetter)) } ?? ""
            return number.isEmpty ? airline : "\(airline) \(number)"
        }
        return cs ?? registration?.nilIfEmpty ?? hex.uppercased()
    }

    var isEmergency: Bool {
        guard let squawk else { return false }
        return ["7500", "7600", "7700"].contains(squawk)
    }

    /// Short badge code: first 3 letters of airline, callsign prefix, or hex.
    var badgeCode: String {
        if let airline, airline.count >= 2 {
            return String(airline.prefix(3)).uppercased()
        }
        if let cs = callsign?.trimmingCharacters(in: .whitespaces), !cs.isEmpty {
            return String(cs.prefix(3)).uppercased()
        }
        return String(hex.prefix(3)).uppercased()
    }

    /// Semantic color tone for blips/badges.
    var tone: AtlasTone {
        if isEmergency { return .emergency }
        if isMilitary  { return .military }
        if !matches.isEmpty { return .violet }
        return .cyan
    }

    /// Altitude in flight level string, e.g. "FL350"
    var flightLevelString: String? {
        guard let alt = altitude, alt > 0 else { return nil }
        let fl = alt / 100
        return "FL\(fl)"
    }

    /// Route string if both endpoints are available.
    var routeLabel: String? {
        guard let o = originIata, let d = destIata else { return nil }
        return "\(o) → \(d)"
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
