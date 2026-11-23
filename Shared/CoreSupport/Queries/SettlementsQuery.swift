//
//  SettlementsQuery.swift
//  GTNWCore
//
//  `{"q":"settlements"}`: a surrender waiting for the President's terms (SettlementSheet): annex the loser as a
//  territory (with an optional new name) or let it form one of the post-war governments, each with the cabinet's
//  take and, for annexation, the three-line warnings. Answered with the `settle` verb; until then the sheet stays up.
//

#if GTNW_CORE
import Foundation

enum SettlementsQuery: BridgeQuery {
    static let name = "settlements"

    struct Option: Encodable {
        /// "annex" or a PostWarGovernment id.
        var choice: String
        var title: String
        var summary: String
        var button: String
        var who: String
        var take: String
    }

    struct Settlement: Encodable {
        var id: String
        var loser: String
        var loserName: String
        var loserFlag: String
        var date: String
        var headline: String
        var annex: Option
        var renamePlaceholder: String
        var maxNameLength: Int
        var warnings: [WarSupport.Warning]
        var governmentsHeading: String
        var governments: [Option]
    }

    struct Result: Encodable { var date: String; var settlements: [Settlement] }

    static func run(_ args: NoArgs, engine: GameEngine?) throws -> Result {
        let (e, gs) = try GTNWBridge.game(engine)
        let owner = gs.getPlayerCountry()
        let territory = CombatModel.territoryTitle(ownerID: owner?.id ?? "USA", ownerName: owner?.name ?? "")
        func option(_ choice: SettlementChoice, id: String, title: String, summary: String, button: String) -> Option {
            let take = CombatModel.advisorTake(on: choice)
            let who = AdviceEngine.advisor(for: take.role, in: gs.advisors)?.name ?? AdviceEngine.roleTitle(take.role)
            return Option(choice: id, title: title, summary: summary, button: button, who: who, take: take.text)
        }
        let list = gs.shadow.pendingSettlements.map { s -> Settlement in
            let loser = gs.getCountry(id: s.loser)
            let name = loser?.name ?? s.loser
            return Settlement(
                id: s.id.uuidString, loser: s.loser, loserName: name, loserFlag: loser?.flag ?? "", date: GameCalendar.format(s.date),
                headline: "\(name) has surrendered. What are your orders, Mr. President?",
                annex: option(.annex, id: "annex", title: "Annex as \(territory) — \(loser?.name ?? "")",
                              summary: "Its arsenal is seized and it flies our flag on the map. Occupation means insurgents, lost output "
                                     + "while it is rebuilt, and anger abroad: rivals by 20, the rest of the world by 10.", button: "Annex"),
                renamePlaceholder: "Rename it (optional) — blank keeps \(loser?.name ?? "its name")",
                maxNameLength: CombatModel.maxTerritoryNameLength,
                warnings: WarSupport.warnings(e.advisorWarnings(for: .annex(country: s.loser))),
                governmentsHeading: "Or let \(loser?.name ?? "it") form a new government:",
                governments: PostWarGovernment.allCases.map { g in
                    option(.government(g), id: g.rawValue, title: g.title, summary: g.summary, button: "Install")
                })
        }
        return Result(date: gs.currentDateLabel, settlements: list)
    }
}
#endif
