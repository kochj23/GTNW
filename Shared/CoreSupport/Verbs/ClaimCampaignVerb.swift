//
//  ClaimCampaignVerb.swift
//  GTNWCore
//
//  `{"verb":"claimCampaign","op":"launch","selection":"emptyIslands"|"region"|"custom","region":"Oceania",
//  "ids":[…]}` or `{"op":"cancel"}`: UnclaimedLandsSheet's campaigns. One order (one action) claims a whole set,
//  a flag or a few a turn.
//

#if GTNW_CORE
import Foundation

enum ClaimCampaignVerb: BridgeVerb {
    static let name = "claimCampaign"

    struct Args: Decodable { var op: String; var selection: String?; var region: String?; var ids: [String]? }

    static func run(_ a: Args, engine e: GameEngine, state gs: GameState) throws -> GTNWBridge.Report? {
        if a.op == "cancel" {
            guard gs.shadow.claimCampaign != nil else { throw QueryError("no campaign under way") }
            e.cancelClaimCampaign()
            return nil
        }
        guard a.op == "launch" else { throw QueryError("op is launch or cancel") }
        let sel: ClaimCampaigns.Selection
        let name: String
        switch a.selection {
        case "emptyIslands": sel = .emptyIslands; name = "Empty Islands"
        case "region":
            guard let r = a.region.flatMap(WorldRegion.init(rawValue:)) else { throw QueryError("unknown region") }
            sel = .region(r); name = r.rawValue
        case "custom":
            let ids = (a.ids ?? []).prefix(ClaimCampaigns.maxLands)
            guard !ids.isEmpty else { throw QueryError("no lands selected") }
            sel = .custom(Array(ids).sorted()); name = "Selected Lands"
        default: throw QueryError("selection is emptyIslands, region or custom")
        }
        guard gs.actionsRemaining > 0 else { throw QueryError("no actions left this turn") }
        guard gs.shadow.claimCampaign == nil else { throw QueryError("a campaign is already under way") }
        guard e.launchClaimCampaign(sel, name: name) else { throw QueryError("nothing there can be claimed") }
        return nil
    }
}
#endif
