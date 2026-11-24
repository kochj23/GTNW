//
//  HomeFront.swift
//  Global Thermal Nuclear War
//
//  Power plays at home (3.36.0): the levers a President can pull on his own government, written as generic
//  mechanics any President in any era can try. Seven orders, each from the command box, the chief of staff and the
//  Situation Room's HOME FRONT sheet, each with the cabinet's advice and a price that comes due later:
//    • troops in your own states, over a governor's objection;
//    • fixing the numbers: fire the chief statistician, bury the bad reports (the true figures stay in the engine);
//    • leaning on the central bank (or the era's equivalent) for cheaper money now and inflation later;
//    • government equity stakes in strategic industries, with conflict-of-interest scandals;
//    • staying in power: defy the term limit, postpone the election, or (lawfully) repeal the 22nd Amendment;
//    • a missile shield that stops only a fraction of incoming warheads, years and billions later;
//    • nuclear test detonations, priced by the test-ban treaties of the day.
//  Everything here is pure: era rules, odds and the reported-versus-true economy. The engine half is in
//  HomeFrontEngine.swift, the command box half in HomePlayCommands.swift.
//  Repository: https://github.com/kochj23/GTNW
//

import Foundation

/// The seven power plays. The raw value is also the command box verb (`CommandVerb`).
enum HomePlay: String, Codable, CaseIterable, Sendable {
    case troopsHome, fixNumbers, leanOnBank, buyStake, stayInPower, missileShield, nuclearTest

    init?(verb: CommandVerb) { self.init(rawValue: verb.rawValue) }

    var title: String {
        switch self {
        case .troopsHome: return "TROOPS TO A STATE"
        case .fixNumbers: return "FIX THE NUMBERS"
        case .leanOnBank: return "LEAN ON THE CENTRAL BANK"
        case .buyStake: return "GOVERNMENT EQUITY STAKE"
        case .stayInPower: return "STAY IN POWER"
        case .missileShield: return "MISSILE SHIELD"
        case .nuclearTest: return "NUCLEAR TEST"
        }
    }

    /// The modes an order can take; the first is the default.
    var modes: [String] {
        switch self {
        case .troopsHome: return ["deploy", "withdraw"]
        case .fixNumbers: return ["fire", "restore"]
        case .leanOnBank: return ["pressure", "overrule", "release"]
        case .buyStake: return ["buy", "sell"]
        case .stayInPower: return ["defy", "postpone", "amendment", "thirdTerm"]
        case .missileShield: return ["start", "cancel"]
        case .nuclearTest: return ["underground", "atmospheric"]
        }
    }

    /// One line for the chief of staff's actions list.
    var toolLine: String {
        switch self {
        case .troopsHome: return "troopsHome ([deploy|withdraw, state]): federal troops into one of your states over its governor"
        case .fixNumbers: return "fixNumbers ([fire|restore]): fire the chief statistician, bury bad reports"
        case .leanOnBank: return "leanOnBank ([pressure|overrule|release]): make the central bank cut rates"
        case .buyStake: return "buyStake ([buy|sell, industry]): government equity stake"
        case .stayInPower: return "stayInPower ([defy|postpone|amendment|thirdTerm]): stay past your term"
        case .missileShield: return "missileShield ([start|cancel]): multi-year missile defense"
        case .nuclearTest: return "nuclearTest ([underground|atmospheric]): test detonation"
        }
    }

    /// The cabinet posts that argue against it (overruling them costs their loyalty).
    var opposedBy: [String] {
        switch self {
        case .troopsHome: return ["whc", "defense"]
        case .fixNumbers: return ["economic", "press"]
        case .leanOnBank: return ["economic"]
        case .buyStake: return ["economic"]
        case .stayInPower: return ["whc", "defense", "state", "press"]
        case .missileShield: return []
        case .nuclearTest: return ["state"]
        }
    }
}

// MARK: - Saved state

/// Federal troops sent into one of the President's own states.
struct HomeDeployment: Codable, Hashable, Sendable {
    var state: String
    var since: Date
    /// Thousands of troops.
    var troops: Double
    /// The state's unrest when they arrived (high unrest: they may restore order; low: they inflame it).
    var unrestAtStart: Double
    /// The governor objected (always, in this order: a governor who asks for troops is a different story).
    var overObjection = true
    /// A court has ruled on it.
    var challenged = false
}

/// A government stake in one industry.
struct EquityStake: Codable, Hashable, Sendable {
    var industry: String
    var bought: Date
    /// Billions of dollars paid.
    var value: Double
}

/// An attempt to stay in power, one stage a turn.
struct TenureBid: Codable, Hashable, Sendable {
    var route: String
    var started: Date
    /// Stages already passed.
    var stage = 0
}

/// One nuclear test.
struct NuclearTestRecord: Codable, Hashable, Sendable {
    var date: Date
    var atmospheric: Bool
    var status: LegalStatus
}

/// Everything the power plays keep between turns. Every field defaults, so older saves load.
struct HomeFrontState: Codable, Sendable {
    var deployments: [HomeDeployment] = []
    /// Fixing the numbers: when the statistician was fired (nil = an independent office), whether the true
    /// figures have leaked, the figures that leaked, and how many statisticians have been fired.
    var statisticianFired: Date?
    var numbersLeaked: Date?
    var leakedGrowth: Double?
    var leakedInflation: Double?
    var firings = 0
    /// The central bank: points of rate cut forced below neutral, whether it has been overruled outright, when it was
    /// last leaned on, inflation (nil until anything here touches the economy) and the credit spread markets demand.
    var bankPressure: Double = 0
    var bankOverruled = false
    var lastBankPressure: Date?
    var inflation: Double?
    var creditSpread: Double = 0
    /// Equity stakes, income they have paid ($B), and conflict-of-interest scandals so far.
    var stakes: [EquityStake] = []
    var stakeIncome: Double = 0
    var scandals = 0
    /// Staying in power: the attempt under way, failed attempts, and whether the 22nd Amendment has been repealed.
    var bid: TenureBid?
    var bidsFailed = 0
    var termLimitRepealed = false
    /// Missile shield: when the program began, when it is (or was) ready, billions spent, warheads stopped.
    var shieldStarted: Date?
    var shieldReady: Date?
    var shieldSpent: Double = 0
    var shieldIntercepted = 0
    var tests: [NuclearTestRecord] = []

    init() {}

    /// True once anything here is in play (the turn step does nothing, and draws nothing from the RNG, until then).
    var isActive: Bool {
        !deployments.isEmpty || statisticianFired != nil || inflation != nil || !stakes.isEmpty || bid != nil || shieldStarted != nil
    }

    enum CodingKeys: String, CodingKey {
        case deployments, statisticianFired, numbersLeaked, leakedGrowth, leakedInflation, firings
        case bankPressure, bankOverruled, lastBankPressure, inflation, creditSpread
        case stakes, stakeIncome, scandals, bid, bidsFailed, termLimitRepealed
        case shieldStarted, shieldReady, shieldSpent, shieldIntercepted, tests
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        deployments = (try? c.decodeIfPresent([HomeDeployment].self, forKey: .deployments)) ?? []
        statisticianFired = try? c.decodeIfPresent(Date.self, forKey: .statisticianFired)
        numbersLeaked = try? c.decodeIfPresent(Date.self, forKey: .numbersLeaked)
        leakedGrowth = try? c.decodeIfPresent(Double.self, forKey: .leakedGrowth)
        leakedInflation = try? c.decodeIfPresent(Double.self, forKey: .leakedInflation)
        firings = (try? c.decodeIfPresent(Int.self, forKey: .firings)) ?? 0
        bankPressure = (try? c.decodeIfPresent(Double.self, forKey: .bankPressure)) ?? 0
        bankOverruled = (try? c.decodeIfPresent(Bool.self, forKey: .bankOverruled)) ?? false
        lastBankPressure = try? c.decodeIfPresent(Date.self, forKey: .lastBankPressure)
        inflation = try? c.decodeIfPresent(Double.self, forKey: .inflation)
        creditSpread = (try? c.decodeIfPresent(Double.self, forKey: .creditSpread)) ?? 0
        stakes = (try? c.decodeIfPresent([EquityStake].self, forKey: .stakes)) ?? []
        stakeIncome = (try? c.decodeIfPresent(Double.self, forKey: .stakeIncome)) ?? 0
        scandals = (try? c.decodeIfPresent(Int.self, forKey: .scandals)) ?? 0
        bid = try? c.decodeIfPresent(TenureBid.self, forKey: .bid)
        bidsFailed = (try? c.decodeIfPresent(Int.self, forKey: .bidsFailed)) ?? 0
        termLimitRepealed = (try? c.decodeIfPresent(Bool.self, forKey: .termLimitRepealed)) ?? false
        shieldStarted = try? c.decodeIfPresent(Date.self, forKey: .shieldStarted)
        shieldReady = try? c.decodeIfPresent(Date.self, forKey: .shieldReady)
        shieldSpent = (try? c.decodeIfPresent(Double.self, forKey: .shieldSpent)) ?? 0
        shieldIntercepted = (try? c.decodeIfPresent(Int.self, forKey: .shieldIntercepted)) ?? 0
        tests = (try? c.decodeIfPresent([NuclearTestRecord].self, forKey: .tests)) ?? []
    }
}

// MARK: - Era rules and numbers

/// One industry the government can buy into.
struct StrategicIndustry: Hashable, Sendable {
    let id: String
    let name: String
    let from: Int
    let to: Int?
    /// Defense-related: the stake also adds a little military strength.
    let strategic: Bool
    func exists(in year: Int) -> Bool { year >= from && year <= (to ?? Int.max) }
}

/// The economy as two sets of books: what is true (the engine plays on these) and what the government reports.
struct EconomyFigures: Equatable, Sendable {
    /// Annual GDP growth, percent.
    var growth: Double
    /// Annual inflation, percent.
    var inflation: Double
    /// What the government pays to borrow, percent.
    var borrowing: Double
}

enum HomeFrontModel {

    // MARK: Troops at home

    /// Thousands of troops a deployment sends, by era (a regiment in the 1790s, a division-sized force today).
    static func homeTroops(year: Int) -> Double { year < 1860 ? 2 : year < 1940 ? 5 : 10 }
    /// Unrest above which federal troops can restore order; below it they inflame the state.
    static let orderThreshold = 45.0

    // MARK: Statistics

    /// Who keeps the government's numbers, by era.
    static func statsOffice(year: Int) -> String {
        switch year {
        case ..<1866: return "the Treasury's statistics clerk"
        case ..<1884: return "the Treasury's Bureau of Statistics"
        default: return "the Bureau of Labor Statistics"
        }
    }

    /// How far the official figures are from the truth, by months since the statistician was fired: the error grows.
    static func officialBias(months: Double) -> (growth: Double, inflation: Double) {
        let m = max(0, months)
        return (min(4, 0.6 + 0.12 * m), -min(3, 0.4 + 0.08 * m))
    }

    /// Annual chance the true figures leak, by years since the firing: secrets keep worse every year.
    static func leakAnnual(years: Double) -> Double { min(0.9, 0.35 + 0.2 * max(0, years)) }

    // MARK: Central bank

    /// The central bank (or the era's equivalent) a President can lean on, or nil when there is none.
    static func centralBank(year: Int, nation: String) -> String? {
        guard nation == "USA" else {
            let founded = ["GBR": 1694, "SWE": 1668, "FRA": 1800, "NLD": 1814, "RUS": 1860, "DEU": 1876, "JPN": 1882, "ITA": 1893]
            return year >= (founded[nation] ?? 1913) ? "the central bank" : nil
        }
        switch year {
        case 1791...1811: return "the Bank of the United States"
        case 1816...1836: return "the Second Bank of the United States"
        case 1914...: return "the Federal Reserve"
        default: return nil
        }
    }

    /// Why there is no bank to lean on.
    static func noBankReason(year: Int, nation: String) -> String {
        guard nation == "USA" else { return "Your nation has no central bank in \(year)." }
        if year < 1791 { return "No central bank in \(year): the Bank of the United States is chartered in 1791." }
        if (1812...1815).contains(year) { return "No central bank in \(year): the first Bank's charter lapsed in 1811; the second opens in 1816." }
        return "No central bank in \(year): the Independent Treasury holds the government's money until the Federal Reserve opens in 1914. There are no rates to lean on."
    }

    /// Inflation in a quiet year of the era.
    static func baselineInflation(year: Int) -> Double { year < 1914 ? 1.0 : year < 1971 ? 2.5 : 2.2 }

    /// Points of rate cut an order forces: a pressure campaign moves an independent bank one point, overruling it two.
    static let pressureStep = 1.0
    static let overruleStep = 2.0
    static let maxPressure = 4.0

    /// Inflation the bank's pressure is pushing toward.
    static func inflationTarget(baseline: Double, pressure: Double, overruled: Bool) -> Double {
        baseline + pressure * 1.6 + (overruled ? 1.0 : 0)
    }

    static func borrowing(inflation: Double, spread: Double, overruled: Bool) -> Double {
        2 + inflation * 0.6 + spread + (overruled ? 1.0 : 0)
    }

    // MARK: Equity stakes

    static let industries: [StrategicIndustry] = [
        StrategicIndustry(id: "shipbuilding", name: "Shipbuilding", from: 1789, to: nil, strategic: true),
        StrategicIndustry(id: "railroads", name: "Railroads", from: 1830, to: 1970, strategic: false),
        StrategicIndustry(id: "steel", name: "Steel", from: 1870, to: nil, strategic: true),
        StrategicIndustry(id: "telecom", name: "Telegraph and telephone", from: 1850, to: nil, strategic: false),
        StrategicIndustry(id: "oil", name: "Oil and gas", from: 1901, to: nil, strategic: true),
        StrategicIndustry(id: "autos", name: "Automobiles", from: 1908, to: nil, strategic: false),
        StrategicIndustry(id: "aerospace", name: "Aerospace", from: 1920, to: nil, strategic: true),
        StrategicIndustry(id: "semiconductors", name: "Semiconductors", from: 1960, to: nil, strategic: true),
        StrategicIndustry(id: "rareEarths", name: "Rare earths and critical minerals", from: 1990, to: nil, strategic: true),
    ]

    static func industry(_ id: String) -> StrategicIndustry? { industries.first { $0.id == id } }

    /// A stake's price in billions: a tenth of a percent of the economy.
    static func stakePrice(gdpTrillions: Double) -> Double { max(0.01, gdpTrillions * 1000 * 0.001) }
    /// What a stake pays each year, as a share of its price.
    static let stakeYield = 0.06
    /// Annual chance of a conflict-of-interest scandal: more stakes, more insiders trading ahead of the government.
    static func scandalAnnual(stakes: Int) -> Double { min(0.5, 0.06 * Double(max(0, stakes))) }

    // MARK: Staying in power

    /// How far the generals would follow an unconstitutional order (0…100).
    static func militaryLoyalty(popularity: Double, ruthlessness: Double, defense: Double) -> Double {
        min(100, max(0, 55 + (popularity - 50) * 0.4 + (defense - 3.5) * 2 - ruthlessness * 0.1))
    }

    /// The stages an attempt must pass, in order.
    static func stages(route: String) -> [String] {
        route == "amendment" ? ["congress", "states"] : ["congress", "courts", "states", "military"]
    }

    /// The odds one stage goes the President's way. Never better than even; a court almost never lets it stand.
    static func stageOdds(_ stage: String, route: String, congress: Double, popularity: Double, outcry: Double,
                          loyalty: Double, courtsWeakened: Bool) -> Double {
        let lawful = route == "amendment"
        switch stage {
        case "congress":
            return lawful ? min(0.5, max(0.01, (congress - 60) / 40)) : min(0.6, max(0.02, (congress - 55) / 60))
        case "courts":
            return courtsWeakened ? 0.3 : 0.08
        case "states":
            return lawful ? min(0.4, max(0.01, (popularity - 55) / 45))
                : min(0.6, max(0.02, (popularity - 45) / 50 - outcry / 200))
        case "military":
            return min(0.7, max(0.02, (loyalty - 40) / 80))
        default: return 0
        }
    }

    /// Of failed unconstitutional attempts, the share that end in removal (the rest: the President backs down).
    static let removalShare = 0.85

    // MARK: Missile shield

    /// Ballistic missiles to stop exist from 1957 (the first ICBM tests; Nike-Zeus research begins).
    static let shieldFrom = 1957
    static let abmTreatyInForce = GameCalendar.date(year: 1972, month: 10, day: 3)
    static let abmTreatyEnds = GameCalendar.date(year: 2002, month: 6, day: 13)

    static func shieldStatus(on date: Date) -> LegalStatus {
        date >= abmTreatyInForce && date < abmTreatyEnds ? .treatyBanned : .legal
    }

    static func shieldBuildYears(year: Int) -> Int { year < 1990 ? 6 : 4 }

    /// Share of the warheads that reach the shield it stops, by the era's technology. Never most of them.
    static func interceptRate(year: Int) -> Double {
        switch year {
        case ..<1980: return 0.10
        case ..<2000: return 0.15
        case ..<2020: return 0.25
        default: return 0.30
        }
    }

    /// Warheads stopped: a fixed share, rounded down (deterministic, no dice).
    static func intercepted(_ incoming: Int, rate: Double) -> Int {
        guard incoming > 0, rate > 0 else { return 0 }
        return min(incoming, Int((Double(incoming) * min(1, rate)).rounded(.down)))
    }

    /// Annual cost in billions while it is built (0.2% of GDP), and a quarter of that to run it.
    static func shieldAnnualCost(gdpTrillions: Double) -> Double { gdpTrillions * 1000 * 0.002 }

    // MARK: Nuclear tests

    /// The first contained underground test (Rainier, 19 Sep 1957).
    static let undergroundFrom = GameCalendar.date(year: 1957, month: 9, day: 19)
    /// The Limited Test Ban Treaty in force (10 Oct 1963): no tests in the atmosphere, under water or in space.
    static let limitedTestBan = GameCalendar.date(year: 1963, month: 10, day: 10)
    /// The U.S. moratorium on testing (1 Oct 1992) and the Comprehensive Test Ban Treaty opened for signature (1996).
    static let moratorium = GameCalendar.date(year: 1992, month: 10, day: 1)

    static func testStatus(atmospheric: Bool, on date: Date) -> LegalStatus {
        if atmospheric { return date >= limitedTestBan ? .treatyBanned : .legal }
        return date >= moratorium ? .restricted : .legal
    }

    static func testNote(atmospheric: Bool, on date: Date) -> String {
        switch testStatus(atmospheric: atmospheric, on: date) {
        case .treatyBanned: return "Violates the Limited Test Ban Treaty (1963)."
        case .restricted: return "Breaks the testing moratorium (1992) and the Comprehensive Test Ban Treaty's norm (1996)."
        default: return atmospheric ? "Legal in this era; the fallout drifts downwind." : "Legal in this era."
        }
    }

    // MARK: Small helpers

    static func one(_ v: Double) -> String {
        let r = (v * 10).rounded() / 10
        return r == r.rounded() ? "\(Int(r)).0" : "\(r)"
    }

    static func signed(_ v: Double) -> String { (v >= 0 ? "+" : "") + one(v) }

    static func billions(_ v: Double) -> String {
        v >= 1000 ? "$\(one(v / 1000))T" : v >= 1 ? "$\(Int(v.rounded()))B" : "$\(Int((v * 1000).rounded()))M"
    }
}
