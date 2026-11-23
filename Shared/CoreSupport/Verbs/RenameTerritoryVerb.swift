//
//  RenameTerritoryVerb.swift
//  GTNWCore
//
//  `{"verb":"renameTerritory","id":"…","name":"New Name"}`: TerritoryNameSheet's NAME IT / RENAME for one of the
//  player's territories (no action spent). The name is checked as the app checks it.
//

#if GTNW_CORE
import Foundation

enum RenameTerritoryVerb: BridgeVerb {
    static let name = "renameTerritory"

    struct Args: Decodable { var id: String; var name: String }

    static func run(_ a: Args, engine e: GameEngine, state gs: GameState) throws -> GTNWBridge.Report? {
        guard gs.getCountry(id: a.id)?.territoryOf == gs.playerCountryID else { throw QueryError("not your territory") }
        guard CombatModel.validTerritoryName(a.name) != nil else {
            throw QueryError("1–\(CombatModel.maxTerritoryNameLength) characters on one line")
        }
        guard e.renameTerritory(a.id, to: a.name) else { throw QueryError("that name can't be used") }
        return nil
    }
}
#endif
