//
//  ScenariosQuery.swift
//  GTNWCore
//
//  `{"q":"scenarios"}`: the dated scenarios (ScenarioDefinition.all, techno-thrillers included) and the one-sitting
//  crises (OneSitting.all), for the new-game screen. Needs no game.
//

#if GTNW_CORE
import Foundation

enum ScenariosQuery: BridgeQuery {
    static let name = "scenarios"

    struct Scenario: Encodable {
        var id: String
        var title: String
        var summary: String
        var date: String
        var year: Int
        var turnLength: String
        var fiction: Bool
    }

    struct Sitting: Encodable {
        var id: String
        var scenario: String
        var title: String
        var goal: String
        var turns: Int
        var turnLength: String
    }

    struct Result: Encodable {
        var scenarios: [Scenario]
        var sittings: [Sitting]
    }

    static func run(_ args: NoArgs, engine: GameEngine?) throws -> Result {
        Result(
            scenarios: ScenarioDefinition.all.map {
                Scenario(id: $0.id, title: $0.title, summary: $0.summary, date: GameCalendar.format($0.startDate),
                         year: GameCalendar.year(of: $0.startDate), turnLength: $0.suggestedTurnLength.rawValue, fiction: $0.isFiction)
            },
            sittings: OneSitting.all.map {
                Sitting(id: $0.id, scenario: $0.scenario, title: $0.title, goal: $0.goal, turns: $0.turns, turnLength: $0.turnLength.rawValue)
            })
    }
}
#endif
