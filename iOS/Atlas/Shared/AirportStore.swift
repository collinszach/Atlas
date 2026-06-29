import Foundation
import CoreLocation

/// A major airport from the bundled static dataset.
/// Data source: OurAirports (public domain, https://ourairports.com/data/),
/// trimmed to the world's busiest fields and annotated with IANA time zones.
struct Airport: Codable, Identifiable, Hashable {
    let icao: String
    let iata: String?
    let name: String
    let city: String?
    let lat: Double
    let lon: Double
    let tz: String?

    var id: String { icao }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    var code: String { iata ?? icao }

    var timeZone: TimeZone? { tz.flatMap(TimeZone.init(identifier:)) }
}

@MainActor
@Observable
final class AirportStore {
    static let shared = AirportStore()

    private(set) var airports: [Airport] = []

    private init() { load() }

    private func load() {
        guard let url = Bundle.main.url(forResource: "airports", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([Airport].self, from: data) else {
            return
        }
        airports = decoded
    }

    func airport(iata: String) -> Airport? {
        let code = iata.uppercased()
        return airports.first { $0.iata?.uppercased() == code }
    }

    func airport(icao: String) -> Airport? {
        let code = icao.uppercased()
        return airports.first { $0.icao.uppercased() == code }
    }
}
