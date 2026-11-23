//
//  DirtyTacticsQuery.swift
//  GTNWCore
//
//  `{"q":"dirtyTactics","target":"CUB","preset":"standard"}`: the app's DirtyTacticsSheet for the era. Each tactic
//  with its legal status and the treaty behind it, why it can't be used against the target, a programme under way
//  or a stance in force, and the chance a covert use is found out at the chosen scale. Tactics the era doesn't allow
//  yet are listed with the reason.
//

#if GTNW_CORE
import Foundation

enum DirtyTacticsQuery: BridgeQuery {
    static let name = "dirtyTactics"

    struct Args: Decodable {
        var target: String?
        var preset: String?
    }

    struct Tactic: Encodable {
        var id: String
        var group: String
        var name: String
        var status: String
        var statusLabel: String
        var blurb: String
        var note: String?
        var problem: String?
        var programReady: String?
        var inForce: Bool
        var stance: Bool
        var canBeCovert: Bool
        /// A research programme (AUTHORISE) rather than a use (OPENLY / IN SECRET).
        var program: Bool
        var covertRisk: Double?
    }

    struct Later: Encodable {
        var id: String
        var group: String
        var name: String
        var from: Int
        var reason: String
    }

    struct Result: Encodable {
        var year: Int
        var dateLabel: String
        var groups: [[String: String]]
        var presets: [String]
        var tactics: [Tactic]
        var later: [Later]
        var actionsRemaining: Int
    }

    static func run(_ args: Args, engine: GameEngine?) throws -> Result {
        let (e, gs) = try GTNWBridge.game(engine)
        let year = gs.currentYear
        let preset = args.preset.flatMap(AttackPreset.init(rawValue:)) ?? .standard
        let groups = TacticGroup.allCases.filter { !DirtyTactics.available(in: year, group: $0).isEmpty }
        let tactics = DirtyTactics.available(in: year).map { t -> Tactic in
            let status = t.status(in: year)
            let inForce = gs.shadow.tacticStances.contains(DirtyTactics.stanceKey(t.id, target: args.target))
            return Tactic(id: t.id, group: t.group.rawValue, name: t.name, status: status.rawValue, statusLabel: status.label, blurb: t.blurb,
                          note: t.note(in: year), problem: e.tacticProblem(t.id, target: args.target),
                          programReady: gs.shadow.tacticPrograms[t.id].map { GameCalendar.format($0.ready) }, inForce: inForce,
                          stance: t.isStance, canBeCovert: t.canBeCovert, program: DirtyTactics.programYears(t) != nil,
                          covertRisk: t.canBeCovert ? QueryText.round2(DirtyTactics.discoveryChance(t, year: year, scale: preset.multiplier)) : nil)
        }
        let later = DirtyTactics.all.filter { year < $0.from }.map {
            Later(id: $0.id, group: $0.group.rawValue, name: $0.name, from: $0.from, reason: DirtyTactics.eraReason($0, year: year))
        }
        return Result(year: year, dateLabel: gs.currentDateLabel, groups: groups.map { ["id": $0.rawValue, "title": $0.title] },
                      presets: AttackPreset.allCases.map(\.rawValue), tactics: tactics, later: later, actionsRemaining: gs.actionsRemaining)
    }
}
#endif
