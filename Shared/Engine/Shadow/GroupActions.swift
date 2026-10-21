//
//  GroupActions.swift
//  Global Thermal Nuclear War
//
//  Group actions (3.10.0): the President acts on a group of nations at once ("all U.S. territories", "all allies",
//  "all of a region", a hand-picked selection or a saved custom group). Each member goes through the same
//  single-nation code as before (sendAid, setGarrison, executeShadowPresidentAction), so effects and logging are
//  identical; the group costs one action (garrison changes are free, as they are singly), its domestic effect is
//  counted once, and one play-history event lists the members.
//  Repository: https://github.com/kochj23/GTNW
//

import Foundation

enum GroupSelector: Hashable {
    case territories
    case allies
    case region(WorldRegion)
    case custom(name: String, ids: [String])

    var title: String {
        switch self {
        case .territories: return "All U.S. territories"
        case .allies: return "All allies"
        case .region(let r): return "All of \(r.rawValue)"
        case .custom(let name, _): return name
        }
    }
}

enum GroupActionKind: String, CaseIterable, Identifiable {
    case money, aid, garrison, sanctions, message, recall, extraction, levy
    var id: String { rawValue }
    var title: String {
        switch self {
        case .money: return "Give Money"
        case .aid: return "Send Aid"
        case .garrison: return "Set Garrison"
        case .sanctions: return "Sanctions"
        case .message: return "Diplomatic Message"
        case .recall: return "Recall Ambassadors"
        case .extraction: return "Extraction"
        case .levy: return "Collect Levy"
        }
    }
    /// The single-nation action each member gets, for the ones that map onto one.
    var presidential: PresidentialAction? {
        switch self {
        case .sanctions: return .sanctions
        case .message: return .jointStatement
        case .recall: return .recallAmbassador
        default: return nil
        }
    }
}

enum AidSplit: String, CaseIterable, Identifiable {
    case even, byNeed
    var id: String { rawValue }
    var title: String { self == .even ? "Evenly" : "By need" }
}

/// What a group action will do, member by member, before the President confirms.
struct GroupPlan {
    struct Line: Hashable {
        var id: String
        var name: String
        /// $ billions (money / aid) or thousands of troops (garrison); 0 otherwise.
        var amount: Double
        var detail: String
    }
    var lines: [Line]
    var total: Double
    var problem: String?
}

extension GameEngine {
    /// The members of a group now (never the player; territories only for garrisons; existing countries only).
    func groupMembers(_ selector: GroupSelector) -> [String] {
        guard let gs = gameState else { return [] }
        let player = gs.playerCountryID
        let live = gs.countries.filter { !$0.isDestroyed && $0.id != player }
        switch selector {
        case .territories: return live.filter { $0.territoryOf == player }.map(\.id).sorted()
        case .allies:
            // Treaty allies of the era (NATO, the Warsaw Pact…) plus any alliance made in play.
            let bloc = MilitaryAllianceSystem.allianceName(year: gs.currentYear, forCountryID: player)
            let mine = gs.getPlayerCountry()?.alliances ?? []
            return live.filter { c in
                c.territoryOf != player && (c.alliances.contains(player) || mine.contains(c.id)
                    || (bloc != nil && MilitaryAllianceSystem.allianceName(year: gs.currentYear, forCountryID: c.id) == bloc))
            }.map(\.id).sorted()
        case .region(let r): return live.filter { $0.region == r }.map(\.id).sorted()
        case .custom(_, let ids): return ids.filter { id in live.contains { $0.id == id } }
        }
    }

    /// The per-nation breakdown and total, or why it can't be done. `amount` is $B for money/aid (the total to
    /// share) and thousands per territory for garrisons.
    func planGroupAction(_ kind: GroupActionKind, members: [String], amount: Double = 0, split: AidSplit = .even, rate: ExtractionRate = .normal) -> GroupPlan {
        guard let gs = gameState else { return GroupPlan(lines: [], total: 0, problem: "No game.") }
        let countries = members.compactMap { gs.getCountry(id: $0) }
        if countries.isEmpty { return GroupPlan(lines: [], total: 0, problem: "The group is empty.") }
        if kind != .garrison && kind != .extraction && kind != .levy && gs.actionsRemaining == 0 {
            return GroupPlan(lines: [], total: 0, problem: "No actions left this \(gs.turnLength.displayName.lowercased()).")
        }
        switch kind {
        case .money, .aid:
            guard amount.isFinite, amount > 0 else { return GroupPlan(lines: [], total: 0, problem: "Choose an amount.") }
            if amount > gs.shadow.aidRemaining + 0.0001 {
                return GroupPlan(lines: [], total: amount, problem: String(format: "Only $%.1fB of aid is left this year.", gs.shadow.aidRemaining))
            }
            let needs = countries.map { max(0.01, $0.profile.aidNeed.total) }
            let sum = needs.reduce(0, +)
            let lines = countries.enumerated().map { i, c -> GroupPlan.Line in
                let share = split == .even ? amount / Double(countries.count) : amount * needs[i] / sum
                return GroupPlan.Line(id: c.id, name: c.name, amount: share, detail: String(format: "$%.2fB %@", share, kind == .money ? "economic" : "humanitarian"))
            }
            return GroupPlan(lines: lines, total: amount, problem: nil)
        case .garrison:
            guard amount.isFinite, amount >= 0.5 else { return GroupPlan(lines: [], total: 0, problem: "At least 0.5K per territory.") }
            let ours = countries.filter { $0.territoryOf == gs.playerCountryID }
            if ours.count != countries.count { return GroupPlan(lines: [], total: 0, problem: "Garrisons are for U.S. territories only.") }
            let lines = ours.map { c in
                GroupPlan.Line(id: c.id, name: c.name, amount: amount - (gs.shadow.garrisons[c.id] ?? 0),
                               detail: "\(Int(gs.shadow.garrisons[c.id] ?? 0))K → \(Int(amount))K")
            }
            let extra = lines.reduce(0) { $0 + max(0, $1.amount) }
            return GroupPlan(lines: lines, total: extra, problem: extra > AttackSizing.freeTroops(gs) ? "Needs \(Int(extra))K more troops than are free." : nil)
        case .sanctions, .message, .recall:
            let a = kind.presidential!
            let lines = countries.map { c in GroupPlan.Line(id: c.id, name: c.name, amount: Double(a.cost) / 1e9, detail: a.description) }
            return GroupPlan(lines: lines, total: lines.reduce(0) { $0 + $1.amount }, problem: nil)
        case .extraction, .levy:
            // 3.13.1: territory money, for U.S. territories only. Levies skip territories still in their cooldown.
            if countries.contains(where: { $0.territoryOf != gs.playerCountryID }) {
                return GroupPlan(lines: [], total: 0, problem: "Extraction and levies are for your territories only.")
            }
            if kind == .extraction {
                let lines = countries.map { c in GroupPlan.Line(id: c.id, name: c.name, amount: 0,
                                                                 detail: "\(ExpansionModel.rate(c.id, in: gs).title) → \(rate.title)") }
                return GroupPlan(lines: lines, total: 0, problem: nil)
            }
            let ready = countries.filter { ExpansionModel.levyCooldown($0.id, in: gs) == 0 }
            let lines = ready.map { c -> GroupPlan.Line in
                let amount = ExpansionModel.levyAmount(c, in: gs)
                return GroupPlan.Line(id: c.id, name: c.name, amount: amount, detail: String(format: "$%.2fB, stability −10", amount))
            }
            return GroupPlan(lines: lines, total: lines.reduce(0) { $0 + $1.amount }, problem: lines.isEmpty ? "Every territory is in its levy cooldown." : nil)
        }
    }

    /// Carry out a group action through the single-nation code. Returns the plan carried out, or nil if refused.
    @discardableResult
    func executeGroupAction(_ kind: GroupActionKind, members: [String], amount: Double = 0, split: AidSplit = .even,
                            groupName: String = "Group", rate: ExtractionRate = .normal) -> GroupPlan? {
        let plan = planGroupAction(kind, members: members, amount: amount, split: split, rate: rate)
        guard plan.problem == nil, let gs = gameState else { return nil }
        switch kind {
        case .money, .aid:
            for l in plan.lines {
                var v = AidVector()
                if kind == .money { v.economic = l.amount } else { v.humanitarian = l.amount }
                sendAid(v, to: l.id)
            }
        case .garrison:
            // Shrink first so the troops come home before others go out.
            for l in plan.lines.sorted(by: { $0.amount < $1.amount }) { setGarrison(l.id, thousands: amount) }
        case .sanctions, .message, .recall:
            let a = kind.presidential!
            for l in plan.lines { executeShadowPresidentAction(a, from: gs.playerCountryID, to: l.id) }
            recordPlayerAction(rung: a.rung, hostile: a.isHostile, detected: false)
        case .extraction:
            for l in plan.lines { setExtraction(l.id, rate) }
        case .levy:
            for l in plan.lines { collectLevy(l.id) }
        }
        gs.shadow.post("\(kind.title): \(groupName) (\(plan.lines.count) nation\(plan.lines.count == 1 ? "" : "s")).", date: gs.currentDate, severity: 1)
        logPlayEvent("group_action", detail: ["action": kind.rawValue, "group": PlayHistory.text(groupName),
                                              "members": plan.lines.map(\.id), "member_names": plan.lines.map { PlayHistory.text($0.name) },
                                              "total": PlayHistory.num(plan.total), "game_date": PlayHistory.day(gs.currentDate)])
        self.gameState = gs
        if kind != .garrison && kind != .extraction && kind != .levy { completePlayerAction() }   // territory money is free, like garrisons
        return plan
    }

    /// Save (or replace) a named custom group. Names are validated like territory names.
    @discardableResult
    func saveGroup(name raw: String, ids: [String]) -> Bool {
        guard let gs = gameState, let name = CombatModel.validTerritoryName(raw), !ids.isEmpty else { return false }
        gs.shadow.savedGroups[name] = Array(Set(ids)).sorted()
        self.gameState = gs
        return true
    }
}
