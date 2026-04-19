import SwiftUI

struct TripFormView: View {
    let api: APIClient
    let onCreated: (Trip) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var status: TripStatus = .past
    @State private var vm = TripWriteViewModel()
    @FocusState private var titleFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                Color.atlasBackground.ignoresSafeArea()

                Form {
                    Section {
                        TextField("Trip title", text: $title)
                            .font(AtlasFont.body(15))
                            .focused($titleFocused)

                        Picker("Status", selection: $status) {
                            ForEach(TripStatus.allCases, id: \.self) { s in
                                Label(s.label, systemImage: s.systemImage).tag(s)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
                .scrollContentBackground(.hidden)

                if vm.isLoading {
                    Color.black.opacity(0.3).ignoresSafeArea()
                    ProgressView()
                        .tint(Color.atlasAccent)
                        .scaleEffect(1.4)
                }
            }
            .navigationTitle("New Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.atlasMuted)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            do {
                                let trip = try await vm.createTrip(title: title, status: status, api: api)
                                onCreated(trip)
                                dismiss()
                            } catch {
                                vm.error = error.localizedDescription
                            }
                        }
                    }
                    .font(AtlasFont.body(15, weight: .semibold))
                    .foregroundStyle(title.trimmingCharacters(in: .whitespaces).isEmpty ? Color.atlasMuted : Color.atlasAccent)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || vm.isLoading)
                }
            }
            .alert("Error", isPresented: Binding(
                get: { vm.error != nil },
                set: { if !$0 { vm.error = nil } }
            )) {
                Button("OK", role: .cancel) { vm.error = nil }
            } message: {
                Text(vm.error ?? "")
            }
            .onAppear { titleFocused = true }
        }
    }
}
