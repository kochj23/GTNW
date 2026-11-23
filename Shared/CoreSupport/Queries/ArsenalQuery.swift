//
//  ArsenalQuery.swift
//  GTNWCore
//
//  `{"q":"arsenal","target":"CUB","action":"Ground Invasion","troops":120}` (all optional): the era's weapons
//  under each military order (ArsenalLine: what the country actually had this year, its legal status and the
//  treaty behind it; restricted and banned options are labelled, never hidden) and, for one sized order, the force
//  sizing panel (AttackSizingPanel: the presets, each force with what is free, and the honest read-out from the
//  engine's own functions) with the cabinet's warnings. Ordered with the `sizedOrder` verb.
//

#if GTNW_CORE
import Foundation

enum ArsenalQuery: BridgeQuery {
    static let name = "arsenal"

    struct Args: Decodable {
        var target: String?
        var action: String?
        var troops: Double?
        var aircraft: Int?
        var warheads: Int?
    }

    struct Line: Encodable {
        var action: String
        var rung: Int
        var hostile: Bool
        /// "Arsenal 1962: M48 Patton tanks · …" (up to four examples), or nil.
        var arsenal: String?
        /// "Treaty-banned — Banned by the Chemical Weapons Convention (in force 1997)", shown for anything not plainly
        /// legal and for every chemical / biological order.
        var legal: String?
        /// legal, restricted, treatyBanned, destroyed
        var status: String?
        var problem: String?
        var sized: Bool
    }

    struct Force: Encodable { var kind: String; var label: String; var cap: Int; var amount: Int; var capLine: String }
    struct Preset: Encodable { var id: String; var title: String; var troops: Int; var aircraft: Int; var warheads: Int; var selected: Bool }

    struct Sizing: Encodable {
        var action: String
        var forces: [Force]
        var presets: [Preset]
        var readout: String
        var escalates: Bool
        var warnings: [WarSupport.Warning]
        var orderTitle: String
        var problem: String?
    }

    struct Result: Encodable {
        var year: Int
        var target: String?
        var targetName: String?
        var lines: [Line]
        var sizing: Sizing?
    }

    static func run(_ args: Args, engine: GameEngine?) throws -> Result {
        let (e, gs) = try GTNWBridge.game(engine)
        let year = gs.currentYear
        let lines = PresidentialAction.allCases.filter { $0.isAvailable(on: gs.currentDate, in: gs) }.compactMap { a -> Line? in
            let examples = ArsenalCatalog.examples(for: a, year: year)
            let status = a.wmd.map { ArsenalCatalog.legalStatus($0, on: gs.currentDate) } ?? ArsenalCatalog.status(for: a, year: year)
            guard !examples.isEmpty || status != nil || a.wmd != nil else { return nil }
            let treaty = a.wmd.map { ArsenalCatalog.treatyLabel($0, year: year) }
                ?? ArsenalCatalog.optionIDs(for: a).first.flatMap(ArsenalCatalog.option)?.note(in: year)
                    .map { note in String((note.components(separatedBy: ". ").first ?? note).components(separatedBy: "; ").first!.prefix(110)) }
            let shown = status.flatMap { s in s != .legal || a.wmd != nil ? s : nil }
            return Line(action: a.rawValue, rung: a.rung.rawValue, hostile: a.isHostile,
                        arsenal: examples.isEmpty ? nil : "Arsenal \(year): " + examples.prefix(4).joined(separator: " · "),
                        legal: shown.map { "\($0.label)\(treaty.flatMap { $0 }.map { " — \($0)" } ?? "")" }, status: shown?.rawValue,
                        problem: a.wmd != nil ? e.wmdProblem(a) : nil, sized: !AttackSizing.kinds(for: a).isEmpty)
        }
        var sizing: Sizing?
        if let name = args.action {
            guard let a = PresidentialAction(rawValue: name) else { throw QueryError("unknown action \(name)") }
            let kinds = AttackSizing.kinds(for: a)
            if !kinds.isEmpty {
                let custom = args.troops != nil || args.aircraft != nil || args.warheads != nil
                let std = AttackSizing.preset(.standard, for: a, in: gs)
                let size = custom ? AttackSizing.clamp(AttackSize(troops: args.troops ?? std.troops, aircraft: args.aircraft ?? std.aircraft,
                                                                  warheads: args.warheads ?? std.warheads), for: a, in: gs) : std
                let target = args.target.flatMap { gs.getCountry(id: $0) }
                let warnings = target.map { e.advisorWarnings(for: .attack(a, target: $0.id, size: size)) } ?? []
                var problem = e.wmdProblem(a)
                if problem == nil, let k = kinds.first(where: { AttackSizing.available($0, in: gs) <= 0 }) {
                    problem = "Nothing to send: no \(k.label.lowercased()) available."
                }
                if problem == nil, target == nil || target?.isDestroyed == true || target?.id == gs.playerCountryID { problem = "Pick a foreign nation on the map." }
                if problem == nil, gs.actionsRemaining == 0 { problem = "No actions left this \(gs.turnLength.displayName.lowercased())." }
                sizing = Sizing(
                    action: a.rawValue,
                    forces: kinds.map { k in
                        let cap = AttackSizing.available(k, in: gs)
                        return Force(kind: k.rawValue, label: k.label, cap: Int(cap), amount: Int(size.amount(k)),
                                     capLine: cap > 0 ? "\(Int(size.amount(k))) of \(Int(cap)) free" : "None available in \(year)")
                    },
                    presets: AttackPreset.allCases.map { p in
                        let s = AttackSizing.preset(p, for: a, in: gs)
                        return Preset(id: p.rawValue, title: p.title, troops: Int(s.troops), aircraft: s.aircraft, warheads: s.warheads, selected: s == size)
                    },
                    readout: readout(a, kinds: kinds, size: size, target: target, gs: gs),
                    escalates: AttackSizing.escalates(scale: AttackSizing.scale(size, for: a, in: gs)),
                    warnings: WarSupport.warnings(warnings),
                    orderTitle: WarSupport.proceedTitle(warnings, default: "Order \(a.rawValue)"), problem: problem)
            }
        }
        return Result(year: year, target: args.target, targetName: args.target.map { WarSupport.name($0, gs) }, lines: lines, sizing: sizing)
    }

    /// AttackSizingPanel.readout: the same functions the engine uses.
    static func readout(_ a: PresidentialAction, kinds: [ForceKind], size: AttackSize, target: Country?, gs: GameState) -> String {
        let m = AttackSizing.scale(size, for: a, in: gs)
        var parts: [String] = []
        if kinds.contains(.troops), let t = target, let p = gs.getPlayerCountry() {
            parts.append("Opening odds \(Int(AttackSizing.invasionOdds(troops: size.troops, attacker: p, defender: t) * 100))%")
        } else {
            parts.append("Success \(Int(AttackSizing.successOdds(scale: m) * 100))%")
        }
        if kinds.contains(.aircraft), let t = target {
            parts.append("~\(AttackSizing.aircraftLost(sorties: size.aircraft, against: t)) aircraft lost")
        }
        if kinds.contains(.warheads) {
            parts.append("Up to \(grouped(size.warheads * 1_000_000)) casualties before defenses; retaliation up to \(size.warheads * 2) warheads")
        }
        let hit = AttackSizing.worldHit(scale: m)
        parts.append(hit > 0 ? "World opinion −\(hit)" : "No extra world reaction")
        if AttackSizing.escalates(scale: m) { parts.append("Escalation: alert level rises") }
        return parts.joined(separator: " · ")
    }

    /// 1234567 → "1,234,567" (WASI Foundation has no locale data).
    static func grouped(_ n: Int) -> String {
        let s = String(abs(n))
        var out = ""
        for (i, ch) in s.enumerated() {
            if i > 0 && (s.count - i) % 3 == 0 { out.append(",") }
            out.append(ch)
        }
        return (n < 0 ? "-" : "") + out
    }
}
#endif
