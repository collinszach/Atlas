import Foundation
import MapKit

@MainActor
@Observable
final class MapViewModel {
    var countries: [MapCountry] = []
    var cities: [MapCity] = []
    var arcs: [MapArc] = []
    var isLoading = false
    var error: String? = nil

    func load(api: APIClient) async {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            async let c = api.mapCountries()
            async let ci = api.mapCities()
            async let a = api.mapArcs()
            (countries, cities, arcs) = try await (c, ci, a)
        } catch {
            self.error = error.localizedDescription
        }
    }
}

extension MapCity {
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

extension MapArc {
    var originCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: originLat, longitude: originLng)
    }
    var destCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: destLat, longitude: destLng)
    }
    var arcCoordinates: [CLLocationCoordinate2D] {
        let steps = 60
        return (0...steps).map { i in
            let t = Double(i) / Double(steps)
            let lat = originLat + (destLat - originLat) * t
            let lng = originLng + (destLng - originLng) * t
            return CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }
    }
}
