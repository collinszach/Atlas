import SwiftUI
import MapKit

// MARK: - Layer state

struct MapLayers: Equatable {
    enum Style: String, CaseIterable, Identifiable {
        case dark, satellite, hybrid
        var id: String { rawValue }
        var label: String {
            switch self {
            case .dark: return "Standard"
            case .satellite: return "Satellite"
            case .hybrid: return "Hybrid"
            }
        }
    }

    var style: Style = .dark
    var weatherRadar = false
    var weatherOpacity: Double = 0.6
    var dayNight = false
    var airports = true
}

// MARK: - MKMapView-backed live map

struct LiveMapView: UIViewRepresentable {
    var aircraft: [OverheadAircraft]
    var airports: [Airport]
    var layers: MapLayers
    @Binding var selected: OverheadAircraft?
    @Binding var selectedAirport: Airport?
    let initialCenter: CLLocationCoordinate2D
    let initialSpanKm: Double
    var onRegionChange: (CLLocationCoordinate2D, Double) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> MKMapView {
        let mv = MKMapView()
        mv.delegate = context.coordinator
        mv.showsCompass = true
        mv.showsUserLocation = true
        mv.pointOfInterestFilter = .excludingAll
        mv.register(AircraftAnnotationView.self,
                    forAnnotationViewWithReuseIdentifier: AircraftAnnotationView.reuse)
        mv.register(AirportAnnotationView.self,
                    forAnnotationViewWithReuseIdentifier: AirportAnnotationView.reuse)
        let delta = max(0.02, initialSpanKm / 111.0)
        mv.setRegion(MKCoordinateRegion(
            center: initialCenter,
            span: MKCoordinateSpan(latitudeDelta: delta, longitudeDelta: delta)
        ), animated: false)
        context.coordinator.applyStyle(layers.style, to: mv)
        return mv
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        let coord = context.coordinator
        coord.parent = self

        if coord.appliedStyle != layers.style {
            coord.applyStyle(layers.style, to: mapView)
        }
        coord.syncAircraft(aircraft, selectedHex: selected?.hex, on: mapView)
        coord.syncAirports(layers.airports ? airports : [], on: mapView)
        coord.syncWeather(layers, on: mapView)
        coord.syncTerminator(enabled: layers.dayNight, on: mapView)

        if selected == nil {
            for ann in mapView.selectedAnnotations where ann is AircraftAnnotation {
                mapView.deselectAnnotation(ann, animated: true)
            }
        }
    }

    // MARK: Coordinator

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: LiveMapView
        var appliedStyle: MapLayers.Style?

        private var weatherOverlay: MKTileOverlay?
        private weak var weatherRenderer: MKTileOverlayRenderer?
        private var fetchingWeather = false
        private var terminatorOverlay: MKPolygon?
        private var lastTerminatorRefresh = Date.distantPast

        init(_ parent: LiveMapView) { self.parent = parent }

        func applyStyle(_ style: MapLayers.Style, to mapView: MKMapView) {
            switch style {
            case .dark:
                let cfg = MKStandardMapConfiguration(elevationStyle: .flat, emphasisStyle: .muted)
                cfg.pointOfInterestFilter = .excludingAll
                cfg.showsTraffic = false
                mapView.preferredConfiguration = cfg
                mapView.overrideUserInterfaceStyle = .dark
            case .satellite:
                mapView.preferredConfiguration = MKImageryMapConfiguration(elevationStyle: .flat)
                mapView.overrideUserInterfaceStyle = .dark
            case .hybrid:
                let cfg = MKHybridMapConfiguration(elevationStyle: .flat)
                cfg.pointOfInterestFilter = .excludingAll
                mapView.preferredConfiguration = cfg
                mapView.overrideUserInterfaceStyle = .dark
            }
            appliedStyle = style
        }

        // MARK: Aircraft annotations (diffed by hex)

        func syncAircraft(_ aircraft: [OverheadAircraft], selectedHex: String?, on mapView: MKMapView) {
            let existing = mapView.annotations.compactMap { $0 as? AircraftAnnotation }
            var byHex = Dictionary(existing.map { ($0.hex, $0) }, uniquingKeysWith: { a, _ in a })

            // Update existing annotations in place, collect adds, and apply add/remove
            // in batches AFTER the loop. Mutating mapView.annotations while a coordinate
            // KVO is being processed makes MapKit's annotation manager abort with a
            // "collection mutated while enumerated" exception.
            var toAdd: [AircraftAnnotation] = []
            for ac in aircraft {
                guard let c = ac.coordinate else { continue }
                let isSel = ac.hex == selectedHex
                if let ann = byHex.removeValue(forKey: ac.hex) {
                    if ann.coordinate.latitude != c.latitude || ann.coordinate.longitude != c.longitude {
                        ann.coordinate = c
                    }
                    ann.aircraft = ac
                    ann.isSelected = isSel
                    if let v = mapView.view(for: ann) as? AircraftAnnotationView { v.configure(ann) }
                } else {
                    toAdd.append(AircraftAnnotation(aircraft: ac, selected: isSel))
                }
            }
            if !byHex.isEmpty { mapView.removeAnnotations(Array(byHex.values)) }
            if !toAdd.isEmpty { mapView.addAnnotations(toAdd) }
        }

        // MARK: Airport annotations (diffed by icao)

        func syncAirports(_ airports: [Airport], on mapView: MKMapView) {
            let existing = mapView.annotations.compactMap { $0 as? AirportAnnotation }
            var byIcao = Dictionary(existing.map { ($0.airport.icao, $0) }, uniquingKeysWith: { a, _ in a })

            var toAdd: [AirportAnnotation] = []
            for ap in airports {
                if byIcao.removeValue(forKey: ap.icao) == nil {
                    toAdd.append(AirportAnnotation(ap))
                }
            }
            if !byIcao.isEmpty { mapView.removeAnnotations(Array(byIcao.values)) }
            if !toAdd.isEmpty { mapView.addAnnotations(toAdd) }
        }

        // MARK: Weather radar (RainViewer)

        func syncWeather(_ layers: MapLayers, on mapView: MKMapView) {
            if layers.weatherRadar {
                weatherRenderer?.alpha = layers.weatherOpacity
                weatherRenderer?.setNeedsDisplay()
                if weatherOverlay == nil, !fetchingWeather {
                    fetchWeatherOverlay(on: mapView)
                }
            } else if let overlay = weatherOverlay {
                mapView.removeOverlay(overlay)
                weatherOverlay = nil
                weatherRenderer = nil
            }
        }

        private func fetchWeatherOverlay(on mapView: MKMapView) {
            fetchingWeather = true
            Task { [weak self, weak mapView] in
                defer { self?.fetchingWeather = false }
                guard let template = await RainViewer.latestTileTemplate() else { return }
                guard let self, let mapView, self.parent.layers.weatherRadar else { return }
                await MainActor.run {
                    let overlay = MKTileOverlay(urlTemplate: template)
                    overlay.canReplaceMapContent = false
                    overlay.maximumZ = 14
                    self.weatherOverlay = overlay
                    mapView.addOverlay(overlay, level: .aboveLabels)
                }
            }
        }

        // MARK: Day-night terminator

        func syncTerminator(enabled: Bool, on mapView: MKMapView) {
            if enabled {
                let stale = Date().timeIntervalSince(lastTerminatorRefresh) > 600
                if terminatorOverlay == nil || stale {
                    if let old = terminatorOverlay { mapView.removeOverlay(old) }
                    let poly = Terminator.nightPolygon(at: Date())
                    terminatorOverlay = poly
                    lastTerminatorRefresh = Date()
                    mapView.addOverlay(poly, level: .aboveRoads)
                }
            } else if let old = terminatorOverlay {
                mapView.removeOverlay(old)
                terminatorOverlay = nil
            }
        }

        // MARK: MKMapViewDelegate

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }
            if let airport = annotation as? AirportAnnotation {
                let v = mapView.dequeueReusableAnnotationView(
                    withIdentifier: AirportAnnotationView.reuse, for: airport)
                v.annotation = airport
                return v
            }
            guard let ac = annotation as? AircraftAnnotation else { return nil }
            let v = mapView.dequeueReusableAnnotationView(
                withIdentifier: AircraftAnnotationView.reuse, for: ac) as! AircraftAnnotationView
            v.configure(ac)
            return v
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let tile = overlay as? MKTileOverlay {
                let r = MKTileOverlayRenderer(tileOverlay: tile)
                r.alpha = parent.layers.weatherOpacity
                weatherRenderer = r
                return r
            }
            if let poly = overlay as? MKPolygon {
                let r = MKPolygonRenderer(polygon: poly)
                r.fillColor = UIColor.black.withAlphaComponent(0.30)
                r.strokeColor = UIColor(white: 0.45, alpha: 0.25)
                r.lineWidth = 0.5
                return r
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            if let airport = view.annotation as? AirportAnnotation {
                mapView.deselectAnnotation(airport, animated: false)
                parent.selectedAirport = airport.airport
                return
            }
            guard let ann = view.annotation as? AircraftAnnotation else { return }
            parent.selected = ann.aircraft
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            let region = mapView.region
            parent.onRegionChange(region.center, region.span.latitudeDelta * 111.0)
        }
    }
}

// MARK: - Annotation + view

final class AircraftAnnotation: NSObject, MKAnnotation {
    let hex: String
    @objc dynamic var coordinate: CLLocationCoordinate2D
    var aircraft: OverheadAircraft
    var isSelected: Bool

    init(aircraft: OverheadAircraft, selected: Bool) {
        self.hex = aircraft.hex
        self.aircraft = aircraft
        self.coordinate = aircraft.coordinate ?? CLLocationCoordinate2D()
        self.isSelected = selected
    }
}

final class AircraftAnnotationView: MKAnnotationView {
    static let reuse = "plane"

    func configure(_ a: AircraftAnnotation) {
        // No clustering: real silhouettes only, never a count bubble. When markers
        // overlap, `.circle` collision hides the lower-priority one — so density is
        // resolved by keeping the aircraft that matter (emergency → notable/military
        // → higher traffic), and the rest reveal as you zoom in.
        collisionMode = .circle
        centerOffset = .zero
        canShowCallout = false
        displayPriority = Self.priority(for: a)
        image = MarkerImageCache.image(for: a.aircraft, selected: a.isSelected)
    }

    private static func priority(for a: AircraftAnnotation) -> MKFeatureDisplayPriority {
        let ac = a.aircraft
        if a.isSelected || ac.isEmergency { return .required }              // 1000
        if ac.isMilitary || !ac.matches.isEmpty { return .init(rawValue: 880) }
        // Base tier 600–750: higher-altitude traffic stays legible when the map is busy.
        let altBoost = min(150, Float(ac.altitude ?? 0) / 280)
        return .init(rawValue: 600 + altBoost)
    }
}

// MARK: - Airport annotation + view

final class AirportAnnotation: NSObject, MKAnnotation {
    let airport: Airport
    @objc dynamic var coordinate: CLLocationCoordinate2D
    var title: String? { airport.code }
    var subtitle: String? { airport.name }

    init(_ airport: Airport) {
        self.airport = airport
        self.coordinate = airport.coordinate
    }
}

final class AirportAnnotationView: MKAnnotationView {
    static let reuse = "airport"

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        // Static airports cluster awkwardly with planes; keep them independent and
        // let collision resolution hide them under aircraft (lower display priority).
        collisionMode = .circle
        canShowCallout = false
        centerOffset = .zero
        displayPriority = .defaultLow
        image = AirportGlyph.image
    }
}

/// Small muted tower/building glyph drawn once into a UIImage.
enum AirportGlyph {
    static let image: UIImage = {
        let size = CGSize(width: 26, height: 26)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            let rect = CGRect(x: 2, y: 2, width: 22, height: 22)
            let circle = UIBezierPath(ovalIn: rect)
            UIColor(Color.atlasSurface2).withAlphaComponent(0.92).setFill()
            circle.fill()
            UIColor(Color.atlasBorderStrong).setStroke()
            circle.lineWidth = 1
            circle.stroke()
            let cfg = UIImage.SymbolConfiguration(pointSize: 12, weight: .bold)
            if let sym = UIImage(systemName: "airplane", withConfiguration: cfg)?
                .withTintColor(UIColor(Color.atlasInk2), renderingMode: .alwaysOriginal) {
                let symRect = CGRect(
                    x: (size.width - sym.size.width) / 2,
                    y: (size.height - sym.size.height) / 2,
                    width: sym.size.width, height: sym.size.height
                )
                sym.draw(in: symRect)
            }
        }
    }()
}

// MARK: - SwiftUI marker → cached UIImage

enum MarkerImageCache {
    private static var cache: [String: UIImage] = [:]

    @MainActor
    static func image(for ac: OverheadAircraft, selected: Bool) -> UIImage {
        let category = AircraftCategory(typeCode: ac.type, isMilitary: ac.isMilitary)
        // Quantize heading to 5° buckets so the cache stays bounded
        // (shapes × 72 × tones × 2) instead of growing per whole degree.
        let headingBucket = Int(((ac.track ?? 0) / 5).rounded()) % 72
        let key = "\(category.shape)-\(headingBucket)-\(ac.tone)-\(selected)"
        if let cached = cache[key] { return cached }

        let marker = AircraftMarker(
            category: category,
            heading: ac.track,
            color: selected ? Color.atlasAccent : ac.tone.color,
            baseSize: 19,
            selected: selected
        )
        .frame(width: 48, height: 48)

        let renderer = ImageRenderer(content: marker)
        renderer.scale = UIScreen.main.scale
        let img = renderer.uiImage ?? UIImage()
        cache[key] = img
        return img
    }
}

// MARK: - RainViewer tile source (no API key)

enum RainViewer {
    private struct MapsResponse: Decodable {
        let host: String
        let radar: Radar
        struct Radar: Decodable {
            let past: [Frame]
            let nowcast: [Frame]?
        }
        struct Frame: Decodable { let path: String }
    }

    /// Fetches the latest radar frame and returns an `MKTileOverlay` URL template.
    static func latestTileTemplate() async -> String? {
        let url = URL(string: "https://api.rainviewer.com/public/weather-maps.json")!
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(MapsResponse.self, from: data)
            guard let frame = decoded.radar.past.last ?? decoded.radar.nowcast?.first else { return nil }
            // `host` already includes the https:// scheme. color scheme 2 (universal blue), smooth=1, snow=1
            return "\(decoded.host)\(frame.path)/256/{z}/{x}/{y}/2/1_1.png"
        } catch {
            return nil
        }
    }
}

// MARK: - Day-night terminator math

enum Terminator {
    /// Night-side polygon derived from the current subsolar point.
    static func nightPolygon(at date: Date) -> MKPolygon {
        let jd = julianDay(date)
        let n = jd - 2_451_545.0
        let rad = Double.pi / 180

        let meanLong = (280.460 + 0.9856474 * n).truncatingRemainder(dividingBy: 360)
        let meanAnom = (357.528 + 0.9856003 * n).truncatingRemainder(dividingBy: 360) * rad
        let lambda = (meanLong + 1.915 * sin(meanAnom) + 0.020 * sin(2 * meanAnom)) * rad
        let epsilon = (23.439 - 0.0000004 * n) * rad

        let declination = asin(sin(epsilon) * sin(lambda))                       // radians
        let ra = atan2(cos(epsilon) * sin(lambda), cos(lambda)) / rad            // degrees
        var gmst = (280.46061837 + 360.98564736629 * n).truncatingRemainder(dividingBy: 360)
        if gmst < 0 { gmst += 360 }
        let subsolarLon = normalizeLon(ra - gmst)

        var coords: [CLLocationCoordinate2D] = []
        var lon = -180.0
        while lon <= 180.0 {
            let hourAngle = (lon - subsolarLon) * rad
            // terminator latitude where solar elevation == 0
            let lat = atan(-cos(hourAngle) / tan(declination)) / rad
            coords.append(CLLocationCoordinate2D(latitude: lat, longitude: lon))
            lon += 1.0
        }

        // Close the band toward the pole that is currently in darkness.
        let nightPoleLat = declination >= 0 ? -90.0 : 90.0
        coords.append(CLLocationCoordinate2D(latitude: nightPoleLat, longitude: 180))
        coords.append(CLLocationCoordinate2D(latitude: nightPoleLat, longitude: -180))

        return MKPolygon(coordinates: coords, count: coords.count)
    }

    private static func julianDay(_ date: Date) -> Double {
        date.timeIntervalSince1970 / 86_400.0 + 2_440_587.5
    }

    private static func normalizeLon(_ lon: Double) -> Double {
        var l = lon.truncatingRemainder(dividingBy: 360)
        if l > 180 { l -= 360 }
        if l < -180 { l += 360 }
        return l
    }
}
