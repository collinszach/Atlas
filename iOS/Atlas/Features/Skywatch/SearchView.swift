import SwiftUI
import CoreLocation

struct SearchView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(\.dismiss) private var dismiss
    var userCoordinate: CLLocationCoordinate2D? = nil

    @State private var query = ""
    @State private var results: [OverheadAircraft] = []
    @State private var isSearching = false
    @State private var searched = false
    @State private var selected: OverheadAircraft? = nil
    @State private var searchTask: Task<Void, Never>? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
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
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(Color.atlasInkFaint)
            TextField("", text: $query, prompt: Text("Flight, callsign, reg, type, 7700").foregroundColor(Color.atlasInkFaint))
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
        if !searched && results.isEmpty {
            AtlasEmptyState(
                icon: "magnifyingglass",
                title: "Find any aircraft",
                message: "Search a flight number or callsign (JBU1354), registration (N834JB), hex, aircraft type (A320), or squawk (7700)."
            )
            Spacer()
        } else if searched && results.isEmpty && !isSearching {
            AtlasEmptyState(icon: "airplane.slash", title: "No aircraft found", message: "Nothing matching “\(query)” is airborne right now. Try a full flight number or registration.")
            Spacer()
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(results) { ac in
                        Button { selected = ac } label: {
                            FlightRow(
                                badge: ac.badgeCode, tone: ac.tone,
                                title: ac.displayName,
                                subtitle: [ac.type, ac.routeLabel, ac.flightLevelString].compactMap { $0 }.joined(separator: " · "),
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
