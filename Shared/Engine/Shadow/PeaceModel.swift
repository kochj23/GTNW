//
//  PeaceModel.swift
//  Global Thermal Nuclear War
//
//  Peace victories (3.16.0). Before this the peaceful endings were out of reach: Peace Maker needed every war on
//  Earth to stop (the living world of 3.14.0 never sleeps), Master Diplomat needed alliances with 80% of nations and
//  Economic Tycoon a GDP above everyone else's combined. Now there are four paths, each with a progress panel:
//    • Treaty network: treaties with 35% of the world's nations.
//    • Alliance leadership: the largest alliance on Earth, at least max(8, 20% of nations).
//    • Economic dominance: 30% of world output, at peace.
//    • Nobel moments: broker peace between warring nations three times.
//  Each needs the player at peace, with no nuclear weapons ever used, and five years in office. Short of a victory,
//  every path still scores (`peaceBonus`).
//  Repository: https://github.com/kochj23/GTNW
//

import Foundation

enum PeacePath: String, CaseIterable, Identifiable {
    case treatyNetwork, allianceLeader, economicDominance, nobel
    var id: String { rawValue }

    var title: String {
        switch self {
        case .treatyNetwork: return "Treaty network"
        case .allianceLeader: return "Alliance leadership"
        case .economicDominance: return "Economic dominance"
        case .nobel: return "Nobel moments"
        }
    }

    var victory: VictoryType {
        switch self {
        case .treatyNetwork: return .diplomaticVictory
        case .allianceLeader: return .allianceLeader
        case .economicDominance: return .economicVictory
        case .nobel: return .nobelPeace
        }
    }
}

struct PeaceProgress: Hashable {
    var value: Double
    var target: Double
    /// What still stands in the way (nil when the path's own goal is met).
    var missing: String?
    var fraction: Double { target > 0 ? min(1, value / target) : 0 }
}

enum PeaceModel {
    static let treatyShare = 0.35
    static let outputShare = 0.30
    static let nobelTarget = 3
    static let minYears = 5.0

    /// Independent nations on the board other than the player.
    static func others(_ gs: GameState) -> [Country] { gs.liveCountries.filter { $0.id != gs.playerCountryID } }

    /// Nations the player has any treaty with.
    static func treatyPartners(_ gs: GameState) -> Set<String> {
        let me = gs.playerCountryID
        let live = Set(others(gs).map(\.id))
        return Set(gs.treaties.filter { $0.signatories.contains(me) }.flatMap(\.signatories)).intersection(live)
            .union(gs.getPlayerCountry()?.alliances.intersection(live) ?? [])
    }

    static func economicTarget(_ gs: GameState) -> Double {
        let start = gs.shadow.startOutputShare > 0 ? gs.shadow.startOutputShare : outputShare(gs)
        return min(outputShare, start + 0.05)
    }

    static func outputShare(_ gs: GameState) -> Double {
        guard let me = gs.getPlayerCountry() else { return 0 }
        let world = gs.liveCountries.reduce(0) { $0 + max(0, $1.gdp) }
        return world > 0 ? max(0, me.gdp) / world : 0
    }

    static func progress(_ path: PeacePath, _ gs: GameState) -> PeaceProgress {
        let n = Double(max(1, others(gs).count))
        switch path {
        case .treatyNetwork:
            let have = Double(treatyPartners(gs).count), need = (n * treatyShare).rounded(.up)
            return PeaceProgress(value: have, target: need, missing: have >= need ? nil : "\(Int(need - have)) more treaty partners")
        case .allianceLeader:
            let mine = gs.getPlayerCountry()?.alliances.filter { id in others(gs).contains { $0.id == id } }.count ?? 0
            let rival = others(gs).map(\.alliances.count).max() ?? 0
            let need = Double(max(8, Int((n * 0.2).rounded(.up))))
            if Double(mine) < need { return PeaceProgress(value: Double(mine), target: need, missing: "\(Int(need) - mine) more allies") }
            return PeaceProgress(value: Double(mine), target: need, missing: mine > rival ? nil : "another nation leads a bloc as large (\(rival))")
        case .economicDominance:
            // Era-relative: 30% of world output, or five points above the share you started with if that's less
            // (the 1789 republic starts near 0%), and the largest economy on Earth.
            let s = outputShare(gs), need = economicTarget(gs)
            if s < need { return PeaceProgress(value: s, target: need, missing: String(format: "%.1f%% of world output; %.1f%% needed", s * 100, need * 100)) }
            let rival = others(gs).max { $0.gdp < $1.gdp }
            if let r = rival, let me = gs.getPlayerCountry(), r.gdp >= me.gdp {
                return PeaceProgress(value: s, target: need, missing: "\(r.name) is still the largest economy")
            }
            return PeaceProgress(value: s, target: need, missing: nil)
        case .nobel:
            let k = gs.shadow.nobelMoments
            return PeaceProgress(value: Double(k), target: Double(nobelTarget), missing: k >= nobelTarget ? nil : "broker \(nobelTarget - k) more peace\(nobelTarget - k == 1 ? "" : "s")")
        }
    }

    /// What every peace victory also needs (nil when met).
    static func conditionsProblem(_ gs: GameState) -> String? {
        guard let me = gs.getPlayerCountry() else { return "No nation." }
        if gs.nuclearStrikes.contains(where: { $0.attacker == me.id }) { return "You have used nuclear weapons." }
        if !me.atWarWith.isEmpty { return "You are at war." }
        if gs.elapsedYears < minYears - 1e-6 { return String(format: "%.1f of %.0f years in office", gs.elapsedYears, minYears) }
        return nil
    }

    /// The peace victory reached, if any (first path in order).
    static func victory(_ gs: GameState) -> VictoryType? {
        guard conditionsProblem(gs) == nil else { return nil }
        return PeacePath.allCases.first { progress($0, gs).missing == nil }?.victory
    }

    /// Score for peace short of victory: treaty partners, allies, Nobel moments, years of peace and output share.
    static func scoreBonus(_ gs: GameState) -> Int {
        let peaceYears = Double(gs.peaceTurns) * gs.turnLength.yearFraction
        return treatyPartners(gs).count * 25 + gs.shadow.nobelMoments * 200 + Int(peaceYears * 10) + Int(outputShare(gs) * 1000)
    }

    /// Odds the player can broker peace between two warring nations: better the more both like the United States.
    static func brokerOdds(_ a: Country, _ b: Country, player: String) -> Double {
        let ra = Double(a.diplomaticRelations[player] ?? 0), rb = Double(b.diplomaticRelations[player] ?? 0)
        return min(0.9, max(0.1, 0.35 + (ra + rb) / 400))
    }

    /// Wars between other nations the player could try to end.
    static func brokerable(_ gs: GameState) -> [(Country, Country)] {
        let me = gs.playerCountryID
        return gs.activeWars.compactMap { w in
            guard w.aggressor != me, w.defender != me, let a = gs.getCountry(id: w.aggressor), let b = gs.getCountry(id: w.defender),
                  !a.isDestroyed, !b.isDestroyed else { return nil }
            return (a, b)
        }
    }
}

extension GameEngine {
    /// Broker peace between two warring nations (one action). Success ends the war and is a Nobel moment.
    @discardableResult
    func brokerPeace(_ a: String, _ b: String, roll: Double = Double.random(in: 0..<1)) -> Bool? {
        guard let gs = gameState, gs.actionsRemaining > 0, a != gs.playerCountryID, b != gs.playerCountryID,
              let ca = gs.getCountry(id: a), let cb = gs.getCountry(id: b), ca.atWarWith.contains(b) else { return nil }
        let won = roll < PeaceModel.brokerOdds(ca, cb, player: gs.playerCountryID)
        if won {
            makePeace(a, b)
            gs.shadow.nobelMoments += 1
            gs.shadow.popularity = PopularityModel.clamp(gs.shadow.popularity + 2)
            modifyDiplomaticRelation(from: a, to: gs.playerCountryID, by: 10)
            modifyDiplomaticRelation(from: b, to: gs.playerCountryID, by: 10)
            gs.shadow.post("The President brokers peace between \(ca.name) and \(cb.name). There is talk of a Nobel Prize.", date: gs.currentDate, severity: 2)
        } else {
            modifyDiplomaticRelation(from: a, to: gs.playerCountryID, by: -3)
            modifyDiplomaticRelation(from: b, to: gs.playerCountryID, by: -3)
            gs.shadow.post("Talks between \(ca.name) and \(cb.name) collapse.", date: gs.currentDate, severity: 1)
        }
        logPlayEvent("peace_brokered", detail: ["a": a, "b": b, "success": won, "game_date": PlayHistory.day(gs.currentDate)])
        self.gameState = gs
        completePlayerAction()
        return won
    }
}
