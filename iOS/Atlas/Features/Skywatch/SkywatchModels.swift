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

// MARK: - Forecast

/// An aircraft projected to enter your radius, from `/skywatch/forecast`.
///
/// The backend deliberately reports no confidence value: the projection assumes
/// the aircraft holds its heading and speed, so `etaSeconds` and
/// `closestDistanceKm` are the honest outputs. Treat them as "pointed this way
/// now", not a promise — accuracy degrades once an aircraft is under vectors.
struct ForecastAircraft: Codable, Identifiable, Hashable {
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

    let etaSeconds: Int
    let closestDistanceKm: Double
    let closestLat: Double
    let closestLon: Double
    let matches: [SkywatchMatch]

    var id: String { hex }

    enum CodingKeys: String, CodingKey {
        case hex, lat, lon, type, squawk, matches, track, airline, registration
        case callsign = "flight"
        case altitude = "alt_baro"
        case groundSpeed = "ground_speed"
        case isMilitary = "is_military"
        case distanceKm = "distance_km"
        case etaSeconds = "eta_seconds"
        case closestDistanceKm = "closest_distance_km"
        case closestLat = "closest_lat"
        case closestLon = "closest_lon"
    }

    /// "in 4m" / "in 45s" — the lead time is the whole point of this feature.
    var etaLabel: String {
        if etaSeconds < 60 { return "in \(etaSeconds)s" }
        let minutes = etaSeconds / 60
        return "in \(minutes)m"
    }

    var closestLabel: String {
        String(format: "%.0f km", closestDistanceKm)
    }

    /// Lets a forecast row open the same detail sheet as a live contact.
    /// Enrichment fields are absent here; the sheet fetches them by hex.
    var asOverhead: OverheadAircraft {
        OverheadAircraft(
            hex: hex, callsign: callsign, registration: registration, type: type,
            airline: airline, lat: lat, lon: lon, altitude: altitude,
            groundSpeed: groundSpeed, track: track, squawk: squawk,
            isMilitary: isMilitary, distanceKm: distanceKm, matches: matches,
            originIata: nil, originName: nil, destIata: nil, destName: nil,
            photoUrl: nil, photoLink: nil, photoCredit: nil, trail: nil,
            manufacturer: nil, aircraftTypeLong: nil, owner: nil, ownerCountry: nil
        )
    }
}

struct ForecastResponse: Codable {
    let aircraft: [ForecastAircraft]
    let horizonMinutes: Int
    let radiusKm: Double
    let source: String

    enum CodingKeys: String, CodingKey {
        case aircraft, source
        case horizonMinutes = "horizon_minutes"
        case radiusKm = "radius_km"
    }
}

/// Display helpers delegate to the live-contact versions so an inbound row and
/// a nearby row can never disagree about how the same aircraft is labelled.
extension ForecastAircraft {
    var displayName: String { asOverhead.displayName }
    var badgeCode: String { asOverhead.badgeCode }
    var tone: AtlasTone { asOverhead.tone }
    var flightLevelString: String? { asOverhead.flightLevelString }
}
