//
//  Settlements.swift
//  Global Thermal Nuclear War
//
//  3.32.2: the peace, modelled as carefully as the campaign. A war that ends leaves a piece of paper, and the paper
//  says what was kept, what was paid, what was promised and for how long:
//    • territory transferred to the victor,
//    • an indemnity paid in instalments out of the loser's output,
//    • demilitarization — a cap on the loser's forces for a stated term,
//    • an alliance term binding the loser to the victor,
//    • and a term of years the signatories meant it to hold.
//  Then it is kept, or it erodes. Each turn the instalments are paid and the cap enforced; as the loser recovers,
//  as the years run and as unrest grows, the paper weakens, and a treaty can be repudiated — which costs the
//  breaker its standing everywhere and can put the two back at war. Terms are built on top of the existing
//  terms-of-surrender flow (PostWarSettlement) and the war-termination test (WarCouncil), not beside it.
//  Shares, erosion rates and durations are design choices.
//  Repository: https://github.com/kochj23/GTNW
//

import Foundation

/// The paper a war leaves behind.
struct PeaceTerms: Codable, Identifiable, Hashable {
    var id = UUID()
    var victor: String
    var loser: String
    var date: Date
    /// Lands and territories that changed hands.
    var territory: [String] = []
    /// Billions still owed, and the instalment due each year.
    var indemnityOwed: Double = 0
    var indemnityPerYear: Double = 0
    /// The cap on the loser's forces (1…100) and the date it lapses.
    var forceCap: Int?
    var capUntil: Date?
    /// The loser is bound to the victor.
    var alliance = false
    /// The years the signatories meant it to hold, and how well it is holding (0…1).
    var years: Double
    var strength: Double = 1
    var broken = false
    /// Whether the war it ended was settled at the table rather than in a capital.
    var negotiated: Bool

    var headline: String {
        var parts: [String] = []
        if !territory.isEmpty { parts.append("\(territory.count) territor\(territory.count == 1 ? "y" : "ies") ceded") }
        if indemnityPerYear > 0 { parts.append(String(format: "$%.1fB a year in reparations", indemnityPerYear)) }
        if forceCap != nil { parts.append("forces capped") }
        if alliance { parts.append("bound in alliance") }
        return parts.isEmpty ? "a peace without terms" : parts.joined(separator: ", ")
    }
}

enum Settlements {
    /// How long the paper is meant to hold, by era (design choices: a dynastic peace was meant to last a reign, a
    /// modern armistice a decade).
    static func termYears(year: Int) -> Double { year < 1900 ? 30 : (year < 1945 ? 20 : 10) }

    /// An indemnity: a share of the loser's yearly output, by how badly it lost.
    static func indemnity(loser: Country, momentum: Double, year: Int) -> (total: Double, perYear: Double) {
        let share = min(0.3, max(0.02, 0.05 + 0.2 * max(0, momentum)))
        let total = max(0.1, loser.gdp * 1000 * share)
        let years = max(2.0, min(10, termYears(year: year) / 3))
        return (total, total / years)
    }

    /// A cap on the beaten army: harsher the more decisive the defeat.
    static func forceCap(loser: Country, momentum: Double) -> Int {
        max(5, Int((Double(loser.militaryStrength) * (1 - min(0.6, 0.25 + 0.35 * max(0, momentum)))).rounded()))
    }

    /// How the paper weakens in a turn: the years running out, the loser's recovery, its unrest, and a cap it
    /// resents. 0…1 of strength lost a year.
    static func erosion(_ t: PeaceTerms, loser: Country, year: Int) -> Double {
        var e = 1 / max(2, t.years)                                   // time alone
        e += Double(max(0, loser.militaryStrength - (t.forceCap ?? 100))) / 500   // an army rebuilt past its cap
        e += loser.profile.outcry / 1200                               // a population that will not have it
        if t.indemnityOwed > 0 { e += 0.04 }                           // every instalment is a reminder
        if !t.territory.isEmpty { e += 0.03 }                          // and so is a lost province
        return min(0.6, e)
    }

    /// Chance a year that a weakened treaty is repudiated outright.
    static func breakChance(_ t: PeaceTerms, loser: Country) -> Double {
        guard !t.broken else { return 0 }
        let weak = 1 - t.strength
        return min(0.5, weak * weak * (0.3 + Double(loser.profile.ambition) / 20))
    }
}

extension GameEngine {
    /// Write the terms a settlement leaves behind. Called wherever a war ends: a victory in a capital, or a war
    /// that met the test it declared and went to the table.
    @discardableResult
    func writePeaceTerms(victor: String, loser: String, negotiated: Bool, territory: [String] = [],
                         alliance: Bool = false) -> PeaceTerms? {
        guard let gs = gameState, let l = gs.getCountry(id: loser), gs.getCountry(id: victor) != nil,
              !gs.shadow.peaceTerms.contains(where: { $0.victor == victor && $0.loser == loser && !$0.broken }) else { return nil }
        let front = gs.shadow.fronts.last { ($0.attacker == victor && $0.defender == loser) || ($0.attacker == loser && $0.defender == victor) }
        let momentum = front.map { $0.attacker == victor ? $0.attackerMomentum : -$0.attackerMomentum } ?? 0
        let money = Settlements.indemnity(loser: l, momentum: momentum, year: gs.currentYear)
        var t = PeaceTerms(victor: victor, loser: loser, date: gs.currentDate, territory: territory,
                           indemnityOwed: negotiated ? money.total * 0.5 : money.total,
                           indemnityPerYear: (negotiated ? money.total * 0.5 : money.total) / max(2, Settlements.termYears(year: gs.currentYear) / 3),
                           years: Settlements.termYears(year: gs.currentYear), negotiated: negotiated)
        if !negotiated || momentum > 0.3 {
            t.forceCap = Settlements.forceCap(loser: l, momentum: momentum)
            t.capUntil = GameCalendar.calendar.date(byAdding: .year, value: Int(t.years), to: gs.currentDate)
        }
        t.alliance = alliance
        gs.shadow.peaceTerms.append(t)
        if gs.shadow.peaceTerms.count > 40 { gs.shadow.peaceTerms.removeFirst() }
        gs.shadow.post("Terms between \(gs.getCountry(id: victor)?.name ?? victor) and \(l.name): \(t.headline).",
                       date: gs.currentDate, severity: 2)
        gs.shadow.logWar("\(GameCalendar.format(gs.currentDate)): terms signed — \(t.headline).")
        logPlayEvent("peace_terms", detail: ["victor": victor, "loser": loser, "negotiated": negotiated,
                                            "indemnity_b": PlayHistory.num(t.indemnityOwed),
                                            "force_cap": t.forceCap ?? 0, "territory": t.territory.count,
                                            "game_date": PlayHistory.day(gs.currentDate)])
        self.gameState = gs
        return t
    }

    /// Each turn: instalments paid, caps enforced, paper weakened, and sometimes torn up.
    func processPeaceTerms(breakRoll: Double? = nil) {
        guard let gs = gameState else { return }
        let yearFraction = gs.turnLength.yearFraction
        for k in gs.shadow.peaceTerms.indices.reversed() where !gs.shadow.peaceTerms[k].broken {
            var t = gs.shadow.peaceTerms[k]
            guard let li = gs.countries.firstIndex(where: { $0.id == t.loser }),
                  let vi = gs.countries.firstIndex(where: { $0.id == t.victor }) else { continue }
            // Reparations, out of the loser's output and into the victor's.
            if t.indemnityOwed > 0 {
                let due = min(t.indemnityOwed, t.indemnityPerYear * yearFraction)
                t.indemnityOwed -= due
                gs.countries[li].gdp = max(0.001, gs.countries[li].gdp - due / 1000)
                gs.countries[vi].gdp += due / 1000
                if t.loser == gs.playerCountryID { gs.shadow.popularity = PopularityModel.clamp(gs.shadow.popularity - 0.3 * yearFraction) }
                if t.indemnityOwed <= 0 {
                    gs.shadow.post("\(gs.countries[li].name) pays the last of its reparations to \(gs.countries[vi].name).",
                                   date: gs.currentDate, severity: 1)
                }
            }
            // The cap on the beaten army, while the paper holds.
            if let cap = t.forceCap, let until = t.capUntil {
                if gs.currentDate >= until {
                    t.forceCap = nil
                    t.capUntil = nil
                    gs.shadow.post("The limits on \(gs.countries[li].name)'s forces lapse.", date: gs.currentDate, severity: 1)
                } else if gs.countries[li].militaryStrength > cap, t.strength > 0.4 {
                    gs.countries[li].militaryStrength = cap
                }
            }
            t.strength = max(0, t.strength - Settlements.erosion(t, loser: gs.countries[li], year: gs.currentYear) * yearFraction)
            let roll = breakRoll ?? Double.random(in: 0..<1, using: &gs.rng)
            if roll < gs.scale.probability(annual: Settlements.breakChance(t, loser: gs.countries[li])) {
                t.broken = true
                t.forceCap = nil
                let ln = gs.countries[li].name, vn = gs.countries[vi].name
                gs.shadow.peaceTerms[k] = t
                self.gameState = gs
                gs.shadow.post("\(ln) repudiates the terms it signed with \(vn).", date: gs.currentDate, severity: 3)
                gs.shadow.logWar("\(GameCalendar.format(gs.currentDate)): \(ln) tears up the treaty of \(GameCalendar.format(t.date)).")
                modifyDiplomaticRelation(from: t.victor, to: t.loser, by: -40)
                for o in gs.countries where o.id != t.loser && !o.isDestroyed && !o.isTerritory {
                    modifyDiplomaticRelation(from: o.id, to: t.loser, by: -8)
                }
                if t.loser == gs.playerCountryID { gs.shadow.ruthlessness += 8 }
                logPlayEvent("peace_terms_broken", detail: ["victor": t.victor, "loser": t.loser,
                                                            "years_held": PlayHistory.num(Double(GameCalendar.days(from: t.date, to: gs.currentDate)) / 365.25),
                                                            "game_date": PlayHistory.day(gs.currentDate)])
                continue
            }
            gs.shadow.peaceTerms[k] = t
        }
        self.gameState = gs
    }

    /// The paper that is still holding between two nations, if any.
    func peaceTerms(between a: String, and b: String) -> PeaceTerms? {
        gameState?.shadow.peaceTerms.last { !$0.broken && (($0.victor == a && $0.loser == b) || ($0.victor == b && $0.loser == a)) }
    }
}
