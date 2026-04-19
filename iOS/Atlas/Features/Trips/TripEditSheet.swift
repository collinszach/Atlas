import SwiftUI

struct TripEditSheet: View {
    let trip: Trip
    let api: APIClient
    let onUpdated: (Trip) -> Void
    let onDeleted: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var status: TripStatus
    @State private var hasStartDate: Bool
    @State private var startDate: Date
    @State private var hasEndDate: Bool
    @State private var endDate: Date
    @State private var description: String
    @State private var tagsText: String
    @State private var vm = TripWriteViewModel()
    @State private var showDeleteAlert = false

    init(trip: Trip, api: APIClient, onUpdated: @escaping (Trip) -> Void, onDeleted: @escaping () -> Void) {
        self.trip = trip
        self.api = api
        self.onUpdated = onUpdated
        self.onDeleted = onDeleted
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        let sd = trip.startDate.flatMap { f.date(from: $0) }
        let ed = trip.endDate.flatMap { f.date(from: $0) }
        _title = State(initialValue: trip.title)
        _status = State(initialValue: trip.status)
        _hasStartDate = State(initialValue: sd != nil)
        _startDate = State(initialValue: sd ?? Date())
        _hasEndDate = State(initialValue: ed != nil)
        _endDate = State(initialValue: ed ?? Date())
        _description = State(initialValue: trip.description ?? "")
        _tagsText = State(initialValue: trip.tags.joined(separator: ", "))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.atlasBackground.ignoresSafeArea()

                Form {
                    Section("Details") {
                        TextField("Title", text: $title)
                            .font(AtlasFont.body(15))

                        Picker("Status", selection: $status) {
                            ForEach(TripStatus.allCases, id: \.self) { s in
                                Text(s.label).tag(s)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    Section("Dates") {
                        Toggle("Start date", isOn: $hasStartDate)
                            .tint(Color.atlasAccent)
                        if hasStartDate {
                            DatePicker("", selection: $startDate, displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                        }

                        Toggle("End date", isOn: $hasEndDate)
                            .tint(Color.atlasAccent)
                        if hasEndDate {
                            DatePicker("", selection: $endDate, displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                        }
                    }

                    Section("Description") {
                        TextEditor(text: $description)
                            .font(AtlasFont.body(14))
                            .frame(minHeight: 80)
                    }

                    Section("Tags") {
                        TextField("adventure, europe, food", text: $tagsText)
                            .font(AtlasFont.body(14))
                            .foregroundStyle(Color.atlasText)
                    }

                    Section {
                        Button(role: .destructive) {
                            showDeleteAlert = true
                        } label: {
                            HStack {
                                Spacer()
                                Text("Delete Trip")
                                    .font(AtlasFont.body(15, weight: .medium))
                                Spacer()
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)

                if vm.isLoading {
                    ZStack {
                        Color.black.opacity(0.3)
                        ProgressView()
                            .tint(Color.atlasAccent)
                            .scaleEffect(1.4)
                    }
                    .ignoresSafeArea()
                }
            }
            .navigationTitle("Edit Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.atlasMuted)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .font(AtlasFont.body(15, weight: .semibold))
                        .foregroundStyle(title.trimmingCharacters(in: .whitespaces).isEmpty ? Color.atlasMuted : Color.atlasAccent)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || vm.isLoading)
                }
            }
            .alert("Delete \"\(trip.title)\"?", isPresented: $showDeleteAlert) {
                Button("Delete", role: .destructive) { deleteTrip() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete the trip and all its data.")
            }
            .alert("Error", isPresented: Binding(
                get: { vm.error != nil },
                set: { if !$0 { vm.error = nil } }
            )) {
                Button("OK", role: .cancel) { vm.error = nil }
            } message: {
                Text(vm.error ?? "")
            }
        }
    }

    private func save() {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        let start = hasStartDate ? f.string(from: startDate) : nil
        let end = hasEndDate ? f.string(from: endDate) : nil
        let tags = tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        Task {
            do {
                let updated = try await vm.updateTrip(
                    trip: trip,
                    title: title.trimmingCharacters(in: .whitespaces),
                    status: status,
                    startDate: start,
                    endDate: end,
                    description: description,
                    tags: tags,
                    api: api
                )
                onUpdated(updated)
                dismiss()
            } catch {
                vm.error = error.localizedDescription
            }
        }
    }

    private func deleteTrip() {
        Task {
            do {
                try await vm.deleteTrip(id: trip.id, api: api)
                onDeleted()
                dismiss()
            } catch {
                vm.error = error.localizedDescription
            }
        }
    }
}
