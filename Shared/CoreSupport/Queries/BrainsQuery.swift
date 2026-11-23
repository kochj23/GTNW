//
//  BrainsQuery.swift
//  GTNWCore
//
//  `{"q":"brains"}`: who plays each country (the app's BrainAssignmentView) and whether the player is only watching
//  (Watch AI vs AI). On the web a country's brain is the player (human), the built-in rule-based AI, or the site's
//  AI service (`AIBrain.kit(backend: "games-relay")`, see `WebBrains`). `jobs` are the moves the next end of turn
//  will ask the site AI for, each with the request the app's brains are sent; the front end asks for them before
//  it ends the turn and hands the answers in with the `brainMoves` verb. Countries the AI doesn't answer for (or
//  answers wrongly) play the rule-based AI that turn, as in the app.
//

#if GTNW_CORE
import Foundation

enum BrainsQuery: BridgeQuery {
    static let name = "brains"

    struct Args: Decodable {
        /// Include `jobs` (the next end of turn's site-AI requests).
        var jobs: Bool?
    }

    struct Country: Encodable {
        var id: String
        var name: String
        var flag: String
        var warheads: Int
        var military: Int
        var isPlayer: Bool
        /// human, rule, relay
        var brain: String
        var label: String
    }

    struct Job: Encodable {
        var country: String
        var name: String
        var year: Int
        var situation: String
        var legal: [String]
    }

    struct Result: Encodable {
        var spectating: Bool
        var aiOn: Bool
        var countries: [Country]
        var relayCount: Int
        var jobs: [Job]
    }

    static func run(_ args: Args, engine: GameEngine?) throws -> Result {
        let (e, gs) = try GTNWBridge.game(engine)
        let list = gs.countries.filter { !$0.isDestroyed && !$0.isTerritory }.sorted { $0.name < $1.name }.map { c -> Country in
            let b = e.brain(for: c.id)
            let kind = WebBrains.kind(b)
            return Country(id: c.id, name: c.name, flag: c.flag, warheads: c.nuclearWarheads, military: c.militaryStrength,
                           isPlayer: c.id == gs.playerCountryID, brain: kind, label: WebBrains.label(kind))
        }
        return Result(spectating: e.spectating, aiOn: CoreAI.brainsOn, countries: list,
                      relayCount: list.filter { $0.brain == "relay" }.count, jobs: args.jobs == true ? jobs(e, gs) : [])
    }

    /// The countries whose site-AI brain thinks at the next end of turn (processAITurnsWithBrains's choice: the turn
    /// counter has moved on by then), with what they are asked.
    static func jobs(_ e: GameEngine, _ gs: GameState) -> [Job] {
        let turn = gs.turn + 1
        let thinking = gs.countries
            .filter { (e.spectating || !$0.isPlayerControlled) && !$0.isDestroyed && !$0.isTerritory && WebBrains.kind(e.brain(for: $0.id)) == "relay" }
            .filter { e.brainThinks($0.id, turn: turn) }
            .sorted { CountryProfile.stableUnit($0.id + "\(turn)") < CountryProfile.stableUnit($1.id + "\(turn)") }
            .prefix(GameEngine.maxBrainCallsPerTurn)
        return thinking.compactMap { c in
            guard let r = e.buildMoveRequest(for: c.id) else { return nil }
            return Job(country: c.id, name: c.name, year: r.year, situation: r.worldStateSummary, legal: r.legalActions)
        }
    }
}

/// The brains a web game offers.
enum WebBrains {
    static let backend = "games-relay"
    static let relay = AIBrain.kit(backend: backend, model: "")

    static func kind(_ b: AIBrain) -> String {
        switch b {
        case .human: return "human"
        case .kit(let backend, _) where backend == Self.backend: return "relay"
        default: return "rule"
        }
    }

    static func label(_ kind: String) -> String {
        switch kind {
        case "human": return "Human"
        case "relay": return "Site AI (games relay)"
        default: return "Rule-Based AI"
        }
    }

    /// Answers for this end of turn, by country (set by the `brainMoves` verb, used once).
    nonisolated(unsafe) static var staged: [String: MoveResponse] = [:]

    /// The engine's brain transport on the web: the staged answer for the country's first ask, nothing after.
    static func install(_ e: GameEngine) {
        e.brainTransportOverride = { request, _ in
            await MainActor.run { () -> MoveResponse? in
                guard request.previousError == nil else { return nil }
                return WebBrains.staged.removeValue(forKey: request.countryId)
            }
        }
    }
}
#endif
