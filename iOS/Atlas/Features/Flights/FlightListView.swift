import SwiftUI

struct FlightListView: View {
    @Environment(AuthManager.self) private var auth
    @State private var vm = FlightListViewModel()
    @State private var showAddSheet = false
    @State private var pendingDelete: TransportLeg? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color.atlasBackground.ignoresSafeArea()
                content
            }
            .navigationTitle("Flights")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(Color.atlasAccent)
                    }
                    .accessibilityLabel("Log a flight")
                }
            }
            .navigationDestination(for: TransportLeg.self) { leg in
                FlightDetailView(flight: leg) { deletedId in
                    Task { await vm.delete(id: deletedId, api: auth.api) }
                }
            }
        }
        .task { if vm.flights.isEmpty { await vm.load(api: auth.api) } }
        .sheet(isPresented: $showAddSheet) {
            AddTransportSheet(api: auth.api) { newLeg in
                vm.flights.insert(newLeg, at: 0)
            }
        }
        .alert(
            "Delete this flight?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            )
        ) {
            Button("Delete", role: .destructive) {
                guard let leg = pendingDelete else { return }
                pendingDelete = nil
                Task { await vm.delete(id: leg.id, api: auth.api) }
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: {
            Text(pendingDelete.map { "\($0.routeLabel) · \($0.departureDisplay)" } ?? "")
        }
    }

    @ViewBuilder
    private var content: some View {
        if vm.isLoading && vm.flights.isEmpty {
            List { ForEach(0..<6, id: \.self) { _ in SkeletonRow() } }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
        } else if let err = vm.error, vm.flights.isEmpty {
            VStack {
                ErrorBanner(message: err) {
                    Task { await vm.load(api: auth.api) }
                }
                Spacer()
            }
        } else if vm.flights.isEmpty {
            AtlasEmptyState(
                icon: "airplane",
                title: "No flights logged",
                message: "Tap + to log a flight. Enter a flight number and Atlas can look up the route for you."
            )
        } else {
            List {
                if !vm.flights.isEmpty {
                    summaryHeader
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 4, leading: 4, bottom: 8, trailing: 4))
                }
                ForEach(vm.grouped, id: \.year) { group in
                    Section {
                        ForEach(group.legs) { leg in
                            NavigationLink(value: leg) {
                                FlightRow(
                                    badge: leg.airline ?? leg.flightNumber ?? "✈",
                                    title: leg.routeLabel,
                                    subtitle: subtitle(for: leg),
                                    trailing: leg.distanceDisplay
                                )
                            }
                            .listRowBackground(Color.atlasSurface)
                            .listRowSeparatorTint(Color.atlasBorder)
                        }
                        .onDelete { idx in
                            guard let i = idx.first else { return }
                            pendingDelete = group.legs[i]
                        }
                    } header: {
                        AtlasSectionHeader(title: group.year)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .searchable(text: $vm.searchText, prompt: "Search flights")
            .refreshable { await vm.load(api: auth.api) }
        }
    }

    private var summaryHeader: some View {
        HStack(spacing: 16) {
            metric("\(vm.flights.count)", "flights")
            Rectangle().fill(Color.atlasBorder).frame(width: 1, height: 28)
            metric(
                vm.totalDistanceKm >= 1_000
                    ? String(format: "%.0fk", vm.totalDistanceKm / 1_000)
                    : String(format: "%.0f", vm.totalDistanceKm),
                "km flown"
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.atlasSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func metric(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.atlasText)
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(1.0)
                .foregroundStyle(Color.atlasInkFaint)
        }
    }

    private func subtitle(for leg: TransportLeg) -> String {
        [leg.flightNumber, leg.departureDisplay, leg.durationDisplay]
            .compactMap { $0 }
            .joined(separator: " · ")
    }
}
