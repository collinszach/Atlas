import SwiftUI

struct BookmarksView: View {
    var onSelectAircraft: (String) -> Void

    private let store = BookmarksStore.shared
    private let spottedStore = SpottedStore.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if store.aircraft.isEmpty && store.airports.isEmpty {
                        AtlasEmptyState(
                            icon: "star",
                            title: "No bookmarks yet",
                            message: "Star an aircraft or airport to pin it here."
                        )
                        .padding(.top, 40)
                    }

                    if !spottedStore.entries.isEmpty {
                        lifeListSection
                    }

                    if !store.aircraft.isEmpty {
                        section("Aircraft") {
                            ForEach(store.aircraft) { fav in
                                row(
                                    title: fav.label,
                                    subtitle: fav.type,
                                    icon: "airplane",
                                    onTap: { onSelectAircraft(fav.hex) },
                                    onRemove: { store.removeAircraft(fav.hex) }
                                )
                            }
                        }
                    }

                    if !store.airports.isEmpty {
                        section("Airports") {
                            ForEach(store.airports) { fav in
                                row(
                                    title: fav.name,
                                    subtitle: [fav.iata, fav.icao].compactMap { $0 }.joined(separator: " · "),
                                    icon: "airplane.circle.fill",
                                    onTap: nil,
                                    onRemove: { store.removeAirport(fav.icao) }
                                )
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(Color.atlasBackground)
            .navigationTitle("Bookmarks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.atlasAccent)
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationBackground(Color.atlasBackground)
    }

    private func section(_ title: String, @ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            AtlasSectionHeader(title: title)
            VStack(spacing: 0) { content() }.atlasCard(radius: 16)
        }
    }

    /// A plane-spotter's life list — every distinct aircraft the user has opened the
    /// detail sheet for, most recent first. Purely client-side (UserDefaults), no
    /// backend dependency.
    private var lifeListSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                AtlasSectionHeader(title: "Life list")
                Spacer()
                Text("\(spottedStore.entries.count) SEEN · \(spottedStore.uniqueTypeCount) TYPES")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(0.4)
                    .foregroundStyle(Color.atlasInkFaint)
            }
            VStack(spacing: 0) {
                ForEach(Array(spottedStore.recent.prefix(20))) { entry in
                    lifeListRow(entry)
                    if entry.id != spottedStore.recent.prefix(20).last?.id {
                        Divider().overlay(Color.atlasBorder).padding(.leading, 52)
                    }
                }
            }
            .atlasCard(radius: 16)
        }
    }

    private func lifeListRow(_ entry: SpottedAircraft) -> some View {
        HStack(spacing: 12) {
            Image(systemName: entry.isMilitary ? "shield.fill" : "airplane")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.atlasAccent)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.label).font(AtlasFont.body(15, weight: .medium)).foregroundStyle(Color.atlasText)
                Text([entry.type, entry.spotCount > 1 ? "×\(entry.spotCount)" : nil].compactMap { $0 }.joined(separator: " · "))
                    .font(AtlasFont.mono(11)).foregroundStyle(Color.atlasInk2)
            }
            Spacer()
            Button {
                spottedStore.remove(entry.hex)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.atlasInkFaint)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .contentShape(Rectangle())
        .onTapGesture { onSelectAircraft(entry.hex) }
    }

    private func row(
        title: String,
        subtitle: String?,
        icon: String,
        onTap: (() -> Void)?,
        onRemove: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.atlasAccent)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(AtlasFont.body(15, weight: .medium)).foregroundStyle(Color.atlasText)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle).font(AtlasFont.mono(11)).foregroundStyle(Color.atlasInk2)
                }
            }
            Spacer()
            Button {
                onRemove()
            } label: {
                Image(systemName: "star.slash")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.atlasInkFaint)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
    }
}
