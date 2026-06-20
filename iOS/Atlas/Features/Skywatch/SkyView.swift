import SwiftUI
import CoreLocation

// MARK: - SkyView

struct SkyView: View {
    @Environment(AuthManager.self) private var auth
    @State private var vm = SkyViewModel()
    @State private var location = LocationProvider()
    @State private var selectedAircraft: OverheadAircraft? = nil
    @State private var showPreferences = false
    @State private var showAR = false
    @State private var refreshTask: Task<Void, Never>? = nil
    @State private var showFollowToast = false
    @State private var followToastMessage = ""

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color.atlasBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        // Radar — full-width centered block
                        Group {
                            if let coord = location.coordinate {
                                RadarView(
                                    aircraft: vm.aircraft,
                                    userCoordinate: coord,
                                    radiusKm: vm.radiusKm,
                                    reduceMotion: reduceMotion,
                                    onTap: { selectedAircraft = $0 }
                                )
                            } else {
                                RadarPlaceholder()
                            }
                        }
                        .padding(.top, 8)

                        // "Special right now" horizontal strip
                        if !vm.special.isEmpty {
                            specialStrip
                        }

                        // Nearby list
                        if vm.isLoading && vm.aircraft.isEmpty {
                            skeletonBlock
                        } else if vm.aircraft.isEmpty && vm.error == nil && location.coordinate != nil {
                            AtlasEmptyState(
                                icon: "dot.radiowaves.up.forward",
                                title: "Clear skies overhead",
                                message: "No aircraft detected within \(Int(vm.radiusKm)) km."
                            )
                            .padding(.top, 24)
                        } else if !vm.aircraft.isEmpty {
                            nearbySection
                        }
                    }
                }
                .refreshable { await refresh() }

                // Error banner — floats at top
                if let err = vm.error {
                    VStack {
                        ErrorBanner(message: err) {
                            Task { await refresh() }
                        }
                        .padding(.top, 8)
                        Spacer()
                    }
                    .ignoresSafeArea(edges: .top)
                }

                // Follow toast
                if showFollowToast {
                    VStack {
                        Spacer()
                        Text(followToastMessage)
                            .font(AtlasFont.body(14, weight: .medium))
                            .foregroundStyle(Color.atlasText)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(.ultraThinMaterial, in: Capsule())
                            .padding(.bottom, 100)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
            .navigationTitle("Sky")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        if vm.isLoading {
                            ProgressView()
                                .tint(.atlasCyan)
                                .scaleEffect(0.8)
                        }
                        Button {
                            showAR = true
                        } label: {
                            Image(systemName: "camera.viewfinder")
                                .foregroundStyle(Color.atlasCyan)
                        }
                        Button {
                            showPreferences = true
                        } label: {
                            Image(systemName: "slider.horizontal.3")
                                .foregroundStyle(Color.atlasAccent)
                        }
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    if location.coordinate != nil && !vm.isLoading {
                        Text("\(vm.aircraft.count) in range")
                            .font(AtlasFont.mono(11))
                            .foregroundStyle(Color.atlasInkFaint)
                    }
                }
            }
        }
        .sheet(item: $selectedAircraft) { ac in
            AircraftDetailSheet(
                aircraft: ac,
                userCoordinate: location.coordinate,
                isFollowed: vm.isFollowed(ac.hex),
                onFollow: { handleFollow(ac) }
            )
            .presentationDetents([.large])
            .presentationBackground(Color.atlasBackground)
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showPreferences) {
            SkywatchPreferencesView()
                .presentationBackground(Color.atlasBackground)
        }
        .fullScreenCover(isPresented: $showAR) {
            ARSkyView(locationProvider: location)
                .environment(auth)
        }
        .task {
            location.api = auth.api
            location.start()
            location.startBackgroundMonitoring()
            await vm.loadPreferenceRadius(api: auth.api)
            await refresh()
            startAutoRefresh()
        }
        .onDisappear {
            refreshTask?.cancel()
            location.stop()
        }
    }

    // MARK: - Subviews

    private var specialStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            AtlasSectionHeader(title: "Special right now")
                .padding(.horizontal, 20)
                .padding(.top, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(vm.special) { ac in
                        Button { selectedAircraft = ac } label: {
                            SpecialCard(aircraft: ac)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 6)
            }
        }
    }

    private var nearbySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            AtlasSectionHeader(title: "Nearby")
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 10)

            VStack(spacing: 0) {
                ForEach(Array(vm.aircraft.enumerated()), id: \.element.id) { idx, ac in
                    Button {
                        selectedAircraft = ac
                    } label: {
                        FlightRow(
                            badge: ac.badgeCode,
                            tone: ac.tone,
                            title: ac.displayName,
                            subtitle: buildSubtitle(ac),
                            typeCode: ac.type,
                            trailing: ac.distanceKm.map { String(format: "%.0f km", $0) },
                            pill: pillForAircraft(ac),
                            chevron: true
                        )
                        .padding(.horizontal, 16)
                    }
                    .buttonStyle(.plain)

                    if idx < vm.aircraft.count - 1 {
                        Divider()
                            .background(Color.atlasBorder)
                            .padding(.horizontal, 16)
                    }
                }
            }
            .atlasCard(radius: 16)
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
    }

    private var skeletonBlock: some View {
        VStack(spacing: 0) {
            ForEach(0..<6, id: \.self) { idx in
                SkeletonRow()
                    .padding(.horizontal, 16)
                if idx < 5 {
                    Divider().background(Color.atlasBorder).padding(.horizontal, 16)
                }
            }
        }
        .atlasCard(radius: 16)
        .padding(.horizontal, 16)
        .padding(.top, 20)
    }

    // MARK: - Helpers

    private func buildSubtitle(_ ac: OverheadAircraft) -> String {
        var parts: [String] = []
        if let t = ac.type { parts.append(t) }
        if let fl = ac.flightLevelString { parts.append(fl) }
        if let spd = ac.groundSpeed, spd > 0 { parts.append(String(format: "%.0f kt", spd)) }
        if parts.isEmpty, let reg = ac.registration { parts.append(reg) }
        return parts.joined(separator: " · ")
    }

    private func pillForAircraft(_ ac: OverheadAircraft) -> (String, AtlasTone)? {
        if ac.isEmergency { return ("EMERGENCY", .emergency) }
        if ac.isMilitary  { return ("MILITARY", .military) }
        if let trigger = ac.matches.first?.trigger { return (trigger, .violet) }
        return nil
    }

    private func handleFollow(_ ac: OverheadAircraft) {
        vm.toggleFollow(ac.hex)
        let name = ac.displayName
        let msg = vm.isFollowed(ac.hex) ? "Following \(name)" : "Unfollowed \(name)"
        followToastMessage = msg
        withAnimation(.spring()) { showFollowToast = true }
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation { showFollowToast = false }
        }
    }

    private func refresh() async {
        guard let coord = location.coordinate else { return }
        await vm.load(api: auth.api, coordinate: coord)
    }

    private func startAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(15))
                guard !Task.isCancelled else { break }
                await refresh()
            }
        }
    }
}

// MARK: - RadarView

struct RadarView: View {
    let aircraft: [OverheadAircraft]
    let userCoordinate: CLLocationCoordinate2D
    let radiusKm: Double
    let reduceMotion: Bool
    let onTap: (OverheadAircraft) -> Void

    @State private var sweepAngle: Double = 0

    private let radarSize: CGFloat = 300

    var body: some View {
        ZStack {
            // Dark radar background
            Circle()
                .fill(Color(hex: "#04080F"))
                .frame(width: radarSize, height: radarSize)
                .overlay(
                    Circle()
                        .stroke(Color.atlasAccent.opacity(0.25), lineWidth: 1.5)
                )
                .shadow(color: Color.atlasCyan.opacity(0.06), radius: 40)

            // Range rings (3 inner + outer rim)
            ForEach([0.33, 0.67], id: \.self) { fraction in
                Circle()
                    .stroke(Color.atlasAccent.opacity(0.10), lineWidth: 0.5)
                    .frame(width: radarSize * fraction, height: radarSize * fraction)
            }

            // Crosshair lines
            Group {
                Rectangle()
                    .fill(Color.atlasAccent.opacity(0.08))
                    .frame(width: radarSize, height: 0.5)
                Rectangle()
                    .fill(Color.atlasAccent.opacity(0.08))
                    .frame(width: 0.5, height: radarSize)
            }

            // Sweep
            if !reduceMotion {
                SweepBeam()
                    .frame(width: radarSize, height: radarSize)
                    .clipShape(Circle())
                    .rotationEffect(.degrees(sweepAngle))
                    .onAppear {
                        withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                            sweepAngle = 360
                        }
                    }
            }

            // You-dot
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 18, height: 18)
                Circle()
                    .fill(Color.white)
                    .frame(width: 7, height: 7)
                    .shadow(color: Color.white.opacity(0.9), radius: 5)
                    .shadow(color: Color.atlasCyan.opacity(0.6), radius: 10)
            }

            // Aircraft blips
            ForEach(aircraft) { ac in
                if let pos = blipPosition(for: ac) {
                    BlipView(aircraft: ac, onTap: { onTap(ac) })
                        .position(pos)
                }
            }

            // Range label
            VStack {
                Spacer()
                Text("\(Int(radiusKm)) km")
                    .font(AtlasFont.mono(9))
                    .foregroundStyle(Color.atlasInkFaint)
                    .padding(.bottom, 8)
            }
            .frame(width: radarSize, height: radarSize)
        }
        .frame(width: radarSize, height: radarSize)
        .frame(maxWidth: .infinity)
    }

    private func blipPosition(for ac: OverheadAircraft) -> CGPoint? {
        guard let acLat = ac.lat, let acLon = ac.lon else { return nil }

        let dLat = acLat - userCoordinate.latitude
        let dLon = (acLon - userCoordinate.longitude) * cos(userCoordinate.latitude * .pi / 180)

        let radiusDeg = radiusKm / 111.0
        let distDeg = sqrt(dLat * dLat + dLon * dLon)
        let normalizedDist = min(distDeg / max(radiusDeg, 0.001), 1.0)

        // Bearing angle (from north, clockwise)
        let bearing = atan2(dLon, dLat)

        let half = radarSize / 2
        let maxR = half - 14.0

        let x = half + CGFloat(sin(bearing)) * CGFloat(normalizedDist) * maxR
        let y = half - CGFloat(cos(bearing)) * CGFloat(normalizedDist) * maxR

        return CGPoint(x: x, y: y)
    }
}

// MARK: - RadarPlaceholder

private struct RadarPlaceholder: View {
    private let size: CGFloat = 300
    var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: "#04080F"))
                .frame(width: size, height: size)
                .overlay(Circle().stroke(Color.atlasAccent.opacity(0.20), lineWidth: 1.5))

            VStack(spacing: 8) {
                ProgressView().tint(.atlasCyan)
                Text("Acquiring location…")
                    .font(AtlasFont.mono(12))
                    .foregroundStyle(Color.atlasInkFaint)
            }
        }
        .frame(width: size, height: size)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - SweepBeam

private struct SweepBeam: View {
    var body: some View {
        Canvas { ctx, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let r = size.width / 2

            var path = Path()
            path.move(to: center)
            path.addArc(
                center: center,
                radius: r,
                startAngle: .degrees(-90),
                endAngle: .degrees(-30),
                clockwise: false
            )
            path.closeSubpath()

            ctx.fill(
                path,
                with: .linearGradient(
                    Gradient(stops: [
                        .init(color: Color.atlasCyan.opacity(0.0), location: 0),
                        .init(color: Color.atlasCyan.opacity(0.20), location: 1)
                    ]),
                    startPoint: center,
                    endPoint: CGPoint(x: center.x, y: 0)
                )
            )

            // Leading edge line
            var line = Path()
            line.move(to: center)
            line.addLine(to: CGPoint(x: center.x, y: 0))
            ctx.stroke(line, with: .color(Color.atlasCyan.opacity(0.55)), lineWidth: 1.5)
        }
    }
}

// MARK: - BlipView

private struct BlipView: View {
    let aircraft: OverheadAircraft
    let onTap: () -> Void

    @State private var pulseScale: CGFloat = 1.0

    private var color: Color { aircraft.tone.color }
    private var isPulsing: Bool { aircraft.isEmergency || !aircraft.matches.isEmpty }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                if isPulsing {
                    Circle()
                        .fill(color.opacity(0.25))
                        .frame(width: 20, height: 20)
                        .scaleEffect(pulseScale)
                        .opacity(2.0 - pulseScale)
                }
                Circle()
                    .fill(color)
                    .frame(width: 9, height: 9)
                    .shadow(color: color.opacity(0.9), radius: 6)
            }
        }
        .buttonStyle(.plain)
        .onAppear {
            if isPulsing {
                withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) {
                    pulseScale = 2.2
                }
            }
        }
    }
}

// MARK: - SpecialCard

private struct SpecialCard: View {
    let aircraft: OverheadAircraft

    private var tone: AtlasTone { aircraft.tone }
    private var glowEnabled: Bool { aircraft.isEmergency }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Pill(text: pillLabel, tone: tone, dot: true)

            Text(aircraft.displayName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.atlasText)
                .lineLimit(1)

            HStack(spacing: 6) {
                if let typeStr = aircraft.type {
                    Text(typeStr)
                        .font(AtlasFont.mono(11))
                        .foregroundStyle(Color.atlasInk2)
                }
                if let dist = aircraft.distanceKm {
                    Text(String(format: "%.0f km", dist))
                        .font(AtlasFont.mono(11))
                        .foregroundStyle(tone.color)
                }
            }

            if let msg = aircraft.matches.first?.message {
                Text(msg)
                    .font(AtlasFont.body(11))
                    .foregroundStyle(Color.atlasInkFaint)
                    .lineLimit(2)
            }
        }
        .frame(width: 150, alignment: .leading)
        .padding(14)
        .atlasCard(radius: 16, glow: glowEnabled)
    }

    private var pillLabel: String {
        if aircraft.isEmergency {
            switch aircraft.squawk {
            case "7700": return "MAYDAY"
            case "7600": return "NORDO"
            case "7500": return "HIJACK"
            default:     return "EMERGENCY"
            }
        }
        if aircraft.isMilitary { return "MILITARY" }
        if let trigger = aircraft.matches.first?.trigger { return trigger }
        return "SPECIAL"
    }
}
