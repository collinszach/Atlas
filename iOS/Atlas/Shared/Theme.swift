import SwiftUI

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

// MARK: - Typography (modern: SF Pro Rounded display, mono for data)

enum AtlasFont {
    /// Big, bold, modern — rounded sans (NOT serif).
    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
    static func mono(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
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
