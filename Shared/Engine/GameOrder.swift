//
//  GameOrder.swift
//  Global Thermal Nuclear War
//
//  3.34.0: the command box. A typed order is the only thing the command box can carry out, and every order is one of
//  the engine's existing verbs: a whitelisted Situation Room action (sized like the ladder's sizing step), a war
//  declaration, a named U.S. fleet order, or one of the land actions (claim, seize, buy, back independence). The text
//  the player typed never reaches the engine; the parser or the local model only picks orders from this list, the
//  planner fills in the numbers from the game state, and the engine and the game's seeded RNG decide what happens.
//  Saves, play history and replays keep the resolved orders (`ShadowState.commandLog`), never the text.
//  Repository: https://github.com/kochj23/GTNW
//

import Foundation

/// What kind of engine verb an order runs. Nothing outside this list can be ordered from the command box.
enum OrderKind: String, Codable, CaseIterable, Sendable {
    /// A whitelisted `PresidentialAction`, through `performAdvisedAction` (advice, popularity, one action).
    case action
    /// `declareWar` on a nation (one action).
    case declareWar
    /// A named U.S. fleet (`orderFleet`, one action).
    case fleet
    /// Unclaimed or indigenous-held land (`claimLand` / `claimIndigenousLand`).
    case claimLand
    /// A colony seized by force from its owner (`seizeColony`).
    case seizeColony
    /// A colony bought by treaty (`purchaseColony`).
    case buyColony
    /// A colony's independence backed (`supportIndependence`).
    case backIndependence
    /// 3.36.0 power plays (ForeignPowerPlays.swift): a step of an acquisition campaign (`mission` = `CampaignStep`), an
    /// emergency order (`mission` = `EmergencyStep`, `detail` = the reason or the legal basis), a leader-capture raid,
    /// and a limited strike (`mission` = `StrikeKind`). `renamePlace`: a sea, mountain or department (`target` = its
    /// id in MapFeatures.swift, `detail` = the new name); 3.36.0 runs it through `rename` like `.rename`.
    case acquire, emergency, captureLeader, limitedStrike, renamePlace

    var isPowerPlay: Bool { [.acquire, .emergency, .captureLeader, .limitedStrike, .renamePlace].contains(self) }
    /// 3.36.0: anything the President may rename (`RenameTarget.from(id:)`: his country, a land he holds, a sea, mountain
    /// or department), through `rename`, no action spent. `detail` is the new name (checked by `NameScreen` again).
    case rename
    /// 3.36.0: invest in a territory the President holds (`investInLand`, one action, era-priced).
    case developLand
    /// 3.36.0: a power play at home (`executeHomePlay`): `action` is a `HomePlay`, `mission` its mode, `target` a
    /// state, an industry or the President's own nation.
    case homePlay
    /// 3.36.0: the Antarctic programme (`runAntarcticOrder`): `mission` is an `AntarcticOrder`, `target` "ATA".
    case antarctic
}

/// One resolved order: what the engine is asked to do, against whom, with exactly which forces.
struct GameOrder: Codable, Equatable, Hashable, Sendable {
    var kind: OrderKind
    /// A country id or a land id.
    var target: String
    /// `PresidentialAction.rawValue` when `kind == .action`.
    var action: String? = nil
    /// Ground troops, thousands.
    var troops: Double? = nil
    var aircraft: Int? = nil
    var warheads: Int? = nil
    /// `USFleet.id`, `NavalMission.rawValue` and `AttackPreset.rawValue` when `kind == .fleet`.
    var fleet: String? = nil
    var mission: String? = nil
    var preset: String? = nil
    /// 3.36.0: a power play's parameter: an emergency's reason or an order's legal basis (closed lists, checked again).
    var detail: String? = nil

    var presidentialAction: PresidentialAction? { action.flatMap(PresidentialAction.init(rawValue:)) }

    /// 3.36.0: a rename and ending the emergency take no action, so they run with none left.
    var costsNoAction: Bool { kind == .rename || kind == .renamePlace || (kind == .emergency && mission == "end") }

    var isNuclear: Bool {
        if kind == .homePlay { return action == HomePlay.nuclearTest.rawValue }   // a test needs the second press too
        return presidentialAction.map { OrderWhitelist.nuclear.contains($0) } ?? false
    }

    /// One line for logs and the play history: "Air Strike → FRA (300 aircraft)".
    var summary: String {
        var what: String
        switch kind {
        case .action: what = action ?? "?"
        case .declareWar: what = "Declare War"
        case .fleet: what = "Fleet \(fleet ?? "?") \(mission ?? "?")"
        case .claimLand: what = "Claim Land"
        case .seizeColony: what = "Seize Colony"
        case .buyColony: what = "Buy Colony"
        case .backIndependence: what = "Back Independence"
        case .acquire: what = "Acquire (\(mission ?? "?"))"
        case .emergency: what = "Emergency (\(mission ?? "?")\(detail.map { ", \($0)" } ?? ""))"
        case .captureLeader: what = "Capture Leader"
        case .limitedStrike: what = "Limited Strike (\(mission ?? "?"))"
        case .renamePlace: what = "Rename (\(detail ?? "?"))"
        case .rename: what = "Rename (\(detail ?? "?"))"
        case .developLand: what = "Invest"
        case .homePlay: what = "\(action ?? "?") \(mission ?? "")"
        case .antarctic: what = "Antarctica \(mission ?? "?")"
        }
        var sizes: [String] = []
        if let t = troops { sizes.append("\(Int(t))K troops") }
        if let a = aircraft { sizes.append("\(a) aircraft") }
        if let w = warheads { sizes.append("\(w) warheads") }
        if let p = preset { sizes.append(p) }
        return "\(what) → \(target)" + (sizes.isEmpty ? "" : " (\(sizes.joined(separator: ", ")))")
    }

    /// For the play history (`command_orders` event): plain keys, no free text.
    var record: [String: Any] {
        var d: [String: Any] = ["kind": kind.rawValue, "target": target]
        if let action { d["action"] = action }
        if let troops { d["troops"] = Int(troops.rounded()) }
        if let aircraft { d["aircraft"] = aircraft }
        if let warheads { d["warheads"] = warheads }
        if let fleet { d["fleet"] = fleet }
        if let mission { d["mission"] = mission }
        if let preset { d["preset"] = preset }
        if let detail { d["detail"] = detail }
        return d
    }
}

/// Where a command's orders came from.
enum CommandSource: String, Codable, Sendable {
    /// The built-in phrase parser (no AI).
    case parser
    /// The local model translated the text; the same planner and checks then ran.
    case model
    /// Replayed from a saved record.
    case replay
    /// 3.35.0: proposed by the chief of staff in the conversation and confirmed by the President.
    case chat
    /// 3.37.0: a Situation Room button that gives the same order (the Govern sheet's INVEST).
    case sheet
}

/// What the command box carried out on one turn: the orders, never the text.
struct CommandRecord: Codable, Equatable, Sendable {
    var turn: Int
    var date: Date
    var source: CommandSource
    var orders: [GameOrder]
}

/// The orders the command box may give. Chemical and biological weapons, assassination, poisoning, terror support and
/// drug operations are not here: they stay on the escalation ladder, where the cabinet and the legal status are shown.
enum OrderWhitelist {
    static let military: Set<PresidentialAction> = [
        .groundInvasion, .airStrike, .bombardment, .navalBlockade, .amphAssault, .militaryExercise, .deployTroops,
        .withdrawTroops, .militaryAid, .sellWeapons, .makeCaseForWar,
    ]
    static let nuclear: Set<PresidentialAction> = [.launchNukes, .tacticalNuke, .strategicNuke]
    static let diplomatic: Set<PresidentialAction> = [
        .sendAmbassador, .recallAmbassador, .stateVisit, .summit, .demandApology, .severRelations, .restoreRelations,
    ]
    static let economic: Set<PresidentialAction> = [
        .economicAid, .foodAid, .tradeDeal, .imposeTariffs, .sanctions, .liftSanctions, .freezeAssets, .oilEmbargo,
    ]
    static let covert: Set<PresidentialAction> = [
        .supportRebels, .sabotageInfra, .stealTech, .cyberAttack, .deploySpies, .satellite,
    ]
    static let treaties: Set<PresidentialAction> = [.nonAggression, .joinNATO, .leaveNATO, .ceasefire, .peace, .unCondemn, .propaganda]

    static let actions: Set<PresidentialAction> = military.union(nuclear).union(diplomatic).union(economic).union(covert).union(treaties)

    static func allows(_ a: PresidentialAction) -> Bool { actions.contains(a) }
}

// MARK: - Engine

extension GameEngine {

    /// Why an order cannot be carried out right now, or nil. Checked when the plan is built and again just before
    /// each order runs (a replayed or tampered order gets the same checks).
    func orderProblem(_ o: GameOrder) -> String? {
        guard let gs = gameState, let me = gs.getPlayerCountry() else { return "No game in progress." }
        if gs.gameOver { return "The game is over." }
        if o.kind == .homePlay { return homePlayProblem(o) }   // 3.36.0: aimed at home, checked there
        guard !o.target.isEmpty, o.target.count <= 16,
              o.target.unicodeScalars.allSatisfy({ CharacterSet.alphanumerics.contains($0) || $0 == "_" }) else {
            return "Not a target."
        }
        for v in [o.troops, o.aircraft.map(Double.init), o.warheads.map(Double.init)] {
            if let v, !v.isFinite || v < 0 || v > 100_000_000 { return "Force size out of range." }
        }
        if o.kind == .rename || o.kind == .renamePlace { return renameCheck(RenameTarget.from(id: o.target, in: gs), to: o.detail ?? "").refusal }
        if o.kind.isPowerPlay { return powerPlayProblem(o) }   // 3.36.0
        if o.kind == .antarctic { return antarcticProblem(o) }   // 3.36.0: Antarctica may fly the President's own flag
        if o.target == me.id { return "That is your own nation." }
        let nation = gs.getCountry(id: o.target).flatMap { $0.isDestroyed ? nil : $0 }
        if let n = nation, n.territoryOf == me.id, o.kind != .developLand { return "\(n.name) flies your own flag." }
        switch o.kind {
        case .action:
            guard let a = o.presidentialAction, OrderWhitelist.allows(a) else { return "That order is not one the command box can give." }
            guard nation != nil else { return "No nation to aim it at." }
            guard a.isAvailable(on: gs.currentDate, in: gs) else { return "\(a.rawValue) is not available in \(gs.currentYear)." }
            if OrderWhitelist.nuclear.contains(a), me.nuclearWarheads < 1 { return "No nuclear warheads." }
            return nil
        case .declareWar:
            guard let n = nation else { return "No nation to declare war on." }
            return me.atWarWith.contains(n.id) ? "Already at war with \(n.name)." : nil
        case .fleet:
            guard let f = o.fleet, let m = o.mission.flatMap(NavalMission.init(rawValue:)),
                  o.preset.flatMap(AttackPreset.init(rawValue:)) != nil else { return "Not a fleet order." }
            return fleetOrderProblem(fleetID: f, target: o.target, mission: m)
        case .claimLand:
            guard gs.unclaimedLandIDs.contains(o.target) || gs.indigenousLandIDs.contains(o.target) else {
                return "That land is not free to claim in \(gs.currentYear)."
            }
            return (o.troops ?? 0) >= 1 ? nil : "An expedition needs troops."
        case .seizeColony:
            guard colonyTarget(o.target) != nil else { return "Not a colony in \(gs.currentYear)." }
            return (o.troops ?? 0) >= 1 ? nil : "An expedition needs troops."
        case .buyColony, .backIndependence:
            return colonyTarget(o.target) == nil ? "Not a colony in \(gs.currentYear)." : nil
        case .acquire, .emergency, .captureLeader, .limitedStrike:
            return powerPlayProblem(o)
        case .rename, .renamePlace:
            return nil   // checked above
        case .developLand:
            return LandDevelopment.problem(o.target, in: gs)
        case .homePlay:
            return homePlayProblem(o)
        case .antarctic:
            return antarcticProblem(o)
        }
    }

    /// Carry out one order through its engine verb. Returns whether it went through (an order the engine refused
    /// costs no action, the 3.28.2 rule).
    @discardableResult
    func executeOrder(_ o: GameOrder) -> Bool {
        guard orderProblem(o) == nil, let gs = gameState, gs.actionsRemaining > 0 || o.costsNoAction else { return false }
        switch o.kind {
        case .action:
            guard let a = o.presidentialAction else { return false }
            var size: AttackSize?
            if !AttackSizing.kinds(for: a).isEmpty {
                var s = AttackSizing.standard(a, in: gs)
                if let t = o.troops { s.troops = t }
                if let n = o.aircraft { s.aircraft = n }
                if let w = o.warheads { s.warheads = w }
                size = s
            }
            actionResult = nil
            performAdvisedAction(a, targetID: o.target, advice: advice(for: a, targetID: o.target), size: size)
            return actionResult?.success != false
        case .declareWar:
            declareWar(aggressor: gs.playerCountryID, defender: o.target)
            recordPlayerAction(rung: .military, hostile: true, detected: false)
            completePlayerAction()
            return true
        case .fleet:
            guard let f = o.fleet, let m = o.mission.flatMap(NavalMission.init(rawValue:)),
                  let p = o.preset.flatMap(AttackPreset.init(rawValue:)) else { return false }
            return orderFleet(f, to: o.target, mission: m, preset: p) != nil
        case .claimLand:
            let troops = o.troops ?? AttackSizing.expeditionStandard
            if gs.indigenousLandIDs.contains(o.target) { return claimIndigenousLand(o.target, troops: troops) != nil }
            return claimLand(o.target, troops: troops)
        case .seizeColony:
            return seizeColony(o.target, troops: o.troops ?? AttackSizing.expeditionStandard) != nil
        case .buyColony:
            return purchaseColony(o.target) != nil
        case .backIndependence:
            return supportIndependence(o.target) != nil
        case .acquire, .emergency, .captureLeader, .limitedStrike:
            return executePowerPlay(o)
        case .rename, .renamePlace:
            return rename(RenameTarget.from(id: o.target, in: gs), to: o.detail ?? "").succeeded
        case .developLand:
            return investInLand(o.target)
        case .homePlay:
            return executeHomePlay(o)
        case .antarctic:
            guard let op = o.mission.flatMap(AntarcticOrder.init(rawValue:)) else { return false }
            return runAntarcticOrder(op)
        }
    }

    /// The result of carrying out a command's orders.
    struct CommandExecution: Equatable {
        var carried: [GameOrder] = []
        var refused: [GameOrder] = []
        /// Orders left over when the turn's actions ran out.
        var notReached: [GameOrder] = []
        /// What the orders wrote to the game log, in order.
        var lines: [String] = []
    }

    /// Carry out a confirmed command, in order, while actions remain. Records the resolved orders (not the text) on
    /// the game and in the play history.
    @discardableResult
    func executeCommand(_ orders: [GameOrder], source: CommandSource) -> CommandExecution {
        var out = CommandExecution()
        guard let gs = gameState else { out.notReached = orders; return out }
        let turn = gs.turn, date = gs.currentDate
        for (i, o) in orders.enumerated() {
            guard let now = gameState, !now.gameOver, now.actionsRemaining > 0 || o.costsNoAction else {
                out.notReached = Array(orders[i...])
                break
            }
            let logStart = logMessages.count
            if executeOrder(o) { out.carried.append(o) } else { out.refused.append(o) }
            let start = min(logStart, logMessages.count)
            out.lines += logMessages[start...].map(\.message).filter { !$0.isEmpty }
        }
        // The command box shows the outcome itself; no second pop-up.
        actionResult = nil
        if !out.carried.isEmpty, let gs = gameState {
            gs.shadow.commandLog.append(CommandRecord(turn: turn, date: date, source: source, orders: out.carried))
            if gs.shadow.commandLog.count > ShadowState.commandLogCap {
                gs.shadow.commandLog.removeFirst(gs.shadow.commandLog.count - ShadowState.commandLogCap)
            }
            self.gameState = gs
            logPlayEvent("command_orders", detail: ["source": source.rawValue, "turn": turn,
                                                    "orders": out.carried.map(\.record),
                                                    "refused": out.refused.count, "not_reached": out.notReached.count,
                                                    "game_date": PlayHistory.day(date)])
        }
        Log.commands.info("command: \(out.carried.count) carried, \(out.refused.count) refused, \(out.notReached.count) not reached")
        return out
    }
}
