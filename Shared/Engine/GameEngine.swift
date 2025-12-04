//
//  GameEngine.swift
//  Global Thermal Nuclear War
//
//  Core game engine managing turns, diplomacy, and nuclear war
//  "The only winning move is not to play." - WOPR
//

import Foundation
import Combine

/// Main game engine - ObservableObject for SwiftUI integration
class GameEngine: ObservableObject {
    @Published var gameState: GameState?
    @Published var logMessages: [LogMessage] = []
    @Published var showingGameOver = false
    @Published var advisors: [Advisor] = []
    @Published var selectedAdvisor: Advisor?
    @Published var crisisManager = CrisisManager()
    @Published var newsManager = NewsManager()
    @Published var leaderboardManager = LeaderboardManager()
    @Published var showingVictoryScreen = false
    @Published var victoryType: VictoryType?
    @Published var finalScore: GameScore?

    private var cancellables = Set<AnyCancellable>()

    init() {
        // Engine ready to start game
        // Initialize advisors
        advisors = Advisor.trumpCabinet()
    }

    // MARK: - Game Lifecycle

    /// Start a new game
    func startNewGame(playerCountryID: String = "USA", difficulty: DifficultyLevel = .normal, administration: Administration? = nil) {
        gameState = GameState(playerCountryID: playerCountryID, difficultyLevel: difficulty, administration: administration)
        logMessages = []
        showingGameOver = false

        addLog("WOPR SYSTEM INITIALIZED", type: .system)
        addLog("GREETINGS PROFESSOR FALKEN", type: .system)
        addLog("SHALL WE PLAY A GAME?", type: .system)
        addLog("", type: .system)
        addLog("Game started as \(playerCountryID)", type: .info)
        addLog("Difficulty: \(difficulty.rawValue)", type: .info)
        addLog("DEFCON Level: \(gameState!.defconLevel.description)", type: .info)
    }

    /// End the current turn and process AI moves
    func endTurn() {
        guard let gameState = gameState, !gameState.gameOver else { return }

        addLog("", type: .system)
        addLog("===== TURN \(gameState.turn + 1) =====", type: .system)

        // Increment turn
        self.gameState?.turn += 1

        // Process all game systems
        if let gs = self.gameState {
            gs.systems.processTurn(gameState: gs)
        }

        // Process cyber operations
        processCyberOperations()

        // Process weapons programs
        processWeaponsPrograms()

        // Process AI turns
        processAITurns()

        // Update DEFCON level
        updateDEFCON()

        // Check for game over conditions
        checkGameOver()

        // Process consequences of actions
        processConsequences()

        // Check for random crisis events
        checkForCrisis()

        // Generate news headlines
        generateNews()

        // Log system updates
        logSystemUpdates()
    }

    /// Generate news headlines for this turn
    private func generateNews() {
        guard let gameState = gameState else { return }
        newsManager.generateNews(from: gameState)
    }

    /// Check for and generate crisis events
    private func checkForCrisis() {
        guard let gameState = gameState else { return }

        // Don't generate crisis if one is already active
        guard crisisManager.activeCrisis == nil else { return }

        // Generate random crisis based on game state
        if let crisis = crisisManager.generateRandomCrisis(gameState: gameState) {
            crisisManager.presentCrisis(crisis)
            addLog("🚨 CRISIS EVENT: \(crisis.title)", type: .critical)
        }
    }

    /// Process all AI-controlled countries
    private func processAITurns() {
        guard let gameState = gameState else { return }

        for country in gameState.countries where !country.isPlayerControlled && !country.isDestroyed {
            // AI decision making
            let action = determineAIAction(for: country)
            executeAIAction(action, for: country)
        }
    }

    /// Determine what action the AI should take
    private func determineAIAction(for country: Country) -> AIAction {
        guard let gameState = gameState else { return .wait }

        // If already at war, continue war efforts
        if !country.atWarWith.isEmpty {
            // Check if should escalate to nuclear
            if gameState.defconLevel.rawValue <= 2 && country.nuclearWarheads > 0 {
                let shouldLaunch = Int.random(in: 1...100) <= (country.aggressionLevel / 2)
                if shouldLaunch {
                    if let target = country.atWarWith.first {
                        return .launchNuclearStrike(target: target, warheads: min(5, country.nuclearWarheads))
                    }
                }
            }
            return .continuousWar
        }

        // Evaluate threats
        let aggressionRoll = Int.random(in: 1...100)
        let aggressionThreshold = Int(Double(country.aggressionLevel) * gameState.difficultyLevel.aiAggressionMultiplier)

        if aggressionRoll > aggressionThreshold {
            // Peaceful actions
            let peacefulActions: [AIAction] = [.wait, .improveDiplomacy, .seekAlliance]
            return peacefulActions.randomElement() ?? .wait
        } else {
            // Aggressive actions
            if country.nuclearWarheads > 0 && gameState.defconLevel.rawValue <= 3 {
                // Find hostile nations
                if let hostile = findMostHostileNation(for: country) {
                    return .threatenNuclearStrike(target: hostile)
                }
            }

            // Conventional warfare
            if let target = findWeakTarget(for: country) {
                return .declareWar(target: target)
            }

            return .wait
        }
    }

    /// Execute AI action
    private func executeAIAction(_ action: AIAction, for country: Country) {
        switch action {
        case .wait:
            break

        case .declareWar(let targetID):
            declareWar(aggressor: country.id, defender: targetID)

        case .launchNuclearStrike(let targetID, let warheads):
            launchNuclearStrike(from: country.id, to: targetID, warheads: warheads)

        case .threatenNuclearStrike(let targetID):
            addLog("\(country.flag) \(country.name) threatens \(getCountry(targetID)?.name ?? "unknown") with nuclear strike!", type: .warning)
            modifyDiplomaticRelation(from: country.id, to: targetID, by: -20)
            raiseDEFCON()

        case .improveDiplomacy:
            // Find country with mediocre relations and improve them
            if let targetID = country.diplomaticRelations.filter({ $0.value > -50 && $0.value < 50 }).keys.randomElement() {
                modifyDiplomaticRelation(from: country.id, to: targetID, by: 10)
                addLog("\(country.flag) \(country.name) improves relations with \(getCountry(targetID)?.name ?? "unknown")", type: .info)
            }

        case .seekAlliance:
            // Find friendly nation and form alliance
            if let targetID = country.diplomaticRelations.filter({ $0.value > 60 }).keys.randomElement(),
               !country.alliances.contains(targetID) {
                formAlliance(country1: country.id, country2: targetID)
            }

        case .continuousWar:
            break
        }
    }

    /// Find most hostile nation
    private func findMostHostileNation(for country: Country) -> String? {
        return country.diplomaticRelations
            .sorted { $0.value < $1.value }
            .first?
            .key
    }

    /// Find weak target for potential war
    private func findWeakTarget(for country: Country) -> String? {
        guard let gameState = gameState else { return nil }

        return gameState.countries
            .filter { !$0.isDestroyed && $0.id != country.id && !country.alliances.contains($0.id) }
            .filter { (country.diplomaticRelations[$0.id] ?? 0) < -40 }
            .sorted { $0.militaryStrength < $1.militaryStrength }
            .first?
            .id
    }

    // MARK: - Game Actions

    /// Launch nuclear strike
    func launchNuclearStrike(from attackerID: String, to targetID: String, warheads: Int) {
        guard let gameState = gameState else { return }
        guard let attackerIndex = gameState.countries.firstIndex(where: { $0.id == attackerID }),
              let targetIndex = gameState.countries.firstIndex(where: { $0.id == targetID }) else { return }

        var attacker = gameState.countries[attackerIndex]
        var target = gameState.countries[targetIndex]

        // Check if attacker has warheads
        guard attacker.nuclearWarheads >= warheads else {
            addLog("❌ \(attacker.name) doesn't have enough warheads!", type: .error)
            return
        }

        // Calculate SDI interception if target has defensive system
        var interceptedWarheads = 0
        var penetratingWarheads = warheads

        if target.hasSDI {
            addLog("", type: .system)
            addLog("🛰️ SDI SYSTEM ACTIVATED", type: .warning)
            addLog("Incoming warheads: \(warheads)", type: .info)
            addLog("SDI Coverage: \(target.sdiCoverage)%", type: .info)
            addLog("Interception Rate: \(target.sdiInterceptionRate)%", type: .info)

            // Calculate how many warheads are covered by SDI
            let coveredWarheads = Int(Double(warheads) * (Double(target.sdiCoverage) / 100.0))
            let uncoveredWarheads = warheads - coveredWarheads

            // Roll for interception on covered warheads
            for _ in 0..<coveredWarheads {
                let roll = Int.random(in: 1...100)
                if roll <= target.sdiInterceptionRate {
                    interceptedWarheads += 1
                }
            }

            penetratingWarheads = uncoveredWarheads + (coveredWarheads - interceptedWarheads)

            addLog("", type: .system)
            addLog("🎯 INTERCEPTION RESULTS:", type: .info)
            addLog("  Tracked warheads: \(coveredWarheads)", type: .info)
            addLog("  Intercepted: \(interceptedWarheads)", type: .info)
            addLog("  Untracked: \(uncoveredWarheads)", type: .warning)
            addLog("  PENETRATING TARGET: \(penetratingWarheads)", type: .critical)

            // SDI can be degraded by the attack
            if penetratingWarheads > 5 {
                target.sdiCoverage = max(0, target.sdiCoverage - 10)
                target.sdiInterceptionRate = max(0, target.sdiInterceptionRate - 5)
                addLog("⚠️ SDI system degraded by saturation attack", type: .warning)
                addLog("  New coverage: \(target.sdiCoverage)%", type: .warning)
                addLog("  New interception: \(target.sdiInterceptionRate)%", type: .warning)
            }
        }

        // Calculate casualties based on penetrating warheads
        let casualtiesPerWarhead = 1_000_000 // 1 million per warhead
        let casualties = penetratingWarheads * casualtiesPerWarhead
        let radiationSpread = penetratingWarheads * 10

        // Update attacker
        attacker.nuclearWarheads -= warheads
        gameState.countries[attackerIndex] = attacker

        // Update target
        target.damageLevel += penetratingWarheads * 10
        target.radiationLevel += radiationSpread
        if target.damageLevel >= 100 {
            target.isDestroyed = true
        }
        gameState.countries[targetIndex] = target

        // Record strike
        let strike = NuclearStrike(
            attacker: attackerID,
            target: targetID,
            warheadsUsed: warheads,
            turn: gameState.turn,
            casualties: casualties,
            radiationSpread: radiationSpread
        )
        gameState.nuclearStrikes.append(strike)

        // Update global stats
        gameState.totalCasualties += casualties
        gameState.globalRadiation += radiationSpread

        // Set DEFCON 1
        gameState.defconLevel = .defcon1

        addLog("", type: .system)
        addLog("☢️  NUCLEAR STRIKE DETECTED ☢️", type: .critical)
        addLog("\(attacker.flag) \(attacker.name) launches \(warheads) nuclear warhead(s) at \(target.flag) \(target.name)", type: .critical)
        addLog("Estimated casualties: \(casualties.formatted())", type: .critical)
        addLog("Radiation spread: +\(radiationSpread) points", type: .critical)
        addLog("Target damage: \(target.damageLevel)%", type: .critical)

        if target.isDestroyed {
            addLog("💀 \(target.flag) \(target.name) has been DESTROYED", type: .critical)
        }

        // Check for retaliation
        if !target.isDestroyed && target.nuclearWarheads > 0 {
            addLog("", type: .system)
            addLog("⚠️  RETALIATION IMMINENT ⚠️", type: .warning)

            // AI will retaliate
            if !target.isPlayerControlled {
                let retaliationWarheads = min(warheads * 2, target.nuclearWarheads)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    self?.launchNuclearStrike(from: targetID, to: attackerID, warheads: retaliationWarheads)
                }
            }
        }

        self.gameState = gameState

        // Trigger MAD (Mutually Assured Destruction) chain
        checkMAD()
    }

    /// Declare war between countries
    func declareWar(aggressor: String, defender: String) {
        guard let gameState = gameState else { return }
        guard let aggressorCountry = getCountry(aggressor),
              let defenderCountry = getCountry(defender) else { return }

        // Update countries
        if let aggressorIndex = gameState.countries.firstIndex(where: { $0.id == aggressor }) {
            gameState.countries[aggressorIndex].atWarWith.insert(defender)
        }
        if let defenderIndex = gameState.countries.firstIndex(where: { $0.id == defender }) {
            gameState.countries[defenderIndex].atWarWith.insert(aggressor)
        }

        // Create war
        let war = War(aggressor: aggressor, defender: defender, startTurn: gameState.turn)
        gameState.activeWars.append(war)

        addLog("", type: .system)
        addLog("⚔️  WAR DECLARED", type: .warning)
        addLog("\(aggressorCountry.flag) \(aggressorCountry.name) declares war on \(defenderCountry.flag) \(defenderCountry.name)", type: .warning)

        self.gameState = gameState

        // Raise DEFCON
        raiseDEFCON()
    }

    /// Form alliance between two countries
    func formAlliance(country1: String, country2: String) {
        guard let gameState = gameState else { return }
        guard let c1 = getCountry(country1), let c2 = getCountry(country2) else { return }

        // Update countries
        if let index1 = gameState.countries.firstIndex(where: { $0.id == country1 }) {
            gameState.countries[index1].alliances.insert(country2)
        }
        if let index2 = gameState.countries.firstIndex(where: { $0.id == country2 }) {
            gameState.countries[index2].alliances.insert(country1)
        }

        // Create treaty
        let treaty = Treaty(type: .alliance, signatories: [country1, country2], turn: gameState.turn)
        gameState.treaties.append(treaty)

        addLog("🤝 \(c1.flag) \(c1.name) and \(c2.flag) \(c2.name) form an alliance", type: .info)

        self.gameState = gameState
    }

    /// Modify diplomatic relation
    func modifyDiplomaticRelation(from: String, to: String, by: Int) {
        guard let gameState = gameState else { return }
        gameState.setRelation(from: from, to: to, value: (gameState.getCountry(id: from)?.diplomaticRelations[to] ?? 0) + by)
        self.gameState = gameState
    }

    /// Economic diplomacy - Turn enemy into ally with money
    func economicDiplomacy(from fromID: String, to toID: String, amount: Int) {
        guard let gameState = gameState else { return }
        guard let fromCountry = getCountry(fromID), let toCountry = getCountry(toID) else { return }

        // Calculate diplomatic improvement based on amount
        let relationBoost = amount / 10_000_000 // $10M = +1 relation, $1B = +100

        // Get current relation
        let currentRelation = fromCountry.diplomaticRelations[toID] ?? 0

        // Apply massive boost
        let newRelation = min(100, currentRelation + relationBoost)
        gameState.setRelation(from: fromID, to: toID, value: newRelation)

        // End any wars between them
        if let fromIndex = gameState.countries.firstIndex(where: { $0.id == fromID }) {
            gameState.countries[fromIndex].atWarWith.remove(toID)
        }
        if let toIndex = gameState.countries.firstIndex(where: { $0.id == toID }) {
            gameState.countries[toIndex].atWarWith.remove(fromID)
        }

        // Remove from active wars
        gameState.activeWars.removeAll { war in
            (war.aggressor == fromID && war.defender == toID) ||
            (war.aggressor == toID && war.defender == fromID)
        }

        // If relations are high enough (70+), auto-form alliance
        if newRelation >= 70 {
            if let fromIndex = gameState.countries.firstIndex(where: { $0.id == fromID }),
               let toIndex = gameState.countries.firstIndex(where: { $0.id == toID }) {
                gameState.countries[fromIndex].alliances.insert(toID)
                gameState.countries[toIndex].alliances.insert(fromID)

                let treaty = Treaty(type: .alliance, signatories: [fromID, toID], turn: gameState.turn)
                gameState.treaties.append(treaty)

                addLog("💰 Economic diplomacy successful!", type: .info)
                addLog("🤝 \(fromCountry.flag) \(fromCountry.name) and \(toCountry.flag) \(toCountry.name) form alliance", type: .info)
            }
        } else if newRelation >= 0 {
            addLog("💰 $\(amount.formatted()) improves relations: \(currentRelation) → \(newRelation)", type: .info)
            addLog("⚔️ Wars ended between \(fromCountry.name) and \(toCountry.name)", type: .info)
        } else {
            addLog("💰 $\(amount.formatted()) softens hostility: \(currentRelation) → \(newRelation)", type: .warning)
        }

        self.gameState = gameState

        // Lower DEFCON if peace is spreading
        if gameState.activeWars.count < 2 && gameState.defconLevel.rawValue < 4 {
            let newLevel = DefconLevel(rawValue: min(5, gameState.defconLevel.rawValue + 1)) ?? .defcon5
            gameState.defconLevel = newLevel
            addLog("DEFCON lowered to: \(newLevel.description)", type: .info)
        }

        self.gameState = gameState
    }

    // MARK: - SDI / Star Wars Defense System

    /// Deploy Strategic Defense Initiative (Reagan's Star Wars program)
    /// Based on actual 1980s SDI capabilities and expectations
    func deploySDI(countryID: String, investmentAmount: Int) {
        guard let gameState = gameState else { return }
        guard let countryIndex = gameState.countries.firstIndex(where: { $0.id == countryID }) else { return }

        var country = gameState.countries[countryIndex]

        // Cost: $100 billion minimum for basic deployment
        // Realistic 1980s expectations: 20-40% interception rate
        if investmentAmount < 100_000_000_000 {
            addLog("❌ SDI deployment requires minimum $100 billion investment", type: .error)
            return
        }

        // Calculate coverage and interception rate based on investment
        // $100B = 40% coverage, 25% interception (basic deployment)
        // $200B = 70% coverage, 35% interception (enhanced deployment)
        // $300B+ = 90% coverage, 45% interception (full deployment)
        let coverageBonus = min(90, 40 + ((investmentAmount - 100_000_000_000) / 10_000_000_000))
        let interceptionBonus = min(45, 25 + ((investmentAmount - 100_000_000_000) / 20_000_000_000))

        country.hasSDI = true
        country.sdiCoverage = coverageBonus
        country.sdiInterceptionRate = interceptionBonus

        gameState.countries[countryIndex] = country

        addLog("", type: .system)
        addLog("🛰️ STRATEGIC DEFENSE INITIATIVE DEPLOYED", type: .info)
        addLog("Investment: $\(investmentAmount.formatted())", type: .info)
        addLog("System Components:", type: .info)
        addLog("  • Space-based X-ray lasers", type: .info)
        addLog("  • Brilliant Pebbles kinetic interceptors", type: .info)
        addLog("  • Ground-based radar network", type: .info)
        addLog("  • Satellite early warning system", type: .info)
        addLog("Coverage: \(coverageBonus)% of incoming missiles", type: .info)
        addLog("Interception Rate: \(interceptionBonus)% per warhead", type: .info)
        addLog("", type: .system)
        addLog("⚠️ Note: SDI effectiveness is limited by 1980s technology", type: .warning)
        addLog("System may be overwhelmed by saturation attacks", type: .warning)

        self.gameState = gameState

        // Lower DEFCON slightly (defensive posture)
        if gameState.defconLevel.rawValue < 5 {
            let newLevel = DefconLevel(rawValue: min(5, gameState.defconLevel.rawValue + 1)) ?? .defcon5
            gameState.defconLevel = newLevel
            addLog("DEFCON lowered to: \(newLevel.description) (defensive deployment)", type: .info)
        }

        self.gameState = gameState
    }

    /// Upgrade existing SDI system
    func upgradeSDI(countryID: String, additionalInvestment: Int) {
        guard let gameState = gameState else { return }
        guard let countryIndex = gameState.countries.firstIndex(where: { $0.id == countryID }) else { return }

        var country = gameState.countries[countryIndex]

        if !country.hasSDI {
            addLog("❌ No SDI system to upgrade. Deploy first.", type: .error)
            return
        }

        // Each $50B improves coverage by +10% and interception by +5%
        let coverageIncrease = min(90 - country.sdiCoverage, (additionalInvestment / 5_000_000_000))
        let interceptionIncrease = min(45 - country.sdiInterceptionRate, (additionalInvestment / 10_000_000_000))

        country.sdiCoverage = min(90, country.sdiCoverage + coverageIncrease)
        country.sdiInterceptionRate = min(45, country.sdiInterceptionRate + interceptionIncrease)

        gameState.countries[countryIndex] = country

        addLog("🛰️ SDI SYSTEM UPGRADED", type: .info)
        addLog("Investment: $\(additionalInvestment.formatted())", type: .info)
        addLog("New Coverage: \(country.sdiCoverage)%", type: .info)
        addLog("New Interception Rate: \(country.sdiInterceptionRate)%", type: .info)

        self.gameState = gameState
    }

    // MARK: - Prohibited Weapons Programs (SALT I/II Violations)

    /// Initiate secret weapons program violating SALT treaties
    func startWeaponProgram(countryID: String, weapon: SALTProhibitedWeapon) {
        guard let gameState = gameState else { return }
        guard let countryIndex = gameState.countries.firstIndex(where: { $0.id == countryID }) else { return }

        var country = gameState.countries[countryIndex]

        // Check if country can afford it
        guard country.treasury >= weapon.developmentCost else {
            addLog("❌ Insufficient funds for weapons program. Cost: $\(weapon.developmentCost.formatted())", type: .error)
            return
        }

        // Check if already deployed
        if country.deployedProhibitedWeapons.contains(weapon) {
            addLog("❌ \(weapon.rawValue) already deployed", type: .error)
            return
        }

        // Check if already in development
        let alreadyDeveloping = gameState.activeWeaponPrograms.contains { $0.weapon == weapon && $0.countryID == countryID }
        if alreadyDeveloping {
            addLog("❌ \(weapon.rawValue) already in development", type: .error)
            return
        }

        // Deduct cost
        country.treasury -= weapon.developmentCost
        gameState.countries[countryIndex] = country

        // Create program
        let program = WeaponsDevelopmentProgram(
            countryID: countryID,
            weapon: weapon,
            startTurn: gameState.turn
        )

        gameState.activeWeaponPrograms.append(program)
        country.activeWeaponPrograms.append(program.id)
        gameState.countries[countryIndex] = country

        addLog("", type: .system)
        addLog("🔬 SECRET WEAPONS PROGRAM INITIATED", type: .warning)
        addLog("Program: \(weapon.rawValue)", type: .info)
        addLog("Cost: $\(weapon.developmentCost.formatted())", type: .info)
        addLog("Estimated completion: Turn \(program.completionTurn)", type: .info)
        addLog("⚠️ WARNING: Treaty violation if discovered", type: .warning)
        addLog("", type: .system)
        addLog("CLASSIFICATION: TOP SECRET", type: .critical)
        addLog(weapon.historicalContext, type: .info)

        self.gameState = gameState
    }

    /// Process weapons programs each turn
    func processWeaponsPrograms() {
        guard let gameState = gameState else { return }

        for i in gameState.activeWeaponPrograms.indices {
            var program = gameState.activeWeaponPrograms[i]

            // Check if complete
            if gameState.turn >= program.completionTurn && !program.isCompleted {
                completeWeaponProgram(&program)
                gameState.activeWeaponPrograms[i] = program
            }

            // Check for detection during development
            if !program.wasDetected && gameState.turn < program.completionTurn {
                let detectionChance = calculateWeaponDetectionChance(program: program)
                if Int.random(in: 1...100) <= detectionChance {
                    program.wasDetected = true
                    program.detectedOnTurn = gameState.turn
                    gameState.activeWeaponPrograms[i] = program
                    handleWeaponDetection(program: program)
                }
            }
        }

        // Remove completed programs
        gameState.activeWeaponPrograms.removeAll { $0.isCompleted }

        self.gameState = gameState
    }

    private func calculateWeaponDetectionChance(program: WeaponsDevelopmentProgram) -> Int {
        guard let gameState = gameState else { return 20 }

        // Average intelligence of major nuclear powers
        let majorPowers = ["USA", "RUS", "CHN", "GBR", "FRA"]
        let averageIntel = majorPowers.compactMap { id in
            gameState.getCountry(id: id)?.intelligenceLevel
        }.reduce(0, +) / max(majorPowers.count, 1)

        return WeaponsIntelligence.detectionChance(
            for: program.weapon,
            targetIntelligence: averageIntel,
            turn: gameState.turn,
            startTurn: program.startTurn
        )
    }

    private func completeWeaponProgram(_ program: inout WeaponsDevelopmentProgram) {
        guard let gameState = gameState else { return }
        guard let countryIndex = gameState.countries.firstIndex(where: { $0.id == program.countryID }) else { return }

        var country = gameState.countries[countryIndex]
        program.isCompleted = true

        // Apply weapon benefits
        let benefit = program.weapon.militaryBenefit

        country.nuclearWarheads += benefit.nuclearWarheads
        country.deployedProhibitedWeapons.append(program.weapon)

        // Apply specific capabilities
        switch program.weapon {
        case .antiBallisticMissiles:
            country.hasABMSystem = true
            addLog("🛡️ ABM system operational: +\(benefit.interceptors) interceptors", type: .info)
        case .multipleReentryVehicles:
            country.hasMIRVTechnology = true
            addLog("🚀 MIRV technology deployed", type: .info)
        case .mobileLaunchers:
            country.hasMobileLaunchers = true
            addLog("🚛 Mobile launcher fleet operational", type: .info)
        case .antisatelliteWeapons:
            country.hasASATWeapons = true
            addLog("🛰️ ASAT capability achieved", type: .info)
        case .heavyICBM:
            country.icbmCount += 30
            addLog("🚀 Heavy ICBM silos constructed", type: .info)
        default:
            break
        }

        // Update capabilities
        if benefit.firstStrike {
            country.firstStrikeCapability = true
        }
        if benefit.secondStrike {
            country.secondStrikeCapability = true
        }

        country.activeWeaponPrograms.removeAll { $0 == program.id }
        gameState.countries[countryIndex] = country

        addLog("", type: .system)
        addLog("✅ SECRET WEAPONS PROGRAM COMPLETED", type: .info)
        addLog("\(country.flag) \(country.name): \(program.weapon.rawValue)", type: .info)
        addLog(benefit.description, type: .info)

        // If detected, trigger diplomatic crisis
        if program.wasDetected {
            addLog("", type: .system)
            addLog("🚨 TREATY VIOLATION CONFIRMED", type: .critical)
            handleTreatyViolation(countryID: program.countryID, weapon: program.weapon)
        } else {
            addLog("⚠️ Program remains classified", type: .warning)
        }

        self.gameState = gameState
    }

    private func handleWeaponDetection(program: WeaponsDevelopmentProgram) {
        guard let gameState = gameState else { return }
        guard let country = gameState.getCountry(id: program.countryID) else { return }

        addLog("", type: .system)
        addLog("🚨 SECRET WEAPONS PROGRAM DETECTED", type: .critical)
        addLog("\(country.flag) \(country.name) developing: \(program.weapon.rawValue)", type: .critical)
        addLog("Intelligence confirms treaty violation in progress", type: .warning)
        addLog("Estimated completion: Turn \(program.completionTurn)", type: .info)
        addLog("", type: .system)
        addLog("⚠️ International crisis escalating", type: .warning)

        // Immediate diplomatic fallout
        let impact = program.weapon.diplomaticConsequences

        // Relations penalty with all nuclear powers
        let nuclearPowers = ["USA", "RUS", "CHN", "GBR", "FRA", "IND", "PAK", "ISR"]
        for powerID in nuclearPowers where powerID != program.countryID {
            modifyDiplomaticRelation(from: powerID, to: program.countryID, by: impact.relationsPenalty)
        }

        addLog(impact.message, type: .critical)

        // Raise DEFCON if treaty violation is serious
        if impact.defconIncrease {
            raiseDEFCON()
        }

        self.gameState = gameState
    }

    private func handleTreatyViolation(countryID: String, weapon: SALTProhibitedWeapon) {
        guard let gameState = gameState else { return }
        guard let countryIndex = gameState.countries.firstIndex(where: { $0.id == countryID }) else { return }

        var country = gameState.countries[countryIndex]
        country.treatyViolations += 1
        gameState.countries[countryIndex] = country

        let impact = weapon.diplomaticConsequences

        addLog("", type: .system)
        addLog("⚖️ ARMS CONTROL TREATY VIOLATED", type: .critical)
        addLog("\(country.flag) \(country.name) violates SALT agreements", type: .critical)
        addLog("Weapon deployed: \(weapon.rawValue)", type: .warning)
        addLog(impact.message, type: .critical)
        addLog("Total violations: \(country.treatyViolations)", type: .warning)

        // Global diplomatic crisis
        let nuclearPowers = ["USA", "RUS", "CHN", "GBR", "FRA", "IND", "PAK", "ISR", "PRK"]
        for powerID in nuclearPowers where powerID != countryID {
            modifyDiplomaticRelation(from: powerID, to: countryID, by: impact.relationsPenalty)
        }

        // Multiple violations may trigger war
        if country.treatyViolations >= 3 {
            addLog("", type: .system)
            addLog("⚠️ MULTIPLE TREATY VIOLATIONS", type: .critical)
            addLog("International community considers military response", type: .critical)

            // 30% chance of war with hostile nuclear power
            for powerID in nuclearPowers where powerID != countryID {
                if let power = gameState.getCountry(id: powerID) {
                    let relation = power.diplomaticRelations[countryID] ?? 0
                    if relation < -50 && Int.random(in: 1...100) <= 30 {
                        addLog("⚔️ \(power.name) considers treaty violations an act of aggression!", type: .critical)
                        declareWar(aggressor: powerID, defender: countryID)
                        break
                    }
                }
            }
        }

        if impact.defconIncrease {
            raiseDEFCON()
        }

        self.gameState = gameState
    }

    // MARK: - Cyber Warfare Operations

    /// Launch cyber attack on enemy government
    func launchCyberAttack(from attackerID: String, to targetID: String, attackType: CyberAttackType, useProxy: HackerGroup?) {
        guard let gameState = gameState else { return }
        guard let attackerIndex = gameState.countries.firstIndex(where: { $0.id == attackerID }),
              let targetIndex = gameState.countries.firstIndex(where: { $0.id == targetID }) else { return }

        var attacker = gameState.countries[attackerIndex]
        let target = gameState.countries[targetIndex]

        // Check if attacker can afford it
        guard attacker.treasury >= attackType.cost else {
            addLog("❌ Insufficient funds for cyber operation. Cost: $\(attackType.cost.formatted())", type: .error)
            return
        }

        // Deduct cost
        attacker.treasury -= attackType.cost
        gameState.countries[attackerIndex] = attacker

        // Create operation
        let operation = CyberOperation(
            attackerID: attackerID,
            targetID: targetID,
            type: attackType,
            startTurn: gameState.turn
        )

        gameState.activeCyberOperations.append(operation)
        attacker.activeCyberOperations.append(operation.id)
        attacker.cyberAttacksLaunched += 1
        gameState.countries[attackerIndex] = attacker

        addLog("", type: .system)
        addLog("🖥️ CYBER OPERATION INITIATED", type: .warning)
        addLog("Type: \(attackType.rawValue)", type: .info)
        addLog("Target: \(target.flag) \(target.name)", type: .info)
        addLog("Cost: $\(attackType.cost.formatted())", type: .info)
        addLog("Duration: \(attackType.duration) turns", type: .info)

        if let proxy = useProxy {
            addLog("Cover: \(proxy.rawValue)", type: .info)
            addLog("Plausible deniability: \(proxy.plausibleDeniability)%", type: .info)
        } else {
            addLog("⚠️ Direct attack - high attribution risk", type: .warning)
        }

        self.gameState = gameState
    }

    /// Process ongoing cyber operations each turn
    func processCyberOperations() {
        guard let gameState = gameState else { return }

        for i in gameState.activeCyberOperations.indices {
            var operation = gameState.activeCyberOperations[i]

            // Check if complete
            if gameState.turn >= operation.completionTurn && !operation.isCompleted {
                executeCyberAttack(&operation)
                gameState.activeCyberOperations[i] = operation
            }

            // Check for detection during operation
            if !operation.wasDetected && gameState.turn < operation.completionTurn {
                let detectionChance = calculateDetectionChance(operation: operation)
                if Int.random(in: 1...100) <= detectionChance {
                    operation.wasDetected = true
                    operation.detectedOnTurn = gameState.turn
                    gameState.activeCyberOperations[i] = operation
                    handleCyberDetection(operation: operation)
                }
            }
        }

        // Remove completed operations
        gameState.activeCyberOperations.removeAll { $0.isCompleted }

        self.gameState = gameState
    }

    private func calculateDetectionChance(operation: CyberOperation) -> Int {
        guard let gameState = gameState else { return 50 }
        guard let target = gameState.getCountry(id: operation.targetID) else { return 50 }

        let baseDetection = operation.type.detectability
        let defenseBonus = target.cyberDefenseLevel.detectionBonus
        let perTurnIncrease = (gameState.turn - operation.startTurn) * 5 // Increases over time

        return min(95, baseDetection + defenseBonus + perTurnIncrease)
    }

    private func executeCyberAttack(_ operation: inout CyberOperation) {
        guard let gameState = gameState else { return }
        guard let attackerIndex = gameState.countries.firstIndex(where: { $0.id == operation.attackerID }),
              let targetIndex = gameState.countries.firstIndex(where: { $0.id == operation.targetID }) else { return }

        var attacker = gameState.countries[attackerIndex]
        var target = gameState.countries[targetIndex]

        // Calculate success based on offense vs defense
        let offenseSkill = attacker.cyberOffenseLevel
        let defensePrevention = target.cyberDefenseLevel.preventionBonus
        let successChance = max(10, min(90, offenseSkill - defensePrevention + 30))

        let success = Int.random(in: 1...100) <= successChance
        operation.success = success
        operation.isCompleted = true

        if success {
            // Apply effects
            let effects = CyberAttackEffect.effectsFor(attackType: operation.type, targetCountry: target)

            target.economicStrength = max(0, target.economicStrength - effects.economicDamage)
            target.militaryStrength = max(0, target.militaryStrength - effects.militaryDegradation)
            target.stability = max(0, target.stability - effects.stabilityLoss)
            target.nuclearWarheads = max(0, target.nuclearWarheads - effects.warheadsCompromised)
            target.cyberAttacksReceived += 1
            target.isUnderCyberAttack = true

            gameState.totalCasualties += effects.civilianCasualties
            gameState.countries[targetIndex] = target

            // Create incident
            let attributionConfidence: Int
            if operation.wasDetected {
                attributionConfidence = 80
            } else {
                attributionConfidence = 30
            }

            let incident = CyberIncident(
                turn: gameState.turn,
                attackType: operation.type,
                suspectedSource: operation.wasDetected ? operation.attackerID : nil,
                targetID: operation.targetID,
                effects: effects,
                attributionConfidence: attributionConfidence
            )
            gameState.cyberIncidents.append(incident)

            addLog("", type: .system)
            addLog("🖥️💥 CYBER ATTACK SUCCESSFUL", type: .critical)
            addLog("Target: \(target.flag) \(target.name)", type: .critical)
            addLog("Attack Type: \(operation.type.rawValue)", type: .critical)
            addLog("", type: .system)
            addLog("EFFECTS:", type: .warning)
            if effects.economicDamage > 0 {
                addLog("  Economic damage: -\(effects.economicDamage)%", type: .warning)
            }
            if effects.militaryDegradation > 0 {
                addLog("  Military degradation: -\(effects.militaryDegradation)", type: .warning)
            }
            if effects.stabilityLoss > 0 {
                addLog("  Stability loss: -\(effects.stabilityLoss)", type: .warning)
            }
            if effects.warheadsCompromised > 0 {
                addLog("  Nuclear warheads compromised: \(effects.warheadsCompromised)", type: .critical)
            }
            if effects.civilianCasualties > 0 {
                addLog("  Civilian casualties: \(effects.civilianCasualties.formatted())", type: .critical)
            }

            if operation.wasDetected {
                addLog("", type: .system)
                addLog("🔍 ATTACK ATTRIBUTED TO: \(attacker.flag) \(attacker.name)", type: .critical)
                modifyDiplomaticRelation(from: operation.targetID, to: operation.attackerID, by: effects.relationsDamage)

                // Risk of war
                let attackSeverity = operation.type.severity
                if attackSeverity == .critical || attackSeverity == .catastrophic {
                    let warRisk = 40
                    if Int.random(in: 1...100) <= warRisk {
                        addLog("⚔️ \(target.name) considers this an act of war!", type: .critical)
                        declareWar(aggressor: operation.targetID, defender: operation.attackerID)
                    }
                }
            } else {
                addLog("", type: .system)
                addLog("🕵️ Attribution: Unknown", type: .info)
                addLog("Suspected source: Multiple candidates", type: .info)
            }

        } else {
            addLog("", type: .system)
            addLog("🖥️❌ CYBER ATTACK FAILED", type: .warning)
            addLog("Target defenses repelled intrusion", type: .info)
            addLog("Operation burned. Assets compromised.", type: .warning)

            // Automatic detection on failure
            operation.wasDetected = true
            target.cyberAttacksReceived += 1
            gameState.countries[targetIndex] = target

            addLog("🔍 Attack traced to: \(attacker.flag) \(attacker.name)", type: .critical)
            modifyDiplomaticRelation(from: operation.targetID, to: operation.attackerID, by: -40)
        }

        attacker.activeCyberOperations.removeAll { $0 == operation.id }
        gameState.countries[attackerIndex] = attacker

        self.gameState = gameState
    }

    private func handleCyberDetection(operation: CyberOperation) {
        guard let gameState = gameState else { return }
        guard let attacker = gameState.getCountry(id: operation.attackerID),
              let target = gameState.getCountry(id: operation.targetID) else { return }

        addLog("", type: .system)
        addLog("🚨 CYBER INTRUSION DETECTED", type: .critical)
        addLog("Target: \(target.flag) \(target.name)", type: .info)
        addLog("Source traced to: \(attacker.flag) \(attacker.name)", type: .critical)
        addLog("Operation exposed before completion", type: .warning)

        modifyDiplomaticRelation(from: operation.targetID, to: operation.attackerID, by: -30)

        // Target may launch counter-hack
        if target.cyberOffenseLevel > 50 && !target.isPlayerControlled {
            addLog("⚠️ \(target.name) preparing counter-cyber operation", type: .warning)
            // AI will retaliate next turn
        }
    }

    /// Upgrade cyber defense
    func upgradeCyberDefense(countryID: String) {
        guard let gameState = gameState else { return }
        guard let countryIndex = gameState.countries.firstIndex(where: { $0.id == countryID }) else { return }

        var country = gameState.countries[countryIndex]

        if country.cyberDefenseLevel == .impenetrable {
            addLog("❌ Cyber defense already at maximum level", type: .error)
            return
        }

        let newLevel = CyberDefenseLevel(rawValue: country.cyberDefenseLevel.rawValue + 1) ?? .impenetrable
        let cost = newLevel.cost

        guard country.treasury >= cost else {
            addLog("❌ Insufficient funds. Cost: $\(cost.formatted())", type: .error)
            return
        }

        country.treasury -= cost
        country.cyberDefenseLevel = newLevel
        gameState.countries[countryIndex] = country

        addLog("🛡️ CYBER DEFENSE UPGRADED", type: .info)
        addLog("New level: \(newLevel.description)", type: .info)
        addLog("Detection bonus: +\(newLevel.detectionBonus)%", type: .info)
        addLog("Prevention bonus: +\(newLevel.preventionBonus)%", type: .info)
        addLog("Cost: $\(cost.formatted())", type: .info)

        self.gameState = gameState
    }

    // MARK: - Covert Operations

    /// Sabotage: Destroy military infrastructure
    func covertSabotage(from fromID: String, to toID: String) {
        guard let gameState = gameState else { return }
        guard let fromCountry = getCountry(fromID), let toCountry = getCountry(toID) else { return }

        if let targetIndex = gameState.countries.firstIndex(where: { $0.id == toID }) {
            var target = gameState.countries[targetIndex]
            target.militaryStrength = max(0, target.militaryStrength - 20)
            target.economicStrength = max(0, target.economicStrength - 15)
            gameState.countries[targetIndex] = target

            addLog("💣 CIA SABOTAGE: Infrastructure destroyed in \(toCountry.name)", type: .warning)
            addLog("   -20 military strength, -15 economic strength", type: .info)

            // Small chance of discovery
            if Int.random(in: 1...100) <= 30 {
                addLog("⚠️ Operation exposed! \(toCountry.name) blames \(fromCountry.name)", type: .warning)
                modifyDiplomaticRelation(from: toID, to: fromID, by: -30)
                if Int.random(in: 1...100) <= 20 {
                    declareWar(aggressor: toID, defender: fromID)
                }
            }
        }

        self.gameState = gameState
    }

    /// Cyber Warfare: Hack military and government systems
    func cyberWarfare(from fromID: String, to toID: String) {
        guard let gameState = gameState else { return }
        guard let fromCountry = getCountry(fromID), let toCountry = getCountry(toID) else { return }

        if let targetIndex = gameState.countries.firstIndex(where: { $0.id == toID }) {
            var target = gameState.countries[targetIndex]
            target.militaryStrength = max(0, target.militaryStrength - 15)
            target.stability = max(0, target.stability - 10)
            gameState.countries[targetIndex] = target

            addLog("📡 CYBER ATTACK: Systems compromised in \(toCountry.name)", type: .warning)
            addLog("   -15 military strength, -10 stability", type: .info)

            // Cyber attacks are hard to trace
            if Int.random(in: 1...100) <= 15 {
                addLog("🔍 Attack traced to \(fromCountry.name)!", type: .warning)
                modifyDiplomaticRelation(from: toID, to: fromID, by: -20)
                raiseDEFCON()
            } else {
                addLog("🕵️ Attack origin: Unknown", type: .info)
            }
        }

        self.gameState = gameState
    }

    /// Propaganda: Undermine regime, reduce morale
    func propaganda(from fromID: String, to toID: String) {
        guard let gameState = gameState else { return }
        guard let fromCountry = getCountry(fromID), let toCountry = getCountry(toID) else { return }

        if let targetIndex = gameState.countries.firstIndex(where: { $0.id == toID }) {
            var target = gameState.countries[targetIndex]
            target.stability = max(0, target.stability - 20)
            gameState.countries[targetIndex] = target

            addLog("🎭 PROPAGANDA: Dissent spreads in \(toCountry.name)", type: .info)
            addLog("   -20 stability, regime weakened", type: .info)

            // Propaganda improves your image
            modifyDiplomaticRelation(from: toID, to: fromID, by: 10)
            addLog("   +10 relations (population sympathizes with \(fromCountry.name))", type: .info)

            // Low chance of backlash
            if Int.random(in: 1...100) <= 10 {
                addLog("📺 Counter-propaganda exposes \(fromCountry.name)'s interference", type: .warning)
                modifyDiplomaticRelation(from: toID, to: fromID, by: -15)
            }
        }

        self.gameState = gameState
    }

    /// Special Forces: Tactical strike on military targets
    func specialForces(from fromID: String, to toID: String) {
        guard let gameState = gameState else { return }
        guard let fromCountry = getCountry(fromID), let toCountry = getCountry(toID) else { return }

        if let targetIndex = gameState.countries.firstIndex(where: { $0.id == toID }) {
            var target = gameState.countries[targetIndex]
            target.militaryStrength = max(0, target.militaryStrength - 25)
            target.nuclearWarheads = max(0, target.nuclearWarheads - min(10, target.nuclearWarheads))
            gameState.countries[targetIndex] = target

            let warheadsDestroyed = min(10, toCountry.nuclearWarheads)

            addLog("🪖 SPECIAL FORCES: Strike on \(toCountry.name) military base", type: .warning)
            addLog("   -25 military strength, -\(warheadsDestroyed) nuclear warheads", type: .info)

            // High chance of discovery and war
            if Int.random(in: 1...100) <= 70 {
                addLog("🚨 ATTACK TRACED TO \(fromCountry.name)!", type: .critical)
                modifyDiplomaticRelation(from: toID, to: fromID, by: -50)
                addLog("⚔️ \(toCountry.name) considers this an act of war!", type: .critical)

                if Int.random(in: 1...100) <= 60 {
                    declareWar(aggressor: toID, defender: fromID)
                }
            } else {
                addLog("🕵️ Origin: Unconfirmed", type: .info)
            }
        }

        self.gameState = gameState
        raiseDEFCON()
    }

    // MARK: - DEFCON Management

    /// Raise DEFCON level (lower number = higher alert)
    private func raiseDEFCON() {
        guard let gameState = gameState else { return }

        if gameState.defconLevel.rawValue > 1 {
            let newLevel = DefconLevel(rawValue: gameState.defconLevel.rawValue - 1) ?? .defcon1
            gameState.defconLevel = newLevel
            addLog("⚠️  DEFCON RAISED TO: \(newLevel.description)", type: .warning)
            self.gameState = gameState
        }
    }

    /// Update DEFCON based on world situation
    private func updateDEFCON() {
        guard let gameState = gameState else { return }

        let warCount = gameState.activeWars.count
        let nuclearStrikes = gameState.nuclearStrikes.count

        let targetDEFCON: DefconLevel
        if nuclearStrikes > 0 {
            targetDEFCON = .defcon1
        } else if warCount >= 3 {
            targetDEFCON = .defcon2
        } else if warCount >= 1 {
            targetDEFCON = .defcon3
        } else {
            // Gradually return to peace
            if gameState.defconLevel.rawValue < 5 && gameState.turn % 5 == 0 {
                let newLevel = DefconLevel(rawValue: min(5, gameState.defconLevel.rawValue + 1)) ?? .defcon5
                gameState.defconLevel = newLevel
                addLog("DEFCON lowered to: \(newLevel.description)", type: .info)
                self.gameState = gameState
                return
            }
            return
        }

        if targetDEFCON.rawValue < gameState.defconLevel.rawValue {
            gameState.defconLevel = targetDEFCON
            addLog("⚠️  DEFCON changed to: \(targetDEFCON.description)", type: .warning)
            self.gameState = gameState
        }
    }

    // MARK: - Game Over

    /// Check for game over conditions
    private func checkGameOver() {
        guard var gameState = gameState else { return }

        // Check for defeat
        let defeatCheck = VictoryChecker.checkDefeat(gameState: gameState)
        if defeatCheck.defeated {
            gameState.gameOver = true
            gameState.gameOverReason = defeatCheck.reason
            self.gameState = gameState

            // Calculate final score (no victory)
            let score = GameScore.calculate(from: gameState, victoryType: nil)
            self.finalScore = score
            self.victoryType = nil
            self.showingVictoryScreen = true
            showGameOver()
            return
        }

        // Check for victory
        if let victory = VictoryChecker.checkVictory(gameState: gameState) {
            gameState.gameOver = true
            gameState.gameOverReason = victory.description
            self.gameState = gameState

            // Calculate final score with victory
            let score = GameScore.calculate(from: gameState, victoryType: victory)
            self.finalScore = score
            self.victoryType = victory
            self.showingVictoryScreen = true
            showGameOver()
            return
        }

        self.gameState = gameState
    }

    /// Check for MAD scenario
    private func checkMAD() {
        guard let gameState = gameState else { return }

        // If major powers start launching, trigger global nuclear war
        let majorPowers = ["USA", "RUS", "CHN"]
        let majorPowerStrikes = gameState.nuclearStrikes.filter { majorPowers.contains($0.attacker) }

        if majorPowerStrikes.count >= 2 {
            addLog("", type: .system)
            addLog("☢️☢️☢️  MUTUALLY ASSURED DESTRUCTION  ☢️☢️☢️", type: .critical)
            addLog("Global nuclear exchange detected!", type: .critical)
            addLog("The only winning move is not to play.", type: .critical)
        }
    }

    /// Show game over screen
    private func showGameOver() {
        guard let gameState = gameState else { return }

        addLog("", type: .system)
        addLog("======================", type: .critical)
        addLog("     GAME OVER", type: .critical)
        addLog("======================", type: .critical)
        addLog(gameState.gameOverReason, type: .critical)
        addLog("", type: .system)
        addLog("Final Statistics:", type: .info)
        addLog("Turns: \(gameState.turn)", type: .info)
        addLog("Total casualties: \(gameState.totalCasualties.formatted())", type: .info)
        addLog("Nuclear strikes: \(gameState.nuclearStrikes.count)", type: .info)
        addLog("Global radiation: \(gameState.globalRadiation)", type: .info)

        showingGameOver = true
    }

    /// Process consequences of radiation, damage, etc.
    private func processConsequences() {
        guard let gameState = gameState else { return }

        // Radiation spread
        for i in gameState.countries.indices {
            if gameState.countries[i].radiationLevel > 50 {
                gameState.countries[i].stability = max(0, gameState.countries[i].stability - 5)
                gameState.countries[i].economicStrength = max(0, gameState.countries[i].economicStrength - 3)
            }
        }

        self.gameState = gameState
    }

    // MARK: - Helpers

    /// Get country by ID
    private func getCountry(_ id: String) -> Country? {
        return gameState?.getCountry(id: id)
    }

    /// Add log message
    func addLog(_ message: String, type: LogType) {
        let logMessage = LogMessage(message: message, type: type, timestamp: Date())
        logMessages.append(logMessage)

        // Keep log size manageable
        if logMessages.count > 200 {
            logMessages.removeFirst(50)
        }
    }
}

/// AI action types
enum AIAction {
    case wait
    case declareWar(target: String)
    case launchNuclearStrike(target: String, warheads: Int)
    case threatenNuclearStrike(target: String)
    case improveDiplomacy
    case seekAlliance
    case continuousWar
}

// MARK: - GameEngine System Logging Extension
extension GameEngine {
    /// Log updates from all game systems
    func logSystemUpdates() {
        guard let gs = gameState else { return }

        // Crisis alerts
        for crisis in gs.systems.crises where crisis.turn == gs.turn {
            addLog("⚠️ CRISIS: \(crisis.type.rawValue) - \(crisis.deadline) turns to resolve", type: .critical)
        }

        // Nuclear winter progression
        if gs.systems.environ.stage != .none {
            addLog("❄️ Nuclear Winter: Stage \(gs.systems.environ.stage.rawValue) - Temp: -\(gs.systems.environ.temp)°C", type: .warning)
        }

        // Famine warnings
        if gs.systems.famine.severity > 20 {
            addLog("🌾 Famine: \(gs.systems.famine.deaths) deaths, \(gs.systems.famine.reserves) months food left", type: .warning)
        }

        // Treaty updates
        for treaty in gs.systems.treaties where treaty.accepted {
            addLog("📜 Treaty signed: \(treaty.type.rawValue)", type: .info)
        }

        // Intelligence reports
        let newIntel = gs.systems.intelOps.filter { $0.turn == gs.turn && $0.success }
        if !newIntel.isEmpty {
            addLog("🕵️ \(newIntel.count) intelligence operation(s) successful", type: .info)
        }

        // Compromised spy networks
        let compromised = gs.systems.spyNets.filter { $0.compromised }
        if !compromised.isEmpty {
            addLog("⚠️ \(compromised.count) spy network(s) compromised!", type: .warning)
        }

        // ASAT attacks
        let asatAttacks = gs.systems.asat.filter { $0.turn == gs.turn && $0.success }
        if !asatAttacks.isEmpty {
            addLog("🛰️ \(asatAttacks.count) satellite(s) destroyed - Debris risk: \(gs.systems.debris.kessler)%", type: .warning)
        }
    }
}

struct LogMessage: Identifiable {
    let id = UUID()
    let message: String
    let type: LogType
    let timestamp: Date
}

/// Log message types
enum LogType {
    case system
    case info
    case warning
    case error
    case critical
}
