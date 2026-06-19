import Foundation

extension APIClient {
    /// Search aircraft by flight number, callsign, registration, hex, type, or squawk.
    func searchAircraft(query: String) async throws -> [OverheadAircraft] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let resp: OverheadResponse = try await get("/api/v1/skywatch/search?q=\(q)")
        return resp.aircraft
    }
}
