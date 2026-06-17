import SwiftUI

/// Client-side filter for the live map / radar. Addresses the "cluttered map" pain point.
struct FlightFilter: Equatable {
    var showCommercial = true
    var showMilitary = true
    var showGA = true            // general aviation / light / bizjet / helicopter
    var onlyInteresting = false  // matches a Skywatch trigger
    var onlyEmergency = false
    var maxAltitudeFt: Double = 60_000   // hide above this (slider ceiling = "all")
    var hideGround = true

    static let `default` = FlightFilter()

    var isActive: Bool { self != .default }

    /// A coarse class used for the commercial/military/GA toggles.
    private enum Klass { case commercial, military, ga }
    private func klass(_ ac: OverheadAircraft) -> Klass {
        if ac.isMilitary { return .military }
        let cat = AircraftCategory(typeCode: ac.type, isMilitary: ac.isMilitary)
        switch cat {
        case .widebody, .narrowbody, .regional: return .commercial
        case .lightProp, .turboprop, .bizjet, .helicopter, .glider: return .ga
        case .fighter, .military: return .military
        case .unknown: return ac.airline != nil ? .commercial : .ga
        }
    }

    func matches(_ ac: OverheadAircraft) -> Bool {
        if onlyEmergency, !ac.isEmergency { return false }
        if onlyInteresting, ac.matches.isEmpty, !ac.isEmergency { return false }
        if hideGround, let alt = ac.altitude, alt <= 0 { return false }
        if let alt = ac.altitude, Double(alt) > maxAltitudeFt { return false }
        switch klass(ac) {
        case .commercial: if !showCommercial { return false }
        case .military:   if !showMilitary { return false }
        case .ga:         if !showGA { return false }
        }
        return true
    }
}

// MARK: - Filter sheet

struct FilterSheet: View {
    @Binding var filter: FlightFilter
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    section("Aircraft") {
                        toggle("Commercial", icon: "airplane", $filter.showCommercial)
                        toggle("Military", icon: "shield.lefthalf.filled", $filter.showMilitary)
                        toggle("General aviation", icon: "airplane.circle", $filter.showGA)
                    }
                    section("Highlights") {
                        toggle("Only interesting", icon: "sparkles", $filter.onlyInteresting)
                        toggle("Only emergencies", icon: "exclamationmark.triangle.fill", $filter.onlyEmergency)
                        toggle("Hide aircraft on the ground", icon: "airplane.arrival", $filter.hideGround)
                    }
                    section("Altitude") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Below").font(AtlasFont.body(14)).foregroundStyle(Color.atlasInk2)
                                Spacer()
                                Text(filter.maxAltitudeFt >= 60_000 ? "All" : "FL\(Int(filter.maxAltitudeFt)/100)")
                                    .font(AtlasFont.mono(13)).foregroundStyle(Color.atlasCyan)
                            }
                            Slider(value: $filter.maxAltitudeFt, in: 5_000...60_000, step: 1_000)
                                .tint(Color.atlasAccent)
                        }
                        .padding(14).atlasCard(radius: 16)
                    }
                }
                .padding(16)
            }
            .background(Color.atlasBackground)
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Reset") { filter = .default }
                        .foregroundStyle(filter.isActive ? Color.atlasAccent : Color.atlasInkFaint)
                        .disabled(!filter.isActive)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundStyle(Color.atlasAccent).fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(Color.atlasBackground)
    }

    private func section(_ title: String, @ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            AtlasSectionHeader(title: title)
            VStack(spacing: 0) { content() }.atlasCard(radius: 16)
        }
    }

    private func toggle(_ label: String, icon: String, _ binding: Binding<Bool>) -> some View {
        Toggle(isOn: binding) {
            HStack(spacing: 11) {
                Image(systemName: icon).font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(binding.wrappedValue ? Color.atlasAccent : Color.atlasInkFaint)
                    .frame(width: 22)
                Text(label).font(AtlasFont.body(15)).foregroundStyle(Color.atlasText)
            }
        }
        .tint(Color.atlasAccent)
        .padding(.horizontal, 14).padding(.vertical, 11)
    }
}
