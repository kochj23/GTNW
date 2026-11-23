//
//  GroupActionVerb.swift
//  GTNWCore
//
//  `{"verb":"groupAction", …the groupAction query's fields}`: GroupActionSheet CONFIRM.
//

#if GTNW_CORE
import Foundation

enum GroupActionVerb: BridgeVerb {
    static let name = "groupAction"

    typealias Args = GroupActionQuery.Args

    static func run(_ a: Args, engine e: GameEngine, state gs: GameState) throws -> GTNWBridge.Report? {
        let selector = a.selector(gs)
        let members = e.groupMembers(selector)
        let kind = a.kindValue
        let plan = e.planGroupAction(kind, members: members, amount: a.amountValue, split: a.splitValue, rate: a.rateValue)
        if let problem = plan.problem { throw QueryError(problem) }
        guard e.executeGroupAction(kind, members: members, amount: a.amountValue, split: a.splitValue, groupName: selector.title, rate: a.rateValue) != nil else {
            throw QueryError("Those orders can't be carried out.")
        }
        return nil
    }
}
#endif
