import SwiftUI

// MARK: - Wide hero tile

private struct WideStatTile: View {
    let value: String
    let label: String
    var subLabel: String? = nil
    var icon: String? = nil
    var tone: AtlasTone = .neutral
    var isHero: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isHero ? Color.atlasCyan : tone.color)
            }
            if isHero {
                Text(value)
                    .font(AtlasFont.mono(44, weight: .heavy))
                    .foregroundStyle(AtlasGradient.accentBright)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            } else {
                Text(value)
                    .font(AtlasFont.mono(38, weight: .heavy))
                    .foregroundStyle(tone == .neutral ? Color.atlasText : tone.color)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }
            Text(label)
                .font(AtlasFont.body(13, weight: .semibold))
                .foregroundStyle(Color.atlasInk2)
            if let sub = subLabel {
                Text(sub)
                    .font(AtlasFont.mono(11))
                    .foregroundStyle(Color.atlasInkFaint)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .atlasCard(radius: 20, glow: isHero)
    }
}

// MARK: - Dual wide tile (most flown airport / top airline)

private struct DualWideTile: View {
    let leftLabel: String
    let leftValue: String
    let rightLabel: String
    let rightValue: String

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: "airplane.departure")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.atlasAccent)
                Text(leftValue)
                    .font(AtlasFont.mono(22, weight: .heavy))
                    .foregroundStyle(Color.atlasText)
                    .minimumScaleFactor(0.6).lineLimit(1)
                Text(leftLabel.uppercased())
                    .font(AtlasFont.mono(10, weight: .bold))
                    .tracking(1.0).foregroundStyle(Color.atlasInkFaint)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Rectangle().fill(Color.atlasBorder).frame(width: 1).padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: "star.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.atlasWarning)
                Text(rightValue)
                    .font(AtlasFont.mono(22, weight: .heavy))
                    .foregroundStyle(Color.atlasText)
                    .minimumScaleFactor(0.6).lineLimit(1)
                Text(rightLabel.uppercased())
                    .font(AtlasFont.mono(10, weight: .bold))
                    .tracking(1.0).foregroundStyle(Color.atlasInkFaint)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 16)
        }
        .padding(18)
        .atlasCard(radius: 20)
    }
}

// MARK: - Skeleton placeholder

private struct BentoSkeletonTile: View {
    var height: CGFloat = 110
    var body: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color.atlasSurface)
            .frame(maxWidth: .infinity, minHeight: height)
    }
}

// MARK: - StatsView

struct StatsView: View {
    @Environment(AuthManager.self) private var auth
    @State private var vm = StatsViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                AtlasGradient.backdrop.ignoresSafeArea()

                if vm.isLoading {
                    skeletonBento
                } else if let err = vm.error {
                    VStack {
                        ErrorBanner(message: err) {
                            Task { await vm.load(api: auth.api) }
                        }
                        Spacer()
                    }
                } else if vm.stats == nil {
                    AtlasEmptyState(
                        icon: "chart.bar",
                        title: "No stats yet",
                        message: "Log some flights to see your stats here."
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        if let stats = vm.stats {
                            bentoCells(stats: stats)
                                .padding(16)
                        }
                    }
                    .refreshable { await vm.load(api: auth.api) }
                }
            }
            .navigationTitle("Stats")
            .navigationBarTitleDisplayMode(.large)
        }
        .task { await vm.load(api: auth.api) }
    }

    // MARK: - Bento

    @ViewBuilder
    private func bentoCells(stats: StatsResponse) -> some View {
        VStack(spacing: 12) {
            // HERO — km flown (wide, cyan, glow)
            let km = stats.totalDistanceKm
            let moonPct = km / 384_400.0 * 100
            WideStatTile(
                value: km >= 1_000 ? String(format: "%.0fk", km / 1_000) : String(format: "%.0f", km),
                label: "km flown",
                subLabel: String(format: "%.1f%% of the way to the Moon", moonPct),
                icon: "airplane",
                isHero: true
            )

            // 2-col small tiles
            let cols = [GridItem(.flexible()), GridItem(.flexible())]
            LazyVGrid(columns: cols, spacing: 12) {
                StatTile(
                    value: "\(stats.flightsCount)",
                    label: "Flights",
                    tone: .accent,
                    icon: "airplane.departure"
                )
                StatTile(
                    value: stats.hoursInAir.map { String(format: "%.0f", $0) } ?? "—",
                    label: "Hours in air",
                    unit: stats.hoursInAir != nil ? "h" : nil,
                    tone: .cyan,
                    icon: "clock"
                )
            }

            // Wide dual tile — most flown airport + top airline
            DualWideTile(
                leftLabel: "Most flown airport",
                leftValue: stats.mostFlownAirport ?? "—",
                rightLabel: "Top airline",
                rightValue: stats.topAirline ?? "—"
            )

            let co2 = stats.co2KgEstimate
            WideStatTile(
                value: co2 >= 1_000 ? String(format: "%.1f t", co2 / 1_000) : String(format: "%.0f kg", co2),
                label: "CO2 estimate",
                icon: "leaf",
                tone: .neutral
            )
        }
    }

    private var skeletonBento: some View {
        ScrollView {
            VStack(spacing: 12) {
                BentoSkeletonTile(height: 120)
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 12
                ) {
                    ForEach(0..<4, id: \.self) { _ in BentoSkeletonTile() }
                }
                BentoSkeletonTile(height: 100)
            }
            .padding(16)
            .redacted(reason: .placeholder)
        }
    }
}
