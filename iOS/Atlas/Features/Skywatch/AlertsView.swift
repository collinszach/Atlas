import SwiftUI

/// History of fired Skywatch alerts — the feed behind push notifications.
/// Tapping a row tries to open live detail if the aircraft is still trackable.
struct AlertsView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var vm = AlertsViewModel()
    @State private var detail: OverheadAircraft? = nil
    @State private var loadingHex: String? = nil

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading && vm.alerts.isEmpty {
                    VStack {
                        ProgressView().tint(Color.atlasAccent)
                        Text("Loading…")
                            .font(AtlasFont.body(13))
                            .foregroundStyle(Color.atlasInk2)
                            .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let err = vm.error, vm.alerts.isEmpty {
                    ErrorBanner(message: err) {
                        Task { await vm.load(api: auth.api) }
                    }
                } else if vm.alerts.isEmpty {
                    AtlasEmptyState(
                        icon: "bell.slash",
                        title: "No alerts yet",
                        message: "When a rare, military, watchlisted, or emergency aircraft passes overhead, it shows up here."
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(vm.alerts) { alert in
                                Button { Task { await open(alert) } } label: {
                                    FlightRow(
                                        badge: alert.badgeCode,
                                        tone: alert.tone,
                                        title: alert.displayName,
                                        subtitle: alert.message ?? alert.relativeTime,
                                        typeCode: alert.type,
                                        trailing: alert.relativeTime,
                                        pill: (alert.triggerLabel, alert.tone),
                                        chevron: true
                                    )
                                    .padding(.horizontal, 16)
                                    .opacity(loadingHex == alert.hex ? 0.5 : 1)
                                }
                                .buttonStyle(.plain)
                                .disabled(loadingHex != nil)
                                Divider().overlay(Color.atlasBorder).padding(.leading, 60)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .refreshable { await vm.load(api: auth.api) }
                }
            }
            .background(Color.atlasBackground)
            .navigationTitle("Alerts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.atlasAccent)
                        .fontWeight(.semibold)
                }
            }
        }
        .sheet(item: $detail) { ac in
            AircraftDetailSheet(aircraft: ac, userCoordinate: ac.coordinate, isFollowed: false, onFollow: {})
                .presentationDetents([.large])
                .presentationBackground(Color.atlasBackground)
                .presentationDragIndicator(.visible)
        }
        .task { await vm.load(api: auth.api) }
    }

    /// Fetch live detail for the alert's aircraft; silently no-op if it's no longer trackable.
    private func open(_ alert: AircraftAlert) async {
        guard loadingHex == nil else { return }
        loadingHex = alert.hex
        defer { loadingHex = nil }
        do {
            detail = try await auth.api.fetchAircraftDetail(
                hex: alert.hex,
                lat: alert.lat ?? 0,
                lon: alert.lng ?? 0
            )
        } catch {
            // Aircraft has likely left the area (404) — nothing to show.
        }
    }
}
