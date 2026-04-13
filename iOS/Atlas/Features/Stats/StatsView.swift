import SwiftUI

struct StatsView: View {
    @Environment(AuthManager.self) private var auth
    @State private var vm = StatsViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.atlasBackground.ignoresSafeArea()

                if vm.isLoading {
                    LoadingView()
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 24) {
                            if let err = vm.error {
                                ErrorBanner(message: err) {
                                    Task { await vm.load(api: auth.api) }
                                }
                            }

                            if let stats = vm.stats {
                                statGrid(stats: stats)
                            }

                            timelineSection
                        }
                        .padding(.vertical, 16)
                    }
                    .refreshable { await vm.load(api: auth.api) }
                }
            }
            .navigationTitle("Stats")
            .navigationBarTitleDisplayMode(.large)
        }
        .task { await vm.load(api: auth.api) }
    }

    @ViewBuilder
    private func statGrid(stats: StatsResponse) -> some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            spacing: 12
        ) {
            StatCard(icon: "globe", label: "Countries", value: "\(stats.countriesVisited)")
            StatCard(icon: "mappin.circle", label: "Trips", value: "\(stats.tripsCount)")
            StatCard(icon: "moon.stars", label: "Nights Away", value: "\(stats.nightsAway)")
            StatCard(icon: "airplane", label: "Distance",
                     value: stats.totalDistanceKm >= 1000
                         ? String(format: "%.1fk km", stats.totalDistanceKm / 1000)
                         : String(format: "%.0f km", stats.totalDistanceKm))
            StatCard(icon: "leaf", label: "CO₂",
                     value: String(format: "%.1ft", stats.co2KgEstimate / 1000),
                     sub: "economy class avg")
            if let country = stats.mostVisitedCountry {
                StatCard(icon: "star", label: "Most Visited", value: country,
                         sub: stats.mostVisitedCountryCode)
            }
            if let days = stats.longestTripDays, let title = stats.longestTripTitle {
                StatCard(icon: "clock", label: "Longest Trip", value: "\(days) days", sub: title)
            }
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Trip Timeline", count: vm.timeline.count)
                .padding(.horizontal, 16)

            if vm.timeline.isEmpty {
                Text("No past trips to show.")
                    .font(AtlasFont.body(13))
                    .foregroundStyle(Color.atlasMuted)
                    .padding(.horizontal, 16)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(vm.timeline) { trip in
                            TimelineCard(trip: trip)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }
}

struct StatCard: View {
    let icon: String
    let label: String
    let value: String
    var sub: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.atlasAccent)
                Text(label.uppercased())
                    .font(AtlasFont.body(10, weight: .semibold))
                    .foregroundStyle(Color.atlasMuted)
                    .tracking(0.8)
            }
            Text(value)
                .font(AtlasFont.mono(22, weight: .semibold))
                .foregroundStyle(Color.atlasText)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            if let sub {
                Text(sub)
                    .font(AtlasFont.body(11))
                    .foregroundStyle(Color.atlasMuted)
                    .lineLimit(1)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .atlasCard()
    }
}

struct TimelineCard: View {
    let trip: TimelineTrip

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(trip.startDate.map { String($0.prefix(4)) } ?? "—")
                .font(AtlasFont.mono(11))
                .foregroundStyle(Color.atlasAccent)
            Text(trip.title)
                .font(AtlasFont.body(13, weight: .medium))
                .foregroundStyle(Color.atlasText)
                .lineLimit(2)
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: "mappin")
                    .font(.system(size: 10))
                Text("\(trip.destinationCount)")
                    .font(AtlasFont.mono(11))
            }
            .foregroundStyle(Color.atlasMuted)
        }
        .padding(14)
        .frame(width: 140, height: 120)
        .atlasCard()
    }
}
