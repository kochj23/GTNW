//
//  SaveGroupVerb.swift
//  GTNWCore
//
//  `{"verb":"saveGroup","name":"Gulf states","ids":["KWT","QAT"]}`: GroupActionSheet SAVE GROUP. Changes no
//  nation, only the saved groups.
//

#if GTNW_CORE
import Foundation

enum SaveGroupVerb: BridgeVerb {
    static let name = "saveGroup"

    struct Args: Decodable { var name: String; var ids: [String] }

    static func run(_ a: Args, engine e: GameEngine, state gs: GameState) throws -> GTNWBridge.Report? {
        guard e.saveGroup(name: a.name, ids: a.ids) else {
            throw QueryError("Pick at least one nation and a name of 1–\(CombatModel.maxTerritoryNameLength) characters on one line.")
        }
        return nil
    }
}
#endif
