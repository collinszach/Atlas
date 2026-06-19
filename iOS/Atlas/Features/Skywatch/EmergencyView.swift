import SwiftUI
import CoreLocation

/// Global "aircraft in distress" feed — squawk 7700 (emergency), 7600 (radio fail), 7500 (hijack).
struct EmergencyView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var aircraft: [OverheadAircraft] = []
    @State private var isLoading = true
    @State private var selected: OverheadAircraft? = nil
    @State private var refreshTask: Task<Void, Never>? = nil

    private static let codes = ["7700", "7600", "7500"]

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && aircraft.isEmpty {
                    VStack { ProgressView().tint(Color.atlasDanger); Text("Scanning…").font(AtlasFont.body(13)).foregroundStyle(Color.atlasInk2).padding(.top, 8) }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if aircraft.isEmpty {
                    AtlasEmptyState(
                        icon: "checkmark.shield.fill",
                        title: "Clear skies",
                        message: "No aircraft squawking an emergency code right now. That's good news."
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(aircraft) { ac in
                                Button { selected = ac } label: {
                                    FlightRow(
                                        badge: ac.badgeCode, tone: .emergency,
                                        title: ac.displayName,
                                        subtitle: [ac.type, ac.routeLabel, ac.flightLevelString].compactMap { $0 }.joined(separator: " · "),
                                        pill: (Self.label(ac.squawk), .emergency),
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
            .background(Color.atlasBackground)
            .navigationTitle("Emergencies")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundStyle(Color.atlasAccent).fontWeight(.semibold)
                }
            }
        }
        .sheet(item: $selected) { ac in
            AircraftDetailSheet(aircraft: ac, userCoordinate: ac.coordinate, isFollowed: false, onFollow: {})
                .presentationDetents([.large])
                .presentationBackground(Color.atlasBackground)
                .presentationDragIndicator(.visible)
        }
        .task { await load(); startAutoRefresh() }
        .onDisappear { refreshTask?.cancel() }
    }

    private static func label(_ squawk: String?) -> String {
        switch squawk {
        case "7500": return "HIJACK"
        case "7600": return "RADIO FAIL"
        default: return "EMERGENCY"
        }
    }

    private func load() async {
        let lists = await withTaskGroup(of: [OverheadAircraft].self) { group -> [OverheadAircraft] in
            for code in Self.codes {
                group.addTask { (try? await auth.api.searchAircraft(query: code)) ?? [] }
            }
            var all: [OverheadAircraft] = []
            for await r in group { all.append(contentsOf: r) }
            return all
        }
        var seen = Set<String>()
        aircraft = lists.filter { seen.insert($0.hex).inserted }
            .sorted { ($0.squawk ?? "") < ($1.squawk ?? "") }
        isLoading = false
    }

    private func startAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(20))
                if Task.isCancelled { break }
                await load()
            }
        }
    }
}
