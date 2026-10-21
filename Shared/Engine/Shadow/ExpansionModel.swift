//
//  ExpansionModel.swift
//  Global Thermal Nuclear War
//
//  Territory wealth and the politics of expansion (3.7.0). Territories (3.2.0 annexations and 3.3.0 claims) yield
//  era-accurate resources that add to U.S. output each turn after a ramp-up, scaled by garrison and stability;
//  strategic resources (oil, uranium, rubber) matter in the eras they mattered. The domestic and foreign reaction to
//  taking land depends on the era and on how much is taken per year: gentle for a few claims, steep for a spree.
//  Impeachment pressure is computed here too, so the top bar and advisors can warn before Congress acts.
//  Repository: https://github.com/kochj23/GTNW
//

import Foundation

// MARK: - Resources

enum ResourceKind: String, Codable, CaseIterable {
    case gold, diamonds, copper, cobalt, rubber, ivory, cocoa, coffee, tea, cotton, oil, uranium, phosphates, timber,
         palmOil, groundnuts, tin, ironOre, manganese, bauxite, sisal, tobacco, vanilla, agriculture,
         whaling, sealing, science, minerals

    var title: String {
        switch self {
        case .palmOil: return "palm oil"
        case .ironOre: return "iron ore"
        case .science: return "science prestige"
        default: return rawValue
        }
    }

    /// Strategic resources change the game in the eras they mattered (see `ExpansionModel.strategic`).
    var isStrategic: Bool { self == .oil || self == .uranium || self == .rubber }
}

/// One resource a land yields from (roughly) the year it was first exploited at scale. `value` is game income in
/// $ billions a year at full production; `to` ends a boom (Congo rubber and ivory collapsed by c.1920).
struct ResourceDeposit: Hashable {
    let kind: ResourceKind
    let from: Int
    var to: Int? = nil
    let value: Double
}

enum ExpansionModel {
    /// Approximate first large-scale exploitation years, encyclopedia level. Sources: Encyclopaedia Britannica country
    /// economy articles; USGS Minerals Yearbook country chapters; Wikipedia ("Witwatersrand Gold Rush" 1886, "Kimberley
    /// diamond rush" 1867, "Copperbelt" c.1928, "Congo Free State" rubber 1890–1908, "Shinkolobwe" uranium 1940s,
    /// "Oloibiri oilfield" 1956, "Petroleum in Libya" 1959, "Arlit" uranium 1971, "Gezira Scheme" 1925,
    /// "Firestone Liberia" 1926, "Cocoa production in Ghana" 1890s).
    static let deposits: [String: [ResourceDeposit]] = [
        "ZAF": [.init(kind: .diamonds, from: 1867, value: 3), .init(kind: .gold, from: 1886, value: 6), .init(kind: .uranium, from: 1952, value: 2)],
        "GHA": [.init(kind: .gold, from: 1789, value: 2), .init(kind: .cocoa, from: 1891, value: 3), .init(kind: .manganese, from: 1916, value: 1),
                .init(kind: .bauxite, from: 1941, value: 1)],
        "ZMB": [.init(kind: .copper, from: 1928, value: 5), .init(kind: .cobalt, from: 1933, value: 1)],
        "COD": [.init(kind: .ivory, from: 1880, to: 1914, value: 2), .init(kind: .rubber, from: 1890, to: 1920, value: 4),
                .init(kind: .copper, from: 1911, value: 4), .init(kind: .diamonds, from: 1907, value: 2),
                .init(kind: .uranium, from: 1942, value: 3), .init(kind: .cobalt, from: 1924, value: 2)],
        "NGA": [.init(kind: .palmOil, from: 1789, value: 2), .init(kind: .tin, from: 1909, value: 1), .init(kind: .cocoa, from: 1900, value: 1),
                .init(kind: .oil, from: 1956, value: 8)],
        "LBY": [.init(kind: .agriculture, from: 1789, value: 0.3), .init(kind: .oil, from: 1959, value: 9)],
        "AGO": [.init(kind: .coffee, from: 1900, value: 1), .init(kind: .diamonds, from: 1912, value: 2), .init(kind: .oil, from: 1955, value: 6)],
        "NER": [.init(kind: .groundnuts, from: 1900, value: 0.5), .init(kind: .uranium, from: 1971, value: 3)],
        "GAB": [.init(kind: .timber, from: 1890, value: 1), .init(kind: .uranium, from: 1958, value: 1), .init(kind: .manganese, from: 1962, value: 1),
                .init(kind: .oil, from: 1956, value: 3)],
        "COG": [.init(kind: .timber, from: 1890, value: 1), .init(kind: .rubber, from: 1895, to: 1920, value: 1), .init(kind: .oil, from: 1957, value: 3)],
        "LBR": [.init(kind: .rubber, from: 1926, value: 2), .init(kind: .ironOre, from: 1951, value: 2)],
        "SLE": [.init(kind: .diamonds, from: 1930, value: 2), .init(kind: .ironOre, from: 1933, value: 1)],
        "GIN": [.init(kind: .groundnuts, from: 1850, value: 0.5), .init(kind: .bauxite, from: 1952, value: 3)],
        "NAM": [.init(kind: .diamonds, from: 1908, value: 3), .init(kind: .uranium, from: 1976, value: 2)],
        "BWA": [.init(kind: .agriculture, from: 1789, value: 0.3), .init(kind: .diamonds, from: 1971, value: 4)],
        "ZWE": [.init(kind: .gold, from: 1890, value: 2), .init(kind: .tobacco, from: 1910, value: 1)],
        "CIV": [.init(kind: .timber, from: 1890, value: 1), .init(kind: .cocoa, from: 1920, value: 2), .init(kind: .coffee, from: 1930, value: 1)],
        "CMR": [.init(kind: .timber, from: 1890, value: 1), .init(kind: .cocoa, from: 1900, value: 1)],
        "KEN": [.init(kind: .coffee, from: 1900, value: 1), .init(kind: .tea, from: 1925, value: 1)],
        "TZA": [.init(kind: .sisal, from: 1893, value: 1), .init(kind: .gold, from: 1930, value: 1), .init(kind: .diamonds, from: 1940, value: 1)],
        "UGA": [.init(kind: .cotton, from: 1904, value: 1), .init(kind: .coffee, from: 1920, value: 1)],
        "SEN": [.init(kind: .groundnuts, from: 1840, value: 1), .init(kind: .phosphates, from: 1960, value: 1)],
        "TCD": [.init(kind: .cotton, from: 1928, value: 0.5), .init(kind: .oil, from: 2003, value: 2)],
        "MLI": [.init(kind: .cotton, from: 1920, value: 0.5), .init(kind: .gold, from: 1990, value: 1)],
        "MDG": [.init(kind: .vanilla, from: 1880, value: 0.5), .init(kind: .timber, from: 1789, value: 0.5)],
        "MWI": [.init(kind: .tobacco, from: 1893, value: 0.5), .init(kind: .tea, from: 1891, value: 0.5)],
        "CAF": [.init(kind: .diamonds, from: 1913, value: 1), .init(kind: .timber, from: 1900, value: 0.5)],
        "MOZ": [.init(kind: .agriculture, from: 1789, value: 0.5), .init(kind: .agriculture, from: 1890, value: 0.5)],
        "SSD": [.init(kind: .agriculture, from: 1789, value: 0.3), .init(kind: .oil, from: 1999, value: 3)],
        "RWA": [.init(kind: .coffee, from: 1930, value: 0.5)],
        "BDI": [.init(kind: .coffee, from: 1930, value: 0.5)],
        "ETH": [.init(kind: .coffee, from: 1789, value: 1)],
        // Countries that can be annexed (3.2.0) as well as claimed.
        "EGY": [.init(kind: .cotton, from: 1821, value: 3), .init(kind: .oil, from: 1909, value: 2)],
        "SDN": [.init(kind: .cotton, from: 1925, value: 1)],
        "MAR": [.init(kind: .phosphates, from: 1921, value: 2)],
        // Antarctica (3.10.0): whaling to the 1960s, sealing in the 1800s, science from the IGY (1957), and minerals
        // and oil only once the Madrid Protocol's mining ban can be reviewed (2048).
        "ATA": [.init(kind: .sealing, from: 1789, to: 1900, value: 0.5), .init(kind: .whaling, from: 1789, to: 1964, value: 1.5),
                .init(kind: .science, from: 1957, value: 0.5), .init(kind: .minerals, from: 2048, value: 5), .init(kind: .oil, from: 2048, value: 5)],
    ]

    /// What a land yields in a year. Lands not in the table, or before their resources were found, farm a little.
    static func deposits(for id: String, year: Int) -> [ResourceDeposit] {
        let now = (deposits[id] ?? []).filter { year >= $0.from && year <= ($0.to ?? Int.max) }
        return now.isEmpty ? [ResourceDeposit(kind: .agriculture, from: 1789, value: 0.4)] : now
    }

    /// Ramp-up after taking a land: nothing for 6 months, then linear to full output at 2 years.
    static func rampUp(yearsHeld: Double) -> Double { max(0, min(1, (yearsHeld - 0.5) / 1.5)) }

    /// How well a territory is held: stability (60 = full) and garrison (5K = full), each floored so neglect hurts
    /// without zeroing everything.
    static func holdFactor(stability: Int, garrison: Double) -> Double {
        max(0.25, min(1, Double(stability) / 60)) * max(0.4, min(1, garrison / AttackSizing.expeditionStandard))
    }

    /// $B a year a territory produces now. Annexed countries without a table entry pay 2% of their GDP a year.
    static func annualIncome(_ c: Country, in gs: GameState) -> Double {
        let year = gs.currentYear
        let tabled = deposits[c.id] != nil || WorldCountriesDatabase.postColonialAfrica.contains(c.id)
        let base = tabled ? deposits(for: c.id, year: year).reduce(0) { $0 + $1.value } : c.gdp * 1000 * 0.02
        let held = gs.shadow.claimDates[c.id].map { GameCalendar.years(from: $0, to: gs.currentDate) } ?? 10
        // 3.13.1: the extraction rate and self-rule's share apply here, so every view shows the same figure.
        let share = gs.shadow.territoryPolicies[c.id]?.governance.incomeShare ?? 1
        return base * rampUp(yearsHeld: held) * holdFactor(stability: c.stability, garrison: gs.shadow.garrisons[c.id] ?? AttackSizing.expeditionStandard)
            * rate(c.id, in: gs).incomeMultiplier * share
    }

    /// The player's territories with their yearly income, highest first.
    static func ledger(_ gs: GameState) -> [(country: Country, income: Double, resources: [ResourceKind])] {
        gs.countries.filter { $0.territoryOf == gs.playerCountryID && !$0.isDestroyed }
            .map { ($0, annualIncome($0, in: gs), deposits(for: $0.id, year: gs.currentYear).map(\.kind)) }
            .sorted { $0.income > $1.income }
    }

    /// Strategic resources producing for the player this year, in the eras they matter: oil from 1910 (navy and air
    /// force), uranium from 1942 (the bomb), rubber in the world wars.
    static func strategic(_ gs: GameState) -> Set<ResourceKind> {
        let y = gs.currentYear
        var out: Set<ResourceKind> = []
        for (c, income, kinds) in ledger(gs) where income > 0 {
            _ = c
            for k in kinds where k.isStrategic {
                switch k {
                case .oil where y >= 1910: out.insert(.oil)
                case .uranium where y >= 1942: out.insert(.uranium)
                case .rubber where (1914...1918).contains(y) || (1939...1945).contains(y): out.insert(.rubber)
                default: break
                }
            }
        }
        return out
    }

    // MARK: Politics of expansion

    /// Lands taken (claimed or annexed) in the year up to `date`.
    static func takenLastYear(_ gs: GameState, before date: Date) -> Int {
        let start = GameCalendar.calendar.date(byAdding: .year, value: -1, to: date) ?? date
        return gs.shadow.expansionLog.filter { $0 > start && $0 <= date }.count
    }

    /// The domestic and foreign reaction to the n-th land taken within a year, by era. DESIGN CHOICES:
    /// - Imperial era (before 1919): the first few claims are popular (+0.5 approval each up to 6 a year), then a
    ///   growing anti-imperialist backlash (−0.03 × (n − 6)); ruthlessness 0.5 + 0.003 × (n − 4)².
    /// - Interwar (1919–1944): no bump; ruthlessness 2 + 0.006 × (n − 2)².
    /// - UN era (1945–): approval −3 each, ruthlessness 8 + 0.02 × n², world reaction ×3.
    /// The squared spree term keeps a handful of claims cheap and makes dozens a year dangerous.
    static func politics(year: Int, nth n: Int) -> (popularity: Double, ruthlessness: Double, worldFactor: Double) {
        let x = Double(n)
        switch year {
        case ..<1919:
            let pop = n <= 6 ? 0.5 : -0.03 * (x - 6)
            return (pop, 0.5 + 0.003 * pow(max(0, x - 4), 2), 1 + 0.03 * max(0, x - 6))
        case ..<1945:
            return (-0.1 * max(0, x - 3), 2 + 0.006 * pow(max(0, x - 2), 2), 1.5 + 0.05 * max(0, x - 3))
        default:
            return (-3, 8 + 0.02 * x * x, 3 + 0.1 * x)
        }
    }

    /// Approval bonus from territory income (prosperity at home), capped.
    static func prosperityBonus(incomePerYear: Double) -> Double { min(5, incomePerYear * 0.15) }

    // MARK: Impeachment risk (the same formula Congress uses)

    /// Congress's pressure: above 12 at a monthly poll moves impeachment a stage; below that it holds; popularity over
    /// 38 with ruthlessness under 30 ends it.
    static func impeachmentPressure(popularity: Double, ruthlessness: Double, congress: Int) -> Double {
        (30 - popularity) + ruthlessness * 0.4 + Double(max(0, 40 - congress)) * 0.3
    }

    static let impeachmentThreshold = 12.0
    static let popularityFloor = 38.0

    enum Risk: String { case none = "LOW", rising = "RISING", high = "HIGH" }

    static func risk(pressure: Double) -> Risk {
        pressure > impeachmentThreshold ? .high : (pressure > impeachmentThreshold / 2 ? .rising : .none)
    }

    /// Score for land and wealth: 100 per territory held, 10 per $1B of resources earned, 1000 per statehood.
    static func scoreBonus(territories: Int, earned: Double, statehoods: Int) -> Int {
        territories * 100 + Int(earned * 10) + statehoods * 1000
    }
}

// MARK: - Engine

extension GameEngine {
    /// Current impeachment pressure and risk for the player.
    func impeachmentRisk() -> (pressure: Double, risk: ExpansionModel.Risk) {
        guard let gs = gameState, let p = gs.getPlayerCountry() else { return (0, .none) }
        let pr = ExpansionModel.impeachmentPressure(popularity: gs.shadow.popularity, ruthlessness: gs.shadow.ruthlessness, congress: p.congressionalSupport)
        return (pr, ExpansionModel.risk(pressure: pr))
    }

    /// What one more claim would do to impeachment pressure (for the advisor's warning before it).
    func pressureAfterNextClaim() -> Double {
        guard let gs = gameState, let p = gs.getPlayerCountry() else { return 0 }
        let n = ExpansionModel.takenLastYear(gs, before: gs.currentDate) + 1
        let pol = ExpansionModel.politics(year: gs.currentYear, nth: n)
        return ExpansionModel.impeachmentPressure(popularity: gs.shadow.popularity + pol.popularity,
                                                  ruthlessness: gs.shadow.ruthlessness + pol.ruthlessness, congress: p.congressionalSupport)
    }

    /// Each turn: territories pay into U.S. output, strategic resources take effect, and a warning goes out the first
    /// turn Congress's pressure crosses the threshold (before the monthly poll can move impeachment a stage).
    func processTerritoryEconomy() {
        guard let gs = gameState, let pi = gs.countries.firstIndex(where: { $0.id == gs.playerCountryID }) else { return }
        let yf = gs.turnLength.yearFraction
        var total = 0.0
        for (c, income, kinds) in ExpansionModel.ledger(gs) where income > 0 {
            total += income
            let firstTime = !(gs.shadow.producing.contains(c.id))
            if firstTime {
                gs.shadow.producing.insert(c.id)
                let what = kinds.map(\.title).joined(separator: ", ")
                gs.shadow.post("\(c.name) is now producing \(what).", date: gs.currentDate, severity: 1)
                logPlayEvent("territory_producing", detail: ["land": c.id, "name": PlayHistory.text(c.name), "resources": what,
                                                             "income_b": PlayHistory.num(income), "game_date": PlayHistory.day(gs.currentDate)])
            }
        }
        total += gs.shadow.acquisitionIncome   // 3.13.0: purchases like Louisiana pay too
        let earned = total * yf
        gs.shadow.resourceEarnings += earned
        // 3.13.1: the money lands in the spendable funds (aid, group actions, purchases); a smaller share shows up
        // in national output, so it isn't counted twice.
        gs.shadow.aidRemaining += earned
        gs.shadow.lastTurnCash = earned
        gs.countries[pi].gdp += earned * 0.25 / 1000
        if earned >= 0.01 { gs.shadow.post(String(format: "Territories paid $%.2fB this %@.", earned, gs.turnLength.displayName.lowercased()), date: gs.currentDate) }
        // Heavy extraction and plunder cost goodwill abroad.
        for (c, _, _) in ExpansionModel.ledger(gs) {
            let hit = gs.scale.integer(annual: ExpansionModel.rate(c.id, in: gs).worldHitPerYear)
            if hit > 0 { for o in gs.countries where o.id != gs.playerCountryID && !o.isTerritory && !o.isDestroyed { modifyDiplomaticRelation(from: o.id, to: gs.playerCountryID, by: -hit) } }
        }
        // Strategic resources: uranium speeds the bomb; oil and rubber feed the forces (see AttackSizing / NavalModel).
        if ExpansionModel.strategic(gs).contains(.uranium) && gs.currentDate >= ArsenalCatalog.trinity {
            gs.countries[pi].nuclearWarheads += gs.scale.integer(annual: 20)
        }
        // Warn once when impeachment pressure crosses the line (and again if it drops back and returns).
        let (pressure, _) = impeachmentRisk()
        if pressure > ExpansionModel.impeachmentThreshold && gs.shadow.impeachmentStage < 4 {
            if !gs.shadow.impeachmentWarned {
                gs.shadow.impeachmentWarned = true
                let next = gs.shadow.impeachmentStage + 1
                gs.shadow.post("WARNING from the Chief of Staff: at the next monthly poll Congress moves to \(next >= 4 ? "remove you" : (next == 3 ? "a House impeachment vote" : (next == 2 ? "draft articles of impeachment" : "open impeachment hearings"))) unless approval recovers above \(Int(ExpansionModel.popularityFloor))% and the outrage fades.",
                               date: gs.currentDate, severity: 3)
            }
        } else {
            gs.shadow.impeachmentWarned = false
        }
        self.gameState = gs
    }
}

// MARK: - Territory money (3.13.1)

/// How hard a territory is squeezed. Game balance only (design choices):
/// income ×0.6 / ×1 / ×1.5 / ×2.5; insurgency target +0 / +0 / +12 / +30; stability −0 / −0 / −1 / −3 a month;
/// world relations −0 / −0 / −1 / −4 a year per territory; Plunder also risks revolt (25% a year while unrest is
/// over 60).
enum ExtractionRate: String, Codable, CaseIterable, Identifiable {
    case light, normal, heavy, plunder
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var incomeMultiplier: Double { [0.6, 1, 1.5, 2.5][index] }
    var insurgencyShift: Double { [0, 0, 12, 30][index] }
    var stabilityPerMonth: Double { [0, 0, 1, 3][index] }
    var worldHitPerYear: Double { [0, 0, 1, 4][index] }
    private var index: Int { ExtractionRate.allCases.firstIndex(of: self)! }
}

extension ExpansionModel {
    /// Levy: half a year's income at once (at least $0.2B), −10 stability, +10 unrest, then six months' cooldown.
    static let levyCooldownMonths = 6.0

    static func rate(_ id: String, in gs: GameState) -> ExtractionRate {
        gs.shadow.extraction[id].flatMap(ExtractionRate.init(rawValue:)) ?? .normal
    }

    /// Months until a new territory starts producing (0 once it does).
    static func monthsUntilProducing(_ id: String, in gs: GameState) -> Int {
        guard let claimed = gs.shadow.claimDates[id] else { return 0 }
        return max(0, 6 - (GameCalendar.calendar.dateComponents([.month], from: claimed, to: gs.currentDate).month ?? 0))
    }

    /// What holds a territory's income back, with a one-line fix (nil when nothing does).
    static func limit(_ c: Country, in gs: GameState) -> String? {
        let g = gs.shadow.garrisons[c.id] ?? AttackSizing.expeditionStandard
        if g < AttackSizing.expeditionStandard { return "Low garrison (\(Int(g))K): raise it to \(Int(AttackSizing.expeditionStandard))K in Govern." }
        if let m = stabilityRecoveryMonths(c, in: gs) { return "Stability \(c.stability) → 60 in ~\(m) month\(m == 1 ? "" : "s") at this garrison." }
        if c.stability < 60 { return "Low stability (\(c.stability)): try local elections or a lighter extraction rate." }
        return nil
    }

    /// A levy takes half a year's base income, at least $0.2B.
    static func levyAmount(_ c: Country, in gs: GameState) -> Double {
        let tabled = deposits[c.id] != nil || WorldCountriesDatabase.postColonialAfrica.contains(c.id)
        let base = tabled ? deposits(for: c.id, year: gs.currentYear).reduce(0) { $0 + $1.value } : c.gdp * 1000 * 0.02
        return max(0.2, base * 0.5)
    }

    /// Months left before a territory can be levied again (0 = now). Calendar months, so six turns of a monthly
    /// game is exactly six.
    static func levyCooldown(_ id: String, in gs: GameState) -> Int {
        guard let last = gs.shadow.lastLevy[id] else { return 0 }
        let months = GameCalendar.calendar.dateComponents([.month], from: last, to: gs.currentDate).month ?? 0
        return max(0, Int(levyCooldownMonths) - months)
    }

    /// 3.13.2: in its first year, a well-garrisoned territory under Light or Normal extraction recovers to 60
    /// stability (full output) by its first anniversary. Months left, or nil when it isn't recovering.
    static func stabilityRecoveryMonths(_ c: Country, in gs: GameState) -> Int? {
        guard c.stability < 60, let claimed = gs.shadow.claimDates[c.id], rate(c.id, in: gs).insurgencyShift == 0,
              (gs.shadow.garrisons[c.id] ?? OccupationModel.neededGarrison(c)) >= OccupationModel.neededGarrison(c) else { return nil }
        let left = 12 - (GameCalendar.calendar.dateComponents([.month], from: claimed, to: gs.currentDate).month ?? 0)
        return left > 0 ? left : nil
    }
}

extension GameEngine {
    /// Set a territory's extraction rate (free).
    @discardableResult
    func setExtraction(_ id: String, _ rate: ExtractionRate) -> Bool {
        guard let gs = gameState, gs.getCountry(id: id)?.territoryOf == gs.playerCountryID else { return false }
        gs.shadow.extraction[id] = rate.rawValue
        self.gameState = gs
        return true
    }

    /// Collect a one-off levy from a territory: cash now, stability later. Returns $B collected, or nil.
    @discardableResult
    func collectLevy(_ id: String) -> Double? {
        guard let gs = gameState, let i = gs.countries.firstIndex(where: { $0.id == id && $0.territoryOf == gs.playerCountryID }),
              ExpansionModel.levyCooldown(id, in: gs) == 0 else { return nil }
        let c = gs.countries[i]
        let amount = ExpansionModel.levyAmount(c, in: gs)
        gs.shadow.aidRemaining += amount
        gs.shadow.resourceEarnings += amount
        gs.shadow.lastLevy[id] = gs.currentDate
        gs.countries[i].stability = max(0, c.stability - 10)
        gs.countries[i].profile.outcry = min(100, c.profile.outcry + 10)
        gs.shadow.post(String(format: "A levy on %@ raises $%.1fB. Resentment grows.", c.name, amount), date: gs.currentDate, severity: 1)
        logPlayEvent("territory_levy", detail: ["land": id, "name": PlayHistory.text(c.name), "amount_b": PlayHistory.num(amount),
                                                "game_date": PlayHistory.day(gs.currentDate)])
        self.gameState = gs
        return amount
    }

    /// Pay for something from the spendable funds first, then from national output ($B).
    func spendFunds(_ amount: Double) {
        guard let gs = gameState, amount > 0, let pi = gs.countries.firstIndex(where: { $0.id == gs.playerCountryID }) else { return }
        let fromFunds = min(amount, gs.shadow.aidRemaining)
        gs.shadow.aidRemaining -= fromFunds
        gs.countries[pi].gdp -= (amount - fromFunds) / 1000
        self.gameState = gs
    }
}
