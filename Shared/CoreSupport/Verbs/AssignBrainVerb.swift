//
//  AssignBrainVerb.swift
//  GTNWCore
//
//  `{"verb":"assignBrain","country":"RUS","brain":"human"|"rule"|"relay"}`: who plays a country
//  (BrainAssignmentView). On the web the choices are the player, the rule-based AI and the site's AI service.
//

#if GTNW_CORE
import Foundation

enum AssignBrainVerb: BridgeVerb {
    static let name = "assignBrain"

    struct Args: Decodable { var country: String; var brain: String }

    static func run(_ a: Args, engine e: GameEngine, state gs: GameState) throws -> GTNWBridge.Report? {
        guard let c = gs.getCountry(id: a.country), !c.isDestroyed else { throw QueryError("no country \(a.country)") }
        switch a.brain {
        case "human": e.setBrain(.human, for: c.id)
        case "rule": e.setBrain(.ruleBased, for: c.id)
        case "relay": e.setBrain(WebBrains.relay, for: c.id); WebBrains.install(e)
        default: throw QueryError("brain is human, rule or relay")
        }
        return nil
    }
}
#endif
