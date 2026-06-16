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

    /// Posted by `AppDelegate` when the user taps a Skywatch push notification.
    func selectSkyTab() {
        selectedTab = .sky
    }
}
