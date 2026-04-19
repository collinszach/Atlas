import SwiftUI
import PhotosUI

struct TripDetailView: View {
    @State private var trip: Trip
    @Environment(AuthManager.self) private var auth
    @Environment(\.dismiss) private var dismiss
    @State private var vm = TripDetailViewModel()
    @State private var photosVM = PhotosViewModel()
    @State private var destWriteVM = DestinationWriteViewModel()
    @State private var filmstripViewerToken: PhotoViewerToken? = nil
    @State private var filmstripPickerItems: [PhotosPickerItem] = []
    @State private var showEditSheet = false
    @State private var showAddDestSheet = false
    @State private var destToDelete: Destination? = nil

    init(trip: Trip) {
        _trip = State(initialValue: trip)
    }

    var body: some View {
        ZStack {
            Color.atlasBackground.ignoresSafeArea()

            if vm.isLoading {
                LoadingView()
            } else if let err = vm.error {
                ErrorBanner(message: err) {
                    Task { await vm.load(tripId: trip.id, api: auth.api) }
                }
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        // Photos
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                SectionHeader(title: "Photos", count: photosVM.photos.count)
                                Spacer()
                                if photosVM.isUploading {
                                    ProgressView()
                                        .tint(Color.atlasAccent)
                                        .frame(width: 18, height: 18)
                                } else {
                                    PhotosPicker(
                                        selection: $filmstripPickerItems,
                                        maxSelectionCount: 10,
                                        matching: .images
                                    ) {
                                        Image(systemName: "plus.circle")
                                            .font(.system(size: 18))
                                            .foregroundStyle(Color.atlasAccent)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)

                            if photosVM.isLoading {
                                // photos still loading — show nothing to avoid flash
                            } else if photosVM.photos.isEmpty {
                                Text("No photos yet. Tap + to add from your library.")
                                    .font(AtlasFont.body(13))
                                    .foregroundStyle(Color.atlasMuted)
                                    .padding(.horizontal, 16)
                            } else {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(Array(photosVM.photos.prefix(6).enumerated()), id: \.element.id) { index, photo in
                                            FilmstripCell(photo: photo)
                                                .onTapGesture {
                                                    filmstripViewerToken = PhotoViewerToken(photoId: photo.id)
                                                }
                                        }
                                        NavigationLink {
                                            PhotoGridView(tripId: trip.id, tripTitle: trip.title, vm: photosVM)
                                        } label: {
                                            VStack(spacing: 4) {
                                                Image(systemName: "chevron.right")
                                                    .font(.system(size: 16, weight: .medium))
                                                    .foregroundStyle(Color.atlasAccent)
                                                Text("All")
                                                    .font(AtlasFont.mono(10))
                                                    .foregroundStyle(Color.atlasMuted)
                                            }
                                            .frame(width: 60, height: 60)
                                            .background(Color.atlasSurface)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(Color.atlasBorder, lineWidth: 0.5)
                                            )
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                }
                            }
                        }

                        // Destinations
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                SectionHeader(title: "Destinations", count: vm.destinations.count)
                                Spacer()
                                Button {
                                    showAddDestSheet = true
                                } label: {
                                    Image(systemName: "plus.circle")
                                        .font(.system(size: 18))
                                        .foregroundStyle(Color.atlasAccent)
                                }
                            }
                            .padding(.horizontal, 16)

                            if !vm.destinations.isEmpty {
                                VStack(spacing: 1) {
                                    ForEach(vm.destinations) { dest in
                                        DestinationRow(destination: dest)
                                            .contextMenu {
                                                Button(role: .destructive) {
                                                    destToDelete = dest
                                                } label: {
                                                    Label("Delete Destination", systemImage: "trash")
                                                }
                                            }
                                    }
                                }
                                .atlasCard()
                                .padding(.horizontal, 16)
                            }
                        }

                        // Transport
                        if !vm.transport.isEmpty {
                            SectionHeader(title: "Transport", count: vm.transport.count)
                                .padding(.horizontal, 16)

                            VStack(spacing: 1) {
                                ForEach(vm.transport) { leg in
                                    TransportRow(leg: leg)
                                }
                            }
                            .atlasCard()
                            .padding(.horizontal, 16)
                        }

                        if vm.transport.isEmpty && vm.destinations.isEmpty {
                            Text("No transport logged yet.")
                                .font(AtlasFont.body(14))
                                .foregroundStyle(Color.atlasMuted)
                                .padding(24)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.vertical, 16)
                }
            }
        }
        .navigationTitle(trip.title)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showEditSheet = true
                } label: {
                    Image(systemName: "square.and.pencil")
                        .foregroundStyle(Color.atlasAccent)
                }
            }
        }
        .task {
            async let tripLoad: Void = vm.load(tripId: trip.id, api: auth.api)
            async let photoLoad: Void = photosVM.load(tripId: trip.id, api: auth.api)
            _ = await (tripLoad, photoLoad)
        }
        .onChange(of: filmstripPickerItems) { _, items in
            guard !items.isEmpty else { return }
            Task {
                let uploads = await loadPickerItems(items)
                filmstripPickerItems = []
                await photosVM.upload(tripId: trip.id, uploads: uploads, api: auth.api)
            }
        }
        .fullScreenCover(item: $filmstripViewerToken) { token in
            let startIndex = photosVM.photos.firstIndex(where: { $0.id == token.photoId }) ?? 0
            PhotoViewer(photos: photosVM.photos, startIndex: startIndex)
        }
        .sheet(isPresented: $showEditSheet) {
            TripEditSheet(
                trip: trip,
                api: auth.api,
                onUpdated: { updated in
                    trip = updated
                },
                onDeleted: {
                    dismiss()
                }
            )
        }
        .sheet(isPresented: $showAddDestSheet) {
            AddDestinationSheet(
                tripId: trip.id,
                destinationCount: vm.destinations.count,
                api: auth.api
            ) { newDest in
                vm.destinations.append(newDest)
            }
        }
        .alert(
            "Delete \"\(destToDelete?.city ?? "")\"?",
            isPresented: Binding(
                get: { destToDelete != nil },
                set: { if !$0 { destToDelete = nil } }
            )
        ) {
            Button("Delete", role: .destructive) {
                guard let dest = destToDelete else { return }
                destToDelete = nil
                vm.destinations.removeAll { $0.id == dest.id }
                let api = auth.api
                Task {
                    do {
                        try await destWriteVM.deleteDestination(id: dest.id, api: api)
                    } catch {
                        await vm.load(tripId: trip.id, api: api)
                    }
                }
            }
            Button("Cancel", role: .cancel) { destToDelete = nil }
        } message: {
            Text("This will permanently remove the destination from the trip.")
        }
    }
}

struct DestinationRow: View {
    let destination: Destination

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "mappin.circle.fill")
                .foregroundStyle(Color.atlasAccentCool)
                .font(.system(size: 20))

            VStack(alignment: .leading, spacing: 3) {
                Text(destination.city)
                    .font(AtlasFont.body(15, weight: .medium))
                    .foregroundStyle(Color.atlasText)
                HStack(spacing: 6) {
                    Text(destination.countryName)
                        .font(AtlasFont.body(12))
                        .foregroundStyle(Color.atlasMuted)
                    if let nights = destination.nights, nights > 0 {
                        Text("·")
                            .foregroundStyle(Color.atlasBorder)
                        Text("\(nights)n")
                            .font(AtlasFont.mono(11))
                            .foregroundStyle(Color.atlasMuted)
                    }
                }
            }

            Spacer()

            if let arrival = destination.arrivalDate {
                Text(arrival.prefix(10))
                    .font(AtlasFont.mono(11))
                    .foregroundStyle(Color.atlasMuted)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

struct TransportRow: View {
    let leg: TransportLeg

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: legIcon)
                .foregroundStyle(Color.atlasAccent)
                .font(.system(size: 18))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                if let fn = leg.flightNumber {
                    Text(fn)
                        .font(AtlasFont.mono(14, weight: .medium))
                        .foregroundStyle(Color.atlasText)
                }
                HStack(spacing: 4) {
                    Text(leg.originCity ?? leg.originIata ?? "—")
                    Image(systemName: "arrow.right")
                        .font(.system(size: 9))
                    Text(leg.destCity ?? leg.destIata ?? "—")
                }
                .font(AtlasFont.body(12))
                .foregroundStyle(Color.atlasMuted)
            }

            Spacer()

            if let km = leg.distanceKm {
                Text(String(format: "%.0f km", km))
                    .font(AtlasFont.mono(11))
                    .foregroundStyle(Color.atlasMuted)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var legIcon: String {
        switch leg.type {
        case "flight": return "airplane"
        case "train":  return "tram.fill"
        case "car":    return "car.fill"
        case "ferry":  return "ferry.fill"
        case "bus":    return "bus.fill"
        default:       return "arrow.right.circle"
        }
    }
}

struct SectionHeader: View {
    let title: String
    let count: Int

    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(AtlasFont.body(11, weight: .semibold))
                .foregroundStyle(Color.atlasMuted)
                .tracking(1.2)
            Spacer()
            Text("\(count)")
                .font(AtlasFont.mono(11))
                .foregroundStyle(Color.atlasMuted)
        }
    }
}

struct FilmstripCell: View {
    let photo: Photo

    var body: some View {
        AsyncImage(url: URL(string: photo.thumbnailUrl ?? photo.url)) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            case .failure:
                Color.atlasSurface
                    .overlay(Image(systemName: "photo").foregroundStyle(Color.atlasMuted))
            default:
                Color.atlasSurface
                    .overlay(ProgressView().tint(Color.atlasMuted).scaleEffect(0.7))
            }
        }
        .frame(width: 60, height: 60)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.atlasBorder, lineWidth: 0.5)
        )
    }
}
