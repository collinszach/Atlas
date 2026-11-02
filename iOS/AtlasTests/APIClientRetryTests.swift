import XCTest
@testable import Atlas

/// Transport stub: answers each request from a queued script and records what it saw,
/// so a test can assert both how many round trips happened and which token each carried.
final class StubURLProtocol: URLProtocol {
    struct Exchange {
        let status: Int
        let body: Data
    }

    nonisolated(unsafe) static var script: [Exchange] = []
    nonisolated(unsafe) static var seenAuthHeaders: [String?] = []

    static func reset() {
        script = []
        seenAuthHeaders = []
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.seenAuthHeaders.append(request.value(forHTTPHeaderField: "Authorization"))
        let exchange = Self.script.isEmpty
            ? Exchange(status: 500, body: Data("stub exhausted".utf8))
            : Self.script.removeFirst()
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: exchange.status,
            httpVersion: "HTTP/1.1",
            headerFields: nil
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: exchange.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

final class APIClientRetryTests: XCTestCase {
    /// Every non-optional field of StatsResponse, so a decode failure cannot be
    /// mistaken for a retry failure.
    private static let statsJSON = #"""
    {"flights_count": 3, "total_distance_km": 42, "co2_kg_estimate": 7.5}
    """#

    private func makeClient() -> APIClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return APIClient(token: "stale", session: URLSession(configuration: config))
    }

    override func setUp() {
        super.setUp()
        StubURLProtocol.reset()
    }

    override func tearDown() {
        StubURLProtocol.reset()
        super.tearDown()
    }

    /// A 401 is retried once with a force-refreshed token, and the caller sees the
    /// successful second response rather than an error.
    func testRetriesOnceWithRefreshedTokenAfter401() async throws {
        StubURLProtocol.script = [
            .init(status: 401, body: Data("expired".utf8)),
            .init(status: 200, body: Data(Self.statsJSON.utf8)),
        ]
        let client = makeClient()
        var forceRefreshCalls: [Bool] = []
        client.tokenProvider = { force in
            forceRefreshCalls.append(force)
            return force ? "refreshed" : "stale"
        }

        let stats: StatsResponse = try await client.get("/api/v1/stats")

        XCTAssertEqual(stats.totalDistanceKm, 42)
        XCTAssertEqual(StubURLProtocol.seenAuthHeaders.count, 2, "expected exactly one retry")
        XCTAssertEqual(StubURLProtocol.seenAuthHeaders.first, "Bearer stale")
        XCTAssertEqual(StubURLProtocol.seenAuthHeaders.last, "Bearer refreshed",
                       "the retry must carry the refreshed token, not the stale one")
        XCTAssertEqual(forceRefreshCalls, [false, true],
                       "the second token fetch must ask Clerk to skip its cache")
    }

    /// Two 401s is a real auth failure, not a stale token: surface it and stop.
    func testSecond401SurfacesAsNotAuthenticated() async {
        StubURLProtocol.script = [
            .init(status: 401, body: Data()),
            .init(status: 401, body: Data()),
        ]
        let client = makeClient()
        client.tokenProvider = { _ in "whatever" }

        do {
            let _: StatsResponse = try await client.get("/api/v1/stats")
            XCTFail("expected notAuthenticated")
        } catch APIError.notAuthenticated {
            XCTAssertEqual(StubURLProtocol.seenAuthHeaders.count, 2, "must not retry more than once")
        } catch {
            XCTFail("expected notAuthenticated, got \(error)")
        }
    }

    /// A non-401 failure is not retried — replaying a write the server may already
    /// have accepted is worse than reporting the error.
    func testServerErrorIsNotRetried() async {
        StubURLProtocol.script = [.init(status: 500, body: Data("boom".utf8))]
        let client = makeClient()
        client.tokenProvider = { _ in "tok" }

        do {
            let _: StatsResponse = try await client.get("/api/v1/stats")
            XCTFail("expected httpError")
        } catch APIError.httpError(let code, let body) {
            XCTAssertEqual(code, 500)
            XCTAssertEqual(body, "boom")
            XCTAssertEqual(StubURLProtocol.seenAuthHeaders.count, 1, "500 must not be retried")
        } catch {
            XCTFail("expected httpError, got \(error)")
        }
    }

    /// `delete` used to read status codes on its own and never mapped 401, so an
    /// expired token surfaced as "Server error 401" instead of "Not signed in".
    /// It now shares the one send path, which means it retries like everything else.
    func testDeleteRetriesAndMaps401() async throws {
        StubURLProtocol.script = [
            .init(status: 401, body: Data()),
            .init(status: 204, body: Data()),
        ]
        let client = makeClient()
        client.tokenProvider = { force in force ? "refreshed" : "stale" }

        try await client.delete("/api/v1/photos/abc")

        XCTAssertEqual(StubURLProtocol.seenAuthHeaders.count, 2)
        XCTAssertEqual(StubURLProtocol.seenAuthHeaders.last, "Bearer refreshed")
    }
}
