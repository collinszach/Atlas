import SwiftUI
import CoreLocation

/// All aircraft of a single ICAO type code currently flying.
/// Reached from `AircraftDetailSheet` ("see all …") or a `TypePill` tap.
struct AircraftTypePage: View {
    let typeCode: String
    var userCoordinate: CLLocationCoordinate2D? = nil

    @Environment(AuthManager.self) private var auth

    @State private var aircraft: [OverheadAircraft] = []
    @State private var isLoading = true
    @State private var selected: OverheadAircraft? = nil

    private var category: AircraftCategory { AircraftCategory(typeCode: typeCode) }
    private var info: AircraftTypeInfo? { AircraftTypeInfo.lookup(typeCode) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                if isLoading && aircraft.isEmpty {
                    VStack {
                        ProgressView().tint(Color.atlasAccent)
                        Text("Scanning…").font(AtlasFont.body(13)).foregroundStyle(Color.atlasInk2).padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 40)
                } else if aircraft.isEmpty {
                    AtlasEmptyState(
                        icon: "airplane.slash",
                        title: "None airborne",
                        message: "No \(typeCode.uppercased()) is trackable right now. Check back later."
                    )
                } else {
                    list
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .background(Color.atlasBackground)
        .navigationTitle(typeCode.uppercased())
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selected) { ac in
            AircraftDetailSheet(
                aircraft: ac,
                userCoordinate: ac.coordinate ?? userCoordinate,
                isFollowed: false,
                onFollow: {}
            )
            .presentationDetents([.large])
            .presentationBackground(Color.atlasBackground)
            .presentationDragIndicator(.visible)
        }
        .task { await load() }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(category.tint.opacity(0.16))
                    .frame(width: 68, height: 68)
                AircraftMarker(category: category, heading: 0, color: category.tint, baseSize: 34)
            }
            VStack(alignment: .leading, spacing: 5) {
                Text(info?.name ?? category.label)
                    .font(AtlasFont.display(20, weight: .bold))
                    .foregroundStyle(Color.atlasText)
                    .lineLimit(2)
                if let summary = info?.summary {
                    Text(summary)
                        .font(AtlasFont.body(13))
                        .foregroundStyle(Color.atlasInk2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !isLoading {
                    Text("\(aircraft.count) flying now")
                        .font(AtlasFont.mono(12))
                        .foregroundStyle(category.tint)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .atlasCard(radius: 18)
    }

    private var list: some View {
        VStack(spacing: 0) {
            AtlasSectionHeader(title: "Live")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 6)
            LazyVStack(spacing: 0) {
                ForEach(aircraft) { ac in
                    Button { selected = ac } label: {
                        FlightRow(
                            badge: ac.badgeCode, tone: ac.tone,
                            title: ac.displayName,
                            subtitle: [ac.routeLabel, ac.flightLevelString].compactMap { $0 }.joined(separator: " · "),
                            typeCode: ac.type,
                            pill: ac.isEmergency ? ("EMERGENCY", .emergency) : (ac.isMilitary ? ("MIL", .military) : nil),
                            chevron: true
                        )
                    }
                    .buttonStyle(.plain)
                    Divider().overlay(Color.atlasBorder).padding(.leading, 60)
                }
            }
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await auth.api.searchAircraftType(typeCode)
            aircraft = result.sorted {
                ($0.distanceKm ?? .greatestFiniteMagnitude) < ($1.distanceKm ?? .greatestFiniteMagnitude)
            }
        } catch {
            aircraft = []
        }
    }
}
