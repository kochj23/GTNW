//
//  AcceptAcquisitionVerb.swift
//  GTNWCore
//
//  `{"verb":"acceptAcquisition","id":"alaska"}`: accept a historical purchase in its window (AcquisitionSheet's
//  ACCEPT; one action). A rival power may bid against it (the land market).
//

#if GTNW_CORE
import Foundation

enum AcceptAcquisitionVerb: BridgeVerb {
    static let name = "acceptAcquisition"

    struct Args: Decodable { var id: String }

    static func run(_ a: Args, engine e: GameEngine, state gs: GameState) throws -> GTNWBridge.Report? {
        guard gs.actionsRemaining > 0 else { throw QueryError("no actions left this turn") }
        guard let offer = e.openAcquisitions().first(where: { $0.id == a.id }) else { throw QueryError("no such offer this year") }
        guard e.acceptAcquisition(a.id) else { throw QueryError("\(offer.name) can't be bought now") }
        return nil
    }
}
#endif
