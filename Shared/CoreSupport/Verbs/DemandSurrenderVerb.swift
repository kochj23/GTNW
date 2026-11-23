//
//  DemandSurrenderVerb.swift
//  GTNWCore
//
//  `{"verb":"demandSurrender","front":"<id>"}`: WarRoomView DEMAND SURRENDER (the enemy may give up, or fight on
//  harder), recorded as a hostile military move.
//

#if GTNW_CORE
import Foundation

enum DemandSurrenderVerb: BridgeVerb {
    static let name = "demandSurrender"

    struct Args: Decodable { var front: String }

    static func run(_ a: Args, engine e: GameEngine, state gs: GameState) throws -> GTNWBridge.Report? {
        let id = try WarSupport.uuid(a.front)
        guard let f = gs.shadow.fronts.first(where: { $0.id == id }), f.status == .fighting,
              f.usSide != nil || f.attacker == gs.playerCountryID || f.defender == gs.playerCountryID else {
            throw QueryError("Those orders can't be carried out.")
        }
        let accepted = e.demandSurrender(frontID: id)
        e.recordPlayerAction(rung: .military, hostile: true, detected: true)
        return GTNWBridge.Report(title: "Surrender demand",
                                 lines: [accepted ? "They have accepted your terms." : "Surrender demand rejected. The fighting continues."], success: accepted)
    }
}
#endif
