import SwiftUI

extension Color {
    // Atlas brand palette
    static let atlasBackground    = Color(hex: "#0A0E1A")
    static let atlasSurface       = Color(hex: "#111827")
    static let atlasBorder        = Color(hex: "#1E2D45")
    static let atlasAccent        = Color(hex: "#C9A84C")  // antique gold
    static let atlasAccentCool    = Color(hex: "#4A90D9")  // ocean blue
    static let atlasText          = Color(hex: "#E2E8F0")
    static let atlasMuted         = Color(hex: "#64748B")
    static let atlasVisited       = Color(hex: "#4A90D9")
    static let atlasPlanned       = Color(hex: "#C9A84C")

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

enum AtlasFont {
    static func display(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
}

struct AtlasCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.atlasSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.atlasBorder, lineWidth: 0.5)
            )
    }
}

extension View {
    func atlasCard() -> some View {
        modifier(AtlasCardStyle())
    }
}
