//
//  BrokerCeasefireVerb.swift
//  GTNWCore
//
//  `{"verb":"brokerCeasefire","front":"<id>"}`: WarRoomView BROKER CEASEFIRE on a war between others (one action).
//

#if GTNW_CORE
import Foundation

enum BrokerCeasefireVerb: BridgeVerb {
    static let name = "brokerCeasefire"

    struct Args: Decodable { var front: String }

    static func run(_ a: Args, engine e: GameEngine, state gs: GameState) throws -> GTNWBridge.Report? {
        let id = try WarSupport.uuid(a.front)
        let us = gs.playerCountryID
        guard let f = gs.shadow.fronts.first(where: { $0.id == id }), f.status == .fighting, f.attacker != us, f.defender != us else {
            throw QueryError("Those orders can't be carried out.")
        }
        guard gs.actionsRemaining > 0 else { throw QueryError("No actions left this \(gs.turnLength.displayName.lowercased()).") }
        _ = e.sueForPeace(from: f.attacker, to: f.defender)
        e.completePlayerAction()
        return GTNWBridge.Report(title: "Ceasefire", lines: ["U.S. mediators have brokered a ceasefire."], success: true)
    }
}
#endif
