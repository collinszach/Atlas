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
    /// Set by AuthManager to call `Clerk.shared.session?.getToken()`. The flag asks
    /// it to bypass Clerk's token cache, which is what makes a 401 retry meaningful:
    /// without it a retry re-sends the same cached token and 401s again.
    @ObservationIgnored var tokenProvider: ((_ forceRefresh: Bool) async -> String?)?

    private let base: URL
    private let session: URLSession
    private let keychain = KeychainSwift()
    private let keychainKey = "atlas_jwt"
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        return d
    }()

    /// `session` is injectable so tests can stub transport via `URLProtocol`.
    init(token: String? = nil, session: URLSession = .shared) {
        self.base = Config.apiBase
        self.session = session
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
        let data = try await send { await self.makeRequest("GET", path: path, forceRefresh: $0) }
        return try decode(data)
    }

    func post<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T {
        let encoded = try JSONEncoder().encode(body)
        let data = try await send {
            var req = await self.makeRequest("POST", path: path, forceRefresh: $0)
            req.httpBody = encoded
            return req
        }
        return try decode(data)
    }

    func put<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T {
        let encoded = try JSONEncoder().encode(body)
        let data = try await send {
            var req = await self.makeRequest("PUT", path: path, forceRefresh: $0)
            req.httpBody = encoded
            return req
        }
        return try decode(data)
    }

    func delete(_ path: String) async throws {
        _ = try await send { await self.makeRequest("DELETE", path: path, forceRefresh: $0) }
    }

    // MARK: - Convenience API wrappers

    /// The user's flight logbook, newest-first by departure.
    func flights() async throws -> [TransportLeg] {
        let legs: [TransportLeg] = try await get("/api/v1/flights")
        return legs.sorted { ($0.departureAt ?? "") > ($1.departureAt ?? "") }
    }

    func flight(id: String) async throws -> TransportLeg {
        try await get("/api/v1/flights/\(id)")
    }

    func mapArcs() async throws -> [MapArc] {
        try await get("/api/v1/map/arcs")
    }

    func stats() async throws -> StatsResponse {
        try await get("/api/v1/stats")
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

    /// Aircraft projected to enter the radius within `horizonMinutes`, soonest first.
    func fetchForecast(
        lat: Double,
        lon: Double,
        horizonMinutes: Int = 30,
        notableOnly: Bool = true
    ) async throws -> [ForecastAircraft] {
        let path = "/api/v1/skywatch/forecast?lat=\(lat)&lon=\(lon)"
            + "&horizon_minutes=\(horizonMinutes)&notable_only=\(notableOnly)"
        let response: ForecastResponse = try await get(path)
        return response.aircraft
    }

    func getSkywatchPreferences() async throws -> SkywatchPreference {
        try await get("/api/v1/skywatch/preferences")
    }

    /// Recent fired alerts (most recent first) — the history behind push notifications.
    func listAlerts(limit: Int = 50) async throws -> [AircraftAlert] {
        try await get("/api/v1/skywatch/alerts?limit=\(limit)")
    }

    /// Departures board for an airport (by IATA code). Empty `flights` with
    /// `configured == false` means no schedule API key is set server-side —
    /// callers should fall back to a live-derived view, not show a dead end.
    func airportDepartures(iata: String) async throws -> AirportSchedule {
        try await get("/api/v1/skywatch/airports/\(iata)/departures")
    }

    func airportArrivals(iata: String) async throws -> AirportSchedule {
        try await get("/api/v1/skywatch/airports/\(iata)/arrivals")
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

    func listPhotos(flightId: String) async throws -> [Photo] {
        let response: PhotoListResponse = try await get("/api/v1/flights/\(flightId)/photos")
        return response.items
    }

    func uploadPhoto(
        flightId: String,
        data: Data,
        filename: String,
        mimeType: String,
        caption: String? = nil
    ) async throws -> Photo {
        let boundary = UUID().uuidString
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
        let payload = body
        let responseData = try await send {
            var req = await self.makeRequest(
                "POST", path: "/api/v1/flights/\(flightId)/photos/upload", forceRefresh: $0
            )
            req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            req.timeoutInterval = 120
            req.httpBody = payload
            return req
        }
        return try decode(responseData)
    }

    func deletePhoto(photoId: String) async throws {
        try await delete("/api/v1/photos/\(photoId)")
    }

    func setCoverPhoto(photoId: String) async throws {
        try await postVoid("/api/v1/photos/\(photoId)/set-cover")
    }

    // MARK: - Flight write operations

    func createFlight(body: TransportCreate) async throws -> TransportLeg {
        try await post("/api/v1/flights", body: body)
    }

    func updateFlight(id: String, body: TransportCreate) async throws -> TransportLeg {
        try await put("/api/v1/flights/\(id)", body: body)
    }

    func deleteFlight(id: String) async throws {
        try await delete("/api/v1/flights/\(id)")
    }

    func enrichFlight(flightNumber: String, date: String) async throws -> FlightEnrichResponse {
        try await post(
            "/api/v1/transport/enrich-flight",
            body: FlightEnrichRequest(flightNumber: flightNumber, date: date)
        )
    }

    // MARK: - Private

    /// Fetches a token and caches it. `forceRefresh` asks the provider to bypass
    /// Clerk's cache; see `tokenProvider`.
    private func freshToken(forceRefresh: Bool = false) async -> String? {
        if let provider = tokenProvider, let t = await provider(forceRefresh) {
            persistToken(t)
            return t
        }
        return token
    }

    private func makeRequest(
        _ method: String,
        path: String,
        forceRefresh: Bool = false
    ) async -> URLRequest {
        let url = URL(string: path, relativeTo: base)?.absoluteURL ?? base
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let t = await freshToken(forceRefresh: forceRefresh) {
            req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization")
        }
        req.timeoutInterval = 15
        return req
    }

    /// The one place a request is sent and its status read.
    ///
    /// Clerk session tokens live about 60 seconds, so one expiring between being
    /// minted and being validated is routine rather than exceptional. On a 401 this
    /// rebuilds the request with a force-refreshed token and sends it once more;
    /// `makeReq` takes the flag so the retry carries the new Authorization header.
    /// A second 401 is a real authentication failure and surfaces as such.
    ///
    /// Retrying only on 401, and only once, is deliberate: anything else risks
    /// replaying a non-idempotent write (a logged flight, a photo upload) against a
    /// server that already accepted it.
    private func send(_ makeReq: @escaping (Bool) async -> URLRequest) async throws -> Data {
        var (data, http) = try await roundTrip(makeReq(false))
        if http.statusCode == 401 {
            (data, http) = try await roundTrip(makeReq(true))
            if http.statusCode == 401 { throw APIError.notAuthenticated }
        }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.httpError(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        return data
    }

    private func roundTrip(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }
        guard let http = response as? HTTPURLResponse else {
            throw APIError.httpError(0, "No HTTP response")
        }
        return (data, http)
    }

    private func decode<T: Decodable>(_ data: Data) throws -> T {
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    private func postVoid(_ path: String) async throws {
        _ = try await send {
            var req = await self.makeRequest("POST", path: path, forceRefresh: $0)
            req.httpBody = "{}".data(using: .utf8)
            return req
        }
    }
}

private extension Data {
    mutating func appendString(_ string: String) {
        if let d = string.data(using: .utf8) { append(d) }
    }
}
