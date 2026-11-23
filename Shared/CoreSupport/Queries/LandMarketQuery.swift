//
//  LandMarketQuery.swift
//  GTNWCore
//
//  `{"q":"landMarket"}`: the land market (price wars, auctions and offers to sell, AcquisitionSheet 3.29.0) and the
//  unclaimed lands (UnclaimedLandsSheet): every land no government holds this year, the claim campaign under way,
//  and how many lands each campaign choice (empty islands, a region) would cover.
//

#if GTNW_CORE
import Foundation

enum LandMarketQuery: BridgeQuery {
    static let name = "landMarket"

    struct Bid: Encodable {
        var id: String
        /// priceWar, auction, offer
        var kind: String
        var title: String
        var line: String
        var land: String
    }

    struct Land: Encodable {
        var id: String
        var name: String
        var kindLabel: String
        var emptyIsland: Bool
    }

    struct Campaign: Encodable {
        var name: String
        var planted: Int
        var toGo: Int
    }

    struct Region: Encodable {
        var id: String
        var lands: Int
    }

    struct Result: Encodable {
        var year: Int
        var dateLabel: String
        var bids: [Bid]
        var lands: [Land]
        var campaign: Campaign?
        var emptyIslands: Int
        var regions: [Region]
        var perTurn: Int
        var actionsRemaining: Int
    }

    static func run(_ args: NoArgs, engine: GameEngine?) throws -> Result {
        let (_, gs) = try GTNWBridge.game(engine)
        let name = { (id: String?) in id.flatMap { gs.getCountry(id: $0)?.name ?? $0 } }
        let bids = gs.shadow.landBids.map { b in
            Bid(id: b.id.uuidString, kind: b.kind.rawValue,
                title: "\(b.kind == .priceWar ? "PRICE WAR" : (b.kind == .auction ? "AUCTION" : "OFFER")): \(b.label.uppercased())",
                line: b.kind == .offer
                    ? String(format: "%@ asks $%.1fB · until %@", name(b.owner) ?? b.owner, b.price, GameCalendar.format(b.deadline))
                    : String(format: "%@ bids $%.1fB · your raise $%.1fB · closes %@", name(b.rival) ?? "Reserve", b.rivalPrice,
                             LandMarket.raise(b), GameCalendar.format(b.deadline)),
                land: b.land)
        }
        let lands = gs.unclaimedLands.map { Land(id: $0.id, name: $0.name, kindLabel: $0.kind.label, emptyIsland: $0.kind == .emptyIsland) }
        let regions = WorldRegion.allCases.map { Region(id: $0.rawValue, lands: gs.campaignTargets(.region($0)).count) }
        return Result(year: gs.currentYear, dateLabel: gs.currentDateLabel, bids: bids, lands: lands,
                      campaign: gs.shadow.claimCampaign.map { Campaign(name: $0.name, planted: $0.planted.count, toGo: $0.queue.count) },
                      emptyIslands: gs.campaignTargets(.emptyIslands).count, regions: regions,
                      perTurn: ClaimCampaigns.perTurn(gs.turnLength), actionsRemaining: gs.actionsRemaining)
    }
}
#endif
