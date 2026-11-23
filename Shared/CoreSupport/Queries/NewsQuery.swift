//
//  NewsQuery.swift
//  GTNWCore
//
//  `{"q":"news"}`: the news wire as the game keeps it (`ShadowState.ticker`, the last 120 items, saved with the
//  game), oldest first, each with its date and severity (0 routine, 1 notable, 2 urgent, 3 flash), plus the
//  scenario's epigraph when the game is a scenario. The app's NewsTicker crawls the latest eight; the web's news
//  sheet shows the whole wire, so it survives a reload.
//

#if GTNW_CORE
import Foundation

enum NewsQuery: BridgeQuery {
    static let name = "news"

    struct Item: Encodable {
        var date: String
        var text: String
        var severity: Int
    }

    struct Result: Encodable {
        var items: [Item]
        var scenario: String?
        var epigraph: CrisisQuery.Quote?
    }

    static func run(_ args: NoArgs, engine: GameEngine?) throws -> Result {
        let (_, gs) = try GTNWBridge.game(engine)
        let def = gs.shadow.scenarioID.flatMap(ScenarioDefinition.find)
        return Result(
            items: gs.shadow.ticker.map { Item(date: GameCalendar.format($0.date), text: $0.text, severity: max(0, min(3, $0.severity))) },
            scenario: def?.title, epigraph: def.map { CrisisQuery.quote($0.epigraph) })
    }
}
#endif
