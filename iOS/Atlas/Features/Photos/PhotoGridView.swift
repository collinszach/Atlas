import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

// Shared token for fullScreenCover(item:) — used by both PhotoGridView and TripDetailView
struct PhotoViewerToken: Identifiable {
    let id = UUID()
    let index: Int
}

// Free function shared by PhotoGridView and TripDetailView
func loadPickerItems(
    _ items: [PhotosPickerItem]
) async -> [(data: Data, filename: String, mimeType: String)] {
    var results: [(data: Data, filename: String, mimeType: String)] = []
    for item in items {
        guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
        let contentType = item.supportedContentTypes.first ?? UTType.jpeg
        let mimeType = contentType.preferredMIMEType ?? "image/jpeg"
        let ext = contentType.preferredFilenameExtension ?? "jpg"
        results.append((data: data, filename: "\(UUID().uuidString).\(ext)", mimeType: mimeType))
    }
    return results
}

struct PhotoGridView: View {
    let tripId: String
    let tripTitle: String
    let vm: PhotosViewModel   // reference — @Observable tracks changes automatically

    @Environment(AuthManager.self) private var auth
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var viewerToken: PhotoViewerToken? = nil
    @State private var deleteTarget: Photo? = nil
    @State private var showDeleteAlert = false

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
    ]

    var body: some View {
        ZStack {
            Color.atlasBackground.ignoresSafeArea()

            if vm.isLoading && vm.photos.isEmpty {
                LoadingView()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if vm.isUploading {
                            uploadProgressRow
                        }
                        if let err = vm.error {
                            ErrorBanner(message: err) {
                                Task { await vm.load(tripId: tripId, api: auth.api) }
                            }
                            .padding(16)
                        }
                        if vm.photos.isEmpty && !vm.isUploading {
                            emptyState
                        } else {
                            LazyVGrid(columns: columns, spacing: 2) {
                                ForEach(Array(vm.photos.enumerated()), id: \.element.id) { index, photo in
                                    PhotoCell(photo: photo)
                                        .onTapGesture {
                                            viewerToken = PhotoViewerToken(index: index)
                                        }
                                        .contextMenu {
                                            Button {
                                                Task { await vm.setCover(photoId: photo.id, api: auth.api) }
                                            } label: {
                                                Label(
                                                    photo.isCover ? "Cover Photo ✓" : "Set as Cover",
                                                    systemImage: photo.isCover ? "checkmark.circle.fill" : "star"
                                                )
                                            }
                                            .disabled(photo.isCover)

                                            Button(role: .destructive) {
                                                deleteTarget = photo
                                                showDeleteAlert = true
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                }
                            }
                        }
                    }
                }
                .refreshable { await vm.load(tripId: tripId, api: auth.api) }
            }
        }
        .navigationTitle(tripTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                PhotosPicker(selection: $pickerItems, maxSelectionCount: 10, matching: .images) {
                    Image(systemName: "plus")
                        .foregroundStyle(Color.atlasAccent)
                }
            }
        }
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }
            Task {
                let uploads = await loadPickerItems(items)
                pickerItems = []
                await vm.upload(tripId: tripId, uploads: uploads, api: auth.api)
            }
        }
        .fullScreenCover(item: $viewerToken) { token in
            PhotoViewer(photos: vm.photos, startIndex: token.index)
        }
        .alert("Delete Photo", isPresented: $showDeleteAlert, presenting: deleteTarget) { photo in
            Button("Delete", role: .destructive) {
                Task { await vm.delete(photoId: photo.id, api: auth.api) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("This photo will be permanently deleted.")
        }
        .task {
            if vm.photos.isEmpty { await vm.load(tripId: tripId, api: auth.api) }
        }
    }

    // MARK: - Sub-views

    private var uploadProgressRow: some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: "arrow.up.circle")
                    .foregroundStyle(Color.atlasAccent)
                Text("Uploading…")
                    .font(AtlasFont.body(13))
                    .foregroundStyle(Color.atlasText)
                Spacer()
                Text("\(Int(vm.uploadProgress * 100))%")
                    .font(AtlasFont.mono(12))
                    .foregroundStyle(Color.atlasMuted)
            }
            ProgressView(value: vm.uploadProgress)
                .tint(Color.atlasAccent)
        }
        .padding(16)
        .background(Color.atlasSurface)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 40))
                .foregroundStyle(Color.atlasMuted)
            Text("No photos yet")
                .font(AtlasFont.body(15))
                .foregroundStyle(Color.atlasMuted)
            Text("Tap + to add photos from your library")
                .font(AtlasFont.body(13))
                .foregroundStyle(Color.atlasMuted.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(48)
    }
}

// MARK: - PhotoCell

struct PhotoCell: View {
    let photo: Photo

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topTrailing) {
                AsyncImage(url: URL(string: photo.thumbnailUrl ?? photo.url)) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        Color.atlasSurface
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundStyle(Color.atlasMuted)
                            )
                    default:
                        Color.atlasSurface
                            .overlay(
                                ProgressView()
                                    .tint(Color.atlasMuted)
                                    .scaleEffect(0.7)
                            )
                    }
                }
                .frame(width: geo.size.width, height: geo.size.width)
                .clipped()

                if photo.isCover {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.atlasAccent)
                        .padding(4)
                        .background(Color.black.opacity(0.55))
                        .clipShape(Circle())
                        .padding(4)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
