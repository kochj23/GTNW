//
//  RequestCoalitionVerb.swift
//  GTNWCore
//
//  `{"verb":"requestCoalition","target":"IRQ"}`: CoalitionSheet ASK N NATIONS TO JOIN (one action).
//

#if GTNW_CORE
import Foundation

enum RequestCoalitionVerb: BridgeVerb {
    static let name = "requestCoalition"

    struct Args: Decodable { var target: String }

    static func run(_ a: Args, engine e: GameEngine, state gs: GameState) throws -> GTNWBridge.Report? {
        guard gs.actionsRemaining > 0 else { throw QueryError("No actions left this \(gs.turnLength.displayName.lowercased()).") }
        guard e.requestCoalition(against: a.target) != nil else { throw QueryError("Nobody to ask: no allies or friends outside the target's camp.") }
        return nil
    }
}
#endif
