//
//  EconomyModels.swift
//  Global Thermal Nuclear War
//
//  The U.S. federal budget (four taxes, four spending lines, an end-of-year cycle) and five-category foreign aid
//  with per-country need and thanks / partial / reject reactions. Numbers are GTNW's own tuning, expressed as
//  shares of GDP so every era (1789 to today) uses the same model.
//  Repository: https://github.com/kochj23/GTNW
//

import Foundation

// MARK: - Federal budget

struct FederalBudget: Codable, Hashable {
    // Tax rates, percent
    var personalTax: Double = 20
    var corporateTax: Double = 21
    var salesTax: Double = 5
    var tariff: Double = 3
    // Spending, percent of GDP
    var defense: Double = 3.5
    var social: Double = 9
    var research: Double = 1.0
    var foreignAid: Double = 0.25

    /// Fixed obligations (interest, administration) as percent of GDP.
    static let fixedObligations: Double = 4.0

    static let limits: [WritableKeyPath<FederalBudget, Double>: ClosedRange<Double>] = [
        \.personalTax: 0...70, \.corporateTax: 0...60, \.salesTax: 0...25, \.tariff: 0...60,
        \.defense: 0.5...20, \.social: 1...25, \.research: 0...6, \.foreignAid: 0...3,
    ]

    mutating func set(_ key: WritableKeyPath<FederalBudget, Double>, _ value: Double) {
        let r = Self.limits[key] ?? 0...100
        self[keyPath: key] = min(r.upperBound, max(r.lowerBound, value))
    }

    /// Revenue as percent of GDP.
    var revenue: Double { personalTax * 0.5 + corporateTax * 0.12 + salesTax * 0.4 + tariff * 0.15 }
    /// Spending as percent of GDP.
    var spending: Double { defense + social + research + foreignAid + Self.fixedObligations }
    /// Deficit as percent of GDP (negative = surplus).
    var deficit: Double { spending - revenue }

    /// Era-appropriate starting budget: a small 19th-century state, the Cold War warfare state, the modern mix.
    static func forYear(_ year: Int) -> FederalBudget {
        var b = FederalBudget()
        switch year {
        case ..<1913:
            b.personalTax = 0; b.corporateTax = 0; b.salesTax = 4; b.tariff = 25
            b.defense = 1.0; b.social = 1; b.research = 0.1; b.foreignAid = 0
        case 1913..<1941:
            b.personalTax = 8; b.corporateTax = 12; b.salesTax = 3; b.tariff = 15
            b.defense = 1.5; b.social = 3; b.research = 0.2; b.foreignAid = 0.05
        case 1941..<1946:
            b.personalTax = 40; b.corporateTax = 40; b.salesTax = 5; b.tariff = 8
            b.defense = 18; b.social = 3; b.research = 0.8; b.foreignAid = 1.5
        case 1946..<1970:
            b.personalTax = 30; b.corporateTax = 45; b.salesTax = 3; b.tariff = 6
            b.defense = 9; b.social = 5; b.research = 1.5; b.foreignAid = 1.0
        case 1970..<1992:
            b.personalTax = 26; b.corporateTax = 38; b.salesTax = 4; b.tariff = 4
            b.defense = 6; b.social = 8; b.research = 1.2; b.foreignAid = 0.4
        default:
            break
        }
        return b
    }

    /// Foreign-aid pool in billions of dollars for a GDP given in trillions.
    func aidPool(gdpTrillions: Double) -> Double { (foreignAid / 100 * gdpTrillions * 1000).rounded(toPlaces: 1) }
}

/// What a budget is expected to do over a year.
struct BudgetProjection: Equatable {
    var revenue: Double
    var spending: Double
    var deficit: Double
    /// Annual GDP growth, percent.
    var growth: Double
    /// Quality-of-life change per year, points.
    var qualityOfLifeChange: Double
    /// Military strength change per year, points (1–100 scale).
    var militaryChange: Double
    /// Popularity change when the budget is enacted, points.
    var popularityChange: Double
}

enum BudgetModel {
    static func project(_ b: FederalBudget, atWar: Bool = false) -> BudgetProjection {
        let taxBurden = b.revenue
        var growth = 2.5 + b.research * 0.6 - max(0, taxBurden - 15) * 0.12 - max(0, b.deficit - 3) * 0.25
        growth -= b.tariff > 10 ? (b.tariff - 10) * 0.05 : 0
        if atWar { growth -= 0.5 }
        growth = min(8, max(-6, growth))
        let qol = (b.social - 9) * 0.8 + growth * 0.3 - max(0, taxBurden - 15) * 0.2
        let military = (b.defense - 3.5) * 2.5
        var pop = -max(0, taxBurden - 15) * 1.2 + (b.social - 9) * 0.6 + growth * 0.8 - max(0, b.deficit - 4) * 0.8
        pop += taxBurden < 15 ? (15 - taxBurden) * 0.5 : 0
        return BudgetProjection(revenue: taxBurden, spending: b.spending, deficit: b.deficit, growth: growth,
                                qualityOfLifeChange: qol, militaryChange: military, popularityChange: min(8, max(-12, pop)))
    }
}

// MARK: - Foreign aid

enum AidReaction: String, Codable, Equatable {
    case thanks        // accepted in full
    case partial       // accepted the part they needed, returned the rest
    case reject        // refused politely: they don't need it
    case publicRejection // refused loudly: they don't want *your* money

    var label: String {
        switch self {
        case .thanks: return "Accepted with thanks"
        case .partial: return "Partly accepted"
        case .reject: return "Declined"
        case .publicRejection: return "Publicly rejected"
        }
    }
}

struct AidOutcome: Equatable {
    var reaction: AidReaction
    var accepted: AidVector
    var returned: Double
    var relationChange: Int
    var message: String
}

enum AidModel {
    /// Decide how a country responds to an aid package. Pure: no game state is changed.
    static func evaluate(package: AidVector, need: AidVector, relation: Int, recipient: Country,
                         donorName: String) -> AidOutcome {
        let offered = package.total
        guard offered > 0 else {
            return AidOutcome(reaction: .reject, accepted: AidVector(), returned: 0, relationChange: 0, message: "Nothing was sent.")
        }
        let name = recipient.name
        // Hostile governments won't be seen taking our money.
        if relation < -50 {
            return AidOutcome(reaction: .publicRejection, accepted: AidVector(), returned: offered, relationChange: -3,
                              message: "\(name) denounces the offer as a bribe and sends every dollar back.")
        }
        var accepted = AidVector()
        for c in AidCategory.allCases {
            // Countries take up to 125% of what they asked for in each category.
            accepted[c] = min(package[c], need[c] * 1.25)
        }
        let taken = accepted.total
        let returned = max(0, offered - taken)
        if taken < 0.05 {
            return AidOutcome(reaction: .reject, accepted: AidVector(), returned: offered, relationChange: 0,
                              message: "\(name) thanks \(donorName) but says it has no need for this kind of help.")
        }
        let needTotal = max(0.5, need.total)
        let gain = Int(min(25, max(1, taken / needTotal * 18)).rounded())
        if returned > 0.05 {
            return AidOutcome(reaction: .partial, accepted: accepted, returned: returned, relationChange: max(1, gain - 2),
                              message: String(format: "%@ accepts $%.1fB and returns $%.1fB it cannot use.", name, taken, returned))
        }
        return AidOutcome(reaction: .thanks, accepted: accepted, returned: 0, relationChange: gain,
                          message: String(format: "%@ welcomes $%.1fB from %@ — \"exactly what we needed.\"", name, taken, donorName))
    }

    /// Apply accepted aid to the recipient country.
    static func apply(_ accepted: AidVector, to c: inout Country) {
        var p = c.profile
        p.qualityOfLife = min(100, p.qualityOfLife + accepted.humanitarian * 0.8)
        p.outcry = max(0, p.outcry - accepted.humanitarian * 1.5)
        c.economicStrength = min(100, c.economicStrength + Int((accepted.economic * 0.6).rounded()))
        c.gdp += accepted.economic / 1000
        c.stability = min(100, c.stability + Int((accepted.intelligence * 2).rounded()))
        p.anxieties.political = max(0, p.anxieties.political - accepted.intelligence * 3)
        c.militaryStrength = min(100, c.militaryStrength + Int((accepted.military * 0.8).rounded()))
        p.anxieties.military = max(0, p.anxieties.military - accepted.military * 2)
        if accepted.nuclear > 0 {
            c.nuclearWarheads += Int(accepted.nuclear * 2)
            if c.nuclearStatus == .none { c.nuclearStatus = .developing }
        }
        for cat in AidCategory.allCases { p.aidNeed[cat] = max(0, p.aidNeed[cat] - accepted[cat]) }
        c.profile = p
    }
}
