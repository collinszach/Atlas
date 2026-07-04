import SwiftUI
import MapKit

struct MapView: View {
    @Environment(AuthManager.self) private var auth
    @State private var vm = MapViewModel()
    @State private var center = CLLocationCoordinate2D(latitude: 40.0, longitude: -74.0)
    @State private var spanKm: Double = 330
    @State private var selected: OverheadAircraft? = nil
    @State private var selectedAirport: Airport? = nil
    @State private var refreshTask: Task<Void, Never>? = nil
    private let airportStore = AirportStore.shared
    @State private var filter = FlightFilter.default
    @State private var layers = MapLayers()
    @State private var showFilter = false
    @State private var showSearch = false
    @State private var showEmergency = false
    @State private var showLayers = false

    private var visibleAircraft: [OverheadAircraft] {
        vm.liveAircraft.filter { filter.matches($0) }
    }

    var body: some View {
        ZStack(alignment: .top) {
            LiveMapView(
                aircraft: visibleAircraft,
                airports: airportStore.airports,
                layers: layers,
                selected: $selected,
                selectedAirport: $selectedAirport,
                initialCenter: center,
                initialSpanKm: spanKm,
                onRegionChange: { newCenter, newSpanKm in
                    center = newCenter
                    spanKm = newSpanKm
                    Task { await vm.loadLive(api: auth.api, center: center, spanKm: spanKm) }
                }
            )
            .ignoresSafeArea()

            header

            if vm.tooFarOut {
                Text("Zoom in for full coverage")
                    .font(AtlasFont.mono(11))
                    .foregroundStyle(Color.atlasInk2)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.top, 116)
            }

            if let err = vm.error, vm.liveAircraft.isEmpty {
                ErrorBanner(message: err) {
                    Task { await vm.loadLive(api: auth.api, center: center, spanKm: spanKm) }
                }
                .padding(.top, 116)
            }
        }
        .sheet(item: $selected) { ac in
            AircraftDetailSheet(
                aircraft: ac,
                userCoordinate: center,
                isFollowed: followed.contains(ac.hex),
                onFollow: { toggleFollow(ac) }
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
        .sheet(isPresented: $showLayers) {
            MapLayersSheet(layers: $layers)
        }
        .sheet(item: $selectedAirport) { airport in
            AirportPage(airport: airport)
                .presentationDetents([.large])
                .presentationBackground(Color.atlasBackground)
                .presentationDragIndicator(.visible)
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
            Button { showLayers = true } label: {
                Image(systemName: layers.isActive ? "square.3.layers.3d.top.filled" : "square.3.layers.3d")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(layers.isActive ? Color.atlasAccent : Color.atlasInk2)
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
                FlightActivityController.shared.sync(with: vm.liveAircraft)
            }
        }
    }

    // Followed set shared with Sky via UserDefaults.
    private var followed: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: "skywatch_followed_hexes") ?? [])
    }
    private func toggleFollow(_ ac: OverheadAircraft) {
        var s = followed
        if s.contains(ac.hex) {
            s.remove(ac.hex)
            FlightActivityController.shared.stop(hex: ac.hex)
        } else {
            s.insert(ac.hex)
            FlightActivityController.shared.start(for: ac)
        }
        UserDefaults.standard.set(Array(s), forKey: "skywatch_followed_hexes")
    }
}

// MARK: - Layers sheet

extension MapLayers {
    var isActive: Bool { self != MapLayers() }
}

struct MapLayersSheet: View {
    @Binding var layers: MapLayers
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    section("Base map") {
                        Picker("Style", selection: $layers.style) {
                            ForEach(MapLayers.Style.allCases) { style in
                                Text(style.label).tag(style)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(14)
                    }
                    section("Overlays") {
                        toggle("Weather radar", icon: "cloud.rain.fill", $layers.weatherRadar)
                        if layers.weatherRadar {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Opacity").font(AtlasFont.body(14)).foregroundStyle(Color.atlasInk2)
                                    Spacer()
                                    Text("\(Int(layers.weatherOpacity * 100))%")
                                        .font(AtlasFont.mono(13)).foregroundStyle(Color.atlasCyan)
                                }
                                Slider(value: $layers.weatherOpacity, in: 0.1...1.0, step: 0.05)
                                    .tint(Color.atlasAccent)
                            }
                            .padding(.horizontal, 14).padding(.bottom, 12)
                        }
                        toggle("Day / night terminator", icon: "circle.lefthalf.filled", $layers.dayNight)
                        toggle("Airports", icon: "airplane.circle.fill", $layers.airports)
                    }
                }
                .padding(16)
            }
            .background(Color.atlasBackground)
            .navigationTitle("Layers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Reset") { layers = MapLayers() }
                        .foregroundStyle(layers.isActive ? Color.atlasAccent : Color.atlasInkFaint)
                        .disabled(!layers.isActive)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundStyle(Color.atlasAccent).fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationBackground(Color.atlasBackground)
    }

    private func section(_ title: String, @ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            AtlasSectionHeader(title: title)
            VStack(spacing: 0) { content() }.atlasCard(radius: 16)
        }
    }

    private func toggle(_ label: String, icon: String, _ binding: Binding<Bool>) -> some View {
        Toggle(isOn: binding) {
            HStack(spacing: 11) {
                Image(systemName: icon).font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(binding.wrappedValue ? Color.atlasAccent : Color.atlasInkFaint)
                    .frame(width: 22)
                Text(label).font(AtlasFont.body(15)).foregroundStyle(Color.atlasText)
            }
        }
        .tint(Color.atlasAccent)
        .padding(.horizontal, 14).padding(.vertical, 11)
    }
}
