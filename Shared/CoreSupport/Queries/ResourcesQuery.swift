//
//  ResourcesQuery.swift
//  GTNWCore
//
//  `{"q":"resources"}`: ResourcesSheet. Income from every territory: this turn's cash and the funds it lands in,
//  the yearly total, what the land itself yields, the strategic resources held, and per territory what it produces,
//  when it starts producing, its extraction rate and levy, and any limit on it. Changed with the `setExtraction`
//  and `collectLevy` verbs.
//

#if GTNW_CORE
import Foundation

enum ResourcesQuery: BridgeQuery {
    static let name = "resources"

    struct Rate: Encodable { var id: String; var title: String; var harsh: Bool }

    struct Territory: Encodable {
        var id: String
        var name: String
        var resources: String
        var income: String
        var waiting: Bool
        var rate: String
        var levyTitle: String
        var canLevy: Bool
        var limit: String?
    }

    struct Result: Encodable {
        var date: String
        var turnLine: String
        var totalLine: String
        var yieldLine: String
        var strategic: String?
        var rates: [Rate]
        var territories: [Territory]
    }

    static func run(_ args: NoArgs, engine: GameEngine?) throws -> Result {
        let (_, gs) = try GTNWBridge.game(engine)
        let rows = ExpansionModel.ledger(gs)
        let total = rows.reduce(0) { $0 + $1.income }
        let strategic = ExpansionModel.strategic(gs)
        return Result(
            date: gs.currentDateLabel,
            turnLine: String(format: "This turn +$%.2fB · funds $%.1fB · territory cash goes straight into your funds", gs.shadow.lastTurnCash, gs.shadow.aidRemaining),
            totalLine: String(format: "Total $%.1fB a year · earned so far $%.1fB · approval +%.1f from prosperity", total,
                              gs.shadow.resourceEarnings, ExpansionModel.prosperityBonus(incomePerYear: total)),
            yieldLine: String(format: "Land yield $%.1fB a year at full production · rises with years held",
                              rows.reduce(0) { $0 + ExpansionModel.landYield($1.country, in: gs) }),
            strategic: strategic.isEmpty ? nil : "Strategic: " + strategic.map { k in
                switch k {
                case .oil: return "oil fuels the fleet and air arm"
                case .uranium: return "uranium speeds the bomb"
                default: return "rubber keeps the wartime army moving"
                }
            }.sorted().joined(separator: " · "),
            rates: ExtractionRate.ordinary.map { Rate(id: $0.rawValue, title: $0.title, harsh: $0.insurgencyShift > 0) },
            territories: rows.map { r in
                let id = r.country.id
                let wait = ExpansionModel.monthsUntilProducing(id, in: gs)
                let cooldown = ExpansionModel.levyCooldown(id, in: gs)
                let starting = wait == 0 && r.income < 0.005
                return Territory(
                    id: id, name: r.country.name, resources: r.resources.map(\.title).joined(separator: ", "),
                    income: wait > 0 ? "Producing in \(wait) month\(wait == 1 ? "" : "s")" : (starting ? "First income next month" : String(format: "$%.2fB/yr", r.income)),
                    waiting: wait > 0 || starting, rate: ExpansionModel.rate(id, in: gs).rawValue,
                    levyTitle: cooldown > 0 ? "Levy in \(cooldown)mo" : String(format: "Collect $%.1fB", ExpansionModel.levyAmount(r.country, in: gs)),
                    canLevy: cooldown == 0, limit: ExpansionModel.limit(r.country, in: gs))
            })
    }
}
#endif
