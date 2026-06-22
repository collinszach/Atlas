import SwiftUI

struct TripListView: View {
    @Environment(AuthManager.self) private var auth
    @State private var vm = TripListViewModel()
    @State private var showCreateSheet = false
    @State private var tripToDelete: Trip? = nil

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
                        .onDelete { indexSet in
                            guard tripToDelete == nil, let idx = indexSet.first else { return }
                            tripToDelete = vm.filtered[idx]
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
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(Color.atlasAccent)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    StatusFilterMenu(selected: vm.selectedStatus) { status in
                        Task { await vm.changeFilter(to: status, api: auth.api) }
                    }
                }
            }
            .navigationDestination(for: Trip.self) { trip in
                TripDetailView(trip: trip)
            }
        }
        .task { await vm.load(api: auth.api, reset: true) }
        .sheet(isPresented: $showCreateSheet) {
            TripFormView(api: auth.api) { newTrip in
                vm.trips.insert(newTrip, at: 0)
            }
        }
        .alert(
            "Delete \"\(tripToDelete?.title ?? "")\"?",
            isPresented: Binding(
                get: { tripToDelete != nil },
                set: { if !$0 { tripToDelete = nil } }
            )
        ) {
            Button("Delete", role: .destructive) {
                guard let trip = tripToDelete else { return }
                tripToDelete = nil
                vm.trips.removeAll { $0.id == trip.id }
                let api = auth.api
                Task {
                    do {
                        try await api.deleteTrip(id: trip.id)
                    } catch {
                        await vm.load(api: api, reset: true)
                    }
                }
            }
            Button("Cancel", role: .cancel) { tripToDelete = nil }
        } message: {
            Text("This will permanently delete the trip and all its data.")
        }
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
