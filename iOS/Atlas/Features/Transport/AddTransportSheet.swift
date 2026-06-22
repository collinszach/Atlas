import SwiftUI

private enum TransportType: String, CaseIterable {
    case flight, train, car, ferry, bus, walk, other

    var label: String { rawValue.capitalized }

    var systemImage: String {
        switch self {
        case .flight: return "airplane"
        case .train:  return "tram.fill"
        case .car:    return "car.fill"
        case .ferry:  return "ferry.fill"
        case .bus:    return "bus.fill"
        case .walk:   return "figure.walk"
        case .other:  return "arrow.right.circle"
        }
    }
}

struct AddTransportSheet: View {
    let tripId: String
    let api: APIClient
    var onAdded: (TransportLeg) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var vm = TransportWriteViewModel()

    @State private var type: TransportType = .flight
    @State private var flightNumber = ""
    @State private var originIata = ""
    @State private var destIata = ""
    @State private var airline = ""
    @State private var seatClass = ""
    @State private var originCity = ""
    @State private var destCity = ""
    @State private var departureDate = Date()
    @State private var includeDepartureTime = false
    @State private var hasArrival = false
    @State private var arrivalDate = Date()
    @State private var includeArrivalTime = false
    @State private var enrichedDurationMin: Int? = nil
    @State private var enrichedDistanceKm: Double? = nil

    private var isValid: Bool {
        if type == .flight {
            return !originIata.trimmingCharacters(in: .whitespaces).isEmpty ||
                   !destIata.trimmingCharacters(in: .whitespaces).isEmpty
        }
        return !originCity.trimmingCharacters(in: .whitespaces).isEmpty ||
               !destCity.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $type) {
                        ForEach(TransportType.allCases, id: \.rawValue) { t in
                            Label(t.label, systemImage: t.systemImage).tag(t)
                        }
                    }
                    .pickerStyle(.menu)
                }

                if type == .flight {
                    Section("Flight") {
                        HStack {
                            TextField("Flight number (e.g. AA123)", text: $flightNumber)
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                            if vm.isEnriching {
                                ProgressView().scaleEffect(0.8)
                            } else {
                                Button("Lookup") {
                                    Task { await lookupFlight() }
                                }
                                .foregroundStyle(flightNumber.isEmpty ? Color.atlasMuted : Color.atlasAccent)
                                .disabled(flightNumber.isEmpty)
                            }
                        }
                        if let err = vm.enrichError {
                            Text(err)
                                .font(AtlasFont.body(12))
                                .foregroundStyle(.red)
                        }
                    }

                    Section("Route") {
                        HStack(spacing: 12) {
                            TextField("Origin IATA", text: $originIata)
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                            Image(systemName: "arrow.right")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.atlasMuted)
                            TextField("Dest IATA", text: $destIata)
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                        }
                        TextField("Airline", text: $airline)
                        Picker("Seat class", selection: $seatClass) {
                            Text("None").tag("")
                            Text("Economy").tag("economy")
                            Text("Business").tag("business")
                            Text("First").tag("first")
                        }
                        .pickerStyle(.menu)
                    }
                } else {
                    Section("Route") {
                        TextField("From", text: $originCity)
                        TextField("To", text: $destCity)
                    }
                }

                Section("Departure") {
                    DatePicker(
                        "Date",
                        selection: $departureDate,
                        displayedComponents: includeDepartureTime ? [.date, .hourAndMinute] : .date
                    )
                    Toggle("Include time", isOn: $includeDepartureTime)
                        .tint(Color.atlasAccent)
                }

                Section {
                    Toggle("Add arrival", isOn: $hasArrival)
                        .tint(Color.atlasAccent)
                    if hasArrival {
                        DatePicker(
                            "Date",
                            selection: $arrivalDate,
                            in: departureDate...,
                            displayedComponents: includeArrivalTime ? [.date, .hourAndMinute] : .date
                        )
                        Toggle("Include time", isOn: $includeArrivalTime)
                            .tint(Color.atlasAccent)
                    }
                } header: {
                    Text("Arrival (optional)")
                }

                if let err = vm.error {
                    Section {
                        Text(err)
                            .font(AtlasFont.body(13))
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Add Transport")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: type) { _, newType in
                if newType != .flight {
                    enrichedDurationMin = nil
                    enrichedDistanceKm = nil
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.atlasMuted)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if vm.isSubmitting {
                        ProgressView().tint(Color.atlasAccent)
                    } else {
                        Button("Save") {
                            Task { await save() }
                        }
                        .foregroundStyle(isValid ? Color.atlasAccent : Color.atlasMuted)
                        .disabled(!isValid)
                    }
                }
            }
        }
    }

    private func lookupFlight() async {
        vm.enrichError = nil
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        let dateStr = f.string(from: departureDate)
        guard let result = await vm.enrich(
            flightNumber: flightNumber.uppercased(),
            date: dateStr,
            api: api
        ) else { return }
        if let v = result.originIata, !v.isEmpty { originIata = v }
        if let v = result.destIata, !v.isEmpty { destIata = v }
        if let v = result.airline, !v.isEmpty { airline = v }
        if let v = result.originCity, !v.isEmpty, originCity.isEmpty { originCity = v }
        if let v = result.destCity, !v.isEmpty, destCity.isEmpty { destCity = v }
        enrichedDurationMin = result.durationMin
        enrichedDistanceKm = result.distanceKm
    }

    private func save() async {
        guard !vm.isSubmitting else { return }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")

        func fmt(_ date: Date, includeTime: Bool) -> String {
            f.dateFormat = includeTime ? "yyyy-MM-dd'T'HH:mm:ss" : "yyyy-MM-dd"
            return f.string(from: date)
        }

        let body = TransportCreate(
            type: type.rawValue,
            flightNumber: type == .flight ? (flightNumber.isEmpty ? nil : flightNumber.uppercased()) : nil,
            airline: type == .flight ? (airline.isEmpty ? nil : airline) : nil,
            originIata: type == .flight ? (originIata.isEmpty ? nil : originIata.uppercased()) : nil,
            destIata: type == .flight ? (destIata.isEmpty ? nil : destIata.uppercased()) : nil,
            originCity: originCity.isEmpty ? nil : originCity,
            destCity: destCity.isEmpty ? nil : destCity,
            departureAt: fmt(departureDate, includeTime: includeDepartureTime),
            arrivalAt: hasArrival ? fmt(arrivalDate, includeTime: includeArrivalTime) : nil,
            durationMin: enrichedDurationMin,
            distanceKm: enrichedDistanceKm,
            seatClass: type == .flight ? (seatClass.isEmpty ? nil : seatClass) : nil
        )

        do {
            let leg = try await vm.createTransportLeg(tripId: tripId, body: body, api: api)
            onAdded(leg)
            dismiss()
        } catch {
            vm.error = error.localizedDescription
        }
    }
}
