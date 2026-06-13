import Foundation
import CoreLocation

@MainActor
@Observable
final class LocationProvider: NSObject, CLLocationManagerDelegate {
    var coordinate: CLLocationCoordinate2D?
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var error: String? = nil

    /// Set so background significant-change updates can be posted to the backend.
    var api: APIClient?

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authorizationStatus = manager.authorizationStatus
    }

    func requestAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    /// Requests Always authorization so significant-location-change monitoring keeps working in the background.
    func requestAlwaysAuthorization() {
        manager.requestAlwaysAuthorization()
    }

    func start() {
        switch manager.authorizationStatus {
        case .notDetermined:
            requestAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        default:
            error = "Location access denied — enable it in Settings to see aircraft near you."
        }
    }

    func stop() {
        manager.stopUpdatingLocation()
    }

    /// Starts background significant-location-change monitoring for Skywatch.
    /// Requires Always authorization; posts each change to `/skywatch/location`.
    func startBackgroundMonitoring() {
        guard CLLocationManager.significantLocationChangeMonitoringAvailable() else { return }
        switch manager.authorizationStatus {
        case .authorizedAlways:
            manager.startMonitoringSignificantLocationChanges()
        case .notDetermined, .authorizedWhenInUse:
            requestAlwaysAuthorization()
        default:
            error = "Location access denied — enable Always access in Settings for background sky alerts."
        }
    }

    func stopBackgroundMonitoring() {
        manager.stopMonitoringSignificantLocationChanges()
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationStatus = status
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                self.error = nil
                manager.startUpdatingLocation()
                if status == .authorizedAlways, CLLocationManager.significantLocationChangeMonitoringAvailable() {
                    manager.startMonitoringSignificantLocationChanges()
                }
            case .denied, .restricted:
                self.error = "Location access denied — enable it in Settings to see aircraft near you."
            default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        let coord = loc.coordinate
        Task { @MainActor in
            self.coordinate = coord
            await self.postLocationUpdate(coord)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let message = error.localizedDescription
        Task { @MainActor in
            self.error = message
        }
    }

    private func postLocationUpdate(_ coordinate: CLLocationCoordinate2D) async {
        guard let api else { return }
        do {
            try await api.updateLocation(lat: coordinate.latitude, lng: coordinate.longitude)
        } catch {
            self.error = error.localizedDescription
        }
    }
}
