//
//  BrainMovesVerb.swift
//  GTNWCore
//
//  `{"verb":"brainMoves","on":true,"moves":{"RUS":{"action":"WAIT","target":null}}}`: the site AI's answers for
//  the coming end of turn (the `brains` query's jobs), staged for the engine's brain transport. `on: false` (AI off
//  or signed out) makes every model brain play the rule-based AI, as the app does with AI off. Changes nothing else.
//

#if GTNW_CORE
import Foundation

enum BrainMovesVerb: BridgeVerb {
    static let name = "brainMoves"

    struct Args: Decodable { var on: Bool; var moves: [String: MoveResponse]? }

    static func run(_ a: Args, engine e: GameEngine, state gs: GameState) throws -> GTNWBridge.Report? {
        CoreAI.brainsOn = a.on
        WebBrains.install(e)
        WebBrains.staged = a.on ? (a.moves ?? [:]).filter { gs.getCountry(id: $0.key) != nil } : [:]
        return nil
    }
}
#endif
