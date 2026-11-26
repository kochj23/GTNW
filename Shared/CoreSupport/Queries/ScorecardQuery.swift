//
//  ScorecardQuery.swift
//  GTNWCore
//
//  `{"q":"scorecard"}`: how the game is going and how it ended. The scenario's scorecard against history
//  (ScorecardSheet), the World Evaluation with the Presidency Summary (WorldEvaluationView), and once the game is
//  over the VictoryScreen: the victory or defeat, the domestic ending, the final score and its breakdown, the
//  statistics, the debrief and the closing epigraphs.
//

#if GTNW_CORE
import Foundation

enum ScorecardQuery: BridgeQuery {
    static let name = "scorecard"

    struct Line: Encodable {
        var label: String
        var historical: String
        var player: String
        var matches: Bool?
    }

    struct Meter: Encodable {
        var label: String
        var value: Double
        var text: String
    }

    struct Summary: Encodable {
        var label: String
        var start: Double
        var now: Double
    }

    struct Final: Encodable {
        var victory: String?
        var victoryDescription: String?
        var secretEnding: Bool
        var destroyed: Bool
        var reason: String
        var ending: String?
        var endingTitle: String?
        var score: Int
        var breakdown: [[String: String]]
        var stats: [[String: String]]
        var epigraphs: [[String: String]]
        var wopr: [String]
    }

    struct Block: Encodable {
        var title: String
        var body: String
    }

    struct Result: Encodable {
        var scenario: String?
        var title: String
        var fiction: Bool
        var matched: Int
        var total: Int
        var lines: [Line]
        var meters: [Meter]
        var peaceLevels: [String]
        var peaceLevel: Int
        var summaryFrom: String?
        var summary: [Summary]
        var debrief: [Block]
        var final: Final?
    }

    static func run(_ args: NoArgs, engine: GameEngine?) throws -> Result {
        let (e, gs) = try GTNWBridge.game(engine)
        let id = gs.shadow.scenarioID ?? ""
        let def = ScenarioDefinition.find(id)
        let lines = Scorecard.lines(for: id, in: gs)
        let score = Scorecard.score(lines)
        let ev = WorldEvaluation.evaluate(gs)
        let meters = [
            Meter(label: "U.S. leadership effectiveness", value: ev.leadership, text: "\(Int(ev.leadership))"),
            Meter(label: "U.S. share of world influence", value: min(100, ev.influenceShare * 4), text: String(format: "%.1f%%", ev.influenceShare)),
            Meter(label: "U.S. quality of life", value: ev.usQualityOfLife, text: "\(Int(ev.usQualityOfLife))"),
            Meter(label: "World quality of life", value: ev.worldQualityOfLife, text: "\(Int(ev.worldQualityOfLife))"),
        ].map { Meter(label: $0.label, value: QueryText.round2($0.value), text: $0.text) }
        var summary: [Summary] = []
        if let s = gs.shadow.startSnapshot {
            let n = ev.snapshot(date: gs.currentDate, popularity: gs.shadow.popularity)
            summary = [Summary(label: "Popularity", start: s.popularity, now: n.popularity),
                       Summary(label: "U.S. quality of life", start: s.usQualityOfLife, now: n.usQualityOfLife),
                       Summary(label: "World quality of life", start: s.worldQualityOfLife, now: n.worldQualityOfLife),
                       Summary(label: "World peace", start: s.worldPeace, now: n.worldPeace),
                       Summary(label: "Leadership", start: s.leadership, now: n.leadership)]
                .map { Summary(label: $0.label, start: QueryText.round2($0.start), now: QueryText.round2($0.now)) }
        }
        return Result(scenario: gs.shadow.scenarioID, title: def?.title ?? "Sandbox", fiction: def?.isFiction ?? false,
                      matched: score.matched, total: score.total,
                      lines: lines.map { Line(label: $0.label, historical: $0.historical, player: $0.player, matches: $0.matchesHistory) },
                      meters: meters, peaceLevels: PeaceLevel.allCases.map(\.label), peaceLevel: ev.peaceLevel.rawValue,
                      summaryFrom: gs.shadow.startSnapshot.map { GameCalendar.format($0.date) }, summary: summary,
                      debrief: Debrief.lines(gs).map { Block(title: $0.title, body: $0.body) },
                      final: gs.gameOver ? final(e, gs) : nil)
    }

    /// VictoryScreen.
    static func final(_ e: GameEngine, _ gs: GameState) -> Final {
        let victory = e.victoryType ?? gs.victoryType
        let s = e.finalScore ?? GameScore.calculate(from: gs, victoryType: victory)
        var breakdown: [[String: String]] = [["label": "Base score", "value": "+\(s.baseScore)"], ["label": "Turns played", "value": "+\(s.turnsPlayed * 5)"]]
        if s.nuclearVirgin { breakdown.append(["label": "Nuclear virgin bonus", "value": "+500", "tone": "good"]) }
        if s.casualtyPenalty < 0 { breakdown.append(["label": "Casualty penalty", "value": "\(s.casualtyPenalty)", "tone": "bad"]) }
        breakdown += [["label": "Alliance bonus", "value": "+\(s.allianceBonus)"], ["label": "Economic bonus", "value": "+\(s.economicBonus)"],
                      ["label": "Difficulty multiplier", "value": "×" + String(format: "%.1f", s.difficultyMultiplier)]]
        let stats: [[String: String]] = [
            ["label": "Turns played", "value": "\(gs.turn)"], ["label": "Wars fought", "value": "\(gs.activeWars.count)"],
            ["label": "Treaties signed", "value": "\(gs.treaties.count)"], ["label": "Nuclear strikes", "value": "\(gs.nuclearStrikes.count)"],
            ["label": "Total casualties", "value": "\(gs.totalCasualties)"], ["label": "Global radiation", "value": "\(gs.globalRadiation)"],
        ]
        let destroyed = gs.getPlayerCountry()?.isDestroyed ?? false
        let tags = endingTags(victory, ending: gs.shadow.domesticEnding, destroyed: destroyed)
        let quotes = Quotations.triad(tags, seed: "\(gs.shadow.playSessionID?.uuidString ?? "")\(victory?.rawValue ?? "defeat")")
        let wopr: [String]
        if victory == .peaceMaker { wopr = ["\"A STRANGE GAME.\"", "\"THE ONLY WINNING MOVE IS NOT TO PLAY.\"", "- WOPR"] }
        else if victory != nil { wopr = ["\"SHALL WE PLAY ANOTHER GAME?\"", "- WOPR"] }
        else { wopr = ["\"WOULD YOU LIKE TO TRY AGAIN?\"", "- WOPR"] }
        return Final(victory: victory.map { $0.title(for: gs) }, victoryDescription: victory.map { $0.description(for: gs) }, secretEnding: victory == .secretEnding,
                     destroyed: destroyed, reason: gs.gameOverReason, ending: gs.shadow.domesticEnding?.rawValue,
                     endingTitle: gs.shadow.domesticEnding.map(ElectionQuery.endingTitle), score: s.finalScore, breakdown: breakdown, stats: stats,
                     epigraphs: quotes.map { ["text": $0.text, "source": $0.source, "kind": $0.kind.rawValue] }, wopr: wopr)
    }

    /// VictoryScreen.endingTags.
    static func endingTags(_ v: VictoryType?, ending: DomesticEnding?, destroyed: Bool) -> Set<QuoteTag> {
        switch v {
        case .peaceMaker?, .nobelPeace?, .secretEnding?: return [.peace, .victory, .nuclear]
        case .diplomaticVictory?, .allianceLeader?, .honestBroker?: return [.diplomacy, .alliance, .victory]
        case .economicVictory?, .prosperity?: return [.economy, .peace]
        case .servedFullTerm?: return [.election, .leadership, .peace]
        case .manifestDestiny?, .sunNeverSets?, .everyRock?: return [.power, .victory, .economy]
        case .supremacy?, .survival?: return [.nuclear, .victory, .power]
        case .pyrrhicVictory?: return [.victory, .apocalypse, .defeat]
        case nil where [.lostElection, .termLimited, .retired, .deniedRenomination].contains(ending):
            return [.election, .leadership, .power]
        case nil: return destroyed ? [.apocalypse, .nuclear, .defeat] : [.defeat, .power, .coup]
        }
    }
}
#endif
