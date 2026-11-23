//
//  BrokerPeaceVerb.swift
//  GTNWCore
//
//  `{"verb":"brokerPeace","a":"IRN","b":"IRQ"}`: PeaceSheet BROKER (one action; a success is a Nobel moment).
//

#if GTNW_CORE
import Foundation

enum BrokerPeaceVerb: BridgeVerb {
    static let name = "brokerPeace"

    struct Args: Decodable { var a: String; var b: String }

    static func run(_ a: Args, engine e: GameEngine, state gs: GameState) throws -> GTNWBridge.Report? {
        guard e.brokerPeace(a.a, a.b) != nil else { throw QueryError("Those orders can't be carried out.") }
        return nil
    }
}
#endif
