//
//  HolySeeVerb.swift
//  GTNWCore
//
//  `{"verb":"holySee","op":"mediate","first":"ARG","second":"CHL"}` (3.37.0): a HOLY SEE sheet button
//  (`GameEngine.runHolySee`, HolySee.swift), one action each (resigning ends the game). `op` is a HolySeeAction
//  (`holySee` query lists them); `first` / `second` are nation ids where the action takes them; `option` is the
//  teaching theme (nuclear, environment, workers, peace) or the treaty id. Vatican City only.
//

#if GTNW_CORE
import Foundation

enum HolySeeVerb: BridgeVerb {
    static let name = "holySee"

    struct Args: Decodable { var op: String; var first: String?; var second: String?; var option: String? }

    static func run(_ a: Args, engine e: GameEngine, state gs: GameState) throws -> GTNWBridge.Report? {
        guard let action = HolySeeAction(rawValue: a.op) else {
            throw QueryError("op must be one of " + HolySeeAction.allCases.map(\.rawValue).joined(separator: ", "))
        }
        let o = HolySeeOrder(action: action, first: a.first, second: a.second, option: a.option)
        if let problem = e.holySeeProblem(o) { throw QueryError(problem) }
        guard let r = e.runHolySee(o) else { throw QueryError("That can't be done now.") }
        return GTNWBridge.Report(title: action.title, lines: r.lines, success: r.success)
    }
}
#endif
