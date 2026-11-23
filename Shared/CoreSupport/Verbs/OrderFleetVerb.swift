//
//  OrderFleetVerb.swift
//  GTNWCore
//
//  `{"verb":"orderFleet","fleet":"pac","target":"CUB","mission":"blockade","preset":"standard"}`: FleetOrderSheet
//  ORDER <FLEET> OUT (one action).
//

#if GTNW_CORE
import Foundation

enum OrderFleetVerb: BridgeVerb {
    static let name = "orderFleet"

    struct Args: Decodable { var fleet: String; var target: String; var mission: String; var preset: String? }

    static func run(_ a: Args, engine e: GameEngine, state gs: GameState) throws -> GTNWBridge.Report? {
        guard let mission = NavalMission(rawValue: a.mission) else { throw QueryError("unknown mission \(a.mission)") }
        if let problem = e.fleetOrderProblem(fleetID: a.fleet, target: a.target, mission: mission) { throw QueryError(problem) }
        guard e.orderFleet(a.fleet, to: a.target, mission: mission, preset: WarSupport.preset(a.preset)) != nil else {
            throw QueryError("Those orders can't be carried out.")
        }
        return nil
    }
}
#endif
