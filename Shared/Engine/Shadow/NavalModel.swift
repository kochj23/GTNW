//
//  NavalModel.swift
//  Global Thermal Nuclear War
//
//  Naval operations (3.5.0): the President orders a named, era-appropriate U.S. fleet or squadron to a target for a
//  show of force, a blockade, a naval strike or an amphibious invasion. The fleet sails from its home port (transit
//  takes game days by great-circle distance and era speed), is drawn on the map, can be engaged by the target's navy
//  and air force, and stays on station, tying up its ships, until recalled.
//  Fleet names, dates and home ports come from Documentation/arsenal (gtnw_us_arsenal_by_era.json, "fleets").
//  Repository: https://github.com/kochj23/GTNW
//

import Foundation

// MARK: - The fleet table

/// A U.S. fleet or squadron and where it was based when. `periods` cover only the years it existed (gaps such as the
/// Fifth Fleet's 1947–1995 are simply missing); `to` is inclusive, nil = still active.
struct USFleet: Identifiable, Hashable {
    struct Period: Hashable {
        let from: Int
        let to: Int?
        let home: String
        let lat: Double
        let lon: Double
    }
    let id: String
    let name: String
    let periods: [Period]
    /// Rough size relative to an ordinary fleet of its era (the WWII Pacific Fleet is big, the Africa Squadron small).
    var weight: Double = 1

    func period(in year: Int) -> Period? { periods.first { year >= $0.from && year <= ($0.to ?? Int.max) } }
}

/// Ships in a fleet, by type. Encyclopedia-level counts, not orders of battle.
struct FleetComposition: Codable, Hashable {
    var carriers = 0
    var surface = 0
    var submarines = 0
    var amphibious = 0
    var total: Int { carriers + surface + submarines + amphibious }

    func scaled(_ f: Double) -> FleetComposition {
        func s(_ n: Int) -> Int { n == 0 ? 0 : max(1, Int((Double(n) * f).rounded())) }
        return FleetComposition(carriers: s(carriers), surface: s(surface), submarines: s(submarines), amphibious: s(amphibious))
    }
}

enum NavalModel {
    /// No U.S. Navy existed 1789–1797 (Naval Act 1794, first frigates 1797); the first named squadron sailed in 1801.
    /// Dates of uncertain start/end are rounded to the year, as in the research.
    static let fleets: [USFleet] = [
        USFleet(id: "med", name: "Mediterranean Squadron", periods: [.init(from: 1801, to: 1861, home: "Port Mahon", lat: 39.9, lon: 4.3)], weight: 0.8),
        USFleet(id: "pacsq", name: "Pacific Squadron", periods: [.init(from: 1821, to: 1907, home: "Callao", lat: -12.05, lon: -77.15)], weight: 0.7),
        USFleet(id: "westindia", name: "West India Squadron", periods: [.init(from: 1822, to: 1842, home: "Key West", lat: 24.55, lon: -81.8)], weight: 0.5),
        USFleet(id: "brazil", name: "Brazil / South Atlantic Squadron", periods: [.init(from: 1826, to: 1861, home: "Rio de Janeiro", lat: -22.9, lon: -43.2),
                                                                                  .init(from: 1865, to: 1905, home: "Rio de Janeiro", lat: -22.9, lon: -43.2)], weight: 0.5),
        USFleet(id: "eastindia", name: "East India Squadron", periods: [.init(from: 1835, to: 1868, home: "Hong Kong", lat: 22.3, lon: 114.2)], weight: 0.6),
        USFleet(id: "home", name: "Home Squadron", periods: [.init(from: 1838, to: 1861, home: "Norfolk", lat: 36.95, lon: -76.3)], weight: 0.8),
        USFleet(id: "africa", name: "Africa Squadron", periods: [.init(from: 1843, to: 1861, home: "Porto Praya, Cape Verde", lat: 14.9, lon: -23.5)], weight: 0.5),
        USFleet(id: "blockade", name: "Union Blockading Squadrons", periods: [.init(from: 1861, to: 1865, home: "Hampton Roads", lat: 36.95, lon: -76.3)], weight: 3),
        USFleet(id: "european", name: "European Squadron", periods: [.init(from: 1865, to: 1905, home: "Villefranche", lat: 43.7, lon: 7.3)], weight: 0.7),
        USFleet(id: "northatl", name: "North Atlantic Squadron", periods: [.init(from: 1865, to: 1902, home: "Norfolk", lat: 36.95, lon: -76.3)]),
        USFleet(id: "asiatic", name: "Asiatic Squadron / Asiatic Fleet", periods: [.init(from: 1868, to: 1898, home: "Hong Kong", lat: 22.3, lon: 114.2),
                                                                                   .init(from: 1899, to: 1942, home: "Manila", lat: 14.6, lon: 120.95)], weight: 0.8),
        USFleet(id: "flying", name: "Flying Squadron", periods: [.init(from: 1898, to: 1898, home: "Hampton Roads", lat: 36.95, lon: -76.3)], weight: 0.6),
        USFleet(id: "atlantic1", name: "Atlantic Fleet", periods: [.init(from: 1906, to: 1922, home: "Norfolk", lat: 36.95, lon: -76.3)], weight: 1.5),
        USFleet(id: "gwf", name: "Great White Fleet", periods: [.init(from: 1907, to: 1909, home: "Hampton Roads", lat: 36.95, lon: -76.3)], weight: 1.3),
        USFleet(id: "pacific1", name: "Pacific Fleet", periods: [.init(from: 1907, to: 1922, home: "San Diego", lat: 32.7, lon: -117.2)]),
        USFleet(id: "usfleet", name: "United States Fleet", periods: [.init(from: 1922, to: 1940, home: "San Pedro", lat: 33.7, lon: -118.3)], weight: 2),
        USFleet(id: "pacfleet", name: "U.S. Pacific Fleet", periods: [.init(from: 1941, to: nil, home: "Pearl Harbor", lat: 21.35, lon: -157.95)], weight: 2),
        USFleet(id: "atlfleet", name: "U.S. Atlantic Fleet", periods: [.init(from: 1941, to: nil, home: "Norfolk", lat: 36.95, lon: -76.3)], weight: 1.5),
        USFleet(id: "first", name: "First Fleet", periods: [.init(from: 1947, to: 1973, home: "San Diego", lat: 32.7, lon: -117.2)]),
        USFleet(id: "second", name: "Second Fleet", periods: [.init(from: 1950, to: 2011, home: "Norfolk", lat: 36.95, lon: -76.3),
                                                              .init(from: 2018, to: nil, home: "Norfolk", lat: 36.95, lon: -76.3)]),
        USFleet(id: "third", name: "Third Fleet", periods: [.init(from: 1943, to: 1945, home: "Pearl Harbor", lat: 21.35, lon: -157.95),
                                                            .init(from: 1973, to: nil, home: "San Diego", lat: 32.7, lon: -117.2)]),
        USFleet(id: "fourth", name: "Fourth Fleet", periods: [.init(from: 1943, to: 1950, home: "Recife", lat: -8.05, lon: -34.9),
                                                              .init(from: 2008, to: nil, home: "Mayport", lat: 30.4, lon: -81.4)], weight: 0.4),
        USFleet(id: "fifth", name: "Fifth Fleet", periods: [.init(from: 1944, to: 1947, home: "Pearl Harbor", lat: 21.35, lon: -157.95),
                                                            .init(from: 1995, to: nil, home: "Bahrain", lat: 26.2, lon: 50.6)]),
        USFleet(id: "sixth", name: "Sixth Fleet", periods: [.init(from: 1950, to: nil, home: "Naples", lat: 40.8, lon: 14.25)]),
        USFleet(id: "seventh", name: "Seventh Fleet", periods: [.init(from: 1943, to: 1945, home: "Brisbane", lat: -27.45, lon: 153.05),
                                                                .init(from: 1946, to: nil, home: "Yokosuka", lat: 35.3, lon: 139.65)], weight: 1.5),
        USFleet(id: "eighth", name: "Eighth Fleet", periods: [.init(from: 1943, to: 1946, home: "Algiers", lat: 36.8, lon: 3.05)]),
        USFleet(id: "twelfth", name: "Twelfth Fleet", periods: [.init(from: 1943, to: 1946, home: "London", lat: 51.5, lon: -0.1)], weight: 0.6),
    ]

    static func fleet(id: String) -> USFleet? { fleets.first { $0.id == id } }

    /// Fleets that existed in a year.
    static func fleets(in year: Int) -> [USFleet] { fleets.filter { $0.period(in: year) != nil } }

    /// What an ordinary fleet of the era held: sail frigates and sloops, then steam, the steel navy, the treaty navy
    /// with the first carrier (1922), the WWII navy, and the post-war carrier fleet. Submarines from 1900, carriers
    /// from 1922; amphibious ships as such from 1942 (earlier landings used whatever the squadron carried).
    static func baseComposition(year: Int) -> FleetComposition {
        switch year {
        case ..<1840: return FleetComposition(surface: 5)
        case ..<1890: return FleetComposition(surface: 7)
        case ..<1900: return FleetComposition(surface: 10)
        case ..<1922: return FleetComposition(surface: 14, submarines: 3)
        case ..<1941: return FleetComposition(carriers: 1, surface: 20, submarines: 8)
        case ..<1946: return FleetComposition(carriers: 6, surface: 40, submarines: 15, amphibious: 20)
        default: return FleetComposition(carriers: 2, surface: 14, submarines: 4, amphibious: 4)
        }
    }

    static func composition(_ fleet: USFleet, year: Int) -> FleetComposition {
        fleet.period(in: year) == nil ? FleetComposition() : baseComposition(year: year).scaled(fleet.weight)
    }

    /// Sea speed, km per day: sail, steam (from 1840), and the modern ~20-knot fleet (from 1946).
    static func speedKmPerDay(year: Int) -> Double { year < 1840 ? 150 : (year < 1946 ? 350 : 900) }

    /// Great-circle distance, km.
    static func distanceKm(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let r = 6371.0, d = Double.pi / 180
        let a = pow(sin((lat2 - lat1) * d / 2), 2) + cos(lat1 * d) * cos(lat2 * d) * pow(sin((lon2 - lon1) * d / 2), 2)
        return 2 * r * asin(min(1, a.squareRoot()))
    }

    /// Days at sea: distance ÷ era speed, rounded up, at least one.
    static func transitDays(km: Double, year: Int) -> Int { max(1, Int((km / speedKmPerDay(year: year)).rounded(.up))) }

    /// The 44 landlocked countries (plus Czechoslovakia), on top of the Factbook's flag. No naval operation reaches them.
    static let knownLandlocked: Set<String> = [
        "AFG", "AND", "ARM", "AUT", "AZE", "BLR", "BTN", "BOL", "BWA", "BFA", "BDI", "CAF", "TCD", "CZE", "SWZ", "ETH", "HUN",
        "KAZ", "XKX", "KGZ", "LAO", "LSO", "LIE", "LUX", "MWI", "MLI", "MDA", "MNG", "NPL", "NER", "MKD", "PRY", "RWA", "SMR",
        "SRB", "SSD", "SVK", "CHE", "TJK", "TKM", "UGA", "UZB", "VAT", "ZMB", "ZWE", "CSK",
    ]

    static func isLandlocked(_ id: String) -> Bool {
        knownLandlocked.contains(id) || WorldFactbookDatabase.record(for: id).isLandlocked
    }

    /// The fleet's main naval-strike weapon in a year (names and dates only).
    static func strikeWeapon(year: Int) -> String {
        switch year {
        case ..<1862: return "broadsides from sail warships"
        case ..<1906: return "naval guns"
        case ..<1942: return "battleship and cruiser guns"
        case ..<1983: return "carrier air wings and naval gunfire"
        default: return "Tomahawk cruise missiles and carrier air wings"   // Tomahawk in service from 1983
        }
    }
}

// MARK: - Missions and deployments

enum NavalMission: String, Codable, CaseIterable, Identifiable {
    case showOfForce, blockade, strike, amphibious
    var id: String { rawValue }

    var title: String {
        switch self {
        case .showOfForce: return "Show of Force"
        case .blockade: return "Blockade"
        case .strike: return "Naval Strike"
        case .amphibious: return "Amphibious Invasion"
        }
    }

    /// Past-tense verb for the news and play history: "Fifth Fleet blockaded Japan".
    var verb: String {
        switch self {
        case .showOfForce: return "showed the flag off"
        case .blockade: return "blockaded"
        case .strike: return "struck"
        case .amphibious: return "landed troops in"
        }
    }

    var summary: String {
        switch self {
        case .showOfForce: return "Sail into their waters. Pressure and tension, no shots fired."
        case .blockade: return "Close their ports. Output falls every turn while the fleet is on station; it means war."
        case .strike: return "Bombard military and coastal targets. Damage and casualties; it means war."
        case .amphibious: return "Land troops from the sea. Opens a front, or takes unclaimed coastal land outright."
        }
    }

    /// Probe / Standard / Overwhelming = a quarter, half, or all of the fleet (3.4.0 sizing step).
    static func commitment(_ p: AttackPreset) -> Double {
        switch p {
        case .probe: return 0.25
        case .standard: return 0.5
        case .overwhelming: return 1
        }
    }
}

enum FleetStatus: String, Codable { case underway, onStation }

/// A fleet the President has sent somewhere. Saved with the game; position is derived from the dates.
struct FleetDeployment: Codable, Identifiable, Hashable {
    var id = UUID()
    var fleetID: String
    var target: String
    var mission: NavalMission
    /// Share of the fleet committed, 0.25 … 1.
    var commitment: Double
    var ships: FleetComposition
    var shipsLost: Int = 0
    var fromLat: Double
    var fromLon: Double
    var toLat: Double
    var toLon: Double
    var departed: Date
    var arrives: Date
    var status: FleetStatus = .underway

    /// Position along the great-circle chord (good enough for a map marker), by elapsed transit time.
    func position(at date: Date) -> (lat: Double, lon: Double) {
        let total = arrives.timeIntervalSince(departed)
        let f = total <= 0 ? 1 : max(0, min(1, date.timeIntervalSince(departed) / total))
        return (fromLat + (toLat - fromLat) * f, fromLon + (toLon - fromLon) * f)
    }

    var shipsAfloat: Int { max(0, ships.total - shipsLost) }
}

extension NavalModel {
    /// Fleet strength in a fight: ships weighted by type (carriers count most), times the share still afloat.
    static func power(_ d: FleetDeployment) -> Double {
        let s = d.ships
        let raw = Double(s.carriers) * 6 + Double(s.surface) * 2 + Double(s.submarines) * 1.5 + Double(s.amphibious) * 0.5
        return raw * Double(d.shipsAfloat) / Double(max(1, s.total))
    }

    /// The target's naval and air strength against a fleet off its coast: military strength, scaled by the era's
    /// reach (aircraft from 1914, missiles from 1960), and nothing for a land with no country.
    static func defence(_ c: Country?, year: Int) -> Double {
        guard let c else { return 0 }
        let reach = year < 1914 ? 0.15 : (year < 1960 ? 0.3 : 0.45)
        return Double(c.militaryStrength) * reach
    }

    /// Ships lost in one engagement: up to a quarter of what is afloat, by the defender's share of the combined
    /// strength (`intensity` 1 on arrival, less for each turn of a blockade). More ships committed → more power and
    /// a smaller share lost, but more hulls exposed.
    static func shipsLost(_ d: FleetDeployment, defence: Double, intensity: Double = 1) -> Int {
        let f = power(d), share = defence / max(0.001, defence + f)
        return min(d.shipsAfloat, Int((Double(d.shipsAfloat) * 0.25 * share * intensity).rounded()))
    }

    /// Troops (thousands) an amphibious force can land: 2K per amphibious ship, or 0.5K per warship before 1942.
    static func landingTroops(_ ships: FleetComposition, year: Int) -> Double {
        year >= 1942 ? Double(ships.amphibious) * 2 : max(1, Double(ships.surface) * 0.5)
    }
}

// MARK: - Fleet orders (engine)

extension GameEngine {
    /// Where a target is: a country's capital, or an unclaimed land's modern capital.
    private func navalTargetPoint(_ id: String, in gs: GameState) -> (lat: Double, lon: Double, name: String)? {
        if let c = gs.getCountry(id: id) { return (c.coordinates.lat, c.coordinates.lon, c.name) }
        if gs.unclaimedLandIDs.contains(id), let t = WorldCountriesDatabase.template(id: id) { return (t.lat, t.lon, t.name) }
        return nil
    }

    /// Why this order can't be given right now, in a line for the sheet; nil when it can.
    func fleetOrderProblem(fleetID: String, target: String, mission: NavalMission) -> String? {
        guard let gs = gameState else { return "No game in progress." }
        guard let fleet = NavalModel.fleet(id: fleetID), fleet.period(in: gs.currentYear) != nil else {
            return "That fleet doesn't exist in \(gs.currentYear)."
        }
        if gs.shadow.fleetDeployments.contains(where: { $0.fleetID == fleetID }) { return "\(fleet.name) is already deployed. Recall it first." }
        guard let point = navalTargetPoint(target, in: gs) else { return "No such target." }
        if NavalModel.isLandlocked(target) { return "\(point.name) is landlocked: no coast for a fleet to reach." }
        if target == gs.playerCountryID || gs.getCountry(id: target)?.territoryOf == gs.playerCountryID {
            return "That flies our own flag."
        }
        if gs.getCountry(id: target) == nil && mission != .amphibious {
            return "Unclaimed land has no navy or ports to pressure: send an amphibious landing."
        }
        if gs.actionsRemaining == 0 { return "No actions left this \(gs.turnLength.displayName.lowercased())." }
        return nil
    }

    /// Order a fleet out (one action). `preset` commits a quarter, half or all of it. Returns the deployment.
    @discardableResult
    func orderFleet(_ fleetID: String, to target: String, mission: NavalMission, preset: AttackPreset = .standard) -> FleetDeployment? {
        guard fleetOrderProblem(fleetID: fleetID, target: target, mission: mission) == nil,
              let gs = gameState, let fleet = NavalModel.fleet(id: fleetID), let home = fleet.period(in: gs.currentYear),
              let point = navalTargetPoint(target, in: gs) else { return nil }
        let year = gs.currentYear
        let commit = NavalMission.commitment(preset)
        let km = NavalModel.distanceKm(lat1: home.lat, lon1: home.lon, lat2: point.lat, lon2: point.lon)
        // 3.7.0: territory oil fuels the fleet (about 10% faster).
        let days = NavalModel.transitDays(km: km / (ExpansionModel.strategic(gs).contains(.oil) ? 1.1 : 1), year: year)
        let d = FleetDeployment(fleetID: fleetID, target: target, mission: mission, commitment: commit,
                                ships: NavalModel.composition(fleet, year: year).scaled(commit),
                                fromLat: home.lat, fromLon: home.lon, toLat: point.lat, toLon: point.lon,
                                departed: gs.currentDate,
                                arrives: GameCalendar.calendar.date(byAdding: .day, value: days, to: gs.currentDate) ?? gs.currentDate)
        gs.shadow.fleetDeployments.append(d)
        gs.shadow.post("\(fleet.name) sails from \(home.home) for \(point.name): \(mission.title.lowercased()), \(d.ships.total) ships, "
                       + "about \(days) days at sea.", date: gs.currentDate, severity: 1)
        gs.shadow.logWar("\(GameCalendar.format(gs.currentDate)): \(fleet.name) ordered to \(point.name) (\(mission.title)).")
        logPlayEvent("fleet_ordered", detail: ["fleet": fleet.name, "target": target, "target_name": PlayHistory.text(point.name),
                                               "mission": mission.rawValue, "preset": preset.rawValue, "ships": d.ships.total,
                                               "transit_days": days, "game_date": PlayHistory.day(gs.currentDate)])
        self.gameState = gs
        completePlayerAction()
        return d
    }

    /// Bring a fleet home; its ships are free for new orders at once.
    @discardableResult
    func recallFleet(_ id: UUID) -> Bool {
        guard let gs = gameState, let i = gs.shadow.fleetDeployments.firstIndex(where: { $0.id == id }) else { return false }
        let d = gs.shadow.fleetDeployments.remove(at: i)
        let name = NavalModel.fleet(id: d.fleetID)?.name ?? d.fleetID
        gs.shadow.post("\(name) is recalled to port.", date: gs.currentDate, severity: 1)
        logPlayEvent("fleet_recalled", detail: ["fleet": name, "target": d.target, "game_date": PlayHistory.day(gs.currentDate)])
        self.gameState = gs
        return true
    }

    /// Each turn: blockades already on station squeeze the target; fleets that have arrived carry out their mission.
    func processFleets() {
        guard let gs = gameState else { return }
        let year = gs.currentYear, months = gs.turnLength.yearFraction * 12
        for i in gs.shadow.fleetDeployments.indices where gs.shadow.fleetDeployments[i].status == .onStation
            && gs.shadow.fleetDeployments[i].mission == .blockade {
            let d = gs.shadow.fleetDeployments[i]
            guard let ti = gs.countries.firstIndex(where: { $0.id == d.target }), !gs.countries[ti].isDestroyed else { continue }
            // Output falls 3% a month per unit of commitment over the standard half fleet, less for a short coastline.
            let m = d.commitment / NavalMission.commitment(.standard)
            let coast = WorldFactbookDatabase.record(for: d.target).terrainType.blockadeable ? 1.0 : 0.5
            gs.countries[ti].gdp *= max(0.5, 1 - 0.03 * m * months * coast)
            gs.countries[ti].economicStrength = max(1, gs.countries[ti].economicStrength - 1)
            gs.shadow.fleetDeployments[i].shipsLost += NavalModel.shipsLost(d, defence: NavalModel.defence(gs.countries[ti], year: year), intensity: 0.2)
        }
        for i in gs.shadow.fleetDeployments.indices where gs.shadow.fleetDeployments[i].status == .underway
            && gs.shadow.fleetDeployments[i].arrives <= gs.currentDate {
            arrive(index: i)
        }
        // A fleet with nothing left afloat is gone.
        for d in gs.shadow.fleetDeployments where d.shipsAfloat == 0 {
            gs.shadow.post("\(NavalModel.fleet(id: d.fleetID)?.name ?? d.fleetID) has been destroyed.", date: gs.currentDate, severity: 3)
        }
        gs.shadow.fleetDeployments.removeAll { $0.shipsAfloat == 0 }
        self.gameState = gs
    }

    /// A fleet reaches its target: it is engaged by the target's navy and air force, then carries out its mission.
    private func arrive(index i: Int) {
        guard let gs = gameState else { return }
        var d = gs.shadow.fleetDeployments[i]
        let year = gs.currentYear, player = gs.playerCountryID
        let fleetName = NavalModel.fleet(id: d.fleetID)?.name ?? d.fleetID
        let target = gs.getCountry(id: d.target)
        let targetName = target?.name ?? WorldCountriesDatabase.template(id: d.target)?.name ?? d.target
        let m = d.commitment / NavalMission.commitment(.standard)   // 3.4.0 scale: Standard = half the fleet
        d.status = .onStation
        // The engagement: shows of force aren't fired on unless already at war.
        let atWar = target?.atWarWith.contains(player) ?? false
        let intensity: Double = d.mission == .showOfForce ? (atWar ? 1 : 0) : 1
        let lost = NavalModel.shipsLost(d, defence: NavalModel.defence(target, year: year), intensity: intensity)
        d.shipsLost += lost
        gs.shadow.fleetDeployments[i] = d
        if let ti = gs.countries.firstIndex(where: { $0.id == d.target }), intensity > 0 {
            let f = NavalModel.power(d), def = NavalModel.defence(target, year: year)
            gs.countries[ti].militaryStrength = max(1, gs.countries[ti].militaryStrength - Int((5 * f / max(0.001, f + def)).rounded()))
        }
        let factor = AttackSizing.relationFactor(scale: m)
        func war() { if !(gs.getCountry(id: d.target)?.atWarWith.contains(player) ?? true) { declareWar(aggressor: player, defender: d.target) } }
        switch d.mission {
        case .showOfForce:
            modifyDiplomaticRelation(from: d.target, to: player, by: Int((-10 * factor).rounded()))
            if let ti = gs.countries.firstIndex(where: { $0.id == d.target }) { gs.countries[ti].profile.anxieties.military += 20 * m }
        case .blockade:
            war()
            modifyDiplomaticRelation(from: d.target, to: player, by: Int((-60 * factor).rounded()))
        case .strike:
            war()
            modifyDiplomaticRelation(from: d.target, to: player, by: Int((-70 * factor).rounded()))
            if let ti = gs.countries.firstIndex(where: { $0.id == d.target }) {
                gs.countries[ti].damageLevel = min(99, gs.countries[ti].damageLevel + Int((5 * m).rounded()))
                gs.countries[ti].gdp *= max(0.5, 1 - 0.02 * m)
            }
            gs.totalCasualties += Int(NavalModel.power(d) * 300)
        case .amphibious:
            let troops = NavalModel.landingTroops(d.ships, year: year) * Double(d.shipsAfloat) / Double(max(1, d.ships.total))
            if target == nil {
                if !claimLand(d.target, troops: max(1, troops.rounded()), spendAction: false) { break }
            } else {
                war()
                syncFronts()
                if let fi = gs.shadow.fronts.firstIndex(where: { $0.status == .fighting && $0.attacker == player && $0.defender == d.target }) {
                    if gs.shadow.fronts[fi].battles == 0 {
                        gs.shadow.fronts[fi].attackerTroops = troops; gs.shadow.fronts[fi].attackerInitial = troops
                    } else {
                        gs.shadow.fronts[fi].attackerTroops += troops; gs.shadow.fronts[fi].attackerInitial += troops
                    }
                }
            }
        }
        let hit = AttackSizing.worldHit(scale: m)
        if hit > 0 { for c in gs.countries where c.id != player && c.id != d.target && !c.isTerritory { modifyDiplomaticRelation(from: c.id, to: player, by: -hit) } }
        if AttackSizing.escalates(scale: m) && d.mission != .showOfForce { raiseDEFCON() }
        let sentence = "\(fleetName) \(d.mission.verb) \(targetName)"
        let weapon = d.mission == .strike ? " with \(NavalModel.strikeWeapon(year: year))" : ""
        gs.shadow.post("\(sentence)\(weapon).\(lost > 0 ? " \(lost) ship\(lost == 1 ? "" : "s") lost." : "")", date: gs.currentDate, severity: 2)
        gs.shadow.logWar("\(GameCalendar.format(gs.currentDate)): \(sentence).")
        logPlayEvent("fleet_action", detail: ["fleet": fleetName, "target": d.target, "target_name": PlayHistory.text(targetName),
                                              "mission": d.mission.rawValue, "ships": d.ships.total, "ships_lost": lost,
                                              "sentence": PlayHistory.text(sentence), "game_date": PlayHistory.day(gs.currentDate)])
        self.gameState = gs
    }
}
