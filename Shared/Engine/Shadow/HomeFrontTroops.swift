//
//  HomeFrontTroops.swift
//  Global Thermal Nuclear War
//
//  Troops in your own states (3.36.0): federal troops (the guard federalized, or the army) sent into one of the
//  President's own states over its governor's objection. In a state already in turmoil they can restore order; in a
//  quiet one they inflame it. The nation splits: a law-and-order state cheers, the rest of the country (and the state
//  itself) resents it, and every state's own swing at the next election follows its unrest. A deployment is taken to
//  court (under the emergency-powers hook when one is in force); a state pushed past its breaking point while the
//  troops stay may try to leave the Union.
//  The states themselves (names, unrest, secession, the state-by-state election) are the states-and-provinces model;
//  this file only reads and nudges them through the adapter at the bottom.
//  Repository: https://github.com/kochj23/GTNW
//

import Foundation

/// A state picked for an order: its id and the card's label.
struct HomeStateTarget: Equatable {
    let id: String
    let label: String
}

struct HomeTargetError: Error, Equatable { let message: String }

extension HomeFrontModel {
    /// Days until a court rules on a deployment over a governor's objection.
    static let courtDays = 90
    /// Whether a court lets a deployment over a governor's objection stand (deterministic): it holds in real turmoil,
    /// not in a quiet state, and a declared emergency helps.
    static func deploymentUpheld(unrestAtStart: Double, emergency: Bool) -> Bool {
        (unrestAtStart >= orderThreshold ? 0.6 : 0.3) + (emergency ? 0.1 : 0) >= 0.5
    }
    /// Annual chance a state past its breaking point, with troops in it, tries to leave the Union.
    static let secessionAnnual = 0.25
    static var secessionUnrest: Double { ProvinceModel.breakingPoint }
}

extension GameEngine {

    // MARK: Orders

    /// Resolve a typed state name to one of the President's own states.
    func homeStateTarget(_ raw: String) -> Result<HomeStateTarget, HomeTargetError> {
        guard let gs = gameState else { return .failure(HomeTargetError(message: "No game in progress.")) }
        guard gs.playerCountryID == "USA" else {
            return .failure(HomeTargetError(message: "Only the United States' states are modeled for this order."))
        }
        let name = raw.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return .failure(HomeTargetError(message: "Name one of your states, for example \"send federal troops into Texas\".")) }
        guard let s = homeStateLookup(name) else {
            return .failure(HomeTargetError(message: "No state of yours called \"\(String(name.prefix(30)))\" in \(gs.currentYear)."))
        }
        return .success(HomeStateTarget(id: s.id, label: "\(s.name), \(gs.currentYear)"))
    }

    func homeTroopsProblem(mode: String, state: String) -> String? {
        guard let gs = gameState else { return "No game in progress." }
        guard gs.playerCountryID == "USA" else { return "Only the United States' states are modeled for this order." }
        guard let name = homeStateName(state) else { return "That is not one of your states in \(gs.currentYear)." }
        let there = gs.shadow.homeFront.deployments.contains { $0.state == state }
        if mode == "withdraw" { return there ? nil : "No federal troops are deployed in \(name)." }
        if there { return "Federal troops are already deployed in \(name)." }
        let need = HomeFrontModel.homeTroops(year: gs.currentYear)
        return AttackSizing.freeTroops(gs) >= need ? nil : "Not enough free troops: a deployment needs \(Int(need))K."
    }

    func homeTroopsReadout(mode: String, state: String) -> ([String], [CommandWarning]) {
        guard let gs = gameState, let name = homeStateName(state) else { return ([], []) }
        func who(_ role: String) -> String {
            let t = AdviceEngine.roleTitle(role)
            return AdviceEngine.advisor(for: role, in: gs.advisors).map { "\(t) \($0.name)" } ?? t
        }
        if mode == "withdraw" { return (["Withdraw the federal troops from \(name) and return control to its governor."], []) }
        let unrest = homeStateUnrest(state)
        let restores = unrest >= HomeFrontModel.orderThreshold
        let troops = Int(HomeFrontModel.homeTroops(year: gs.currentYear))
        let c = ["Send \(troops)K federal troops into \(name) over its governor's objection.",
                 restores ? "Unrest there is \(Int(unrest.rounded())): the troops can restore order."
                          : "Unrest there is only \(Int(unrest.rounded())): the troops will inflame it.",
                 "The governor sues; a court rules in about \(HomeFrontModel.courtDays) days."]
        var w = [CommandWarning(text: "\(who("whc")): The country splits. \(restores ? "Law-and-order voters cheer" : "Most of the country sees an occupation")"
                                + "; \(name) will vote against you either way.", level: 1)]
        w.append(CommandWarning(text: "\(who("defense")): Soldiers trained for war are poor police. If unrest passes \(Int(HomeFrontModel.secessionUnrest)), talk of leaving the Union starts.",
                                level: restores ? 1 : 2))
        return (c, w)
    }

    func runHomeTroops(mode: String, state: String) -> Bool {
        guard let gs = gameState, let name = homeStateName(state) else { return false }
        if mode == "withdraw" {
            gs.shadow.homeFront.deployments.removeAll { $0.state == state }
            self.gameState = gs
            if let o = liveEmergencyOrder(.deployment, target: state) { endEmergencyOrder(o.id, status: .rescinded, why: "the troops came home") }
            homeStateNudge(state, by: -5)
            gs.shadow.post("Federal troops leave \(name). The governor resumes command of the state's guard.", date: gs.currentDate, severity: 1)
            addLog("🏛️ Federal troops withdrawn from \(name).", type: .info)
            return true
        }
        let unrest = homeStateUnrest(state)
        let restores = unrest >= HomeFrontModel.orderThreshold
        gs.shadow.homeFront.deployments.append(HomeDeployment(state: state, since: gs.currentDate, troops: HomeFrontModel.homeTroops(year: gs.currentYear),
                                                                unrestAtStart: unrest))
        gs.shadow.popularity = PopularityModel.clamp(gs.shadow.popularity + (restores ? 1 : -3))
        gs.shadow.ruthlessness += restores ? 3 : 8
        self.gameState = gs
        homeStateNudge(state, by: restores ? 5 : 15)   // the first days are the worst
        homeFrontEmergencyOrder(state: state, name: name)
        gs.shadow.post("The President sends federal troops into \(name) over the governor's objection. "
                       + (restores ? "Supporters call it overdue." : "Protests spread to other states."), date: gs.currentDate, severity: 2)
        addLog("🪖 Federal troops deployed in \(name) over its governor's objection.", type: .warning)
        return true
    }

    // MARK: Each turn

    /// Troops in the states: order restored or unrest rising, the courts, and a state past its breaking point.
    func processHomeDeployments() {
        guard let gs = gameState, !gs.shadow.homeFront.deployments.isEmpty else { return }
        let scale = gs.scale
        for d in gs.shadow.homeFront.deployments {
            guard let name = homeStateName(d.state) else {
                gs.shadow.homeFront.deployments.removeAll { $0.state == d.state }
                continue
            }
            // Under the Insurrection Act the emergency-powers court rules; struck down (or withdrawn), the troops leave.
            if let o = homeFrontOrder(d), !o.status.isLive {
                gs.shadow.homeFront.deployments.removeAll { $0.state == d.state }
                continue
            }
            let restores = d.unrestAtStart >= HomeFrontModel.orderThreshold
            homeStateNudge(d.state, by: scale.amount(annual: restores ? -30 : 25))
            gs.shadow.popularity = PopularityModel.clamp(gs.shadow.popularity - scale.amount(annual: restores ? 0 : 4))
            // The governor's suit.
            if !d.challenged, GameCalendar.days(from: d.since, to: gs.currentDate) >= HomeFrontModel.courtDays, homeFrontOrder(d) == nil {
                if let i = gs.shadow.homeFront.deployments.firstIndex(where: { $0.state == d.state }) { gs.shadow.homeFront.deployments[i].challenged = true }
                if HomeFrontModel.deploymentUpheld(unrestAtStart: d.unrestAtStart, emergency: homeFrontEmergencyInForce()) {
                    gs.shadow.post("The courts let the federal deployment in \(name) stand.", date: gs.currentDate, severity: 1)
                } else {
                    gs.shadow.homeFront.deployments.removeAll { $0.state == d.state }
                    gs.shadow.popularity = PopularityModel.clamp(gs.shadow.popularity - 2)
                    gs.shadow.post("The courts order the federal troops out of \(name): the governor's objection stands.", date: gs.currentDate, severity: 2)
                    addLog("⚖️ Federal deployment in \(name) struck down.", type: .warning)
                    continue
                }
            }
            // A state pushed past its breaking point with soldiers in its streets.
            if homeStateUnrest(d.state) >= HomeFrontModel.secessionUnrest,
               Double.random(in: 0..<1, using: &gs.rng) < scale.probability(annual: HomeFrontModel.secessionAnnual) {
                gs.shadow.homeFront.deployments.removeAll { $0.state == d.state }
                self.gameState = gs
                homeStateSecede(d.state, reason: "after federal troops were sent in over its governor's objection")
            }
        }
        self.gameState = gs
    }

    // MARK: The states model (adapter)

    /// One of the President's own states by a typed name: its id and name this year.
    func homeStateLookup(_ raw: String) -> (id: String, name: String)? {
        guard let gs = gameState, let s = Subdivisions.find(raw, in: gs), let name = homeStateName(s.id) else { return nil }
        return (s.id, name)
    }

    /// A state's name, when it is one of the President's own states this year (a state of the Union he still holds).
    func homeStateName(_ id: String) -> String? {
        guard let gs = gameState, Subdivisions.isUSState(id, on: gs.currentDate), gs.provinceOwner(id) == gs.playerCountryID else { return nil }
        return gs.provinceName(id)
    }

    func homeStateUnrest(_ id: String) -> Double { gameState?.shadow.provinces.unrest[id] ?? 0 }

    func homeStateNudge(_ id: String, by amount: Double) {
        guard let gs = gameState else { return }
        let v = min(100, max(0, homeStateUnrest(id) + amount))
        gs.shadow.provinces.unrest[id] = v < 0.5 ? nil : (v * 10).rounded() / 10
    }

    func homeStateSecede(_ id: String, reason: String) { secede(id, reason: reason) }

    // MARK: Emergency powers and the courts (adapter)

    /// Records the deployment as an emergency order under the Insurrection Act (from 1807, U.S. only); its court
    /// clock then decides. Nil before the Act: the governor's suit (`deploymentUpheld`) decides instead.
    func homeFrontEmergencyOrder(state: String, name: String) {
        issueEmergencyOrder(kind: .deployment, target: state, subject: "federal troops in \(name)", basis: .insurrectionAct)
    }

    /// The emergency order behind this deployment, when the emergency-powers court is the one reviewing it.
    func homeFrontOrder(_ d: HomeDeployment) -> EmergencyOrder? {
        gameState?.shadow.powerPlays.orders.last { $0.kind == .deployment && $0.target == d.state && $0.issued >= d.since }
    }

    func homeFrontEmergencyInForce() -> Bool { gameState?.shadow.powerPlays.emergency != nil }
}
