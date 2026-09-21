import Foundation

extension TransportLeg {
    /// "JFK → LHR", falling back to city names, then to the flight number.
    var routeLabel: String {
        let from = originIata ?? originCity
        let to = destIata ?? destCity
        if let from, let to { return "\(from) → \(to)" }
        return from ?? to ?? flightNumber ?? "Flight"
    }

    var cityLabel: String? {
        guard let originCity, let destCity else { return originCity ?? destCity }
        return "\(originCity) → \(destCity)"
    }

    var departureDate: Date? { TransportLeg.parseDate(departureAt) }

    var year: String {
        guard let d = departureDate else { return "Undated" }
        return TransportLeg.yearFormatter.string(from: d)
    }

    var departureDisplay: String {
        guard let d = departureDate else { return "—" }
        return TransportLeg.mediumDate.string(from: d)
    }

    var durationDisplay: String? {
        guard let m = durationMin, m > 0 else { return nil }
        let h = m / 60
        let rem = m % 60
        return h > 0 ? "\(h)h \(rem)m" : "\(rem)m"
    }

    var distanceDisplay: String? {
        guard let km = distanceKm, km > 0 else { return nil }
        return String(format: "%.0f km", km)
    }

    /// Backend sends TIMESTAMPTZ; tolerate fractional seconds and bare dates.
    static func parseDate(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        if let d = isoFractional.date(from: raw) { return d }
        if let d = iso.date(from: raw) { return d }
        return plainDate.date(from: String(raw.prefix(10)))
    }

    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let plainDate: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let yearFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy"
        return f
    }()

    private static let mediumDate: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()
}
