//
//  ManpowerQuery.swift
//  GTNWCore
//
//  `{"q":"manpower"}`: ManpowerSheet. The troops the President has (all, free, in garrisons), the era's standing
//  force, a historical draft in force or the all-volunteer force, and the two call-ups (a draft; the militia before
//  1861 or the reserves after) with their size, training time and political cost, whether one is called and how
//  far trained, or why it can't be. Answered with the `callUp` and `standDown` verbs.
//

#if GTNW_CORE
import Foundation

enum ManpowerQuery: BridgeQuery {
    static let name = "manpower"

    struct CallUp: Encodable {
        var kind: String
        var title: String
        var cost: String
        var called: String?
        var problem: String?
    }

    struct Result: Encodable {
        var date: String
        var troopsLine: String
        var standingLine: String
        var draftLine: String?
        var callUps: [CallUp]
    }

    static func run(_ args: NoArgs, engine: GameEngine?) throws -> Result {
        let (e, gs) = try GTNWBridge.game(engine)
        let date = gs.currentDate, year = gs.currentYear
        let atWar = !(gs.getPlayerCountry()?.atWarWith.isEmpty ?? true)
        var draftLine: String?
        if let h = ManpowerModel.historicalDraft(on: date) {
            draftLine = "In force: \(h.name), \(GameCalendar.format(h.from))–\(GameCalendar.format(h.to))."
        } else if date >= ManpowerModel.allVolunteer {
            draftLine = "All-volunteer force since 27 Jan 1973."
        }
        return Result(
            date: gs.currentDateLabel,
            troopsLine: "Troops \(Int(AttackSizing.troopPool(gs)))K · free \(Int(AttackSizing.freeTroops(gs)))K · garrisons \(Int(gs.shadow.garrisons.values.reduce(0, +)))K",
            standingLine: "Standing force \(Int(ManpowerModel.standing(year: year)))K (regulars and Guard of the era).",
            draftLine: draftLine,
            callUps: [ManpowerKind.draft, .mobilization].map { kind in
                let cost = ManpowerModel.callCost(kind, atWar: atWar)
                let months = ManpowerModel.trainingMonths(kind)
                let called = gs.shadow.mobilizations.first { $0.kind == kind }
                return CallUp(
                    kind: kind.rawValue, title: ManpowerModel.title(kind, year: year),
                    cost: String(format: "+%dK over %.0f month%@ · approval %+.0f · Congress %+d", Int(ManpowerModel.callUpSize(kind, year: year).rounded()),
                                 months, months == 1 ? "" : "s", cost.popularity, cost.congress),
                    called: called.map { c in
                        String(format: "Called %@; %.0f%% trained.", GameCalendar.format(c.started), ManpowerModel.trained(since: c.started, now: date, kind: kind) * 100)
                    },
                    problem: called == nil ? e.callUpProblem(kind) : nil)
            })
    }
}
#endif
