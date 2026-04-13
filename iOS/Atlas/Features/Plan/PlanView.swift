import SwiftUI

struct PlanView: View {
    @Environment(AuthManager.self) private var auth
    @State private var vm = PlanViewModel()

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

                            // Future Trips
                            VStack(alignment: .leading, spacing: 12) {
                                SectionHeader(title: "Future Trips", count: vm.plannedTrips.count)
                                    .padding(.horizontal, 16)

                                if vm.plannedTrips.isEmpty {
                                    emptyState(text: "No planned or dream trips yet.")
                                } else {
                                    VStack(spacing: 1) {
                                        ForEach(vm.plannedTrips) { trip in
                                            PlannedTripRow(trip: trip)
                                        }
                                    }
                                    .atlasCard()
                                    .padding(.horizontal, 16)
                                }
                            }

                            // Bucket List
                            VStack(alignment: .leading, spacing: 12) {
                                SectionHeader(title: "Bucket List", count: vm.bucketList.count)
                                    .padding(.horizontal, 16)

                                if vm.bucketList.isEmpty {
                                    emptyState(text: "Add destinations you want to visit.")
                                } else {
                                    VStack(spacing: 1) {
                                        ForEach(vm.bucketList) { item in
                                            BucketListRow(item: item)
                                        }
                                    }
                                    .atlasCard()
                                    .padding(.horizontal, 16)
                                }
                            }
                        }
                        .padding(.vertical, 16)
                    }
                    .refreshable { await vm.load(api: auth.api) }
                }
            }
            .navigationTitle("Plan")
            .navigationBarTitleDisplayMode(.large)
        }
        .task { await vm.load(api: auth.api) }
    }

    private func emptyState(text: String) -> some View {
        Text(text)
            .font(AtlasFont.body(13))
            .foregroundStyle(Color.atlasMuted)
            .multilineTextAlignment(.center)
            .padding(24)
            .frame(maxWidth: .infinity)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.atlasBorder.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [6]))
            )
            .padding(.horizontal, 16)
    }
}

struct PlannedTripRow: View {
    let trip: Trip

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: trip.status == .dream ? "sparkles" : "calendar")
                .font(.system(size: 16))
                .foregroundStyle(Color.atlasAccent)
                .frame(width: 32, height: 32)
                .background(Color.atlasAccent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                Text(trip.title)
                    .font(AtlasFont.body(15, weight: .medium))
                    .foregroundStyle(Color.atlasText)
                Text(trip.status.label)
                    .font(AtlasFont.body(12))
                    .foregroundStyle(Color.atlasMuted)
            }

            Spacer()

            if let date = trip.startDate {
                Text(date.prefix(10))
                    .font(AtlasFont.mono(11))
                    .foregroundStyle(Color.atlasMuted)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

struct BucketListRow: View {
    let item: BucketListItem

    private let priorityColors: [Int: Color] = [
        5: .yellow, 4: Color.atlasAccent, 3: Color.atlasText, 2: Color.atlasMuted, 1: Color.atlasMuted,
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "globe")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.atlasAccent)

                Text(locationLabel)
                    .font(AtlasFont.body(15, weight: .medium))
                    .foregroundStyle(Color.atlasText)

                Spacer()

                priorityStars
            }

            if let reason = item.reason {
                Text(reason)
                    .font(AtlasFont.body(12))
                    .foregroundStyle(Color.atlasMuted)
                    .lineLimit(2)
            }

            if let summary = item.aiSummary {
                Text(summary)
                    .font(AtlasFont.body(12))
                    .foregroundStyle(Color.atlasText.opacity(0.7))
                    .lineLimit(3)
                    .padding(.leading, 8)
                    .overlay(
                        Rectangle()
                            .fill(Color.atlasAccent.opacity(0.4))
                            .frame(width: 2),
                        alignment: .leading
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var locationLabel: String {
        if let city = item.city, let country = item.countryName {
            return "\(city), \(country)"
        }
        return item.countryName ?? item.countryCode ?? "Unknown"
    }

    private var priorityStars: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { n in
                Image(systemName: n <= item.priority ? "star.fill" : "star")
                    .font(.system(size: 8))
                    .foregroundStyle(n <= item.priority ? (priorityColors[item.priority] ?? .atlasAccent) : Color.atlasBorder)
            }
        }
    }
}
