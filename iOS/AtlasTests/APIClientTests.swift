import XCTest
import SwiftUI
@testable import Atlas

final class APIClientTests: XCTestCase {
    func testConfigHasValidBaseURL() {
        XCTAssertNotNil(Config.apiBase.host)
    }

    func testAPIClientInitializes() {
        // Asserts the explicit-token path, not `token: nil`. The initializer
        // falls back to the keychain (`token ?? keychain.get("atlas_jwt")`), so
        // asserting nil only held on a simulator nobody had signed into — and
        // when it failed, XCTAssertNil printed the live session JWT into the
        // test log. Keychain state is also shared with the app, so the test
        // must not clear it either.
        let client = APIClient(token: "test-token")
        XCTAssertEqual(client.token, "test-token")
    }

    func testColorHexInitializer() {
        let gold = Color(hex: "#C9A84C")
        // Just verify it doesn't crash — UIColor would be needed for value comparison
        XCTAssertNotNil(gold)
    }
}
