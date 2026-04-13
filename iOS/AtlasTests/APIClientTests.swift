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
