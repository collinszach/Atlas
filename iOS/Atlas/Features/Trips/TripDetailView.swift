import SwiftUI

struct TripDetailView: View {
    let tripId: String
    let tripTitle: String

    @Environment(AuthManager.self) private var auth
    @State private var vm = TripDetailViewModel()

    var body: some View {
        ZStack {
            Color.atlasBackground.ignoresSafeArea()

            if vm.isLoading {
                LoadingView()
            } else if let err = vm.error {
                ErrorBanner(message: err) {
                    Task { await vm.load(tripId: tripId, api: auth.api) }
                }
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        // Destinations
                        if !vm.destinations.isEmpty {
                            SectionHeader(title: "Destinations", count: vm.destinations.count)
                                .padding(.horizontal, 16)

                            VStack(spacing: 1) {
                                ForEach(vm.destinations) { dest in
                                    DestinationRow(destination: dest)
                                }
                            }
                            .atlasCard()
                            .padding(.horizontal, 16)
                        }

                        // Transport
                        if !vm.transport.isEmpty {
                            SectionHeader(title: "Transport", count: vm.transport.count)
                                .padding(.horizontal, 16)

                            VStack(spacing: 1) {
                                ForEach(vm.transport) { leg in
                                    TransportRow(leg: leg)
                                }
                            }
                            .atlasCard()
                            .padding(.horizontal, 16)
                        }

                        if vm.destinations.isEmpty && vm.transport.isEmpty {
                            Text("No destinations or transport logged yet.")
                                .font(AtlasFont.body(14))
                                .foregroundStyle(Color.atlasMuted)
                                .padding(24)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.vertical, 16)
                }
            }
        }
        .navigationTitle(tripTitle)
        .navigationBarTitleDisplayMode(.large)
        .task { await vm.load(tripId: tripId, api: auth.api) }
    }
}

struct DestinationRow: View {
    let destination: Destination

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "mappin.circle.fill")
                .foregroundStyle(Color.atlasAccentCool)
                .font(.system(size: 20))

            VStack(alignment: .leading, spacing: 3) {
                Text(destination.city)
                    .font(AtlasFont.body(15, weight: .medium))
                    .foregroundStyle(Color.atlasText)
                HStack(spacing: 6) {
                    Text(destination.countryName)
                        .font(AtlasFont.body(12))
                        .foregroundStyle(Color.atlasMuted)
                    if let nights = destination.nights, nights > 0 {
                        Text("·")
                            .foregroundStyle(Color.atlasBorder)
                        Text("\(nights)n")
                            .font(AtlasFont.mono(11))
                            .foregroundStyle(Color.atlasMuted)
                    }
                }
            }

            Spacer()

            if let arrival = destination.arrivalDate {
                Text(arrival.prefix(10))
                    .font(AtlasFont.mono(11))
                    .foregroundStyle(Color.atlasMuted)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

struct TransportRow: View {
    let leg: TransportLeg

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: legIcon)
                .foregroundStyle(Color.atlasAccent)
                .font(.system(size: 18))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                if let fn = leg.flightNumber {
                    Text(fn)
                        .font(AtlasFont.mono(14, weight: .medium))
                        .foregroundStyle(Color.atlasText)
                }
                HStack(spacing: 4) {
                    Text(leg.originCity ?? leg.originIata ?? "—")
                    Image(systemName: "arrow.right")
                        .font(.system(size: 9))
                    Text(leg.destCity ?? leg.destIata ?? "—")
                }
                .font(AtlasFont.body(12))
                .foregroundStyle(Color.atlasMuted)
            }

            Spacer()

            if let km = leg.distanceKm {
                Text(String(format: "%.0f km", km))
                    .font(AtlasFont.mono(11))
                    .foregroundStyle(Color.atlasMuted)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var legIcon: String {
        switch leg.type {
        case "flight": return "airplane"
        case "train":  return "tram.fill"
        case "car":    return "car.fill"
        case "ferry":  return "ferry.fill"
        case "bus":    return "bus.fill"
        default:       return "arrow.right.circle"
        }
    }
}

struct SectionHeader: View {
    let title: String
    let count: Int

    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(AtlasFont.body(11, weight: .semibold))
                .foregroundStyle(Color.atlasMuted)
                .tracking(1.2)
            Spacer()
            Text("\(count)")
                .font(AtlasFont.mono(11))
                .foregroundStyle(Color.atlasMuted)
        }
    }
}
