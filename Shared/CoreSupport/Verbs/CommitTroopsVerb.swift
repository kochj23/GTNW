//
//  CommitTroopsVerb.swift
//  GTNWCore
//
//  `{"verb":"commitTroops","front":"<id>","side":"KOR","thousands":50}`: WarRoomView SEND TO / RECALL. A negative
//  amount recalls that many from the side the U.S. is on.
//

#if GTNW_CORE
import Foundation

enum CommitTroopsVerb: BridgeVerb {
    static let name = "commitTroops"

    struct Args: Decodable { var front: String; var side: String; var thousands: Double }

    static func run(_ a: Args, engine e: GameEngine, state gs: GameState) throws -> GTNWBridge.Report? {
        let id = try WarSupport.uuid(a.front)
        guard a.thousands.isFinite, a.thousands != 0, e.commitTroops(frontID: id, side: a.side, thousands: a.thousands) else {
            throw QueryError("Those orders can't be carried out.")
        }
        return GTNWBridge.Report(title: "Orders sent.", lines: [], success: true)
    }
}
#endif
