//
//  EnactBudgetVerb.swift
//  GTNWCore
//
//  `{"verb":"enactBudget","draft":{…the budget query's figures}}`: BudgetView ENACT BUDGET.
//

#if GTNW_CORE
import Foundation

enum EnactBudgetVerb: BridgeVerb {
    static let name = "enactBudget"

    struct Args: Decodable { var draft: BudgetQuery.Figures }

    static func run(_ a: Args, engine e: GameEngine, state gs: GameState) throws -> GTNWBridge.Report? {
        e.applyBudget(a.draft.budget(over: gs.shadow.budget))
        return nil
    }
}
#endif
