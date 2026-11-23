//
//  GovernTerritoryVerb.swift
//  GTNWCore
//
//  `{"verb":"governTerritory","id":"CUB","garrison":12}` or `{…,"governance":"localElections"}`: GovernSheet's
//  garrison buttons and government choice for one of the player's territories (no action spent).
//

#if GTNW_CORE
import Foundation

enum GovernTerritoryVerb: BridgeVerb {
    static let name = "governTerritory"

    struct Args: Decodable { var id: String; var garrison: Double?; var governance: String? }

    static func run(_ a: Args, engine e: GameEngine, state gs: GameState) throws -> GTNWBridge.Report? {
        guard gs.getCountry(id: a.id)?.territoryOf == gs.playerCountryID else { throw QueryError("not your territory") }
        if let g = a.garrison {
            guard g.isFinite, g >= 0.5 else { throw QueryError("garrison must be at least 0.5 thousand") }
            guard e.setGarrison(a.id, thousands: g) else { throw QueryError("not enough free troops for that garrison") }
        }
        if let raw = a.governance {
            guard let g = TerritoryGovernance(rawValue: raw) else { throw QueryError("unknown government \(raw)") }
            guard e.setGovernance(a.id, g) else { throw QueryError("that government can't be set") }
        }
        return nil
    }
}
#endif
