//
//  SizedOrderVerb.swift
//  GTNWCore
//
//  `{"verb":"sizedOrder","action":"Ground Invasion","target":"CUB","troops":120}`: an offensive ordered after the
//  cabinet's advice at a size the President set on the force-sizing panel (AttackSizingPanel), rather than a preset
//  (the `act` advised order with `preset`). The size is clamped to what is free; the era's warhead goes with a
//  nuclear order. The report is the app's ActionResultSheet.
//

#if GTNW_CORE
import Foundation

enum SizedOrderVerb: BridgeVerb {
    static let name = "sizedOrder"

    struct Args: Decodable {
        var action: String
        var target: String
        var troops: Double?
        var aircraft: Int?
        var warheads: Int?
    }

    static func run(_ a: Args, engine e: GameEngine, state gs: GameState) throws -> GTNWBridge.Report? {
        guard let action = PresidentialAction(rawValue: a.action) else { throw QueryError("unknown action \(a.action)") }
        let kinds = AttackSizing.kinds(for: action)
        guard !kinds.isEmpty else { throw QueryError("\(a.action) is not sized") }
        guard let me = gs.getPlayerCountry(), let t = gs.getCountry(id: a.target), !t.isDestroyed, t.id != me.id else {
            throw QueryError("Pick a foreign nation on the map.")
        }
        guard gs.actionsRemaining > 0 else { throw QueryError("No actions left this \(gs.turnLength.displayName.lowercased()).") }
        guard action.isAvailable(on: gs.currentDate, in: gs) else { throw QueryError("\(a.action) is not available in \(gs.currentYear).") }
        if action.wmd != nil, let problem = e.wmdProblem(action) { throw QueryError(problem) }
        if let k = kinds.first(where: { AttackSizing.available($0, in: gs) <= 0 }) { throw QueryError("Nothing to send: no \(k.label.lowercased()) available.") }
        let std = AttackSizing.preset(.standard, for: action, in: gs)
        let size = AttackSizing.clamp(AttackSize(troops: a.troops ?? std.troops, aircraft: a.aircraft ?? std.aircraft, warheads: a.warheads ?? std.warheads),
                                      for: action, in: gs)
        let warhead = kinds.contains(.warheads) ? GTNWBridge.defaultWarhead(action, year: gs.currentYear) : nil
        let advice = AdviceEngine.advise(action: action, player: me, target: t, gameState: gs)
        e.actionResult = nil
        e.performAdvisedAction(action, targetID: t.id, advice: advice, size: size, warhead: warhead)
        return e.actionResult.map(GTNWBridge.report)
    }
}
#endif
