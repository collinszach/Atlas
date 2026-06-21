import Foundation

enum AppTab: Hashable {
    case map
    case trips
    case sky
    case plan
    case stats
}

/// Shared app-wide state for cross-feature coordination (e.g. push notification deep links).
@MainActor
@Observable
final class AppState {
    var selectedTab: AppTab = .map

    /// Set once `AuthManager` is available so `AppDelegate` can register the APNs token.
    var api: APIClient?

    /// Requests `SkyView` to present the alerts feed; reset by the view once handled.
    var showAlerts = false

    /// Aircraft a tapped push refers to. `AlertsView` consumes and clears these to
    /// auto-open the live detail sheet; nil when the push named no specific aircraft.
    var pendingAlertHex: String?
    var pendingAlertLat: Double?
    var pendingAlertLon: Double?

    /// Posted by `AppDelegate` when the user taps a Skywatch push notification —
    /// jumps to the Sky tab and opens the alerts feed the push refers to.
    func openAlerts() {
        selectedTab = .sky
        showAlerts = true
    }

    /// Push tap that named a specific aircraft — opens the feed and asks it to
    /// surface that aircraft's live detail.
    func openAlert(hex: String, lat: Double?, lon: Double?) {
        pendingAlertHex = hex
        pendingAlertLat = lat
        pendingAlertLon = lon
        openAlerts()
    }
}
