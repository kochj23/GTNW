//
//  DirtyTacticVerb.swift
//  GTNWCore
//
//  `{"verb":"dirtyTactic","id":"…","target":"CUB","covert":true,"preset":"standard"}`: DirtyTacticsSheet's
//  OPENLY / IN SECRET / AUTHORISE (one action), or `"stance":true|false` to put a standing policy in force or lift it.
//

#if GTNW_CORE
import Foundation

enum DirtyTacticVerb: BridgeVerb {
    static let name = "dirtyTactic"

    struct Args: Decodable { var id: String; var target: String?; var covert: Bool?; var preset: String?; var stance: Bool? }

    static func run(_ a: Args, engine e: GameEngine, state gs: GameState) throws -> GTNWBridge.Report? {
        guard let t = DirtyTactics.tactic(a.id) else { throw QueryError("unknown tactic \(a.id)") }
        if let on = a.stance {
            guard t.isStance else { throw QueryError("\(t.name) is not a standing policy") }
            if on, let p = e.tacticProblem(t.id, target: a.target) { throw QueryError(p) }
            if on && gs.actionsRemaining == 0 { throw QueryError("no actions left this turn") }
            guard e.setStance(t.id, target: a.target, on: on) else { throw QueryError("\(t.name) can't be \(on ? "put in force" : "lifted")") }
            return nil
        }
        guard gs.actionsRemaining > 0 else { throw QueryError("no actions left this turn") }
        if let p = e.tacticProblem(t.id, target: a.target) { throw QueryError(p) }
        let preset = a.preset.flatMap(AttackPreset.init(rawValue:)) ?? .standard
        guard e.useTactic(t.id, target: a.target, covert: a.covert == true, preset: preset) != nil else { throw QueryError("\(t.name) can't be used") }
        return nil
    }
}
#endif
