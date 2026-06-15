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

    var id: String { hex }

    enum CodingKeys: String, CodingKey {
        case hex, lat, lon, type, squawk, matches, track, airline
        case callsign = "flight"
        case registration
        case altitude = "alt_baro"
        case groundSpeed = "ground_speed"
        case isMilitary = "is_military"
        case distanceKm = "distance_km"
    }
}

struct OverheadResponse: Codable {
    let aircraft: [OverheadAircraft]
    let source: String
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
