# Atlas iOS Transport Write Operations — Design Spec

**Date:** 2026-04-19
**Scope:** Add/delete transport legs on iOS. First transport write operations. Backend CRUD endpoints fully built.

---

## Architecture

### New Files

| File | Purpose |
|---|---|
| `iOS/Atlas/Features/Transport/AddTransportSheet.swift` | Single adaptive form sheet — flight fields vs. generic fields based on type |
| `iOS/Atlas/Features/Transport/TransportWriteViewModel.swift` | `@Observable @MainActor` — create, delete, enrich-flight operations |

### Modified Files

| File | Change |
|---|---|
| `iOS/Atlas/API/Models.swift` | Add `TransportCreate` encodable + `FlightEnrichResponse` decodable |
| `iOS/Atlas/API/APIClient.swift` | Add `createTransportLeg`, `deleteTransportLeg`, `enrichFlight` |
| `iOS/Atlas/Features/Trips/TripDetailView.swift` | "+" button on Transport header, `showAddTransportSheet` sheet, contextMenu delete on `TransportRow` items |

---

## Data Model

### Request / Response Bodies (added to Models.swift)

```swift
struct TransportCreate: Encodable {
    let type: String          // "flight" | "train" | "car" | "ferry" | "bus" | "walk" | "other"
    let flightNumber: String?
    let airline: String?
    let originIata: String?
    let destIata: String?
    let originCity: String?
    let destCity: String?
    let departureAt: String?  // "yyyy-MM-dd" or "yyyy-MM-dd'T'HH:mm:ss" (POSIX locale)
    let arrivalAt: String?
    let durationMin: Int?
    let distanceKm: Double?
    let seatClass: String?    // "economy" | "business" | "first" | nil

    enum CodingKeys: String, CodingKey {
        case type, airline
        case flightNumber = "flight_number"
        case originIata = "origin_iata"
        case destIata = "dest_iata"
        case originCity = "origin_city"
        case destCity = "dest_city"
        case departureAt = "departure_at"
        case arrivalAt = "arrival_at"
        case durationMin = "duration_min"
        case distanceKm = "distance_km"
        case seatClass = "seat_class"
    }
}

struct FlightEnrichResponse: Decodable {
    let flightNumber: String?
    let airline: String?
    let originIata: String?
    let destIata: String?
    let originCity: String?
    let destCity: String?
    let durationMin: Int?
    let distanceKm: Double?

    enum CodingKeys: String, CodingKey {
        case airline
        case flightNumber = "flight_number"
        case originIata = "origin_iata"
        case destIata = "dest_iata"
        case originCity = "origin_city"
        case destCity = "dest_city"
        case durationMin = "duration_min"
        case distanceKm = "distance_km"
    }
}
```

Out of scope: `booking_ref`, `cost`, `currency`, `notes` — backend accepts them but not included in this phase.

---

## API Client Additions

```swift
func createTransportLeg(tripId: String, body: TransportCreate) async throws -> TransportLeg
func deleteTransportLeg(id: String) async throws
func enrichFlight(flightNumber: String, date: String) async throws -> FlightEnrichResponse
// enrichFlight: POST /transport/enrich-flight with body { flight_number, date }
```

---

## UI Components

### TransportWriteViewModel

`@MainActor @Observable final class TransportWriteViewModel`

Properties:
- `var isSubmitting = false`
- `var error: String? = nil`
- `var isEnriching = false`
- `var enrichError: String? = nil`

Methods:
- `func enrich(flightNumber: String, date: Date, api: APIClient) async -> FlightEnrichResponse?` — sets `isEnriching`, clears `enrichError`, returns nil + sets `enrichError` on failure
- `func createTransportLeg(tripId: String, body: TransportCreate, api: APIClient) async throws -> TransportLeg`
- `func deleteTransportLeg(id: String, api: APIClient) async throws`

### AddTransportSheet

Modal sheet with `NavigationStack`.

**Toolbar:**
- Leading: Cancel button → dismisses
- Trailing: Save button → disabled until valid (see validation below)

**Type picker:**
- `Picker("Type", selection: $type)` with `.menu` style
- Options: flight, train, car, ferry, bus, walk, other
- Each option shown as `Text` with SF Symbol prefix: e.g. `"✈ Flight"` via `Text("\(typeIcon) \(typeName)")`
  - Actually: use `Label` in a non-segmented Picker (`.menu` style supports icons unlike segmented)
- Default: `"flight"`

**Flight-specific section** (shown when `type == "flight"`):
- `TextField("Flight number", text: $flightNumber)` + `Button("Lookup")` inline in an `HStack`
  - During enrichment: replace button with `ProgressView().scaleEffect(0.8)`
  - On success: pre-fill `originIata`, `destIata`, `airline`, `durationMin`, `distanceKm`
  - On failure: show `enrichError` as small red `Text` below the field; fields remain editable
- `HStack` with two `TextField`s: "Origin IATA" + "Dest IATA" (3-char, `.uppercased()` via `.onChange`)
- `TextField("Airline", text: $airline)`
- `Picker("Seat class", selection: $seatClass)` with `.menu` style — Economy / Business / First / None

**Generic section** (shown when `type != "flight"`):
- `TextField("From", text: $originCity)`
- `TextField("To", text: $destCity)`

**Departure (all types):**
- `DatePicker("Departure", selection: $departureDate, displayedComponents: .date)` always shown
- Toggle "Include time" → when on, `displayedComponents: [.date, .hourAndMinute]`

**Arrival (all types, optional):**
- Toggle "Arrival" → when on, shows `DatePicker` with same date/time pattern as departure

**Save validation:**
- type is always set (has default), so check:
  - flight: `!originIata.isEmpty || !destIata.isEmpty`
  - others: `!originCity.isEmpty || !destCity.isEmpty`

**Date formatting:**
- `DateFormatter` with `locale = Locale(identifier: "en_US_POSIX")`
- Without time: `dateFormat = "yyyy-MM-dd"`
- With time: `dateFormat = "yyyy-MM-dd'T'HH:mm:ss"`

### TripDetailView Changes

- Transport section header always rendered (not gated on `!vm.transport.isEmpty`)
- `SectionHeader` + Spacer + `Button { showAddTransportSheet = true } label: { Image(systemName: "plus.circle") }` — matching Destinations header pattern exactly
- `@State private var showAddTransportSheet = false`
- `@State private var legToDelete: TransportLeg? = nil`
- `@State private var transportWriteVM = TransportWriteViewModel()`
- `.contextMenu` on each `TransportRow`:
  ```swift
  .contextMenu {
      Button(role: .destructive) { legToDelete = leg } label: {
          Label("Delete Leg", systemImage: "trash")
      }
  }
  ```
- Delete alert: same pattern as destination delete — guard + capture + optimistic remove + reload on failure
- `.sheet(isPresented: $showAddTransportSheet)` presenting `AddTransportSheet`
- On add success: `vm.transport.append(newLeg)`

---

## State & Data Flow

- `TransportWriteViewModel` is `@State` in `TripDetailView`, passed into `AddTransportSheet`
- `vm.transport` (on `TripDetailViewModel`) is the displayed list — mutated optimistically
- Enrichment is in-sheet only: pre-fills fields, never auto-saves
- Delete: optimistic removal → `vm.load(tripId:api:)` on failure
- `let api = auth.api` captured before all `Task` blocks

---

## What This Does Not Include

- Editing transport legs after creation (future)
- Transport leg reordering (future)
- Automatic duration computation from departure/arrival times (future)
- Booking reference, cost, currency, notes fields (future)
- Walk type enrichment (no enrichment endpoint for non-flights)
