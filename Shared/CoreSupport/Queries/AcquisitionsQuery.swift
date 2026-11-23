//
//  AcquisitionsQuery.swift
//  GTNWCore
//
//  `{"q":"acquisitions"}`: the app's AcquisitionSheet ("Land for sale": historical purchases open in their real
//  windows) and StatehoodSheet (real U.S. territories that can petition for statehood, and the count of stars).
//  The land market's bids are `landMarket`.
//

#if GTNW_CORE
import Foundation

enum AcquisitionsQuery: BridgeQuery {
    static let name = "acquisitions"

    struct Offer: Encodable {
        var id: String
        var name: String
        var seller: String
        var price: String
        var window: String
        var note: String
    }

    struct Statehood: Encodable {
        var id: String
        var name: String
        var flag: String
        var note: String
        var odds: Double
    }

    struct Result: Encodable {
        var dateLabel: String
        var offers: [Offer]
        var usa: Bool
        var stars: Int
        var territories: [Statehood]
        var actionsRemaining: Int
    }

    static func run(_ args: NoArgs, engine: GameEngine?) throws -> Result {
        let (e, gs) = try GTNWBridge.game(engine)
        let offers = e.openAcquisitions().map { a in
            Offer(id: a.id, name: a.name, seller: gs.getCountry(id: a.owner)?.name ?? a.owner, price: a.price, window: "\(a.from)–\(a.to - 1)",
                  note: a.land.isEmpty ? "Inside today's U.S. outline: adds its resources and score." : "Adds the land as U.S. territory.")
        }
        let admitted = Set(gs.shadow.statesAdmitted.map(\.id))
        let congress = gs.getPlayerCountry()?.congressionalSupport ?? 50
        let usa = gs.playerCountryID == "USA"
        let territories = usa ? OccupationModel.availableTerritories(year: gs.currentYear, admitted: admitted).map { t in
            Statehood(id: t.id, name: t.name, flag: t.flag, note: t.note,
                      odds: QueryText.round2(CongressModel.passOdds(expectedYes: OccupationModel.statehoodYes(congress: congress, stability: t.baseStability))))
        } : []
        return Result(dateLabel: gs.currentDateLabel, offers: offers, usa: usa,
                      stars: OccupationModel.historicalStates(year: gs.currentYear) + gs.shadow.statesAdmitted.count,
                      territories: territories, actionsRemaining: gs.actionsRemaining)
    }
}
#endif
