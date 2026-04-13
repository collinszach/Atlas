import Foundation

// MARK: - Trips

struct Trip: Codable, Identifiable {
    let id: String
    let userId: String
    let title: String
    let description: String?
    let status: TripStatus
    let startDate: String?
    let endDate: String?
    let tags: [String]
    let visibility: String
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, title, description, status, tags, visibility
        case userId = "user_id"
        case startDate = "start_date"
        case endDate = "end_date"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

enum TripStatus: String, Codable, CaseIterable {
    case past, active, planned, dream
    var label: String { rawValue.capitalized }
    var systemImage: String {
        switch self {
        case .past:    return "checkmark.circle"
        case .active:  return "airplane"
        case .planned: return "calendar"
        case .dream:   return "sparkles"
        }
    }
}

struct TripListResponse: Codable {
    let items: [Trip]
    let total: Int
    let page: Int
    let limit: Int
}

// MARK: - Destinations

struct Destination: Codable, Identifiable {
    let id: String
    let tripId: String
    let city: String
    let countryCode: String
    let countryName: String
    let arrivalDate: String?
    let departureDate: String?
    let nights: Int?
    let rating: Int?
    let notes: String?
    let orderIndex: Int

    enum CodingKeys: String, CodingKey {
        case id, city, rating, notes
        case tripId = "trip_id"
        case countryCode = "country_code"
        case countryName = "country_name"
        case arrivalDate = "arrival_date"
        case departureDate = "departure_date"
        case nights
        case orderIndex = "order_index"
    }
}

// MARK: - Map

struct MapCountry: Codable, Identifiable {
    var id: String { countryCode }
    let countryCode: String
    let countryName: String
    let visitCount: Int
    let totalNights: Int
    let firstVisit: String?
    let lastVisit: String?

    enum CodingKeys: String, CodingKey {
        case countryCode = "country_code"
        case countryName = "country_name"
        case visitCount = "visit_count"
        case totalNights = "total_nights"
        case firstVisit = "first_visit"
        case lastVisit = "last_visit"
    }
}

struct MapCity: Codable, Identifiable {
    let id: String
    let city: String
    let countryCode: String
    let countryName: String
    let latitude: Double
    let longitude: Double
    let tripId: String

    enum CodingKeys: String, CodingKey {
        case id, city, latitude, longitude
        case countryCode = "country_code"
        case countryName = "country_name"
        case tripId = "trip_id"
    }
}

struct MapArc: Codable, Identifiable {
    let id: String
    let tripId: String
    let flightNumber: String?
    let originCity: String?
    let destCity: String?
    let originLat: Double
    let originLng: Double
    let destLat: Double
    let destLng: Double

    enum CodingKeys: String, CodingKey {
        case id
        case tripId = "trip_id"
        case flightNumber = "flight_number"
        case originCity = "origin_city"
        case destCity = "dest_city"
        case originLat = "origin_lat"
        case originLng = "origin_lng"
        case destLat = "dest_lat"
        case destLng = "dest_lng"
    }
}

// MARK: - Bucket list

struct BucketListItem: Codable, Identifiable {
    let id: String
    let countryCode: String?
    let countryName: String?
    let city: String?
    let priority: Int
    let reason: String?
    let idealSeason: String?
    let aiSummary: String?

    enum CodingKeys: String, CodingKey {
        case id, priority, reason
        case countryCode = "country_code"
        case countryName = "country_name"
        case city
        case idealSeason = "ideal_season"
        case aiSummary = "ai_summary"
    }
}

// MARK: - Stats

struct StatsResponse: Codable {
    let countriesVisited: Int
    let tripsCount: Int
    let nightsAway: Int
    let totalDistanceKm: Double
    let co2KgEstimate: Double
    let mostVisitedCountry: String?
    let mostVisitedCountryCode: String?
    let longestTripTitle: String?
    let longestTripDays: Int?

    enum CodingKeys: String, CodingKey {
        case countriesVisited = "countries_visited"
        case tripsCount = "trips_count"
        case nightsAway = "nights_away"
        case totalDistanceKm = "total_distance_km"
        case co2KgEstimate = "co2_kg_estimate"
        case mostVisitedCountry = "most_visited_country"
        case mostVisitedCountryCode = "most_visited_country_code"
        case longestTripTitle = "longest_trip_title"
        case longestTripDays = "longest_trip_days"
    }
}

struct TimelineTrip: Codable, Identifiable {
    let id: String
    let title: String
    let status: String
    let startDate: String?
    let endDate: String?
    let destinationCount: Int

    enum CodingKeys: String, CodingKey {
        case id, title, status
        case startDate = "start_date"
        case endDate = "end_date"
        case destinationCount = "destination_count"
    }
}

// MARK: - Transport

struct TransportLeg: Codable, Identifiable {
    let id: String
    let type: String
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

    enum CodingKeys: String, CodingKey {
        case id, type, airline
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
    }
}
