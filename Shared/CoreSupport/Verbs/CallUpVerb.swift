//
//  CallUpVerb.swift
//  GTNWCore
//
//  `{"verb":"callUp","kind":"draft"|"mobilization"}`: ManpowerSheet CALL (one action).
//

#if GTNW_CORE
import Foundation

enum CallUpVerb: BridgeVerb {
    static let name = "callUp"

    struct Args: Decodable { var kind: String }

    static func run(_ a: Args, engine e: GameEngine, state gs: GameState) throws -> GTNWBridge.Report? {
        guard let kind = ManpowerKind(rawValue: a.kind) else { throw QueryError("unknown kind \(a.kind)") }
        if let problem = e.callUpProblem(kind) { throw QueryError(problem) }
        guard e.callUp(kind) else { throw QueryError("Those orders can't be carried out.") }
        return nil
    }
}
#endif
