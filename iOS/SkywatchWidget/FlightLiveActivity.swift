import ActivityKit
import WidgetKit
import SwiftUI

// Atlas brand tokens (Theme.swift lives in the app target, not the widget).
private extension Color {
    static let atlasGold = Color(red: 0xC9 / 255, green: 0xA8 / 255, blue: 0x4C / 255)
    static let atlasInk = Color(red: 0x9F / 255, green: 0xB0 / 255, blue: 0xCC / 255)
}

struct FlightLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FlightActivityAttributes.self) { context in
            // Lock screen / banner
            LockScreenView(context: context)
                .padding(16)
                .activityBackgroundTint(Color.black.opacity(0.85))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text(context.attributes.callsign).font(.headline)
                    } icon: {
                        Image(systemName: "airplane").foregroundStyle(Color.atlasGold)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if let type = context.attributes.type {
                        Text(type).font(.system(.caption, design: .monospaced)).foregroundStyle(Color.atlasInk)
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.routeText).font(.subheadline).foregroundStyle(Color.atlasInk)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(context.state.altitudeText)
                        Spacer()
                        Text(context.state.speedText)
                        Spacer()
                        Text(context.state.headingText)
                    }
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Color.atlasInk)
                }
            } compactLeading: {
                Image(systemName: "airplane").foregroundStyle(Color.atlasGold)
            } compactTrailing: {
                Text(context.attributes.callsign).font(.system(.caption2, design: .monospaced))
            } minimal: {
                Image(systemName: "airplane").foregroundStyle(Color.atlasGold)
            }
            .keylineTint(Color.atlasGold)
        }
    }
}

private struct LockScreenView: View {
    let context: ActivityViewContext<FlightActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "airplane").foregroundStyle(Color.atlasGold)
                Text(context.attributes.callsign).font(.headline)
                if let type = context.attributes.type {
                    Text(type)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Color.atlasInk)
                }
                Spacer()
                Text(context.attributes.routeText)
                    .font(.subheadline)
                    .foregroundStyle(Color.atlasInk)
            }
            HStack {
                metric("ALT", context.state.altitudeText)
                Spacer()
                metric("SPD", context.state.speedText)
                Spacer()
                metric("HDG", context.state.headingText)
            }
        }
        .foregroundStyle(.white)
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.system(size: 9, weight: .bold)).foregroundStyle(Color.atlasInk)
            Text(value).font(.system(.caption, design: .monospaced))
        }
    }
}
