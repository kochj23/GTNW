//
//  RegimeQuery.swift
//  GTNWCore
//
//  `{"q":"regime"}`: the player's own government (Regime.swift, 3.37.0): its form, the leader's title, the names of
//  its legislature, deputy and military chiefs, how its leader falls (with the stage the pressure has reached, in its
//  words), whether it holds elections, and what it can do (forces of its own, the ally it would ask, and whether a
//  chemical or biological program would be restarted or started). For the United States the words are the familiar
//  ones. Read-only, no RNG.
//

#if GTNW_CORE
import Foundation

enum RegimeQuery: BridgeQuery {
    static let name = "regime"

    struct Result: Encodable {
        var country: String
        var kind: String
        var title: String
        var legislature: String
        var deputy: String
        var militaryChiefs: String
        var tenure: String
        var hasElections: Bool
        /// "Impeachment", "No-confidence vote", "Pressure to resign"…
        var removal: String
        var stage: Int
        /// The latest stage's line in the regime's words ("" at stage 0).
        var stageText: String
        var forcesOfItsOwn: Bool
        /// The friendly power it would ask to act, when it has no forces of its own.
        var allyToAsk: String?
        var chemicalProgram: String
        var biologicalProgram: String
    }

    static func run(_ args: NoArgs, engine: GameEngine?) throws -> Result {
        let (_, gs) = try GTNWBridge.game(engine)
        let r = gs.regime, t = r.terms
        let me = gs.getPlayerCountry()
        let armed = me.map(RegimeCapability.hasMeaningfulMilitary) ?? true
        let stage = gs.shadow.impeachmentStage
        let restart = { (k: WMDKind) in gs.playerCountryID == "USA" || RegimeCapability.hadProgram(k, gs.playerCountryID) ? "restart" : "start" }
        return Result(country: gs.playerCountryID, kind: r.kind.rawValue, title: t.title, legislature: r.isUS ? "Congress" : t.legislature,
                      deputy: r.isUS ? "Vice President" : t.deputy, militaryChiefs: r.isUS ? "Joint Chiefs" : t.chiefs,
                      tenure: t.tenure, hasElections: r.isUS ? gs.shadow.electionsEnabled : t.hasElections,
                      removal: r.removal.title, stage: stage,
                      stageText: stage == 0 ? "" : gs.say(r.removal.stageText(min(3, stage))),
                      forcesOfItsOwn: armed, allyToAsk: armed ? nil : RegimeCapability.nearestCapableAlly(gs, target: nil)?.name,
                      chemicalProgram: restart(.chemical), biologicalProgram: restart(.biological))
    }
}
#endif
