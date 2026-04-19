# Atlas iOS Transport Write Operations — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow users to add and delete transport legs in TripDetailView, with flight number auto-enrichment via a new backend endpoint.

**Architecture:** A new `POST /api/v1/transport/enrich-flight` backend endpoint wraps AviationStack (degrades to 503 when key not configured). On iOS, `TransportWriteViewModel` handles create/delete/enrich; `AddTransportSheet` is a single adaptive form — flight fields vs. free-text route depending on type. TripDetailView gains a "+" button, contextMenu delete on rows, and two new modifiers.

**Tech Stack:** Swift 5.9, SwiftUI iOS 17, `@Observable @MainActor`, FastAPI, httpx, AviationStack API (optional)

---

## File Map

| Action | Path | Responsibility |
|---|---|---|
| Modify | `backend/app/config.py` | Add `aviationstack_api_key` setting |
| Modify | `backend/app/schemas/transport.py` | Add `EnrichFlightRequest`, `EnrichFlightResponse` |
| Modify | `backend/app/routers/transport.py` | Add `POST /transport/enrich-flight` endpoint |
| Modify | `backend/tests/test_transport.py` | Test enrich-flight 503 path |
| Modify | `iOS/Atlas/API/Models.swift` | Add `TransportCreate`, `FlightEnrichRequest`, `FlightEnrichResponse` |
| Modify | `iOS/Atlas/API/APIClient.swift` | Add `createTransportLeg`, `deleteTransportLeg`, `enrichFlight` |
| Create | `iOS/Atlas/Features/Transport/TransportWriteViewModel.swift` | `@Observable @MainActor` — create, delete, enrich |
| Create | `iOS/Atlas/Features/Transport/AddTransportSheet.swift` | Adaptive form sheet + `TransportType` enum |
| Modify | `iOS/Atlas/Features/Trips/TripDetailView.swift` | "+" button, sheet, contextMenu delete, delete alert |

---

## Task 1: Backend — enrich-flight endpoint

**Files:**
- Modify: `backend/app/config.py`
- Modify: `backend/app/schemas/transport.py`
- Modify: `backend/app/routers/transport.py`
- Modify: `backend/tests/test_transport.py`

- [ ] **Step 1: Write the failing test**

Add to the bottom of `backend/tests/test_transport.py`:

```python
@pytest.mark.asyncio
@pytest.mark.integration
async def test_enrich_flight_no_key_returns_503(authed_client):
    resp = await authed_client.post(
        "/api/v1/transport/enrich-flight",
        json={"flight_number": "AA123", "date": "2026-04-19"},
    )
    assert resp.status_code == 503
    assert "not configured" in resp.json()["detail"]


@pytest.mark.asyncio
@pytest.mark.integration
async def test_enrich_flight_requires_auth(client):
    resp = await client.post(
        "/api/v1/transport/enrich-flight",
        json={"flight_number": "AA123", "date": "2026-04-19"},
    )
    assert resp.status_code == 401
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd backend
pytest tests/test_transport.py::test_enrich_flight_no_key_returns_503 tests/test_transport.py::test_enrich_flight_requires_auth -v
```

Expected: FAIL — `404 Not Found` (endpoint doesn't exist yet)

- [ ] **Step 3: Add aviationstack_api_key to config**

In `backend/app/config.py`, add after `anthropic_api_key`:

```python
    # Flight enrichment (optional)
    aviationstack_api_key: str = ""
```

- [ ] **Step 4: Add request/response schemas**

In `backend/app/schemas/transport.py`, add at the end of the file (after `TransportRead`):

```python
class EnrichFlightRequest(BaseModel):
    flight_number: str
    date: str  # "YYYY-MM-DD"


class EnrichFlightResponse(BaseModel):
    flight_number: str | None = None
    airline: str | None = None
    origin_iata: str | None = None
    dest_iata: str | None = None
    origin_city: str | None = None
    dest_city: str | None = None
    duration_min: int | None = None
    distance_km: float | None = None
```

- [ ] **Step 5: Add the endpoint to the transport router**

In `backend/app/routers/transport.py`:

Add `import httpx` at the top (after the existing imports).

Add this import to the schema import line:
```python
from app.schemas.transport import TransportCreate, TransportRead, TransportUpdate, EnrichFlightRequest, EnrichFlightResponse
```

Add the endpoint after the existing `delete_transport` function:

```python
@router.post("/transport/enrich-flight", response_model=EnrichFlightResponse)
async def enrich_flight(
    body: EnrichFlightRequest,
    user_id: CurrentUser,
) -> EnrichFlightResponse:
    from app.config import settings

    if not settings.aviationstack_api_key:
        raise HTTPException(status_code=503, detail="Flight enrichment not configured")

    async with httpx.AsyncClient(timeout=10.0) as http:
        try:
            resp = await http.get(
                "http://api.aviationstack.com/v1/flights",
                params={
                    "access_key": settings.aviationstack_api_key,
                    "flight_iata": body.flight_number.upper(),
                    "flight_date": body.date,
                },
            )
        except httpx.HTTPError as exc:
            raise HTTPException(status_code=502, detail=f"Flight lookup failed: {exc}")

    if resp.status_code != 200:
        raise HTTPException(status_code=502, detail="Flight data unavailable")

    data = resp.json()
    flights = data.get("data") or []
    if not flights:
        raise HTTPException(status_code=404, detail=f"No data for {body.flight_number}")

    f = flights[0]
    dep = f.get("departure") or {}
    arr = f.get("arrival") or {}

    duration_min = None
    dep_sched = dep.get("scheduled")
    arr_sched = arr.get("scheduled")
    if dep_sched and arr_sched:
        try:
            from datetime import datetime as dt
            d_dep = dt.fromisoformat(dep_sched.replace("Z", "+00:00"))
            d_arr = dt.fromisoformat(arr_sched.replace("Z", "+00:00"))
            delta = int((d_arr - d_dep).total_seconds() / 60)
            if delta > 0:
                duration_min = delta
        except ValueError:
            pass

    return EnrichFlightResponse(
        flight_number=(f.get("flight") or {}).get("iata"),
        airline=(f.get("airline") or {}).get("name"),
        origin_iata=dep.get("iata"),
        dest_iata=arr.get("iata"),
        origin_city=dep.get("airport"),
        dest_city=arr.get("airport"),
        duration_min=duration_min,
        distance_km=None,  # AviationStack free tier omits distance
    )
```

- [ ] **Step 6: Run tests to verify they pass**

```bash
cd backend
pytest tests/test_transport.py::test_enrich_flight_no_key_returns_503 tests/test_transport.py::test_enrich_flight_requires_auth -v
```

Expected: both PASS

- [ ] **Step 7: Commit**

```bash
git add backend/app/config.py backend/app/schemas/transport.py backend/app/routers/transport.py backend/tests/test_transport.py
git commit -m "feat(backend): add POST /transport/enrich-flight endpoint"
```

---

## Task 2: iOS Models + APIClient

**Files:**
- Modify: `iOS/Atlas/API/Models.swift`
- Modify: `iOS/Atlas/API/APIClient.swift`

- [ ] **Step 1: Add transport write types to Models.swift**

In `iOS/Atlas/API/Models.swift`, find the `// MARK: - Transport` section (around line 251). Add a new `// MARK: - Transport write` section immediately before the `TransportLeg` struct:

```swift
// MARK: - Transport write

struct FlightEnrichRequest: Encodable {
    let flightNumber: String
    let date: String

    enum CodingKeys: String, CodingKey {
        case flightNumber = "flight_number"
        case date
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

struct TransportCreate: Encodable {
    let type: String
    let flightNumber: String?
    let airline: String?
    let originIata: String?
    let destIata: String?
    let originCity: String?
    let destCity: String?
    let departureAt: String?   // "yyyy-MM-dd" or "yyyy-MM-dd'T'HH:mm:ss"
    let arrivalAt: String?
    let durationMin: Int?
    let distanceKm: Double?
    let seatClass: String?

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
```

- [ ] **Step 2: Add transport write methods to APIClient.swift**

In `iOS/Atlas/API/APIClient.swift`, find the `// MARK: - Destination write operations` section and add a new section immediately after `deleteDestination`:

```swift
    // MARK: - Transport write operations

    func createTransportLeg(tripId: String, body: TransportCreate) async throws -> TransportLeg {
        try await post("/api/v1/trips/\(tripId)/transport", body: body)
    }

    func deleteTransportLeg(id: String) async throws {
        try await delete("/api/v1/transport/\(id)")
    }

    func enrichFlight(flightNumber: String, date: String) async throws -> FlightEnrichResponse {
        try await post(
            "/api/v1/transport/enrich-flight",
            body: FlightEnrichRequest(flightNumber: flightNumber, date: date)
        )
    }
```

- [ ] **Step 3: Verify the project builds**

Open `iOS/Atlas.xcodeproj` in Xcode. Press `⌘B`. Expected: build succeeds with no errors.

- [ ] **Step 4: Commit**

```bash
git add iOS/Atlas/API/Models.swift iOS/Atlas/API/APIClient.swift
git commit -m "feat(ios): add TransportCreate, FlightEnrichResponse, and transport write API methods"
```

---

## Task 3: TransportWriteViewModel

**Files:**
- Create: `iOS/Atlas/Features/Transport/TransportWriteViewModel.swift`

- [ ] **Step 1: Create the Transport directory and view model**

Create `iOS/Atlas/Features/Transport/TransportWriteViewModel.swift` with the following content:

```swift
import Foundation

@MainActor
@Observable
final class TransportWriteViewModel {
    var isSubmitting = false
    var error: String? = nil
    var isEnriching = false
    var enrichError: String? = nil

    /// Calls enrich-flight endpoint. Returns nil and sets enrichError on failure.
    func enrich(flightNumber: String, date: String, api: APIClient) async -> FlightEnrichResponse? {
        isEnriching = true
        enrichError = nil
        defer { isEnriching = false }
        do {
            return try await api.enrichFlight(flightNumber: flightNumber, date: date)
        } catch {
            enrichError = error.localizedDescription
            return nil
        }
    }

    func createTransportLeg(tripId: String, body: TransportCreate, api: APIClient) async throws -> TransportLeg {
        isSubmitting = true
        error = nil
        defer { isSubmitting = false }
        return try await api.createTransportLeg(tripId: tripId, body: body)
    }

    func deleteTransportLeg(id: String, api: APIClient) async throws {
        try await api.deleteTransportLeg(id: id)
    }
}
```

- [ ] **Step 2: Add the file to the Xcode project**

In Xcode, right-click the `Features` group → Add Files → select `TransportWriteViewModel.swift`. Make sure it's added to the Atlas target.

- [ ] **Step 3: Verify build**

Press `⌘B`. Expected: build succeeds.

- [ ] **Step 4: Commit**

```bash
git add iOS/Atlas/Features/Transport/TransportWriteViewModel.swift
git commit -m "feat(ios): add TransportWriteViewModel"
```

---

## Task 4: AddTransportSheet

**Files:**
- Create: `iOS/Atlas/Features/Transport/AddTransportSheet.swift`

- [ ] **Step 1: Create the sheet**

Create `iOS/Atlas/Features/Transport/AddTransportSheet.swift`:

```swift
import SwiftUI

private enum TransportType: String, CaseIterable {
    case flight, train, car, ferry, bus, walk, other

    var label: String { rawValue.capitalized }

    var systemImage: String {
        switch self {
        case .flight: return "airplane"
        case .train:  return "tram.fill"
        case .car:    return "car.fill"
        case .ferry:  return "ferry.fill"
        case .bus:    return "bus.fill"
        case .walk:   return "figure.walk"
        case .other:  return "arrow.right.circle"
        }
    }
}

struct AddTransportSheet: View {
    let tripId: String
    let api: APIClient
    var onAdded: (TransportLeg) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var vm = TransportWriteViewModel()

    @State private var type: TransportType = .flight
    @State private var flightNumber = ""
    @State private var originIata = ""
    @State private var destIata = ""
    @State private var airline = ""
    @State private var seatClass = ""
    @State private var originCity = ""
    @State private var destCity = ""
    @State private var departureDate = Date()
    @State private var includeDepartureTime = false
    @State private var hasArrival = false
    @State private var arrivalDate = Date()
    @State private var includeArrivalTime = false
    @State private var enrichedDurationMin: Int? = nil
    @State private var enrichedDistanceKm: Double? = nil

    private var isValid: Bool {
        if type == .flight {
            return !originIata.trimmingCharacters(in: .whitespaces).isEmpty ||
                   !destIata.trimmingCharacters(in: .whitespaces).isEmpty
        }
        return !originCity.trimmingCharacters(in: .whitespaces).isEmpty ||
               !destCity.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $type) {
                        ForEach(TransportType.allCases, id: \.rawValue) { t in
                            Label(t.label, systemImage: t.systemImage).tag(t)
                        }
                    }
                    .pickerStyle(.menu)
                }

                if type == .flight {
                    Section("Flight") {
                        HStack {
                            TextField("Flight number (e.g. AA123)", text: $flightNumber)
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                            if vm.isEnriching {
                                ProgressView().scaleEffect(0.8)
                            } else {
                                Button("Lookup") {
                                    Task { await lookupFlight() }
                                }
                                .foregroundStyle(flightNumber.isEmpty ? Color.atlasMuted : Color.atlasAccent)
                                .disabled(flightNumber.isEmpty)
                            }
                        }
                        if let err = vm.enrichError {
                            Text(err)
                                .font(AtlasFont.body(12))
                                .foregroundStyle(.red)
                        }
                    }

                    Section("Route") {
                        HStack(spacing: 12) {
                            TextField("Origin IATA", text: $originIata)
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                            Image(systemName: "arrow.right")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.atlasMuted)
                            TextField("Dest IATA", text: $destIata)
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                        }
                        TextField("Airline", text: $airline)
                        Picker("Seat class", selection: $seatClass) {
                            Text("None").tag("")
                            Text("Economy").tag("economy")
                            Text("Business").tag("business")
                            Text("First").tag("first")
                        }
                        .pickerStyle(.menu)
                    }
                } else {
                    Section("Route") {
                        TextField("From", text: $originCity)
                        TextField("To", text: $destCity)
                    }
                }

                Section("Departure") {
                    DatePicker(
                        "Date",
                        selection: $departureDate,
                        displayedComponents: includeDepartureTime ? [.date, .hourAndMinute] : .date
                    )
                    Toggle("Include time", isOn: $includeDepartureTime)
                        .tint(Color.atlasAccent)
                }

                Section {
                    Toggle("Add arrival", isOn: $hasArrival)
                        .tint(Color.atlasAccent)
                    if hasArrival {
                        DatePicker(
                            "Date",
                            selection: $arrivalDate,
                            displayedComponents: includeArrivalTime ? [.date, .hourAndMinute] : .date
                        )
                        Toggle("Include time", isOn: $includeArrivalTime)
                            .tint(Color.atlasAccent)
                    }
                } header: {
                    Text("Arrival (optional)")
                }

                if let err = vm.error {
                    Section {
                        Text(err)
                            .font(AtlasFont.body(13))
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Add Transport")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.atlasAccent)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if vm.isSubmitting {
                        ProgressView().tint(Color.atlasAccent)
                    } else {
                        Button("Save") {
                            Task { await save() }
                        }
                        .foregroundStyle(isValid ? Color.atlasAccent : Color.atlasMuted)
                        .disabled(!isValid)
                    }
                }
            }
        }
    }

    private func lookupFlight() async {
        vm.enrichError = nil
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        let dateStr = f.string(from: departureDate)
        guard let result = await vm.enrich(
            flightNumber: flightNumber.uppercased(),
            date: dateStr,
            api: api
        ) else { return }
        if let v = result.originIata, !v.isEmpty { originIata = v }
        if let v = result.destIata, !v.isEmpty { destIata = v }
        if let v = result.airline, !v.isEmpty { airline = v }
        if let v = result.originCity, !v.isEmpty, originCity.isEmpty { originCity = v }
        if let v = result.destCity, !v.isEmpty, destCity.isEmpty { destCity = v }
        enrichedDurationMin = result.durationMin
        enrichedDistanceKm = result.distanceKm
    }

    private func save() async {
        guard !vm.isSubmitting else { return }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")

        func fmt(_ date: Date, includeTime: Bool) -> String {
            f.dateFormat = includeTime ? "yyyy-MM-dd'T'HH:mm:ss" : "yyyy-MM-dd"
            return f.string(from: date)
        }

        let body = TransportCreate(
            type: type.rawValue,
            flightNumber: type == .flight ? (flightNumber.isEmpty ? nil : flightNumber.uppercased()) : nil,
            airline: type == .flight ? (airline.isEmpty ? nil : airline) : nil,
            originIata: type == .flight ? (originIata.isEmpty ? nil : originIata.uppercased()) : nil,
            destIata: type == .flight ? (destIata.isEmpty ? nil : destIata.uppercased()) : nil,
            originCity: originCity.isEmpty ? nil : originCity,
            destCity: destCity.isEmpty ? nil : destCity,
            departureAt: fmt(departureDate, includeTime: includeDepartureTime),
            arrivalAt: hasArrival ? fmt(arrivalDate, includeTime: includeArrivalTime) : nil,
            durationMin: enrichedDurationMin,
            distanceKm: enrichedDistanceKm,
            seatClass: type == .flight ? (seatClass.isEmpty ? nil : seatClass) : nil
        )

        do {
            let leg = try await vm.createTransportLeg(tripId: tripId, body: body, api: api)
            onAdded(leg)
            dismiss()
        } catch {
            vm.error = error.localizedDescription
        }
    }
}
```

- [ ] **Step 2: Add the file to the Xcode project**

In Xcode, right-click the `Transport` group (created in Task 3) → Add Files → select `AddTransportSheet.swift`. Make sure it's added to the Atlas target.

- [ ] **Step 3: Verify build**

Press `⌘B`. Expected: build succeeds.

- [ ] **Step 4: Smoke-test in simulator**

Run in simulator. Navigate to any trip. (Transport "+" button not yet wired — that's Task 5.) Open the sheet manually by temporarily adding a `Button { showSheet = true }` in a test view, or wait until Task 5.

- [ ] **Step 5: Commit**

```bash
git add iOS/Atlas/Features/Transport/AddTransportSheet.swift
git commit -m "feat(ios): add AddTransportSheet with adaptive form and flight enrichment"
```

---

## Task 5: TripDetailView modifications

**Files:**
- Modify: `iOS/Atlas/Features/Trips/TripDetailView.swift`

**Context:** TripDetailView currently at `iOS/Atlas/Features/Trips/TripDetailView.swift`. The Transport section (lines ~132–151) is gated by `if !vm.transport.isEmpty` and has no add/delete controls. We need to:
1. Add three `@State` properties
2. Replace the transport section with one that always shows the header + "+" button
3. Add contextMenu delete on each `TransportRow`
4. Remove the "No transport logged yet." empty state (section header is always visible now)
5. Add `.sheet` and `.alert` modifiers

- [ ] **Step 1: Add state properties**

In `TripDetailView`, after the existing `@State private var destToDelete: Destination? = nil` line (line ~15), add:

```swift
    @State private var showAddTransportSheet = false
    @State private var legToDelete: TransportLeg? = nil
    @State private var transportWriteVM = TransportWriteViewModel()
```

- [ ] **Step 2: Replace the transport section**

Replace the entire transport section (from `// Transport` comment through the closing `}` of the `if vm.transport.isEmpty && vm.destinations.isEmpty` block):

```swift
                        // Transport
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                SectionHeader(title: "Transport", count: vm.transport.count)
                                Spacer()
                                Button {
                                    showAddTransportSheet = true
                                } label: {
                                    Image(systemName: "plus.circle")
                                        .font(.system(size: 18))
                                        .foregroundStyle(Color.atlasAccent)
                                }
                            }
                            .padding(.horizontal, 16)

                            if !vm.transport.isEmpty {
                                VStack(spacing: 1) {
                                    ForEach(vm.transport) { leg in
                                        TransportRow(leg: leg)
                                            .contextMenu {
                                                Button(role: .destructive) {
                                                    legToDelete = leg
                                                } label: {
                                                    Label("Delete Leg", systemImage: "trash")
                                                }
                                            }
                                    }
                                }
                                .atlasCard()
                                .padding(.horizontal, 16)
                            }
                        }
```

- [ ] **Step 3: Add sheet and alert modifiers**

After the existing `.alert(...)` for destination delete (around line ~207), add:

```swift
        .sheet(isPresented: $showAddTransportSheet) {
            AddTransportSheet(
                tripId: trip.id,
                api: auth.api
            ) { newLeg in
                vm.transport.append(newLeg)
            }
        }
        .alert(
            "Delete transport leg?",
            isPresented: Binding(
                get: { legToDelete != nil },
                set: { if !$0 { legToDelete = nil } }
            )
        ) {
            Button("Delete", role: .destructive) {
                guard let leg = legToDelete else { return }
                legToDelete = nil
                vm.transport.removeAll { $0.id == leg.id }
                let api = auth.api
                Task {
                    do {
                        try await transportWriteVM.deleteTransportLeg(id: leg.id, api: api)
                    } catch {
                        await vm.load(tripId: trip.id, api: api)
                    }
                }
            }
            Button("Cancel", role: .cancel) { legToDelete = nil }
        } message: {
            Text("This will permanently remove the transport leg from the trip.")
        }
```

- [ ] **Step 4: Verify build**

Press `⌘B`. Expected: build succeeds with no errors or warnings related to the new code.

- [ ] **Step 5: End-to-end test in simulator**

1. Run app in simulator, navigate to a trip's detail view
2. Verify Transport section header is always visible (even when empty) with a "+" button
3. Tap "+" → `AddTransportSheet` appears
4. Select type "Flight", enter a flight number, tap "Lookup" — expect either enrichment result or error message (503 if AviationStack not configured)
5. Fill in origin IATA + dest IATA manually, tap "Save" → leg appears in Transport list
6. Long-press a transport row → context menu appears with "Delete Leg"
7. Tap "Delete Leg" → confirmation alert appears
8. Confirm → leg removed from list
9. Select type "Car", fill "From" and "To", tap Save → leg appears correctly

- [ ] **Step 6: Commit**

```bash
git add iOS/Atlas/Features/Trips/TripDetailView.swift
git commit -m "feat(ios): add transport write ops to TripDetailView"
```
