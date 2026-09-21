import SwiftUI

/// Logbook card per `docs/SPEC-flight-ui.md` D1 and the `atlas-flight-ui.html` mockup:
/// airline pill + mono date, big ORIG → DEST route over a dashed great-circle, mono meta line.
struct FlightLogCard: View {
    let flight: TransportLeg
    var showGlow: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                if let airline = flight.airline, !airline.isEmpty {
                    Pill(text: airline, tone: Self.tone(for: airline))
                } else {
                    Pill(text: "Flight", tone: .neutral)
                }
                Spacer()
                Text(flight.departureDisplay.uppercased())
                    .font(AtlasFont.mono(11))
                    .foregroundStyle(Color.atlasInkFaint)
            }

            RouteLine(origin: flight.originIata ?? flight.originCity ?? "—",
                      destination: flight.destIata ?? flight.destCity ?? "—")

            if let meta = metaLine {
                Text(meta)
                    .font(AtlasFont.mono(11))
                    .foregroundStyle(Color.atlasInk2)
                    .lineLimit(1)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(alignment: .topTrailing) {
            if showGlow {
                Circle()
                    .fill(Color.atlasAccent)
                    .frame(width: 120, height: 120)
                    .blur(radius: 44)
                    .opacity(0.28)
                    .offset(x: 44, y: -44)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .atlasCard(radius: 20)
        .contentShape(Rectangle())
    }

    private var metaLine: String? {
        let parts = [flight.flightNumber, flight.durationDisplay, flight.distanceDisplay]
            .compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// Stable per-airline tint so the list reads as varied rather than uniform.
    private static func tone(for airline: String) -> AtlasTone {
        let palette: [AtlasTone] = [.accent, .violet, .cyan, .success, .rare]
        let hash = airline.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFFFF }
        return palette[hash % palette.count]
    }
}

/// ORIG ---✈ DEST — the dashed great-circle from the mockup's `.route .arr`.
struct RouteLine: View {
    let origin: String
    let destination: String

    var body: some View {
        HStack(spacing: 8) {
            Text(origin)
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.atlasText)
            ZStack(alignment: .trailing) {
                GeometryReader { geo in
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: geo.size.height / 2))
                        p.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height / 2))
                    }
                    .stroke(
                        Color.atlasInkFaint,
                        style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                    )
                }
                .frame(height: 12)
                Image(systemName: "airplane")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.atlasAccent)
                    .offset(y: -1)
            }
            .frame(maxWidth: .infinity)
            Text(destination)
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.atlasText)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(origin) to \(destination)")
    }
}
