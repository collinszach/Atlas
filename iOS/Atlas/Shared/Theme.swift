import SwiftUI
import UIKit

extension Color {
    // MARK: Surfaces (dark, modern)
    static let atlasBackground     = Color(hex: "#070B14")   // near-black navy
    static let atlasBackgroundDeep = Color(hex: "#04060C")
    static let atlasSurface        = Color(hex: "#101725")   // card
    static let atlasSurface2       = Color(hex: "#19233A")   // raised
    static let atlasBorder         = Color(hex: "#212E45")
    static let atlasBorderStrong   = Color(hex: "#33415E")

    // MARK: Ink
    static let atlasText           = Color(hex: "#F2F6FF")
    static let atlasInk2           = Color(hex: "#9FB0CC")
    static let atlasInkFaint       = Color(hex: "#5C6C8A")
    static let atlasMuted          = Color(hex: "#5C6C8A")

    // MARK: Accent — vivid electric blue → cyan (flashy, modern, aviation)
    static let atlasAccent         = Color(hex: "#4F8DFF")
    static let atlasAccentHi       = Color(hex: "#6FA6FF")
    static let atlasCyan           = Color(hex: "#26E0E0")
    static let atlasAccentCool     = Color(hex: "#4F8DFF")
    static let atlasViolet         = Color(hex: "#8B6CFF")

    // MARK: Semantic
    static let atlasSuccess        = Color(hex: "#34E0A1")
    static let atlasWarning        = Color(hex: "#FFB948")
    static let atlasDanger         = Color(hex: "#FF5C7A")
    static let atlasVisited        = Color(hex: "#4F8DFF")
    static let atlasPlanned        = Color(hex: "#8B6CFF")

    // legacy alias kept so older references compile
    static let atlasGold           = Color(hex: "#C9A84C")

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

// MARK: - Signature gradients

enum AtlasGradient {
    /// The brand gradient — electric blue → cyan.
    static let accent = LinearGradient(
        colors: [Color.atlasAccent, Color.atlasCyan],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let accentBright = LinearGradient(
        colors: [Color.atlasAccentHi, Color.atlasCyan],
        startPoint: .leading, endPoint: .trailing
    )
    static let violet = LinearGradient(
        colors: [Color.atlasViolet, Color.atlasAccent],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    /// Page background wash.
    static let backdrop = LinearGradient(
        colors: [Color.atlasBackground, Color.atlasBackgroundDeep],
        startPoint: .top, endPoint: .bottom
    )
}

// MARK: - Typography (DESIGN.md: Playfair Display / IBM Plex Sans / IBM Plex Mono)

enum AtlasFont {
    /// PostScript names as they appear in the bundled files' name tables. Playfair's
    /// variable named instances carry a "Roman" infix — `PlayfairDisplay-Bold` does NOT
    /// exist and would silently fall back to the system face.
    private enum PS {
        static let displaySemibold = "PlayfairDisplayRoman-SemiBold"
        static let displayBold     = "PlayfairDisplayRoman-Bold"
        static let sansRegular     = "IBMPlexSans-Regular"
        static let sansMedium      = "IBMPlexSans-Medium"
        static let sansSemibold    = "IBMPlexSans-SemiBold"
        static let monoRegular     = "IBMPlexMono-Regular"
        static let monoMedium      = "IBMPlexMono-Medium"
    }

    /// A *moment* font — route headers, airport names, hero numeral companions.
    /// Never on buttons, labels or data (DESIGN.md → Typography).
    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        let name: String
        switch weight {
        case .bold, .heavy, .black: name = PS.displayBold
        default:                    name = PS.displaySemibold
        }
        return custom(name, size: size, fallback: weight, design: .serif)
    }

    /// The instrument voice — flight numbers, distances, altitudes, dates, codes.
    static func mono(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        let name: String
        switch weight {
        case .ultraLight, .thin, .light, .regular: name = PS.monoRegular
        default:                                   name = PS.monoMedium
        }
        return custom(name, size: size, fallback: weight, design: .monospaced)
    }

    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let name: String
        switch weight {
        case .semibold, .bold, .heavy, .black: name = PS.sansSemibold
        case .medium:                          name = PS.sansMedium
        default:                               name = PS.sansRegular
        }
        return custom(name, size: size, fallback: weight, design: .default)
    }

    /// Resolves a bundled face, falling back to the system equivalent if it is missing.
    /// `UIFont(name:)` returns nil for an unregistered name, whereas `Font.custom` would
    /// silently substitute — so the check is explicit and the fallback is deliberate.
    private static func custom(
        _ name: String,
        size: CGFloat,
        fallback weight: Font.Weight,
        design: Font.Design
    ) -> Font {
        guard isRegistered(name) else {
            return .system(size: size, weight: weight, design: design)
        }
        return .custom(name, size: size)
    }

    private static var registeredCache: [String: Bool] = [:]

    static func isRegistered(_ name: String) -> Bool {
        if let cached = registeredCache[name] { return cached }
        let found = UIFont(name: name, size: 12) != nil
        registeredCache[name] = found
        if !found {
            assertionFailure("Atlas font not registered: \(name) — check UIAppFonts and the bundled file.")
        }
        return found
    }

    /// Every face this app expects to find; used by the startup check and tests.
    static var expectedFaces: [String] {
        [PS.displaySemibold, PS.displayBold,
         PS.sansRegular, PS.sansMedium, PS.sansSemibold,
         PS.monoRegular, PS.monoMedium]
    }
}

// MARK: - Modular glass card

struct AtlasCardStyle: ViewModifier {
    var radius: CGFloat = 20
    var glow: Bool = false
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Color.atlasSurface.opacity(0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.10), Color.white.opacity(0.02)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.35), radius: 18, x: 0, y: 10)
            .shadow(color: glow ? Color.atlasAccent.opacity(0.28) : .clear, radius: 24, x: 0, y: 8)
    }
}

extension View {
    func atlasCard(radius: CGFloat = 20, glow: Bool = false) -> some View {
        modifier(AtlasCardStyle(radius: radius, glow: glow))
    }

    /// Solid pill with the brand gradient — for primary CTAs and chips.
    func atlasGradientPill(radius: CGFloat = 14) -> some View {
        self
            .background(AtlasGradient.accent, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .shadow(color: Color.atlasAccent.opacity(0.35), radius: 16, x: 0, y: 8)
    }
}
