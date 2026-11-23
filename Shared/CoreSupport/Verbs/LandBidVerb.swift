//
//  LandBidVerb.swift
//  GTNWCore
//
//  `{"verb":"landBid","id":"<uuid>","op":"raise"|"accept"|"walkAway"}`: the land market (AcquisitionSheet 3.29.0):
//  raise once in a price war or bid in an auction, accept an offer to sell (one action), or walk away / decline.
//

#if GTNW_CORE
import Foundation

enum LandBidVerb: BridgeVerb {
    static let name = "landBid"

    struct Args: Decodable { var id: String; var op: String }

    static func run(_ a: Args, engine e: GameEngine, state gs: GameState) throws -> GTNWBridge.Report? {
        guard let uuid = UUID(uuidString: a.id), let bid = gs.shadow.landBids.first(where: { $0.id == uuid }) else { throw QueryError("no such bid") }
        switch a.op {
        case "raise":
            guard bid.kind != .offer else { throw QueryError("an offer is accepted, not raised") }
            guard let won = e.raiseBid(uuid) else { throw QueryError("the bid can't be raised") }
            return GTNWBridge.Report(title: won ? "\(bid.label): yours" : "\(bid.label): outbid", lines: [], success: won)
        case "accept":
            guard bid.kind == .offer else { throw QueryError("only an offer to sell can be accepted") }
            guard gs.actionsRemaining > 0 else { throw QueryError("no actions left this turn") }
            guard e.acceptLandOffer(uuid) else { throw QueryError("the offer can't be accepted") }
        case "walkAway":
            e.walkAway(uuid)
        default:
            throw QueryError("op is raise, accept or walkAway")
        }
        return nil
    }
}
#endif
