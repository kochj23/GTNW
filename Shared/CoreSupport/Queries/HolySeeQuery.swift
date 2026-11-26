//
//  HolySeeQuery.swift
//  GTNWCore
//
//  `{"q":"holySee"}` (3.37.0): the Situation Room's HOLY SEE sheet (HolySeeSheet.swift, HolySee.swift): whether it is
//  offered (the player leads Vatican City), the record and its points toward "Honest Broker", every action with its
//  summary, precedent, cooldown and why it can't be used now, the pairs on the board (wars and disputes), the treaties
//  open to ratify and the teaching themes. An action is the `holySee` verb; each uses one action. Read-only, no RNG.
//

#if GTNW_CORE
import Foundation

enum HolySeeQuery: BridgeQuery {
    static let name = "holySee"

    struct Action: Encodable {
        var op: String
        var title: String
        var summary: String
        var precedent: String
        /// 0, 1 or 2 nations.
        var targets: Int
        var cooldownDays: Int
        /// Why it can't be used now with no nations named (nil when it can, or when it needs nations: ask with them).
        var problem: String?
        var readyOn: String?
    }

    struct Pair: Encodable { var a: String; var b: String; var label: String; var atWar: Bool; var odds: Double }
    struct Option: Encodable { var id: String; var name: String }

    struct Result: Encodable {
        var offered: Bool
        var points: Int
        var victoryPoints: Int
        var victoryProblem: String?
        var record: [String: Double]
        var actions: [Action]
        var pairs: [Pair]
        var themes: [Option]
        var treaties: [Option]
        var recent: [String]
        var busy: Bool
    }

    static func run(_ args: NoArgs, engine: GameEngine?) throws -> Result {
        let (e, gs) = try GTNWBridge.game(engine)
        let offered = HolySeeModel.isOffered(gs)
        let r = gs.shadow.holySee.record
        let actions = offered ? HolySeeAction.allCases.map { a -> Action in
            let probe = a.targets == 0 && a != .encyclical && a != .ratifyTreaty ? e.holySeeProblem(HolySeeOrder(action: a)) : nil
            return Action(op: a.rawValue, title: a.title, summary: a.summary, precedent: a.precedent, targets: a.targets,
                          cooldownDays: a.cooldownDays, problem: probe, readyOn: HolySeeModel.readyOn(gs, a).map(GameCalendar.format))
        } : []
        let pairs = offered ? HolySeeModel.pairs(gs, wars: true, disputes: true).map { a, b in
            Pair(a: a.id, b: b.id, label: "\(a.name) – \(b.name)", atWar: a.atWarWith.contains(b.id),
                 odds: HolySeeModel.pairOdds(gs, a.atWarWith.contains(b.id) ? .hostTalks : .mediate, a.id, b.id))
        } : []
        let record: [String: Double] = [
            "treatiesAtVatican": Double(r.treatiesAtVatican), "ceasefires": Double(r.ceasefires), "crisesDefused": Double(r.crisesDefused),
            "warsAverted": Double(r.warsAverted), "warsDelayed": Double(r.warsDelayed), "thaws": Double(r.thaws), "livesSaved": Double(r.livesSaved),
            "treatiesRatified": Double(r.treatiesRatified), "treatyJoiners": Double(r.treatyJoiners), "debtRelievedB": r.debtRelievedB,
            "relationsOpened": Double(r.relationsOpened), "reforms": Double(r.reforms),
        ]
        return Result(offered: offered, points: HolySeeModel.points(gs), victoryPoints: HolySeeModel.victoryPoints,
                      victoryProblem: offered ? HolySeeModel.victoryProblem(gs) : nil, record: record, actions: actions, pairs: pairs,
                      themes: TeachingTheme.allCases.map { Option(id: $0.rawValue, name: $0.title) },
                      treaties: offered ? HolySeeModel.openTreaties(gs).map { Option(id: $0.id, name: $0.name) } : [],
                      recent: gs.shadow.holySee.log.suffix(8).map { "\(GameCalendar.format($0.date)): \($0.text)" },
                      busy: gs.actionsRemaining == 0 || e.isProcessingAITurn || gs.gameOver)
    }
}
#endif
