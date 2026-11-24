//
//  AnnexProvincesVerb.swift
//  GTNWCore
//
//  `{"verb":"annexProvinces","id":"<settlement>"}`: SettlementSheet's ANNEX PROVINCES (3.36.0). Annex only the
//  provinces the victor's army holds; the loser keeps its government.
//

#if GTNW_CORE
import Foundation

enum AnnexProvincesVerb: BridgeVerb {
    static let name = "annexProvinces"

    struct Args: Decodable { var id: String }

    static func run(_ a: Args, engine e: GameEngine, state gs: GameState) throws -> GTNWBridge.Report? {
        let id = try WarSupport.uuid(a.id)
        guard gs.shadow.pendingSettlements.contains(where: { $0.id == id }) else { throw QueryError("No such surrender is waiting.") }
        guard e.annexOccupied(id) else { throw QueryError("The army holds no province of that nation.") }
        return nil
    }
}
#endif
