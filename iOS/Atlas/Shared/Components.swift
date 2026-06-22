import SwiftUI

// MARK: - Tone (semantic color for pills/badges/blips)

enum AtlasTone {
    case neutral, accent, cyan, violet, military, rare, emergency, success

    var color: Color {
        switch self {
        case .neutral: return .atlasInk2
        case .accent: return .atlasAccent
        case .cyan: return .atlasCyan
        case .violet: return .atlasViolet
        case .military: return .atlasWarning
        case .rare: return .atlasViolet
        case .emergency: return .atlasDanger
        case .success: return .atlasSuccess
        }
    }
    var tint: Color { color.opacity(0.15) }
}

// MARK: - Pill

struct Pill: View {
    let text: String
    var tone: AtlasTone = .neutral
    var dot: Bool = false
    var body: some View {
        HStack(spacing: 5) {
            if dot { Circle().fill(tone.color).frame(width: 6, height: 6) }
            Text(text.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(0.4)
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .foregroundStyle(tone.color)
        .background(tone.tint, in: Capsule())
    }
}

// MARK: - Airline / code badge

struct AirlineBadge: View {
    let code: String
    var tone: AtlasTone = .accent
    var body: some View {
        Text(code.prefix(3))
            .font(.system(size: 12, weight: .heavy, design: .rounded))
            .foregroundStyle(tone.color)
            .frame(width: 36, height: 36)
            .background(tone.tint, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
}

// MARK: - Aircraft row (used in map sheet, sky list, search results)

struct FlightRow: View {
    let badge: String
    var tone: AtlasTone = .accent
    let title: String
    let subtitle: String
    var typeCode: String? = nil
    var trailing: String? = nil
    var pill: (String, AtlasTone)? = nil
    var chevron: Bool = false

    var body: some View {
        HStack(spacing: 11) {
            AirlineBadge(code: badge, tone: tone)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.atlasText)
                        .lineLimit(1)
                    if let typeCode, !typeCode.isEmpty {
                        Text(typeCode)
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                            .foregroundStyle(Color.atlasCyan)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.atlasCyan.opacity(0.14), in: Capsule())
                    }
                    if let pill { Pill(text: pill.0, tone: pill.1) }
                }
                Text(subtitle)
                    .font(AtlasFont.mono(11))
                    .foregroundStyle(Color.atlasInk2)
                    .lineLimit(1)
            }
            Spacer(minLength: 6)
            if let trailing {
                Text(trailing)
                    .font(AtlasFont.mono(12))
                    .foregroundStyle(Color.atlasInkFaint)
            }
            if chevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.atlasInkFaint)
            }
        }
        .padding(.vertical, 7)
        .contentShape(Rectangle())
    }
}

// MARK: - Stat tile (bento)

struct StatTile: View {
    let value: String
    let label: String
    var unit: String? = nil
    var tone: AtlasTone = .neutral
    var icon: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tone == .neutral ? Color.atlasInkFaint : tone.color)
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(tone == .neutral ? Color.atlasText : tone.color)
                    .minimumScaleFactor(0.6).lineLimit(1)
                if let unit {
                    Text(unit).font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.atlasInk2)
                }
            }
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.atlasInk2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15)
        .atlasCard(radius: 18)
    }
}

// MARK: - Section header

struct AtlasSectionHeader: View {
    let title: String
    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .tracking(1.6)
            .foregroundStyle(Color.atlasInkFaint)
    }
}

// MARK: - Empty state

struct AtlasEmptyState: View {
    let icon: String
    let title: String
    let message: String
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.atlasAccent.opacity(0.12)).frame(width: 56, height: 56)
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.atlasAccent)
            }
            Text(title).font(AtlasFont.display(20, weight: .bold)).foregroundStyle(Color.atlasText)
            Text(message)
                .font(AtlasFont.body(14)).foregroundStyle(Color.atlasInk2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.horizontal, 32).padding(.vertical, 40)
    }
}
