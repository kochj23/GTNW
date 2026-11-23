//
//  CollectLevyVerb.swift
//  GTNWCore
//
//  `{"verb":"collectLevy","id":"<territory>"}`: ResourcesSheet COLLECT (free; then six months' cooldown).
//

#if GTNW_CORE
import Foundation

enum CollectLevyVerb: BridgeVerb {
    static let name = "collectLevy"

    struct Args: Decodable { var id: String }

    static func run(_ a: Args, engine e: GameEngine, state gs: GameState) throws -> GTNWBridge.Report? {
        guard e.collectLevy(a.id) != nil else { throw QueryError("No levy can be collected there yet.") }
        return nil
    }
}
#endif
