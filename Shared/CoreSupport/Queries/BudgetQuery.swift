//
//  BudgetQuery.swift
//  GTNWCore
//
//  `{"q":"budget","draft":{"personalTax":25,…}}` (draft optional): BudgetView. The four tax rates and four spending
//  lines with their limits and steps, the year's projection for the draft (or the budget in force) from the
//  engine's BudgetModel, where the money goes, the foreign-aid pool it funds, the era's starting budget (RESET), and
//  whether the new year's budget is waiting for review. Enacted with the `enactBudget` verb.
//

#if GTNW_CORE
import Foundation

enum BudgetQuery: BridgeQuery {
    static let name = "budget"

    /// FederalBudget's eight figures, all optional in a draft.
    struct Figures: Codable {
        var personalTax: Double?, corporateTax: Double?, salesTax: Double?, tariff: Double?
        var defense: Double?, social: Double?, research: Double?, foreignAid: Double?

        init(_ b: FederalBudget) {
            personalTax = b.personalTax; corporateTax = b.corporateTax; salesTax = b.salesTax; tariff = b.tariff
            defense = b.defense; social = b.social; research = b.research; foreignAid = b.foreignAid
        }

        /// Laid over `base`, each figure clamped to its limits (FederalBudget.set).
        func budget(over base: FederalBudget) -> FederalBudget {
            var b = base
            let pairs: [(WritableKeyPath<FederalBudget, Double>, Double?)] = [
                (\.personalTax, personalTax), (\.corporateTax, corporateTax), (\.salesTax, salesTax), (\.tariff, tariff),
                (\.defense, defense), (\.social, social), (\.research, research), (\.foreignAid, foreignAid),
            ]
            for (k, v) in pairs { if let v, v.isFinite { b.set(k, v) } }
            return b
        }
    }

    struct Args: Decodable { var draft: Figures? }

    struct Slider: Encodable { var key: String; var label: String; var group: String; var min: Double; var max: Double; var step: Double; var value: Double }
    struct Row: Encodable { var label: String; var value: String; var bad: Bool }
    struct Bar: Encodable { var label: String; var share: Double }

    struct Result: Encodable {
        var title: String
        var pending: String?
        var sliders: [Slider]
        var projection: [Row]
        var bars: [Bar]
        var reset: Figures
        var current: Figures
    }

    static let fields: [(key: String, label: String, group: String, path: WritableKeyPath<FederalBudget, Double>, step: Double)] = [
        ("personalTax", "Personal income tax", "income", \.personalTax, 1), ("corporateTax", "Corporate tax", "income", \.corporateTax, 1),
        ("salesTax", "Sales tax", "income", \.salesTax, 0.5), ("tariff", "Import tariff", "income", \.tariff, 1),
        ("defense", "Defense", "spending", \.defense, 0.25), ("social", "Social programs", "spending", \.social, 0.25),
        ("research", "Research & investment", "spending", \.research, 0.1), ("foreignAid", "Foreign aid", "spending", \.foreignAid, 0.05),
    ]

    static func run(_ args: Args, engine: GameEngine?) throws -> Result {
        let (_, gs) = try GTNWBridge.game(engine)
        let draft = args.draft?.budget(over: gs.shadow.budget) ?? gs.shadow.budget
        let p = BudgetModel.project(draft, atWar: !(gs.getPlayerCountry()?.atWarWith.isEmpty ?? true))
        let f = { (v: Double) in String(format: "%.1f%% of GDP", v) }
        let parts: [(String, Double)] = [("DEF", draft.defense), ("SOC", draft.social), ("R&D", draft.research), ("AID", draft.foreignAid),
                                         ("FIX", FederalBudget.fixedObligations)]
        return Result(
            title: "Federal Budget \(gs.currentYear)",
            pending: gs.shadow.budgetReviewPending ? "The budget for the new year is about to be processed. Accept it as is, or adjust it first." : nil,
            sliders: fields.map { s in
                let r = FederalBudget.limits[s.path] ?? 0...100
                return Slider(key: s.key, label: s.label, group: s.group, min: r.lowerBound, max: r.upperBound, step: s.step, value: draft[keyPath: s.path])
            },
            projection: [
                Row(label: "Revenue", value: f(p.revenue), bad: false),
                Row(label: "Spending", value: f(p.spending), bad: false),
                Row(label: p.deficit >= 0 ? "Deficit" : "Surplus", value: f(abs(p.deficit)), bad: p.deficit > 4),
                Row(label: "GDP growth", value: String(format: "%+.1f%% / yr", p.growth), bad: p.growth < 1),
                Row(label: "Quality of life", value: String(format: "%+.1f / yr", p.qualityOfLifeChange), bad: p.qualityOfLifeChange < 0),
                Row(label: "Military strength", value: String(format: "%+.1f / yr", p.militaryChange), bad: p.militaryChange < 0),
                Row(label: "Popularity at year end", value: String(format: "%+.1f", p.popularityChange), bad: p.popularityChange < 0),
                Row(label: "Foreign-aid pool", value: String(format: "$%.1fB", draft.aidPool(gdpTrillions: gs.getPlayerCountry()?.gdp ?? 1)), bad: false),
            ],
            bars: parts.map { Bar(label: $0.0, share: QueryText.round2(max(0, $0.1) / max(0.1, p.spending))) },
            reset: Figures(FederalBudget.forYear(gs.currentYear)), current: Figures(gs.shadow.budget))
    }
}
#endif
