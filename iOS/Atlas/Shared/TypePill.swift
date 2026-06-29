import SwiftUI

extension AircraftCategory {
    /// Marker/pill tint for this category.
    var tint: Color {
        switch self {
        case .widebody, .narrowbody, .regional: return .atlasCyan
        case .bizjet: return .atlasViolet
        case .turboprop, .lightProp: return .atlasSuccess
        case .helicopter: return .atlasWarning
        case .fighter, .military: return .atlasDanger
        case .glider: return .atlasInk2
        case .unknown: return .atlasInk2
        }
    }
}

/// Compact aircraft-type code pill (e.g. `A320`), tinted by `AircraftCategory`.
/// Provide `onTap` to make it open the aircraft-type page; omit it for a static label.
struct TypePill: View {
    let typeCode: String
    var onTap: (() -> Void)? = nil

    private var color: Color {
        AircraftCategory(typeCode: typeCode).tint
    }

    var body: some View {
        if let onTap {
            Button(action: onTap) { label }.buttonStyle(.plain)
        } else {
            label
        }
    }

    private var label: some View {
        Text(typeCode.uppercased())
            .font(.system(size: 10, weight: .heavy, design: .monospaced))
            .tracking(0.3)
            .foregroundStyle(color)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(color.opacity(0.16), in: Capsule())
    }
}
