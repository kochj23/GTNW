//
//  StandDownVerb.swift
//  GTNWCore
//
//  `{"verb":"standDown","kind":"draft"|"mobilization"}`: ManpowerSheet STAND DOWN (free).
//

#if GTNW_CORE
import Foundation

enum StandDownVerb: BridgeVerb {
    static let name = "standDown"

    struct Args: Decodable { var kind: String }

    static func run(_ a: Args, engine e: GameEngine, state gs: GameState) throws -> GTNWBridge.Report? {
        guard let kind = ManpowerKind(rawValue: a.kind), e.standDown(kind) else { throw QueryError("Nothing to stand down.") }
        return nil
    }
}
#endif
