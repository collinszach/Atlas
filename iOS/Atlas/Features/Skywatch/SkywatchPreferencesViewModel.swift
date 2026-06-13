import Foundation

@MainActor
@Observable
final class SkywatchPreferencesViewModel {
    var preference: SkywatchPreference? = nil
    var isLoading = false
    var isSaving = false
    var error: String? = nil

    var rareTypesEnabled = true
    var militaryEnabled = true
    var emergencyEnabled = true
    var radiusKm: Double = 30
    var altCeilingFt: Int? = nil
    var quietHoursEnabled = false
    var quietHoursStart: Date = Calendar.current.date(from: DateComponents(hour: 22, minute: 0)) ?? Date()
    var quietHoursEnd: Date = Calendar.current.date(from: DateComponents(hour: 7, minute: 0)) ?? Date()
    var nlPrompt: String = ""

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    func load(api: APIClient) async {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            let prefs = try await api.getSkywatchPreferences()
            apply(prefs)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func save(api: APIClient) async {
        guard !isSaving else { return }
        isSaving = true
        error = nil
        defer { isSaving = false }

        var quietHours: [String: String]? = nil
        if quietHoursEnabled {
            quietHours = [
                "start": Self.timeFormatter.string(from: quietHoursStart),
                "end": Self.timeFormatter.string(from: quietHoursEnd),
            ]
        } else {
            quietHours = [:]
        }

        let update = SkywatchPreferenceUpdate(
            notableTypesEnabled: rareTypesEnabled,
            militaryEnabled: militaryEnabled,
            emergencyEnabled: emergencyEnabled,
            radiusKm: radiusKm,
            altCeilingFt: altCeilingFt,
            quietHours: quietHours,
            nlPrompt: nlPrompt.isEmpty ? nil : nlPrompt
        )

        do {
            let prefs = try await api.updateSkywatchPreferences(update)
            apply(prefs)
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func apply(_ prefs: SkywatchPreference) {
        preference = prefs
        rareTypesEnabled = prefs.notableTypesEnabled
        militaryEnabled = prefs.militaryEnabled
        emergencyEnabled = prefs.emergencyEnabled
        radiusKm = prefs.radiusKm
        altCeilingFt = prefs.altCeilingFt
        nlPrompt = prefs.nlPrompt ?? ""

        if let quietHours = prefs.quietHours,
           let startStr = quietHours["start"],
           let endStr = quietHours["end"],
           let start = Self.timeFormatter.date(from: startStr),
           let end = Self.timeFormatter.date(from: endStr) {
            quietHoursEnabled = true
            quietHoursStart = start
            quietHoursEnd = end
        } else {
            quietHoursEnabled = false
        }
    }
}
