//
//  PetitionStatehoodVerb.swift
//  GTNWCore
//
//  `{"verb":"petitionStatehood","id":"US-PR"}`: ask Congress to admit a territory as a state (one action): a real
//  U.S. possession (StatehoodSheet, ids "US-…") or a territory the President governs (GovernSheet).
//

#if GTNW_CORE
import Foundation

enum PetitionStatehoodVerb: BridgeVerb {
    static let name = "petitionStatehood"

    struct Args: Decodable { var id: String }

    static func run(_ a: Args, engine e: GameEngine, state gs: GameState) throws -> GTNWBridge.Report? {
        guard gs.playerCountryID == "USA" else { throw QueryError("statehood is a U.S. process") }
        guard gs.actionsRemaining > 0 else { throw QueryError("no actions left this turn") }
        let domestic = OccupationModel.usTerritories.contains { $0.id == a.id }
        let name = domestic ? OccupationModel.usTerritories.first { $0.id == a.id }?.name ?? a.id : gs.getCountry(id: a.id)?.name ?? a.id
        guard let passed = domestic ? e.petitionDomesticStatehood(a.id) : e.petitionStatehood(a.id) else {
            throw QueryError("\(name) can't petition for statehood now")
        }
        return GTNWBridge.Report(title: passed ? "\(name) admitted" : "Statehood for \(name) fails",
                                 lines: [passed ? "Congress votes to admit \(name) as a state." : "Congress votes the petition down."], success: passed)
    }
}
#endif
