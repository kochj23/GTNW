//
//  Chronicle.swift
//  Global Thermal Nuclear War
//
//  3.32.3: the game writes its own record.
//    • The DEBRIEF (counterfactual): the three decisions that bent the timeline most, the crisis that almost
//      happened, and what the cabinet believed at the time set against what was true. It is assembled from what the
//      game already recorded — the pre-war deliberations and their estimates against the truth (WarCouncil), the
//      stated reasons, the peace terms and whether the paper held, the tactics, the outbreaks, the arsenal — not
//      from anything written for the occasion. Available at the end and on demand.
//    • LEGENDS: the same material as a readable chronicle of the whole presidency, exportable as Markdown, in the
//      manner of a legends mode: what the world was, what was decided, what came of it.
//  Nothing here invents events; if the record is thin, the chronicle is short and says so.
//  Repository: https://github.com/kochj23/GTNW
//

import Foundation

/// One block of the debrief.
struct DebriefLine: Identifiable, Hashable {
    var id = UUID()
    var title: String
    var body: String
}

enum Debrief {
    /// How many decisions the debrief names.
    static let decisions = 3

    /// The decisions that bent the timeline most, weighted by what they cost and what they changed.
    static func turningPoints(_ gs: GameState) -> [(weight: Double, text: String)] {
        var out: [(Double, String)] = []
        for s in gs.nuclearStrikes where s.attacker == gs.playerCountryID {
            out.append((1000 + Double(s.casualties) / 1000,
                        "\(GameCalendar.format(gs.date(atTurn: s.turn))): the United States used nuclear weapons against \(gs.getCountry(id: s.target)?.name ?? s.target). \(s.casualties.formatted()) dead."))
        }
        for d in gs.shadow.deliberations where d.actor == gs.playerCountryID && d.chose == "war" {
            out.append((300 + d.estimate.capability * 100,
                        "\(GameCalendar.format(d.date)): war on \(gs.getCountry(id: d.target)?.name ?? d.target), on a reading of \(WarCouncil.pct(d.estimate.capability)) of the balance of force."))
        }
        for c in gs.shadow.casusLog where c.actor == gs.playerCountryID && !c.supported {
            out.append((260, "\(GameCalendar.format(c.date)): the case for war on \(gs.getCountry(id: c.target)?.name ?? c.target) rested on \(c.casus.title.lowercased()) that the facts did not bear out."))
        }
        for t in gs.shadow.peaceTerms where t.victor == gs.playerCountryID || t.loser == gs.playerCountryID {
            let held = t.broken ? "and it was torn up" : "and it has held so far"
            out.append((200, "\(GameCalendar.format(t.date)): terms with \(gs.getCountry(id: t.victor == gs.playerCountryID ? t.loser : t.victor)?.name ?? "?") — \(t.headline), \(held)."))
        }
        for u in gs.shadow.tacticUses where u.discovered {
            let t = DirtyTactics.tactic(u.tactic)
            out.append((240, "\(GameCalendar.format(u.date)): \(t?.name.lowercased() ?? u.tactic) was traced back to Washington."))
        }
        for o in gs.shadow.outbreaks where o.engineered && o.by == gs.playerCountryID {
            out.append((280, "\(GameCalendar.format(o.started)): a pathogen released against \(gs.getCountry(id: o.origin)?.name ?? o.origin) crossed \(o.over.count + o.waves.count) borders."))
        }
        for d in gs.shadow.claimDates.sorted(by: { $0.value < $1.value }).prefix(2) {
            out.append((120, "\(GameCalendar.format(d.value)): \(gs.getCountry(id: d.key)?.name ?? d.key) was taken."))
        }
        return out.map { (weight: $0.0, text: $0.1) }.sorted { $0.weight > $1.weight }
    }

    /// The crisis that almost happened: a government that weighed a war on us and stepped back, or a war that was
    /// abandoned before it was lost. Recorded, not invented.
    static func nearMiss(_ gs: GameState) -> String? {
        if let d = gs.shadow.deliberations.last(where: { $0.chose != "war" && $0.target == gs.playerCountryID }) {
            let who = gs.getCountry(id: d.actor)?.name ?? d.actor
            let alt = d.instruments.first { $0.id == d.chose }?.name.lowercased() ?? "something cheaper"
            return "\(GameCalendar.format(d.date)): \(who) weighed war on the United States and did not go. It put our will to fight at \(WarCouncil.pct(d.estimate.resolve)) and took \(alt) instead. Nobody in Washington ever heard about it."
        }
        if let d = gs.shadow.deliberations.last(where: { $0.chose != "war" }) {
            let who = gs.getCountry(id: d.actor)?.name ?? d.actor
            return "\(GameCalendar.format(d.date)): \(who) weighed war on \(gs.getCountry(id: d.target)?.name ?? d.target) and stepped back. The war that did not happen is the one nobody writes about."
        }
        return nil
    }

    /// What the cabinet believed, against what was true — for every war this presidency opened.
    static func beliefs(_ gs: GameState) -> [String] {
        gs.shadow.deliberations.filter { $0.actor == gs.playerCountryID || $0.target == gs.playerCountryID }.suffix(4).map { d in
            let who = gs.getCountry(id: d.actor)?.name ?? d.actor
            let whom = gs.getCountry(id: d.target)?.name ?? d.target
            let capGap = d.estimate.capability - d.truth.capability
            let resGap = d.estimate.resolve - d.truth.resolve
            var line = "\(GameCalendar.format(d.date)), \(who) against \(whom): believed \(WarCouncil.pct(d.estimate.capability)) of the balance of force — it was \(WarCouncil.pct(d.truth.capability)); believed their will to fight \(WarCouncil.pct(d.estimate.resolve)) — it was \(WarCouncil.pct(d.truth.resolve))."
            if abs(capGap) >= 0.08 || abs(resGap) >= 0.08 {
                line += " Wrong, and for reasons it had written down: " + (d.biases.isEmpty ? "thin information" : d.biases.map(\.note).joined(separator: "; ")) + "."
            } else {
                line += " Close enough."
            }
            if let r = d.recordOdds {
                line += " The record gave the side that starts such a war \(WarCouncil.pct(r))."
            }
            return line
        }
    }

    /// The whole debrief.
    static func lines(_ gs: GameState) -> [DebriefLine] {
        var out: [DebriefLine] = []
        let points = turningPoints(gs).prefix(decisions)
        out.append(DebriefLine(title: "THE DECISIONS THAT BENT IT",
                               body: points.isEmpty ? "Nothing this presidency did moved the world off its course."
                                   : points.enumerated().map { "\($0.offset + 1). \($0.element.text)" }.joined(separator: "\n")))
        out.append(DebriefLine(title: "THE CRISIS THAT ALMOST HAPPENED",
                               body: nearMiss(gs) ?? "No government weighed a war and thought better of it while you were in office."))
        let b = beliefs(gs)
        out.append(DebriefLine(title: "WHAT WE BELIEVED, AND WHAT WAS TRUE",
                               body: b.isEmpty ? "No war was weighed on paper this presidency." : b.joined(separator: "\n")))
        if !gs.shadow.doctrines.isEmpty {
            let mine = gs.shadow.doctrines.filter { $0.key.hasPrefix(gs.playerCountryID + ":") && $0.value.wins > 0 }
                .sorted { $0.value.wins > $1.value.wins }.prefix(3)
            if !mine.isEmpty {
                out.append(DebriefLine(title: "THE HABITS YOU LEFT BEHIND",
                                       body: mine.map { k, v in
                    let d = Doctrine(rawValue: String(k.split(separator: ":").last ?? "")) ?? .diplomacy
                    return "\(d.title.capitalized): \(v.wins) time\(v.wins == 1 ? "" : "s") it worked\(v.lastWinYear.map { ", last in \($0)" } ?? ""). The building will reach for it again."
                }.joined(separator: "\n")))
            }
        }
        if let trial = Consequences.trial(gs) { out.append(trial) }   // 3.36.0
        return out
    }
}

enum Legends {
    /// The chronicle of a presidency, in Markdown, from what the game recorded.
    static func markdown(_ gs: GameState) -> String {
        let me = gs.getPlayerCountry()
        var L = ["# \(me?.name ?? "The Republic"), \(GameCalendar.year(of: gs.startDate))–\(gs.currentYear)", "",
                 "*A chronicle assembled from the record of this game: \(gs.turn) turns, "
                 + "\(gs.shadow.deliberations.count) wars weighed, \(gs.shadow.casusLog.count) declared, "
                 + "\(gs.totalCasualties.formatted()) dead.*", ""]
        L += ["## The world as it stood", "",
              "- Approval: \(Int(gs.shadow.popularity.rounded()))%",
              "- Wars burning at the close: \(gs.activeWars.count)",
              "- Lands taken: \(gs.shadow.claimDates.count)",
              "- Nuclear weapons used: \(gs.nuclearStrikes.count)", ""]
        if !gs.shadow.deliberations.isEmpty {
            L += ["## Why they went", ""]
            for d in gs.shadow.deliberations.suffix(12) {
                let who = gs.getCountry(id: d.actor)?.name ?? d.actor
                let whom = gs.getCountry(id: d.target)?.name ?? d.target
                L += ["### \(who) and \(whom), \(GameCalendar.format(d.date))", "",
                      "> " + d.statement.replacingOccurrences(of: "\n", with: " "), "",
                      "- Stated reason: \(d.casus.title)\(d.chose == "war" ? "" : " — and then it did not go")",
                      "- Its test for calling it finished: \(d.doneTest.note)",
                      "- What was true: \(WarCouncil.pct(d.truth.capability)) of the balance, their will \(WarCouncil.pct(d.truth.resolve))", ""]
            }
        }
        if !gs.shadow.peaceTerms.isEmpty {
            L += ["## The peace", ""]
            for t in gs.shadow.peaceTerms.suffix(10) {
                let v = gs.getCountry(id: t.victor)?.name ?? t.victor, l = gs.getCountry(id: t.loser)?.name ?? t.loser
                L.append("- \(GameCalendar.format(t.date)), \(v) and \(l): \(t.headline). "
                         + (t.broken ? "Torn up." : String(format: "Holding at %.0f%% of its strength.", t.strength * 100)))
            }
            L.append("")
        }
        if !gs.shadow.worldAtrocities.isEmpty {
            L += ["## The record of the age", ""] + gs.shadow.worldAtrocities.suffix(10).map { "- \(GameCalendar.format($0.date)): \($0.text)" } + [""]
        }
        if !gs.shadow.tacticUses.isEmpty {
            L += ["## What was done quietly", ""]
            for u in gs.shadow.tacticUses.suffix(10) {
                let name = DirtyTactics.tactic(u.tactic)?.name ?? u.tactic
                L.append("- \(GameCalendar.format(u.date)): \(name)\(u.target.map { " against \(gs.getCountry(id: $0)?.name ?? $0)" } ?? "")\(u.discovered ? " — discovered." : ".")")
            }
            L.append("")
        }
        if !gs.shadow.outbreaks.isEmpty || gs.shadow.firedRivalries.contains(where: { $0.hasPrefix("pandemic-") }) {
            L += ["## Plague", ""]
            for o in gs.shadow.outbreaks { L.append("- \(GameCalendar.format(o.started)): \(o.name), from \(gs.getCountry(id: o.origin)?.name ?? o.origin)\(o.engineered ? " — engineered." : ".")") }
            L.append("")
        }
        L += ["## Debrief", ""]
        for d in Debrief.lines(gs) { L += ["### \(d.title.capitalized)", "", d.body, ""] }
        if !gs.novaRoast.isEmpty { L += ["## Nova's verdict", "", "> " + gs.novaRoast, ""] }
        L += ["---", "", "*Generated by Global Thermal Nuclear War. Every line above happened in this game.*"]
        return L.joined(separator: "\n")
    }
}

extension Legends {
    /// Write the chronicle beside the documents and say where it went. Nothing is written under test.
    @discardableResult
    static func export(_ gs: GameState) -> URL? {
        guard !GameStoreService.isTestOrSmokeRun else { return nil }
        #if GTNW_CORE
        return nil   // GTNWCore writes no files (WASI has none to write); a host saves `markdown(gs)` itself
        #else
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let url = dir.appendingPathComponent("GTNW-legends-\(PlayHistory.day(gs.currentDate)).md")
        guard let data = markdown(gs).data(using: .utf8), (try? data.write(to: url, options: .atomic)) != nil else { return nil }
        gs.shadow.post("The chronicle of this presidency is written to \(url.lastPathComponent).", date: gs.currentDate, severity: 1)
        return url
        #endif
    }
}

extension GameEngine {
    /// The debrief, on demand.
    func debrief() -> [DebriefLine] { gameState.map(Debrief.lines) ?? [] }

    /// Write the chronicle out, and say so in the log.
    @discardableResult
    func exportLegends() -> URL? {
        guard let gs = gameState, let url = Legends.export(gs) else { return nil }
        addLog("📜 Chronicle written to \(url.path)", type: .info)
        self.gameState = gs
        return url
    }
}
