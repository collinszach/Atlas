import Foundation

// MARK: - Overhead aircraft

struct SkywatchMatch: Codable, Hashable {
    let trigger: String
    let score: Int
    let message: String
}

struct OverheadAircraft: Codable, Identifiable, Hashable {
    let hex: String
    let callsign: String?
    let registration: String?
    let type: String?
    let airline: String?
    let lat: Double?
    let lon: Double?
    let altitude: Int?
    let groundSpeed: Double?
    let track: Double?
    let squawk: String?
    let isMilitary: Bool
    let distanceKm: Double?
    let matches: [SkywatchMatch]

    // Backend enrichment fields — all optional, decode-safe (may be absent until backend lands)
    let originIata: String?
    let originName: String?
    let destIata: String?
    let destName: String?
    let photoUrl: String?
    let photoLink: String?
    let photoCredit: String?
    /// Trail breadcrumb: array of [lat, lon] pairs.
    let trail: [[Double]]?
    // Airframe database (adsbdb)
    let manufacturer: String?
    let aircraftTypeLong: String?
    let owner: String?
    let ownerCountry: String?

    var id: String { hex }

    enum CodingKeys: String, CodingKey {
        case hex, lat, lon, type, squawk, matches, track, airline
        case callsign = "flight"
        case registration
        case altitude = "alt_baro"
        case groundSpeed = "ground_speed"
        case isMilitary = "is_military"
        case distanceKm = "distance_km"
        case originIata = "origin_iata"
        case originName = "origin_name"
        case destIata = "dest_iata"
        case destName = "dest_name"
        case photoUrl = "photo_url"
        case photoLink = "photo_link"
        case photoCredit = "photo_credit"
        case trail
        case manufacturer
        case aircraftTypeLong = "aircraft_type_long"
        case owner
        case ownerCountry = "owner_country"
    }
}

struct OverheadResponse: Codable {
    let aircraft: [OverheadAircraft]
    let source: String
}

// MARK: - Alerts

/// A fired Skywatch alert — the persisted record behind each push notification.
/// Mirrors backend `AircraftAlertRead`.
struct AircraftAlert: Codable, Identifiable, Hashable {
    let id: String
    let hex: String
    let callsign: String?
    let type: String?
    let registration: String?
    let trigger: String
    let score: Int
    let message: String?
    let lat: Double?
    let lng: Double?
    let altBaro: Int?
    let distanceKm: Double?
    let sentAt: String

    enum CodingKeys: String, CodingKey {
        case id, hex, type, trigger, score, message, lat, lng
        case callsign
        case registration
        case altBaro = "alt_baro"
        case distanceKm = "distance_km"
        case sentAt = "sent_at"
    }
}

// MARK: - Devices

struct SkywatchDevice: Codable {
    let id: String
    let apnsToken: String?
    let platform: String

    enum CodingKeys: String, CodingKey {
        case id
        case apnsToken = "apns_token"
        case platform
    }
}

struct DeviceCreate: Codable {
    let apnsToken: String
    let platform: String

    enum CodingKeys: String, CodingKey {
        case apnsToken = "apns_token"
        case platform
    }
}

struct LocationUpdate: Codable {
    let lat: Double
    let lng: Double
    let deviceId: String?

    enum CodingKeys: String, CodingKey {
        case lat, lng
        case deviceId = "device_id"
    }
}

// MARK: - Preferences

struct SkywatchPreference: Codable {
    let id: String?
    let notableTypesEnabled: Bool
    let militaryEnabled: Bool
    let emergencyEnabled: Bool
    let watchlistEnabled: Bool
    let radiusKm: Double
    let altCeilingFt: Int?
    let cooldownMinutes: Int?
    let quietHours: [String: String]?
    let nlPrompt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case notableTypesEnabled = "notable_types_enabled"
        case militaryEnabled = "military_enabled"
        case emergencyEnabled = "emergency_enabled"
        case watchlistEnabled = "watchlist_enabled"
        case radiusKm = "radius_km"
        case altCeilingFt = "alt_ceiling_ft"
        case cooldownMinutes = "cooldown_minutes"
        case quietHours = "quiet_hours"
        case nlPrompt = "nl_prompt"
    }
}

/// Partial update payload for `PUT /skywatch/preferences`.
struct SkywatchPreferenceUpdate: Codable {
    var notableTypesEnabled: Bool?
    var militaryEnabled: Bool?
    var emergencyEnabled: Bool?
    var radiusKm: Double?
    var altCeilingFt: Int?
    var quietHours: [String: String]?
    var nlPrompt: String?

    enum CodingKeys: String, CodingKey {
        case notableTypesEnabled = "notable_types_enabled"
        case militaryEnabled = "military_enabled"
        case emergencyEnabled = "emergency_enabled"
        case radiusKm = "radius_km"
        case altCeilingFt = "alt_ceiling_ft"
        case quietHours = "quiet_hours"
        case nlPrompt = "nl_prompt"
    }
}

// MARK: - Airport schedule

/// A single scheduled flight from an airport departures/arrivals board.
/// Mirrors backend `ScheduledFlightRead`.
struct ScheduledFlight: Codable, Hashable, Identifiable {
    let flightNumber: String?
    let airline: String?
    let aircraftType: String?
    let scheduledTime: String?
    let estimatedTime: String?
    let actualTime: String?
    let status: String?
    let originIata: String?
    let originName: String?
    let destIata: String?
    let destName: String?
    let gate: String?
    let terminal: String?

    var id: String {
        (flightNumber ?? "") + (scheduledTime ?? UUID().uuidString)
    }

    /// Prefers actual (landed/departed) over estimated (delayed) over scheduled, formatted local time.
    var displayTime: String {
        let iso = actualTime ?? estimatedTime ?? scheduledTime
        guard let iso, let date = ScheduledFlight.isoFormatter.date(from: iso) else { return "—" }
        return ScheduledFlight.timeFormatter.string(from: date)
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    enum CodingKeys: String, CodingKey {
        case flightNumber = "flight_number"
        case airline
        case aircraftType = "aircraft_type"
        case scheduledTime = "scheduled_time"
        case estimatedTime = "estimated_time"
        case actualTime = "actual_time"
        case status
        case originIata = "origin_iata"
        case originName = "origin_name"
        case destIata = "dest_iata"
        case destName = "dest_name"
        case gate, terminal
    }
}

struct AirportSchedule: Codable {
    let flights: [ScheduledFlight]
    let configured: Bool
}
