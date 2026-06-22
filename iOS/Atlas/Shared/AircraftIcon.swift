import SwiftUI

// MARK: - Category derived from ICAO type code

enum AircraftCategory {
    case widebody, narrowbody, regional, turboprop, lightProp, bizjet
    case helicopter, fighter, military, glider, unknown

    /// Heuristic from the ADS-B type designator + military flag.
    init(typeCode: String?, isMilitary: Bool = false) {
        let t = (typeCode ?? "").uppercased()

        if Self.helicopters.contains(t) || t.hasPrefix("EC") || t.hasPrefix("AS3")
            || t.hasPrefix("R22") || t.hasPrefix("R44") || t.hasPrefix("R66") {
            self = .helicopter; return
        }
        if Self.fighters.contains(t) { self = .fighter; return }
        if Self.widebodies.contains(where: { t.hasPrefix($0) }) { self = .widebody; return }
        if Self.bizjets.contains(where: { t.hasPrefix($0) }) { self = .bizjet; return }
        if Self.turboprops.contains(where: { t.hasPrefix($0) }) { self = .turboprop; return }
        if Self.regionals.contains(where: { t.hasPrefix($0) }) { self = .regional; return }
        if Self.narrowbodies.contains(where: { t.hasPrefix($0) }) { self = .narrowbody; return }
        if Self.gliders.contains(t) { self = .glider; return }
        if Self.lightProps.contains(where: { t.hasPrefix($0) }) { self = .lightProp; return }
        if isMilitary { self = .military; return }
        self = .unknown
    }

    /// Which silhouette to draw.
    var shape: AircraftShape {
        switch self {
        case .widebody, .narrowbody, .regional, .bizjet, .military, .unknown: return .jet
        case .turboprop, .lightProp: return .prop
        case .helicopter: return .helicopter
        case .fighter: return .fighter
        case .glider: return .glider
        }
    }

    /// Relative marker size.
    var sizeScale: CGFloat {
        switch self {
        case .widebody: return 1.25
        case .narrowbody, .bizjet, .military, .unknown: return 1.0
        case .regional, .turboprop: return 0.9
        case .lightProp, .helicopter, .glider: return 0.8
        case .fighter: return 0.95
        }
    }

    var label: String {
        switch self {
        case .widebody: return "Widebody"
        case .narrowbody: return "Jet"
        case .regional: return "Regional jet"
        case .turboprop: return "Turboprop"
        case .lightProp: return "Light aircraft"
        case .bizjet: return "Business jet"
        case .helicopter: return "Helicopter"
        case .fighter: return "Fighter"
        case .military: return "Military"
        case .glider: return "Glider"
        case .unknown: return "Aircraft"
        }
    }

    // Type-code tables (common cases; extend over time)
    private static let widebodies = ["A38", "A33", "A34", "A35", "B74", "B77", "B78", "B76", "MD1", "A124", "A225", "IL76", "AN12"]
    private static let narrowbodies = ["A19", "A20", "A21", "A31", "A32", "B73", "B75", "B72", "BCS", "MD8", "MD9", "DC9"]
    private static let regionals = ["E17", "E19", "E29", "E75", "CRJ", "CR7", "CR9", "RJ", "E45", "E70"]
    private static let turboprops = ["DH8", "AT7", "AT4", "AT5", "C208", "PC12", "SF34", "B190", "SW4", "JS3", "D328", "F50"]
    private static let lightProps = ["C17", "C15", "C12", "C18", "C20", "PA2", "PA3", "PA4", "SR2", "DA4", "DA2", "BE3", "P28", "M20", "RV"]
    private static let bizjets = ["GLF", "GLE", "GL5", "GL6", "G15", "C25", "C56", "C68", "C75", "LJ", "CL6", "CL3", "F2T", "F90", "FA", "E55", "H25", "BE40", "PRM"]
    private static let helicopters: Set<String> = ["H60", "S76", "S92", "B06", "B407", "B412", "B429", "A139", "A169", "A109", "EC30", "EC35", "EC45", "EC20", "H500", "AS50", "AS65", "R22", "R44", "R66", "GAZL", "EH10", "UH1"]
    private static let fighters: Set<String> = ["F15", "F16", "F18", "F22", "F35", "F5", "F4", "EUFI", "RFAL", "MIG", "SU27", "SU30", "SU35", "A10", "EA18", "TOR", "GR4", "HAR", "F14"]
    private static let gliders: Set<String> = ["GLID", "DG", "AS21", "ASK", "DISC", "LS8", "VENT", "DUOD"]
}

// MARK: - Silhouettes

enum AircraftShape { case jet, prop, helicopter, fighter, glider }

/// Top-down aircraft silhouette pointing UP (north). Rotate by heading at the call site.
struct AircraftSilhouette: Shape {
    let kind: AircraftShape

    func path(in r: CGRect) -> Path {
        // Work in a 100x100 unit box, then map to rect.
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: r.minX + x / 100 * r.width, y: r.minY + y / 100 * r.height)
        }
        var path = Path()
        switch kind {
        case .jet:
            // fuselage
            path.move(to: p(50, 4))
            path.addLine(to: p(56, 18)); path.addLine(to: p(56, 40))
            path.addLine(to: p(95, 64)); path.addLine(to: p(95, 72))  // right swept wing
            path.addLine(to: p(56, 56)); path.addLine(to: p(56, 80))
            path.addLine(to: p(70, 90)); path.addLine(to: p(70, 95))  // right tailplane
            path.addLine(to: p(50, 88))
            path.addLine(to: p(30, 95)); path.addLine(to: p(30, 90))  // left tailplane
            path.addLine(to: p(44, 80)); path.addLine(to: p(44, 56))
            path.addLine(to: p(5, 72)); path.addLine(to: p(5, 64))    // left swept wing
            path.addLine(to: p(44, 40)); path.addLine(to: p(44, 18))
            path.closeSubpath()
        case .prop:
            // straight wings, prop bar at nose
            path.move(to: p(50, 8))
            path.addLine(to: p(55, 20)); path.addLine(to: p(55, 42))
            path.addLine(to: p(96, 42)); path.addLine(to: p(96, 50))  // right straight wing
            path.addLine(to: p(55, 50)); path.addLine(to: p(55, 82))
            path.addLine(to: p(68, 88)); path.addLine(to: p(68, 93))
            path.addLine(to: p(50, 86))
            path.addLine(to: p(32, 93)); path.addLine(to: p(32, 88))
            path.addLine(to: p(45, 82)); path.addLine(to: p(45, 50))
            path.addLine(to: p(4, 50)); path.addLine(to: p(4, 42))     // left straight wing
            path.addLine(to: p(45, 42)); path.addLine(to: p(45, 20))
            path.closeSubpath()
            // prop bar
            path.move(to: p(34, 8)); path.addLine(to: p(66, 8))
        case .fighter:
            // delta / arrow
            path.move(to: p(50, 2))
            path.addLine(to: p(58, 35)); path.addLine(to: p(92, 86))   // right delta
            path.addLine(to: p(58, 74)); path.addLine(to: p(58, 92))
            path.addLine(to: p(50, 98)); path.addLine(to: p(42, 92))
            path.addLine(to: p(42, 74)); path.addLine(to: p(8, 86))    // left delta
            path.addLine(to: p(42, 35))
            path.closeSubpath()
        case .helicopter:
            // body
            path.addEllipse(in: CGRect(x: r.minX + 0.34 * r.width, y: r.minY + 0.30 * r.height,
                                       width: 0.32 * r.width, height: 0.40 * r.height))
            // tail boom
            path.move(to: p(50, 66)); path.addLine(to: p(50, 96))
            path.move(to: p(40, 94)); path.addLine(to: p(60, 94))      // tail rotor
            // main rotor (X)
            path.move(to: p(14, 14)); path.addLine(to: p(86, 86))
            path.move(to: p(86, 14)); path.addLine(to: p(14, 86))
        case .glider:
            // very long thin straight wings
            path.move(to: p(50, 8))
            path.addLine(to: p(53, 24)); path.addLine(to: p(53, 44))
            path.addLine(to: p(99, 46)); path.addLine(to: p(99, 50))
            path.addLine(to: p(53, 52)); path.addLine(to: p(53, 86))
            path.addLine(to: p(64, 92)); path.addLine(to: p(50, 88))
            path.addLine(to: p(36, 92)); path.addLine(to: p(47, 86))
            path.addLine(to: p(47, 52))
            path.addLine(to: p(1, 50)); path.addLine(to: p(1, 46))
            path.addLine(to: p(47, 44)); path.addLine(to: p(47, 24))
            path.closeSubpath()
        }
        return path
    }
}

// MARK: - Marker view

struct AircraftMarker: View {
    let category: AircraftCategory
    let heading: Double?
    let color: Color
    var baseSize: CGFloat = 18
    var selected: Bool = false

    var body: some View {
        let size = baseSize * category.sizeScale * (selected ? 1.4 : 1.0)
        let isStroke = category.shape == .helicopter
        AircraftSilhouette(kind: category.shape)
            .fill(isStroke ? Color.clear : color)
            .overlay(
                AircraftSilhouette(kind: category.shape)
                    .stroke(color, lineWidth: isStroke ? 1.6 : 0)
            )
            .frame(width: size, height: size)
            .rotationEffect(.degrees((heading ?? 0)))
            .shadow(color: color.opacity(0.7), radius: selected ? 8 : 4)
    }
}
