# Atlas iOS Write Operations — Design Spec

**Date:** 2026-04-16
**Scope:** Trip create/edit/delete + destination add/delete on iOS. First write operations for trips and destinations (photos write ops shipped separately).
**Backend status:** Fully built. All CRUD endpoints exist for trips and destinations.

---

## Architecture

### New Files

| File | Purpose |
|---|---|
| `iOS/Atlas/Features/Trips/TripFormView.swift` | Create-trip sheet: title field + status picker, "Create" button |
| `iOS/Atlas/Features/Trips/TripEditSheet.swift` | Edit-trip sheet: all fields (title, status, dates, description, tags) + delete button |
| `iOS/Atlas/Features/Trips/TripWriteViewModel.swift` | `@Observable @MainActor` — create, update, delete trip operations |
| `iOS/Atlas/Features/Destinations/AddDestinationSheet.swift` | Two-stage sheet: MKLocalSearch city picker → date/rating entry |
| `iOS/Atlas/Features/Destinations/DestinationWriteViewModel.swift` | City search state (MKLocalSearch) + add/delete destination operations |

### Modified Files

| File | Change |
|---|---|
| `iOS/Atlas/API/Models.swift` | Add `TripCreate`, `TripUpdate`, `DestinationCreate` encodable request bodies |
| `iOS/Atlas/API/APIClient.swift` | Add `createTrip`, `updateTrip` (needs `put` helper), `deleteTrip`, `addDestination`, `deleteDestination` |
| `iOS/Atlas/Features/Trips/TripListView.swift` | "+" toolbar button → TripFormView sheet; swipe-to-delete on trip rows |
| `iOS/Atlas/Features/Trips/TripDetailView.swift` | Edit toolbar button → TripEditSheet; "Add Destination" button → AddDestinationSheet; swipe-to-delete on destination rows |

---

## Data Model

### Request Bodies (added to Models.swift)

```swift
struct TripCreate: Encodable {
    let title: String
    let status: TripStatus

    enum CodingKeys: String, CodingKey {
        case title, status
    }
}

struct TripUpdate: Encodable {
    var title: String?
    var status: TripStatus?
    var startDate: String?    // "YYYY-MM-DD" or nil to clear
    var endDate: String?
    var description: String?
    var tags: [String]?

    enum CodingKeys: String, CodingKey {
        case title, status, description, tags
        case startDate = "start_date"
        case endDate = "end_date"
    }
}

struct DestinationCreate: Encodable {
    let city: String
    let countryCode: String
    let countryName: String
    let region: String?
    let latitude: Double?
    let longitude: Double?
    let arrivalDate: String?    // "YYYY-MM-DD"
    let departureDate: String?
    let rating: Int?
    let orderIndex: Int

    enum CodingKeys: String, CodingKey {
        case city, region, latitude, longitude, rating
        case countryCode = "country_code"
        case countryName = "country_name"
        case arrivalDate = "arrival_date"
        case departureDate = "departure_date"
        case orderIndex = "order_index"
    }
}
```

---

## API Client Additions

```swift
// Needs new `put` generic helper (mirrors `post` but method = "PUT")
func put<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T

func createTrip(body: TripCreate) async throws -> Trip
func updateTrip(id: String, body: TripUpdate) async throws -> Trip
func deleteTrip(id: String) async throws          // uses existing delete()
func addDestination(tripId: String, body: DestinationCreate) async throws -> Destination
func deleteDestination(id: String) async throws   // uses existing delete()
```

---

## UI Components

### TripFormView (create)

- Modal sheet with `NavigationStack` for toolbar buttons
- Auto-focused `TextField` for title
- `Picker` for status (segmented style) showing all 4 statuses with SF Symbol icons
- "Cancel" dismisses, "Create" disabled until title non-empty
- On success: sheet dismisses, new `Trip` prepended to `TripListViewModel.trips` optimistically

### TripEditSheet (edit existing trip)

- Modal sheet pre-filled from current `Trip` values
- Fields:
  - Title: `TextField`
  - Status: `Picker` (segmented)
  - Start date: `DatePicker(.date)` with "None" toggle (nil-able)
  - End date: `DatePicker(.date)` with "None" toggle
  - Description: `TextEditor` (~4 lines, `.frame(minHeight: 80)`)
  - Tags: `TextField` with placeholder "adventure, europe, food" — split on commas when saved
- "Save" button in toolbar — calls `updateTrip`, updates `Trip` in parent on success
- "Delete Trip" destructive button at bottom — confirmation `Alert` — calls `deleteTrip` — on success dismisses sheet and pops navigation to trip list

### AddDestinationSheet (two-stage)

**Stage 1 — City Search:**
- `TextField` search bar with `Image(systemName: "magnifyingglass")` icon
- Live `MKLocalSearch` with 400ms debounce
- Results list: each row shows city name (body font) + country name (muted) + country flag emoji derived from ISO code
- Tap a result → advances to Stage 2 with that city pre-filled
- Empty state: "Search for a city" placeholder when query is empty
- No-results state: "No results for \(query)"

**Stage 2 — Detail Entry:**
- Non-editable city + country display at top (with back button to re-search)
- Arrival date: `DatePicker(.date)`, optional (toggle)
- Departure date: `DatePicker(.date)`, optional (toggle), must be ≥ arrival if both set
- Rating: horizontal row of 5 star buttons — tap to set (1–5), tap same star to clear
- "Add" button — calls `addDestination`, dismisses sheet, appends `Destination` to `TripDetailViewModel.destinations`

### Deletes

**TripListView:**
- `.onDelete` modifier on `ForEach` trip rows
- Confirmation `Alert` before deleting ("Delete \(trip.title)?")
- On confirm: `deleteTrip` → optimistic removal from `TripListViewModel.trips`
- On failure: trip re-inserted at original index, error banner shown

**TripDetailView:**
- Swipe-to-delete on `DestinationRow` items
- Confirmation alert
- On confirm: `deleteDestination` → optimistic removal from `TripDetailViewModel.destinations`

---

## State & Data Flow

- `TripWriteViewModel` is created as `@State` in `TripListView` and passed to `TripFormView` and `TripEditSheet`
- `DestinationWriteViewModel` is created as `@State` in `TripDetailView` and passed to `AddDestinationSheet`
- After successful create/update, the returned model is used to update the parent's list in-place — no full reload required
- After successful delete, the item is removed from the parent's array by ID — no reload required
- `MKLocalSearch` is called on the main actor (it is safe to do so); results are stored on `DestinationWriteViewModel`

---

## Geocoding

Uses **MapKit `MKLocalSearch`** (built-in iOS, no API key, no backend changes):

```swift
let request = MKLocalSearch.Request()
request.naturalLanguageQuery = query
request.resultTypes = .pointOfInterest  // cities appear as POIs
let search = MKLocalSearch(request: request)
let response = try await search.start()
// MKMapItem gives: name, placemark.isoCountryCode, placemark.country,
//                  placemark.administrativeArea, placemark.coordinate
```

Country flag emoji derived from ISO code:
```swift
func flagEmoji(for isoCode: String) -> String {
    isoCode.uppercased().unicodeScalars
        .compactMap { UnicodeScalar(127397 + $0.value) }
        .map { String($0) }.joined()
}
```

---

## What This Does Not Include

- Editing individual destinations after creation (future)
- Destination reordering (future)
- Transport leg creation (future — Phase 3)
- Trip duplication (future)
- Batch delete (future)
