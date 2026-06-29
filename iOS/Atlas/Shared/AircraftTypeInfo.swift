import Foundation

/// Friendly name + one-line description for common ICAO aircraft type designators.
/// Curated from publicly documented manufacturer specs and the ICAO DOC 8643
/// aircraft type designator list (public reference). Used by `AircraftTypePage`.
struct AircraftTypeInfo {
    let name: String
    let summary: String

    static func lookup(_ typeCode: String?) -> AircraftTypeInfo? {
        guard let typeCode else { return nil }
        let key = typeCode.uppercased()
        if let exact = table[key] { return exact }
        // Fall back to a 3-char family prefix (e.g. A20N -> A20, B38M -> B38).
        let prefix = String(key.prefix(3))
        return table[prefix]
    }

    private static let table: [String: AircraftTypeInfo] = [
        "A319": .init(name: "Airbus A319", summary: "Shortened A320-family narrowbody, ~120–150 seats."),
        "A320": .init(name: "Airbus A320", summary: "Best-selling narrowbody twinjet, ~150–180 seats."),
        "A20N": .init(name: "Airbus A320neo", summary: "Re-engined A320 with higher efficiency and range."),
        "A321": .init(name: "Airbus A321", summary: "Stretched A320 family, ~185–240 seats."),
        "A21N": .init(name: "Airbus A321neo", summary: "Long-range re-engined A321 narrowbody."),
        "A332": .init(name: "Airbus A330-200", summary: "Long-range widebody twinjet."),
        "A333": .init(name: "Airbus A330-300", summary: "Stretched twin-aisle widebody for medium-long haul."),
        "A339": .init(name: "Airbus A330-900neo", summary: "Re-engined A330 widebody with new wingtips."),
        "A343": .init(name: "Airbus A340-300", summary: "Four-engine long-haul widebody."),
        "A346": .init(name: "Airbus A340-600", summary: "Stretched four-engine ultra-long-haul widebody."),
        "A359": .init(name: "Airbus A350-900", summary: "Composite long-haul widebody twinjet."),
        "A35K": .init(name: "Airbus A350-1000", summary: "Largest A350 variant for ultra-long-haul."),
        "A388": .init(name: "Airbus A380-800", summary: "Double-deck four-engine superjumbo."),
        "B712": .init(name: "Boeing 717", summary: "Short-haul regional twinjet (ex-MD-95)."),
        "B733": .init(name: "Boeing 737-300", summary: "Classic-generation narrowbody twinjet."),
        "B737": .init(name: "Boeing 737-700", summary: "Next-Generation narrowbody, ~125–140 seats."),
        "B738": .init(name: "Boeing 737-800", summary: "Most common 737 NG, ~160–190 seats."),
        "B739": .init(name: "Boeing 737-900", summary: "Stretched 737 Next-Generation."),
        "B38M": .init(name: "Boeing 737 MAX 8", summary: "Re-engined 737 with higher efficiency."),
        "B39M": .init(name: "Boeing 737 MAX 9", summary: "Stretched 737 MAX narrowbody."),
        "B744": .init(name: "Boeing 747-400", summary: "Iconic four-engine widebody jumbo jet."),
        "B748": .init(name: "Boeing 747-8", summary: "Latest, longest 747 variant."),
        "B752": .init(name: "Boeing 757-200", summary: "High-performance narrowbody twinjet."),
        "B763": .init(name: "Boeing 767-300", summary: "Mid-size long-range widebody twinjet."),
        "B772": .init(name: "Boeing 777-200", summary: "Long-haul widebody twinjet."),
        "B77L": .init(name: "Boeing 777-200LR", summary: "Ultra-long-range 777 variant."),
        "B77W": .init(name: "Boeing 777-300ER", summary: "Extended-range stretched 777."),
        "B788": .init(name: "Boeing 787-8", summary: "Composite long-haul Dreamliner twinjet."),
        "B789": .init(name: "Boeing 787-9", summary: "Stretched long-range Dreamliner."),
        "B78X": .init(name: "Boeing 787-10", summary: "Largest Dreamliner variant."),
        "BCS1": .init(name: "Airbus A220-100", summary: "Composite-wing small narrowbody (ex-Bombardier CS100)."),
        "BCS3": .init(name: "Airbus A220-300", summary: "Stretched A220 narrowbody (ex-CS300)."),
        "E145": .init(name: "Embraer ERJ-145", summary: "50-seat regional jet."),
        "E170": .init(name: "Embraer E170", summary: "Small regional jet, ~70 seats."),
        "E75L": .init(name: "Embraer E175", summary: "Popular ~76-seat regional jet."),
        "E190": .init(name: "Embraer E190", summary: "Regional/short-haul jet, ~100 seats."),
        "E195": .init(name: "Embraer E195", summary: "Stretched E-Jet, ~120 seats."),
        "CRJ2": .init(name: "Bombardier CRJ200", summary: "50-seat regional jet."),
        "CRJ7": .init(name: "Bombardier CRJ700", summary: "~70-seat regional jet."),
        "CRJ9": .init(name: "Bombardier CRJ900", summary: "~90-seat regional jet."),
        "DH8D": .init(name: "De Havilland Dash 8-400", summary: "High-speed regional turboprop."),
        "AT72": .init(name: "ATR 72", summary: "Twin-engine regional turboprop."),
        "AT76": .init(name: "ATR 72-600", summary: "Modernized ATR 72 regional turboprop."),
        "C208": .init(name: "Cessna 208 Caravan", summary: "Single-engine utility turboprop."),
        "PC12": .init(name: "Pilatus PC-12", summary: "Single-engine business/utility turboprop."),
        "C172": .init(name: "Cessna 172 Skyhawk", summary: "Four-seat single-engine light aircraft."),
        "C152": .init(name: "Cessna 152", summary: "Two-seat single-engine trainer."),
        "SR22": .init(name: "Cirrus SR22", summary: "High-performance single-engine light aircraft."),
        "GLF6": .init(name: "Gulfstream G650", summary: "Ultra-long-range business jet."),
        "GLF5": .init(name: "Gulfstream G550", summary: "Long-range business jet."),
        "C68A": .init(name: "Cessna Citation Latitude", summary: "Mid-size business jet."),
        "CL60": .init(name: "Bombardier Challenger 600", summary: "Large-cabin business jet."),
        "H25B": .init(name: "Hawker 800", summary: "Mid-size business jet."),
        "EC35": .init(name: "Airbus H135", summary: "Light twin-engine helicopter."),
        "EC30": .init(name: "Airbus H130", summary: "Single-engine light helicopter."),
        "B06": .init(name: "Bell 206", summary: "Light single-engine helicopter."),
        "S76": .init(name: "Sikorsky S-76", summary: "Medium twin-engine helicopter."),
        "F16": .init(name: "Lockheed Martin F-16", summary: "Single-engine multirole fighter."),
        "F35": .init(name: "Lockheed Martin F-35", summary: "Stealth multirole fighter."),
        "C130": .init(name: "Lockheed C-130 Hercules", summary: "Four-engine military transport turboprop."),
        "K35R": .init(name: "Boeing KC-135 Stratotanker", summary: "Aerial refueling tanker."),
    ]
}
