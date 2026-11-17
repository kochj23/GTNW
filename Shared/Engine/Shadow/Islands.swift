//
//  Islands.swift
//  Global Thermal Nuclear War
//
//  Small islands as lands of their own (3.28.0). Who held each one, and when, is in TerritoryData (generated from
//  Documentation/territories/data.py): unheld until a power claimed it, then that power's for good. An unheld island
//  is claimed by expedition; a held one is seized from its owner like a colony (war with the owner). An island where
//  nobody lives never revolts, since the only people there are your own, and every island can be developed (airstrip,
//  naval station, military base, farms, fishery, radar station).
//  Repository: https://github.com/kochj23/GTNW
//

import Foundation

struct Island {
    let id: String
    let name: String
    let lat: Double
    let lon: Double
    /// Permanent residents, thousands (0 = nobody lives there, or only a staffed station).
    let peopleK: Double
    let region: WorldRegion
    /// No outline of its own on the map: drawn as a dot.
    let dot: Bool
}

enum Islands {
    static let all: [Island] = [
        // Outlines already on the map.
        Island(id: "IOA", name: "Christmas and Cocos Islands", lat: -10.49, lon: 105.62, peopleK: 2.3, region: .oceania, dot: false),
        Island(id: "HMD", name: "Heard and McDonald Islands", lat: -53.08, lon: 73.51, peopleK: 0, region: .oceania, dot: false),
        Island(id: "PCN", name: "Pitcairn Islands", lat: -25.07, lon: -130.10, peopleK: 0.05, region: .oceania, dot: false),
        Island(id: "IOT", name: "Chagos Archipelago", lat: -7.31, lon: 72.41, peopleK: 0, region: .asia, dot: false),
        Island(id: "SGS", name: "South Georgia", lat: -54.43, lon: -36.59, peopleK: 0, region: .southAmerica, dot: false),
        Island(id: "ATF", name: "Kerguelen Islands", lat: -49.35, lon: 70.22, peopleK: 0, region: .africa, dot: false),
        Island(id: "NFK", name: "Norfolk Island", lat: -29.04, lon: 167.95, peopleK: 2.2, region: .oceania, dot: false),
        Island(id: "FLK", name: "Falkland Islands", lat: -51.70, lon: -59.52, peopleK: 3.7, region: .southAmerica, dot: false),
        Island(id: "SHN", name: "St Helena", lat: -15.97, lon: -5.71, peopleK: 5.6, region: .africa, dot: false),
        // Dots.
        Island(id: "NSI", name: "North Sentinel Island", lat: 11.55, lon: 92.24, peopleK: 0.1, region: .asia, dot: true),
        Island(id: "CPT", name: "Clipperton Island", lat: 10.30, lon: -109.22, peopleK: 0, region: .northAmerica, dot: true),
        Island(id: "BVT", name: "Bouvet Island", lat: -54.42, lon: 3.36, peopleK: 0, region: .africa, dot: true),
        Island(id: "JMN", name: "Jan Mayen", lat: 71.03, lon: -8.29, peopleK: 0, region: .europe, dot: true),
        Island(id: "SVB", name: "Svalbard", lat: 78.22, lon: 15.65, peopleK: 2.5, region: .europe, dot: true),
        Island(id: "WAK", name: "Wake Island", lat: 19.28, lon: 166.65, peopleK: 0, region: .oceania, dot: true),
        Island(id: "MID", name: "Midway Atoll", lat: 28.21, lon: -177.37, peopleK: 0, region: .oceania, dot: true),
        Island(id: "JTN", name: "Johnston Atoll", lat: 16.73, lon: -169.53, peopleK: 0, region: .oceania, dot: true),
        Island(id: "NAV", name: "Navassa Island", lat: 18.40, lon: -75.01, peopleK: 0, region: .northAmerica, dot: true),
        Island(id: "HOW", name: "Howland and Baker Islands", lat: 0.81, lon: -176.62, peopleK: 0, region: .oceania, dot: true),
        Island(id: "PLM", name: "Palmyra Atoll", lat: 5.88, lon: -162.08, peopleK: 0, region: .oceania, dot: true),
        Island(id: "EAS", name: "Easter Island", lat: -27.11, lon: -109.35, peopleK: 7.7, region: .southAmerica, dot: true),
        Island(id: "GAL", name: "Galápagos Islands", lat: -0.74, lon: -90.31, peopleK: 30, region: .southAmerica, dot: true),
        Island(id: "PIO", name: "Peter I Island", lat: -68.80, lon: -90.58, peopleK: 0, region: .southAmerica, dot: true),
        Island(id: "WRN", name: "Wrangel Island", lat: 71.24, lon: -179.42, peopleK: 0, region: .asia, dot: true),
        Island(id: "SPR", name: "Spratly Islands", lat: 10.38, lon: 114.36, peopleK: 0, region: .asia, dot: true),
        Island(id: "PCL", name: "Paracel Islands", lat: 16.50, lon: 112.00, peopleK: 0, region: .asia, dot: true),
        Island(id: "SNK", name: "Senkaku Islands", lat: 25.74, lon: 123.48, peopleK: 0, region: .asia, dot: true),
        Island(id: "MCQ", name: "Macquarie Island", lat: -54.62, lon: 158.86, peopleK: 0, region: .oceania, dot: true),
        Island(id: "AKL", name: "Auckland Islands", lat: -50.73, lon: 166.10, peopleK: 0, region: .oceania, dot: true),
        Island(id: "PEM", name: "Prince Edward Islands", lat: -46.90, lon: 37.75, peopleK: 0, region: .africa, dot: true),
        Island(id: "MNT", name: "Minami-Torishima", lat: 24.29, lon: 153.98, peopleK: 0, region: .asia, dot: true),
        Island(id: "SBL", name: "Sable Island", lat: 43.93, lon: -59.91, peopleK: 0, region: .northAmerica, dot: true),
    ]
    static let byID = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
    static let dots = all.filter(\.dot)

    /// Nobody lives there: no resistance to a landing and no revolt afterwards.
    static func uninhabited(_ id: String) -> Bool { byID[id].map { $0.peopleK == 0 } ?? false }

    static func template(_ id: String) -> CountryTemplate? {
        guard let i = byID[id] else { return nil }
        return CountryTemplate(i.id, i.name, flag: "🏝️", capital: i.name, lat: i.lat, lon: i.lon, region: i.region,
                               gov: .republic, align: .independent, gdp: 0.05, pop: max(0.0001, i.peopleK / 1000),
                               mil: 1, aggr: 0, stab: 90)
    }
}

/// What can be built on an island the President holds (one of each per island; paid from discretionary funds).
enum IslandProject: String, Codable, CaseIterable, Identifiable {
    case airstrip, navalStation, militaryBase, farms, fishery, radarStation
    var id: String { rawValue }

    var title: String {
        switch self {
        case .airstrip: return "Airstrip"
        case .navalStation: return "Naval station"
        case .militaryBase: return "Military base"
        case .farms: return "Farms and settlers"
        case .fishery: return "Fishery and port"
        case .radarStation: return "Radar station"
        }
    }
    var blurb: String {
        switch self {
        case .airstrip: return "Refuels aircraft half an ocean from home."
        case .navalStation: return "Coal, then oil, for the fleet; a harbor for patrols."
        case .militaryBase: return "Barracks and a standing garrison (+2K troops)."
        case .farms: return "Clear land and bring settlers; it starts paying its way."
        case .fishery: return "Cannery, cold store and a pier for the fishing fleet."
        case .radarStation: return "Sees bombers and missiles coming hours earlier."
        }
    }
    /// First year it can be built (aircraft and radar didn't exist before).
    var from: Int { self == .airstrip ? 1920 : self == .radarStation ? 1940 : 1789 }
    /// Cost, $B.
    var cost: Double {
        switch self {
        case .airstrip: return 0.3
        case .navalStation: return 0.5
        case .militaryBase: return 1.0
        case .farms: return 0.3
        case .fishery: return 0.2
        case .radarStation: return 0.4
        }
    }
    /// What it adds to the island's yearly income, $B.
    var income: Double {
        switch self {
        case .farms: return 0.4
        case .fishery: return 0.3
        case .navalStation: return 0.1
        default: return 0
        }
    }
    /// Military strength it adds to the President's nation (bases abroad).
    var military: Int {
        switch self {
        case .airstrip, .navalStation, .radarStation: return 1
        case .militaryBase: return 2
        case .farms, .fishery: return 0
        }
    }
}

extension GameEngine {
    /// Why a project can't be built on this island now, or nil.
    func islandProjectProblem(_ project: IslandProject, on id: String) -> String? {
        guard let gs = gameState, let c = gs.getCountry(id: id), c.territoryOf == gs.playerCountryID, !c.isDestroyed else {
            return "Not your territory."
        }
        if gs.shadow.islandProjects[id, default: []].contains(project) { return "Already built." }
        if gs.currentYear < project.from { return "Not before \(project.from)." }
        if gs.shadow.aidRemaining + 0.0001 < project.cost { return "Needs $\(String(format: "%.1f", project.cost))B; the treasury is short." }
        return nil
    }

    /// Build on one of the President's islands. Paid from discretionary funds; no action used.
    @discardableResult
    func developIsland(_ id: String, _ project: IslandProject) -> Bool {
        guard islandProjectProblem(project, on: id) == nil, let gs = gameState,
              let pi = gs.countries.firstIndex(where: { $0.id == gs.playerCountryID }) else { return false }
        gs.shadow.aidRemaining -= project.cost
        gs.shadow.islandProjects[id, default: []].append(project)
        gs.countries[pi].militaryStrength = min(100, gs.countries[pi].militaryStrength + project.military)
        if project == .militaryBase { gs.shadow.garrisons[id, default: 0] += 2 }
        let name = gs.getCountry(id: id)?.name ?? id
        gs.shadow.post("\(project.title) completed on \(name).", date: gs.currentDate, severity: 1)
        logPlayEvent("island_project", detail: ["land": id, "project": project.rawValue, "cost_b": project.cost,
                                                "game_date": PlayHistory.day(gs.currentDate)])
        self.gameState = gs
        return true
    }
}

/// One land nobody governs, for the Situation Room's UNCLAIMED list (3.28.1).
struct UnclaimedLand: Identifiable, Equatable {
    enum Kind: Int, Comparable {
        case emptyIsland, land, island, peoples
        static func < (a: Kind, b: Kind) -> Bool { a.rawValue < b.rawValue }
        var label: String {
            switch self {
            case .emptyIsland: return "Uninhabited island: plant the flag"
            case .land: return "No government, no army"
            case .island: return "Inhabited island: take by force"
            case .peoples: return "Peoples' land: take by force"
            }
        }
    }
    let id: String
    let name: String
    let kind: Kind
}

extension GameState {
    /// Every land no government in the game holds this year: unclaimed land (Antarctica and the rest), unheld islands,
    /// and peoples' lands. The easiest to take come first.
    var unclaimedLands: [UnclaimedLand] {
        let plain = unclaimedLandIDs.map { id in
            UnclaimedLand(id: id, name: id == Antarctica.id ? "Antarctica" : WorldCountriesDatabase.template(id: id)?.name ?? id, kind: .land)
        }
        let unheld = indigenousLandIDs.compactMap { id -> UnclaimedLand? in
            guard let st = preState(id) else { return nil }
            let kind: UnclaimedLand.Kind = Islands.byID[id] == nil ? .peoples : Islands.uninhabited(id) ? .emptyIsland : .island
            return UnclaimedLand(id: id, name: st.era.name, kind: kind)
        }
        return (plain + unheld).sorted { ($0.kind, $0.name) < ($1.kind, $1.name) }
    }
}
