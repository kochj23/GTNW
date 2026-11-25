//
//  LimitedStrikes.swift
//  Global Thermal Nuclear War
//
//  3.36.0: limited strikes without a declared war: a precision strike, strikes on vessels at sea, a strike on a
//  military or industrial facility, and a strike on a nuclear facility. None declares war. Each one:
//    • counts as hostilities for the War Powers Resolution (from 1973, for the United States) while the last strike
//      is under 90 days old, so the existing 60-day clock starts and runs;
//    • raises the target's posture (its alert, war support and an escalation score that adds up strike by strike
//      and cools by itself); past a threshold a nation that can fight back declares war;
//    • and from the second strike on the same nation within 180 days, Congress forces a vote on a resolution to stop
//      them. The President vetoes; two-thirds of both chambers override, and a strike after that defies Congress.
//  A strike on a nuclear facility sets the target's programme back (no warhead build-up while delayed) and risks
//  retaliation. Hit odds and the retaliation draw come from the seeded RNG; everything else is a formula.
//  Repository: https://github.com/kochj23/GTNW
//

import Foundation

enum StrikeKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case precision, boats, facility, nuclearFacility
    var id: String { rawValue }

    var title: String {
        switch self {
        case .precision: return "Precision strike"
        case .boats: return "Strike on vessels at sea"
        case .facility: return "Facility strike"
        case .nuclearFacility: return "Strike on nuclear facilities"
        }
    }

    /// Base hit odds before intelligence and air defenses.
    var baseOdds: Double {
        switch self {
        case .precision: return 0.85
        case .boats: return 0.9
        case .facility: return 0.75
        case .nuclearFacility: return 0.55
        }
    }

    /// How much one strike raises the target's escalation score (before its aggression).
    var escalation: Double {
        switch self {
        case .precision: return 20
        case .boats: return 10
        case .facility: return 30
        case .nuclearFacility: return 50
        }
    }

    /// What it costs ($B).
    var cost: Double {
        switch self {
        case .precision: return 0.3
        case .boats: return 0.1
        case .facility: return 0.6
        case .nuclearFacility: return 1.5
        }
    }

    /// Relations the target loses on a hit.
    var relationHit: Int {
        switch self {
        case .precision: return 20
        case .boats: return 10
        case .facility: return 25
        case .nuclearFacility: return 40
        }
    }
}

struct LimitedStrikeRecord: Codable, Equatable {
    var target: String
    var kind: StrikeKind
    var date: Date
    var hit: Bool
    /// Congress had authorized hostilities with the target.
    var authorized: Bool
    /// Struck after Congress overrode the President's veto.
    var defied: Bool = false
}

/// Congress's forced vote on a resolution to stop strikes on one nation.
struct StrikeVote: Codable, Equatable {
    var target: String
    var date: Date
    var houseYes: Int
    var senateYes: Int
    var passed: Bool
    var overridden: Bool
}

/// A nuclear programme set back by a strike: no build-up for `days` from `from`.
struct ProgramDelay: Codable, Equatable {
    var from: Date
    var days: Int
}

enum LimitedStrikes {
    /// A strike counts as hostilities for this many days.
    static let hostilityDays = 90
    /// Strikes on one nation within this many days add up for Congress.
    static let windowDays = 180
    /// Escalation at which a nation that can fight back declares war.
    static let warThreshold = 100.0
    /// Escalation cools by this much a month.
    static let coolingPerMonth = 15.0
    /// A nuclear facility strike sets the programme back this many days.
    static let programDelayDays = 730

    /// The yes share for a resolution to stop the strikes: the complement of what an authorization would get.
    static func restraintYes(authorizationYes: Double) -> Int { Int(min(95, max(5, 100 - authorizationYes)).rounded()) }
}

// MARK: - Engine

extension GameEngine {

    /// The hit odds the Situation Room shows for a strike.
    func strikeOdds(_ target: String, kind: StrikeKind) -> Double {
        guard let gs = gameState, let t = gs.getCountry(id: target) else { return 0 }
        let intel = IntelligenceModel.confidence(year: gs.currentYear, recon: hasSatellite(.recon))
        var p = kind.baseOdds + (intel - 0.6) * 0.5
        p -= kind == .boats ? Double(t.navalForces) / 800 : Double(t.airForces) / 500
        return (PowerPlay.unit(max(0.1, min(0.95, p))) * 100).rounded() / 100
    }

    /// Does the target have a nuclear programme to strike?
    func hasNuclearProgram(_ c: Country) -> Bool { c.nuclearStatus != .none || c.nuclearWarheads > 0 }

    /// Is the nation's nuclear programme set back by a strike right now?
    func nuclearProgramDelayed(_ id: String) -> Bool {
        guard let gs = gameState, let d = gs.shadow.powerPlays.programDelays[id] else { return false }
        return GameCalendar.days(from: d.from, to: gs.currentDate) < d.days
    }

    func strikeProblem(_ target: String, kind: StrikeKind) -> String? {
        guard let gs = gameState, let me = gs.getPlayerCountry() else { return "No game." }
        if gs.gameOver { return "The game is over." }
        if gs.actionsRemaining < 1 { return "No actions left." }
        guard let t = gs.getCountry(id: target), !t.isDestroyed else { return "No nation to strike." }
        if t.id == me.id || t.territoryOf == me.id { return "That is your own." }
        if me.atWarWith.contains(t.id) { return "You are at war with \(t.name): use the war orders, not a limited strike." }
        switch kind {
        case .boats:
            if gs.currentYear < 1900 { return "No navy strikes vessels that way before 1900." }
            if NavalModel.isLandlocked(t.id) { return "\(t.name) is landlocked: no vessels at sea to strike." }
            if me.navalForces < 1 { return "You have no navy." }
        case .precision, .facility, .nuclearFacility:
            if !PresidentialAction.airStrike.isAvailable(on: gs.currentDate, in: gs) || AttackSizing.available(.aircraft, in: gs) < 1 {
                return gs.currentYear < 1914 ? "No air arm in \(gs.currentYear): military aviation begins in 1914." : "No aircraft available."
            }
            if kind == .nuclearFacility {
                if gs.currentYear < 1945 { return "No nation has a nuclear programme before 1945." }
                if !hasNuclearProgram(t) { return "\(t.name) has no nuclear programme to strike." }
            }
        }
        return nil
    }

    /// Strikes on a nation within the window (limited strikes and capture raids alike).
    func recentStrikes(on target: String, days: Int = LimitedStrikes.windowDays) -> [LimitedStrikeRecord] {
        guard let gs = gameState else { return [] }
        let raids = gs.shadow.powerPlays.raids.filter { $0.target == target }.map {
            LimitedStrikeRecord(target: $0.target, kind: .precision, date: $0.date, hit: $0.outcome == .captured, authorized: false)
        }
        return (gs.shadow.powerPlays.strikes.filter { $0.target == target } + raids)
            .filter { GameCalendar.days(from: $0.date, to: gs.currentDate) < days }
    }

    /// Nations under limited strikes or raids recent enough to count as hostilities (for the War Powers clock).
    func limitedStrikeHostilities() -> Set<String> {
        guard let gs = gameState else { return [] }
        let all = gs.shadow.powerPlays.strikes.map { ($0.target, $0.date) } + gs.shadow.powerPlays.raids.map { ($0.target, $0.date) }
        return Set(all.filter { GameCalendar.days(from: $0.1, to: gs.currentDate) < LimitedStrikes.hostilityDays }.map(\.0))
    }

    /// The cabinet's read-out on a strike, before EXECUTE.
    func rawStrikeWarnings(_ target: String, kind: StrikeKind) -> [AdvisorWarning] {   // 3.37.0: see Regime.swift
        guard let gs = gameState, let t = gs.getCountry(id: target) else { return [] }
        let odds = strikeOdds(target, kind: kind)
        let esc = (gs.shadow.powerPlays.escalation[target] ?? 0) + kind.escalation * (0.5 + Double(t.aggressionLevel) / 100)
        var jcs = "Hit odds \(Int(odds * 100))%."
        var jl = odds < 0.5 ? 1 : 0
        if kind == .nuclearFacility {
            jcs += " Sets the programme back about two years. Expect them to hit back."
            jl = t.nuclearWarheads > 0 ? 2 : 1
        }
        if esc >= LimitedStrikes.warThreshold && t.militaryStrength >= 20 {
            jcs += " This one could push \(t.name) into war."
            jl = 2
        }
        var law = "No declaration of war. "
        var ll = 0
        if gs.playerCountryID == "USA" && gs.currentDate >= CongressModel.warPowersResolution && !isAuthorized(target) {
            let n = recentStrikes(on: target).count + 1
            law += "Congress has not authorized force against \(t.name): it counts as hostilities under the War Powers Resolution."
            if n >= 2 { law += " A second strike in six months forces a vote in Congress to stop them." }
            ll = 1
        } else {
            law += gs.currentYear >= 1945 ? "The UN Charter allows force in self-defense; other capitals will ask what this one is." : "The law of nations of the day asks little."
        }
        if gs.shadow.powerPlays.strikeBans.contains(target) {
            law = "Congress overrode your veto and ordered these strikes stopped. Another one defies Congress."
            ll = 2
        }
        let state = AdvisorWarning(who: powerPlayStateWho, text: "\(t.name) will put its forces on alert; relations −\(kind.relationHit).", level: kind == .nuclearFacility ? 2 : 1)
        return [AdvisorWarning(who: "Joint Chiefs", text: jcs, level: jl),
                AdvisorWarning(who: PowerPlay.counsel, text: law, level: ll),
                state,
                powerPlayPolitics(dPop: kind == .nuclearFacility ? -3 : -1, dRuth: kind == .nuclearFacility ? 6 : 2, hostilities: target)]
    }

    /// Carry out a limited strike (one action). Returns whether it hit (nil if it could not be ordered).
    @discardableResult
    func limitedStrike(_ target: String, kind: StrikeKind, roll: Double? = nil) -> Bool? {
        guard strikeProblem(target, kind: kind) == nil, let gs = gameState, let ti = gs.countries.firstIndex(where: { $0.id == target }),
              let pi = gs.countries.firstIndex(where: { $0.id == gs.playerCountryID }) else { return nil }
        let odds = strikeOdds(target, kind: kind)
        powerPlayConsequences(target, how: "strikes")
        let hit = (roll ?? gameRoll()) < odds
        let name = gs.countries[ti].name
        let authorized = isAuthorized(target)
        let defied = gs.shadow.powerPlays.strikeBans.contains(target) && !authorized
        gs.flash([gs.playerCountryID, target], .hostile, "\(gs.countries[pi].name): \(kind.title) → \(name)")
        spendFunds(kind.cost)
        if hit {
            switch kind {
            case .precision:
                gs.countries[ti].militaryStrength = max(1, gs.countries[ti].militaryStrength - 2)
                gs.countries[ti].damageLevel = min(100, gs.countries[ti].damageLevel + 1)
                gs.shadow.post("A precision strike hits military targets in \(name). No declaration of war.", date: gs.currentDate, severity: 2)
            case .boats:
                gs.countries[ti].navalForces = max(0, gs.countries[ti].navalForces - 1)
                gs.shadow.post("Vessels from \(name) are destroyed at sea in a strike ordered by the President.", date: gs.currentDate, severity: 2)
            case .facility:
                gs.countries[ti].militaryStrength = max(1, gs.countries[ti].militaryStrength - 3)
                gs.countries[ti].economicStrength = max(1, gs.countries[ti].economicStrength - 2)
                gs.countries[ti].damageLevel = min(100, gs.countries[ti].damageLevel + 2)
                gs.shadow.post("A strike destroys a military facility in \(name).", date: gs.currentDate, severity: 2)
            case .nuclearFacility:
                let lost = min(20, gs.countries[ti].nuclearWarheads / 10)
                gs.countries[ti].nuclearWarheads -= lost
                gs.countries[ti].damageLevel = min(100, gs.countries[ti].damageLevel + 2)
                gs.shadow.powerPlays.programDelays[target] = ProgramDelay(from: gs.currentDate, days: LimitedStrikes.programDelayDays)
                gs.shadow.post("Strikes hit \(name)'s nuclear facilities. Its programme is set back by about two years.", date: gs.currentDate, severity: 3)
            }
        } else {
            gs.shadow.post("A \(kind.title.lowercased()) on \(name) misses its targets.", date: gs.currentDate, severity: 1)
        }
        addLog("🎯 \(kind.title.uppercased()) — \(name): \(hit ? "on target" : "missed").", type: hit ? .info : .warning)
        // Their posture: alert, war support, aggression, and the escalation that adds up.
        let t = gs.countries[ti]
        let add = kind.escalation * (0.5 + Double(t.aggressionLevel) / 100) * (hit ? 1 : 0.5)
        gs.shadow.powerPlays.escalation[target, default: 0] += (add * 10).rounded() / 10
        gs.countries[ti].warSupport = min(100, gs.countries[ti].warSupport + 10)
        gs.countries[ti].aggressionLevel = min(100, gs.countries[ti].aggressionLevel + 3)
        gs.countries[ti].profile.anxieties.military = min(100, gs.countries[ti].profile.anxieties.military + 20)
        if defied {
            gs.countries[pi].congressionalSupport = max(0, gs.countries[pi].congressionalSupport - 10)
            gs.shadow.ruthlessness += 10
            gs.shadow.post("The President strikes \(name) again in defiance of Congress.", date: gs.currentDate, severity: 3)
        }
        gs.shadow.powerPlays.strikes.append(LimitedStrikeRecord(target: target, kind: kind, date: gs.currentDate, hit: hit,
                                                                authorized: authorized, defied: defied))
        self.gameState = gs
        modifyDiplomaticRelation(from: target, to: gs.playerCountryID, by: -(hit ? kind.relationHit : kind.relationHit / 2))
        modifyDiplomaticRelation(from: gs.playerCountryID, to: target, by: -5)
        if kind == .nuclearFacility {
            for c in gs.countries where !c.isDestroyed && !c.isTerritory && c.id != gs.playerCountryID && c.id != target
                && c.alliances.contains(target) { modifyDiplomaticRelation(from: c.id, to: gs.playerCountryID, by: -10) }
        }
        recordPlayerAction(rung: .military, hostile: true, detected: false)
        logPlayEvent("limited_strike", detail: ["target": target, "kind": kind.rawValue, "hit": hit, "odds": PlayHistory.num(odds, places: 100),
                                                "authorized": authorized, "defied": defied, "game_date": PlayHistory.day(gs.currentDate)])
        if kind == .nuclearFacility { nuclearFacilityRetaliation(target) }
        checkStrikeEscalation(target)
        completePlayerAction()
        return hit
    }

    /// After a nuclear facility strike: the target may hit back (the seeded RNG; likelier for an aggressive nation
    /// and one with weapons).
    func nuclearFacilityRetaliation(_ target: String, roll: Double? = nil) {
        guard let gs = gameState, let t = gs.getCountry(id: target), let pi = gs.countries.firstIndex(where: { $0.id == gs.playerCountryID }) else { return }
        let p = min(0.9, 0.2 + Double(t.aggressionLevel) / 200 + (t.nuclearWarheads > 0 ? 0.3 : 0))
        guard (roll ?? gameRoll()) < p else { return }
        if t.militaryStrength >= 20 {
            gs.shadow.post("\(t.name) retaliates for the strike on its nuclear facilities and declares war.", date: gs.currentDate, severity: 3)
            self.gameState = gs
            declareWar(aggressor: target, defender: gs.playerCountryID)
        } else {
            gs.countries[pi].damageLevel = min(100, gs.countries[pi].damageLevel + 1)
            gs.shadow.popularity = PopularityModel.clamp(gs.shadow.popularity - 3)
            gs.shadow.post("\(t.name) strikes back at our forces in the region. Casualties are reported.", date: gs.currentDate, severity: 3)
            self.gameState = gs
        }
    }

    /// Past the threshold a nation that can fight declares war; one that can't appeals to the world.
    func checkStrikeEscalation(_ target: String) {
        guard let gs = gameState, let t = gs.getCountry(id: target), !t.atWarWith.contains(gs.playerCountryID),
              (gs.shadow.powerPlays.escalation[target] ?? 0) >= LimitedStrikes.warThreshold else { return }
        gs.shadow.powerPlays.escalation[target] = 0
        if t.militaryStrength >= 20 {
            gs.shadow.post("The strikes add up: \(t.name) declares war.", date: gs.currentDate, severity: 3)
            self.gameState = gs
            declareWar(aggressor: target, defender: gs.playerCountryID)
        } else {
            gs.shadow.post("\(t.name) cannot answer the strikes in kind and appeals to the world. Capitals condemn them.", date: gs.currentDate, severity: 2)
            self.gameState = gs
            for c in gs.countries where !c.isDestroyed && !c.isTerritory && c.id != gs.playerCountryID && c.id != target
                && !c.alliances.contains(gs.playerCountryID) { modifyDiplomaticRelation(from: c.id, to: gs.playerCountryID, by: -3) }
        }
    }

    /// Each turn: escalation cools, delays run out, and Congress may force a vote.
    func processLimitedStrikes() {
        guard let gs = gameState else { return }
        let cool = LimitedStrikes.coolingPerMonth * gs.scale.yearFraction * 12
        for (k, v) in gs.shadow.powerPlays.escalation.sorted(by: { $0.key < $1.key }) {
            let n = v - cool
            gs.shadow.powerPlays.escalation[k] = n > 0 ? (n * 10).rounded() / 10 : nil
        }
        for (k, d) in gs.shadow.powerPlays.programDelays.sorted(by: { $0.key < $1.key }) where GameCalendar.days(from: d.from, to: gs.currentDate) >= d.days {
            gs.shadow.powerPlays.programDelays[k] = nil
        }
        self.gameState = gs
        guard gs.playerCountryID == "USA", gs.currentDate >= CongressModel.warPowersResolution else { return }
        let struck = Set(gs.shadow.powerPlays.strikes.map(\.target) + gs.shadow.powerPlays.raids.map(\.target)).sorted()
        for t in struck where !isAuthorized(t) && recentStrikes(on: t).count >= 2 {
            let voted = gs.shadow.powerPlays.strikeVotes.contains { $0.target == t && GameCalendar.days(from: $0.date, to: gs.currentDate) < LimitedStrikes.windowDays }
            if !voted, !(gs.getPlayerCountry()?.atWarWith.contains(t) ?? true) { forceStrikeVote(t) }
        }
    }

    /// Congress votes on a resolution to stop the strikes on `target`. Deterministic: the yes share is what an
    /// authorization would not get; the President vetoes; two-thirds of both chambers override.
    @discardableResult
    func forceStrikeVote(_ target: String) -> StrikeVote? {
        guard let gs = gameState, let o = authorizationOdds(target: target, kind: .useOfForce),
              let pi = gs.countries.firstIndex(where: { $0.id == gs.playerCountryID }) else { return nil }
        let h = LimitedStrikes.restraintYes(authorizationYes: o.house), s = LimitedStrikes.restraintYes(authorizationYes: o.senate)
        let passed = h > 50 && s > 50
        let overridden = passed && h >= 67 && s >= 67
        let v = StrikeVote(target: target, date: gs.currentDate, houseYes: h, senateYes: s, passed: passed, overridden: overridden)
        gs.shadow.powerPlays.strikeVotes.append(v)
        let name = gs.getCountry(id: target)?.name ?? target
        if overridden {
            gs.shadow.powerPlays.strikeBans.insert(target)
            gs.countries[pi].congressionalSupport = max(0, gs.countries[pi].congressionalSupport - 5)
            gs.shadow.post("Congress overrides the President's veto: no more strikes on \(name) without its authorization (House \(h)%, Senate \(s)%).",
                           date: gs.currentDate, severity: 3)
        } else if passed {
            gs.shadow.popularity = PopularityModel.clamp(gs.shadow.popularity - 2)
            gs.shadow.post("Congress passes a resolution to stop the strikes on \(name) (House \(h)%, Senate \(s)%). The President vetoes it; the veto holds.",
                           date: gs.currentDate, severity: 2)
        } else {
            gs.shadow.post("Congress votes down a resolution to stop the strikes on \(name) (House \(h)%, Senate \(s)%).", date: gs.currentDate, severity: 1)
        }
        logPlayEvent("strike_vote", detail: ["target": target, "house_yes": h, "senate_yes": s, "passed": passed, "overridden": overridden,
                                             "game_date": PlayHistory.day(gs.currentDate)])
        self.gameState = gs
        return v
    }
}
