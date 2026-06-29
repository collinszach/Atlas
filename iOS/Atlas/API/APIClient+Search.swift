import Foundation

extension APIClient {
    /// Search aircraft by flight number, callsign, registration, hex, type, or squawk.
    func searchAircraft(query: String) async throws -> [OverheadAircraft] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let resp: OverheadResponse = try await get("/api/v1/skywatch/search?q=\(q)")
        return resp.aircraft
    }

    /// All currently-flying aircraft of a given ICAO type code.
    /// Reuses `GET /skywatch/search?q=<type>` (the backend routes non-hex/non-squawk
    /// queries to its `/type/{q}` lookup) and narrows to exact type matches.
    func searchAircraftType(_ typeCode: String) async throws -> [OverheadAircraft] {
        let upper = typeCode.uppercased()
        let results = try await searchAircraft(query: typeCode)
        let exact = results.filter { ($0.type ?? "").uppercased() == upper }
        return exact.isEmpty ? results : exact
    }
}
