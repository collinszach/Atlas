import SwiftUI

struct FlightListView: View {
    @Environment(AuthManager.self) private var auth
    @State private var vm = FlightListViewModel()
    @State private var showAddSheet = false
    @State private var pendingDelete: TransportLeg? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                AtlasGradient.backdrop.ignoresSafeArea()
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
            ScrollView {
                VStack(spacing: 11) {
                    ForEach(0..<5, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.atlasSurface)
                            .frame(height: 104)
                    }
                }
                .padding(16)
                .redacted(reason: .placeholder)
            }
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
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 11) {
                    Text(subtitle)
                        .font(AtlasFont.body(13))
                        .foregroundStyle(Color.atlasInk2)
                        .padding(.bottom, 2)

                    if vm.filtered.isEmpty {
                        Text("No flights match “\(vm.searchText)”.")
                            .font(AtlasFont.body(13))
                            .foregroundStyle(Color.atlasInkFaint)
                            .padding(.top, 24)
                            .frame(maxWidth: .infinity)
                    }

                    ForEach(Array(vm.filtered.enumerated()), id: \.element.id) { index, leg in
                        NavigationLink(value: leg) {
                            FlightLogCard(flight: leg, showGlow: index == 0)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                pendingDelete = leg
                            } label: {
                                Label("Delete flight", systemImage: "trash")
                            }
                        }
                    }
                }
                .padding(16)
            }
            .searchable(text: $vm.searchText, prompt: "Search flights")
            .refreshable { await vm.load(api: auth.api) }
        }
    }

    /// "Your logbook · 112 flights · 389,402 km" — the mockup's hero subtitle stat.
    private var subtitle: String {
        var parts = ["Your logbook", "\(vm.flights.count) flight\(vm.flights.count == 1 ? "" : "s")"]
        let km = vm.totalDistanceKm
        if km > 0 {
            parts.append("\(Self.kmFormatter.string(from: NSNumber(value: Int(km))) ?? "\(Int(km))") km")
        }
        return parts.joined(separator: " · ")
    }

    private static let kmFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f
    }()
}
