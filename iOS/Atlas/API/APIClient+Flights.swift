import Foundation

// MARK: - Flight logbook helpers

extension APIClient {
    /// Fetches all trips then their flight-type transport legs concurrently.
    /// Returns a flat array of (leg, trip) pairs sorted newest-first by departure.
    func allFlights() async throws -> [(leg: TransportLeg, trip: Trip)] {
        var allTrips: [Trip] = []
        var page = 1
        while true {
            let batch = try await trips(page: page)
            allTrips.append(contentsOf: batch.items)
            if allTrips.count >= batch.total || batch.items.isEmpty { break }
            page += 1
        }

        var pairs: [(leg: TransportLeg, trip: Trip)] = []
        try await withThrowingTaskGroup(of: [(leg: TransportLeg, trip: Trip)].self) { group in
            for trip in allTrips {
                group.addTask { [self] in
                    let legs = try await self.transportLegs(tripId: trip.id)
                    return legs.filter { $0.type == "flight" }.map { (leg: $0, trip: trip) }
                }
            }
            for try await batch in group {
                pairs.append(contentsOf: batch)
            }
        }

        return pairs.sorted {
            ($0.leg.departureAt ?? "") > ($1.leg.departureAt ?? "")
        }
    }
}
