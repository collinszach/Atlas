import SwiftUI

// MARK: - ICAO prefix → airline name (majors; fallback to raw field)
private let airlineMap: [String: String] = [
    "AAL": "American Airlines", "UAL": "United Airlines", "DAL": "Delta Air Lines",
    "SWA": "Southwest Airlines", "JBU": "JetBlue Airways", "ASA": "Alaska Airlines",
    "FFT": "Frontier Airlines", "NKS": "Spirit Airlines", "HAL": "Hawaiian Airlines",
    "BAW": "British Airways", "AFR": "Air France", "DLH": "Lufthansa",
    "KLM": "KLM Royal Dutch", "UAE": "Emirates", "QTR": "Qatar Airways",
    "SIA": "Singapore Airlines", "CPA": "Cathay Pacific", "ANA": "All Nippon Airways",
    "JAL": "Japan Airlines", "QFA": "Qantas", "ETH": "Ethiopian Airlines",
    "MSR": "EgyptAir", "SVA": "Saudia", "THY": "Turkish Airlines",
    "EIN": "Aer Lingus", "AZA": "ITA Airways", "VRD": "Virgin Atlantic",
    "WZZ": "Wizz Air", "RYR": "Ryanair", "EZY": "easyJet",
]

private func resolveAirline(leg: TransportLeg) -> String? {
    if let airline = leg.airline, !airline.isEmpty { return airline }
    if let fn = leg.flightNumber, fn.count >= 3 {
        let icao = String(fn.prefix(3)).uppercased()
        return airlineMap[icao]
    }
    return nil
}

private func airlineBadgeCode(leg: TransportLeg) -> String {
    if let fn = leg.flightNumber, fn.count >= 2 {
        return String(fn.prefix(3)).uppercased()
    }
    return "FLT"
}

private func formatDuration(_ minutes: Int) -> String {
    let h = minutes / 60
    let m = minutes % 60
    return h > 0 ? "\(h)h \(m)m" : "\(m)m"
}

private func formatDateShort(_ iso: String?) -> String {
    guard let iso else { return "—" }
    let raw = String(iso.prefix(10))
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    if let d = f.date(from: raw) {
        f.dateFormat = "MMM d, yyyy"
        return f.string(from: d)
    }
    return raw
}

// MARK: - Skeleton card

private struct FlightCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                RoundedRectangle(cornerRadius: 6).fill(Color.atlasBorder).frame(width: 56, height: 22)
                Spacer()
                RoundedRectangle(cornerRadius: 4).fill(Color.atlasBorder).frame(width: 80, height: 14)
            }
            HStack(alignment: .center, spacing: 0) {
                RoundedRectangle(cornerRadius: 4).fill(Color.atlasBorder).frame(width: 52, height: 32)
                Spacer()
                RoundedRectangle(cornerRadius: 4).fill(Color.atlasBorder).frame(width: 20, height: 14)
                Spacer()
                RoundedRectangle(cornerRadius: 4).fill(Color.atlasBorder).frame(width: 52, height: 32)
            }
            RoundedRectangle(cornerRadius: 4).fill(Color.atlasBorder).frame(height: 12)
        }
        .padding(16)
        .atlasCard()
    }
}

// MARK: - Flight logbook card

struct FlightLogCard: View {
    let flight: LoggedFlight

    private var leg: TransportLeg { flight.leg }
    private var orig: String { leg.originIata ?? leg.originCity ?? "???" }
    private var dest: String { leg.destIata ?? leg.destCity ?? "???" }
    private var airlineName: String { resolveAirline(leg: leg) ?? "Unknown Airline" }

    private var aircraftLine: String {
        var parts: [String] = []
        if let fn = leg.flightNumber { parts.append(fn) }
        if let cls = leg.seatClass { parts.append(cls.capitalized) }
        if let dur = leg.durationMin { parts.append(formatDuration(dur)) }
        if let km = leg.distanceKm { parts.append(String(format: "%.0f km", km)) }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Row 1 — airline pill + date
            HStack(alignment: .center) {
                Pill(text: airlineName, tone: .accent)
                Spacer()
                Text(formatDateShort(leg.departureAt))
                    .font(AtlasFont.mono(11))
                    .foregroundStyle(Color.atlasInkFaint)
            }

            // Row 2 — big route ORIG → DEST
            HStack(alignment: .center, spacing: 0) {
                Text(orig)
                    .font(AtlasFont.display(30, weight: .heavy))
                    .foregroundStyle(Color.atlasText)

                Spacer(minLength: 8)

                HStack(spacing: 3) {
                    Rectangle()
                        .fill(Color.atlasBorder)
                        .frame(height: 1)
                        .frame(maxWidth: .infinity)
                    Image(systemName: "airplane")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.atlasCyan)
                    Rectangle()
                        .fill(Color.atlasBorder)
                        .frame(height: 1)
                        .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: 80)

                Spacer(minLength: 8)

                Text(dest)
                    .font(AtlasFont.display(30, weight: .heavy))
                    .foregroundStyle(Color.atlasText)
            }

            // Row 3 — mono data line
            if !aircraftLine.isEmpty {
                Text(aircraftLine)
                    .font(AtlasFont.mono(11))
                    .foregroundStyle(Color.atlasInk2)
                    .lineLimit(1)
            }
        }
        .padding(16)
        .atlasCard(radius: 20)
    }
}

// MARK: - Flight detail sheet

private struct FlightDetailSheet: View {
    let flight: LoggedFlight
    @Environment(AuthManager.self) private var auth
    @State private var vm = TripDetailViewModel()

    private var leg: TransportLeg { flight.leg }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.atlasBackground.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        heroCard
                        dataGrid
                        tripContext
                        if vm.isLoading {
                            ProgressView().tint(.atlasAccent).frame(maxWidth: .infinity).padding(.top, 8)
                        } else if !vm.destinations.isEmpty {
                            destinationsSection
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle(leg.flightNumber ?? "Flight Detail")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task { await vm.load(tripId: flight.trip.id, api: auth.api) }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(leg.originIata ?? leg.originCity ?? "???")
                    .font(AtlasFont.display(40, weight: .heavy))
                    .foregroundStyle(Color.atlasText)
                Spacer()
                Image(systemName: "airplane")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.atlasCyan)
                Spacer()
                Text(leg.destIata ?? leg.destCity ?? "???")
                    .font(AtlasFont.display(40, weight: .heavy))
                    .foregroundStyle(Color.atlasText)
            }
            if let airline = resolveAirline(leg: leg) {
                Text(airline)
                    .font(AtlasFont.body(13, weight: .medium))
                    .foregroundStyle(Color.atlasInk2)
            }
        }
        .padding(20)
        .atlasCard()
    }

    @ViewBuilder
    private var dataGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            if let fn = leg.flightNumber { dataCell(label: "FLIGHT", value: fn) }
            if let dep = leg.departureAt { dataCell(label: "DATE", value: formatDateShort(dep)) }
            if let dur = leg.durationMin { dataCell(label: "DURATION", value: formatDuration(dur)) }
            if let km = leg.distanceKm { dataCell(label: "DISTANCE", value: String(format: "%.0f km", km)) }
            if let cls = leg.seatClass { dataCell(label: "CLASS", value: cls.capitalized) }
        }
    }

    private func dataCell(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(Color.atlasInkFaint)
            Text(value)
                .font(AtlasFont.mono(16, weight: .semibold))
                .foregroundStyle(Color.atlasText)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .atlasCard()
    }

    private var tripContext: some View {
        VStack(alignment: .leading, spacing: 8) {
            AtlasSectionHeader(title: "Trip").padding(.horizontal, 2)
            HStack(spacing: 11) {
                Image(systemName: "map").foregroundStyle(Color.atlasAccent).font(.system(size: 16))
                Text(flight.trip.title)
                    .font(AtlasFont.body(15, weight: .medium))
                    .foregroundStyle(Color.atlasText)
                Spacer()
            }
            .padding(16)
            .atlasCard()
        }
    }

    private var destinationsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            AtlasSectionHeader(title: "Destinations").padding(.horizontal, 2)
            VStack(spacing: 1) {
                ForEach(vm.destinations) { d in
                    DestinationRow(destination: d)
                }
            }
            .atlasCard()
        }
    }
}

// MARK: - TripListView (Flight Logbook)

struct TripListView: View {
    @Environment(AuthManager.self) private var auth
    @State private var vm = TripListViewModel()
    @State private var selectedFlight: LoggedFlight? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                AtlasGradient.backdrop.ignoresSafeArea()

                Group {
                    if vm.isLoading && vm.flights.isEmpty {
                        skeletonList
                    } else if let err = vm.error, vm.flights.isEmpty {
                        ErrorBanner(message: err) {
                            Task { await vm.load(api: auth.api, reset: true) }
                        }
                    } else if vm.flights.isEmpty {
                        AtlasEmptyState(
                            icon: "airplane",
                            title: "No flights logged yet",
                            message: "Tap + to log your first flight and start your logbook."
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        logbookList
                    }
                }
            }
            .navigationTitle("Logbook")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        logFlightPlaceholder
                    } label: {
                        Image(systemName: "plus").foregroundStyle(Color.atlasAccent)
                    }
                }
            }
            .sheet(item: $selectedFlight) { flight in
                FlightDetailSheet(flight: flight)
                    .environment(auth)
            }
        }
        .task { await vm.load(api: auth.api, reset: true) }
    }

    private var skeletonList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(0..<5, id: \.self) { _ in FlightCardSkeleton() }
            }
            .padding(16)
        }
    }

    private var logbookList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                heroStats
                ForEach(vm.flights) { flight in
                    Button { selectedFlight = flight } label: { FlightLogCard(flight: flight) }
                        .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
        .refreshable { await vm.load(api: auth.api, reset: true) }
    }

    private var heroStats: some View {
        let total = vm.flights.count
        let kmTotal = vm.flights.compactMap { $0.leg.distanceKm }.reduce(0, +)
        return HStack(spacing: 12) {
            statCapsule(value: "\(total)", label: "Flights", tone: .accent)
            if kmTotal > 0 {
                statCapsule(
                    value: String(format: "%.0fk", kmTotal / 1_000),
                    label: "km flown",
                    tone: .cyan
                )
            }
            Spacer()
        }
        .padding(.bottom, 4)
    }

    private func statCapsule(value: String, label: String, tone: AtlasTone) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(AtlasFont.display(22, weight: .heavy))
                .foregroundStyle(tone.color)
            Text(label)
                .font(AtlasFont.mono(10))
                .foregroundStyle(Color.atlasInkFaint)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .atlasCard(radius: 14)
    }

    private var logFlightPlaceholder: some View {
        ZStack {
            Color.atlasBackground.ignoresSafeArea()
            AtlasEmptyState(
                icon: "plus.circle",
                title: "Log a Flight",
                message: "Flight logging form coming soon."
            )
        }
        .navigationTitle("Log Flight")
        .navigationBarTitleDisplayMode(.inline)
    }
}
