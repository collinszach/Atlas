import ActivityKit
import Foundation

struct FlightActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var latitude: Double
        var longitude: Double
        var altitude: Int?
        var groundSpeed: Double?
        var heading: Double?
        var progress: Double
        var etaMinutes: Int?
        var statusLine: String?

        var altitudeText: String {
            guard let altitude, altitude > 0 else { return "Ground" }
            return "\(altitude.formatted()) ft"
        }

        var speedText: String {
            guard let groundSpeed, groundSpeed > 0 else { return "—" }
            return "\(Int(groundSpeed)) kt"
        }

        var etaText: String {
            guard let etaMinutes, etaMinutes > 0 else { return "—" }
            if etaMinutes >= 60 {
                return "\(etaMinutes / 60)h \(etaMinutes % 60)m"
            }
            return "\(etaMinutes)m"
        }
    }

    var hex: String
    var callsign: String
    var type: String?
    var origin: String?
    var dest: String?
    var originName: String?
    var destName: String?

    var routeText: String {
        let o = origin ?? "???"
        let d = dest ?? "???"
        return "\(o) → \(d)"
    }
}
