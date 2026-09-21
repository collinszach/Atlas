import XCTest
import UIKit
@testable import Atlas

/// Guards the font bundling seam. `Font.custom` substitutes silently when a
/// PostScript name is wrong, so a typo here would ship as "looks like the system
/// font" with no error anywhere — exactly the failure these tests exist to catch.
final class TypographyTests: XCTestCase {

    /// Registration comes from the host app's UIAppFonts. Skip rather than fail
    /// when the tests run unhosted, so this can't report a false red.
    private var fontsAreHosted: Bool {
        UIFont.familyNames.contains("Playfair Display")
    }

    func testEveryExpectedFaceIsRegistered() throws {
        try XCTSkipUnless(fontsAreHosted, "Fonts register via the host app's UIAppFonts.")
        for name in AtlasFont.expectedFaces {
            XCTAssertNotNil(
                UIFont(name: name, size: 12),
                "Font face '\(name)' is not registered — check UIAppFonts and the bundled .ttf."
            )
        }
    }

    /// Playfair's variable named instances carry a "Roman" infix. This asserts the
    /// trap is still a trap, so nobody "corrects" the name back to the obvious one.
    func testPlayfairUsesRomanInfixNotTheObviousName() throws {
        try XCTSkipUnless(fontsAreHosted, "Fonts register via the host app's UIAppFonts.")
        XCTAssertNotNil(UIFont(name: "PlayfairDisplayRoman-Bold", size: 12))
        XCTAssertNil(
            UIFont(name: "PlayfairDisplay-Bold", size: 12),
            "If this now resolves, the font file changed — revisit AtlasFont.PS."
        )
    }

    func testResolvedFacesAreTheBundledFamiliesNotSystemFallbacks() throws {
        try XCTSkipUnless(fontsAreHosted, "Fonts register via the host app's UIAppFonts.")
        XCTAssertEqual(UIFont(name: "PlayfairDisplayRoman-Bold", size: 12)?.familyName, "Playfair Display")
        XCTAssertEqual(UIFont(name: "IBMPlexSans-Regular", size: 12)?.familyName, "IBM Plex Sans")
        XCTAssertEqual(UIFont(name: "IBMPlexMono-Regular", size: 12)?.familyName, "IBM Plex Mono")
    }
}
