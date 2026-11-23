//
//  LaunchSatelliteVerb.swift
//  GTNWCore
//
//  `{"verb":"launchSatellite","type":"recon"|"warning"}`: SpaceSheet's launch (one action, from 1957).
//

#if GTNW_CORE
import Foundation

enum LaunchSatelliteVerb: BridgeVerb {
    static let name = "launchSatellite"

    struct Args: Decodable { var type: String }

    static func run(_ a: Args, engine e: GameEngine, state gs: GameState) throws -> GTNWBridge.Report? {
        guard let t = SatType(rawValue: a.type), [.recon, .warning].contains(t) else { throw QueryError("type is recon or warning") }
        guard gs.currentYear >= GameEngine.spaceAgeYear else { throw QueryError("no satellite can launch before \(GameEngine.spaceAgeYear)") }
        guard gs.actionsRemaining > 0 else { throw QueryError("no actions left this turn") }
        guard e.launchSatellite(t) else { throw QueryError("the launch failed") }
        return nil
    }
}
#endif
