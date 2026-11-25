//
//  ActionsQuery.swift
//  GTNWCore
//
//  `{"q":"actions","target":"FRA"}`: the escalation ladder against one nation (the app's ActionLadder and
//  ActionLadderSheet): the five rungs and, on each, the actions this date allows (`isAvailable(on:in:)`) with cost,
//  risk, the estimated odds against this target and why an action cannot go ahead (`wmdProblem`). The advice on one
//  action is the `advice` query. Without `target` the actions come without odds.
//

#if GTNW_CORE
import Foundation

enum ActionsQuery: BridgeQuery {
    static let name = "actions"

    struct Args: Decodable { var target: String? }

    struct Rung: Encodable {
        var rung: Int
        var title: String
        /// The cabinet post that speaks first on this rung.
        var advisorRole: String
    }

    struct Action: Encodable {
        /// The order's name, as `act` takes it ("Send Ambassador").
        var id: String
        /// 3.37.0: the order as the player's nation gives it ("Start a Secret Chemical Program", "Ask Italy: Air Strike").
        var title: String
        var rung: Int
        var category: String
        var hostile: Bool
        var description: String
        var cost: Double
        var risk: String
        var odds: Double?
        /// Why it cannot be ordered now (chemical / biological programs, sizing with nothing to send), or nil.
        var problem: String?
        /// Gets the three-line cabinet warning before it is ordered (the `advice` query has it).
        var major: Bool
        /// Sized by these forces (troops, aircraft, warheads); empty = not sized.
        var sizedBy: [String]
    }

    struct Result: Encodable {
        var target: String?
        var targetName: String?
        /// False for the player's own country, a destroyed one, or with no actions left.
        var usable: Bool
        var actionsRemaining: Int
        var actionsPerTurn: Int
        var rungs: [Rung]
        var actions: [Action]
    }

    static func run(_ args: Args, engine: GameEngine?) throws -> Result {
        let (e, gs) = try GTNWBridge.game(engine)
        let player = gs.getPlayerCountry()
        var target: Country?
        if let id = args.target {
            guard let t = gs.getCountry(id: id) else { throw QueryError("no country \(id)") }
            target = t
        }
        let usable = target.map { !$0.isDestroyed && !$0.isPlayerControlled } == true && gs.actionsRemaining > 0 && !gs.gameOver
        let actions = PresidentialAction.allCases.filter { $0.isAvailable(on: gs.currentDate, in: gs) }.map { a -> Action in
            let kinds = AttackSizing.kinds(for: a)
            var problem = a.wmd != nil ? e.wmdProblem(a) : nil
            let asksAlly = RegimeCapability.needsAlly(a, in: gs)   // 3.37.0: an ally's forces, not ours
            if problem == nil, !asksAlly, let k = kinds.first(where: { AttackSizing.available($0, in: gs) <= 0 }) {
                problem = "Nothing to send: no \(k.label.lowercased()) available."
            }
            let odds = player.flatMap { p in target.map { QueryText.round2(AdviceEngine.successEstimate(action: a, player: p, target: $0)) } }
            return Action(id: a.rawValue, title: a.title(in: gs), rung: a.rung.rawValue, category: a.category.rawValue, hostile: a.isHostile,
                          description: a.description(in: gs), cost: QueryText.dollars(a.cost), risk: a.riskLevel.rawValue, odds: odds,
                          problem: problem, major: MajorAction.isMajor(a), sizedBy: kinds.map(\.rawValue))
        }
        return Result(target: target?.id, targetName: target?.name, usable: usable, actionsRemaining: gs.actionsRemaining,
                      actionsPerTurn: gs.actionsPerTurn,
                      rungs: EscalationRung.allCases.map { Rung(rung: $0.rawValue, title: $0.title, advisorRole: $0.leadAdvisorKey) },
                      actions: actions)
    }
}
#endif
