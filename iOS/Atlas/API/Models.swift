import Foundation

// MARK: - Map

struct MapArc: Codable, Identifiable {
    let id: String
    let flightNumber: String?
    let originCity: String?
    let destCity: String?
    let originIata: String?
    let destIata: String?
    let departureAt: String?
    let originLat: Double
    let originLng: Double
    let destLat: Double
    let destLng: Double

    enum CodingKeys: String, CodingKey {
        case id
        case flightNumber = "flight_number"
        case originCity = "origin_city"
        case destCity = "dest_city"
        case originIata = "origin_iata"
        case destIata = "dest_iata"
        case departureAt = "departure_at"
        case originLat = "origin_lat"
        case originLng = "origin_lng"
        case destLat = "dest_lat"
        case destLng = "dest_lng"
    }
}

// MARK: - Stats

struct StatsResponse: Codable {
    let flightsCount: Int
    let totalDistanceKm: Double
    let co2KgEstimate: Double
    let hoursInAir: Double?
    let topAirline: String?
    let mostFlownAirport: String?

    enum CodingKeys: String, CodingKey {
        case flightsCount = "flights_count"
        case totalDistanceKm = "total_distance_km"
        case co2KgEstimate = "co2_kg_estimate"
        case hoursInAir = "hours_in_air"
        case topAirline = "top_airline"
        case mostFlownAirport = "most_flown_airport"
    }
}

// MARK: - Transport write

struct FlightEnrichRequest: Encodable {
    let flightNumber: String
    let date: String

    enum CodingKeys: String, CodingKey {
        case flightNumber = "flight_number"
        case date
    }
}

struct FlightEnrichResponse: Decodable {
    let flightNumber: String?
    let airline: String?
    let originIata: String?
    let destIata: String?
    let originCity: String?
    let destCity: String?
    let durationMin: Int?
    let distanceKm: Double?

    enum CodingKeys: String, CodingKey {
        case airline
        case flightNumber = "flight_number"
        case originIata = "origin_iata"
        case destIata = "dest_iata"
        case originCity = "origin_city"
        case destCity = "dest_city"
        case durationMin = "duration_min"
        case distanceKm = "distance_km"
    }
}

struct TransportCreate: Encodable {
    var flightNumber: String?
    var airline: String?
    var originIata: String?
    var destIata: String?
    var originCity: String?
    var destCity: String?
    var departureAt: String?   // "yyyy-MM-dd" or "yyyy-MM-dd'T'HH:mm:ss"
    var arrivalAt: String?
    var durationMin: Int?
    var distanceKm: Double?
    var seatClass: String?
    var bookingRef: String?
    var cost: Double?
    var currency: String?
    var notes: String?

    enum CodingKeys: String, CodingKey {
        case airline, cost, currency, notes
        case flightNumber = "flight_number"
        case originIata = "origin_iata"
        case destIata = "dest_iata"
        case originCity = "origin_city"
        case destCity = "dest_city"
        case departureAt = "departure_at"
        case arrivalAt = "arrival_at"
        case durationMin = "duration_min"
        case distanceKm = "distance_km"
        case seatClass = "seat_class"
        case bookingRef = "booking_ref"
    }
}

// MARK: - Transport

/// A flight you've flown — the standalone logbook entry behind `/api/v1/flights`.
struct TransportLeg: Codable, Identifiable, Hashable {
    let id: String
    let userId: String
    let flightNumber: String?
    let airline: String?
    let originCity: String?
    let destCity: String?
    let originIata: String?
    let destIata: String?
    let departureAt: String?
    let arrivalAt: String?
    let durationMin: Int?
    let distanceKm: Double?
    let seatClass: String?
    let bookingRef: String?
    let cost: Double?
    let currency: String
    let notes: String?
    let originLat: Double?
    let originLng: Double?
    let destLat: Double?
    let destLng: Double?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, airline, cost, currency, notes
        case userId = "user_id"
        case flightNumber = "flight_number"
        case originCity = "origin_city"
        case destCity = "dest_city"
        case originIata = "origin_iata"
        case destIata = "dest_iata"
        case departureAt = "departure_at"
        case arrivalAt = "arrival_at"
        case durationMin = "duration_min"
        case distanceKm = "distance_km"
        case seatClass = "seat_class"
        case bookingRef = "booking_ref"
        case originLat = "origin_lat"
        case originLng = "origin_lng"
        case destLat = "dest_lat"
        case destLng = "dest_lng"
        case createdAt = "created_at"
    }
}

// MARK: - Photos

struct Photo: Codable, Identifiable {
    let id: String
    let transportLegId: String
    let originalFilename: String?
    let caption: String?
    let takenAt: String?
    let latitude: Double?
    let longitude: Double?
    let width: Int?
    let height: Int?
    let sizeBytes: Int?
    let isCover: Bool
    let orderIndex: Int?
    let url: String
    let thumbnailUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, caption, latitude, longitude, width, height, url
        case transportLegId = "transport_leg_id"
        case originalFilename = "original_filename"
        case takenAt = "taken_at"
        case sizeBytes = "size_bytes"
        case isCover = "is_cover"
        case orderIndex = "order_index"
        case thumbnailUrl = "thumbnail_url"
    }
}

struct PhotoListResponse: Codable {
    let items: [Photo]
    let total: Int
}
