import SwiftUI
import MapKit

struct AddDestinationSheet: View {
    let tripId: String
    let destinationCount: Int
    let api: APIClient
    let onAdded: (Destination) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var vm = DestinationWriteViewModel()
    @State private var searchQuery = ""
    @State private var selectedPlace: MKMapItem? = nil

    // Stage 2 fields
    @State private var hasArrival = false
    @State private var arrivalDate = Date()
    @State private var hasDeparture = false
    @State private var departureDate = Date()
    @State private var rating: Int? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color.atlasBackground.ignoresSafeArea()

                if let place = selectedPlace {
                    detailStage(place: place)
                } else {
                    searchStage
                }
            }
            .navigationTitle(selectedPlace == nil ? "Find City" : "Add Destination")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.atlasMuted)
                }
                if selectedPlace != nil {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            selectedPlace = nil
                            rating = nil
                            hasArrival = false
                            hasDeparture = false
                            arrivalDate = Date()
                            departureDate = Date()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 13, weight: .medium))
                                Text("Back")
                            }
                            .foregroundStyle(Color.atlasAccent)
                        }
                    }
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
        }
    }

    // MARK: - Stage 1: Search

    private var searchStage: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.atlasMuted)
                TextField("Search for a city", text: $searchQuery)
                    .font(AtlasFont.body(15))
                    .foregroundStyle(Color.atlasText)
                    .autocorrectionDisabled()
                    .onChange(of: searchQuery) { _, q in
                        vm.search(query: q)
                    }
                if !searchQuery.isEmpty {
                    Button {
                        searchQuery = ""
                        vm.searchResults = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.atlasMuted)
                    }
                }
            }
            .padding(12)
            .background(Color.atlasSurface)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.atlasBorder, lineWidth: 0.5)
            )
            .padding(.horizontal, 16)
            .padding(.top, 12)

            if vm.isSearching {
                ProgressView()
                    .tint(Color.atlasAccent)
                    .padding(.top, 40)
                Spacer()
            } else if searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
                Text("Search for a city")
                    .font(AtlasFont.body(14))
                    .foregroundStyle(Color.atlasMuted)
                    .padding(.top, 40)
                Spacer()
            } else if vm.searchResults.isEmpty {
                Text("No results for \"\(searchQuery)\"")
                    .font(AtlasFont.body(14))
                    .foregroundStyle(Color.atlasMuted)
                    .padding(.top, 40)
                Spacer()
            } else {
                List(vm.searchResults, id: \.self) { item in
                    Button {
                        selectedPlace = item
                    } label: {
                        HStack(spacing: 12) {
                            if let code = item.placemark.isoCountryCode {
                                Text(flagEmoji(for: code))
                                    .font(.system(size: 22))
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name ?? item.placemark.locality ?? "Unknown")
                                    .font(AtlasFont.body(15, weight: .medium))
                                    .foregroundStyle(Color.atlasText)
                                Text(item.placemark.country ?? "")
                                    .font(AtlasFont.body(12))
                                    .foregroundStyle(Color.atlasMuted)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(Color.atlasSurface)
                    .listRowSeparatorTint(Color.atlasBorder)
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - Stage 2: Details

    private func detailStage(place: MKMapItem) -> some View {
        Form {
            Section {
                HStack(spacing: 12) {
                    if let code = place.placemark.isoCountryCode {
                        Text(flagEmoji(for: code))
                            .font(.system(size: 28))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(place.name ?? place.placemark.locality ?? "Unknown")
                            .font(AtlasFont.body(17, weight: .semibold))
                            .foregroundStyle(Color.atlasText)
                        Text(place.placemark.country ?? "")
                            .font(AtlasFont.body(13))
                            .foregroundStyle(Color.atlasMuted)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Dates") {
                Toggle("Arrival date", isOn: $hasArrival)
                    .tint(Color.atlasAccent)
                if hasArrival {
                    DatePicker("", selection: $arrivalDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                }
                Toggle("Departure date", isOn: $hasDeparture)
                    .tint(Color.atlasAccent)
                if hasDeparture {
                    DatePicker("", selection: $departureDate, in: hasArrival ? arrivalDate... : .distantPast..., displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                }
            }

            Section("Rating") {
                HStack(spacing: 10) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= (rating ?? 0) ? "star.fill" : "star")
                            .foregroundStyle(star <= (rating ?? 0) ? Color.atlasAccent : Color.atlasMuted)
                            .font(.system(size: 24))
                            .onTapGesture {
                                rating = rating == star ? nil : star
                            }
                    }
                }
                .padding(.vertical, 4)
            }

            Section {
                Button {
                    Task {
                        do {
                            let dest = try await vm.addDestination(
                                tripId: tripId,
                                place: place,
                                arrivalDate: hasArrival ? arrivalDate : nil,
                                departureDate: hasDeparture ? departureDate : nil,
                                rating: rating,
                                orderIndex: destinationCount,
                                api: api
                            )
                            onAdded(dest)
                            dismiss()
                        } catch {
                            vm.error = error.localizedDescription
                        }
                    }
                } label: {
                    HStack {
                        Spacer()
                        if vm.isSubmitting {
                            ProgressView()
                                .tint(Color.atlasAccent)
                        } else {
                            Text("Add Destination")
                                .font(AtlasFont.body(15, weight: .semibold))
                                .foregroundStyle(Color.atlasAccent)
                        }
                        Spacer()
                    }
                }
                .disabled(vm.isSubmitting)
            }
        }
        .scrollContentBackground(.hidden)
    }
}
