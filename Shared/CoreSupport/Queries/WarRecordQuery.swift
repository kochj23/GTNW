//
//  WarRecordQuery.swift
//  GTNWCore
//
//  `{"q":"warRecord"}`: the Records sheet's WAR, FOG and LEGENDS panels, shown in the web War Room. Why they went
//  (governments' deliberations before their wars, and the reasons they gave), what we do not know (the silences,
//  orders with no word back, and how old the intelligence is), and the debrief the game writes for itself, with the
//  chronicle as Markdown for export.
//

#if GTNW_CORE
import Foundation

enum WarRecordQuery: BridgeQuery {
    static let name = "warRecord"

    struct Deliberation: Encodable { var title: String; var went: Bool; var verdict: String; var estimate: String; var statement: String }
    struct Block: Encodable { var title: String; var body: String }

    struct Result: Encodable {
        var deliberations: [Deliberation]
        var reasons: [String]
        var silence: [String]
        var dispatches: [String]
        var intel: [String]
        var debrief: [Block]
        var sitting: [String]
        var chronicle: String
    }

    static func run(_ args: NoArgs, engine: GameEngine?) throws -> Result {
        let (_, gs) = try GTNWBridge.game(engine)
        func n(_ id: String) -> String { gs.getCountry(id: id)?.name ?? id }
        let latest = gs.shadow.intel.filter { $0.field == .army }.sorted { $0.asOfTurn > $1.asOfTurn }.prefix(10)
        return Result(
            deliberations: gs.shadow.deliberations.suffix(6).reversed().map { d in
                Deliberation(title: "\(n(d.actor)) → \(n(d.target))", went: d.chose == "war", verdict: d.chose == "war" ? "Went" : "Held off",
                             estimate: "Capability \(WarCouncil.pct(d.estimate.capability)) · their will \(WarCouncil.pct(d.estimate.resolve)) · confidence \(WarCouncil.pct(d.estimate.confidence)) · test: \(d.doneTest.kind.rawValue)",
                             statement: d.statement)
            },
            reasons: gs.shadow.casusLog.suffix(8).reversed().map { c in "\(GameCalendar.format(c.date)): \(c.statement)\(c.supported ? "" : " (thin)")" },
            silence: Intelligence.silence(gs),
            dispatches: gs.shadow.dispatches.map { d in "\(d.label): sent \(GameCalendar.format(d.sent)), nothing expected before \(GameCalendar.format(d.due))." },
            intel: latest.map { $0.line(name: n($0.subject), now: gs.turn) },
            debrief: Debrief.lines(gs).map { Block(title: $0.title, body: $0.body) },
            sitting: gs.shadow.sittingDebrief,
            chronicle: Legends.markdown(gs))
    }
}
#endif
