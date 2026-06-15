import SwiftUI
import MapKit

struct MapView: View {
    @Environment(AuthManager.self) private var auth
    @State private var vm = MapViewModel()
    @State private var position: MapCameraPosition = .automatic
    @State private var selectedCity: MapCity? = nil

    var body: some View {
        ZStack(alignment: .top) {
            Map(position: $position) {
                // Visited city markers
                ForEach(vm.cities) { city in
                    Annotation(city.city, coordinate: city.coordinate) {
                        Button {
                            selectedCity = city
                        } label: {
                            Circle()
                                .fill(Color.atlasAccentCool)
                                .frame(width: 10, height: 10)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.8), lineWidth: 1.5)
                                )
                                .shadow(color: Color.atlasAccentCool.opacity(0.6), radius: 4)
                        }
                    }
                }

                // Flight arcs as polylines
                ForEach(vm.arcs) { arc in
                    MapPolyline(coordinates: arc.arcCoordinates)
                        .stroke(Color.atlasAccent.opacity(0.5), lineWidth: 1.5)
                }
            }
            .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll, showsTraffic: false))
            .preferredColorScheme(.dark)
            .mapControls { MapCompass() }
            .ignoresSafeArea()

            // Header overlay
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: "globe.americas.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(AtlasGradient.accent)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Atlas")
                            .font(AtlasFont.display(20, weight: .heavy))
                            .foregroundStyle(Color.atlasText)
                        if !vm.isLoading {
                            Text("\(vm.countries.count) countries · \(vm.cities.count) cities")
                                .font(AtlasFont.mono(11))
                                .foregroundStyle(Color.atlasInk2)
                        }
                    }
                    Spacer()
                    if vm.isLoading {
                        ProgressView().tint(.atlasAccent)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
                .padding(.horizontal, 14)
                .padding(.top, 6)
            }

            if let err = vm.error {
                ErrorBanner(message: err) {
                    Task { await vm.load(api: auth.api) }
                }
                .padding(.top, 60)
            }
        }
        .sheet(item: $selectedCity) { city in
            CityDetailSheet(city: city)
                .presentationDetents([.medium])
                .presentationBackground(Color.atlasSurface)
        }
        .task {
            await vm.load(api: auth.api)
        }
    }
}

struct CityDetailSheet: View {
    let city: MapCity

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Color.atlasAccentCool)
                VStack(alignment: .leading, spacing: 2) {
                    Text(city.city)
                        .font(AtlasFont.display(20))
                        .foregroundStyle(Color.atlasText)
                    Text(city.countryName)
                        .font(AtlasFont.body(14))
                        .foregroundStyle(Color.atlasMuted)
                }
            }

            HStack(spacing: 6) {
                Text(city.countryCode)
                    .font(AtlasFont.mono(12))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.atlasBorder)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .foregroundStyle(Color.atlasText)

                Text(String(format: "%.4f, %.4f", city.latitude, city.longitude))
                    .font(AtlasFont.mono(11))
                    .foregroundStyle(Color.atlasMuted)
            }

            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
