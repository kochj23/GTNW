//
//  AntarcticOrderVerb.swift
//  GTNWCore
//
//  `{"verb":"antarcticOrder","op":"station"|"join"|"leave"|"renegotiate"}` (3.37): AntarcticPanel's buttons
//  (BUILD RESEARCH STATION, LEAVE / REJOIN / RENEGOTIATE TREATY): `GameEngine.runAntarcticOrder`, one action each.
//

#if GTNW_CORE
import Foundation

enum AntarcticOrderVerb: BridgeVerb {
    static let name = "antarcticOrder"

    struct Args: Decodable { var op: String }

    static func run(_ a: Args, engine e: GameEngine, state gs: GameState) throws -> GTNWBridge.Report? {
        guard let op = AntarcticOrder(rawValue: a.op) else { throw QueryError("op must be station, join, leave or renegotiate") }
        if let problem = e.antarcticProblem(op) { throw QueryError(problem) }
        if gs.actionsRemaining == 0 { throw QueryError("No actions left this \(gs.turnLength.displayName.lowercased()).") }
        guard e.runAntarcticOrder(op) else { throw QueryError("That order can't be given now.") }
        return nil
    }
}
#endif
