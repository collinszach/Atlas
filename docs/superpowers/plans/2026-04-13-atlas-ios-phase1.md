# Atlas iOS Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native SwiftUI iOS app for Atlas that connects to the existing FastAPI backend on the NUC, replicating the core feature set (map, trips, plan, stats) with native iOS design conventions.

**Architecture:** SwiftUI + iOS 17 `@Observable` state model. A single `APIClient` handles all NUC communication via `async/await` URLSession. Clerk iOS SDK provides auth — the session JWT flows directly into `Authorization: Bearer` headers, matching what the existing FastAPI backend already validates. Navigation is a `TabView` with 5 tabs. Features are self-contained folders under `Features/`.

**Tech Stack:** Swift 5.9, SwiftUI, iOS 17+, MapKit (SwiftUI `Map`), `ClerkSDK` (Swift Package), `KeychainSwift` (Swift Package, for secure token storage), `URLSession` async/await, `xcodegen` (generates the `.xcodeproj`).

**Design direction:** Dark-first, iOS HIG-compliant. SF Symbols throughout. Custom accent: `#C9A84C` (antique gold from Atlas brand). Cards use `.ultraThinMaterial` on a near-black background. Inspired by Flighty and Apple Maps — minimal chrome, information-dense, no gradients.

**Backend URL:** Configurable via `Config.swift`. Default `http://192.168.1.x:8000` — the user sets their NUC IP in that file once.

**Prerequisites before building:**
1. Install xcodegen: `brew install xcodegen`
2. Have Xcode 15+ installed on your Mac
3. Clone this repo on your Mac
4. Add `CLERK_PUBLISHABLE_KEY` to `iOS/Atlas/Resources/Secrets.xcconfig` (copy from `.env`)

---

## File Map

```
iOS/
├── project.yml                              xcodegen config
├── Atlas/
│   ├── App/
│   │   ├── AtlasApp.swift                   App entry + Clerk init
│   │   └── RootView.swift                   Auth gate → TabView
│   ├── Config/
│   │   └── Config.swift                     NUC base URL + Clerk key
│   ├── Auth/
│   │   ├── AuthManager.swift                @Observable Clerk session wrapper
│   │   └── SignInView.swift                 Email/password sign-in screen
│   ├── API/
│   │   ├── APIClient.swift                  URLSession + JWT injection
│   │   └── Models.swift                     Codable response types (mirroring backend schemas)
│   ├── Features/
│   │   ├── Map/
│   │   │   ├── MapViewModel.swift           @Observable: loads countries + cities + arcs
│   │   │   └── MapView.swift                MapKit: choropleth, city pins, flight arcs
│   │   ├── Trips/
│   │   │   ├── TripListViewModel.swift      @Observable: paginated trip list
│   │   │   ├── TripListView.swift           Searchable list + status filter
│   │   │   ├── TripDetailViewModel.swift    @Observable: trip + destinations
│   │   │   └── TripDetailView.swift         Destinations list + transport legs
│   │   ├── Plan/
│   │   │   ├── PlanViewModel.swift          @Observable: future trips + bucket list
│   │   │   └── PlanView.swift               Two sections: planned trips + bucket list
│   │   └── Stats/
│   │       ├── StatsViewModel.swift         @Observable: stats + timeline
│   │       └── StatsView.swift              Stat cards + horizontal timeline scroll
│   └── Shared/
│       ├── Theme.swift                      Colors, fonts, spacing constants
│       ├── LoadingView.swift                Reusable skeleton/spinner
│       └── ErrorBanner.swift               Inline error display
└── AtlasTests/
    └── APIClientTests.swift                 URLSession mock + decode tests
```

---

### Task 1: Project foundation

**Files:**
- Create: `iOS/project.yml`
- Create: `iOS/Atlas/App/AtlasApp.swift`
- Create: `iOS/Atlas/App/RootView.swift`
- Create: `iOS/Atlas/Config/Config.swift`
- Create: `iOS/Atlas/Shared/Theme.swift`
- Create: `iOS/Atlas/Shared/LoadingView.swift`
- Create: `iOS/Atlas/Shared/ErrorBanner.swift`
- Create: `iOS/Atlas/Resources/Info.plist`
- Create: `iOS/AtlasTests/APIClientTests.swift`

- [ ] **Step 1: Create `iOS/project.yml`**

```yaml
name: Atlas
options:
  bundleIdPrefix: com.atlas
  deploymentTarget:
    iOS: "17.0"
  xcodeVersion: "15.0"
  createIntermediateGroups: true

packages:
  ClerkSDK:
    url: https://github.com/clerk/clerk-ios
    from: "2.0.0"
  KeychainSwift:
    url: https://github.com/evgenyneu/keychain-swift
    from: "20.0.0"

targets:
  Atlas:
    type: application
    platform: iOS
    sources:
      - Atlas
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.atlas.app
        SWIFT_VERSION: 5.9
        IPHONEOS_DEPLOYMENT_TARGET: "17.0"
        DEVELOPMENT_TEAM: ""
        INFOPLIST_FILE: Atlas/Resources/Info.plist
        ALWAYS_SEARCH_USER_PATHS: NO
    dependencies:
      - package: ClerkSDK
        product: ClerkSDK
      - package: KeychainSwift
        product: KeychainSwift

  AtlasTests:
    type: bundle.unit-test
    platform: iOS
    sources:
      - AtlasTests
    dependencies:
      - target: Atlas
```

- [ ] **Step 2: Create `iOS/Atlas/Resources/Info.plist`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleName</key>
	<string>Atlas</string>
	<key>CFBundleIdentifier</key>
	<string>com.atlas.app</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundlePrincipalClass</key>
	<string>NSApplication</string>
	<key>UILaunchScreen</key>
	<dict/>
	<key>UISupportedInterfaceOrientations</key>
	<array>
		<string>UIInterfaceOrientationPortrait</string>
		<string>UIInterfaceOrientationLandscapeLeft</string>
		<string>UIInterfaceOrientationLandscapeRight</string>
	</array>
	<key>NSLocationWhenInUseUsageDescription</key>
	<string>Atlas uses your location to show nearby destinations on the map.</string>
</dict>
</plist>
```

- [ ] **Step 3: Create `iOS/Atlas/Config/Config.swift`**

```swift
import Foundation

enum Config {
    /// Base URL of the Atlas backend on the NUC.
    /// Change this to match your NUC's IP address or hostname.
    static let apiBase = URL(string: "http://192.168.1.100:8000")!

    /// Clerk publishable key — copy from your Clerk dashboard.
    static let clerkPublishableKey = "pk_live_REPLACE_ME"
}
```

- [ ] **Step 4: Create `iOS/Atlas/Shared/Theme.swift`**

```swift
import SwiftUI

extension Color {
    // Atlas brand palette
    static let atlasBackground    = Color(hex: "#0A0E1A")
    static let atlasSurface       = Color(hex: "#111827")
    static let atlasBorder        = Color(hex: "#1E2D45")
    static let atlasAccent        = Color(hex: "#C9A84C")  // antique gold
    static let atlasAccentCool    = Color(hex: "#4A90D9")  // ocean blue
    static let atlasText          = Color(hex: "#E2E8F0")
    static let atlasMuted         = Color(hex: "#64748B")
    static let atlasVisited       = Color(hex: "#4A90D9")
    static let atlasPlanned       = Color(hex: "#C9A84C")

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int & 0xFF0000) >> 16) / 255
        let g = Double((int & 0x00FF00) >> 8) / 255
        let b = Double(int & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

enum AtlasFont {
    static func display(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
}

struct AtlasCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.atlasSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.atlasBorder, lineWidth: 0.5)
            )
    }
}

extension View {
    func atlasCard() -> some View {
        modifier(AtlasCardStyle())
    }
}
```

- [ ] **Step 5: Create `iOS/Atlas/Shared/LoadingView.swift`**

```swift
import SwiftUI

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(.atlasAccent)
            Text("Loading…")
                .font(AtlasFont.body(13))
                .foregroundStyle(Color.atlasMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.atlasBackground)
    }
}

struct SkeletonRow: View {
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.atlasBorder)
                .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.atlasBorder)
                    .frame(height: 14)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.atlasBorder)
                    .frame(width: 100, height: 11)
            }
        }
        .padding(.vertical, 4)
        .redacted(reason: .placeholder)
    }
}
```

- [ ] **Step 6: Create `iOS/Atlas/Shared/ErrorBanner.swift`**

```swift
import SwiftUI

struct ErrorBanner: View {
    let message: String
    var retry: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .font(.system(size: 14))
            Text(message)
                .font(AtlasFont.body(13))
                .foregroundStyle(Color.atlasText)
                .lineLimit(2)
            Spacer()
            if let retry {
                Button("Retry", action: retry)
                    .font(AtlasFont.body(12, weight: .medium))
                    .foregroundStyle(Color.atlasAccent)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(hex: "#1F0A0A"))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.red.opacity(0.3), lineWidth: 0.5)
        )
        .padding(.horizontal, 16)
    }
}
```

- [ ] **Step 7: Create `iOS/Atlas/App/AtlasApp.swift`**

```swift
import SwiftUI
import ClerkSDK

@main
struct AtlasApp: App {
    init() {
        Clerk.shared.configure(publishableKey: Config.clerkPublishableKey)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
        }
    }
}
```

- [ ] **Step 8: Create `iOS/Atlas/App/RootView.swift`**

```swift
import SwiftUI
import ClerkSDK

struct RootView: View {
    @State private var authManager = AuthManager()

    var body: some View {
        Group {
            if authManager.isLoading {
                LoadingView()
            } else if authManager.isSignedIn {
                MainTabView()
                    .environment(authManager)
            } else {
                SignInView()
                    .environment(authManager)
            }
        }
        .background(Color.atlasBackground)
        .task {
            await authManager.checkSession()
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            MapView()
                .tabItem {
                    Label("Map", systemImage: "globe")
                }

            TripListView()
                .tabItem {
                    Label("Trips", systemImage: "mappin.circle")
                }

            PlanView()
                .tabItem {
                    Label("Plan", systemImage: "calendar")
                }

            StatsView()
                .tabItem {
                    Label("Stats", systemImage: "chart.bar")
                }
        }
        .tint(.atlasAccent)
        .background(Color.atlasBackground)
    }
}
```

- [ ] **Step 9: Create minimal `iOS/AtlasTests/APIClientTests.swift`**

```swift
import XCTest
@testable import Atlas

final class APIClientTests: XCTestCase {
    func testConfigHasValidBaseURL() {
        XCTAssertNotNil(Config.apiBase.host)
    }

    func testAPIClientInitializes() {
        let client = APIClient(token: nil)
        XCTAssertNil(client.token)
    }

    func testColorHexInitializer() {
        let gold = Color(hex: "#C9A84C")
        // Just verify it doesn't crash — UIColor would be needed for value comparison
        XCTAssertNotNil(gold)
    }
}
```

- [ ] **Step 10: Generate the Xcode project**

On your Mac, from the `iOS/` directory:
```bash
cd iOS && xcodegen generate
```
Expected: `Atlas.xcodeproj` created. Open it in Xcode 15.

- [ ] **Step 11: Commit**

```bash
cd /home/zach/Atlas && git add iOS/
git commit -m "feat(ios): project foundation — xcodegen, theme, navigation shell"
```

---

### Task 2: Auth + API client

**Files:**
- Create: `iOS/Atlas/Auth/AuthManager.swift`
- Create: `iOS/Atlas/Auth/SignInView.swift`
- Create: `iOS/Atlas/API/APIClient.swift`
- Create: `iOS/Atlas/API/Models.swift`

- [ ] **Step 1: Create `iOS/Atlas/API/Models.swift`**

These mirror the backend Pydantic schemas exactly — field names must match JSON keys.

```swift
import Foundation

// MARK: - Trips

struct Trip: Codable, Identifiable {
    let id: String
    let userId: String
    let title: String
    let description: String?
    let status: TripStatus
    let startDate: String?
    let endDate: String?
    let tags: [String]
    let visibility: String
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, title, description, status, tags, visibility
        case userId = "user_id"
        case startDate = "start_date"
        case endDate = "end_date"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

enum TripStatus: String, Codable, CaseIterable {
    case past, active, planned, dream
    var label: String { rawValue.capitalized }
    var systemImage: String {
        switch self {
        case .past:    return "checkmark.circle"
        case .active:  return "airplane"
        case .planned: return "calendar"
        case .dream:   return "sparkles"
        }
    }
}

struct TripListResponse: Codable {
    let items: [Trip]
    let total: Int
    let page: Int
    let limit: Int
}

// MARK: - Destinations

struct Destination: Codable, Identifiable {
    let id: String
    let tripId: String
    let city: String
    let countryCode: String
    let countryName: String
    let arrivalDate: String?
    let departureDate: String?
    let nights: Int?
    let rating: Int?
    let notes: String?
    let orderIndex: Int

    enum CodingKeys: String, CodingKey {
        case id, city, rating, notes
        case tripId = "trip_id"
        case countryCode = "country_code"
        case countryName = "country_name"
        case arrivalDate = "arrival_date"
        case departureDate = "departure_date"
        case nights
        case orderIndex = "order_index"
    }
}

// MARK: - Map

struct MapCountry: Codable, Identifiable {
    var id: String { countryCode }
    let countryCode: String
    let countryName: String
    let visitCount: Int
    let totalNights: Int
    let firstVisit: String?
    let lastVisit: String?

    enum CodingKeys: String, CodingKey {
        case countryCode = "country_code"
        case countryName = "country_name"
        case visitCount = "visit_count"
        case totalNights = "total_nights"
        case firstVisit = "first_visit"
        case lastVisit = "last_visit"
    }
}

struct MapCity: Codable, Identifiable {
    let id: String
    let city: String
    let countryCode: String
    let countryName: String
    let latitude: Double
    let longitude: Double
    let tripId: String

    enum CodingKeys: String, CodingKey {
        case id, city, latitude, longitude
        case countryCode = "country_code"
        case countryName = "country_name"
        case tripId = "trip_id"
    }
}

struct MapArc: Codable, Identifiable {
    let id: String
    let tripId: String
    let flightNumber: String?
    let originCity: String?
    let destCity: String?
    let originLat: Double
    let originLng: Double
    let destLat: Double
    let destLng: Double

    enum CodingKeys: String, CodingKey {
        case id
        case tripId = "trip_id"
        case flightNumber = "flight_number"
        case originCity = "origin_city"
        case destCity = "dest_city"
        case originLat = "origin_lat"
        case originLng = "origin_lng"
        case destLat = "dest_lat"
        case destLng = "dest_lng"
    }
}

// MARK: - Bucket list

struct BucketListItem: Codable, Identifiable {
    let id: String
    let countryCode: String?
    let countryName: String?
    let city: String?
    let priority: Int
    let reason: String?
    let idealSeason: String?
    let aiSummary: String?

    enum CodingKeys: String, CodingKey {
        case id, priority, reason
        case countryCode = "country_code"
        case countryName = "country_name"
        case city
        case idealSeason = "ideal_season"
        case aiSummary = "ai_summary"
    }
}

// MARK: - Stats

struct StatsResponse: Codable {
    let countriesVisited: Int
    let tripsCount: Int
    let nightsAway: Int
    let totalDistanceKm: Double
    let co2KgEstimate: Double
    let mostVisitedCountry: String?
    let mostVisitedCountryCode: String?
    let longestTripTitle: String?
    let longestTripDays: Int?

    enum CodingKeys: String, CodingKey {
        case countriesVisited = "countries_visited"
        case tripsCount = "trips_count"
        case nightsAway = "nights_away"
        case totalDistanceKm = "total_distance_km"
        case co2KgEstimate = "co2_kg_estimate"
        case mostVisitedCountry = "most_visited_country"
        case mostVisitedCountryCode = "most_visited_country_code"
        case longestTripTitle = "longest_trip_title"
        case longestTripDays = "longest_trip_days"
    }
}

struct TimelineTrip: Codable, Identifiable {
    let id: String
    let title: String
    let status: String
    let startDate: String?
    let endDate: String?
    let destinationCount: Int

    enum CodingKeys: String, CodingKey {
        case id, title, status
        case startDate = "start_date"
        case endDate = "end_date"
        case destinationCount = "destination_count"
    }
}

// MARK: - Transport

struct TransportLeg: Codable, Identifiable {
    let id: String
    let type: String
    let flightNumber: String?
    let airline: String?
    let originCity: String?
    let destCity: String?
    let originIata: String?
    let destIata: String?
    let departureAt: String?
    let arrivalAt: String?
    let durationMin: Int?
    let distanceKm: Double?
    let seatClass: String?

    enum CodingKeys: String, CodingKey {
        case id, type, airline
        case flightNumber = "flight_number"
        case originCity = "origin_city"
        case destCity = "dest_city"
        case originIata = "origin_iata"
        case destIata = "dest_iata"
        case departureAt = "departure_at"
        case arrivalAt = "arrival_at"
        case durationMin = "duration_min"
        case distanceKm = "distance_km"
        case seatClass = "seat_class"
    }
}
```

- [ ] **Step 2: Create `iOS/Atlas/API/APIClient.swift`**

```swift
import Foundation
import KeychainSwift

enum APIError: LocalizedError {
    case notAuthenticated
    case httpError(Int, String)
    case decodingError(Error)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not signed in. Please sign in to continue."
        case .httpError(let code, let body):
            return "Server error \(code): \(body.prefix(120))"
        case .decodingError(let err):
            return "Response parsing failed: \(err.localizedDescription)"
        case .networkError(let err):
            return "Network error: \(err.localizedDescription)"
        }
    }
}

@Observable
final class APIClient {
    var token: String?

    private let base: URL
    private let keychain = KeychainSwift()
    private let keychainKey = "atlas_jwt"
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        return d
    }()

    init(token: String? = nil) {
        self.base = Config.apiBase
        self.token = token ?? KeychainSwift().get("atlas_jwt")
    }

    func persistToken(_ token: String?) {
        self.token = token
        if let t = token {
            keychain.set(t, forKey: keychainKey)
        } else {
            keychain.delete(keychainKey)
        }
    }

    // MARK: - HTTP methods

    func get<T: Decodable>(_ path: String) async throws -> T {
        try await perform(makeRequest("GET", path: path))
    }

    func post<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T {
        var req = makeRequest("POST", path: path)
        req.httpBody = try JSONEncoder().encode(body)
        return try await perform(req)
    }

    func delete(_ path: String) async throws {
        let req = makeRequest("DELETE", path: path)
        let (_, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { return }
        if !(200..<300).contains(http.statusCode) {
            throw APIError.httpError(http.statusCode, "")
        }
    }

    // MARK: - Convenience API wrappers

    func trips(page: Int = 1, status: TripStatus? = nil) async throws -> TripListResponse {
        var path = "/api/v1/trips?page=\(page)&limit=20"
        if let s = status { path += "&status=\(s.rawValue)" }
        return try await get(path)
    }

    func trip(id: String) async throws -> Trip {
        try await get("/api/v1/trips/\(id)")
    }

    func destinations(tripId: String) async throws -> [Destination] {
        try await get("/api/v1/trips/\(tripId)/destinations")
    }

    func transportLegs(tripId: String) async throws -> [TransportLeg] {
        try await get("/api/v1/trips/\(tripId)/transport")
    }

    func mapCountries() async throws -> [MapCountry] {
        try await get("/api/v1/map/countries")
    }

    func mapCities() async throws -> [MapCity] {
        try await get("/api/v1/map/cities")
    }

    func mapArcs() async throws -> [MapArc] {
        try await get("/api/v1/map/arcs")
    }

    func bucketList() async throws -> [BucketListItem] {
        try await get("/api/v1/bucket-list")
    }

    func stats() async throws -> StatsResponse {
        try await get("/api/v1/stats")
    }

    func statsTimeline() async throws -> [TimelineTrip] {
        try await get("/api/v1/stats/timeline")
    }

    // MARK: - Private

    private func makeRequest(_ method: String, path: String) -> URLRequest {
        var req = URLRequest(url: base.appendingPathComponent(path))
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        req.timeoutInterval = 15
        return req
    }

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }
        guard let http = response as? HTTPURLResponse else {
            throw APIError.httpError(0, "No HTTP response")
        }
        if http.statusCode == 401 {
            throw APIError.notAuthenticated
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw APIError.httpError(http.statusCode, body)
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }
}
```

- [ ] **Step 3: Create `iOS/Atlas/Auth/AuthManager.swift`**

```swift
import Foundation
import ClerkSDK

@Observable
final class AuthManager {
    var isSignedIn: Bool = false
    var isLoading: Bool = true
    var error: String? = nil

    private(set) var api: APIClient = APIClient()

    /// Called at app launch to restore session from Keychain.
    func checkSession() async {
        defer { isLoading = false }
        // If we already have a stored token, treat as signed in.
        // The backend will reject it if expired.
        isSignedIn = api.token != nil
    }

    /// Sign in via Clerk using email + password.
    func signIn(email: String, password: String) async {
        error = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let signIn = try await Clerk.shared.client.signIn.create(
                strategy: .password(identifier: email, password: password)
            )
            guard signIn.status == .complete,
                  let token = try await Clerk.shared.session?.getToken() else {
                error = "Sign-in incomplete — check credentials."
                return
            }
            api.persistToken(token)
            isSignedIn = true
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Refresh the JWT from Clerk before API calls if needed.
    func refreshToken() async throws {
        guard let token = try await Clerk.shared.session?.getToken() else {
            throw APIError.notAuthenticated
        }
        api.persistToken(token)
    }

    func signOut() {
        Task {
            try? await Clerk.shared.signOut()
        }
        api.persistToken(nil)
        isSignedIn = false
    }
}
```

- [ ] **Step 4: Create `iOS/Atlas/Auth/SignInView.swift`**

```swift
import SwiftUI

struct SignInView: View {
    @Environment(AuthManager.self) private var auth
    @State private var email = ""
    @State private var password = ""
    @FocusState private var focused: Field?

    enum Field { case email, password }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Logo
            VStack(spacing: 8) {
                Text("A")
                    .font(.system(size: 48, weight: .bold, design: .serif))
                    .foregroundStyle(Color.atlasAccent)
                Text("Atlas")
                    .font(AtlasFont.display(28))
                    .foregroundStyle(Color.atlasText)
                Text("Travel Intelligence")
                    .font(AtlasFont.body(13))
                    .foregroundStyle(Color.atlasMuted)
            }
            .padding(.bottom, 48)

            // Form
            VStack(spacing: 12) {
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .focused($focused, equals: .email)
                    .padding()
                    .background(Color.atlasSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(focused == .email ? Color.atlasAccent : Color.atlasBorder, lineWidth: 1)
                    )
                    .foregroundStyle(Color.atlasText)

                SecureField("Password", text: $password)
                    .textContentType(.password)
                    .focused($focused, equals: .password)
                    .padding()
                    .background(Color.atlasSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(focused == .password ? Color.atlasAccent : Color.atlasBorder, lineWidth: 1)
                    )
                    .foregroundStyle(Color.atlasText)
            }
            .padding(.horizontal, 24)

            if let error = auth.error {
                ErrorBanner(message: error)
                    .padding(.top, 12)
            }

            Button {
                Task { await auth.signIn(email: email, password: password) }
            } label: {
                Group {
                    if auth.isLoading {
                        ProgressView().tint(Color.atlasBackground)
                    } else {
                        Text("Sign In")
                            .font(AtlasFont.body(15, weight: .semibold))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
            }
            .background(
                email.isEmpty || password.isEmpty || auth.isLoading
                    ? Color.atlasBorder
                    : Color.atlasAccent
            )
            .foregroundStyle(Color.atlasBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .disabled(email.isEmpty || password.isEmpty || auth.isLoading)

            Spacer()
            Spacer()
        }
        .background(Color.atlasBackground.ignoresSafeArea())
        .onSubmit {
            if focused == .email { focused = .password }
            else if !email.isEmpty && !password.isEmpty {
                Task { await auth.signIn(email: email, password: password) }
            }
        }
    }
}
```

- [ ] **Step 5: Commit**

```bash
cd /home/zach/Atlas && git add iOS/Atlas/Auth iOS/Atlas/API
git commit -m "feat(ios): auth manager, Clerk sign-in, API client, Codable models"
```

---

### Task 3: Map feature

**Files:**
- Create: `iOS/Atlas/Features/Map/MapViewModel.swift`
- Create: `iOS/Atlas/Features/Map/MapView.swift`

- [ ] **Step 1: Create `iOS/Atlas/Features/Map/MapViewModel.swift`**

```swift
import Foundation
import MapKit

@Observable
final class MapViewModel {
    var countries: [MapCountry] = []
    var cities: [MapCity] = []
    var arcs: [MapArc] = []
    var isLoading = false
    var error: String? = nil

    func load(api: APIClient) async {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            async let c = api.mapCountries()
            async let ci = api.mapCities()
            async let a = api.mapArcs()
            (countries, cities, arcs) = try await (c, ci, a)
        } catch {
            self.error = error.localizedDescription
        }
    }
}

extension MapCity {
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

extension MapArc {
    var originCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: originLat, longitude: originLng)
    }
    var destCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: destLat, longitude: destLng)
    }
}
```

- [ ] **Step 2: Create `iOS/Atlas/Features/Map/MapView.swift`**

```swift
import SwiftUI
import MapKit

struct MapView: View {
    @Environment(AuthManager.self) private var auth
    @State private var vm = MapViewModel()
    @State private var position: MapCameraPosition = .automatic
    @State private var selectedCity: MapCity? = nil

    var body: some View {
        ZStack(alignment: .top) {
            Map(position: $position) {
                // Visited city markers
                ForEach(vm.cities) { city in
                    Annotation(city.city, coordinate: city.coordinate) {
                        Button {
                            selectedCity = city
                        } label: {
                            Circle()
                                .fill(Color.atlasAccentCool)
                                .frame(width: 10, height: 10)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.8), lineWidth: 1.5)
                                )
                                .shadow(color: Color.atlasAccentCool.opacity(0.6), radius: 4)
                        }
                    }
                }

                // Flight arcs as polylines
                ForEach(vm.arcs) { arc in
                    let coords = greatCircleCoords(
                        from: arc.originCoordinate,
                        to: arc.destCoordinate
                    )
                    MapPolyline(coordinates: coords)
                        .stroke(Color.atlasAccent.opacity(0.5), lineWidth: 1.5)
                }
            }
            .mapStyle(.imagery(elevation: .realistic))
            .mapControls {
                MapCompass()
                MapScaleView()
            }
            .ignoresSafeArea()

            // Header overlay
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Atlas")
                            .font(AtlasFont.display(22))
                            .foregroundStyle(Color.atlasAccent)
                        if !vm.isLoading {
                            Text("\(vm.countries.count) countries · \(vm.cities.count) cities")
                                .font(AtlasFont.mono(12))
                                .foregroundStyle(Color.atlasText.opacity(0.8))
                        }
                    }
                    Spacer()
                    if vm.isLoading {
                        ProgressView().tint(.atlasAccent)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
            }

            if let err = vm.error {
                ErrorBanner(message: err) {
                    Task { await vm.load(api: auth.api) }
                }
                .padding(.top, 60)
            }
        }
        .sheet(item: $selectedCity) { city in
            CityDetailSheet(city: city)
                .presentationDetents([.medium])
                .presentationBackground(Color.atlasSurface)
        }
        .task {
            await vm.load(api: auth.api)
        }
    }

    /// Generate intermediate coordinates for a great-circle arc.
    private func greatCircleCoords(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D,
        steps: Int = 60
    ) -> [CLLocationCoordinate2D] {
        (0...steps).map { i in
            let t = Double(i) / Double(steps)
            let lat = from.latitude + (to.latitude - from.latitude) * t
            let lng = from.longitude + (to.longitude - from.longitude) * t
            return CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }
    }
}

struct CityDetailSheet: View {
    let city: MapCity

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Color.atlasAccentCool)
                VStack(alignment: .leading, spacing: 2) {
                    Text(city.city)
                        .font(AtlasFont.display(20))
                        .foregroundStyle(Color.atlasText)
                    Text(city.countryName)
                        .font(AtlasFont.body(14))
                        .foregroundStyle(Color.atlasMuted)
                }
            }

            HStack(spacing: 6) {
                Text(city.countryCode)
                    .font(AtlasFont.mono(12))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.atlasBorder)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .foregroundStyle(Color.atlasText)

                Text(String(format: "%.4f, %.4f", city.latitude, city.longitude))
                    .font(AtlasFont.mono(11))
                    .foregroundStyle(Color.atlasMuted)
            }

            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
```

- [ ] **Step 3: Commit**

```bash
cd /home/zach/Atlas && git add iOS/Atlas/Features/Map/
git commit -m "feat(ios): map view with city markers and flight arc polylines"
```

---

### Task 4: Trips feature

**Files:**
- Create: `iOS/Atlas/Features/Trips/TripListViewModel.swift`
- Create: `iOS/Atlas/Features/Trips/TripListView.swift`
- Create: `iOS/Atlas/Features/Trips/TripDetailViewModel.swift`
- Create: `iOS/Atlas/Features/Trips/TripDetailView.swift`

- [ ] **Step 1: Create `iOS/Atlas/Features/Trips/TripListViewModel.swift`**

```swift
import Foundation

@Observable
final class TripListViewModel {
    var trips: [Trip] = []
    var isLoading = false
    var error: String? = nil
    var selectedStatus: TripStatus? = nil
    var searchText = ""
    private var hasMore = true
    private var currentPage = 1

    var filtered: [Trip] {
        guard !searchText.isEmpty else { return trips }
        let q = searchText.lowercased()
        return trips.filter { $0.title.lowercased().contains(q) }
    }

    func load(api: APIClient, reset: Bool = false) async {
        guard !isLoading else { return }
        if reset {
            trips = []
            currentPage = 1
            hasMore = true
        }
        guard hasMore else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            let response = try await api.trips(page: currentPage, status: selectedStatus)
            if reset { trips = response.items }
            else { trips.append(contentsOf: response.items) }
            hasMore = trips.count < response.total
            currentPage += 1
        } catch {
            self.error = error.localizedDescription
        }
    }

    func changeFilter(to status: TripStatus?, api: APIClient) async {
        selectedStatus = status
        await load(api: api, reset: true)
    }
}
```

- [ ] **Step 2: Create `iOS/Atlas/Features/Trips/TripListView.swift`**

```swift
import SwiftUI

struct TripListView: View {
    @Environment(AuthManager.self) private var auth
    @State private var vm = TripListViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.atlasBackground.ignoresSafeArea()

                if vm.isLoading && vm.trips.isEmpty {
                    List { ForEach(0..<6, id: \.self) { _ in SkeletonRow() } }
                        .listStyle(.insetGrouped)
                        .scrollContentBackground(.hidden)
                } else if let err = vm.error, vm.trips.isEmpty {
                    ErrorBanner(message: err) {
                        Task { await vm.load(api: auth.api, reset: true) }
                    }
                } else {
                    List {
                        ForEach(vm.filtered) { trip in
                            NavigationLink(value: trip) {
                                TripRow(trip: trip)
                            }
                            .listRowBackground(Color.atlasSurface)
                            .listRowSeparatorTint(Color.atlasBorder)
                            .onAppear {
                                if trip.id == vm.filtered.last?.id {
                                    Task { await vm.load(api: auth.api) }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .searchable(text: $vm.searchText, prompt: "Search trips")
                    .refreshable { await vm.load(api: auth.api, reset: true) }
                }
            }
            .navigationTitle("Trips")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    StatusFilterMenu(selected: vm.selectedStatus) { status in
                        Task { await vm.changeFilter(to: status, api: auth.api) }
                    }
                }
            }
            .navigationDestination(for: Trip.self) { trip in
                TripDetailView(tripId: trip.id, tripTitle: trip.title)
            }
        }
        .task { await vm.load(api: auth.api, reset: true) }
    }
}

struct TripRow: View {
    let trip: Trip

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: trip.status.systemImage)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(iconColor)
                .frame(width: 32, height: 32)
                .background(iconColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                Text(trip.title)
                    .font(AtlasFont.body(15, weight: .medium))
                    .foregroundStyle(Color.atlasText)
                HStack(spacing: 8) {
                    Text(trip.status.label)
                        .font(AtlasFont.body(12))
                        .foregroundStyle(Color.atlasMuted)
                    if let date = trip.startDate {
                        Text(date.prefix(4))
                            .font(AtlasFont.mono(11))
                            .foregroundStyle(Color.atlasMuted)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var iconColor: Color {
        switch trip.status {
        case .past:    return Color.atlasAccentCool
        case .active:  return .green
        case .planned: return Color.atlasAccent
        case .dream:   return .purple
        }
    }
}

struct StatusFilterMenu: View {
    let selected: TripStatus?
    let onSelect: (TripStatus?) -> Void

    var body: some View {
        Menu {
            Button("All") { onSelect(nil) }
            Divider()
            ForEach(TripStatus.allCases, id: \.self) { status in
                Button {
                    onSelect(status)
                } label: {
                    Label(status.label, systemImage: status.systemImage)
                }
            }
        } label: {
            Image(systemName: selected == nil ? "line.3.horizontal.decrease" : "line.3.horizontal.decrease.circle.fill")
                .foregroundStyle(Color.atlasAccent)
        }
    }
}
```

- [ ] **Step 3: Create `iOS/Atlas/Features/Trips/TripDetailViewModel.swift`**

```swift
import Foundation

@Observable
final class TripDetailViewModel {
    var destinations: [Destination] = []
    var transport: [TransportLeg] = []
    var isLoading = false
    var error: String? = nil

    func load(tripId: String, api: APIClient) async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            async let d = api.destinations(tripId: tripId)
            async let t = api.transportLegs(tripId: tripId)
            (destinations, transport) = try await (d, t)
        } catch {
            self.error = error.localizedDescription
        }
    }
}
```

- [ ] **Step 4: Create `iOS/Atlas/Features/Trips/TripDetailView.swift`**

```swift
import SwiftUI

struct TripDetailView: View {
    let tripId: String
    let tripTitle: String

    @Environment(AuthManager.self) private var auth
    @State private var vm = TripDetailViewModel()

    var body: some View {
        ZStack {
            Color.atlasBackground.ignoresSafeArea()

            if vm.isLoading {
                LoadingView()
            } else if let err = vm.error {
                ErrorBanner(message: err) {
                    Task { await vm.load(tripId: tripId, api: auth.api) }
                }
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        // Destinations
                        if !vm.destinations.isEmpty {
                            SectionHeader(title: "Destinations", count: vm.destinations.count)
                                .padding(.horizontal, 16)

                            VStack(spacing: 1) {
                                ForEach(vm.destinations) { dest in
                                    DestinationRow(destination: dest)
                                }
                            }
                            .atlasCard()
                            .padding(.horizontal, 16)
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

                        if vm.destinations.isEmpty && vm.transport.isEmpty {
                            Text("No destinations or transport logged yet.")
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
        .navigationTitle(tripTitle)
        .navigationBarTitleDisplayMode(.large)
        .task { await vm.load(tripId: tripId, api: auth.api) }
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
```

- [ ] **Step 5: Commit**

```bash
cd /home/zach/Atlas && git add iOS/Atlas/Features/Trips/
git commit -m "feat(ios): trips list with pagination + filter + detail view with destinations"
```

---

### Task 5: Plan + Stats features

**Files:**
- Create: `iOS/Atlas/Features/Plan/PlanViewModel.swift`
- Create: `iOS/Atlas/Features/Plan/PlanView.swift`
- Create: `iOS/Atlas/Features/Stats/StatsViewModel.swift`
- Create: `iOS/Atlas/Features/Stats/StatsView.swift`

- [ ] **Step 1: Create `iOS/Atlas/Features/Plan/PlanViewModel.swift`**

```swift
import Foundation

@Observable
final class PlanViewModel {
    var plannedTrips: [Trip] = []
    var bucketList: [BucketListItem] = []
    var isLoading = false
    var error: String? = nil

    func load(api: APIClient) async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            async let tripResponse = api.trips(status: nil)
            async let bucket = api.bucketList()
            let (trips, bl) = try await (tripResponse, bucket)
            plannedTrips = trips.items.filter { $0.status == .planned || $0.status == .dream }
            bucketList = bl
        } catch {
            self.error = error.localizedDescription
        }
    }
}
```

- [ ] **Step 2: Create `iOS/Atlas/Features/Plan/PlanView.swift`**

```swift
import SwiftUI

struct PlanView: View {
    @Environment(AuthManager.self) private var auth
    @State private var vm = PlanViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.atlasBackground.ignoresSafeArea()

                if vm.isLoading {
                    LoadingView()
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 24) {
                            if let err = vm.error {
                                ErrorBanner(message: err) {
                                    Task { await vm.load(api: auth.api) }
                                }
                            }

                            // Future Trips
                            VStack(alignment: .leading, spacing: 12) {
                                SectionHeader(title: "Future Trips", count: vm.plannedTrips.count)
                                    .padding(.horizontal, 16)

                                if vm.plannedTrips.isEmpty {
                                    emptyState(text: "No planned or dream trips yet.")
                                } else {
                                    VStack(spacing: 1) {
                                        ForEach(vm.plannedTrips) { trip in
                                            PlannedTripRow(trip: trip)
                                        }
                                    }
                                    .atlasCard()
                                    .padding(.horizontal, 16)
                                }
                            }

                            // Bucket List
                            VStack(alignment: .leading, spacing: 12) {
                                SectionHeader(title: "Bucket List", count: vm.bucketList.count)
                                    .padding(.horizontal, 16)

                                if vm.bucketList.isEmpty {
                                    emptyState(text: "Add destinations you want to visit.")
                                } else {
                                    VStack(spacing: 1) {
                                        ForEach(vm.bucketList) { item in
                                            BucketListRow(item: item)
                                        }
                                    }
                                    .atlasCard()
                                    .padding(.horizontal, 16)
                                }
                            }
                        }
                        .padding(.vertical, 16)
                    }
                    .refreshable { await vm.load(api: auth.api) }
                }
            }
            .navigationTitle("Plan")
            .navigationBarTitleDisplayMode(.large)
        }
        .task { await vm.load(api: auth.api) }
    }

    private func emptyState(text: String) -> some View {
        Text(text)
            .font(AtlasFont.body(13))
            .foregroundStyle(Color.atlasMuted)
            .multilineTextAlignment(.center)
            .padding(24)
            .frame(maxWidth: .infinity)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.atlasBorder.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [6]))
            )
            .padding(.horizontal, 16)
    }
}

struct PlannedTripRow: View {
    let trip: Trip

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: trip.status == .dream ? "sparkles" : "calendar")
                .font(.system(size: 16))
                .foregroundStyle(Color.atlasAccent)
                .frame(width: 32, height: 32)
                .background(Color.atlasAccent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                Text(trip.title)
                    .font(AtlasFont.body(15, weight: .medium))
                    .foregroundStyle(Color.atlasText)
                Text(trip.status.label)
                    .font(AtlasFont.body(12))
                    .foregroundStyle(Color.atlasMuted)
            }

            Spacer()

            if let date = trip.startDate {
                Text(date.prefix(10))
                    .font(AtlasFont.mono(11))
                    .foregroundStyle(Color.atlasMuted)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

struct BucketListRow: View {
    let item: BucketListItem

    private let priorityColors: [Int: Color] = [
        5: .yellow, 4: Color.atlasAccent, 3: Color.atlasText, 2: Color.atlasMuted, 1: Color.atlasMuted,
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "globe")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.atlasAccent)

                Text(locationLabel)
                    .font(AtlasFont.body(15, weight: .medium))
                    .foregroundStyle(Color.atlasText)

                Spacer()

                priorityStars
            }

            if let reason = item.reason {
                Text(reason)
                    .font(AtlasFont.body(12))
                    .foregroundStyle(Color.atlasMuted)
                    .lineLimit(2)
            }

            if let summary = item.aiSummary {
                Text(summary)
                    .font(AtlasFont.body(12))
                    .foregroundStyle(Color.atlasText.opacity(0.7))
                    .lineLimit(3)
                    .padding(.leading, 8)
                    .overlay(
                        Rectangle()
                            .fill(Color.atlasAccent.opacity(0.4))
                            .frame(width: 2),
                        alignment: .leading
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var locationLabel: String {
        if let city = item.city, let country = item.countryName {
            return "\(city), \(country)"
        }
        return item.countryName ?? item.countryCode ?? "Unknown"
    }

    private var priorityStars: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { n in
                Image(systemName: n <= item.priority ? "star.fill" : "star")
                    .font(.system(size: 8))
                    .foregroundStyle(n <= item.priority ? (priorityColors[item.priority] ?? .atlasAccent) : Color.atlasBorder)
            }
        }
    }
}
```

- [ ] **Step 3: Create `iOS/Atlas/Features/Stats/StatsViewModel.swift`**

```swift
import Foundation

@Observable
final class StatsViewModel {
    var stats: StatsResponse? = nil
    var timeline: [TimelineTrip] = []
    var isLoading = false
    var error: String? = nil

    func load(api: APIClient) async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            async let s = api.stats()
            async let t = api.statsTimeline()
            (stats, timeline) = try await (s, t)
        } catch {
            self.error = error.localizedDescription
        }
    }
}
```

- [ ] **Step 4: Create `iOS/Atlas/Features/Stats/StatsView.swift`**

```swift
import SwiftUI

struct StatsView: View {
    @Environment(AuthManager.self) private var auth
    @State private var vm = StatsViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.atlasBackground.ignoresSafeArea()

                if vm.isLoading {
                    LoadingView()
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 24) {
                            if let err = vm.error {
                                ErrorBanner(message: err) {
                                    Task { await vm.load(api: auth.api) }
                                }
                            }

                            if let stats = vm.stats {
                                statGrid(stats: stats)
                            }

                            timelineSection
                        }
                        .padding(.vertical, 16)
                    }
                    .refreshable { await vm.load(api: auth.api) }
                }
            }
            .navigationTitle("Stats")
            .navigationBarTitleDisplayMode(.large)
        }
        .task { await vm.load(api: auth.api) }
    }

    @ViewBuilder
    private func statGrid(stats: StatsResponse) -> some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            spacing: 12
        ) {
            StatCard(icon: "globe", label: "Countries", value: "\(stats.countriesVisited)")
            StatCard(icon: "mappin.circle", label: "Trips", value: "\(stats.tripsCount)")
            StatCard(icon: "moon.stars", label: "Nights Away", value: "\(stats.nightsAway)")
            StatCard(icon: "airplane", label: "Distance",
                     value: stats.totalDistanceKm >= 1000
                         ? String(format: "%.1fk km", stats.totalDistanceKm / 1000)
                         : String(format: "%.0f km", stats.totalDistanceKm))
            StatCard(icon: "leaf", label: "CO₂",
                     value: String(format: "%.1ft", stats.co2KgEstimate / 1000),
                     sub: "economy class avg")
            if let country = stats.mostVisitedCountry {
                StatCard(icon: "star", label: "Most Visited", value: country,
                         sub: stats.mostVisitedCountryCode)
            }
            if let days = stats.longestTripDays, let title = stats.longestTripTitle {
                StatCard(icon: "clock", label: "Longest Trip", value: "\(days) days", sub: title)
            }
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Trip Timeline", count: vm.timeline.count)
                .padding(.horizontal, 16)

            if vm.timeline.isEmpty {
                Text("No past trips to show.")
                    .font(AtlasFont.body(13))
                    .foregroundStyle(Color.atlasMuted)
                    .padding(.horizontal, 16)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(vm.timeline) { trip in
                            TimelineCard(trip: trip)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }
}

struct StatCard: View {
    let icon: String
    let label: String
    let value: String
    var sub: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.atlasAccent)
                Text(label.uppercased())
                    .font(AtlasFont.body(10, weight: .semibold))
                    .foregroundStyle(Color.atlasMuted)
                    .tracking(0.8)
            }
            Text(value)
                .font(AtlasFont.mono(22, weight: .semibold))
                .foregroundStyle(Color.atlasText)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            if let sub {
                Text(sub)
                    .font(AtlasFont.body(11))
                    .foregroundStyle(Color.atlasMuted)
                    .lineLimit(1)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .atlasCard()
    }
}

struct TimelineCard: View {
    let trip: TimelineTrip

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(trip.startDate.map { String($0.prefix(4)) } ?? "—")
                .font(AtlasFont.mono(11))
                .foregroundStyle(Color.atlasAccent)
            Text(trip.title)
                .font(AtlasFont.body(13, weight: .medium))
                .foregroundStyle(Color.atlasText)
                .lineLimit(2)
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: "mappin")
                    .font(.system(size: 10))
                Text("\(trip.destinationCount)")
                    .font(AtlasFont.mono(11))
            }
            .foregroundStyle(Color.atlasMuted)
        }
        .padding(14)
        .frame(width: 140, height: 120)
        .atlasCard()
    }
}
```

- [ ] **Step 5: Commit**

```bash
cd /home/zach/Atlas && git add iOS/Atlas/Features/Plan/ iOS/Atlas/Features/Stats/
git commit -m "feat(ios): plan page (future trips + bucket list) and stats page with timeline"
```

---

## Build + Run Instructions (on your Mac)

1. Install xcodegen if needed: `brew install xcodegen`
2. `cd iOS && xcodegen generate`
3. Open `Atlas.xcodeproj` in Xcode 15
4. In `Config.swift`, set your NUC's IP address
5. In `Config.swift`, paste your Clerk publishable key
6. In Xcode, select your development team (Xcode → Target → Signing & Capabilities)
7. Build and run on simulator or device

**Clerk iOS SDK note:** The `ClerkSDK` Swift package at `https://github.com/clerk/clerk-ios` is version-locked at `from: "2.0.0"` in `project.yml`. If the current release has breaking API changes, check the [Clerk iOS docs](https://clerk.com/docs/quickstarts/ios) and adjust `AuthManager.swift` accordingly — the sign-in call and token extraction are the two integration points.

## Completion Checklist

- [ ] `xcodegen generate` succeeds without errors
- [ ] Project compiles in Xcode (0 errors)
- [ ] Sign-in screen appears on first launch
- [ ] Entering Clerk credentials signs in and shows tab bar
- [ ] Map tab loads city markers (requires NUC running + data)
- [ ] Trips tab lists trips with filter menu
- [ ] Tapping a trip shows destinations + transport
- [ ] Plan tab shows future trips + bucket list with AI summaries
- [ ] Stats tab shows stat cards + horizontal timeline scroll
- [ ] Pull-to-refresh works on all list screens
