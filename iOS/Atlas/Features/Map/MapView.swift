import SwiftUI
import MapKit

struct MapView: View {
    @Environment(AuthManager.self) private var auth
    @State private var vm = MapViewModel()
    @State private var position: MapCameraPosition = .userLocation(
        fallback: .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 40.0, longitude: -74.0),
            span: MKCoordinateSpan(latitudeDelta: 3, longitudeDelta: 3)
        ))
    )
    @State private var center = CLLocationCoordinate2D(latitude: 40.0, longitude: -74.0)
    @State private var spanKm: Double = 330
    @State private var selected: OverheadAircraft? = nil
    @State private var refreshTask: Task<Void, Never>? = nil
    @State private var filter = FlightFilter.default
    @State private var showFilter = false
    @State private var showSearch = false
    @State private var showEmergency = false

    private var visibleAircraft: [OverheadAircraft] {
        vm.liveAircraft.filter { filter.matches($0) }
    }

    var body: some View {
        ZStack(alignment: .top) {
            Map(position: $position, selection: .constant(nil)) {
                ForEach(visibleAircraft) { ac in
                    if let coord = ac.coordinate {
                        Annotation("", coordinate: coord) {
                            PlaneGlyph(aircraft: ac, isSelected: selected?.hex == ac.hex)
                                .onTapGesture { selected = ac }
                        }
                        .annotationTitles(.hidden)
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll, showsTraffic: false))
            .preferredColorScheme(.dark)
            .mapControls { MapCompass() }
            .ignoresSafeArea()
            .onMapCameraChange(frequency: .onEnd) { ctx in
                center = ctx.region.center
                spanKm = ctx.region.span.latitudeDelta * 111.0
                Task { await vm.loadLive(api: auth.api, center: center, spanKm: spanKm) }
            }

            header

            if vm.tooFarOut {
                Text("Zoom in for full coverage")
                    .font(AtlasFont.mono(11))
                    .foregroundStyle(Color.atlasInk2)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.top, 116)
            }
        }
        .sheet(item: $selected) { ac in
            AircraftDetailSheet(
                aircraft: ac,
                userCoordinate: center,
                isFollowed: followed.contains(ac.hex),
                onFollow: { toggleFollow(ac.hex) }
            )
            .presentationDetents([.large])
            .presentationBackground(Color.atlasBackground)
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showFilter) {
            FilterSheet(filter: $filter)
        }
        .sheet(isPresented: $showSearch) {
            SearchView(userCoordinate: center)
        }
        .sheet(isPresented: $showEmergency) {
            EmergencyView()
        }
        .task {
            await vm.loadLive(api: auth.api, center: center, spanKm: spanKm)
            startAutoRefresh()
        }
        .onDisappear { refreshTask?.cancel() }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "globe.americas.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AtlasGradient.accent)
            VStack(alignment: .leading, spacing: 1) {
                Text("Live map").font(AtlasFont.display(18, weight: .heavy)).foregroundStyle(Color.atlasText)
                Text("\(visibleAircraft.count) of \(vm.liveAircraft.count) aircraft")
                    .font(AtlasFont.mono(11)).foregroundStyle(Color.atlasInk2)
            }
            Spacer()
            Button { showEmergency = true } label: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.atlasDanger)
            }
            Button { showSearch = true } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.atlasInk2)
            }
            Button { showFilter = true } label: {
                Image(systemName: filter.isActive ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(filter.isActive ? Color.atlasAccent : Color.atlasInk2)
            }
            HStack(spacing: 5) {
                Circle().fill(Color.atlasCyan).frame(width: 6, height: 6)
                Text("LIVE").font(.system(size: 10, weight: .bold, design: .rounded))
            }
            .foregroundStyle(Color.atlasCyan)
            .padding(.horizontal, 9).padding(.vertical, 5)
            .background(Color.atlasCyan.opacity(0.14), in: Capsule())
        }
        .padding(.horizontal, 16).padding(.vertical, 11)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
        .padding(.horizontal, 14).padding(.top, 6)
    }

    private func startAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(12))
                if Task.isCancelled { break }
                await vm.loadLive(api: auth.api, center: center, spanKm: spanKm)
            }
        }
    }

    // Followed set shared with Sky via UserDefaults.
    private var followed: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: "skywatch_followed_hexes") ?? [])
    }
    private func toggleFollow(_ hex: String) {
        var s = followed
        if s.contains(hex) { s.remove(hex) } else { s.insert(hex) }
        UserDefaults.standard.set(Array(s), forKey: "skywatch_followed_hexes")
    }
}

// MARK: - Plane glyph

private struct PlaneGlyph: View {
    let aircraft: OverheadAircraft
    let isSelected: Bool

    var body: some View {
        AircraftMarker(
            category: AircraftCategory(typeCode: aircraft.type, isMilitary: aircraft.isMilitary),
            heading: aircraft.track,
            color: isSelected ? Color.atlasAccent : aircraft.tone.color,
            baseSize: 19,
            selected: isSelected
        )
        .padding(8)
        .contentShape(Circle())
    }
}
