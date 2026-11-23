//
//  RecordsQuery.swift
//  GTNWCore
//
//  `{"q":"records"}`: the app's RecordsSheet tabs. INFAMY: the Hall of Infamy (personal records across every game
//  in this browser) and the record of the age; NAMES: the lands the President renamed; EMPIRE: progress toward the
//  empire victories; WAR: what governments weighed before their wars and the reasons they gave; FOG: what we have
//  not heard and how old the rest is; LEGENDS: the debrief and the sitting's own. `hall` is the Hall as stored (the
//  front end keeps it between visits and hands it back with the `hallOfInfamy` verb).
//

#if GTNW_CORE
import Foundation

enum RecordsQuery: BridgeQuery {
    static let name = "records"

    struct Infamy: Encodable {
        var id: String
        var title: String
        var value: String?
        var who: String?
    }

    struct Dated: Encodable {
        var date: String
        var text: String
    }

    struct Name: Encodable {
        var land: String
        var original: String
        var current: String
        var date: String
    }

    struct Goal: Encodable {
        var id: String
        var title: String
        var status: String
        var description: String
    }

    struct Deliberation: Encodable {
        var actor: String
        var target: String
        var went: Bool
        var estimate: String
        var statement: String
    }

    struct Block: Encodable {
        var title: String
        var body: String
    }

    struct Result: Encodable {
        var infamy: [Infamy]
        var age: [Dated]
        var names: [Name]
        var empire: [Goal]
        var deliberations: [Deliberation]
        var reasons: [String]
        var silence: [String]
        var dispatches: [String]
        var reports: [String]
        var debrief: [Block]
        var sitting: [String]
        var hall: String
    }

    static func run(_ args: NoArgs, engine: GameEngine?) throws -> Result {
        let (_, gs) = try GTNWBridge.game(engine)
        let hall = HallOfInfamy.load()
        let name = { (id: String) in gs.getCountry(id: id)?.name ?? id }
        let met = Set(gs.shadow.empireAtStart ?? [])
        let raw = Dictionary(uniqueKeysWithValues: hall.map { ($0.key.rawValue, $0.value) })
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        enc.dateEncodingStrategy = .secondsSince1970
        return Result(
            infamy: InfamyRecord.allCases.map { r in
                Infamy(id: r.rawValue, title: r.title, value: hall[r].map { r.format($0.value) }, who: hall[r]?.who)
            },
            age: gs.shadow.worldAtrocities.suffix(5).reversed().map { Dated(date: GameCalendar.format($0.date), text: $0.text) },
            names: gs.nameBook.prefix(40).map { Name(land: $0.land, original: $0.original, current: $0.current, date: GameCalendar.format($0.date)) },
            empire: EmpireGoal.allCases.map { g in
                let p = EmpireModel.progress(g, gs)
                return Goal(id: g.rawValue, title: g.title, status: met.contains(g.rawValue) ? "HELD AT THE START" : "\(p.held)/\(p.total) · \(g.victory.baseScore) PTS",
                            description: g.victory.description)
            },
            deliberations: gs.shadow.deliberations.suffix(6).reversed().map { d in
                Deliberation(actor: name(d.actor), target: name(d.target), went: d.chose == "war",
                             estimate: "Capability \(WarCouncil.pct(d.estimate.capability)) · their will \(WarCouncil.pct(d.estimate.resolve)) · confidence \(WarCouncil.pct(d.estimate.confidence)) · test: \(d.doneTest.kind.rawValue)",
                             statement: d.statement)
            },
            reasons: gs.shadow.casusLog.suffix(8).reversed().map { "\(GameCalendar.format($0.date)): \($0.statement)\($0.supported ? "" : " (thin)")" },
            silence: Intelligence.silence(gs),
            dispatches: gs.shadow.dispatches.map { "\($0.label): sent \(GameCalendar.format($0.sent)), nothing expected before \(GameCalendar.format($0.due))." },
            reports: gs.shadow.intel.filter { $0.field == .army }.sorted { $0.asOfTurn > $1.asOfTurn }.prefix(10).map { $0.line(name: name($0.subject), now: gs.turn) },
            debrief: Debrief.lines(gs).map { Block(title: $0.title, body: $0.body) },
            sitting: gs.shadow.sittingDebrief,
            hall: (try? enc.encode(raw)).map { String(decoding: $0, as: UTF8.self) } ?? "{}")
    }
}
#endif
