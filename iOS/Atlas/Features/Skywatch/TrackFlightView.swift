import SwiftUI
import CoreLocation

/// Resolves a flight number / callsign to a live ADS-B aircraft and shows a
/// live-tracking screen: route progress + ETA-from-groundspeed, telemetry, and a
/// Follow button that reuses `FlightActivityController` and the shared
/// `skywatch_followed_hexes` set. If nothing matching is airborne, shows an
/// honest "not currently trackable" state.
struct TrackFlightView: View {
    let query: String

    @Environment(AuthManager.self) private var auth
    private let airports = AirportStore.shared

    @State private var aircraft: OverheadAircraft? = nil
    @State private var phase: Phase = .resolving
    @State private var followed: Set<String> = TrackFlightView.followedSet()
    @State private var pollTask: Task<Void, Never>? = nil

    private enum Phase { case resolving, tracking, notTrackable }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                switch phase {
                case .resolving:
                    loadingState
                case .notTrackable:
                    notTrackableState
                case .tracking:
                    if let ac = aircraft {
                        header(ac)
                        progressSection(ac)
                        telemetrySection(ac)
                        followButton(ac)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
        .background(Color.atlasBackground)
        .navigationTitle("Track \(query.uppercased())")
        .navigationBarTitleDisplayMode(.inline)
        .task { await resolveAndTrack() }
        .onDisappear { pollTask?.cancel() }
    }

    // MARK: - States

    private var loadingState: some View {
        VStack(spacing: 14) {
            ProgressView().tint(Color.atlasAccent)
            Text("Locating \(query.uppercased()) on ADS-B…")
                .font(AtlasFont.body(14)).foregroundStyle(Color.atlasInk2)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 60)
    }

    private var notTrackableState: some View {
        AtlasEmptyState(
            icon: "dot.radiowaves.left.and.right",
            title: "Not currently trackable",
            message: "“\(query.uppercased())” isn’t airborne or visible on ADS-B right now. Track works while the flight is in the air and within coverage."
        )
        .padding(.top, 40)
    }

    // MARK: - Header

    private func header(_ ac: OverheadAircraft) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(ac.tone.tint).frame(width: 52, height: 52)
                AircraftMarker(
                    category: AircraftCategory(typeCode: ac.type, isMilitary: ac.isMilitary),
                    heading: 0, color: ac.tone.color, baseSize: 28
                )
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(ac.displayName)
                    .font(AtlasFont.display(20, weight: .bold))
                    .foregroundStyle(Color.atlasText).lineLimit(1)
                HStack(spacing: 6) {
                    if let t = ac.type { TypePill(typeCode: t) }
                    if let reg = ac.registration {
                        Text(reg).font(AtlasFont.mono(12)).foregroundStyle(Color.atlasInkFaint)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16).atlasCard(radius: 18)
    }

    // MARK: - Route progress + ETA

    @ViewBuilder private func progressSection(_ ac: OverheadAircraft) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            AtlasSectionHeader(title: "Route")
            VStack(spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    endpointLabel(code: ac.originIata, name: ac.originName, align: .leading)
                    Spacer()
                    if let eta = etaMinutes(ac) {
                        VStack(spacing: 1) {
                            Text(etaString(eta)).font(AtlasFont.mono(15, weight: .semibold))
                                .foregroundStyle(Color.atlasAccent)
                            Text("ETA").font(.system(size: 9, weight: .bold, design: .monospaced))
                                .tracking(0.6).foregroundStyle(Color.atlasInkFaint)
                        }
                    } else {
                        Text("—").font(AtlasFont.mono(15)).foregroundStyle(Color.atlasInkFaint)
                    }
                    Spacer()
                    endpointLabel(code: ac.destIata, name: ac.destName, align: .trailing)
                }

                if let p = progress(ac) {
                    GeometryReader { geo in
                        let w = geo.size.width
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.atlasSurface2).frame(height: 6)
                            Capsule().fill(AtlasGradient.accent).frame(width: max(6, w * p), height: 6)
                            Image(systemName: "airplane")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Color.atlasAccent)
                                .offset(x: min(w - 8, max(0, w * p - 8)))
                        }
                    }
                    .frame(height: 16)
                } else {
                    Text("Route progress unavailable")
                        .font(AtlasFont.body(12)).foregroundStyle(Color.atlasInkFaint)
                }
            }
            .padding(16).atlasCard(radius: 16)
        }
    }

    private func endpointLabel(code: String?, name: String?, align: HorizontalAlignment) -> some View {
        VStack(alignment: align, spacing: 2) {
            Text(code ?? "???").font(AtlasFont.display(22, weight: .heavy))
                .foregroundStyle(Color.atlasText)
            if let name {
                Text(name).font(AtlasFont.body(11)).foregroundStyle(Color.atlasInk2)
                    .lineLimit(1)
            }
        }
    }

    // MARK: - Telemetry

    private func telemetrySection(_ ac: OverheadAircraft) -> some View {
        let items: [(String, String)] = [
            ("Altitude", ac.altitude.map { "\($0) ft" } ?? "—"),
            ("Ground speed", ac.groundSpeed.map { String(format: "%.0f kt", $0) } ?? "—"),
            ("Heading", ac.track.map { String(format: "%.0f°", $0) } ?? "—"),
            ("Squawk", ac.squawk ?? "—"),
        ]
        return VStack(alignment: .leading, spacing: 10) {
            AtlasSectionHeader(title: "Live telemetry")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(items, id: \.0) { label, value in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(label.uppercased())
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .tracking(0.6).foregroundStyle(Color.atlasInkFaint)
                        Text(value).font(AtlasFont.mono(16, weight: .semibold))
                            .foregroundStyle(Color.atlasText).lineLimit(1).minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12).atlasCard(radius: 12)
                }
            }
        }
    }

    // MARK: - Follow

    private func followButton(_ ac: OverheadAircraft) -> some View {
        let isFollowed = followed.contains(ac.hex)
        return Button { toggleFollow(ac) } label: {
            HStack(spacing: 8) {
                Image(systemName: isFollowed ? "bell.fill" : "bell")
                    .font(.system(size: 15, weight: .semibold))
                Text(isFollowed ? "Following" : "Follow")
                    .font(.system(size: 15, weight: .semibold))
            }
            .frame(maxWidth: .infinity).padding(.vertical, 14)
            .foregroundStyle(isFollowed ? Color.atlasBackground : Color.atlasText)
            .background(
                isFollowed ? AnyShapeStyle(AtlasGradient.accent) : AnyShapeStyle(Color.atlasSurface2),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
        }
        .buttonStyle(.plain)
    }

    private func toggleFollow(_ ac: OverheadAircraft) {
        var set = followed
        if set.contains(ac.hex) {
            set.remove(ac.hex)
            FlightActivityController.shared.stop(hex: ac.hex)
        } else {
            set.insert(ac.hex)
            FlightActivityController.shared.start(for: ac)
        }
        followed = set
        UserDefaults.standard.set(Array(set), forKey: "skywatch_followed_hexes")
    }

    private static func followedSet() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: "skywatch_followed_hexes") ?? [])
    }

    // MARK: - Resolve + poll

    private func resolveAndTrack() async {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard q.count >= 2 else { phase = .notTrackable; return }
        do {
            let results = try await auth.api.searchAircraft(query: q)
            guard let match = bestMatch(in: results, query: q) else {
                phase = .notTrackable
                return
            }
            aircraft = match
            phase = .tracking
            FlightActivityController.shared.update(with: match)
            startPolling(hex: match.hex)
        } catch {
            phase = .notTrackable
        }
    }

    private func bestMatch(in results: [OverheadAircraft], query: String) -> OverheadAircraft? {
        let q = query.uppercased().replacingOccurrences(of: " ", with: "")
        let exact = results.first {
            ($0.callsign?.uppercased().replacingOccurrences(of: " ", with: "") == q)
                || ($0.registration?.uppercased() == q)
                || ($0.hex.uppercased() == q)
        }
        return exact ?? results.first
    }

    private func startPolling(hex: String) {
        pollTask?.cancel()
        pollTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(8))
                if Task.isCancelled { break }
                let ref = aircraft?.coordinate
                do {
                    let updated = try await auth.api.fetchAircraftDetail(
                        hex: hex, lat: ref?.latitude ?? 0, lon: ref?.longitude ?? 0
                    )
                    aircraft = updated
                    if followed.contains(hex) {
                        FlightActivityController.shared.update(with: updated)
                    }
                } catch {
                    // Keep showing the last known position.
                }
            }
        }
    }

    // MARK: - Great-circle progress + ETA

    private func endpoints(_ ac: OverheadAircraft) -> (origin: CLLocationCoordinate2D, dest: CLLocationCoordinate2D)? {
        guard let o = ac.originIata.flatMap({ airports.airport(iata: $0) }),
              let d = ac.destIata.flatMap({ airports.airport(iata: $0) }) else { return nil }
        return (o.coordinate, d.coordinate)
    }

    private func progress(_ ac: OverheadAircraft) -> Double? {
        guard let ends = endpoints(ac), let pos = ac.coordinate else { return nil }
        let total = greatCircleKm(ends.origin, ends.dest)
        guard total > 1 else { return nil }
        let remaining = greatCircleKm(pos, ends.dest)
        return min(1, max(0, (total - remaining) / total))
    }

    private func etaMinutes(_ ac: OverheadAircraft) -> Double? {
        guard let ends = endpoints(ac), let pos = ac.coordinate,
              let speed = ac.groundSpeed, speed > 30 else { return nil }
        let remainingKm = greatCircleKm(pos, ends.dest)
        let kmh = speed * 1.852
        guard kmh > 0 else { return nil }
        return remainingKm / kmh * 60
    }

    private func etaString(_ minutes: Double) -> String {
        let m = Int(minutes.rounded())
        if m < 1 { return "Arriving" }
        if m < 60 { return "\(m)m" }
        return "\(m / 60)h \(m % 60)m"
    }

    private func greatCircleKm(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        let r = 6371.0
        let lat1 = a.latitude * .pi / 180, lat2 = b.latitude * .pi / 180
        let dLat = (b.latitude - a.latitude) * .pi / 180
        let dLon = (b.longitude - a.longitude) * .pi / 180
        let h = sin(dLat / 2) * sin(dLat / 2) + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * r * asin(min(1, sqrt(h)))
    }
}
