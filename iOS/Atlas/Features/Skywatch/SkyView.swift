import SwiftUI
import MapKit

struct SkyView: View {
    @Environment(AuthManager.self) private var auth
    @State private var vm = SkyViewModel()
    @State private var location = LocationProvider()
    @State private var position: MapCameraPosition = .automatic
    @State private var selectedAircraft: OverheadAircraft? = nil
    @State private var showPreferences = false
    @State private var refreshTask: Task<Void, Never>? = nil
    @State private var hasCenteredMap = false

    var body: some View {
        ZStack(alignment: .top) {
            mapLayer

            VStack(spacing: 0) {
                header

                if !vm.special.isEmpty {
                    specialStrip
                }

                Spacer()

                if let err = vm.error {
                    ErrorBanner(message: err) {
                        Task { await refresh() }
                    }
                    .padding(.bottom, 8)
                }

                if !vm.isLoading && location.coordinate != nil && vm.aircraft.isEmpty && vm.error == nil {
                    emptySkiesBanner
                }

                if let coordinate = location.coordinate {
                    aircraftListSheet(near: coordinate)
                }
            }
        }
        .sheet(item: $selectedAircraft) { ac in
            AircraftDetailSheet(aircraft: ac)
                .presentationDetents([.medium])
                .presentationBackground(Color.atlasSurface)
        }
        .sheet(isPresented: $showPreferences) {
            SkywatchPreferencesView()
                .presentationBackground(Color.atlasBackground)
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

    private var mapLayer: some View {
        Map(position: $position) {
            UserAnnotation()

            if let coordinate = location.coordinate {
                MapCircle(center: coordinate, radius: vm.radiusKm * 1000)
                    .stroke(Color.atlasAccentCool.opacity(0.5), lineWidth: 1.5)
                    .foregroundStyle(Color.atlasAccentCool.opacity(0.05))
            }

            ForEach(vm.aircraft) { ac in
                if let coordinate = ac.coordinate {
                    Annotation(ac.displayName, coordinate: coordinate) {
                        Button {
                            selectedAircraft = ac
                        } label: {
                            AircraftMarker(aircraft: ac)
                        }
                    }
                }
            }
        }
        .mapStyle(.imagery(elevation: .realistic))
        .mapControls {
            MapCompass()
            MapScaleView()
        }
        .ignoresSafeArea()
        .onChange(of: location.coordinate?.latitude) { _, _ in
            guard let newValue = location.coordinate, !hasCenteredMap else { return }
            hasCenteredMap = true
            position = .region(MKCoordinateRegion(center: newValue, latitudinalMeters: vm.radiusKm * 2200, longitudinalMeters: vm.radiusKm * 2200))
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Sky")
                    .font(AtlasFont.display(22))
                    .foregroundStyle(Color.atlasAccent)
                if !vm.isLoading {
                    Text("\(vm.aircraft.count) aircraft within \(Int(vm.radiusKm)) km")
                        .font(AtlasFont.mono(12))
                        .foregroundStyle(Color.atlasText.opacity(0.8))
                }
            }
            Spacer()
            if vm.isLoading {
                ProgressView().tint(.atlasAccent)
            }
            Button {
                showPreferences = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .foregroundStyle(Color.atlasAccent)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    private var specialStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(vm.special) { ac in
                    Button {
                        selectedAircraft = ac
                    } label: {
                        SpecialAircraftCard(aircraft: ac)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(.ultraThinMaterial)
    }

    private var emptySkiesBanner: some View {
        VStack(spacing: 6) {
            Image(systemName: "cloud")
                .font(.system(size: 28))
                .foregroundStyle(Color.atlasMuted)
            Text("Clear skies overhead")
                .font(AtlasFont.body(13, weight: .medium))
                .foregroundStyle(Color.atlasText)
            Text("No aircraft detected within \(Int(vm.radiusKm)) km")
                .font(AtlasFont.body(12))
                .foregroundStyle(Color.atlasMuted)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .padding(.bottom, 120)
    }

    private func aircraftListSheet(near coordinate: CLLocationCoordinate2D) -> some View {
        AircraftListStrip(aircraft: vm.aircraft, onSelect: { selectedAircraft = $0 })
            .refreshable {
                await vm.load(api: auth.api, coordinate: coordinate)
            }
    }

    // MARK: - Refresh

    private func refresh() async {
        guard let coordinate = location.coordinate else { return }
        await vm.load(api: auth.api, coordinate: coordinate)
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

// MARK: - Map marker

private struct AircraftMarker: View {
    let aircraft: OverheadAircraft

    private var tint: Color {
        if aircraft.isEmergency { return .red }
        if aircraft.isMilitary { return Color.atlasAccent }
        if !aircraft.matches.isEmpty { return Color.atlasAccentCool }
        return Color.atlasText
    }

    var body: some View {
        Image(systemName: "airplane")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(tint)
            .rotationEffect(.degrees((aircraft.track ?? 0) - 90))
            .padding(6)
            .background(Color.atlasSurface.opacity(0.85))
            .clipShape(Circle())
            .overlay(
                Circle().stroke(tint.opacity(0.6), lineWidth: 1)
            )
    }
}

// MARK: - Special strip card

private struct SpecialAircraftCard: View {
    let aircraft: OverheadAircraft

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: aircraft.isEmergency ? "exclamationmark.triangle.fill" : "sparkles")
                    .foregroundStyle(aircraft.isEmergency ? .red : Color.atlasAccent)
                Text(aircraft.displayName)
                    .font(AtlasFont.mono(13, weight: .semibold))
                    .foregroundStyle(Color.atlasText)
            }
            if let match = aircraft.matches.first {
                Text(match.message)
                    .font(AtlasFont.body(11))
                    .foregroundStyle(Color.atlasMuted)
                    .lineLimit(2)
                    .frame(maxWidth: 160, alignment: .leading)
            }
        }
        .padding(10)
        .atlasCard()
    }
}

// MARK: - Bottom aircraft list

private struct AircraftListStrip: View {
    let aircraft: [OverheadAircraft]
    let onSelect: (OverheadAircraft) -> Void

    var body: some View {
        if aircraft.isEmpty {
            EmptyView()
        } else {
            List {
                ForEach(aircraft) { ac in
                    Button {
                        onSelect(ac)
                    } label: {
                        AircraftRow(aircraft: ac)
                    }
                    .listRowBackground(Color.atlasSurface)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.atlasBackground.opacity(0.85))
            .frame(height: 220)
        }
    }
}

private struct AircraftRow: View {
    let aircraft: OverheadAircraft

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "airplane")
                .foregroundStyle(aircraft.isEmergency ? .red : (aircraft.isMilitary ? Color.atlasAccent : Color.atlasAccentCool))
                .rotationEffect(.degrees((aircraft.track ?? 0) - 90))

            VStack(alignment: .leading, spacing: 2) {
                Text(aircraft.displayName)
                    .font(AtlasFont.mono(14, weight: .medium))
                    .foregroundStyle(Color.atlasText)
                Text([aircraft.type, aircraft.registration].compactMap { $0 }.joined(separator: " · "))
                    .font(AtlasFont.body(11))
                    .foregroundStyle(Color.atlasMuted)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                if let alt = aircraft.altitude {
                    Text("\(alt) ft")
                        .font(AtlasFont.mono(12))
                        .foregroundStyle(Color.atlasText)
                }
                if let dist = aircraft.distanceKm {
                    Text(String(format: "%.1f km", dist))
                        .font(AtlasFont.mono(11))
                        .foregroundStyle(Color.atlasMuted)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Detail sheet

private struct AircraftDetailSheet: View {
    let aircraft: OverheadAircraft

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "airplane.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(aircraft.isEmergency ? .red : (aircraft.isMilitary ? Color.atlasAccent : Color.atlasAccentCool))
                VStack(alignment: .leading, spacing: 2) {
                    Text(aircraft.displayName)
                        .font(AtlasFont.display(20))
                        .foregroundStyle(Color.atlasText)
                    if let type = aircraft.type {
                        Text(type)
                            .font(AtlasFont.body(14))
                            .foregroundStyle(Color.atlasMuted)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                detailRow("Registration", aircraft.registration ?? "—")
                detailRow("Altitude", aircraft.altitude.map { "\($0) ft" } ?? "—")
                detailRow("Ground speed", aircraft.groundSpeed.map { String(format: "%.0f kt", $0) } ?? "—")
                detailRow("Track", aircraft.track.map { String(format: "%.0f°", $0) } ?? "—")
                detailRow("Distance", aircraft.distanceKm.map { String(format: "%.1f km", $0) } ?? "—")
                detailRow("Squawk", aircraft.squawk ?? "—")
                if aircraft.isMilitary {
                    detailRow("Operator", "Military / government")
                }
            }
            .padding(14)
            .atlasCard()

            if !aircraft.matches.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Why it's special")
                        .font(AtlasFont.body(13, weight: .semibold))
                        .foregroundStyle(Color.atlasAccent)
                    ForEach(aircraft.matches, id: \.message) { match in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "sparkles")
                                .foregroundStyle(Color.atlasAccent)
                                .font(.system(size: 12))
                            Text(match.message)
                                .font(AtlasFont.body(13))
                                .foregroundStyle(Color.atlasText)
                        }
                    }
                }
                .padding(14)
                .atlasCard()
            }

            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(AtlasFont.body(13))
                .foregroundStyle(Color.atlasMuted)
            Spacer()
            Text(value)
                .font(AtlasFont.mono(13))
                .foregroundStyle(Color.atlasText)
        }
    }
}
