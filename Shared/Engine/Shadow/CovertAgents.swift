//
//  CovertAgents.swift
//  Global Thermal Nuclear War
//
//  The covert behavioural-agents programme (3.31.0), after the CIA's MKUltra (authorised April 1953, exposed by the
//  Church Committee and the Rockefeller Commission in 1975). Deliberately abstract: three agent CLASSES and three
//  delivery VECTORS, modelled only as a decision and its consequences on game stats. No substances, quantities or
//  methods appear anywhere in the game.
//    • Ladder: the research programme first (a dirty tactic, `covert_agents`: one action, $2B, a year; then a running
//      cost and a domestic leak risk that grows with time and use), then operations against a nation from its dossier.
//    • Era and law: nothing before 1953; the aerosol vector from 1962. Restricted (Nuremberg Code) until the
//      Biological Weapons Convention (1975), then treaty-banned (and under the CWC from 1997): exposure brings the
//      tribunal risk of the dirty-tactics machinery.
//    • Exposure: a Church Committee–style scandal at home, retaliation abroad, a Hall of Infamy entry.
//    • Computer-run rivals can run it against the player: a "covert contamination suspected" decision.
//  Game-balance numbers are design choices.
//  Repository: https://github.com/kochj23/GTNW
//

import Foundation

/// What an agent class does to a population, in the abstract.
enum AgentClass: String, Codable, CaseIterable, Identifiable {
    case hallucinogenic, stimulant, depressant
    var id: String { rawValue }

    var title: String {
        switch self {
        case .hallucinogenic: return "Hallucinogenic agents"
        case .stimulant: return "Stimulant agents"
        case .depressant: return "Depressant agents"
        }
    }

    var effect: String {
        switch self {
        case .hallucinogenic: return "Disorientation and paranoia: stability and will to fight fall, unrest rises. Short and sharp."
        case .stimulant: return "Agitation and sleeplessness: a brief burst of output, then a crash; riots, indiscipline, and a risk the target lashes out at someone."
        case .depressant: return "Lethargy and apathy: output and readiness fall, unrest falls too. Slower, steadier."
        }
    }

    /// Weeks the effect lasts by the water vector (others scale it).
    var weeks: Double {
        switch self {
        case .hallucinogenic: return 3
        case .stimulant: return 6
        case .depressant: return 10
        }
    }
}

/// How an operation reaches a population, in the abstract.
enum AgentVector: String, Codable, CaseIterable, Identifiable {
    case water, food, air
    var id: String { rawValue }

    var title: String {
        switch self {
        case .water: return "Water supply"
        case .food: return "Food supply"
        case .air: return "Air"
        }
    }

    /// strength, duration and discovery multipliers, and the extra price if traced.
    var profile: (strength: Double, duration: Double, discovery: Double, exposure: Double) {
        switch self {
        case .water: return (1.0, 0.75, 1.5, 1.0)    // broad and fast, the likeliest to be noticed
        case .food: return (0.7, 1.5, 0.8, 1.0)      // slower, deniable, lasts longer
        case .air: return (1.3, 0.5, 1.2, 1.5)       // the hardest to mount, the worst if traced
        }
    }
}

/// An operation still taking effect.
struct AgentOperation: Codable, Hashable, Identifiable {
    var id = UUID()
    var target: String
    var agent: AgentClass
    var vector: AgentVector
    var date: Date
    var strength: Double
    var weeks: Double
    var weeksLeft: Double
    /// Who ran it (the player, or a computer-run rival).
    var by: String
}

enum CovertAgents {
    static let firstYear = 1953
    static let airYear = 1962
    static let programCost = 2.0
    /// $B a year while the programme runs.
    static let runningCost = 0.4
    /// $B an operation costs.
    static let operationCost = 0.3
    /// Chance a bystander nation (a neighbour or ally of the target) is caught by the same operation.
    static let spillChance = 0.08
    /// Under tests rivals don't run operations unless a test asks.
    nonisolated(unsafe) static var aiEnabled = !GameStoreService.isTestOrSmokeRun

    /// Chance one operation is traced: 6% × the era's exposure × the vector × (1 + 25% per earlier operation), ≤ 90%.
    static func discoveryChance(vector: AgentVector, year: Int, priorOps: Int) -> Double {
        min(0.9, 0.06 * DirtyTactics.eraExposure(year: year) * vector.profile.discovery * (1 + 0.25 * Double(priorOps)))
    }

    /// Chance a year the programme itself leaks at home: grows with the era, its years running and its operations.
    static func programLeakAnnual(year: Int, yearsRunning: Double, ops: Int) -> Double {
        min(0.6, 0.04 * DirtyTactics.eraExposure(year: year) * (1 + 0.1 * yearsRunning + 0.1 * Double(ops)))
    }

    static var tactic: DirtyTactic { DirtyTactics.tactic("covert_agents")! }
}

extension GameEngine {
    /// Why an operation can't be ordered, or nil.
    func agentProblem(target: String, agent: AgentClass, vector: AgentVector) -> String? {
        guard let gs = gameState else { return "No game." }
        guard gs.playerCountryID == "USA" else { return "Only the United States has this option." }
        guard gs.currentYear >= CovertAgents.firstYear else { return DirtyTactics.eraReason(CovertAgents.tactic, year: gs.currentYear) }
        guard gs.shadow.agentProgramSince != nil else { return "The research programme must be running first (TACTICS → Chemical and biological)." }
        if vector == .air && gs.currentYear < CovertAgents.airYear { return "No aerosol capability until the 1960s." }
        guard let c = gs.getCountry(id: target), c.id != gs.playerCountryID, !c.isDestroyed, !c.isTerritory else { return "Pick a nation." }
        guard gs.actionsRemaining > 0 else { return "No actions left this turn." }
        return nil
    }

    /// Order an operation (one action, money). `discoveryRoll`, `spillRoll` and `backfireRoll` for tests.
    @discardableResult
    func runAgentOperation(target: String, agent: AgentClass, vector: AgentVector,
                           discoveryRoll: Double? = nil, spillRoll: Double? = nil,
                           backfireRoll: Double? = nil) -> AgentOperation? {
        let discoveryRoll = discoveryRoll ?? gameRoll()
        let spillRoll = spillRoll ?? gameRoll()
        let backfireRoll = backfireRoll ?? gameRoll()
        guard agentProblem(target: target, agent: agent, vector: vector) == nil, let gs = gameState else { return nil }
        let op = launchAgents(by: gs.playerCountryID, target: target, agent: agent, vector: vector, spillRoll: spillRoll, backfireRoll: backfireRoll)
        spendFunds(CovertAgents.operationCost)
        gs.shadow.ruthlessness += DirtyTactics.cost(CovertAgents.tactic, year: gs.currentYear).ruthlessness * DirtyTactics.quietShare
        var use = TacticUse(tactic: "covert_agents", target: target, date: gs.currentDate, covert: true, scale: op.strength)
        use.discovered = discoveryRoll < CovertAgents.discoveryChance(vector: vector, year: gs.currentYear, priorOps: gs.shadow.agentOpsRun)
        gs.shadow.agentOpsRun += 1
        gs.shadow.tacticUses.append(use)
        gs.shadow.logWar("\(GameCalendar.format(gs.currentDate)): covert \(agent.title.lowercased()) operation, \(vector.title.lowercased()).")
        logPlayEvent("agent_operation", detail: ["target": target, "agent": agent.rawValue, "vector": vector.rawValue,
                                                 "discovered": use.discovered, "game_date": PlayHistory.day(gs.currentDate)])
        self.gameState = gs
        if use.discovered { exposeAgentOperation(use.id, vector: vector) }
        completePlayerAction()
        return op
    }

    /// Start an operation's effects (player or rival), with the chance of a bystander and of a stimulant backfire.
    @discardableResult
    func launchAgents(by actor: String, target: String, agent: AgentClass, vector: AgentVector, spillRoll: Double, backfireRoll: Double) -> AgentOperation {
        let v = vector.profile
        let weeks = agent.weeks * v.duration
        let op = AgentOperation(target: target, agent: agent, vector: vector, date: gameState?.currentDate ?? Date(),
                                strength: v.strength, weeks: weeks, weeksLeft: weeks, by: actor)
        guard let gs = gameState else { return op }
        gs.shadow.agentOps.append(op)
        let name = gs.getCountry(id: target)?.name ?? target
        gs.shadow.post("Reports from \(name): unexplained \(agent == .depressant ? "lethargy" : (agent == .stimulant ? "agitation" : "disorientation")) spreads through several cities.",
                       date: gs.currentDate, severity: 1)
        // A bystander: a neighbour or ally of the target caught by the same operation at half strength.
        if spillRoll < CovertAgents.spillChance {
            let near = Reach.landNeighbors(target, in: gs).union(gs.getCountry(id: target)?.alliances ?? []).subtracting([actor]).sorted()
            if let b = near.first(where: { gs.getCountry(id: $0).map { !$0.isDestroyed && !$0.isTerritory } == true }) {
                var spill = op
                spill.id = UUID(); spill.target = b; spill.strength *= 0.5
                gs.shadow.agentOps.append(spill)
                gs.shadow.post("The same symptoms appear across the border in \(gs.getCountry(id: b)?.name ?? b).", date: gs.currentDate, severity: 1)
            }
        }
        // Stimulants can turn a government's aggression outward.
        if agent == .stimulant, backfireRoll < 0.15 * op.strength, let t = gs.getCountry(id: target) {
            let victims = gs.countries.filter { $0.id != target && !$0.isDestroyed && !$0.isTerritory && !t.alliances.contains($0.id)
                && !t.atWarWith.contains($0.id) && Reach.canReach(target, $0.id, in: gs) }
            if let v = victims.min(by: { (t.diplomaticRelations[$0.id] ?? 0, $0.id) < (t.diplomaticRelations[$1.id] ?? 0, $1.id) }) {
                self.gameState = gs
                declareWar(aggressor: target, defender: v.id)
                gs.shadow.post("\(t.name)'s agitated leadership lashes out: war on \(v.name).", date: gs.currentDate, severity: 2)
            }
        }
        self.gameState = gs
        return op
    }

    /// A traced operation: the dirty-tactics exposure (treaty price, cover-up, tribunal in its era) plus a Church
    /// Committee–style inquiry at home and retaliation from the target.
    func exposeAgentOperation(_ useID: UUID, vector: AgentVector) {
        guard let gs = gameState, let use = gs.shadow.tacticUses.first(where: { $0.id == useID }) else { return }
        exposeTactic(useID)
        guard let g = gameState else { return }
        let k = vector.profile.exposure
        g.shadow.popularity = PopularityModel.clamp(g.shadow.popularity - 10 * k)
        if g.shadow.impeachmentStage == 0 {
            g.shadow.impeachmentStage = 1
            g.shadow.post("A Senate select committee opens hearings into the intelligence community's covert programmes.", date: g.currentDate, severity: 3)
        }
        if let t = use.target {
            modifyDiplomaticRelation(from: t, to: g.playerCountryID, by: -Int(50 * k))
            modifyDiplomaticRelation(from: g.playerCountryID, to: t, by: -20)
            if let i = g.countries.firstIndex(where: { $0.id == t }) { g.countries[i].aggressionLevel = min(100, g.countries[i].aggressionLevel + Int(20 * k)) }
        }
        logPlayEvent("agent_operation_exposed", detail: ["target": use.target ?? "", "vector": vector.rawValue, "game_date": PlayHistory.day(g.currentDate)])
        self.gameState = g
        _ = gs
    }

    /// Each turn: active operations take effect and fade; the programme costs money and may leak; rivals may act.
    func processCovertAgents(rivalRoll: Double? = nil) {
        guard let gs = gameState else { return }
        let turnWeeks = gs.turnLength.yearFraction * 52
        for k in gs.shadow.agentOps.indices.reversed() {
            var op = gs.shadow.agentOps[k]
            let w = min(op.weeksLeft, turnWeeks)
            applyAgentWeeks(op, weeks: w)
            op.weeksLeft -= w
            if op.weeksLeft <= 0.001 {
                gs.shadow.agentOps.remove(at: k)
            } else {
                gs.shadow.agentOps[k] = op
            }
        }
        if let since = gs.shadow.agentProgramSince, gs.playerCountryID == "USA" {
            spendFunds(CovertAgents.runningCost * gs.turnLength.yearFraction)
            let years = Double(GameCalendar.days(from: since, to: gs.currentDate)) / 365
            if Double.random(in: 0..<1, using: &gs.rng) < gs.scale.probability(annual: CovertAgents.programLeakAnnual(year: gs.currentYear, yearsRunning: years, ops: gs.shadow.agentOpsRun)) {
                gs.shadow.agentProgramSince = nil
                gs.shadow.post("A leaked file exposes the covert behavioural-agents programme. It is shut down; the hearings begin.", date: gs.currentDate, severity: 3)
                logPlayEvent("agent_program_exposed", detail: ["game_date": PlayHistory.day(gs.currentDate)])
                self.gameState = gs
                applyTacticCost(CovertAgents.tactic, target: nil, coverUp: true)
                if let g = gameState, g.shadow.impeachmentStage == 0 { g.shadow.impeachmentStage = 1 }
            }
        }
        if let g = gameState, CovertAgents.aiEnabled || rivalRoll != nil {
            let r = rivalRoll ?? Double.random(in: 0..<1, using: &g.rng)
            if r < g.scale.probability(annual: 0.12 * difficultyFactor(g.difficultyLevel)) { rivalAgentOperation(roll: r) }
        }
        self.gameState = gameState
    }

    private func difficultyFactor(_ d: DifficultyLevel) -> Double {
        switch d { case .easy: return 0.5; case .normal: return 1; case .hard: return 1.5; case .nightmare: return 2 }
    }

    /// A week's effects, scaled by strength. Game stats only.
    func applyAgentWeeks(_ op: AgentOperation, weeks w: Double) {
        guard w > 0, let gs = gameState, let i = gs.countries.firstIndex(where: { $0.id == op.target }), !gs.countries[i].isDestroyed else { return }
        let s = op.strength * w
        var c = gs.countries[i]
        switch op.agent {
        case .hallucinogenic:
            c.stability = max(0, c.stability - Int((4 * s).rounded()))
            c.profile.outcry = min(100, c.profile.outcry + 4 * s)
            frontBlowOn(c.id, will: 0.04 * s)
        case .stimulant:
            let elapsed = 1 - op.weeksLeft / max(0.001, op.weeks)
            c.gdp *= elapsed < 1.0 / 3 ? 1 + 0.004 * s : 1 - 0.006 * s   // a burst, then the crash
            c.profile.outcry = min(100, c.profile.outcry + 5 * s)
            c.militaryStrength = max(1, c.militaryStrength - Int((1 * s).rounded()))
            c.aggressionLevel = min(100, c.aggressionLevel + Int((2 * s).rounded()))
        case .depressant:
            c.gdp *= 1 - 0.003 * s
            c.militaryStrength = max(1, c.militaryStrength - Int((0.5 * s).rounded()))
            c.profile.outcry = max(0, c.profile.outcry - 3 * s)
            frontBlowOn(c.id, will: 0.02 * s)
        }
        gs.countries[i] = c
        self.gameState = gs
    }

    /// Lower the will of whichever side of a fighting front `id` is on.
    private func frontBlowOn(_ id: String, will: Double) {
        guard let gs = gameState else { return }
        for k in gs.shadow.fronts.indices where gs.shadow.fronts[k].status == .fighting {
            if gs.shadow.fronts[k].defender == id { gs.shadow.fronts[k].defenderWill = max(0, gs.shadow.fronts[k].defenderWill - will) }
            if gs.shadow.fronts[k].attacker == id { gs.shadow.fronts[k].attackerWill = max(0, gs.shadow.fronts[k].attackerWill - will) }
        }
        self.gameState = gs
    }

    /// The most hostile power with the era to run one (from 1953). Covert operations need no physical reach.
    func agentRival(_ gs: GameState, from year: Int = CovertAgents.firstYear) -> Country? {
        guard gs.currentYear >= year else { return nil }
        return WorldPolitics.powers(gs).filter { $0.id != gs.playerCountryID && ($0.diplomaticRelations[gs.playerCountryID] ?? 0) <= -40 }
            .min { ($0.diplomaticRelations[gs.playerCountryID] ?? 0, $0.id) < ($1.diplomaticRelations[gs.playerCountryID] ?? 0, $1.id) }
    }

    /// A rival runs an operation against the player: the effects land, and the President decides how to answer.
    func rivalAgentOperation(roll: Double) {
        guard let gs = gameState, let rival = agentRival(gs) else { return }
        let agent = AgentClass.allCases[Int(roll * 1000) % 3]
        let vectors = AgentVector.allCases.filter { $0 != .air || gs.currentYear >= CovertAgents.airYear }
        let vector = vectors[Int(roll * 7919) % vectors.count]
        launchAgents(by: rival.id, target: gs.playerCountryID, agent: agent, vector: vector, spillRoll: 1, backfireRoll: 1)
        logPlayEvent("agent_operation_suspected", detail: ["suspect": rival.id, "agent": agent.rawValue, "game_date": PlayHistory.day(gs.currentDate)])
        crisisManager.presentCrisis(CovertAgents.suspectedCard(suspect: rival, in: gs))
    }
}

extension CovertAgents {
    /// "Covert contamination suspected": investigate, retaliate or keep it quiet.
    static func suspectedCard(suspect: Country, in gs: GameState) -> CrisisEvent {
        CrisisEvent(
            type: .espionageDiscovered, severity: .serious,
            title: "COVERT CONTAMINATION SUSPECTED",
            description: """
            Public-health officials report clusters of unexplained illness and unrest in several cities. \
            Intelligence analysts suspect a deliberate covert operation, and the trail points toward \(suspect.name).
            Nothing is proven. Whatever you say will be on the record.
            """,
            affectedCountries: [suspect.id], turn: gs.turn,
            options: [
                CrisisOption(title: "Open an investigation", description: "Quietly gather evidence before accusing anyone.",
                             advisorRecommendation: "Director of Central Intelligence",
                             consequences: CrisisConsequences(approvalChange: 2, message: "Investigators begin the slow work of attribution.",
                                                              mutualRelations: [suspect.id: -10])),
                CrisisOption(title: "Retaliate in kind", description: "Answer covertly against \(suspect.name).",
                             advisorRecommendation: "National Security Advisor",
                             consequences: CrisisConsequences(approvalChange: 3, message: "A covert response is authorised against \(suspect.name).",
                                                              mutualRelations: [suspect.id: -35], countryStability: [suspect.id: -6])),
                CrisisOption(title: "Keep it quiet", description: "Treat it as an outbreak of unknown cause and avoid a panic.",
                             advisorRecommendation: "Chief of Staff",
                             consequences: CrisisConsequences(approvalChange: -2, message: "The incident is classified. The rumours are not."))
            ])
    }
}
