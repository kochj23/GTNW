//
//  RecallFleetVerb.swift
//  GTNWCore
//
//  `{"verb":"recallFleet","id":"<deployment>"}`: FleetOrderSheet RECALL.
//

#if GTNW_CORE
import Foundation

enum RecallFleetVerb: BridgeVerb {
    static let name = "recallFleet"

    struct Args: Decodable { var id: String }

    static func run(_ a: Args, engine e: GameEngine, state gs: GameState) throws -> GTNWBridge.Report? {
        guard e.recallFleet(try WarSupport.uuid(a.id)) else { throw QueryError("No such fleet is out.") }
        return nil
    }
}
#endif
