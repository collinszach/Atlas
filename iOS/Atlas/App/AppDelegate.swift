import UIKit
import UserNotifications

/// Handles APNs registration and Skywatch push notification deep-linking.
/// Owned via `@UIApplicationDelegateAdaptor` in `AtlasApp` — does not touch Clerk setup.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    /// A push tap that arrives before `appState` is wired (cold launch) is queued
    /// here and replayed once the SwiftUI layer sets `appState`.
    private enum PendingLaunch {
        case alert(hex: String, lat: Double?, lon: Double?)
        case feed
    }
    private var pendingLaunch: PendingLaunch?

    /// Shared so the rest of the app can route registration through the same API client used for auth.
    var appState: AppState? {
        didSet {
            guard appState != nil, let launch = pendingLaunch else { return }
            pendingLaunch = nil
            Task { @MainActor in apply(launch) }
        }
    }

    @MainActor
    private func apply(_ launch: PendingLaunch) {
        switch launch {
        case let .alert(hex, lat, lon):
            appState?.openAlert(hex: hex, lat: lat, lon: lon)
        case .feed:
            appState?.openAlerts()
        }
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            guard granted else {
                if let error {
                    print("Skywatch: notification authorization error: \(error.localizedDescription)")
                }
                return
            }
            DispatchQueue.main.async {
                application.registerForRemoteNotifications()
            }
        }
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        Task { @MainActor in
            do {
                try await appState?.api?.registerDevice(apnsToken: token)
            } catch {
                print("Skywatch: device registration failed: \(error.localizedDescription)")
            }
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("Skywatch: APNs registration failed: \(error.localizedDescription)")
    }

    /// Deep-links a tapped Skywatch alert to the Sky tab — to the specific aircraft
    /// when the push payload carries its hex, otherwise to the alerts feed.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let launch: PendingLaunch
        if let hex = userInfo["hex"] as? String, !hex.isEmpty {
            launch = .alert(
                hex: hex,
                lat: (userInfo["lat"] as? NSNumber)?.doubleValue,
                lon: (userInfo["lon"] as? NSNumber)?.doubleValue
            )
        } else {
            launch = .feed
        }
        Task { @MainActor in
            // On cold launch this can fire before SwiftUI wires `appState`; queue and replay then.
            if appState != nil { apply(launch) } else { pendingLaunch = launch }
            completionHandler()
        }
    }

    /// Shows alerts while the app is in the foreground.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }
}
