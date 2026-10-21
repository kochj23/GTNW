//
//  CongressModel.swift
//  Global Thermal Nuclear War
//
//  Congress and the war powers (3.8.0). Support is shown by chamber; the President can ask Congress for a declaration
//  of war or an authorization to use military force, and both chambers vote with odds from their support, the
//  public's war support and the casus belli. From the War Powers Resolution (7 Nov 1973) unauthorized hostilities
//  start a 60-day clock (plus 30 days to withdraw). Impeachment ends in a Senate trial that needs two-thirds to convict.
//  Encyclopedia level: party control isn't modelled; support stands in for it.
//  Repository: https://github.com/kochj23/GTNW
//

import Foundation

enum WarAuthorizationKind: String, Codable, CaseIterable, Identifiable {
    case declaration, useOfForce
    var id: String { rawValue }
    var title: String { self == .declaration ? "Declaration of War" : "Authorization for Use of Military Force" }
    /// An authorization is narrower and easier to pass than a declaration.
    var bonus: Double { self == .declaration ? 0 : 8 }
}

/// One vote of Congress on the President's request.
struct WarAuthorization: Codable, Hashable, Identifiable {
    var id = UUID()
    var target: String
    var kind: WarAuthorizationKind
    var date: Date
    var passed: Bool
    /// Share of members voting yes, %.
    var houseYes: Int
    var senateYes: Int
}

/// Unauthorized hostilities under the War Powers Resolution. `warned` counts the warnings already given.
struct WarPowersClock: Codable, Hashable {
    var target: String
    var started: Date
    var warned = 0
}

enum CongressModel {
    /// War Powers Resolution passed over President Nixon's veto, 7 Nov 1973.
    static let warPowersResolution = GameCalendar.date(year: 1973, month: 11, day: 7)
    static let clockDays = 60
    static let withdrawalDays = 30

    /// Support for the President by chamber, 0…100: the House follows the public more, the Senate less.
    static func house(congress: Int, popularity: Double) -> Double { clamp(0.5 * Double(congress) + 0.5 * popularity) }
    static func senate(congress: Int, popularity: Double) -> Double { clamp(0.7 * Double(congress) + 0.3 * popularity) }

    /// Casus belli 0…1: the target is already fighting the U.S., has struck it with nuclear weapons, is at war with a
    /// U.S. ally, or is plainly hostile.
    static func casusBelli(target: Country, player: Country, gs: GameState) -> Double {
        var c = 0.0
        if target.atWarWith.contains(player.id) && gs.activeWars.contains(where: { $0.aggressor == target.id && $0.defender == player.id }) { c += 0.7 }
        if gs.nuclearStrikes.contains(where: { $0.attacker == target.id && $0.target == player.id }) { c += 1 }
        if target.atWarWith.contains(where: { player.alliances.contains($0) }) { c += 0.4 }
        if (player.diplomaticRelations[target.id] ?? 0) < -60 { c += 0.2 }
        return min(1, c)
    }

    /// Percentage of a chamber expected to vote yes.
    static func expectedYes(support: Double, warSupport: Int, casusBelli: Double, kind: WarAuthorizationKind) -> Double {
        min(95, max(5, 0.5 * support + 0.3 * Double(warSupport) + 30 * casusBelli + kind.bonus + 5))
    }

    /// Chance a chamber passes it (votes swing about ±8 points around the expectation).
    static func passOdds(expectedYes e: Double) -> Double { min(1, max(0, (e - 42) / 16)) }

    /// A two-thirds Senate vote convicts: only if the President's Senate support has fallen below a third.
    static func convicts(senateSupport: Double) -> Bool { senateSupport < 34 }

    /// Where congressional support drifts each month: up with approval, down with outrage.
    static func congressTarget(popularity: Double, ruthlessness: Double) -> Double { clamp(30 + 0.5 * popularity - 0.2 * ruthlessness) }

    static func clamp(_ v: Double) -> Double { min(100, max(0, v)) }

    /// Stage names for the visible impeachment process.
    static func impeachmentStageName(_ stage: Int) -> String {
        switch stage {
        case 0: return "NONE"
        case 1: return "INQUIRY"
        case 2: return "ARTICLES DRAFTED"
        case 3: return "IMPEACHED · SENATE TRIAL NEXT"
        default: return "REMOVED"
        }
    }
}

// MARK: - Engine

extension GameEngine {
    /// Odds both chambers pass a request against `target`, and the expected yes shares.
    func authorizationOdds(target: String, kind: WarAuthorizationKind) -> (odds: Double, house: Double, senate: Double, casusBelli: Double)? {
        guard let gs = gameState, let p = gs.getPlayerCountry(), let t = gs.getCountry(id: target), t.id != p.id else { return nil }
        // 3.17.4: a manufactured pretext Congress has not seen through counts too.
        let cb = min(1, CongressModel.casusBelli(target: t, player: p, gs: gs) + pretextBonus(target))
        let h = CongressModel.expectedYes(support: CongressModel.house(congress: p.congressionalSupport, popularity: gs.shadow.popularity),
                                          warSupport: p.warSupport, casusBelli: cb, kind: kind)
        let s = CongressModel.expectedYes(support: CongressModel.senate(congress: p.congressionalSupport, popularity: gs.shadow.popularity),
                                          warSupport: p.warSupport, casusBelli: cb, kind: kind)
        return (CongressModel.passOdds(expectedYes: h) * CongressModel.passOdds(expectedYes: s), h, s, cb)
    }

    /// Has Congress authorized hostilities against `target` (a passed declaration or authorization)?
    func isAuthorized(_ target: String) -> Bool {
        gameState?.shadow.authorizations.contains { $0.target == target && $0.passed } ?? false
    }

    /// Ask Congress (one action). The chambers vote at once; `roll` (0..<1) is for tests. Returns the vote.
    @discardableResult
    func requestAuthorization(target: String, kind: WarAuthorizationKind, roll: Double = Double.random(in: 0..<1)) -> WarAuthorization? {
        guard let gs = gameState, gs.playerCountryID == "USA", gs.actionsRemaining > 0, !isAuthorized(target),
              let o = authorizationOdds(target: target, kind: kind), let pi = gs.countries.firstIndex(where: { $0.id == gs.playerCountryID }) else { return nil }
        let swing = (roll - 0.5) * 16   // the same ±8 points the odds assume
        let houseYes = Int(min(99, max(1, o.house + swing)).rounded()), senateYes = Int(min(99, max(1, o.senate + swing)).rounded())
        let passed = roll < o.odds
        // The tally agrees with the result: both chambers over half when it passes, the weaker one under half when not.
        let houseWeaker = houseYes <= senateYes
        let v = WarAuthorization(target: target, kind: kind, date: gs.currentDate, passed: passed,
                                 houseYes: passed ? max(51, houseYes) : (houseWeaker ? min(49, houseYes) : houseYes),
                                 senateYes: passed ? max(51, senateYes) : (houseWeaker ? senateYes : min(49, senateYes)))
        gs.shadow.authorizations.append(v)
        let name = gs.getCountry(id: target)?.name ?? target
        if passed {
            gs.countries[pi].warSupport = min(100, gs.countries[pi].warSupport + 10)
            gs.countries[pi].congressionalSupport = min(100, gs.countries[pi].congressionalSupport + 2)
            gs.shadow.popularity = PopularityModel.clamp(gs.shadow.popularity + 3)
            gs.shadow.warPowersClocks.removeValue(forKey: target)
            gs.shadow.post("Congress passes a \(kind.title.lowercased()) against \(name) (House \(v.houseYes)%, Senate \(v.senateYes)%).",
                           date: gs.currentDate, severity: 2)
        } else {
            gs.countries[pi].congressionalSupport = max(0, gs.countries[pi].congressionalSupport - 5)
            gs.shadow.popularity = PopularityModel.clamp(gs.shadow.popularity - 3)
            gs.shadow.post("Congress rejects the President's request for a \(kind.title.lowercased()) against \(name).", date: gs.currentDate, severity: 2)
        }
        logPlayEvent("congress_vote", detail: ["target": target, "target_name": PlayHistory.text(name), "kind": kind.rawValue, "passed": passed,
                                               "house_yes": v.houseYes, "senate_yes": v.senateYes, "odds": PlayHistory.num(o.odds, places: 100),
                                               "game_date": PlayHistory.day(gs.currentDate)])
        self.gameState = gs
        completePlayerAction()
        return v
    }

    /// Enemies the U.S. is in hostilities with by its own choice: wars it started, and fronts where U.S. troops fight.
    func hostilitiesTargets() -> Set<String> {
        guard let gs = gameState else { return [] }
        let p = gs.playerCountryID
        var out = Set(gs.activeWars.filter { $0.aggressor == p }.map(\.defender))
        for f in gs.shadow.fronts where f.status == .fighting && f.usSide != nil && f.attacker != p && f.defender != p {
            out.insert(f.usSide == f.attacker ? f.defender : f.attacker)
        }
        return out
    }

    /// Each turn (from Nov 1973): start, advance and enforce the War Powers clock on unauthorized hostilities.
    func processWarPowers() {
        guard let gs = gameState, gs.playerCountryID == "USA", gs.currentDate >= CongressModel.warPowersResolution,
              let pi = gs.countries.firstIndex(where: { $0.id == gs.playerCountryID }) else { return }
        let targets = hostilitiesTargets().filter { !isAuthorized($0) }
        for key in gs.shadow.warPowersClocks.keys where !targets.contains(key) { gs.shadow.warPowersClocks.removeValue(forKey: key) }
        for t in targets {
            let name = gs.getCountry(id: t)?.name ?? t
            guard var clock = gs.shadow.warPowersClocks[t] else {
                gs.shadow.warPowersClocks[t] = WarPowersClock(target: t, started: gs.currentDate)
                gs.shadow.post("War Powers Resolution: hostilities with \(name) without authorization. Congress has 60 days to authorize them.",
                               date: gs.currentDate, severity: 2)
                continue
            }
            let days = GameCalendar.days(from: clock.started, to: gs.currentDate)
            if days >= 45 && clock.warned < 1 {
                clock.warned = 1
                gs.shadow.post("War Powers: \(max(0, CongressModel.clockDays - days)) days left to win authorization for \(name), or begin withdrawal.",
                               date: gs.currentDate, severity: 3)
            }
            if days >= CongressModel.clockDays && clock.warned < 2 {
                clock.warned = 2
                gs.shadow.post("War Powers: the 60 days are up. U.S. forces must leave the fight with \(name) within 30 days.", date: gs.currentDate, severity: 3)
            }
            if days >= CongressModel.clockDays + CongressModel.withdrawalDays && clock.warned < 3 {
                clock.warned = 3
                gs.countries[pi].congressionalSupport = max(0, gs.countries[pi].congressionalSupport - 15)
                gs.shadow.ruthlessness += 15
                gs.shadow.post("The President defies the War Powers Resolution over \(name). Congress is furious.", date: gs.currentDate, severity: 3)
                logPlayEvent("war_powers_violation", detail: ["target": t, "target_name": PlayHistory.text(name), "days": days,
                                                              "game_date": PlayHistory.day(gs.currentDate)])
            }
            gs.shadow.warPowersClocks[t] = clock
        }
        self.gameState = gs
    }

    /// Monthly: Congress's support drifts with approval and outrage.
    func driftCongress(scale: TurnScale) {
        guard let gs = gameState, let pi = gs.countries.firstIndex(where: { $0.id == gs.playerCountryID }) else { return }
        let target = CongressModel.congressTarget(popularity: gs.shadow.popularity, ruthlessness: gs.shadow.ruthlessness)
        let keep = pow(0.5, scale.yearFraction / 0.5)
        let c = Double(gs.countries[pi].congressionalSupport)
        gs.countries[pi].congressionalSupport = Int((c * keep + target * (1 - keep)).rounded())
        self.gameState = gs
    }
}
