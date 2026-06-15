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

    /// Supplies a fresh, unexpired token per request (Clerk tokens live ~60s).
    /// Set by AuthManager to call `Clerk.shared.session?.getToken()`.
    @ObservationIgnored var tokenProvider: (() async -> String?)?

    private let base: URL
    private let keychain = KeychainSwift()
    private let keychainKey = "atlas_jwt"
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        return d
    }()

    init(token: String? = nil) {
        self.base = Config.apiBase
        let keychain = KeychainSwift()
        self.token = token ?? keychain.get("atlas_jwt")
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
        try await perform(await makeRequest("GET", path: path))
    }

    func post<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T {
        var req = await makeRequest("POST", path: path)
        req.httpBody = try JSONEncoder().encode(body)
        return try await perform(req)
    }

    func put<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T {
        var req = await makeRequest("PUT", path: path)
        req.httpBody = try JSONEncoder().encode(body)
        return try await perform(req)
    }

    func delete(_ path: String) async throws {
        let req = await makeRequest("DELETE", path: path)
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

    // MARK: - Skywatch

    func fetchOverhead(lat: Double, lon: Double, radiusKm: Double? = nil) async throws -> [OverheadAircraft] {
        var path = "/api/v1/skywatch/overhead?lat=\(lat)&lon=\(lon)"
        if let radiusKm {
            path += "&radius=\(radiusKm)"
        }
        let response: OverheadResponse = try await get(path)
        return response.aircraft
    }

    func getSkywatchPreferences() async throws -> SkywatchPreference {
        try await get("/api/v1/skywatch/preferences")
    }

    func updateSkywatchPreferences(_ update: SkywatchPreferenceUpdate) async throws -> SkywatchPreference {
        try await put("/api/v1/skywatch/preferences", body: update)
    }

    /// Registers this device's APNs token with the backend and persists the returned device id.
    @discardableResult
    func registerDevice(apnsToken: String) async throws -> SkywatchDevice {
        let body = DeviceCreate(apnsToken: apnsToken, platform: "ios")
        let device: SkywatchDevice = try await post("/api/v1/skywatch/devices", body: body)
        UserDefaults.standard.set(device.id, forKey: Self.deviceIdKey)
        return device
    }

    /// Posts a significant-location-change update, associating it with the persisted device id if available.
    @discardableResult
    func updateLocation(lat: Double, lng: Double, deviceId: String? = nil) async throws -> SkywatchDevice {
        let resolvedDeviceId = deviceId ?? UserDefaults.standard.string(forKey: Self.deviceIdKey)
        let body = LocationUpdate(lat: lat, lng: lng, deviceId: resolvedDeviceId)
        let device: SkywatchDevice = try await post("/api/v1/skywatch/location", body: body)
        UserDefaults.standard.set(device.id, forKey: Self.deviceIdKey)
        return device
    }

    static let deviceIdKey = "atlas_skywatch_device_id"

    // MARK: - Private

    /// Fetches a fresh token (refreshing via Clerk if needed) and caches it.
    private func freshToken() async -> String? {
        if let provider = tokenProvider, let t = await provider() {
            persistToken(t)
            return t
        }
        return token
    }

    private func makeRequest(_ method: String, path: String) async -> URLRequest {
        let url = URL(string: path, relativeTo: base)?.absoluteURL ?? base
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let t = await freshToken() {
            req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization")
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
