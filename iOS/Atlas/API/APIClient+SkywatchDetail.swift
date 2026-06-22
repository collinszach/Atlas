import Foundation

extension APIClient {
    /// Fetches enriched aircraft detail from `GET /api/v1/skywatch/aircraft/{hex}`.
    /// Falls back gracefully if the endpoint 404s — callers should catch `APIError.httpError(404, _)`.
    func fetchAircraftDetail(hex: String, lat: Double, lon: Double) async throws -> OverheadAircraft {
        let path = "/api/v1/skywatch/aircraft/\(hex)?lat=\(lat)&lon=\(lon)"
        return try await get(path)
    }
}
