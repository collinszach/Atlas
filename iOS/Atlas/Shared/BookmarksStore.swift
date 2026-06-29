import Foundation

struct FavoriteAircraft: Codable, Identifiable, Hashable {
    let hex: String
    var label: String
    var type: String?
    var addedAt: Date
    var id: String { hex }
}

struct FavoriteAirport: Codable, Identifiable, Hashable {
    let icao: String
    var iata: String?
    var name: String
    var addedAt: Date
    var id: String { icao }
}

@MainActor
@Observable
final class BookmarksStore {
    static let shared = BookmarksStore()

    private(set) var aircraft: [FavoriteAircraft] = []
    private(set) var airports: [FavoriteAirport] = []

    private let aircraftKey = "atlas_bookmarked_aircraft"
    private let airportsKey = "atlas_bookmarked_airports"

    private init() { load() }

    // MARK: Aircraft

    func isAircraftBookmarked(_ hex: String) -> Bool {
        aircraft.contains { $0.hex == hex }
    }

    func toggleAircraft(_ ac: OverheadAircraft) {
        if let idx = aircraft.firstIndex(where: { $0.hex == ac.hex }) {
            aircraft.remove(at: idx)
        } else {
            aircraft.insert(
                FavoriteAircraft(hex: ac.hex, label: ac.displayName, type: ac.type, addedAt: Date()),
                at: 0
            )
        }
        persist()
    }

    func removeAircraft(_ hex: String) {
        aircraft.removeAll { $0.hex == hex }
        persist()
    }

    // MARK: Airports

    func isAirportBookmarked(_ icao: String) -> Bool {
        airports.contains { $0.icao == icao }
    }

    func toggleAirport(icao: String, iata: String?, name: String) {
        if let idx = airports.firstIndex(where: { $0.icao == icao }) {
            airports.remove(at: idx)
        } else {
            airports.insert(
                FavoriteAirport(icao: icao, iata: iata, name: name, addedAt: Date()),
                at: 0
            )
        }
        persist()
    }

    func removeAirport(_ icao: String) {
        airports.removeAll { $0.icao == icao }
        persist()
    }

    // MARK: Persistence

    private func load() {
        let decoder = JSONDecoder()
        if let data = UserDefaults.standard.data(forKey: aircraftKey),
           let decoded = try? decoder.decode([FavoriteAircraft].self, from: data) {
            aircraft = decoded
        }
        if let data = UserDefaults.standard.data(forKey: airportsKey),
           let decoded = try? decoder.decode([FavoriteAirport].self, from: data) {
            airports = decoded
        }
    }

    private func persist() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(aircraft) {
            UserDefaults.standard.set(data, forKey: aircraftKey)
        }
        if let data = try? encoder.encode(airports) {
            UserDefaults.standard.set(data, forKey: airportsKey)
        }
    }
}
