//
//  InvestLandVerb.swift
//  GTNWCore
//
//  `{"verb":"investLand","id":"…"}` (3.36.0): INVEST in one of the player's territories: six months of development
//  for one action, era-priced, paid from the funds first (ReportBooks.swift, `GameEngine.investInLand`).
//

#if GTNW_CORE
import Foundation

enum InvestLandVerb: BridgeVerb {
    static let name = "investLand"

    struct Args: Decodable { var id: String }

    static func run(_ a: Args, engine e: GameEngine, state gs: GameState) throws -> GTNWBridge.Report? {
        if let problem = LandDevelopment.problem(a.id, in: gs) { throw QueryError(problem) }
        guard e.investInLand(a.id) else { throw QueryError("\(a.id) can't be developed") }
        return nil
    }
}
#endif
