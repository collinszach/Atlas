import Foundation

@MainActor
@Observable
final class PlanViewModel {
    var plannedTrips: [Trip] = []
    var bucketList: [BucketListItem] = []
    var isLoading = true
    var error: String? = nil

    func load(api: APIClient) async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            async let tripResponse = api.trips(status: nil)
            async let bucket = api.bucketList()
            let (trips, bl) = try await (tripResponse, bucket)
            plannedTrips = trips.items.filter { $0.status == .planned || $0.status == .dream }
            bucketList = bl
        } catch {
            self.error = error.localizedDescription
        }
    }
}
