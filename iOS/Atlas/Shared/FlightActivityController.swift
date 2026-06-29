import Foundation
import ActivityKit

@MainActor
@Observable
final class FlightActivityController {
    static let shared = FlightActivityController()

    private var activities: [String: Activity<FlightActivityAttributes>] = [:]

    private init() {
        for activity in Activity<FlightActivityAttributes>.activities {
            activities[activity.attributes.hex] = activity
        }
    }

    var isAvailable: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    /// Starts a Live Activity for an airborne aircraft when the user taps Follow.
    func start(for ac: OverheadAircraft) {
        guard isAvailable else { return }
        guard isAirborne(ac) else { return }
        guard activities[ac.hex] == nil else {
            update(with: ac)
            return
        }

        let attributes = FlightActivityAttributes(
            hex: ac.hex,
            callsign: ac.displayName,
            type: ac.type,
            origin: ac.originIata,
            dest: ac.destIata,
            originName: ac.originName,
            destName: ac.destName
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: contentState(from: ac), staleDate: staleDate()),
                pushType: nil
            )
            activities[ac.hex] = activity
        } catch {
            // ActivityKit rejected the request (limit reached / disabled) — non-fatal.
        }
    }

    /// Ends the Live Activity for a hex (user untracked or aircraft landed).
    func stop(hex: String) {
        guard let activity = activities[hex] else { return }
        activities[hex] = nil
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
    }

    /// Pushes fresh telemetry to a running activity; ends it once the aircraft has landed.
    func update(with ac: OverheadAircraft) {
        guard let activity = activities[ac.hex] else { return }
        if !isAirborne(ac) {
            stop(hex: ac.hex)
            return
        }
        let state = contentState(from: ac)
        Task { await activity.update(.init(state: state, staleDate: staleDate())) }
    }

    /// Reconciles running activities against the latest poll: update live ones, end landed ones.
    /// Does not start new activities — that only happens on an explicit Follow tap.
    func sync(with aircraft: [OverheadAircraft]) {
        guard !activities.isEmpty else { return }
        let byHex = Dictionary(aircraft.map { ($0.hex, $0) }, uniquingKeysWith: { a, _ in a })
        // Snapshot keys: update(with:) may call stop(), which mutates `activities`.
        for hex in Array(activities.keys) {
            if let ac = byHex[hex] {
                update(with: ac)
            }
        }
    }

    private func contentState(from ac: OverheadAircraft) -> FlightActivityAttributes.ContentState {
        .init(
            latitude: ac.lat ?? 0,
            longitude: ac.lon ?? 0,
            altitude: ac.altitude,
            groundSpeed: ac.groundSpeed,
            heading: ac.track,
            progress: routeProgress(for: ac),
            etaMinutes: nil,
            statusLine: ac.routeLabel
        )
    }

    /// Best-effort progress. Route geometry (origin/dest coordinates) is not available from the
    /// overhead feed, so this stays at 0 until a richer route source lands. The bar renders an
    /// empty track in that case.
    private func routeProgress(for ac: OverheadAircraft) -> Double { 0 }

    private func isAirborne(_ ac: OverheadAircraft) -> Bool {
        guard let alt = ac.altitude else { return true }
        return alt > 0
    }

    private func staleDate() -> Date { Date().addingTimeInterval(120) }
}
