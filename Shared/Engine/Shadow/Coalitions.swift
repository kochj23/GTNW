//
//  Coalitions.swift
//  Global Thermal Nuclear War
//
//  Allied coalitions (3.12.0): ask allies to join an operation against a target. Candidates are the era's treaty
//  allies (NATO from 1949, the Warsaw Pact for the USSR, …), alliances made in play, and friendly nations (an ad-hoc
//  coalition of the willing). Each decides by its relations with the player, its ties to the target, and the
//  legitimacy of the action: a declaration or authorization from the legislature helps, a casus belli helps, a
//  chemical or biological weapon used by the player poisons it. Members send troops to the front and share the
//  world-opinion cost of the operation; those who refuse drift a little away.
//  Repository: https://github.com/kochj23/GTNW
//

import Foundation

/// A coalition against one target: who joined, who refused, when.
struct Coalition: Codable, Hashable {
    var target: String
    var members: [String]
    var refused: [String]
    var formed: Date
}

enum CoalitionModel {
    /// Chance an ally joins (design choice): 0.3 at relations +50 with the player, up 0.01 per point, plus 0.25 with
    /// a legislative authorization, 0.15 with a casus belli; minus 0.3 if it is friendly with the target (+50) and
    /// 0.5 if the player has used chemical or biological weapons. Clamped to 0.02…0.95.
    static func joinOdds(relationWithPlayer r: Int, relationWithTarget t: Int, authorized: Bool, casusBelli: Double, wmdUsed: Bool) -> Double {
        var p = 0.3 + Double(r - 50) * 0.01
        if authorized { p += 0.25 }
        p += 0.15 * casusBelli
        if t > 50 { p -= 0.3 }
        if wmdUsed { p -= 0.5 }
        return min(0.95, max(0.02, p))
    }

    /// Troops (thousands) a member sends: a tenth of its force pool.
    static func contribution(_ c: Country) -> Double { (CombatModel.forcePool(c) * 0.1).rounded() }

    /// The world's reaction to an operation is shared out among the coalition: the player bears 1 / (members + 1).
    static func opinionShare(members: Int) -> Double { 1 / Double(members + 1) }
}

extension GameEngine {
    /// Who can be asked: treaty and in-play allies plus friendly nations (relations ≥ 50), never the target or its allies.
    func coalitionCandidates(against target: String) -> [String] {
        guard let gs = gameState, let t = gs.getCountry(id: target), let p = gs.getPlayerCountry() else { return [] }
        let allies = Set(groupMembers(.allies))
        return gs.countries.filter { c in
            c.id != p.id && c.id != target && !c.isDestroyed && !c.isTerritory && !t.alliances.contains(c.id)
                && (allies.contains(c.id) || (c.diplomaticRelations[p.id] ?? 0) >= 50)
        }.map(\.id).sorted()
    }

    /// The odds each candidate joins, from the same function the vote uses.
    func coalitionOdds(against target: String) -> [(id: String, odds: Double)] {
        guard let gs = gameState, let p = gs.getPlayerCountry(), let t = gs.getCountry(id: target) else { return [] }
        let authorized = p.id == "USA" ? isAuthorized(target) : false
        let cb = CongressModel.casusBelli(target: t, player: p, gs: gs)
        let wmd = gs.shadow.wmdPrograms.values.contains { $0.discovered } || gs.shadow.ticker.contains { $0.text.contains("uses chemical") || $0.text.contains("uses biological") }
        return coalitionCandidates(against: target).compactMap { id in
            guard let c = gs.getCountry(id: id) else { return nil }
            return (id, CoalitionModel.joinOdds(relationWithPlayer: c.diplomaticRelations[p.id] ?? 0, relationWithTarget: c.diplomaticRelations[target] ?? 0,
                                                authorized: authorized, casusBelli: cb, wmdUsed: wmd))
        }.sorted { $0.odds > $1.odds }
    }

    /// Ask the candidates to join (one action). `rolls` maps ids to 0..<1 for tests. Returns the coalition.
    @discardableResult
    func requestCoalition(against target: String, rolls: [String: Double] = [:]) -> Coalition? {
        guard let gs = gameState, gs.actionsRemaining > 0, gs.getCountry(id: target) != nil, target != gs.playerCountryID else { return nil }
        let odds = coalitionOdds(against: target)
        guard !odds.isEmpty else { return nil }
        var members: [String] = [], refused: [String] = []
        for (id, p) in odds {
            if (rolls[id] ?? Double.random(in: 0..<1)) < p { members.append(id) } else { refused.append(id) }
        }
        let player = gs.playerCountryID
        for id in members {
            modifyDiplomaticRelation(from: id, to: target, by: -20)
            modifyDiplomaticRelation(from: target, to: id, by: -20)
            // They send troops to any front the player is fighting against the target.
            if let fi = gs.shadow.fronts.firstIndex(where: { $0.status == .fighting && $0.defender == target && ($0.attacker == player || $0.usSide == $0.attacker) }),
               let c = gs.getCountry(id: id) {
                gs.shadow.fronts[fi].attackerTroops += CoalitionModel.contribution(c)
                gs.shadow.fronts[fi].attackerInitial += CoalitionModel.contribution(c)
            }
        }
        for id in refused { modifyDiplomaticRelation(from: id, to: player, by: -5) }
        var co = gs.shadow.coalitions[target] ?? Coalition(target: target, members: [], refused: [], formed: gs.currentDate)
        co.members = Array(Set(co.members + members)).sorted()
        co.refused = Array(Set(co.refused + refused).subtracting(co.members)).sorted()
        gs.shadow.coalitions[target] = co
        let tName = gs.getCountry(id: target)?.name ?? target
        let names = members.compactMap { gs.getCountry(id: $0)?.name }
        gs.shadow.post(members.isEmpty ? "No ally will join an operation against \(tName)."
                       : "\(names.count) nation\(names.count == 1 ? "" : "s") join the coalition against \(tName): \(names.prefix(5).joined(separator: ", "))\(names.count > 5 ? "…" : "").",
                       date: gs.currentDate, severity: 2)
        logPlayEvent("coalition_request", detail: ["target": target, "target_name": PlayHistory.text(tName), "joined": members, "refused": refused,
                                                   "game_date": PlayHistory.day(gs.currentDate)])
        self.gameState = gs
        completePlayerAction()
        return co
    }

    /// The share of world opinion the player bears for an operation against `target` (1 = alone).
    func opinionShare(against target: String) -> Double {
        CoalitionModel.opinionShare(members: gameState?.shadow.coalitions[target]?.members.count ?? 0)
    }
}
