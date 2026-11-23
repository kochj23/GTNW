//
//  ColonyDealVerb.swift
//  GTNWCore
//
//  `{"verb":"colonyDeal","id":"…","op":"buy"|"independence"}`: OFFER TO BUY a colony or another power's territory,
//  or BACK INDEPENDENCE ($2B) (CountryDossier.colonyDeals; one action each).
//

#if GTNW_CORE
import Foundation

enum ColonyDealVerb: BridgeVerb {
    static let name = "colonyDeal"

    struct Args: Decodable { var id: String; var op: String }

    static func run(_ a: Args, engine e: GameEngine, state gs: GameState) throws -> GTNWBridge.Report? {
        guard gs.actionsRemaining > 0 else { throw QueryError("no actions left this turn") }
        guard e.colonyTarget(a.id) != nil else { throw QueryError("\(a.id) is no one's colony") }
        switch a.op {
        case "buy":
            guard let sold = e.purchaseColony(a.id) else { throw QueryError("the offer can't be made") }
            let mine = e.gameState?.getCountry(id: a.id)?.territoryOf == e.gameState?.playerCountryID
            return GTNWBridge.Report(title: mine ? "taken" : (sold ? "under way" : "refused"), lines: [], success: mine)
        case "independence":
            guard let freed = e.supportIndependence(a.id) else { throw QueryError("independence can't be backed") }
            return GTNWBridge.Report(title: freed ? "independent" : "failed", lines: [], success: freed)
        default:
            throw QueryError("op is buy or independence")
        }
    }
}
#endif
