import SwiftUI

struct TripListView: View {
    @Environment(AuthManager.self) private var auth
    @State private var vm = TripListViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.atlasBackground.ignoresSafeArea()

                if vm.isLoading && vm.trips.isEmpty {
                    List { ForEach(0..<6, id: \.self) { _ in SkeletonRow() } }
                        .listStyle(.insetGrouped)
                        .scrollContentBackground(.hidden)
                } else if let err = vm.error, vm.trips.isEmpty {
                    ErrorBanner(message: err) {
                        Task { await vm.load(api: auth.api, reset: true) }
                    }
                } else {
                    List {
                        ForEach(vm.filtered) { trip in
                            NavigationLink(value: trip) {
                                TripRow(trip: trip)
                            }
                            .listRowBackground(Color.atlasSurface)
                            .listRowSeparatorTint(Color.atlasBorder)
                            .onAppear {
                                if trip.id == vm.filtered.last?.id {
                                    Task { await vm.load(api: auth.api) }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .searchable(text: $vm.searchText, prompt: "Search trips")
                    .refreshable { await vm.load(api: auth.api, reset: true) }
                }
            }
            .navigationTitle("Trips")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    StatusFilterMenu(selected: vm.selectedStatus) { status in
                        Task { await vm.changeFilter(to: status, api: auth.api) }
                    }
                }
            }
            .navigationDestination(for: Trip.self) { trip in
                TripDetailView(tripId: trip.id, tripTitle: trip.title)
            }
        }
        .task { await vm.load(api: auth.api, reset: true) }
    }
}

struct TripRow: View {
    let trip: Trip

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: trip.status.systemImage)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(iconColor)
                .frame(width: 32, height: 32)
                .background(iconColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                Text(trip.title)
                    .font(AtlasFont.body(15, weight: .medium))
                    .foregroundStyle(Color.atlasText)
                HStack(spacing: 8) {
                    Text(trip.status.label)
                        .font(AtlasFont.body(12))
                        .foregroundStyle(Color.atlasMuted)
                    if let date = trip.startDate {
                        Text(date.prefix(4))
                            .font(AtlasFont.mono(11))
                            .foregroundStyle(Color.atlasMuted)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var iconColor: Color {
        switch trip.status {
        case .past:    return Color.atlasAccentCool
        case .active:  return .green
        case .planned: return Color.atlasAccent
        case .dream:   return .purple
        }
    }
}

struct StatusFilterMenu: View {
    let selected: TripStatus?
    let onSelect: (TripStatus?) -> Void

    var body: some View {
        Menu {
            Button("All") { onSelect(nil) }
            Divider()
            ForEach(TripStatus.allCases, id: \.self) { status in
                Button {
                    onSelect(status)
                } label: {
                    Label(status.label, systemImage: status.systemImage)
                }
            }
        } label: {
            Image(systemName: selected == nil ? "line.3.horizontal.decrease" : "line.3.horizontal.decrease.circle.fill")
                .foregroundStyle(Color.atlasAccent)
        }
    }
}
