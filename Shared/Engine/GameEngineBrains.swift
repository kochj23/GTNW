//
//  GameEngineBrains.swift
//  Global Thermal Nuclear War
//
//  Turn-loop integration for the "brain per country" system plus the reversible
//  agency verbs (abort launch, sue-for-peace, leave alliance).
//
//  Perf note: the old AI loop made ~195 SERIAL LLM calls with a 200ms main-thread
//  sleep each. Here, only countries whose brain is NOT rule-based make a call,
//  those calls run CONCURRENTLY in a TaskGroup off the main actor, and there is
//  no blocking sleep. Rule-based countries resolve locally. Every remote call is
//  bounded by a timeout that falls back to rule-based AI.
//
//  Created by Jordan Koch on 2026.
//

import Foundation
import NovaAIKit

/// Whose turn it is, for the UI banner and action gating.
enum TurnPhase: Equatable {
    case playerInput   // ▶ YOUR TURN — player may act
    case resolving     // ⏳ WORLD RESOLVING — brains/AI acting, actions disabled
    case results       // brief post-resolution state
}

/// An armed nuclear launch awaiting resolution — cancellable during its window.
struct PendingLaunch: Equatable {
    let from: String
    let to: String
    let warheads: Int
    let scheduledTurn: Int
}

extension GameEngine {

    // MARK: - Brain assignment

    /// The brain driving a country. The player's own country is `.human` (rule-based while spectating); every
    /// other unassigned country is `.ruleBased` (preserving existing behavior).
    func brain(for countryID: String) -> AIBrain {
        if let assigned = brainAssignments[countryID] { return assigned }
        if let gs = gameState, gs.playerCountryID == countryID { return spectating ? .ruleBased : .human }
        return .ruleBased
    }

    /// Assign (or clear back to default) a brain for a country.
    func setBrain(_ brain: AIBrain, for countryID: String) {
        brainAssignments[countryID] = brain
    }

    // MARK: - Turn loop (concurrent, non-blocking)

    /// Resolve every non-player, non-destroyed country's move via its brain.
    @MainActor
    func processAITurnsWithBrains() async {
        guard let gameState = gameState else { return }
        lastTurnFallbackCountryIDs = []

        // Partition countries by brain on the main actor (reads state safely).
        var remoteJobs: [(id: String, brain: AIBrain, request: MoveRequest)] = []   // `var`: thinkers only, below
        var ruleBasedIDs: [String] = []
        // Global "Use AI" switch: off means every automated country plays the built-in rule-based AI and no
        // brain request leaves the app.
        let aiOn = AppAI.shared.isEnabled

        // While spectating, the player's seat is just another country played by its brain.
        for country in gameState.countries where (spectating || !country.isPlayerControlled) && !country.isDestroyed && !country.isTerritory {
            let assigned = brain(for: country.id)
            switch assigned {
            case .human:
                continue                       // human-driven — no automated move
            case .ruleBased:
                ruleBasedIDs.append(country.id)
            default:
                if aiOn, let request = buildMoveRequest(for: country.id) {
                    remoteJobs.append((country.id, assigned, request))
                } else {
                    ruleBasedIDs.append(country.id)
                }
            }
        }

        // 3.27.0 slow strategic layer (after Quake 3's staggered bot think times): a model brain thinks every N turns,
        // staggered by nation, and at most `maxBrainCallsPerTurn` think in one turn; the others play the fast built-in
        // controller this turn (not a fallback).
        let thinking = remoteJobs.filter { brainThinks($0.id, turn: gameState.turn) }
            .sorted { CountryProfile.stableUnit($0.id + "\(gameState.turn)") < CountryProfile.stableUnit($1.id + "\(gameState.turn)") }
        let thinkingIDs = Set(thinking.prefix(Self.maxBrainCallsPerTurn).map(\.id))
        ruleBasedIDs += remoteJobs.filter { !thinkingIDs.contains($0.id) }.map(\.id)
        remoteJobs = remoteJobs.filter { thinkingIDs.contains($0.id) }

        // Ask every thinking brain CONCURRENTLY, off the main actor. Every answer goes through the one validator;
        // a refused answer is asked again with the reason, at most `maxReasks` times, then the built-in AI plays.
        var accepted: [(id: String, response: MoveResponse)] = []
        var intentSwitches = 0
        var pending = remoteJobs
        if !remoteJobs.isEmpty { addLog("🧠 Consulting \(remoteJobs.count) brain(s) concurrently…", type: .info) }
        for attempt in 0...Self.maxReasks where !pending.isEmpty {
            let answers = await askBrains(pending)
            var again: [(id: String, brain: AIBrain, request: MoveRequest)] = []
            for job in pending {
                let (response, ms) = answers[job.id] ?? (nil, 0)
                var reason: String? = response == nil ? "no answer" : nil
                if let response {
                    switch validateMove(response, for: job.id) {
                    case .failure(let why): reason = why.reason
                    case .success(let (action, _)):
                        reason = intentRefusal(job.id, intent: action.intent, switches: &intentSwitches)
                    }
                }
                let last = response == nil || attempt == Self.maxReasks
                logBrainReply(job.id, brain: job.brain, response: response, latencyMs: ms, attempt: attempt,
                              refused: reason, fallback: reason != nil && last)
                if reason == nil, let response {
                    accepted.append((job.id, response))
                } else if !last, let reason {
                    var request = job.request
                    request.previousError = reason
                    again.append((job.id, job.brain, request))
                } else {
                    applyRuleBasedAction(for: job.id)          // swap the source: the built-in AI plays this turn
                    lastTurnFallbackCountryIDs.insert(job.id)
                }
            }
            pending = again
        }

        // Apply the accepted moves on the main actor (mutations are serialized here).
        for (id, response) in accepted {
            if applyMove(response, for: id) == .rejectedIllegal {   // legal but failed (e.g. peace refused)
                applyRuleBasedAction(for: id)
                lastTurnFallbackCountryIDs.insert(id)
            } else if let action = MoveAction(rawValue: response.action.trimmingCharacters(in: .whitespaces).uppercased()) {
                brainIntents[id] = action.intent
            }
        }

        // Rule-based countries resolve locally. Each acts about four times a game year (at most once a turn),
        // so shorter turns don't make the world more hyperactive.
        let actChance = aiActionProbability(gameState)
        for id in ruleBasedIDs where Double.random(in: 0..<1, using: &gameState.rng) < actChance {
            applyRuleBasedAction(for: id)
        }
        // A watch session counts every built-in substitution for its matchup (WATCH-CONTRACT `fallbacks`).
        if let t = playSession, t.spectator, t.game === gameState {
            t.aiEnabled = aiOn
            for id in lastTurnFallbackCountryIDs { t.fallbacks[id, default: 0] += 1 }
        }
    }

    /// Every brain at most this many re-asks per turn (WATCH-CONTRACT: "re-asked up to 2 times").
    static let maxReasks = 2
    /// At most this many model brains think in one turn; the rest play the built-in controller.
    static let maxBrainCallsPerTurn = 16
    /// At most this many nations may change strategic intent in one turn (after Quake 3 MAX_NODESWITCHES).
    static let maxIntentSwitchesPerTurn = 4

    /// Does this nation's brain think this turn? Every `thinkEveryTurns` (from its character; at least weekly
    /// game time on day-length turns), staggered by nation so the calls spread over the turns.
    func brainThinks(_ id: String, turn: Int) -> Bool {
        guard let gs = gameState, let c = gs.getCountry(id: id) else { return true }
        let every = max(NationCharacterTable.shared.character(for: c, difficulty: gs.difficultyLevel).thinkEveryTurns,
                        gs.turnLength == .day ? 7 : 1)
        return (turn + Int(CountryProfile.stableUnit(id, salt: 31) * Double(every))) % every == 0
    }

    /// Nil when the move may stand; otherwise why it can't (the intent-switch cap for this turn).
    func intentRefusal(_ id: String, intent: String, switches: inout Int) -> String? {
        guard let old = brainIntents[id], old != intent else { return nil }
        guard switches < Self.maxIntentSwitchesPerTurn else {
            return "too many nations changed course this turn; hold your current intent (\(old))"
        }
        switches += 1
        addLog("🧭 \(gameState?.getCountry(id: id)?.name ?? id) changes course: \(old) → \(intent)", type: .info)
        logPlayEvent("brain_intent_switch", detail: ["side": id, "from": old, "to": intent, "turn": gameState?.turn ?? 0])
        return nil
    }

    /// One round of brain calls, concurrently off the main actor: each answer with its latency in milliseconds.
    @MainActor
    private func askBrains(_ jobs: [(id: String, brain: AIBrain, request: MoveRequest)]) async -> [String: (MoveResponse?, Int)] {
        var config = brainConfig
        if config.engine == nil { config.engine = AppAI.shared.engine }
        let override = brainTransportOverride
        return await withTaskGroup(of: (String, MoveResponse?, Int).self) { group in
            for job in jobs {
                group.addTask {
                    let t0 = Date()
                    let resp: MoveResponse?
                    if let override {
                        resp = await override(job.request, job.brain)
                    } else {
                        resp = await BrainClient.requestMove(job.request, brain: job.brain, config: config)
                    }
                    return (job.id, resp, Int(Date().timeIntervalSince(t0) * 1000))
                }
            }
            var out: [String: (MoveResponse?, Int)] = [:]
            for await (id, resp, ms) in group { out[id] = (resp, ms) }
            return out
        }
    }

    /// The NovaAIKit backend id and model a brain's moves come from (nil for the built-in engine).
    func brainSource(_ b: AIBrain) -> (backend: String?, model: String?) {
        switch b {
        case .kit(let backend, let model): return (backend, model.isEmpty ? nil : model)
        case .liveSession: return ("live_session", nil)
        default:
            let t = BrainRoute.target(for: b, gatewayBaseURL: "", gatewayModel: brainConfig.gatewayModel)
            return (t?.backend.rawValue, t?.model)
        }
    }

    /// The record is the source of truth (after Quake 3's journal): every model reply is an event with its side,
    /// source, latency, a short excerpt and a hash, and whether it stood or the built-in AI took over. A journal or
    /// replay reads these; it never calls a model again.
    func logBrainReply(_ id: String, brain: AIBrain, response: MoveResponse?, latencyMs: Int, attempt: Int,
                       refused: String?, fallback: Bool) {
        let src = brainSource(brain)
        var d: [String: Any] = ["side": id, "backend": src.backend ?? NSNull(), "model": src.model.map(PlayHistory.text) ?? NSNull(),
                                "attempt": attempt, "latency_ms": max(0, latencyMs), "valid": refused == nil,
                                "fallback": fallback, "turn": gameState?.turn ?? 0]
        if let refused { d["refused"] = PlayHistory.text(String(refused.prefix(200))) }
        if let r = response {
            let raw = "\(r.action)|\(r.target ?? "")|\(r.rationale ?? "")"
            d["action"] = PlayHistory.text(String(r.action.prefix(40)))
            if let t = r.target { d["target"] = PlayHistory.text(String(t.prefix(40))) }
            d["excerpt"] = PlayHistory.text(String((r.rationale ?? "").prefix(160)))
            d["reply_hash"] = String(format: "%016llx", Self.fnv1a(raw))
        }
        logPlayEvent("brain_reply", detail: d)
    }

    static func fnv1a(_ s: String) -> UInt64 {
        var h: UInt64 = 0xcbf29ce484222325
        for b in s.utf8 { h ^= UInt64(b); h = h &* 0x100000001b3 }
        return h
    }

    /// Fast built-in rule-based move for one country.
    func applyRuleBasedAction(for countryID: String) {
        guard let gs = gameState, let country = gs.getCountry(id: countryID) else { return }
        // Countries at war in the nuclear age may escalate; ruthless leaders far more readily.
        if !country.atWarWith.isEmpty, country.nuclearWarheads > 0, gs.defconLevel.rawValue <= 2,
           let enemy = country.atWarWith.first,
           Double.random(in: 0..<1, using: &gs.rng) < Double(country.profile.ambition) / 6 * 0.25 * gs.difficultyLevel.aiAggressionMultiplier
               * NationCharacterTable.shared.character(for: country, difficulty: gs.difficultyLevel).risk {
            executeAIAction(.launchNuclearStrike(target: enemy, warheads: min(3, country.nuclearWarheads)), for: country, reason: nil)
            return
        }
        // Otherwise the leader's personality and anxieties pick the move (see CountryProfile.swift).
        executeWorldMove(PersonalityAI.choose(for: country, in: gs, roll: Double.random(in: 0..<1, using: &gs.rng)), for: country)
    }

    // MARK: - Spectator mode (3.25.0): "Watch AI vs AI"

    /// Speed control: seconds between spectated turns.
    static let spectatorSpeeds: [(label: String, delay: Double)] = [("Slow", 5), ("Normal", 2), ("Fast", 0.5), ("Max", 0)]

    /// A new game the player only watches. The seat is played by its brain like every other country (Brains panel;
    /// rule-based unless assigned, and rule-based whenever AI is off), and the turns run by themselves.
    func startSpectatorGame(playerCountryID: String = "USA", difficulty: DifficultyLevel = .normal,
                            administration: Administration? = nil, turnLength: TurnLength = TurnLength.defaultForNewGames()) {
        startNewGame(playerCountryID: playerCountryID, difficulty: difficulty, administration: administration,
                     turnLength: turnLength, spectate: true)
        spectatorPaused = false
        addLog("👁 SPECTATING: the computer plays \(playerCountryID) too (recorded as AI vs AI). Take the seat at any time.", type: .system)
        spectatorLoop?.cancel()
        spectatorLoop = Task { @MainActor [weak self] in
            while !Task.isCancelled, let self, self.spectating, self.gameState?.gameOver == false {
                if !self.spectatorPaused, !self.isProcessingAITurn { self.spectatorTurn() }
                try? await Task.sleep(nanoseconds: UInt64(max(0.05, self.spectatorDelay) * 1_000_000_000))
            }
        }
    }

    /// One spectated turn: the seat answers what is on its desk (the advised option, else the likeliest to work;
    /// surrender terms the way the computer settles them), then ends the turn as the player would.
    func spectatorTurn() {
        guard spectating, var gs = gameState, !gs.gameOver else { return }
        while let crisis = crisisManager.activeCrisis {
            let o = crisis.options
            guard let pick = o.indices.first(where: { o[$0].advisorRecommendation != nil })
                    ?? o.indices.max(by: { o[$0].successChance < o[$1].successChance }) else {
                crisisManager.activeCrisis = nil
                crisisManager.presentNextPending(gameState: gs)
                continue
            }
            crisisManager.resolveCrisis(optionIndex: pick, gameState: &gs)
        }
        gameState = gs
        for s in gs.shadow.pendingSettlements { settle(s.id, choice: .victorsModel) }
        endTurn()
    }

    /// Take over the watched seat: the turns stop running themselves. The watch session ends as "taken_over" and
    /// the game is his from here on, logged like a continued save (a new play session from this turn).
    func takeSeat() {
        guard spectating else { return }
        endPlaySession(outcome: "taken_over")
        spectating = false
        spectatorPaused = false
        spectatorLoop?.cancel()
        spectatorLoop = nil
        beginPlaySession(resumedFromTurn: gameState?.turn)
        addLog("🎮 You have the seat. The turn is yours.", type: .system)
    }

    /// `summary.matchup` for a watch session: the seat, every nation given a brain other than rule-based, and the
    /// rest of the world. `backend` / `model` are the NovaAIKit ids a model brain is pinned to (null otherwise).
    func watchMatchup(_ gs: GameState, aiEnabled: Bool = true) -> [String: Any] {
        func side(_ id: String) -> [String: Any] {
            let b = brain(for: id)
            let model = aiEnabled && b.needsRemoteMove
            let src: (backend: String?, model: String?) = model ? brainSource(b) : (nil, nil)
            let name = gs.getCountry(id: id)?.name ?? id
            return ["side": id, "kind": model ? "model" : "engine",
                    "backend": src.backend ?? NSNull(), "model": src.model.map(PlayHistory.text) ?? NSNull(),
                    "label": PlayHistory.text("\(name): \(model ? b.displayName : "GTNW rule-based AI")")]
        }
        let seat = gs.playerCountryID
        let others = brainAssignments.filter { $0.key != seat && $0.value != .ruleBased && $0.value != .human }
            .keys.filter { gs.getCountry(id: $0)?.isDestroyed == false }.sorted().prefix(16)
        return ["sides": [side(seat)] + others.map(side)
                + [["side": "world", "kind": "npc", "backend": NSNull(), "model": NSNull(),
                    "label": "Every other nation: GTNW rule-based AI"]]]
    }

    // MARK: - Reversible / agency verbs

    /// Arm a nuclear launch that can be recalled with `abortLaunch()` before it
    /// resolves — the WarGames "the only winning move is not to play" premise.
    func scheduleLaunch(from: String, to: String, warheads: Int) {
        guard let gs = gameState else { return }
        let n = max(1, warheads)
        pendingLaunch = PendingLaunch(from: from, to: to, warheads: n, scheduledTurn: gs.turn)
        addLog("", type: .system)
        addLog("⏳ LAUNCH ARMED — \(n) warhead(s) targeting \(getCountry(to)?.name ?? to)", type: .warning)
        addLog("   ABORT WINDOW OPEN — recall now or confirm to fire.", type: .warning)
    }

    /// Cancel an armed launch. Returns true if a launch was aborted.
    @discardableResult
    func abortLaunch() -> Bool {
        guard let p = pendingLaunch else { return false }
        pendingLaunch = nil
        addLog("🛑 LAUNCH ABORTED — \(p.warheads) warhead(s) recalled. The only winning move is not to play.", type: .info)
        return true
    }

    /// Fire an armed launch. Returns true if a launch resolved.
    @discardableResult
    func resolvePendingLaunch() -> Bool {
        guard let p = pendingLaunch else { return false }
        pendingLaunch = nil
        launchNuclearStrike(from: p.from, to: p.to, warheads: p.warheads)
        return true
    }

    /// Sue for peace / ceasefire: actually clears `activeWars` and `atWarWith`
    /// between two countries (previously only bribery via economicDiplomacy could
    /// end a war). Returns true if a war was ended.
    @discardableResult
    func sueForPeace(from: String, to: String) -> Bool {
        guard let gs = gameState else { return false }
        let wasAtWar = (gs.getCountry(id: from)?.atWarWith.contains(to) ?? false) ||
                       (gs.getCountry(id: to)?.atWarWith.contains(from) ?? false)

        if let i = gs.countries.firstIndex(where: { $0.id == from }) { gs.countries[i].atWarWith.remove(to) }
        if let j = gs.countries.firstIndex(where: { $0.id == to }) { gs.countries[j].atWarWith.remove(from) }

        let before = gs.activeWars.count
        gs.activeWars.removeAll {
            ($0.aggressor == from && $0.defender == to) || ($0.aggressor == to && $0.defender == from)
        }
        let endedWar = wasAtWar || (before != gs.activeWars.count)

        modifyDiplomaticRelation(from: from, to: to, by: 25)
        modifyDiplomaticRelation(from: to, to: from, by: 25)

        if endedWar {
            gs.conflictsMediated += 1
            addLog("", type: .system)
            addLog("🕊️ CEASEFIRE — \(getCountry(from)?.name ?? from) and \(getCountry(to)?.name ?? to) end hostilities.", type: .info)
            updateDEFCONPublic()
        }
        self.gameState = gs
        return endedWar
    }

    /// Leave / defect from an alliance. Mutates `alliances` on both sides and
    /// increments the (previously never-incremented) `alliancesBroken` stat.
    @discardableResult
    func leaveAlliance(country: String, from allyID: String) -> Bool {
        guard let gs = gameState else { return false }
        guard let i = gs.countries.firstIndex(where: { $0.id == country }),
              gs.countries[i].alliances.contains(allyID) else { return false }

        gs.countries[i].alliances.remove(allyID)
        if let j = gs.countries.firstIndex(where: { $0.id == allyID }) {
            gs.countries[j].alliances.remove(country)
        }
        gs.treaties.removeAll {
            $0.type == .alliance && $0.signatories.contains(country) && $0.signatories.contains(allyID)
        }
        gs.alliancesBroken += 1
        self.gameState = gs

        modifyDiplomaticRelation(from: allyID, to: country, by: -30)
        addLog("💔 \(getCountry(country)?.name ?? country) LEFT its alliance with \(getCountry(allyID)?.name ?? allyID).", type: .warning)
        return true
    }

    /// Public shim so extension verbs can nudge DEFCON back toward peace.
    private func updateDEFCONPublic() {
        guard let gs = gameState else { return }
        if gs.activeWars.isEmpty && gs.defconLevel.rawValue < 5 {
            let newLevel = DefconLevel(rawValue: min(5, gs.defconLevel.rawValue + 1)) ?? .defcon5
            gs.defconLevel = newLevel
            self.gameState = gs
        }
    }
}
