//
//  SueForPeaceVerb.swift
//  GTNWCore
//
//  `{"verb":"sueForPeace","front":"<id>"}`: WarRoomView SUE FOR PEACE, on a front the player is fighting.
//

#if GTNW_CORE
import Foundation

enum SueForPeaceVerb: BridgeVerb {
    static let name = "sueForPeace"

    struct Args: Decodable { var front: String }

    static func run(_ a: Args, engine e: GameEngine, state gs: GameState) throws -> GTNWBridge.Report? {
        let id = try WarSupport.uuid(a.front)
        let us = gs.playerCountryID
        guard let f = gs.shadow.fronts.first(where: { $0.id == id }), f.status == .fighting, f.attacker == us || f.defender == us else {
            throw QueryError("Those orders can't be carried out.")
        }
        let other = f.attacker == us ? f.defender : f.attacker
        _ = e.sueForPeace(from: us, to: other)
        return GTNWBridge.Report(title: "Ceasefire", lines: ["Ceasefire signed with \(WarSupport.name(other, gs))."], success: true)
    }
}
#endif
