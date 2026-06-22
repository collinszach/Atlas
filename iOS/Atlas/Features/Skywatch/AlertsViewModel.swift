import Foundation

@MainActor
@Observable
final class AlertsViewModel {
    var alerts: [AircraftAlert] = []
    var isLoading = false
    var error: String? = nil

    func load(api: APIClient?) async {
        guard let api else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            alerts = try await api.listAlerts()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

extension AircraftAlert {
    /// Semantic color tone matching the live-aircraft palette.
    var tone: AtlasTone {
        switch trigger {
        case "emergency":    return .emergency
        case "military":     return .military
        case "notable_type": return .rare
        case "watchlist":    return .violet
        default:             return .accent
        }
    }

    var triggerLabel: String {
        switch trigger {
        case "emergency":    return "Emergency"
        case "military":     return "Military"
        case "notable_type": return "Rare"
        case "watchlist":    return "Watchlist"
        default:             return trigger.capitalized
        }
    }

    /// Short badge: callsign prefix, registration, or hex.
    var badgeCode: String {
        if let cs = callsign?.trimmingCharacters(in: .whitespaces), !cs.isEmpty {
            return String(cs.prefix(3)).uppercased()
        }
        if let reg = registration, !reg.isEmpty {
            return String(reg.prefix(3)).uppercased()
        }
        return String(hex.prefix(3)).uppercased()
    }

    var displayName: String {
        if let cs = callsign?.trimmingCharacters(in: .whitespaces), !cs.isEmpty { return cs }
        if let reg = registration, !reg.isEmpty { return reg }
        return hex.uppercased()
    }

    var distanceString: String? {
        guard let distanceKm else { return nil }
        return String(format: "%.0f km", distanceKm)
    }

    /// "5m ago", "2h ago", "3d ago" from the ISO-8601 `sent_at` timestamp.
    var relativeTime: String {
        guard let date = AircraftAlert.isoFormatter.date(from: sentAt)
            ?? AircraftAlert.isoFormatterNoFraction.date(from: sentAt) else {
            return ""
        }
        let seconds = max(0, -date.timeIntervalSinceNow)
        switch seconds {
        case ..<60:    return "just now"
        case ..<3600:  return "\(Int(seconds / 60))m ago"
        case ..<86400: return "\(Int(seconds / 3600))h ago"
        default:       return "\(Int(seconds / 86400))d ago"
        }
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let isoFormatterNoFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
}
