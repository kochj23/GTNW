//
//  OccupationModel.swift
//  Global Thermal Nuclear War
//
//  Occupation, governance and statehood (3.9.0). Each U.S. territory (3.2.0 annexations, 3.3.0 claims) has a garrison
//  (drawn from the troop pool), an insurgency level and a form of government: a military governor, local elections or
//  self-rule. Each turn insurgency and stability drift toward targets set by those choices. A well-run territory can
//  petition for statehood (held five years, stable and quiet, with elected local government) and Congress votes; a
//  neglected one can break away. A new state keeps its player-given name and adds a star to the flag.
//  Repository: https://github.com/kochj23/GTNW
//

import Foundation

enum TerritoryGovernance: String, Codable, CaseIterable, Identifiable {
    case militaryGovernor, localElections, selfRule
    var id: String { rawValue }
    var title: String {
        switch self {
        case .militaryGovernor: return "Military Governor"
        case .localElections: return "Local Elections"
        case .selfRule: return "Self-Rule"
        }
    }
    /// Effect on the insurgency target (design choice): a governor provokes, elections and self-rule calm.
    var insurgencyShift: Double {
        switch self {
        case .militaryGovernor: return 10
        case .localElections: return -10
        case .selfRule: return -25
        }
    }
    /// Self-rule keeps more of the wealth at home.
    var incomeShare: Double { self == .selfRule ? 0.6 : 1 }
}

struct TerritoryPolicy: Codable, Hashable {
    var governance: TerritoryGovernance = .militaryGovernor
    /// When the current governance began (statehood wants two years of elections).
    var since: Date
    /// When the insurgency first boiled over (above 85), for breakaway.
    var crisisSince: Date?
}

/// A territory admitted as a state.
struct StatehoodRecord: Codable, Hashable {
    var id: String
    var name: String
    var date: Date
    /// Its place in the Union: 49th, 50th, 51st…
    var number: Int
}

enum OccupationModel {
    /// Years the 50 states were admitted (Delaware 1787 … Hawaii 1959), for counting stars.
    static let admissions: [Int] = [1787, 1787, 1787, 1788, 1788, 1788, 1788, 1788, 1788, 1788, 1788, 1789, 1790,
                                    1791, 1792, 1796, 1803, 1812, 1816, 1817, 1818, 1819, 1820, 1821, 1836, 1837,
                                    1845, 1845, 1846, 1848, 1850, 1858, 1859, 1861, 1863, 1864, 1867, 1876, 1889,
                                    1889, 1889, 1889, 1890, 1890, 1896, 1907, 1912, 1912, 1959, 1959]

    /// States in the Union in a year, before any the President adds.
    static func historicalStates(year: Int) -> Int { admissions.filter { $0 <= year }.count }

    /// Garrison (thousands) a territory needs to be held firmly: about 2K per square root of a million people.
    static func neededGarrison(_ c: Country) -> Double { max(2, Double(max(1, c.population)).squareRoot() * 2) }

    /// Where insurgency heads: 50, less up to 35 for a full garrison, shifted by governance; floored at 0.
    static func insurgencyTarget(garrison: Double, needed: Double, governance: TerritoryGovernance) -> Double {
        min(100, max(0, 50 - 35 * min(1.5, garrison / max(0.1, needed)) + governance.insurgencyShift))
    }

    static func stabilityTarget(insurgency: Double, governance: TerritoryGovernance) -> Int {
        Int(max(0, min(100, 75 - insurgency * 0.6 + (governance == .militaryGovernor ? 0 : 5))))
    }

    /// Statehood conditions: held 5 years, stability 60+, insurgency 30 or less, two years of elections or self-rule.
    static func statehoodProblems(c: Country, policy: TerritoryPolicy?, heldSince: Date?, now: Date) -> [String] {
        var out: [String] = []
        let held = heldSince.map { GameCalendar.years(from: $0, to: now) } ?? 10
        if held < 5 { out.append(String(format: "held %.1f of 5 years", held)) }
        if c.stability < 60 { out.append("stability \(c.stability) of 60") }
        if c.profile.outcry > 30 { out.append("insurgency \(Int(c.profile.outcry)) (30 or less)") }
        if let p = policy {
            if p.governance == .militaryGovernor { out.append("needs local elections or self-rule") }
            else if GameCalendar.years(from: p.since, to: now) < 2 { out.append("two years of elected government") }
        } else {
            out.append("needs local elections or self-rule")
        }
        return out
    }

    /// Congress's expected yes share on statehood: half its support plus a stability bonus.
    static func statehoodYes(congress: Int, stability: Int) -> Double {
        min(95, 0.5 * Double(congress) + 20 + Double(stability) / 4)
    }

    static func ordinal(_ n: Int) -> String {
        let suffix = (11...13).contains(n % 100) ? "th" : (n % 10 == 1 ? "st" : (n % 10 == 2 ? "nd" : (n % 10 == 3 ? "rd" : "th")))
        return "\(n)\(suffix)"
    }
}

extension GameState {
    /// "U.S. TERRITORY", or "U.S. STATE ★51" once admitted (3.9.0).
    func territoryLabel(_ c: Country) -> String {
        if let s = shadow.statesAdmitted.first(where: { $0.id == c.id }) { return "U.S. STATE ★\(s.number)" }
        return CombatModel.territoryTitle(ownerID: c.territoryOf ?? "", ownerName: getCountry(id: c.territoryOf ?? "")?.name ?? "")
    }
}

// MARK: - Engine

extension GameEngine {
    /// Set a territory's government (free; once a turn changes nothing more than the date).
    @discardableResult
    func setGovernance(_ id: String, _ g: TerritoryGovernance) -> Bool {
        guard let gs = gameState, gs.getCountry(id: id)?.territoryOf == gs.playerCountryID, !gs.shadow.statesAdmitted.contains(where: { $0.id == id })
        else { return false }
        if gs.shadow.territoryPolicies[id]?.governance == g { return true }
        gs.shadow.territoryPolicies[id] = TerritoryPolicy(governance: g, since: gs.currentDate)
        gs.shadow.post("\(gs.getCountry(id: id)?.name ?? id): \(g.title.lowercased()) from today.", date: gs.currentDate, severity: 1)
        self.gameState = gs
        return true
    }

    /// Change a territory's garrison (thousands, ≥ 0.5): more troops come from the free pool, fewer return to it.
    @discardableResult
    func setGarrison(_ id: String, thousands: Double) -> Bool {
        guard let gs = gameState, gs.getCountry(id: id)?.territoryOf == gs.playerCountryID, thousands.isFinite, thousands >= 0.5 else { return false }
        let current = gs.shadow.garrisons[id] ?? 0
        guard thousands - current <= AttackSizing.freeTroops(gs) else { return false }
        gs.shadow.garrisons[id] = thousands.rounded()
        self.gameState = gs
        return true
    }

    /// Ask Congress to admit a territory as a state (one action). Nil if conditions aren't met; else whether it passed.
    @discardableResult
    func petitionStatehood(_ id: String, roll: Double = Double.random(in: 0..<1)) -> Bool? {
        guard let gs = gameState, gs.actionsRemaining > 0, let ti = gs.countries.firstIndex(where: { $0.id == id }),
              gs.countries[ti].territoryOf == gs.playerCountryID, !gs.shadow.statesAdmitted.contains(where: { $0.id == id }),
              OccupationModel.statehoodProblems(c: gs.countries[ti], policy: gs.shadow.territoryPolicies[id],
                                                heldSince: gs.shadow.claimDates[id], now: gs.currentDate).isEmpty,
              let p = gs.getPlayerCountry() else { return nil }
        let yes = OccupationModel.statehoodYes(congress: p.congressionalSupport, stability: gs.countries[ti].stability)
        let odds = CongressModel.passOdds(expectedYes: yes)
        let name = gs.countries[ti].name
        let passed = roll < odds
        if passed {
            let number = OccupationModel.historicalStates(year: gs.currentYear) + gs.shadow.statesAdmitted.count + 1
            gs.shadow.statesAdmitted.append(StatehoodRecord(id: id, name: name, date: gs.currentDate, number: number))
            gs.shadow.territoryPolicies.removeValue(forKey: id)
            gs.shadow.popularity = PopularityModel.clamp(gs.shadow.popularity + 4)
            gs.shadow.post("\(name) is admitted as the \(OccupationModel.ordinal(number)) state. The flag gains a star.", date: gs.currentDate, severity: 2)
            logPlayEvent("statehood", detail: ["land": id, "name": PlayHistory.text(name), "number": number, "game_date": PlayHistory.day(gs.currentDate)])
        } else {
            gs.shadow.post("Congress votes down statehood for \(name).", date: gs.currentDate, severity: 1)
        }
        self.gameState = gs
        completePlayerAction()
        return passed
    }

    /// Each turn: insurgency and stability drift with garrison and governance; a territory left to boil over for a
    /// year (or with no garrison and no stability) breaks away.
    func processOccupation() {
        guard let gs = gameState else { return }
        let keep = pow(0.7, gs.turnLength.yearFraction / 0.25)   // ~30% of the way to target every quarter
        let states = Set(gs.shadow.statesAdmitted.map(\.id))
        for i in gs.countries.indices where gs.countries[i].territoryOf == gs.playerCountryID && !gs.countries[i].isDestroyed && !states.contains(gs.countries[i].id) {
            let c = gs.countries[i]
            let policy = gs.shadow.territoryPolicies[c.id] ?? TerritoryPolicy(since: gs.shadow.claimDates[c.id] ?? gs.currentDate)
            // No record (saves before 3.9.0): treat the territory as properly garrisoned.
            let garrison = gs.shadow.garrisons[c.id] ?? OccupationModel.neededGarrison(c)
            let target = OccupationModel.insurgencyTarget(garrison: garrison, needed: OccupationModel.neededGarrison(c), governance: policy.governance)
            var p = c.profile
            p.outcry = p.outcry * keep + target * (1 - keep)
            gs.countries[i].profile = p
            let st = OccupationModel.stabilityTarget(insurgency: p.outcry, governance: policy.governance)
            gs.countries[i].stability = Int((Double(c.stability) * keep + Double(st) * (1 - keep)).rounded())
            var pol = policy
            if p.outcry > 85 { pol.crisisSince = pol.crisisSince ?? gs.currentDate } else { pol.crisisSince = nil }
            gs.shadow.territoryPolicies[c.id] = pol
            let boiling = (pol.crisisSince.map { GameCalendar.years(from: $0, to: gs.currentDate) >= 1 } ?? false)
                && garrison < OccupationModel.neededGarrison(c) / 2
            if boiling || (garrison < 0.5 && gs.countries[i].stability < 10) {
                var lost = gs.countries[i]
                lost.territoryOf = nil
                CombatModel.installChosenGovernment(.provisional, on: &lost, by: gs.getPlayerCountry() ?? lost)
                lost.diplomaticRelations[gs.playerCountryID] = -40
                lost.alliances.remove(gs.playerCountryID)
                gs.countries[i] = lost
                gs.shadow.garrisons.removeValue(forKey: c.id)
                gs.shadow.territoryPolicies.removeValue(forKey: c.id)
                gs.shadow.popularity = PopularityModel.clamp(gs.shadow.popularity - 5)
                gs.shadow.post("\(c.name) throws off U.S. rule and declares independence.", date: gs.currentDate, severity: 3)
                logPlayEvent("territory_lost", detail: ["land": c.id, "name": PlayHistory.text(c.name), "game_date": PlayHistory.day(gs.currentDate)])
            }
        }
        self.gameState = gs
    }
}
