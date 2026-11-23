//
//  StrategicBombingVerb.swift
//  GTNWCore
//
//  `{"verb":"strategicBombing","target":"DEU","aim":"industry"|"cities"}`: AirCampaignSheet ORDER THE RAID
//  (one action).
//

#if GTNW_CORE
import Foundation

enum StrategicBombingVerb: BridgeVerb {
    static let name = "strategicBombing"

    struct Args: Decodable { var target: String; var aim: String }

    static func run(_ a: Args, engine e: GameEngine, state gs: GameState) throws -> GTNWBridge.Report? {
        guard let aim = AirForceModel.StrategicAim(rawValue: a.aim) else { throw QueryError("unknown aim \(a.aim)") }
        if let problem = e.strategicBombingProblem(a.target) { throw QueryError(problem) }
        guard e.conductStrategicBombing(target: a.target, aim: aim) else { throw QueryError("No actions left this \(gs.turnLength.displayName.lowercased()).") }
        return nil
    }
}
#endif
