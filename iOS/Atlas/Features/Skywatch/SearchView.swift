import SwiftUI
import CoreLocation

struct SearchView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(\.dismiss) private var dismiss
    var userCoordinate: CLLocationCoordinate2D? = nil

    private enum Scope: String, CaseIterable { case aircraft = "Aircraft", airports = "Airports" }

    @State private var scope: Scope = .aircraft
    @State private var query = ""
    @State private var results: [OverheadAircraft] = []
    @State private var isSearching = false
    @State private var searched = false
    @State private var selected: OverheadAircraft? = nil
    @State private var selectedAirport: Airport? = nil
    @State private var searchTask: Task<Void, Never>? = nil

    private let airportStore = AirportStore.shared

    private var airportResults: [Airport] {
        let q = query.trimmingCharacters(in: .whitespaces).uppercased()
        guard q.count >= 2 else { return [] }
        return airportStore.airports.filter { matches($0, q) }.prefix(30).map { $0 }
    }

    private func matches(_ ap: Airport, _ q: String) -> Bool {
        if ap.iata?.uppercased() == q { return true }
        if ap.icao.uppercased() == q { return true }
        if ap.iata?.uppercased().hasPrefix(q) == true { return true }
        if ap.icao.uppercased().hasPrefix(q) { return true }
        if ap.name.uppercased().contains(q) { return true }
        if ap.city?.uppercased().contains(q) == true { return true }
        return false
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                scopePicker
                searchField
                content
            }
            .background(Color.atlasBackground)
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundStyle(Color.atlasAccent).fontWeight(.semibold)
                }
            }
        }
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
        .sheet(item: $selectedAirport) { ap in
            AirportPage(airport: ap)
        }
    }

    private var scopePicker: some View {
        Picker("Scope", selection: $scope) {
            ForEach(Scope.allCases, id: \.self) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(Color.atlasInkFaint)
            TextField("", text: $query, prompt: Text(scope == .aircraft ? "Flight, callsign, reg, type, 7700" : "Airport code or name (JFK, Heathrow)").foregroundColor(Color.atlasInkFaint))
                .font(AtlasFont.body(16))
                .foregroundStyle(Color.atlasText)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.characters)
                .submitLabel(.search)
                .onSubmit(runSearch)
                .onChange(of: query) { _, _ in debounce() }
            if isSearching { ProgressView().scaleEffect(0.8).tint(Color.atlasAccent) }
            else if !query.isEmpty {
                Button { query = ""; results = []; searched = false } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Color.atlasInkFaint)
                }
            }
        }
        .padding(.horizontal, 14).frame(height: 50)
        .background(Color.atlasSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.atlasBorder, lineWidth: 1))
        .padding(16)
    }

    @ViewBuilder private var content: some View {
        if scope == .aircraft {
            aircraftContent
        } else {
            airportContent
        }
    }

    @ViewBuilder private var aircraftContent: some View {
        if !searched && results.isEmpty {
            AtlasEmptyState(
                icon: "magnifyingglass",
                title: "Find any aircraft",
                message: "Search a flight number or callsign (JBU1354), registration (N834JB), hex, aircraft type (A320), or squawk (7700)."
            )
            Spacer()
        } else if searched && results.isEmpty && !isSearching {
            AtlasEmptyState(icon: "dot.radiowaves.left.and.right", title: "Not currently trackable", message: "“\(query.uppercased())” isn’t airborne or visible on ADS-B right now. Search works while it's in the air and within coverage.")
            Spacer()
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(results) { ac in
                        Button { selected = ac } label: {
                            FlightRow(
                                badge: ac.badgeCode, tone: ac.tone,
                                title: ac.displayName,
                                subtitle: [ac.routeLabel, ac.flightLevelString].compactMap { $0 }.joined(separator: " · "),
                                typeCode: ac.type,
                                pill: ac.isEmergency ? ("EMERGENCY", .emergency) : (ac.isMilitary ? ("MIL", .military) : nil),
                                chevron: true
                            )
                            .padding(.horizontal, 16)
                        }
                        .buttonStyle(.plain)
                        Divider().overlay(Color.atlasBorder).padding(.leading, 60)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    @ViewBuilder private var airportContent: some View {
        if query.trimmingCharacters(in: .whitespaces).count < 2 {
            AtlasEmptyState(
                icon: "airplane.circle",
                title: "Find any airport",
                message: "Search an IATA/ICAO code (JFK, KJFK), name, or city."
            )
            Spacer()
        } else if airportResults.isEmpty {
            AtlasEmptyState(icon: "airplane.circle", title: "No matching airports", message: "“\(query.uppercased())” isn't in the airport dataset.")
            Spacer()
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(airportResults) { ap in
                        Button { selectedAirport = ap } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "airplane.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(Color.atlasAccent)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(ap.name).font(AtlasFont.body(15, weight: .medium)).foregroundStyle(Color.atlasText)
                                    Text([ap.code, ap.city].compactMap { $0 }.joined(separator: " · "))
                                        .font(AtlasFont.mono(11)).foregroundStyle(Color.atlasInk2)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.atlasInkFaint)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 11)
                        }
                        .buttonStyle(.plain)
                        Divider().overlay(Color.atlasBorder).padding(.leading, 60)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func debounce() {
        searchTask?.cancel()
        let current = query
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            if Task.isCancelled || current != query { return }
            await performSearch()
        }
    }

    private func runSearch() { searchTask?.cancel(); Task { await performSearch() } }

    private func performSearch() async {
        guard scope == .aircraft else { return }
        let q = query.trimmingCharacters(in: .whitespaces)
        guard q.count >= 2 else { results = []; searched = false; return }
        isSearching = true
        defer { isSearching = false }
        do {
            results = try await auth.api.searchAircraft(query: q)
        } catch {
            results = []
        }
        searched = true
    }
}
