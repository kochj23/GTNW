//
//  RenameTerritoryVerb.swift
//  GTNWCore
//
//  `{"verb":"renameTerritory","id":"…","name":"New Name"}`: TerritoryNameSheet's NAME IT / RENAME for one of the
//  player's territories, or (3.36.0) the player's own country (no action spent). The name is checked as the app checks
//  it (`NameScreen`), and the refusal is the app's neutral line.
//

#if GTNW_CORE
import Foundation

enum RenameTerritoryVerb: BridgeVerb {
    static let name = "renameTerritory"

    struct Args: Decodable { var id: String; var name: String }

    static func run(_ a: Args, engine e: GameEngine, state gs: GameState) throws -> GTNWBridge.Report? {
        guard RenameTarget.country(a.id).isHeld(in: gs) else { throw QueryError("not your territory") }
        if case .refused(let why) = e.rename(.country(a.id), to: a.name) { throw QueryError(why) }
        return nil
    }
}
#endif
