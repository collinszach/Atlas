import SwiftUI
import MapKit
import CoreLocation

// MARK: - AircraftDetailSheet

struct AircraftDetailSheet: View {
    let aircraft: OverheadAircraft
    let userCoordinate: CLLocationCoordinate2D?
    let isFollowed: Bool
    let onFollow: () -> Void

    @Environment(AuthManager.self) private var auth
    @State private var enriched: OverheadAircraft? = nil
    @State private var isLoadingDetail = false
    @State private var liveTrail: [[Double]] = []

    private var display: OverheadAircraft { enriched ?? aircraft }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    // Header: airline + flight number + type
                    headerSection

                    // Aircraft photo (if available)
                    if let urlString = display.photoUrl, let url = URL(string: urlString) {
                        photoSection(url: url)
                    }

                    // Route
                    routeSection

                    // Telemetry grid
                    telemetrySection

                    // Why special
                    if !display.matches.isEmpty {
                        whySpecialSection
                    }

                    // Mini map
                    if let coord = display.coordinate {
                        miniMapSection(coordinate: coord)
                    }

                    // Actions
                    actionSection

                    Spacer(minLength: 32)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            .background(Color.atlasBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if isLoadingDetail {
                        ProgressView().tint(.atlasCyan).scaleEffect(0.8)
                    }
                }
            }
        }
        .task {
            guard let coord = userCoordinate else { return }
            // Seed with any backend trail + the current position.
            if let t = aircraft.trail, !t.isEmpty { liveTrail = t }
            appendPosition(aircraft)
            isLoadingDetail = true
            // Poll while the sheet is open, accumulating a live trail.
            while !Task.isCancelled {
                do {
                    let updated = try await auth.api.fetchAircraftDetail(
                        hex: aircraft.hex, lat: coord.latitude, lon: coord.longitude
                    )
                    enriched = updated
                    appendPosition(updated)
                } catch {
                    // keep showing what we have
                }
                isLoadingDetail = false
                try? await Task.sleep(for: .seconds(6))
            }
        }
    }

    /// Combined path: accumulated live positions take precedence over the backend trail.
    private var combinedTrail: [[Double]] {
        liveTrail.count >= 2 ? liveTrail : (display.trail ?? [])
    }

    private func appendPosition(_ ac: OverheadAircraft) {
        guard let lat = ac.lat, let lon = ac.lon else { return }
        if let last = liveTrail.last, abs(last[0] - lat) < 0.0002, abs(last[1] - lon) < 0.0002 {
            return  // unchanged
        }
        liveTrail.append([lat, lon])
        if liveTrail.count > 240 { liveTrail.removeFirst(liveTrail.count - 240) }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .top, spacing: 14) {
            // Tone icon
            ZStack {
                Circle()
                    .fill(display.tone.tint)
                    .frame(width: 48, height: 48)
                Image(systemName: iconName)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(display.tone.color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(display.displayName)
                    .font(AtlasFont.display(22, weight: .bold))
                    .foregroundStyle(Color.atlasText)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    if let type = display.type {
                        Text(type)
                            .font(AtlasFont.mono(13))
                            .foregroundStyle(Color.atlasInk2)
                    }
                    if let reg = display.registration {
                        Text(reg)
                            .font(AtlasFont.mono(13))
                            .foregroundStyle(Color.atlasInkFaint)
                    }
                }

                if display.isMilitary {
                    Pill(text: "MILITARY", tone: .military, dot: true)
                        .padding(.top, 2)
                } else if display.isEmergency {
                    Pill(text: emergencyLabel, tone: .emergency, dot: true)
                        .padding(.top, 2)
                }
            }

            Spacer()
        }
    }

    private var iconName: String {
        if display.isEmergency { return "exclamationmark.triangle.fill" }
        if display.isMilitary  { return "shield.fill" }
        return "airplane"
    }

    private var emergencyLabel: String {
        switch display.squawk {
        case "7700": return "MAYDAY 7700"
        case "7600": return "NORDO 7600"
        case "7500": return "HIJACK 7500"
        default:     return "EMERGENCY"
        }
    }

    // MARK: - Photo

    private func photoSection(url: URL) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.atlasSurface)
                            .frame(height: 180)
                        ProgressView().tint(.atlasCyan)
                    }
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity, maxHeight: 200)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                case .failure:
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.atlasSurface)
                            .frame(height: 120)
                        Image(systemName: "photo")
                            .font(.system(size: 28))
                            .foregroundStyle(Color.atlasInkFaint)
                    }
                @unknown default:
                    EmptyView()
                }
            }

            if let credit = display.photoCredit {
                HStack(spacing: 4) {
                    Image(systemName: "camera")
                        .font(.system(size: 10))
                    Text(credit)
                        .font(AtlasFont.body(11))
                }
                .foregroundStyle(Color.atlasInkFaint)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    // MARK: - Route

    private var routeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            AtlasSectionHeader(title: "Route")

            if display.originIata != nil || display.destIata != nil {
                HStack(spacing: 0) {
                    // Origin
                    VStack(alignment: .leading, spacing: 3) {
                        Text(display.originIata ?? "???")
                            .font(AtlasFont.display(26, weight: .heavy))
                            .foregroundStyle(Color.atlasText)
                        if let name = display.originName {
                            Text(name)
                                .font(AtlasFont.body(12))
                                .foregroundStyle(Color.atlasInk2)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    // Dashed connector
                    dashedConnector

                    Spacer()

                    // Destination
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(display.destIata ?? "???")
                            .font(AtlasFont.display(26, weight: .heavy))
                            .foregroundStyle(Color.atlasText)
                        if let name = display.destName {
                            Text(name)
                                .font(AtlasFont.body(12))
                                .foregroundStyle(Color.atlasInk2)
                                .lineLimit(1)
                        }
                    }
                }
                .padding(16)
                .atlasCard(radius: 14)
            } else {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.left.and.right.square")
                        .foregroundStyle(Color.atlasInkFaint)
                    Text("Route unavailable")
                        .font(AtlasFont.body(14))
                        .foregroundStyle(Color.atlasInkFaint)
                }
                .padding(16)
                .atlasCard(radius: 14)
            }
        }
    }

    private var dashedConnector: some View {
        HStack(spacing: 3) {
            Image(systemName: "airplane")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.atlasAccent)
                .rotationEffect(.degrees(0))

            ForEach(0..<6, id: \.self) { _ in
                Rectangle()
                    .fill(Color.atlasBorder)
                    .frame(width: 6, height: 1.5)
            }
        }
    }

    // MARK: - Telemetry grid

    private var telemetrySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            AtlasSectionHeader(title: "Telemetry")

            let items: [(String, String)] = [
                ("Altitude", display.altitude.map { "\($0) ft" } ?? "—"),
                ("Ground speed", display.groundSpeed.map { String(format: "%.0f kt", $0) } ?? "—"),
                ("Heading", display.track.map { String(format: "%.0f°", $0) } ?? "—"),
                ("Squawk", display.squawk ?? "—"),
                ("Distance", display.distanceKm.map { String(format: "%.1f km", $0) } ?? "—"),
                ("Hex", display.hex.uppercased()),
            ]

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(items, id: \.0) { label, value in
                    telemetryCell(label: label, value: value)
                }
            }
        }
    }

    private func telemetryCell(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(0.6)
                .foregroundStyle(Color.atlasInkFaint)
            Text(value)
                .font(AtlasFont.mono(16, weight: .semibold))
                .foregroundStyle(Color.atlasText)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .atlasCard(radius: 12)
    }

    // MARK: - Why special

    private var whySpecialSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            AtlasSectionHeader(title: "Why it's special")

            VStack(alignment: .leading, spacing: 8) {
                ForEach(display.matches, id: \.message) { match in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(Color.atlasViolet)
                            .frame(width: 6, height: 6)
                            .padding(.top, 5)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(match.trigger.uppercased())
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .tracking(0.4)
                                .foregroundStyle(Color.atlasViolet)
                            Text(match.message)
                                .font(AtlasFont.body(13))
                                .foregroundStyle(Color.atlasText)
                        }
                    }
                }
            }
            .padding(14)
            .atlasCard(radius: 14)
        }
    }

    // MARK: - Mini map

    private func miniMapSection(coordinate: CLLocationCoordinate2D) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            AtlasSectionHeader(title: "Position")

            MiniMapView(
                coordinate: enriched?.coordinate ?? coordinate,
                heading: display.track,
                trail: combinedTrail
            )
            .frame(height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.atlasBorder, lineWidth: 1)
            )
        }
    }

    // MARK: - Actions

    private var actionSection: some View {
        HStack(spacing: 12) {
            // Follow button
            Button(action: onFollow) {
                HStack(spacing: 8) {
                    Image(systemName: isFollowed ? "bell.fill" : "bell")
                        .font(.system(size: 15, weight: .semibold))
                    Text(isFollowed ? "Following" : "Follow")
                        .font(.system(size: 15, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(isFollowed ? Color.atlasBackground : Color.atlasText)
                .background(
                    isFollowed
                        ? AnyShapeStyle(AtlasGradient.accent)
                        : AnyShapeStyle(Color.atlasSurface2)
                    , in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
                .shadow(
                    color: isFollowed ? Color.atlasAccent.opacity(0.35) : .clear,
                    radius: 12, x: 0, y: 6
                )
            }
            .buttonStyle(.plain)

            // Share button
            ShareLink(
                item: shareText,
                subject: Text("Aircraft sighting"),
                message: Text(shareText)
            ) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Share")
                        .font(.system(size: 15, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(Color.atlasText)
                .background(Color.atlasSurface2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private var shareText: String {
        var parts: [String] = ["✈️ \(display.displayName)"]
        if let type = display.type { parts.append(type) }
        if let reg = display.registration { parts.append("Reg: \(reg)") }
        if let alt = display.altitude { parts.append("\(alt) ft") }
        if let spd = display.groundSpeed { parts.append(String(format: "%.0f kt", spd)) }
        if let route = display.routeLabel { parts.append(route) }
        parts.append("Spotted via Atlas")
        return parts.joined(separator: " · ")
    }
}

// MARK: - MiniMapView

private struct MiniMapView: View {
    let coordinate: CLLocationCoordinate2D
    let heading: Double?
    let trail: [[Double]]?

    @State private var position: MapCameraPosition

    init(coordinate: CLLocationCoordinate2D, heading: Double?, trail: [[Double]]?) {
        self.coordinate = coordinate
        self.heading = heading
        self.trail = trail
        _position = State(initialValue: .region(MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 40_000,
            longitudinalMeters: 40_000
        )))
    }

    var body: some View {
        Map(position: $position) {
            Annotation("", coordinate: coordinate) {
                Image(systemName: "airplane")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.atlasCyan)
                    .rotationEffect(.degrees((heading ?? 0) - 90))
                    .shadow(color: Color.atlasCyan.opacity(0.7), radius: 6)
            }

            if let trail {
                let coords = trail.compactMap { pair -> CLLocationCoordinate2D? in
                    guard pair.count >= 2 else { return nil }
                    return CLLocationCoordinate2D(latitude: pair[0], longitude: pair[1])
                }
                if coords.count > 1 {
                    MapPolyline(coordinates: coords)
                        .stroke(Color.atlasCyan.opacity(0.6), lineWidth: 2)
                }
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
        .mapControls { }
        .disabled(true)
    }
}
