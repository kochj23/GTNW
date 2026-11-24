//
//  LeaderCapture.swift
//  Global Thermal Nuclear War
//
//  3.36.0: a special-forces raid to seize a foreign head of government and bring him back for trial: between the
//  covert assassination on the escalation ladder and a full invasion. The odds come from the era (no special forces
//  before 1940), the President's intelligence (the era's collection, a reconnaissance satellite, spy networks),
//  the military balance, the distance and how firmly the regime holds. The cabinet reads out the legality first.
//  One draw from the seeded RNG decides it:
//    • captured: the regime falls into the President's hands; the existing post-war settlement asks him to choose
//      the new government (the regime-change path), and the world condemns the raid;
//    • failed, the team taken: a hostage crisis that weighs on approval until they come home;
//    • failed in a firefight: the target declares war.
//  The text never names the leader: "the head of government of X".
//  Repository: https://github.com/kochj23/GTNW
//

import Foundation

enum RaidOutcome: String, Codable, Sendable {
    case captured, hostages, firefight

    var title: String {
        switch self {
        case .captured: return "Captured"
        case .hostages: return "Failed: team captured"
        case .firefight: return "Failed: firefight"
        }
    }
}

struct CaptureRaid: Codable, Equatable {
    var target: String
    var date: Date
    var odds: Double
    var outcome: RaidOutcome
}

/// Members of a failed raid held by the target.
struct HostageCrisis: Codable, Equatable {
    var captor: String
    var date: Date
    var count: Int
    var released = false
}

enum LeaderCapture {
    /// Days before another raid on the same nation.
    static let cooldownDays = 365
    /// Days before a captor lets the team go (unless at war).
    static let hostageDays = 180

    /// The raid's odds, 0.03…0.8. Pure, so the self-checks cover it.
    static func odds(year: Int, intel: Double, spies: Int, playerMilitary: Int, targetMilitary: Int, distanceKm: Double, targetStability: Int) -> Double {
        var p: Double
        switch year {
        case ..<1940: p = 0.08   // a raiding party, not special forces
        case ..<1980: p = 0.2
        default: p = 0.3
        }
        p += (intel - 0.5) * 0.4
        p += Double(min(100, max(0, spies))) / 100 * 0.15
        let ratio = Double(max(1, playerMilitary)) / Double(max(1, targetMilitary))
        p += max(-0.2, min(0.2, 0.08 * (ratio - 1)))
        p -= min(0.15, distanceKm / 80_000)
        p -= Double(targetStability - 50) / 500
        return (min(0.8, max(0.03, p)) * 100).rounded() / 100
    }
}

// MARK: - Engine

extension GameEngine {

    /// The odds the Situation Room shows for a raid on `target`.
    func captureOdds(_ target: String) -> Double {
        guard let gs = gameState, let me = gs.getPlayerCountry(), let t = gs.getCountry(id: target) else { return 0 }
        let km = NavalModel.distanceKm(lat1: me.coordinates.lat, lon1: me.coordinates.lon, lat2: t.coordinates.lat, lon2: t.coordinates.lon)
        return LeaderCapture.odds(year: gs.currentYear, intel: IntelligenceModel.confidence(year: gs.currentYear, recon: hasSatellite(.recon)),
                                  spies: me.spyNetworks[target] ?? 0, playerMilitary: me.militaryStrength, targetMilitary: t.militaryStrength,
                                  distanceKm: km, targetStability: t.stability)
    }

    func captureProblem(_ target: String) -> String? {
        guard let gs = gameState, let me = gs.getPlayerCountry() else { return "No game." }
        if gs.gameOver { return "The game is over." }
        if gs.actionsRemaining < 1 { return "No actions left." }
        guard let t = gs.getCountry(id: target), !t.isDestroyed else { return "No nation there." }
        if t.id == me.id || t.territoryOf == me.id { return "That is your own." }
        if t.isTerritory { return "\(t.name) is governed from \(gs.getCountry(id: t.territoryOf ?? "")?.name ?? "abroad"); it has no head of government of its own to seize." }
        if gs.currentYear < 1800 { return "No raid of this kind before 1800." }
        if gs.shadow.pendingSettlements.contains(where: { $0.loser == target }) { return "\(t.name)'s government is already in your hands." }
        if let last = gs.shadow.powerPlays.raids.last(where: { $0.target == target }),
           GameCalendar.days(from: last.date, to: gs.currentDate) < LeaderCapture.cooldownDays {
            return "\(t.name) is on guard after the last raid. Wait a year."
        }
        return nil
    }

    /// The cabinet's read-out: the odds, the law, the world, the politics.
    func captureWarnings(_ target: String) -> [AdvisorWarning] {
        guard let gs = gameState, let me = gs.getPlayerCountry(), let t = gs.getCountry(id: target) else { return [] }
        let odds = captureOdds(target)
        let jcs = AdvisorWarning(who: "Joint Chiefs", text: "Odds \(Int(odds * 100))%. If it fails, the team is killed or taken, or it turns into a firefight and a war.",
                                 level: odds < 0.3 ? 2 : (odds < 0.5 ? 1 : 0))
        var law: String
        var ll = 1
        if gs.currentYear >= 1945 {
            law = "Seizing a foreign head of government on his own soil without consent breaks the UN Charter's ban on force against another state."
            ll = 2
        } else {
            law = "The law of nations of the day treats a raid on a sovereign's capital as an act of war."
        }
        if gs.playerCountryID == "USA" && !isAuthorized(target) {
            law += " Congress has not authorized it" + (gs.currentDate >= CongressModel.warPowersResolution ? "; it counts as hostilities under the War Powers Resolution." : ".")
        }
        if me.alliances.contains(target) { law += " \(t.name) is an ally."; ll = 2 }
        if t.nuclearWarheads > 0 && gs.currentYear >= 1945 { law += " It is a nuclear power." ; ll = 2 }
        let state = AdvisorWarning(who: powerPlayStateWho,
                                   text: "Even if it works, capitals will condemn it\(gs.currentYear >= 1945 ? " at the United Nations" : ""): relations fall almost everywhere.",
                                   level: 1)
        let rally = (me.diplomaticRelations[target] ?? 0) < -40
        return [jcs, AdvisorWarning(who: PowerPlay.counsel, text: law, level: ll), state,
                powerPlayPolitics(dPop: rally ? 3 : -4, dRuth: 10, hostilities: target)]
    }

    /// Launch the raid (one action). `roll` 0..<1 for tests. Returns the outcome, or nil if it could not be ordered.
    @discardableResult
    func captureLeader(_ target: String, roll: Double? = nil) -> RaidOutcome? {
        guard captureProblem(target) == nil, let gs = gameState, let ti = gs.countries.firstIndex(where: { $0.id == target }),
              let pi = gs.countries.firstIndex(where: { $0.id == gs.playerCountryID }) else { return nil }
        let odds = captureOdds(target)
        powerPlayConsequences(target, how: "a raid")
        let r = roll ?? gameRoll()
        let outcome: RaidOutcome = r < odds ? .captured : (r < odds + (1 - odds) * 0.5 ? .hostages : .firefight)
        let name = gs.countries[ti].name, me = gs.countries[pi]
        let hostile = (me.diplomaticRelations[target] ?? 0) < -40
        gs.flash([me.id, target], .hostile, "\(me.name): raid on \(name)")
        spendFunds(0.5)
        gs.shadow.powerPlays.raids.append(CaptureRaid(target: target, date: gs.currentDate, odds: odds, outcome: outcome))
        switch outcome {
        case .captured:
            gs.countries[ti].stability = max(1, gs.countries[ti].stability - 25)
            gs.countries[ti].profile.leadership = 10
            gs.countries[ti].profile.outcry = min(100, gs.countries[ti].profile.outcry + 20)
            gs.shadow.divergedNations.insert(target)
            gs.shadow.leaderNames[target] = nil
            if !gs.shadow.pendingSettlements.contains(where: { $0.loser == target }) {
                gs.shadow.pendingSettlements.append(PostWarSettlement(loser: target, victor: me.id, date: gs.currentDate))
            }
            gs.shadow.popularity = PopularityModel.clamp(gs.shadow.popularity + (hostile ? 5 : -3))
            gs.shadow.ruthlessness += 10
            gs.shadow.post("Special forces seize the head of government of \(name) and fly them out for trial. \(name)'s government is in our hands: the President must decide what comes next.",
                           date: gs.currentDate, severity: 3)
            gs.shadow.logWar("\(GameCalendar.format(gs.currentDate)): head of government of \(name) captured in a raid.")
            addLog("🪂 RAID ON \(name.uppercased()) — CAPTURED.", type: .warning)
        case .hostages:
            let n = 4 + Int(r * 10) % 8
            gs.shadow.powerPlays.hostages.append(HostageCrisis(captor: target, date: gs.currentDate, count: n))
            gs.shadow.popularity = PopularityModel.clamp(gs.shadow.popularity - 8)
            gs.shadow.ruthlessness += 6
            gs.shadow.post("The raid on \(name) fails. \(n) members of the team are captured and paraded on television.", date: gs.currentDate, severity: 3)
            addLog("🪂 RAID ON \(name.uppercased()) — FAILED. \(n) taken prisoner.", type: .error)
        case .firefight:
            gs.shadow.popularity = PopularityModel.clamp(gs.shadow.popularity - 6)
            gs.shadow.ruthlessness += 8
            gs.shadow.post("The raid on \(name) turns into a firefight and fails. \(name) calls it an act of war.", date: gs.currentDate, severity: 3)
            addLog("🪂 RAID ON \(name.uppercased()) — FAILED IN A FIREFIGHT.", type: .error)
        }
        if gs.playerCountryID == "USA" && !isAuthorized(target) {
            gs.countries[pi].congressionalSupport = max(0, gs.countries[pi].congressionalSupport - 3)
        }
        self.gameState = gs
        // The world condemns it either way; less before the UN Charter, less from allies.
        modifyDiplomaticRelation(from: target, to: me.id, by: -60)
        let world = gs.currentYear >= 1945 ? 6 : 3
        for c in gs.countries where !c.isDestroyed && !c.isTerritory && c.id != me.id && c.id != target {
            modifyDiplomaticRelation(from: c.id, to: me.id, by: -(c.alliances.contains(me.id) ? 2 : world))
        }
        if gs.currentYear >= 1945 {
            gs.shadow.post("The United Nations Security Council meets on the raid on \(name). Most members condemn it.", date: gs.currentDate, severity: 2)
        }
        if outcome == .firefight { declareWar(aggressor: target, defender: me.id) }
        logPlayEvent("leader_capture", detail: ["target": target, "outcome": outcome.rawValue, "odds": PlayHistory.num(odds, places: 100),
                                                "game_date": PlayHistory.day(gs.currentDate)])
        completePlayerAction()
        return outcome
    }

    /// Each turn: the team comes home after half a year, unless the two are at war; until then approval suffers.
    func processHostages() {
        guard let gs = gameState else { return }
        let months = gs.scale.yearFraction * 12
        for i in gs.shadow.powerPlays.hostages.indices where !gs.shadow.powerPlays.hostages[i].released {
            let h = gs.shadow.powerPlays.hostages[i]
            let captor = gs.getCountry(id: h.captor)
            let atWar = captor?.atWarWith.contains(gs.playerCountryID) ?? false
            if captor == nil || captor!.isDestroyed || captor!.territoryOf == gs.playerCountryID
                || (!atWar && GameCalendar.days(from: h.date, to: gs.currentDate) >= LeaderCapture.hostageDays) {
                gs.shadow.powerPlays.hostages[i].released = true
                gs.shadow.post("The \(h.count) members of the raid team held in \(captor?.name ?? h.captor) come home.", date: gs.currentDate, severity: 2)
                gs.shadow.popularity = PopularityModel.clamp(gs.shadow.popularity + 3)
            } else {
                gs.shadow.popularity = PopularityModel.clamp(gs.shadow.popularity - months)
            }
        }
        self.gameState = gs
    }
}
