//
//  SystemsQuery.swift
//  GTNWCore
//
//  `{"q":"systems"}`: the app's Systems tab (SystemsView), the ten world systems on `GameState.systems`:
//  intelligence and espionage, crisis events, nuclear winter (environment, famine, disease, refugees), diplomacy and
//  treaties, proxy wars, economic warfare, AI personalities, submarines, space, and the historical scenarios.
//

#if GTNW_CORE
import Foundation

enum SystemsQuery: BridgeQuery {
    static let name = "systems"

    /// A label and a value, as the tab's rows print them.
    struct Row: Encodable {
        var label: String
        var value: String
        /// good, bad, warn or nil
        var tone: String?
    }

    struct Section: Encodable {
        var id: String
        var title: String
        var groups: [Group]
    }

    struct Group: Encodable {
        var title: String
        var rows: [Row]
    }

    struct Result: Encodable {
        var sections: [Section]
    }

    static func run(_ args: NoArgs, engine: GameEngine?) throws -> Result {
        let (_, gs) = try GTNWBridge.game(engine)
        let s = gs.systems
        func row(_ l: String, _ v: String, _ tone: String? = nil) -> Row { Row(label: l, value: v, tone: tone) }
        let intel = Section(id: "intel", title: "Intelligence & espionage", groups: [
            Group(title: "Spy networks: \(s.spyNets.count)", rows: s.spyNets.map {
                row($0.location, "Strength \($0.strength)% · \($0.compromised ? "COMPROMISED" : "Active")", $0.compromised ? "bad" : "good")
            }),
            Group(title: "Active operations: \(s.intelOps.count)", rows: s.intelOps.prefix(10).map {
                row($0.type.rawValue, "Turn \($0.turn) · \($0.success ? "Succeeded" : "Under way")", $0.success ? "good" : nil)
            }),
        ])
        let crisis = Section(id: "crisis", title: "Crisis events", groups: [
            Group(title: s.crises.isEmpty ? "No active crises" : "Active crises: \(s.crises.count)", rows: s.crises.map {
                row($0.type.rawValue.uppercased(), "Deadline: \($0.deadline) turns" + ($0.options.isEmpty ? "" : " · Options: " + $0.options.joined(separator: "; ")),
                    $0.deadline <= 2 ? "bad" : "warn")
            }),
            Group(title: "Resolved: \(s.resolved.count)", rows: []),
        ])
        let winter = Section(id: "winter", title: "Nuclear winter & environment", groups: [
            Group(title: "Environment", rows: [
                row("Stage", "\(s.environ.stage.rawValue)/5", s.environ.stage.rawValue > 0 ? "bad" : nil),
                row("Temperature drop", "-\(s.environ.temp)°C"), row("Food production", "\(s.environ.food)%"),
                row("Habitable land", "\(s.environ.land)%"), row("Atmospheric soot", "\(s.environ.soot)%"),
            ]),
            Group(title: "Famine", rows: [
                row("Severity", "\(s.famine.severity)%"), row("Deaths", "\(s.famine.deaths)"),
                row("Food reserves", "\(s.famine.reserves) months"), row("Civil unrest", "\(s.famine.unrest)%"),
            ]),
            Group(title: "Disease outbreaks", rows: [row("Total cases", "\(s.disease.total)")]),
            Group(title: "Refugee crisis", rows: [row("Total refugees", "\(s.refugees.total) million")]),
        ])
        let diplomacy = Section(id: "diplomacy", title: "Diplomacy & treaties", groups: [
            Group(title: "Treaty proposals: \(s.treaties.count)", rows: s.treaties.map {
                row($0.type.rawValue, $0.accepted ? "Signed" : "Pending", $0.accepted ? "good" : "warn")
            }),
            Group(title: "Verification missions: \(s.verifications.count)", rows: s.verifications.prefix(10).map {
                row("Inspector: \($0.initiatorID)", $0.cheating ? "CHEATING DETECTED" : "Compliant", $0.cheating ? "bad" : "good")
            }),
        ])
        let proxy = Section(id: "proxy", title: "Proxy wars & conventional warfare", groups: [
            Group(title: "Active proxy wars: \(s.proxies.count)", rows: s.proxies.map {
                row($0.type.rawValue, "Strength \($0.strength)% · Casualties \($0.casualties)")
            }),
            Group(title: "Arms deals: \(s.arms.count)", rows: []),
        ])
        let economy = Section(id: "economy", title: "Economic warfare", groups: [
            Group(title: "Active sanctions: \(s.sanctions.count)", rows: s.sanctions.map { row($0.type.rawValue, "\($0.imposer) → \($0.target)") }),
            Group(title: "Currency attacks: \(s.currency.count)", rows: s.currency.prefix(10).map {
                row("\($0.initiatorID) → \($0.targetID)", "Inflation: \($0.inflation)%")
            }),
        ])
        let ai = Section(id: "ai", title: "AI personalities", groups: Leader.presets.map {
            Group(title: $0.name.uppercased(), rows: [row("Personality", $0.personality.rawValue), row("Ideology", $0.ideology.rawValue),
                                                      row("Goal", $0.goal.rawValue)])
        })
        let subs = Section(id: "subs", title: "Submarine warfare", groups: [
            Group(title: "Deployed submarines: \(s.subs.count)", rows: s.subs.map {
                row($0.subClass.rawValue, "\($0.detected ? "DETECTED" : "Hidden") · \($0.loc.rawValue) · Warheads \($0.warheads)", $0.detected ? "bad" : "good")
            }),
            Group(title: "ASW operations: \(s.asw.count)", rows: []),
        ])
        let space = Section(id: "space", title: "Space warfare", groups: [
            Group(title: "Satellites: \(s.sats.count)", rows: s.sats.map {
                row($0.type.rawValue, $0.operational ? "Operational" : "Offline", $0.operational ? "good" : "bad")
            }),
            Group(title: "Orbital debris", rows: [
                row("Total debris", "\(s.debris.total)"),
                row("Kessler syndrome risk", "\(s.debris.kessler)%", s.debris.kessler > 75 ? "bad" : (s.debris.kessler > 50 ? "warn" : nil)),
                row("Compromised zones", s.debris.zones.isEmpty ? "None" : s.debris.zones.joined(separator: ", ")),
            ]),
        ])
        let scenario = Section(id: "scenario", title: "Historical scenarios", groups: Scenario.all.map {
            Group(title: "\($0.name) (\($0.year))", rows: [row("Difficulty", $0.difficulty.rawValue), row("Situation", $0.desc), row("Objective", $0.objective)])
        })
        return Result(sections: [intel, crisis, winter, diplomacy, proxy, economy, ai, subs, space, scenario])
    }
}
#endif
