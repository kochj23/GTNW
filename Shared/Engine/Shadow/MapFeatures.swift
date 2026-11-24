//
//  MapFeatures.swift
//  Global Thermal Nuclear War
//
//  3.36.0: rename the map and the government. A small set of named geography (seas, gulfs, bays, straits, canals,
//  mountains and ranges) with a position and its English name by era ("Peak XV" before 1856, "Formosa Strait"
//  before 1945; a canal only once it is dug), and the President's own departments by era (the Department of War
//  until 1947, the Department of Defense from 1949; other nations have ministries). The President may rename any of
//  them through the rename card (`RenameTarget.feature` / `.department`, the same content check as every name).
//  Other nations decide whether to use a new feature name (relations nudge); the news gives both names; the
//  President's own map labels show the new name. A department's new name is the President's alone: the statute keeps
//  the old one, and Congress grumbles.
//  Repository: https://github.com/kochj23/GTNW
//

import Foundation

enum MapFeatureKind: String, Codable, Sendable {
    case sea, gulf, bay, strait, canal, mountain, range

    var label: String { rawValue }
}

/// A named feature of the map.
struct MapFeature: Identifiable, Sendable {
    let id: String
    let kind: MapFeatureKind
    let lat: Double
    let lon: Double
    /// English names by era: the first row whose `until` is later than the year.
    let names: [(until: Int, name: String)]
    /// The first year it exists (a canal).
    let since: Int
    /// Nations on its shores or slopes (they care most about its name).
    let shores: [String]

    func name(in year: Int) -> String { names.first { year < $0.until }?.name ?? names.last?.name ?? id }
    func exists(in year: Int) -> Bool { year >= since }
}

enum MapFeatures {
    static let all: [MapFeature] = [
        f("GEO_GULF_MEXICO", .gulf, 25, -90, "Gulf of Mexico", shores: ["USA", "MEX", "CUB"]),
        f("GEO_CARIBBEAN", .sea, 15, -75, "Caribbean Sea", shores: ["CUB", "VEN", "COL", "PAN", "JAM", "HTI", "DOM", "NIC", "HND"]),
        f("GEO_GULF_ALASKA", .gulf, 57.5, -145, "Gulf of Alaska", shores: ["USA"]),
        f("GEO_HUDSON_BAY", .bay, 60, -85, "Hudson Bay", shores: ["CAN"]),
        f("GEO_BERING", .strait, 66, -169, "Bering Strait", shores: ["USA", "RUS"]),
        f("GEO_PANAMA_CANAL", .canal, 9.1, -79.7, "Panama Canal", since: 1914, shores: ["PAN"]),
        f("GEO_GIBRALTAR", .strait, 36, -5.6, "Strait of Gibraltar", shores: ["ESP", "MAR", "GBR"]),
        f("GEO_CHANNEL", .strait, 50, -2, "English Channel", shores: ["GBR", "FRA"]),
        f("GEO_NORTH_SEA", .sea, 56, 3, [(1910, "German Ocean"), (9999, "North Sea")], shores: ["GBR", "NOR", "DNK", "DEU", "NLD", "BEL"]),
        f("GEO_BALTIC", .sea, 58, 20, "Baltic Sea", shores: ["SWE", "FIN", "RUS", "EST", "LVA", "LTU", "POL", "DEU", "DNK"]),
        f("GEO_MED", .sea, 35, 18, "Mediterranean Sea", shores: ["ESP", "FRA", "ITA", "GRC", "TUR", "EGY", "LBY", "TUN", "DZA", "ISR"]),
        f("GEO_BLACK_SEA", .sea, 43, 34, "Black Sea", shores: ["TUR", "RUS", "UKR", "ROU", "BGR", "GEO"]),
        f("GEO_BOSPORUS", .strait, 41.1, 29.05, "Bosporus", shores: ["TUR"]),
        f("GEO_SUEZ", .canal, 30.5, 32.35, "Suez Canal", since: 1869, shores: ["EGY"]),
        f("GEO_RED_SEA", .sea, 20, 38.5, "Red Sea", shores: ["EGY", "SAU", "SDN", "ERI", "YEM"]),
        f("GEO_GULF_ADEN", .gulf, 12.5, 48, "Gulf of Aden", shores: ["YEM", "SOM", "DJI"]),
        f("GEO_PERSIAN_GULF", .gulf, 27, 51, "Persian Gulf", shores: ["IRN", "SAU", "KWT", "IRQ", "ARE", "QAT", "BHR"]),
        f("GEO_HORMUZ", .strait, 26.6, 56.3, "Strait of Hormuz", shores: ["IRN", "OMN", "ARE"]),
        f("GEO_ARABIAN_SEA", .sea, 15, 63, "Arabian Sea", shores: ["IND", "PAK", "OMN", "YEM"]),
        f("GEO_BAY_BENGAL", .bay, 15, 88, "Bay of Bengal", shores: ["IND", "BGD", "MMR", "LKA"]),
        f("GEO_MALACCA", .strait, 3.5, 100.5, "Strait of Malacca", shores: ["MYS", "IDN", "SGP"]),
        f("GEO_S_CHINA_SEA", .sea, 12, 114, "South China Sea", shores: ["CHN", "VNM", "PHL", "MYS", "BRN", "IDN"]),
        f("GEO_TAIWAN_STR", .strait, 24.5, 119.5, [(1945, "Formosa Strait"), (9999, "Taiwan Strait")], shores: ["CHN", "TWN"]),
        f("GEO_EVEREST", .mountain, 27.99, 86.93, [(1856, "Peak XV"), (9999, "Mount Everest")], shores: ["NPL", "CHN"]),
        f("GEO_KILIMANJARO", .mountain, -3.07, 37.35, "Mount Kilimanjaro", shores: ["TZA"]),
        f("GEO_ALPS", .range, 46.5, 10, "the Alps", shores: ["CHE", "FRA", "ITA", "AUT", "DEU"]),
        f("GEO_ROCKIES", .range, 45, -112, "the Rocky Mountains", shores: ["USA", "CAN"]),
        f("GEO_ANDES", .range, -20, -68, "the Andes", shores: ["PER", "CHL", "ARG", "BOL", "ECU", "COL"]),
        f("GEO_URALS", .range, 60, 60, "the Ural Mountains", shores: ["RUS"]),
    ]

    private static func f(_ id: String, _ k: MapFeatureKind, _ lat: Double, _ lon: Double, _ name: String, since: Int = 0, shores: [String]) -> MapFeature {
        MapFeature(id: id, kind: k, lat: lat, lon: lon, names: [(9999, name)], since: since, shores: shores)
    }
    private static func f(_ id: String, _ k: MapFeatureKind, _ lat: Double, _ lon: Double, _ names: [(Int, String)], since: Int = 0, shores: [String]) -> MapFeature {
        MapFeature(id: id, kind: k, lat: lat, lon: lon, names: names.map { (until: $0.0, name: $0.1) }, since: since, shores: shores)
    }

    static func feature(_ id: String) -> MapFeature? { all.first { $0.id == id } }

    /// The feature a typed name means this year: its era name, any of its names, or the name the President gave it.
    static func match(_ raw: String, in gs: GameState) -> MapFeature? {
        var n = CommandParser.normalize(raw)
        if n.hasPrefix("the ") { n = String(n.dropFirst(4)) }
        guard !n.isEmpty else { return nil }
        func norm(_ s: String) -> String {
            let t = CommandParser.normalize(s)
            return t.hasPrefix("the ") ? String(t.dropFirst(4)) : t
        }
        let live = all.filter { $0.exists(in: gs.currentYear) }
        if let f = live.first(where: { norm($0.name(in: gs.currentYear)) == n }) { return f }
        if let f = live.first(where: { gs.shadow.powerPlays.featureNames[$0.id].map(norm) == n }) { return f }
        return live.first { $0.names.contains { norm($0.name) == n } }
    }

    /// The name the President's own map shows.
    static func shownName(_ f: MapFeature, in gs: GameState) -> String {
        gs.shadow.powerPlays.featureNames[f.id] ?? f.name(in: gs.currentYear)
    }

    /// Both names for the news: "Gulf of X (Gulf of Mexico)", or the one name when it is unchanged.
    static func newsName(_ f: MapFeature, in gs: GameState) -> String {
        let real = f.name(in: gs.currentYear)
        guard let mine = gs.shadow.powerPlays.featureNames[f.id], mine != real else { return real }
        return "\(mine) (\(real))"
    }
}

// MARK: - Departments

struct Department: Identifiable, Sendable {
    let id: String
    let name: String
    let from: Int
    let until: Int
    /// The cabinet post that heads it (AdviceEngine role key), if one sits in the Situation Room.
    let role: String?

    func exists(in year: Int) -> Bool { year >= from && year < until }
}

enum Departments {
    static let american: [Department] = [
        Department(id: "DEPT_STATE", name: "Department of State", from: 1789, until: 9999, role: "state"),
        Department(id: "DEPT_TREASURY", name: "Department of the Treasury", from: 1789, until: 9999, role: "economic"),
        Department(id: "DEPT_WAR", name: "Department of War", from: 1789, until: 1947, role: "defense"),
        Department(id: "DEPT_NAVY", name: "Department of the Navy", from: 1798, until: 1947, role: nil),
        Department(id: "DEPT_NME", name: "National Military Establishment", from: 1947, until: 1949, role: "defense"),
        Department(id: "DEPT_DEFENSE", name: "Department of Defense", from: 1949, until: 9999, role: "defense"),
        Department(id: "DEPT_INTERIOR", name: "Department of the Interior", from: 1849, until: 9999, role: nil),
        Department(id: "DEPT_JUSTICE", name: "Department of Justice", from: 1870, until: 9999, role: nil),
        Department(id: "DEPT_AGRICULTURE", name: "Department of Agriculture", from: 1889, until: 9999, role: nil),
        Department(id: "DEPT_COMMERCE", name: "Department of Commerce", from: 1913, until: 9999, role: nil),
        Department(id: "DEPT_LABOR", name: "Department of Labor", from: 1913, until: 9999, role: nil),
        Department(id: "DEPT_ENERGY", name: "Department of Energy", from: 1977, until: 9999, role: nil),
        Department(id: "DEPT_EDUCATION", name: "Department of Education", from: 1979, until: 9999, role: nil),
        Department(id: "DEPT_HOMELAND", name: "Department of Homeland Security", from: 2002, until: 9999, role: nil),
    ]
    static let ministries: [Department] = [
        Department(id: "MIN_FOREIGN", name: "Ministry of Foreign Affairs", from: 0, until: 9999, role: "state"),
        Department(id: "MIN_FINANCE", name: "Ministry of Finance", from: 0, until: 9999, role: "economic"),
        Department(id: "MIN_WAR", name: "Ministry of War", from: 0, until: 1947, role: "defense"),
        Department(id: "MIN_DEFENSE", name: "Ministry of Defense", from: 1947, until: 9999, role: "defense"),
        Department(id: "MIN_INTERIOR", name: "Ministry of the Interior", from: 0, until: 9999, role: nil),
        Department(id: "MIN_JUSTICE", name: "Ministry of Justice", from: 0, until: 9999, role: nil),
    ]

    /// The player's departments this year.
    static func current(in gs: GameState) -> [Department] {
        (gs.playerCountryID == "USA" ? american : ministries).filter { $0.exists(in: gs.currentYear) }
    }

    static func department(_ id: String) -> Department? { (american + ministries).first { $0.id == id } }

    /// The department a typed name means: its name ("Department of Defense", "Defense Department", "the Pentagon"
    /// for Defense), or the name the President gave it.
    static func match(_ raw: String, in gs: GameState) -> Department? {
        var n = CommandParser.normalize(raw)
        if n.hasPrefix("the ") { n = String(n.dropFirst(4)) }
        guard !n.isEmpty else { return nil }
        let list = current(in: gs)
        if n == "pentagon" { return list.first { $0.role == "defense" } }
        for d in list {
            let full = CommandParser.normalize(d.name)
            let core = full.replacingOccurrences(of: "department of the ", with: "").replacingOccurrences(of: "department of ", with: "")
                .replacingOccurrences(of: "ministry of the ", with: "").replacingOccurrences(of: "ministry of ", with: "")
            if n == full || n == core + " department" || n == core + " ministry" || n == "department of " + core || n == "ministry of " + core { return d }
            if let given = gs.shadow.powerPlays.departmentNames[d.id], CommandParser.normalize(given) == n { return d }
        }
        return nil
    }

    /// The name the President's government uses for it.
    static func shownName(_ d: Department, in gs: GameState) -> String { gs.shadow.powerPlays.departmentNames[d.id] ?? d.name }

    /// The cabinet title for a role, after any rename: "Secretary of War" for a "Department of War".
    static func title(forRole role: String, in gs: GameState) -> String? {
        guard let d = current(in: gs).first(where: { $0.role == role }), let given = gs.shadow.powerPlays.departmentNames[d.id] else { return nil }
        for p in ["Department of the ", "Department of ", "Ministry of the ", "Ministry of "] where given.hasPrefix(p) {
            return (gs.playerCountryID == "USA" ? "Secretary of " : "Minister of ") + (p.hasSuffix("the ") ? "the " : "") + given.dropFirst(p.count)
        }
        return "Head of the \(given)"
    }
}

// MARK: - Renaming

extension GameEngine {
    /// Nations that use the President's name for a feature: its shore nations that are allies, territories, or on
    /// warm terms (relation 30 or more). Deterministic; no dice.
    func featureRecognizers(_ f: MapFeature) -> (yes: [String], no: [String]) {
        guard let gs = gameState, let me = gs.getPlayerCountry() else { return ([], []) }
        var yes: [String] = [], no: [String] = []
        for id in f.shores where id != me.id {
            guard let c = gs.getCountry(id: id), !c.isDestroyed else { continue }
            if c.territoryOf == me.id || me.alliances.contains(id) || (c.diplomaticRelations[me.id] ?? 0) >= 30 { yes.append(id) } else { no.append(id) }
        }
        return (yes, no)
    }

    /// Why a sea, mountain or department can't take this name, or nil. The same check as every name in the game:
    /// one line, length, nothing the content rules forbid, no addresses.
    func renamePlaceProblem(_ id: String, to raw: String) -> String? {
        guard let gs = gameState else { return "No game in progress." }
        let isFeature = MapFeatures.feature(id).map { $0.exists(in: gs.currentYear) } ?? false
        let isDept = Departments.current(in: gs).contains { $0.id == id }
        guard isFeature || isDept else { return "Nothing by that name to rename in \(gs.currentYear)." }
        guard let name = CombatModel.validTerritoryName(raw) else { return "A name is 1–\(CombatModel.maxTerritoryNameLength) characters on one line." }
        if ChatSafety.violates(name) || ChatSafety.scrubHosts(name) != name { return "That name can't be used." }
        let current = isFeature ? MapFeatures.feature(id).map { MapFeatures.shownName($0, in: gs) } : Departments.department(id).map { Departments.shownName($0, in: gs) }
        return current == name ? "It already has that name." : nil
    }

    /// The cabinet's read before a rename.
    func renamePlaceWarnings(_ id: String) -> [AdvisorWarning] {
        if let f = MapFeatures.feature(id) {
            let r = featureRecognizers(f)
            guard let gs = gameState else { return [] }
            var out = [AdvisorWarning(who: powerPlayStateWho, text: "Your map and your government will use it. The rest of the world keeps its atlas.", level: 0)]
            if !r.no.isEmpty {
                out.append(AdvisorWarning(who: powerPlayStateWho, text: "\(PowerPlay.list(r.no.compactMap { gs.getCountry(id: $0)?.name })) will not use it, and will resent being asked.", level: 1))
            }
            return out
        }
        return [AdvisorWarning(who: "Vice President", text: "The statute keeps the old name; Congress will grumble.", level: gameState?.playerCountryID == "USA" ? 1 : 0)]
    }

    /// Rename a sea, mountain or department (no action spent). Back to the real name clears it.
    @discardableResult
    func renamePlace(_ id: String, to raw: String) -> Bool {
        guard renamePlaceProblem(id, to: raw) == nil, let gs = gameState, let name = CombatModel.validTerritoryName(raw),
              let me = gs.getPlayerCountry() else { return false }
        if let f = MapFeatures.feature(id) {
            let real = f.name(in: gs.currentYear)
            let old = MapFeatures.shownName(f, in: gs)
            gs.shadow.powerPlays.featureNames[id] = name == real ? nil : name
            let r = featureRecognizers(f)
            gs.shadow.powerPlays.featureRecognition[id] = name == real ? nil : r.yes
            self.gameState = gs
            for c in r.yes { modifyDiplomaticRelation(from: c, to: me.id, by: 1) }
            for c in r.no { modifyDiplomaticRelation(from: c, to: me.id, by: -3) }
            gs.shadow.post(name == real ? "\(old) is \(real) again on the President's maps."
                           : "The President renames \(old) \(name) (\(real)).\(r.yes.isEmpty ? "" : " Used by \(PowerPlay.list(r.yes.compactMap { gs.getCountry(id: $0)?.name })).")",
                           date: gs.currentDate, severity: 1)
            logPlayEvent("renamed_feature", detail: ["feature": id, "name": PlayHistory.text(name), "recognized_by": r.yes.count,
                                                     "game_date": PlayHistory.day(gs.currentDate)])
        } else if let d = Departments.department(id) {
            let old = Departments.shownName(d, in: gs)
            gs.shadow.powerPlays.departmentNames[id] = name == d.name ? nil : name
            if let pi = gs.countries.firstIndex(where: { $0.id == me.id }), gs.playerCountryID == "USA" {
                gs.countries[pi].congressionalSupport = max(0, gs.countries[pi].congressionalSupport - 1)
            }
            gs.shadow.post("By executive order the \(old) is now the \(name)\(name == d.name ? "" : " (\(d.name) in law)").", date: gs.currentDate, severity: 0)
            logPlayEvent("renamed_department", detail: ["department": id, "name": PlayHistory.text(name), "game_date": PlayHistory.day(gs.currentDate)])
        }
        self.gameState = gs
        return true
    }
}
