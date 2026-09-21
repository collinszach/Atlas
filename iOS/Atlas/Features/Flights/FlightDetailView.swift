import SwiftUI
import PhotosUI

struct FlightDetailView: View {
    let flight: TransportLeg
    var onDelete: (String) -> Void

    @Environment(AuthManager.self) private var auth
    @Environment(\.dismiss) private var dismiss
    @State private var photosVM = PhotosViewModel()
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var viewerToken: PhotoViewerToken? = nil
    @State private var showDeleteAlert = false

    var body: some View {
        ZStack {
            AtlasGradient.backdrop.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    routeHeader
                    metrics
                    photosSection
                }
                .padding(16)
            }
        }
        .navigationTitle(flight.flightNumber ?? flight.routeLabel)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Label("Delete flight", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(Color.atlasAccent)
                }
            }
        }
        .task { await photosVM.load(flightId: flight.id, api: auth.api) }
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }
            Task {
                let uploads = await loadUploads(from: items)
                pickerItems = []
                await photosVM.upload(flightId: flight.id, uploads: uploads, api: auth.api)
            }
        }
        .fullScreenCover(item: $viewerToken) { token in
            let start = photosVM.photos.firstIndex { $0.id == token.photoId } ?? 0
            PhotoViewer(photos: photosVM.photos, startIndex: start)
        }
        .alert("Delete this flight?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                onDelete(flight.id)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\(flight.routeLabel) · \(flight.departureDisplay)")
        }
    }

    // MARK: - Header

    private var routeHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                if let airline = flight.airline {
                    AirlineBadge(code: airline)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(flight.routeLabel)
                        .font(AtlasFont.display(26, weight: .bold))
                        .foregroundStyle(Color.atlasText)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    if let cities = flight.cityLabel {
                        Text(cities)
                            .font(AtlasFont.body(13))
                            .foregroundStyle(Color.atlasInk2)
                            .lineLimit(1)
                    }
                }
            }
            HStack(spacing: 8) {
                if let fn = flight.flightNumber {
                    Pill(text: fn, tone: .accent)
                }
                if let seat = flight.seatClass {
                    Pill(text: seat, tone: .violet)
                }
                Text(flight.departureDisplay)
                    .font(AtlasFont.mono(12))
                    .foregroundStyle(Color.atlasInkFaint)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .atlasCard(radius: 20)
    }

    private var metrics: some View {
        let cols = [GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: cols, spacing: 12) {
            StatTile(
                value: flight.distanceKm.map { String(format: "%.0f", $0) } ?? "—",
                label: "Distance",
                unit: flight.distanceKm != nil ? "km" : nil,
                tone: .cyan,
                icon: "arrow.left.and.right"
            )
            StatTile(
                value: flight.durationDisplay ?? "—",
                label: "Duration",
                tone: .accent,
                icon: "clock"
            )
        }
    }

    // MARK: - Photos

    private var photosSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                AtlasSectionHeader(title: "Photos")
                Spacer()
                if photosVM.isUploading {
                    ProgressView().scaleEffect(0.7).tint(Color.atlasAccent)
                } else {
                    PhotosPicker(
                        selection: $pickerItems,
                        maxSelectionCount: 50,
                        matching: .images
                    ) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.atlasAccent)
                    }
                }
            }

            if let err = photosVM.error {
                Text(err)
                    .font(AtlasFont.body(12))
                    .foregroundStyle(Color.atlasDanger)
            }

            if photosVM.isLoading {
                EmptyView()
            } else if photosVM.photos.isEmpty {
                Text("No photos yet. Tap + to add from your library.")
                    .font(AtlasFont.body(13))
                    .foregroundStyle(Color.atlasInk2)
            } else {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 2),
                              GridItem(.flexible(), spacing: 2),
                              GridItem(.flexible(), spacing: 2)],
                    spacing: 2
                ) {
                    ForEach(photosVM.photos.prefix(6)) { photo in
                        Button {
                            viewerToken = PhotoViewerToken(photoId: photo.id)
                        } label: {
                            PhotoCell(photo: photo)
                        }
                        .buttonStyle(.plain)
                    }
                }

                NavigationLink {
                    PhotoGridView(
                        flightId: flight.id,
                        flightTitle: flight.routeLabel,
                        vm: photosVM
                    )
                } label: {
                    HStack {
                        Text("See all \(photosVM.photos.count) photos")
                            .font(AtlasFont.body(13, weight: .medium))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(Color.atlasAccent)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .atlasCard(radius: 20)
    }

    private func loadUploads(
        from items: [PhotosPickerItem]
    ) async -> [(data: Data, filename: String, mimeType: String)] {
        var out: [(data: Data, filename: String, mimeType: String)] = []
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
            out.append((data: data, filename: "photo.jpg", mimeType: "image/jpeg"))
        }
        return out
    }
}
