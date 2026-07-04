import Foundation

/// A single aircraft the user has opened the detail sheet for — the plane-spotter's
/// "life list" entry. Dedup'd by hex; repeat sightings bump `spotCount` and `lastSpottedAt`
/// rather than creating duplicates.
struct SpottedAircraft: Codable, Identifiable, Hashable {
    let hex: String
    var label: String
    var type: String?
    var isMilitary: Bool
    var firstSpottedAt: Date
    var lastSpottedAt: Date
    var spotCount: Int
    var id: String { hex }
}

@MainActor
@Observable
final class SpottedStore {
    static let shared = SpottedStore()

    private(set) var entries: [SpottedAircraft] = []

    private let key = "atlas_spotted_aircraft"

    private init() { load() }

    var uniqueTypeCount: Int {
        Set(entries.compactMap(\.type)).count
    }

    var recent: [SpottedAircraft] {
        entries.sorted { $0.lastSpottedAt > $1.lastSpottedAt }
    }

    /// Records a sighting. Safe to call every time an aircraft's detail sheet is opened —
    /// a repeat sighting within the same session just bumps the existing entry.
    func record(_ ac: OverheadAircraft) {
        let now = Date()
        if let idx = entries.firstIndex(where: { $0.hex == ac.hex }) {
            entries[idx].lastSpottedAt = now
            entries[idx].spotCount += 1
            entries[idx].label = ac.displayName
            entries[idx].type = ac.type ?? entries[idx].type
        } else {
            entries.append(
                SpottedAircraft(
                    hex: ac.hex,
                    label: ac.displayName,
                    type: ac.type,
                    isMilitary: ac.isMilitary,
                    firstSpottedAt: now,
                    lastSpottedAt: now,
                    spotCount: 1
                )
            )
        }
        save()
    }

    func remove(_ hex: String) {
        entries.removeAll { $0.hex == hex }
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([SpottedAircraft].self, from: data)
        else { return }
        entries = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
