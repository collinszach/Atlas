# Atlas iOS Photos — Design Spec

**Date:** 2026-04-15
**Scope:** Native iOS photo feature — grid browsing, fullscreen viewer, upload from photo library, set cover, delete.
**Backend status:** Fully built. Endpoints: `GET /trips/{id}/photos`, `POST /trips/{id}/photos/upload`, `DELETE /photos/{id}`, `POST /photos/{id}/set-cover`.

---

## Architecture

### New Files

| File | Purpose |
|---|---|
| `iOS/Atlas/Features/Photos/PhotosViewModel.swift` | `@Observable` state: photos array, upload progress, errors. Methods: load, upload, delete, setCover. |
| `iOS/Atlas/Features/Photos/PhotoGridView.swift` | Full-screen grid view. `LazyVGrid` 3-col, upload button in toolbar, long-press context menu, progress row during upload. |
| `iOS/Atlas/Features/Photos/PhotoViewer.swift` | Fullscreen swipe viewer. `TabView(.page)` on black, pinch-to-zoom, caption overlay, swipe-down dismiss. |

### Modified Files

| File | Change |
|---|---|
| `iOS/Atlas/API/Models.swift` | Add `Photo`, `PhotoListResponse` |
| `iOS/Atlas/API/APIClient.swift` | Add `listPhotos`, `uploadPhoto` (multipart), `deletePhoto`, `setCoverPhoto` |
| `iOS/Atlas/Features/Trips/TripDetailView.swift` | Add Photos filmstrip section at top of detail scroll view |

---

## Data Model

```swift
struct Photo: Codable, Identifiable {
    let id: String
    let tripId: String
    let destinationId: String?
    let originalFilename: String?
    let caption: String?
    let takenAt: String?          // ISO8601 from EXIF
    let latitude: Double?
    let longitude: Double?
    let width: Int?
    let height: Int?
    let sizeBytes: Int?
    let isCover: Bool
    let orderIndex: Int?
    let url: String               // full-res MinIO URL
    let thumbnailUrl: String?     // 400px WebP, may be nil while backend generates

    enum CodingKeys: String, CodingKey {
        case id, caption, latitude, longitude, width, height
        case tripId = "trip_id"
        case destinationId = "destination_id"
        case originalFilename = "original_filename"
        case takenAt = "taken_at"
        case sizeBytes = "size_bytes"
        case isCover = "is_cover"
        case orderIndex = "order_index"
        case url
        case thumbnailUrl = "thumbnail_url"
    }
}

struct PhotoListResponse: Codable {
    let items: [Photo]
    let total: Int
}
```

---

## API Client Additions

```swift
// List photos for a trip
func listPhotos(tripId: String) async throws -> [Photo]

// Upload: multipart/form-data, boundary built manually (no external deps)
// Supports JPEG, PNG, WebP, HEIC — passes content type through to backend
func uploadPhoto(
    tripId: String,
    data: Data,
    filename: String,
    mimeType: String,
    caption: String?
) async throws -> Photo

// Delete photo + storage object (backend handles both atomically)
func deletePhoto(photoId: String) async throws

// Mark as trip cover
func setCoverPhoto(photoId: String) async throws
```

**Multipart encoding:** UUID boundary string, single file field named `file`, optional `caption` text field. No third-party libraries.

---

## Upload Flow

1. User taps "+" → `PHPickerViewController` sheet (no permission dialog required)
2. User selects 1–10 images
3. Each image loaded as `Data` via `NSItemProvider.loadFileRepresentation` — preserves HEIC for EXIF passthrough
4. Sequential upload: one at a time, `uploadProgress: Double` (0–1) drives inline progress bar
5. Each completed `Photo` inserted immediately into `photos` array
6. `thumbnailUrl` may be `nil` on first insert (backend generates async); `AsyncImage` handles eventual consistency — retries on appear

---

## UI Components

### Filmstrip (TripDetailView)

- Section above Destinations
- `SectionHeader(title: "Photos", count: photos.count)` with upload "+" button on trailing edge
- Horizontal `ScrollView`: up to 6 square thumbnail cells (60pt), then a "See All →" tappable cell
- Empty state: single dashed-border cell with camera icon + "Add photos"
- Tapping a thumbnail → `PhotoViewer` starting at that index
- Tapping "See All" → `NavigationLink` to `PhotoGridView`
- Loads photos lazily on TripDetailView appear (shares `PhotosViewModel` injected as `@State`)

### PhotoGridView

- Navigation title: trip title + " Photos"
- Toolbar: upload button (SF Symbol `plus`) → PHPicker sheet
- `LazyVGrid` with 3 fixed columns, 2pt gaps, cells square with `AsyncImage` thumbnails
- Upload progress: full-width row at top of grid while uploading — filename + `ProgressView(value:)`
- Long-press cell → context menu:
  - **Set as Cover** (disabled if already cover; shows `checkmark` if active)
  - **Delete** (destructive) → confirmation `Alert` before removal
- Cover badge: gold star (`star.fill`) overlay in top-right of thumbnail cell for `isCover == true`
- Pull-to-refresh reloads photo list

### PhotoViewer

- Presented as fullscreen cover (`.fullScreenCover`)
- `TabView(selection:)` with `.tabViewStyle(.page(indexDisplayMode: .never))` — swipe between photos
- Each page: `AsyncImage` with `.scaledToFit` on black `Color.black.ignoresSafeArea()`
- Pinch-to-zoom: `MagnificationGesture` clamped to 1×–5×, paired with drag offset when zoomed
- Top overlay (semi-transparent): photo index label (`"3 / 12"` in mono), close `×` button
- Bottom overlay (semi-transparent): caption text, `taken_at` date formatted as `"MMM d, yyyy"` in mono
- Swipe-down gesture to dismiss (supplemented by close button for accessibility)

---

## Error Handling

| Scenario | Behavior |
|---|---|
| Load failure | `ErrorBanner` with retry in grid/filmstrip |
| Upload failure (single photo) | Inline alert; other photos in batch continue |
| Delete failure | Alert shown; photo remains in local state |
| `thumbnailUrl` nil | `AsyncImage` shows placeholder shimmer; loads full URL as fallback |
| Unsupported file type | PHPicker filter restricts to images; backend 422 surfaced as alert |

---

## What This Does Not Include

- Caption editing after upload (separate future feature)
- Photo reordering (drag-and-drop — future)
- EXIF GPS map mini-inset in viewer (future)
- Batch delete (future)
- Destination-scoped photo filtering (future)
