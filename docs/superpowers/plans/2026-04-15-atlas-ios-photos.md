# Atlas iOS Photos Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a full photo feature to the Atlas iOS app — grid browsing, fullscreen swipe viewer with pinch-to-zoom, upload from photo library, set cover, and delete.

**Architecture:** `PhotosViewModel` (@Observable, @MainActor) owns all photo state and is created in `TripDetailView` and shared by reference to `PhotoGridView`. Upload accepts pre-loaded `Data` tuples (view layer handles PHPicker loading) so the viewmodel stays free of UIKit/PhotosUI imports. Multipart encoding is built manually — no external deps.

**Tech Stack:** Swift 5.9, SwiftUI iOS 17+, PhotosUI (`PhotosPicker`, `PhotosPickerItem`), `UniformTypeIdentifiers` (MIME type detection), `URLSession` async/await.

---

## File Map

| File | Action | Responsibility |
|---|---|---|
| `iOS/Atlas/API/Models.swift` | Modify | Add `Photo`, `PhotoListResponse` |
| `iOS/Atlas/API/APIClient.swift` | Modify | Add `listPhotos`, `uploadPhoto` (multipart), `deletePhoto`, `setCoverPhoto`, `postVoid` helper, `Data.appendString` extension |
| `iOS/Atlas/Features/Photos/PhotosViewModel.swift` | Create | `@Observable @MainActor` state + `load`, `upload`, `delete`, `setCover` |
| `iOS/Atlas/Features/Photos/PhotoViewer.swift` | Create | Fullscreen `TabView(.page)` viewer, pinch-to-zoom, caption overlay, `Array[safe:]` subscript |
| `iOS/Atlas/Features/Photos/PhotoGridView.swift` | Create | 3-col grid, upload toolbar button, progress row, context menu, `PhotoCell`, `PhotoViewerToken`, `loadPickerItems` free function |
| `iOS/Atlas/Features/Trips/TripDetailView.swift` | Modify | Add `photosVM`, filmstrip section, parallel photo load in `.task`, picker onChange, fullScreenCover |

---

## Task 1: Photo model + API client methods

**Files:**
- Modify: `iOS/Atlas/API/Models.swift`
- Modify: `iOS/Atlas/API/APIClient.swift`

- [ ] **Step 1: Add Photo and PhotoListResponse to Models.swift**

Append to the end of `iOS/Atlas/API/Models.swift`:

```swift
// MARK: - Photos

struct Photo: Codable, Identifiable {
    let id: String
    let tripId: String
    let destinationId: String?
    let originalFilename: String?
    let caption: String?
    let takenAt: String?
    let latitude: Double?
    let longitude: Double?
    let width: Int?
    let height: Int?
    let sizeBytes: Int?
    let isCover: Bool
    let orderIndex: Int?
    let url: String
    let thumbnailUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, caption, latitude, longitude, width, height, url
        case tripId = "trip_id"
        case destinationId = "destination_id"
        case originalFilename = "original_filename"
        case takenAt = "taken_at"
        case sizeBytes = "size_bytes"
        case isCover = "is_cover"
        case orderIndex = "order_index"
        case thumbnailUrl = "thumbnail_url"
    }
}

struct PhotoListResponse: Codable {
    let items: [Photo]
    let total: Int
}
```

- [ ] **Step 2: Add photo API methods to APIClient.swift**

In `iOS/Atlas/API/APIClient.swift`, append to the `// MARK: - Convenience API wrappers` section (after `statsTimeline`):

```swift
func listPhotos(tripId: String) async throws -> [Photo] {
    let response: PhotoListResponse = try await get("/api/v1/trips/\(tripId)/photos")
    return response.items
}

func uploadPhoto(
    tripId: String,
    data: Data,
    filename: String,
    mimeType: String,
    caption: String? = nil
) async throws -> Photo {
    let boundary = UUID().uuidString
    var req = makeRequest("POST", path: "/api/v1/trips/\(tripId)/photos/upload")
    req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
    req.timeoutInterval = 120
    var body = Data()
    body.appendString("--\(boundary)\r\n")
    body.appendString("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n")
    body.appendString("Content-Type: \(mimeType)\r\n\r\n")
    body.append(data)
    body.appendString("\r\n")
    if let caption {
        body.appendString("--\(boundary)\r\n")
        body.appendString("Content-Disposition: form-data; name=\"caption\"\r\n\r\n")
        body.appendString(caption)
        body.appendString("\r\n")
    }
    body.appendString("--\(boundary)--\r\n")
    req.httpBody = body
    return try await perform(req)
}

func deletePhoto(photoId: String) async throws {
    try await delete("/api/v1/photos/\(photoId)")
}

func setCoverPhoto(photoId: String) async throws {
    try await postVoid("/api/v1/photos/\(photoId)/set-cover")
}
```

- [ ] **Step 3: Add postVoid helper and Data extension to APIClient.swift**

In `iOS/Atlas/API/APIClient.swift`, append to the `// MARK: - Private` section (after `perform`):

```swift
private func postVoid(_ path: String) async throws {
    var req = makeRequest("POST", path: path)
    req.httpBody = "{}".data(using: .utf8)
    let data: Data
    let response: URLResponse
    do {
        (data, response) = try await URLSession.shared.data(for: req)
    } catch {
        throw APIError.networkError(error)
    }
    guard let http = response as? HTTPURLResponse else { return }
    if http.statusCode == 401 { throw APIError.notAuthenticated }
    if !(200..<300).contains(http.statusCode) {
        let body = String(data: data, encoding: .utf8) ?? ""
        throw APIError.httpError(http.statusCode, body)
    }
}
```

Append after the closing brace of `APIClient` (outside the class):

```swift
private extension Data {
    mutating func appendString(_ string: String) {
        if let d = string.data(using: .utf8) { append(d) }
    }
}
```

- [ ] **Step 4: Commit**

```bash
git add iOS/Atlas/API/Models.swift iOS/Atlas/API/APIClient.swift
git commit -m "feat(ios): Photo model + listPhotos, uploadPhoto, deletePhoto, setCoverPhoto API methods"
```

---

## Task 2: PhotosViewModel

**Files:**
- Create: `iOS/Atlas/Features/Photos/PhotosViewModel.swift`

- [ ] **Step 1: Create the directory and file**

```bash
mkdir -p /path/to/iOS/Atlas/Features/Photos
```

Create `iOS/Atlas/Features/Photos/PhotosViewModel.swift`:

```swift
import Foundation

@MainActor
@Observable
final class PhotosViewModel {
    var photos: [Photo] = []
    var isLoading = false
    var isUploading = false
    var uploadProgress: Double = 0
    var error: String? = nil

    func load(tripId: String, api: APIClient) async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            photos = try await api.listPhotos(tripId: tripId)
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// `uploads` is pre-loaded by the view layer from PHPicker items.
    func upload(
        tripId: String,
        uploads: [(data: Data, filename: String, mimeType: String)],
        api: APIClient
    ) async {
        guard !uploads.isEmpty else { return }
        isUploading = true
        uploadProgress = 0
        defer { isUploading = false; uploadProgress = 0 }
        for (index, item) in uploads.enumerated() {
            do {
                let photo = try await api.uploadPhoto(
                    tripId: tripId,
                    data: item.data,
                    filename: item.filename,
                    mimeType: item.mimeType
                )
                photos.append(photo)
            } catch {
                self.error = "Upload failed: \(error.localizedDescription)"
            }
            uploadProgress = Double(index + 1) / Double(uploads.count)
        }
    }

    func delete(photoId: String, api: APIClient) async {
        do {
            try await api.deletePhoto(photoId: photoId)
            photos.removeAll { $0.id == photoId }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func setCover(photoId: String, api: APIClient) async {
        do {
            try await api.setCoverPhoto(photoId: photoId)
            photos = photos.map {
                Photo(
                    id: $0.id, tripId: $0.tripId, destinationId: $0.destinationId,
                    originalFilename: $0.originalFilename, caption: $0.caption,
                    takenAt: $0.takenAt, latitude: $0.latitude, longitude: $0.longitude,
                    width: $0.width, height: $0.height, sizeBytes: $0.sizeBytes,
                    isCover: $0.id == photoId, orderIndex: $0.orderIndex,
                    url: $0.url, thumbnailUrl: $0.thumbnailUrl
                )
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add iOS/Atlas/Features/Photos/PhotosViewModel.swift
git commit -m "feat(ios): PhotosViewModel — load, upload, delete, setCover"
```

---

## Task 3: PhotoViewer

**Files:**
- Create: `iOS/Atlas/Features/Photos/PhotoViewer.swift`

- [ ] **Step 1: Create PhotoViewer.swift**

Create `iOS/Atlas/Features/Photos/PhotoViewer.swift`:

```swift
import SwiftUI

struct PhotoViewer: View {
    let photos: [Photo]
    let startIndex: Int

    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex: Int
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @GestureState private var magnifyBy: CGFloat = 1.0

    init(photos: [Photo], startIndex: Int) {
        self.photos = photos
        self.startIndex = startIndex
        self._currentIndex = State(initialValue: startIndex)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $currentIndex) {
                ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                    ZoomablePhotoPage(
                        photo: photo,
                        scale: index == currentIndex ? scale * magnifyBy : 1,
                        offset: index == currentIndex ? offset : .zero
                    )
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .gesture(
                SimultaneousGesture(
                    MagnificationGesture()
                        .updating($magnifyBy) { value, state, _ in state = value }
                        .onEnded { value in
                            scale = min(max(scale * value, 1.0), 5.0)
                            if scale <= 1.0 { offset = .zero }
                        },
                    DragGesture()
                        .onChanged { value in
                            guard scale > 1 else { return }
                            offset = value.translation
                        }
                )
            )
            .onTapGesture(count: 2) {
                withAnimation(.spring()) {
                    if scale > 1 { scale = 1; offset = .zero }
                    else { scale = 2.5 }
                }
            }

            overlays
        }
        .onChange(of: currentIndex) { _, _ in
            scale = 1
            offset = .zero
        }
    }

    @ViewBuilder
    private var overlays: some View {
        VStack {
            // Top: counter + close
            HStack {
                Spacer()
                Text("\(currentIndex + 1) / \(photos.count)")
                    .font(AtlasFont.mono(13))
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .white.opacity(0.3))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .background(
                LinearGradient(colors: [.black.opacity(0.5), .clear],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            )

            Spacer()

            // Bottom: caption + date
            if let photo = photos[safe: currentIndex],
               photo.caption != nil || photo.takenAt != nil {
                VStack(alignment: .leading, spacing: 4) {
                    if let caption = photo.caption, !caption.isEmpty {
                        Text(caption)
                            .font(AtlasFont.body(14))
                            .foregroundStyle(.white)
                    }
                    if let takenAt = photo.takenAt {
                        Text(formatDate(takenAt))
                            .font(AtlasFont.mono(12))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(
                    LinearGradient(colors: [.clear, .black.opacity(0.65)],
                                   startPoint: .top, endPoint: .bottom)
                        .ignoresSafeArea()
                )
            }
        }
    }

    private func formatDate(_ iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        for options: ISO8601DateFormatter.Options in [
            [.withInternetDateTime, .withFractionalSeconds],
            [.withInternetDateTime]
        ] {
            formatter.formatOptions = options
            if let date = formatter.date(from: iso) {
                let display = DateFormatter()
                display.dateFormat = "MMM d, yyyy"
                return display.string(from: date)
            }
        }
        return String(iso.prefix(10))
    }
}

private struct ZoomablePhotoPage: View {
    let photo: Photo
    let scale: CGFloat
    let offset: CGSize

    var body: some View {
        AsyncImage(url: URL(string: photo.url)) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFit()
                    .scaleEffect(scale)
                    .offset(offset)
            case .failure:
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.white.opacity(0.4))
            default:
                ProgressView().tint(.white)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add iOS/Atlas/Features/Photos/PhotoViewer.swift
git commit -m "feat(ios): PhotoViewer — fullscreen swipe viewer with pinch-to-zoom and caption overlay"
```

---

## Task 4: PhotoGridView

**Files:**
- Create: `iOS/Atlas/Features/Photos/PhotoGridView.swift`

- [ ] **Step 1: Create PhotoGridView.swift**

Create `iOS/Atlas/Features/Photos/PhotoGridView.swift`:

```swift
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
```

- [ ] **Step 2: Commit**

```bash
git add iOS/Atlas/Features/Photos/PhotoGridView.swift
git commit -m "feat(ios): PhotoGridView — 3-col grid, upload, context menu, progress, empty state"
```

---

## Task 5: Integrate filmstrip into TripDetailView

**Files:**
- Modify: `iOS/Atlas/Features/Trips/TripDetailView.swift`

The current file has: `let tripId`, `let tripTitle`, `@Environment(AuthManager.self)`, `@State private var vm = TripDetailViewModel()`, body with ZStack, `.navigationTitle`, `.task`.

- [ ] **Step 1: Add imports and new @State properties**

At the top of `TripDetailView.swift`, change:

```swift
import SwiftUI
```

to:

```swift
import SwiftUI
import PhotosUI
```

Inside `struct TripDetailView: View`, after `@State private var vm = TripDetailViewModel()`, add:

```swift
@State private var photosVM = PhotosViewModel()
@State private var filmstripViewerToken: PhotoViewerToken? = nil
@State private var filmstripPickerItems: [PhotosPickerItem] = []
```

- [ ] **Step 2: Add Photos section to the ScrollView**

In the `ScrollView > LazyVStack` body, insert the Photos section **before** the Destinations section (before the `if !vm.destinations.isEmpty` block):

```swift
// Photos section
VStack(alignment: .leading, spacing: 12) {
    HStack {
        SectionHeader(title: "Photos", count: photosVM.photos.count)
        Spacer()
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
    .padding(.horizontal, 16)

    if photosVM.photos.isEmpty {
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
                            filmstripViewerToken = PhotoViewerToken(index: index)
                        }
                }
                NavigationLink {
                    PhotoGridView(tripId: tripId, tripTitle: tripTitle, vm: photosVM)
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
```

- [ ] **Step 3: Update .task to load photos in parallel**

Replace:

```swift
.task { await vm.load(tripId: tripId, api: auth.api) }
```

with:

```swift
.task {
    async let tripLoad: Void = vm.load(tripId: tripId, api: auth.api)
    async let photoLoad: Void = photosVM.load(tripId: tripId, api: auth.api)
    _ = await (tripLoad, photoLoad)
}
```

- [ ] **Step 4: Add .onChange and .fullScreenCover modifiers**

After the `.task` modifier (still inside the ZStack's modifiers chain), add:

```swift
.onChange(of: filmstripPickerItems) { _, items in
    guard !items.isEmpty else { return }
    Task {
        let uploads = await loadPickerItems(items)
        filmstripPickerItems = []
        await photosVM.upload(tripId: tripId, uploads: uploads, api: auth.api)
    }
}
.fullScreenCover(item: $filmstripViewerToken) { token in
    PhotoViewer(photos: photosVM.photos, startIndex: token.index)
}
```

- [ ] **Step 5: Add FilmstripCell at the bottom of TripDetailView.swift**

Append after the existing `SectionHeader` struct (at the bottom of the file):

```swift
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
```

- [ ] **Step 6: Commit**

```bash
git add iOS/Atlas/Features/Trips/TripDetailView.swift
git commit -m "feat(ios): add photo filmstrip and upload to TripDetailView"
```

---

## Task 6: Build verification

- [ ] **Step 1: Open the project in Xcode**

```bash
cd iOS && xcodegen generate
open Atlas.xcodeproj
```

- [ ] **Step 2: Build for simulator (⌘+B)**

Expected: zero errors, zero warnings about missing types.

If `Photo` or `PhotosViewModel` are not found → confirm new Swift files were added to the Xcode target (select file in navigator, check Target Membership in File Inspector).

- [ ] **Step 3: Run on simulator and verify these flows**

1. **Load**: Navigate to any trip → Photos section appears with count and "+" button
2. **Empty state**: New trip shows "No photos yet" text
3. **Upload (filmstrip)**: Tap "+" in the Photos section header → picker opens → select 1 photo → progress shows in filmstrip → photo appears
4. **Filmstrip tap**: Tap a thumbnail → PhotoViewer opens fullscreen on black background
5. **Swipe**: Swipe left/right between photos in viewer
6. **Pinch to zoom**: Pinch in viewer → zooms; double-tap → toggles 2.5× zoom
7. **Close viewer**: Tap ×  button → returns to trip detail
8. **See All**: Tap "All" chevron cell → PhotoGridView opens with full 3-col grid
9. **Upload (grid)**: Tap "+" toolbar in grid → select up to 10 photos → progress row appears → photos fill grid
10. **Set cover**: Long-press a photo in grid → "Set as Cover" → star badge appears on that cell
11. **Delete**: Long-press → Delete → confirm → photo removed from grid and filmstrip
12. **Pull to refresh**: Pull down in grid → reloads from backend

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "chore(ios): verify photos feature build and smoke test complete"
```
