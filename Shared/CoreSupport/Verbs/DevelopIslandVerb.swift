//
//  DevelopIslandVerb.swift
//  GTNWCore
//
//  `{"verb":"developIsland","id":"…","project":"airstrip"}`: build on one of the player's islands (paid from
//  discretionary funds, no action spent).
//

#if GTNW_CORE
import Foundation

enum DevelopIslandVerb: BridgeVerb {
    static let name = "developIsland"

    struct Args: Decodable { var id: String; var project: String }

    static func run(_ a: Args, engine e: GameEngine, state gs: GameState) throws -> GTNWBridge.Report? {
        guard let p = IslandProject(rawValue: a.project) else { throw QueryError("unknown project \(a.project)") }
        if let problem = e.islandProjectProblem(p, on: a.id) { throw QueryError(problem) }
        guard e.developIsland(a.id, p) else { throw QueryError("\(p.title) can't be built") }
        return nil
    }
}
#endif
