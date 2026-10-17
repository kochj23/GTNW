//
//  CombatModel.swift
//  Global Thermal Nuclear War
//
//  The War Room's model: each war is a front with troops on both sides, fighting resolved week by week (scaled to the
//  turn length), troop morale ("will to fight"), casualties and economic damage. A side that breaks surrenders and
//  the victor installs a new government; an attacker that breaks withdraws. The U.S. can commit troops to either side.
//  Repository: https://github.com/kochj23/GTNW
//

import Foundation

enum FrontStatus: String, Codable {
    case fighting, attackerWon, defenderWon, ceasefire
}

struct WarFront: Codable, Identifiable, Hashable {
    var id = UUID()
    var attacker: String
    var defender: String
    var startDate: Date
    var lastBattle: Date
    /// Troops in theater, thousands.
    var attackerTroops: Double
    var defenderTroops: Double
    var attackerInitial: Double
    var defenderInitial: Double
    /// Will to fight, 0…1.
    var attackerWill: Double = 0.8
    var defenderWill: Double = 0.85
    /// Who is winning: -1 (defender) … +1 (attacker).
    var attackerMomentum: Double = 0
    /// Casualties, thousands.
    var attackerDead: Double = 0
    var defenderDead: Double = 0
    var civilianDead: Double = 0
    /// Economic damage to the defender, billions.
    var economicLoss: Double = 0
    /// U.S. troops committed, thousands, and on which side (nil = none).
    var usTroops: Double = 0
    var usSide: String?
    var status: FrontStatus = .fighting
    var battles: Int = 0

    var involvesUS: Bool { usSide != nil }
}

/// One week of fighting on a front: pure arithmetic over the inputs, randomness passed in.
struct BattleOutcome: Equatable {
    var attackerLosses: Double
    var defenderLosses: Double
    var civilianLosses: Double
    var momentumChange: Double
}

enum CombatModel {
    /// Troops a country can field, thousands.
    static func forcePool(_ c: Country) -> Double {
        max(5, Double(max(1, c.militaryStrength)) * sqrt(Double(max(1, c.population))) * 1.2)
    }

    static func makeFront(attacker: Country, defender: Country, date: Date) -> WarFront {
        let a = forcePool(attacker) * 0.35
        let d = forcePool(defender) * 0.55
        return WarFront(attacker: attacker.id, defender: defender.id, startDate: date, lastBattle: date,
                        attackerTroops: a, defenderTroops: d, attackerInitial: a, defenderInitial: d)
    }

    /// Combat power: troops × morale × quality (× defender's home-ground bonus).
    static func power(troops: Double, will: Double, strength: Int, defending: Bool) -> Double {
        troops * (0.4 + will) * (0.3 + Double(strength) / 100) * (defending ? 1.25 : 1.0)
    }

    /// Resolve one week. `rolls` are two numbers in 0..<1 (luck for each side).
    static func battle(_ f: WarFront, attackerStrength: Int, defenderStrength: Int, rolls: (Double, Double)) -> BattleOutcome {
        var aTroops = f.attackerTroops, dTroops = f.defenderTroops
        if f.usSide == f.attacker { aTroops += f.usTroops }
        if f.usSide == f.defender { dTroops += f.usTroops }
        let pa = power(troops: aTroops, will: f.attackerWill, strength: attackerStrength, defending: false)
        let pd = power(troops: dTroops, will: f.defenderWill, strength: defenderStrength, defending: true)
        let ratio = max(0.05, min(20, pa / max(0.001, pd)))
        let luckA = 0.7 + rolls.0 * 0.6, luckD = 0.7 + rolls.1 * 0.6
        let aLoss = aTroops * 0.012 * pow(1 / ratio, 0.5) * luckD
        let dLoss = dTroops * 0.012 * pow(ratio, 0.5) * luckA
        return BattleOutcome(attackerLosses: aLoss, defenderLosses: dLoss, civilianLosses: (aLoss + dLoss) * 0.3,
                             momentumChange: max(-0.25, min(0.25, (ratio - 1) * 0.08)))
    }

    /// Apply a battle to a front (casualties split proportionally with committed U.S. troops).
    /// Returns U.S. troop losses (thousands).
    @discardableResult
    static func apply(_ o: BattleOutcome, to f: inout WarFront, date: Date) -> Double {
        var usLoss = 0.0
        func split(_ loss: Double, own: Double, side: String) -> Double {
            guard f.usSide == side, f.usTroops > 0 else { return loss }
            let share = f.usTroops / (own + f.usTroops)
            usLoss += loss * share
            return loss * (1 - share)
        }
        let aLoss = split(o.attackerLosses, own: f.attackerTroops, side: f.attacker)
        let dLoss = split(o.defenderLosses, own: f.defenderTroops, side: f.defender)
        f.usTroops = max(0, f.usTroops - usLoss)
        f.attackerTroops = max(0, f.attackerTroops - aLoss)
        f.defenderTroops = max(0, f.defenderTroops - dLoss)
        f.attackerDead += aLoss * 0.3
        f.defenderDead += dLoss * 0.3
        f.civilianDead += o.civilianLosses
        f.economicLoss += o.defenderLosses * 0.05
        f.attackerMomentum = max(-1, min(1, f.attackerMomentum + o.momentumChange))
        // Morale follows losses and momentum.
        let aFrac = o.attackerLosses / max(1, f.attackerInitial)
        let dFrac = o.defenderLosses / max(1, f.defenderInitial)
        f.attackerWill = max(0, min(1, f.attackerWill - aFrac * 2.5 + f.attackerMomentum * 0.01))
        f.defenderWill = max(0, min(1, f.defenderWill - dFrac * 2.5 - f.attackerMomentum * 0.01))
        f.lastBattle = date
        f.battles += 1
        return usLoss
    }

    /// Has one side broken?
    static func verdict(_ f: WarFront) -> FrontStatus {
        if f.defenderWill < 0.15 || f.defenderTroops < f.defenderInitial * 0.12 { return .attackerWon }
        if f.attackerWill < 0.15 || f.attackerTroops < f.attackerInitial * 0.12 { return .defenderWon }
        return .fighting
    }

    /// Probability a surrender demand is accepted right now.
    static func surrenderAcceptance(_ f: WarFront, demandedBy side: String) -> Double {
        let momentum = side == f.attacker ? f.attackerMomentum : -f.attackerMomentum
        let enemyWill = side == f.attacker ? f.defenderWill : f.attackerWill
        return min(0.95, max(0.02, 0.1 + momentum * 0.5 + (0.6 - enemyWill) * 0.8))
    }

    /// The conquered country gets a government shaped like the victor's.
    static func installGovernment(on loser: inout Country, by winner: Country) {
        loser.alignment = winner.alignment
        loser.government = winner.government == .monarchy ? .authoritarian : winner.government
        var p = loser.profile
        p.ideology = winner.profile.ideology
        p.ambition = 2
        p.ethic = max(2, winner.profile.ethic - 1)
        p.leadership = 30
        p.outcry = min(100, p.outcry + 30)
        loser.profile = p
        loser.stability = max(10, loser.stability - 30)
        loser.diplomaticRelations[winner.id] = 60
        loser.atWarWith.remove(winner.id)
    }
}
