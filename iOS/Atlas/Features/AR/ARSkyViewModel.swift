import Foundation
import CoreLocation
@preconcurrency import CoreMotion
import Combine

// MARK: - Projected aircraft (what the AR view renders)

struct ARProjectedAircraft: Identifiable {
    let aircraft: OverheadAircraft
    /// Normalized screen position: (0,0) = top-left, (1,1) = bottom-right.
    let screenX: Double
    let screenY: Double
    /// True when within the camera FOV cone.
    let isVisible: Bool
    /// Horizontal angular offset from FOV center in degrees (negative = left).
    let azimuthDelta: Double
    /// Elevation above/below horizon in degrees.
    let elevationAngle: Double
    /// Ground distance to aircraft in km.
    let groundDistanceKm: Double

    var id: String { aircraft.id }
}

// MARK: - ARSkyViewModel

@MainActor
@Observable
final class ARSkyViewModel {

    // MARK: Aircraft data
    var aircraft: [OverheadAircraft] = []
    var isLoading = false
    var fetchError: String? = nil

    // MARK: Device attitude (degrees, magnetic north)
    /// Compass heading the phone points toward (yaw around vertical axis, 0 = north).
    var deviceHeading: Double = 0
    /// Pitch: 90 = phone face-up (pointing sky directly), 0 = phone vertical.
    var devicePitch: Double = 0

    // MARK: Projected results
    var projected: [ARProjectedAircraft] = []
    var nearestVisibleID: String? = nil

    // MARK: Camera / FOV (degrees)
    let hFOV: Double = 60.0
    let vFOV: Double = 46.0

    // MARK: Internals
    private let motionManager = CMMotionManager()
    private var refreshTask: Task<Void, Never>? = nil
    private var motionTimer: Timer? = nil
    private static let refreshInterval: TimeInterval = 6
    private static let radiusKm: Double = 50

    // MARK: - Lifecycle

    func startUpdates(api: APIClient, location: LocationProvider) {
        startMotion(location: location)
        startRefreshing(api: api, location: location)
    }

    func stopUpdates() {
        refreshTask?.cancel()
        refreshTask = nil
        motionTimer?.invalidate()
        motionTimer = nil
        if motionManager.isDeviceMotionAvailable {
            motionManager.stopDeviceMotionUpdates()
        }
    }

    // MARK: - Motion

    private func startMotion(location: LocationProvider) {
        guard motionManager.isDeviceMotionAvailable else {
            // Fallback: use CLLocationManager heading via LocationProvider.
            // We still get heading but no pitch; assume pitch ≈ 70° (phone tilted up).
            devicePitch = 70
            return
        }

        // Prefer magnetic-north reference; fall back to arbitrary+corrected.
        let reference: CMAttitudeReferenceFrame = CMMotionManager
            .availableAttitudeReferenceFrames()
            .contains(.xMagneticNorthZVertical)
            ? .xMagneticNorthZVertical
            : .xArbitraryCorrectedZVertical

        motionManager.deviceMotionUpdateInterval = 1.0 / 30.0
        motionManager.startDeviceMotionUpdates(using: reference)

        // Poll on main thread via a timer to avoid threading issues with @Observable.
        let mm = motionManager  // capture before closure to avoid main-actor isolation warning
        motionTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            guard let self, let motion = mm.deviceMotion else { return }
            Task { @MainActor in
                self.updateAttitude(motion: motion, reference: reference, location: location)
            }
        }
    }

    private func updateAttitude(motion: CMDeviceMotion, reference: CMAttitudeReferenceFrame, location: LocationProvider) {
        let attitude = motion.attitude

        if reference == .xMagneticNorthZVertical {
            // yaw = compass heading (radians, 0 = north, clockwise positive in CoreMotion).
            let yawDeg = attitude.yaw * 180.0 / .pi
            // CoreMotion yaw with magnetic-north ref: 0 = north, positive = clockwise.
            // Normalize to [0, 360).
            deviceHeading = (yawDeg + 360).truncatingRemainder(dividingBy: 360)
        } else {
            // Fallback: use CLLocationManager heading if available.
            // (LocationProvider doesn't expose heading directly; we'll skip correction.)
            let yawDeg = attitude.yaw * 180.0 / .pi
            deviceHeading = (yawDeg + 360).truncatingRemainder(dividingBy: 360)
        }

        // Pitch in CoreMotion: 0 = phone vertical (face toward user), π/2 = face up.
        // We want: 0 = vertical, 90 = face up (pointing at zenith).
        let pitchDeg = attitude.pitch * 180.0 / .pi
        // When phone is held portrait and tilted toward the sky, pitch increases.
        // Map CoreMotion pitch [-90, +90] → our elevation pitch.
        // CoreMotion pitch == 0 when device is vertical (normal use).
        // pitch == 90 when face up. pitch == -90 when face down.
        // We want elevation = pitch + 90 (so vertical = 90° → pointing horizon).
        // Actually: we treat devicePitch as the elevation above the horizon that the
        // *center of the screen* points toward. When phone vertical → center points
        // at the horizon (0°). When tilted back 45° → center at 45° elevation.
        // CoreMotion pitch when vertical is ~0; when tilted up it goes negative (portrait mode).
        // Portrait, face toward user: pitch = 0. Tilt top away (sky) → pitch goes negative.
        devicePitch = -pitchDeg  // so tilting up = positive elevation
    }

    // MARK: - Fetch

    private func startRefreshing(api: APIClient, location: LocationProvider) {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                if let coord = location.coordinate {
                    await self.fetchAircraft(api: api, coordinate: coord)
                }
                try? await Task.sleep(for: .seconds(ARSkyViewModel.refreshInterval))
            }
        }
    }

    private func fetchAircraft(api: APIClient, coordinate: CLLocationCoordinate2D) async {
        guard !isLoading else { return }
        isLoading = true
        fetchError = nil
        defer { isLoading = false }
        do {
            let result = try await api.fetchOverhead(
                lat: coordinate.latitude,
                lon: coordinate.longitude,
                radiusKm: ARSkyViewModel.radiusKm
            )
            aircraft = result
            projectAircraft(userCoordinate: coordinate)
        } catch {
            if !Task.isCancelled {
                fetchError = error.localizedDescription
            }
        }
    }

    // MARK: - Projection

    /// Call whenever attitude or aircraft list changes.
    func projectAircraft(userCoordinate: CLLocationCoordinate2D) {
        guard !aircraft.isEmpty else {
            projected = []
            nearestVisibleID = nil
            return
        }

        let userLat = userCoordinate.latitude
        let userLon = userCoordinate.longitude
        // Approximate observer altitude: 0m MSL (could refine with device barometer).
        let observerAlt: Double = 0

        var results: [ARProjectedAircraft] = []

        for ac in aircraft {
            guard let acLat = ac.lat, let acLon = ac.lon else { continue }

            // Ground distance (great-circle, km).
            let gDistKm = haversineKm(lat1: userLat, lon1: userLon, lat2: acLat, lon2: acLon)

            // Azimuth bearing (degrees, 0 = north, clockwise).
            let bearing = initialBearing(lat1: userLat, lon1: userLon, lat2: acLat, lon2: acLon)

            // Elevation angle above horizon.
            let altM = Double(ac.altitude ?? 0) * 0.3048  // feet → meters
            let elevDeg: Double
            if gDistKm > 0 {
                let gDistM = gDistKm * 1000.0
                let altDelta = altM - observerAlt
                elevDeg = atan2(altDelta, gDistM) * 180.0 / .pi
            } else {
                elevDeg = 90  // directly overhead
            }

            // Angular offsets from device center (degrees).
            var azDelta = bearing - deviceHeading
            // Normalize to [-180, 180].
            if azDelta > 180 { azDelta -= 360 }
            if azDelta < -180 { azDelta += 360 }

            let elevDelta = elevDeg - devicePitch  // positive = above screen center

            // Check FOV cone.
            let halfH = hFOV / 2.0
            let halfV = vFOV / 2.0
            let inFOV = abs(azDelta) <= halfH && abs(elevDelta) <= halfV

            // Map to normalized screen coords [0,1].
            // azDelta = -halfH → screenX=0; azDelta = +halfH → screenX=1.
            let screenX = (azDelta + halfH) / hFOV
            // elevDelta positive = above center → smaller Y (top of screen).
            let screenY = (-elevDelta + halfV) / vFOV

            results.append(ARProjectedAircraft(
                aircraft: ac,
                screenX: screenX,
                screenY: screenY,
                isVisible: inFOV,
                azimuthDelta: azDelta,
                elevationAngle: elevDeg,
                groundDistanceKm: gDistKm
            ))
        }

        projected = results

        // Nearest to screen center among visible labels.
        let visible = results.filter(\.isVisible)
        nearestVisibleID = visible.min(by: {
            hypot($0.screenX - 0.5, $0.screenY - 0.5) < hypot($1.screenX - 0.5, $1.screenY - 0.5)
        })?.id
    }

    // MARK: - Math helpers

    private func haversineKm(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let R = 6371.0
        let dLat = (lat2 - lat1) * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180
        let a = sin(dLat/2) * sin(dLat/2)
            + cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180)
            * sin(dLon/2) * sin(dLon/2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return R * c
    }

    private func initialBearing(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let φ1 = lat1 * .pi / 180
        let φ2 = lat2 * .pi / 180
        let Δλ = (lon2 - lon1) * .pi / 180
        let x = sin(Δλ) * cos(φ2)
        let y = cos(φ1) * sin(φ2) - sin(φ1) * cos(φ2) * cos(Δλ)
        let θ = atan2(x, y)
        return (θ * 180.0 / .pi + 360).truncatingRemainder(dividingBy: 360)
    }
}
