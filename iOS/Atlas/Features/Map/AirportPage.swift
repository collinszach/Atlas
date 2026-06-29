import SwiftUI
import CoreLocation

/// Airport detail: identity, local time, bookmark, and live aircraft on the
/// ground & nearby (via the existing `/skywatch/overhead` point query).
/// Departure/arrival boards require a paid schedule API — out of scope.
struct AirportPage: View {
    let airport: Airport

    @Environment(AuthManager.self) private var auth
    @Environment(\.dismiss) private var dismiss
    private let bookmarks = BookmarksStore.shared
    private let atc = ATCPlayer.shared
    private var feeds: [ATCFeed] { ATCFeedStore.shared.feeds(forICAO: airport.icao) }

    @State private var nearby: [OverheadAircraft] = []
    @State private var isLoading = true
    @State private var selected: OverheadAircraft? = nil
    @State private var refreshTask: Task<Void, Never>? = nil

    private static let nearbyRadiusKm = 30.0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    if !feeds.isEmpty { atcSection }
                    boardsNote
                    nearbySection
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .background(Color.atlasBackground)
            .navigationTitle(airport.code)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        bookmarks.toggleAirport(icao: airport.icao, iata: airport.iata, name: airport.name)
                    } label: {
                        Image(systemName: bookmarks.isAirportBookmarked(airport.icao) ? "star.fill" : "star")
                            .foregroundStyle(bookmarks.isAirportBookmarked(airport.icao) ? Color.atlasAccent : Color.atlasInk2)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundStyle(Color.atlasAccent).fontWeight(.semibold)
                }
            }
        }
        .sheet(item: $selected) { ac in
            AircraftDetailSheet(
                aircraft: ac,
                userCoordinate: ac.coordinate ?? airport.coordinate,
                isFollowed: false,
                onFollow: {}
            )
            .presentationDetents([.large])
            .presentationBackground(Color.atlasBackground)
            .presentationDragIndicator(.visible)
        }
        .task { await load(); startAutoRefresh() }
        .onDisappear { refreshTask?.cancel(); atc.stop() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.atlasAccent.opacity(0.14))
                        .frame(width: 56, height: 56)
                    Image(systemName: "building.2.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Color.atlasAccent)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(airport.name)
                        .font(AtlasFont.display(20, weight: .bold))
                        .foregroundStyle(Color.atlasText)
                        .lineLimit(2)
                    if let city = airport.city {
                        Text(city).font(AtlasFont.body(13)).foregroundStyle(Color.atlasInk2)
                    }
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                if let iata = airport.iata { codeChip(iata, tone: .accent) }
                codeChip(airport.icao, tone: .cyan)
                Spacer()
                localTimeView
            }
        }
        .padding(16)
        .atlasCard(radius: 18)
    }

    private func codeChip(_ text: String, tone: AtlasTone) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .heavy, design: .monospaced))
            .foregroundStyle(tone.color)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(tone.tint, in: Capsule())
    }

    @ViewBuilder private var localTimeView: some View {
        if let tz = airport.timeZone {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                VStack(alignment: .trailing, spacing: 1) {
                    Text(context.date, format: Date.FormatStyle(timeZone: tz).hour().minute())
                        .font(AtlasFont.mono(15, weight: .semibold))
                        .foregroundStyle(Color.atlasText)
                    Text("local").font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(0.6).foregroundStyle(Color.atlasInkFaint)
                }
            }
        }
    }

    private var atcSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            AtlasSectionHeader(title: "Listen — ATC")
            VStack(spacing: 0) {
                ForEach(Array(feeds.enumerated()), id: \.element.id) { index, feed in
                    atcRow(feed)
                    if index < feeds.count - 1 {
                        Divider().overlay(Color.atlasBorder).padding(.leading, 52)
                    }
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 4)
            .atlasCard(radius: 16)

            if let error = atc.errorMessage {
                Text(error).font(AtlasFont.body(12)).foregroundStyle(Color.atlasDanger)
                    .padding(.horizontal, 4)
            }
            Text("Audio via LiveATC.net")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.atlasInkFaint)
                .padding(.horizontal, 4)
        }
    }

    private func atcRow(_ feed: ATCFeed) -> some View {
        let playing = atc.isPlaying(feedID: feed.id)
        let loading = playing && atc.isLoading
        return Button { atc.toggle(feed) } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(playing ? Color.atlasAccent.opacity(0.18) : Color.atlasSurface2)
                        .frame(width: 38, height: 38)
                    if loading {
                        ProgressView().tint(Color.atlasAccent).scaleEffect(0.7)
                    } else {
                        Image(systemName: playing ? "stop.fill" : "play.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(playing ? Color.atlasAccent : Color.atlasInk2)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(feed.label).font(AtlasFont.body(14, weight: .semibold))
                        .foregroundStyle(Color.atlasText)
                    Text(playing ? (loading ? "Connecting…" : "Now playing") : "Tap to listen")
                        .font(AtlasFont.body(11))
                        .foregroundStyle(playing ? Color.atlasAccent : Color.atlasInkFaint)
                }
                Spacer()
                if playing && !loading {
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.atlasAccent)
                }
            }
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var boardsNote: some View {
        HStack(spacing: 10) {
            Image(systemName: "rectangle.stack.badge.clock")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.atlasInkFaint)
            VStack(alignment: .leading, spacing: 2) {
                Text("Departure & arrival boards")
                    .font(AtlasFont.body(13, weight: .semibold)).foregroundStyle(Color.atlasInk2)
                Text("Coming soon").font(AtlasFont.body(12)).foregroundStyle(Color.atlasInkFaint)
            }
            Spacer()
        }
        .padding(14)
        .atlasCard(radius: 14)
    }

    private var nearbySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            AtlasSectionHeader(title: "On the ground & nearby")
            if isLoading && nearby.isEmpty {
                HStack { Spacer(); ProgressView().tint(Color.atlasAccent); Spacer() }
                    .padding(.vertical, 24)
            } else if nearby.isEmpty {
                AtlasEmptyState(
                    icon: "airplane.slash",
                    title: "Quiet airspace",
                    message: "No trackable aircraft within \(Int(Self.nearbyRadiusKm)) km of \(airport.code) right now."
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(nearby) { ac in
                        Button { selected = ac } label: {
                            FlightRow(
                                badge: ac.badgeCode, tone: ac.tone,
                                title: ac.displayName,
                                subtitle: [ac.routeLabel, ac.flightLevelString].compactMap { $0 }.joined(separator: " · "),
                                typeCode: ac.type,
                                trailing: ac.distanceKm.map { String(format: "%.0f km", $0) },
                                pill: ac.isEmergency ? ("EMERGENCY", .emergency) : (ac.isMilitary ? ("MIL", .military) : nil),
                                chevron: true
                            )
                        }
                        .buttonStyle(.plain)
                        Divider().overlay(Color.atlasBorder).padding(.leading, 60)
                    }
                }
            }
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await auth.api.fetchOverhead(
                lat: airport.lat, lon: airport.lon, radiusKm: Self.nearbyRadiusKm
            )
            nearby = result.sorted {
                ($0.distanceKm ?? .greatestFiniteMagnitude) < ($1.distanceKm ?? .greatestFiniteMagnitude)
            }
        } catch {
            nearby = []
        }
    }

    private func startAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(15))
                if Task.isCancelled { break }
                await load()
            }
        }
    }
}
