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

    /// The brain driving a country. The player's own country is `.human`; every
    /// other unassigned country is `.ruleBased` (preserving existing behavior).
    func brain(for countryID: String) -> AIBrain {
        if let assigned = brainAssignments[countryID] { return assigned }
        if let gs = gameState, gs.playerCountryID == countryID { return .human }
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
        var remoteJobs: [(id: String, brain: AIBrain, request: MoveRequest)] = []
        var ruleBasedIDs: [String] = []

        for country in gameState.countries where !country.isPlayerControlled && !country.isDestroyed {
            let assigned = brain(for: country.id)
            switch assigned {
            case .human:
                continue                       // human-driven — no automated move
            case .ruleBased:
                ruleBasedIDs.append(country.id)
            default:
                if let request = buildMoveRequest(for: country.id) {
                    remoteJobs.append((country.id, assigned, request))
                } else {
                    ruleBasedIDs.append(country.id)
                }
            }
        }

        // Fire all remote brain calls CONCURRENTLY, off the main actor.
        var responses: [String: MoveResponse] = [:]
        if !remoteJobs.isEmpty {
            addLog("🧠 Consulting \(remoteJobs.count) brain(s) concurrently…", type: .info)
            let config = brainConfig
            let override = brainTransportOverride
            responses = await withTaskGroup(of: (String, MoveResponse?).self) { group in
                for job in remoteJobs {
                    group.addTask {
                        let resp: MoveResponse?
                        if let override {
                            resp = await override(job.request, job.brain)
                        } else {
                            resp = await BrainClient.requestMove(job.request, brain: job.brain, config: config)
                        }
                        return (job.id, resp)
                    }
                }
                var out: [String: MoveResponse] = [:]
                for await (id, resp) in group {
                    if let resp { out[id] = resp }
                }
                return out
            }
        }

        // Apply results on the main actor (mutations are serialized here).
        for job in remoteJobs {
            if let resp = responses[job.id] {
                let outcome = applyMove(resp, for: job.id)
                if outcome == .rejectedIllegal {
                    // Bad/illegal answer — fall back so the country still acts.
                    applyRuleBasedAction(for: job.id)
                    lastTurnFallbackCountryIDs.insert(job.id)
                }
            } else {
                // Timeout / no answer — graceful fallback to rule-based AI.
                applyRuleBasedAction(for: job.id)
                lastTurnFallbackCountryIDs.insert(job.id)
            }
        }

        // Rule-based countries resolve locally.
        for id in ruleBasedIDs {
            applyRuleBasedAction(for: id)
        }
    }

    /// Fast built-in rule-based move for one country.
    func applyRuleBasedAction(for countryID: String) {
        guard let country = gameState?.getCountry(id: countryID) else { return }
        let action = determineAIActionEnhanced(for: country)
        executeAIAction(action, for: country, reason: nil)
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
