//
//  AirCampaignQuery.swift
//  GTNWCore
//
//  `{"q":"airCampaign","target":"DEU"}`: AirCampaignSheet. Why a strategic air campaign can't be ordered against
//  the target now, and the two aims (the enemy's industry, or his cities) with what each means. Ordered with the
//  `strategicBombing` verb.
//

#if GTNW_CORE
import Foundation

enum AirCampaignQuery: BridgeQuery {
    static let name = "airCampaign"

    struct Args: Decodable { var target: String }
    struct Aim: Encodable { var id: String; var title: String; var blurb: String; var harsh: Bool }
    struct Result: Encodable { var target: String; var targetName: String; var problem: String?; var canOrder: Bool; var aims: [Aim] }

    static func run(_ args: Args, engine: GameEngine?) throws -> Result {
        let (e, gs) = try GTNWBridge.game(engine)
        let problem = e.strategicBombingProblem(args.target)
        return Result(target: args.target, targetName: gs.getCountry(id: args.target)?.name ?? args.target, problem: problem,
                      canOrder: problem == nil && gs.actionsRemaining > 0 && !gs.gameOver,
                      aims: AirForceModel.StrategicAim.allCases.map { Aim(id: $0.rawValue, title: $0.title, blurb: $0.blurb, harsh: $0 == .cities) })
    }
}
#endif
