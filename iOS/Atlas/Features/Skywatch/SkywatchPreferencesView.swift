import SwiftUI

struct SkywatchPreferencesView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(\.dismiss) private var dismiss
    @State private var vm = SkywatchPreferencesViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading && vm.preference == nil {
                    LoadingView()
                } else {
                    form
                }
            }
            .background(Color.atlasBackground)
            .navigationTitle("Skywatch")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Color.atlasAccent)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await vm.save(api: auth.api) }
                    } label: {
                        if vm.isSaving {
                            ProgressView().tint(.atlasAccent)
                        } else {
                            Text("Save")
                        }
                    }
                    .foregroundStyle(Color.atlasAccent)
                    .disabled(vm.isSaving)
                }
            }
        }
        .task {
            await vm.load(api: auth.api)
        }
    }

    private var form: some View {
        Form {
            if let err = vm.error {
                Section {
                    ErrorBanner(message: err) {
                        Task { await vm.load(api: auth.api) }
                    }
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            Section("Alert me about") {
                Toggle("Rare & unusual types", isOn: $vm.rareTypesEnabled)
                Toggle("Military & government", isOn: $vm.militaryEnabled)
                Toggle("Emergencies & oddities", isOn: $vm.emergencyEnabled)
            }
            .tint(.atlasAccent)
            .listRowBackground(Color.atlasSurface)

            Section("Range") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Radius: \(Int(vm.radiusKm)) km")
                        .font(AtlasFont.mono(13))
                        .foregroundStyle(Color.atlasText)
                    Slider(value: $vm.radiusKm, in: 5...250, step: 5)
                        .tint(.atlasAccent)
                }

                HStack {
                    Text("Altitude ceiling")
                        .foregroundStyle(Color.atlasText)
                    Spacer()
                    TextField("ft (optional)", value: $vm.altCeilingFt, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(Color.atlasMuted)
                        .frame(width: 100)
                }
            }
            .listRowBackground(Color.atlasSurface)

            Section("Quiet hours") {
                Toggle("Enable quiet hours", isOn: $vm.quietHoursEnabled)
                    .tint(.atlasAccent)
                if vm.quietHoursEnabled {
                    DatePicker("From", selection: $vm.quietHoursStart, displayedComponents: .hourAndMinute)
                    DatePicker("Until", selection: $vm.quietHoursEnd, displayedComponents: .hourAndMinute)
                }
            }
            .listRowBackground(Color.atlasSurface)
            .foregroundStyle(Color.atlasText)

            Section("Custom alerts") {
                Text("Describe anything else you want Atlas to watch for. This is sent to a local model later to tune the rules.")
                    .font(AtlasFont.body(12))
                    .foregroundStyle(Color.atlasMuted)
                TextEditor(text: $vm.nlPrompt)
                    .frame(minHeight: 100)
                    .foregroundStyle(Color.atlasText)
                    .scrollContentBackground(.hidden)
                    .background(Color.atlasBorder.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .listRowBackground(Color.atlasSurface)
        }
        .scrollContentBackground(.hidden)
    }
}
