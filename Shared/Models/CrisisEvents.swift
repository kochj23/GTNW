//
//  CrisisEvents.swift
//  Global Thermal Nuclear War
//
//  Dynamic crisis events that create tension and force tough choices
//  Created by Jordan Koch & Claude Code on 2025-12-03.
//

import Foundation
import SwiftUI

/// Crisis event types that can occur during gameplay
enum CrisisEventType: String, Codable {
    case falseAlarm = "False Alarm"
    case nuclearAccident = "Nuclear Accident"
    case terroristThreat = "Terrorist Threat"
    case espionageDiscovered = "Espionage Discovered"
    case militaryCoup = "Military Coup"
    case cyberAttack = "Cyber Attack"
    case diplomaticIncident = "Diplomatic Incident"
    case economicCollapse = "Economic Collapse"
    case rogueCommander = "Rogue Commander"
    case satelliteFailure = "Satellite Failure"
    case civilUnrest = "Civil Unrest"
    case weaponsMalfunction = "Weapons Malfunction"
    case radiationLeak = "Radiation Leak"
    case spyRingUncovered = "Spy Ring Uncovered"
    case assassinationAttempt = "Assassination Attempt"
}

/// Severity levels for crisis events
enum CrisisSeverity: Int, Codable {
    case minor = 1
    case moderate = 2
    case serious = 3
    case critical = 4
    case catastrophic = 5

    var color: Color {
        switch self {
        case .minor: return .cyan
        case .moderate: return AppSettings.terminalAmber
        case .serious: return .orange
        case .critical: return AppSettings.terminalRed
        case .catastrophic: return .red
        }
    }

    var description: String {
        switch self {
        case .minor: return "MINOR"
        case .moderate: return "MODERATE"
        case .serious: return "SERIOUS"
        case .critical: return "CRITICAL"
        case .catastrophic: return "CATASTROPHIC"
        }
    }
}

/// A crisis event that requires player decision
struct CrisisEvent: Identifiable, Codable {
    let id: UUID
    let type: CrisisEventType
    let severity: CrisisSeverity
    let title: String
    let description: String
    let affectedCountries: [String]
    let turn: Int
    let timeLimit: Int?  // Seconds to respond (nil = no limit)
    let options: [CrisisOption]
    var resolved: Bool = false
    var chosenOption: Int?

    init(type: CrisisEventType, severity: CrisisSeverity, title: String, description: String,
         affectedCountries: [String], turn: Int, timeLimit: Int? = nil, options: [CrisisOption]) {
        self.id = UUID()
        self.type = type
        self.severity = severity
        self.title = title
        self.description = description
        self.affectedCountries = affectedCountries
        self.turn = turn
        self.timeLimit = timeLimit
        self.options = options
    }
}

/// An option for responding to a crisis
struct CrisisOption: Identifiable, Codable {
    let id: UUID
    let title: String
    let description: String
    let advisorRecommendation: String?  // Which advisor recommends this
    let consequences: CrisisConsequences
    let successChance: Double  // 0.0-1.0

    init(title: String, description: String, advisorRecommendation: String? = nil,
         consequences: CrisisConsequences, successChance: Double = 1.0) {
        self.id = UUID()
        self.title = title
        self.description = description
        self.advisorRecommendation = advisorRecommendation
        self.consequences = consequences
        self.successChance = successChance
    }
}

/// Consequences of a crisis decision
struct CrisisConsequences: Codable {
    var relationshipChanges: [String: Int] = [:]  // Country ID -> change
    var approvalChange: Int = 0
    var defconChange: Int = 0
    var economicImpact: Int = 0
    var militaryImpact: Int = 0
    var triggersWar: Bool = false
    var warTarget: String?
    var message: String

    init(relationshipChanges: [String: Int] = [:], approvalChange: Int = 0,
         defconChange: Int = 0, economicImpact: Int = 0, militaryImpact: Int = 0,
         triggersWar: Bool = false, warTarget: String? = nil, message: String) {
        self.relationshipChanges = relationshipChanges
        self.approvalChange = approvalChange
        self.defconChange = defconChange
        self.economicImpact = economicImpact
        self.militaryImpact = militaryImpact
        self.triggersWar = triggersWar
        self.warTarget = warTarget
        self.message = message
    }
}

/// Manages crisis events during gameplay
class CrisisManager: ObservableObject {
    @Published var activeCrisis: CrisisEvent?
    @Published var crisisHistory: [CrisisEvent] = []
    @Published var crisisTimeRemaining: Int = 0

    private var timer: Timer?

    /// Generate a random crisis event based on game state
    func generateRandomCrisis(gameState: GameState) -> CrisisEvent? {
        // Higher DEFCON = more likely to have crisis
        let crisisProbability: Double
        switch gameState.defconLevel {
        case .defcon5: crisisProbability = 0.05
        case .defcon4: crisisProbability = 0.10
        case .defcon3: crisisProbability = 0.20
        case .defcon2: crisisProbability = 0.35
        case .defcon1: crisisProbability = 0.50
        }

        guard Double.random(in: 0...1) < crisisProbability else { return nil }

        // Select random crisis type
        let crisisTypes: [CrisisEventType] = [
            .falseAlarm, .nuclearAccident, .terroristThreat, .espionageDiscovered,
            .militaryCoup, .cyberAttack, .diplomaticIncident, .economicCollapse,
            .rogueCommander, .satelliteFailure, .civilUnrest, .weaponsMalfunction,
            .radiationLeak, .spyRingUncovered, .assassinationAttempt
        ]

        let type = crisisTypes.randomElement()!
        return createCrisis(type: type, gameState: gameState)
    }

    /// Create a specific crisis event
    func createCrisis(type: CrisisEventType, gameState: GameState) -> CrisisEvent {
        switch type {
        case .falseAlarm:
            return createFalseAlarmCrisis(gameState: gameState)
        case .nuclearAccident:
            return createNuclearAccidentCrisis(gameState: gameState)
        case .terroristThreat:
            return createTerroristThreatCrisis(gameState: gameState)
        case .rogueCommander:
            return createRogueCommanderCrisis(gameState: gameState)
        case .cyberAttack:
            return createCyberAttackCrisis(gameState: gameState)
        case .militaryCoup:
            return createMilitaryCoupCrisis(gameState: gameState)
        case .espionageDiscovered:
            return createEspionageCrisis(gameState: gameState)
        case .diplomaticIncident:
            return createDiplomaticIncidentCrisis(gameState: gameState)
        case .economicCollapse:
            return createEconomicCollapseCrisis(gameState: gameState)
        case .satelliteFailure:
            return createSatelliteFailureCrisis(gameState: gameState)
        case .civilUnrest:
            return createCivilUnrestCrisis(gameState: gameState)
        case .weaponsMalfunction:
            return createWeaponsMalfunctionCrisis(gameState: gameState)
        case .radiationLeak:
            return createRadiationLeakCrisis(gameState: gameState)
        case .spyRingUncovered:
            return createSpyRingCrisis(gameState: gameState)
        case .assassinationAttempt:
            return createAssassinationCrisis(gameState: gameState)
        }
    }

    // MARK: - Crisis Factories

    private func createFalseAlarmCrisis(gameState: GameState) -> CrisisEvent {
        let enemy = gameState.countries.filter { $0.nuclearWarheads > 0 && !$0.isPlayerControlled }.randomElement()!

        return CrisisEvent(
            type: .falseAlarm,
            severity: .critical,
            title: "🚨 FALSE ALARM DETECTED",
            description: """
            NORAD has detected what appears to be \(Int.random(in: 50...500)) ICBMs launched from \(enemy.name).

            Early warning satellites show multiple launches.
            Ground radar is attempting confirmation.

            Time to impact: 15 minutes

            WARNING: This may be a false alarm. Soviet officer Stanislav Petrov saved the world in 1983 by correctly identifying a false alarm.
            """,
            affectedCountries: [enemy.id],
            turn: gameState.turn,
            timeLimit: 60,
            options: [
                CrisisOption(
                    title: "Launch Immediate Counterstrike",
                    description: "Launch all ICBMs before we're destroyed",
                    advisorRecommendation: "Pete Hegseth",
                    consequences: CrisisConsequences(
                        relationshipChanges: [enemy.id: -100],
                        approvalChange: -30,
                        defconChange: 0,
                        triggersWar: true,
                        warTarget: enemy.id,
                        message: "You launched nuclear weapons based on a FALSE ALARM. Millions dead. World condemns your rash action."
                    )
                ),
                CrisisOption(
                    title: "Wait for Confirmation",
                    description: "Wait for ground radar confirmation (Petrov's choice)",
                    advisorRecommendation: "Tulsi Gabbard",
                    consequences: CrisisConsequences(
                        approvalChange: 15,
                        message: "Ground radar confirms: FALSE ALARM. You saved the world by remaining calm. +15 approval."
                    ),
                    successChance: 0.85
                ),
                CrisisOption(
                    title: "Alert Allies, Prepare Response",
                    description: "Increase readiness, notify NATO, but don't launch",
                    advisorRecommendation: "Marco Rubio",
                    consequences: CrisisConsequences(
                        defconChange: -1,
                        message: "FALSE ALARM confirmed. Allies appreciate measured response."
                    )
                ),
                CrisisOption(
                    title: "Hotline to Enemy Leader",
                    description: "Use Moscow hotline to verify",
                    advisorRecommendation: "Marco Rubio",
                    consequences: CrisisConsequences(
                        relationshipChanges: [enemy.id: 10],
                        message: "Hotline confirms no launch. Crisis averted through diplomacy."
                    ),
                    successChance: 0.90
                )
            ]
        )
    }

    private func createNuclearAccidentCrisis(gameState: GameState) -> CrisisEvent {
        let country = gameState.countries.filter { $0.nuclearWarheads > 0 }.randomElement()!

        return CrisisEvent(
            type: .nuclearAccident,
            severity: .serious,
            title: "☢️ NUCLEAR REACTOR MELTDOWN",
            description: """
            A nuclear reactor at \(country.name)'s largest power plant is experiencing a critical failure.

            Radiation levels rising rapidly.
            Meltdown imminent in 2 hours.
            Fallout will affect neighboring countries.

            \(country.name) government requesting international assistance.
            """,
            affectedCountries: [country.id],
            turn: gameState.turn,
            timeLimit: nil,
            options: [
                CrisisOption(
                    title: "Provide Emergency Aid",
                    description: "Send nuclear experts and equipment",
                    consequences: CrisisConsequences(
                        relationshipChanges: [country.id: 25],
                        approvalChange: 10,
                        economicImpact: -500,
                        message: "Your aid prevents total meltdown. \(country.name) deeply grateful. +25 relations."
                    ),
                    successChance: 0.75
                ),
                CrisisOption(
                    title: "Offer Humanitarian Support Only",
                    description: "Evacuation assistance, medical aid",
                    consequences: CrisisConsequences(
                        relationshipChanges: [country.id: 10],
                        approvalChange: 5,
                        economicImpact: -100,
                        message: "Limited support provided. Meltdown continues but casualties reduced."
                    )
                ),
                CrisisOption(
                    title: "Remain Neutral",
                    description: "This is their problem, not ours",
                    advisorRecommendation: "Tulsi Gabbard",
                    consequences: CrisisConsequences(
                        relationshipChanges: [country.id: -15],
                        message: "Meltdown occurs. International community criticizes your inaction."
                    )
                ),
                CrisisOption(
                    title: "Blame Enemy Sabotage",
                    description: "Claim this was hostile act",
                    advisorRecommendation: "John Ratcliffe",
                    consequences: CrisisConsequences(
                        relationshipChanges: [country.id: -20],
                        approvalChange: -5,
                        message: "Accusation strains relations. No evidence of sabotage found."
                    ),
                    successChance: 0.20
                )
            ]
        )
    }

    private func createTerroristThreatCrisis(gameState: GameState) -> CrisisEvent {
        let target = gameState.countries.filter { !$0.isPlayerControlled }.randomElement()!

        return CrisisEvent(
            type: .terroristThreat,
            severity: .catastrophic,
            title: "💣 NUCLEAR DEVICE STOLEN",
            description: """
            URGENT: Terrorist group has stolen tactical nuclear weapon from \(target.name).

            Yield: 10 kilotons (Hiroshima-size)
            Location: Unknown
            Target: Likely major Western city

            CIA believes they plan to detonate within 48 hours.
            """,
            affectedCountries: [target.id],
            turn: gameState.turn,
            timeLimit: 90,
            options: [
                CrisisOption(
                    title: "Launch Special Forces Operation",
                    description: "SEAL Team 6 assault on suspected location",
                    advisorRecommendation: "Pete Hegseth",
                    consequences: CrisisConsequences(
                        approvalChange: 25,
                        message: "Special forces recover device! Crisis averted. World celebrates."
                    ),
                    successChance: 0.60
                ),
                CrisisOption(
                    title: "Demand \(target.name) Handle It",
                    description: "This is their weapon, their problem",
                    consequences: CrisisConsequences(
                        relationshipChanges: [target.id: -30],
                        approvalChange: -20,
                        message: "\(target.name) fails to recover device. Detonation kills 100,000. Blood on your hands."
                    ),
                    successChance: 0.30
                ),
                CrisisOption(
                    title: "Coordinate International Response",
                    description: "Share intelligence, coordinate with allies",
                    advisorRecommendation: "Marco Rubio",
                    consequences: CrisisConsequences(
                        relationshipChanges: [target.id: 15],
                        approvalChange: 15,
                        message: "International cooperation locates and disarms device."
                    ),
                    successChance: 0.70
                ),
                CrisisOption(
                    title: "Launch Cyber Operation",
                    description: "NSA tracks terrorist communications",
                    advisorRecommendation: "John Ratcliffe",
                    consequences: CrisisConsequences(
                        approvalChange: 20,
                        message: "NSA intercepts communications, pinpoints location. Device recovered."
                    ),
                    successChance: 0.65
                )
            ]
        )
    }

    private func createRogueCommanderCrisis(gameState: GameState) -> CrisisEvent {
        let country = gameState.countries.filter { $0.nuclearWarheads > 10 }.randomElement()!
        let warheads = Int.random(in: 5...20)

        return CrisisEvent(
            type: .rogueCommander,
            severity: .catastrophic,
            title: "⚠️ ROGUE NUCLEAR COMMANDER",
            description: """
            \(country.name) colonel has gone rogue with access to \(warheads) nuclear warheads.

            Commander: Unstable, suffering mental breakdown
            Demands: Unclear, making incoherent threats
            Warheads: Under his control at remote silo
            Risk: May launch at any moment

            This is a CRIMSON TIDE scenario.
            """,
            affectedCountries: [country.id],
            turn: gameState.turn,
            timeLimit: 45,
            options: [
                CrisisOption(
                    title: "Neutralize with Military Strike",
                    description: "Destroy silo before he can launch",
                    advisorRecommendation: "Pete Hegseth",
                    consequences: CrisisConsequences(
                        relationshipChanges: [country.id: -40],
                        approvalChange: 10,
                        message: "Strike successful. Warheads destroyed. \(country.name) furious at violation of sovereignty."
                    ),
                    successChance: 0.70
                ),
                CrisisOption(
                    title: "Negotiate with Commander",
                    description: "Talk him down, de-escalate",
                    advisorRecommendation: "Tulsi Gabbard",
                    consequences: CrisisConsequences(
                        relationshipChanges: [country.id: 5],
                        approvalChange: 15,
                        message: "Negotiation successful. Commander stands down. No casualties."
                    ),
                    successChance: 0.50
                ),
                CrisisOption(
                    title: "Support \(country.name) Forces",
                    description: "Provide intelligence, let them handle it",
                    advisorRecommendation: "Marco Rubio",
                    consequences: CrisisConsequences(
                        relationshipChanges: [country.id: 20],
                        message: "\(country.name) special forces secure silo. Crisis resolved."
                    ),
                    successChance: 0.60
                ),
                CrisisOption(
                    title: "Prepare for Launch",
                    description: "Assume he'll launch, prepare response",
                    consequences: CrisisConsequences(
                        defconChange: -2,
                        message: "Commander launches warhead. Defensive systems intercept. 1 warhead detonates, 50K dead."
                    ),
                    successChance: 0.40
                )
            ]
        )
    }

    private func createCyberAttackCrisis(gameState: GameState) -> CrisisEvent {
        let enemy = gameState.countries.filter { !$0.isPlayerControlled }.randomElement()!

        return CrisisEvent(
            type: .cyberAttack,
            severity: .critical,
            title: "💻 CYBER ATTACK ON NUCLEAR COMMAND",
            description: """
            Massive cyber attack detected on nuclear command and control systems.

            Origin: Traced to \(enemy.name)
            Target: Launch authorization systems
            Status: Partial penetration achieved
            Risk: Unauthorized launch possible

            NSA and Cyber Command responding.
            """,
            affectedCountries: [enemy.id],
            turn: gameState.turn,
            timeLimit: 60,
            options: [
                CrisisOption(
                    title: "Launch Immediate Counterattack",
                    description: "Cyber warfare against \(enemy.name)",
                    advisorRecommendation: "Mike Waltz",
                    consequences: CrisisConsequences(
                        relationshipChanges: [enemy.id: -30],
                        message: "Counterattack successful. Their systems crippled. They retaliate conventionally."
                    ),
                    successChance: 0.70
                ),
                CrisisOption(
                    title: "Isolate Nuclear Systems",
                    description: "Air-gap critical infrastructure",
                    advisorRecommendation: "Kristi Noem",
                    consequences: CrisisConsequences(
                        message: "Systems isolated. Attack contained. No damage."
                    ),
                    successChance: 0.85
                ),
                CrisisOption(
                    title: "Public Attribution",
                    description: "Expose \(enemy.name) to world",
                    advisorRecommendation: "Marco Rubio",
                    consequences: CrisisConsequences(
                        relationshipChanges: [enemy.id: -20],
                        approvalChange: 10,
                        message: "World condemns \(enemy.name). International sanctions imposed."
                    )
                ),
                CrisisOption(
                    title: "Silent Defense",
                    description: "Repel attack, don't escalate",
                    advisorRecommendation: "Tulsi Gabbard",
                    consequences: CrisisConsequences(
                        message: "Attack repelled quietly. No escalation."
                    ),
                    successChance: 0.80
                )
            ]
        )
    }

    // Stub implementations for remaining crisis types
    private func createMilitaryCoupCrisis(gameState: GameState) -> CrisisEvent {
        let country = gameState.countries.filter { $0.nuclearWarheads > 0 && !$0.isPlayerControlled }.randomElement()!
        return createSimpleCrisis(type: .militaryCoup, title: "Military Coup in \(country.name)", country: country, gameState: gameState)
    }

    private func createEspionageCrisis(gameState: GameState) -> CrisisEvent {
        let country = gameState.countries.filter { !$0.isPlayerControlled }.randomElement()!
        return createSimpleCrisis(type: .espionageDiscovered, title: "Spy Ring Discovered", country: country, gameState: gameState)
    }

    private func createDiplomaticIncidentCrisis(gameState: GameState) -> CrisisEvent {
        let country = gameState.countries.filter { !$0.isPlayerControlled }.randomElement()!
        return createSimpleCrisis(type: .diplomaticIncident, title: "Embassy Attack", country: country, gameState: gameState)
    }

    private func createEconomicCollapseCrisis(gameState: GameState) -> CrisisEvent {
        let country = gameState.countries.filter { !$0.isPlayerControlled }.randomElement()!
        return createSimpleCrisis(type: .economicCollapse, title: "Economic Collapse", country: country, gameState: gameState)
    }

    private func createSatelliteFailureCrisis(gameState: GameState) -> CrisisEvent {
        return createSimpleCrisis(type: .satelliteFailure, title: "Satellite Failure", country: nil, gameState: gameState)
    }

    private func createCivilUnrestCrisis(gameState: GameState) -> CrisisEvent {
        let country = gameState.countries.filter { !$0.isPlayerControlled }.randomElement()!
        return createSimpleCrisis(type: .civilUnrest, title: "Civil Unrest", country: country, gameState: gameState)
    }

    private func createWeaponsMalfunctionCrisis(gameState: GameState) -> CrisisEvent {
        return createSimpleCrisis(type: .weaponsMalfunction, title: "Weapons Malfunction", country: nil, gameState: gameState)
    }

    private func createRadiationLeakCrisis(gameState: GameState) -> CrisisEvent {
        let country = gameState.countries.filter { $0.nuclearWarheads > 0 }.randomElement()!
        return createSimpleCrisis(type: .radiationLeak, title: "Radiation Leak", country: country, gameState: gameState)
    }

    private func createSpyRingCrisis(gameState: GameState) -> CrisisEvent {
        let country = gameState.countries.filter { !$0.isPlayerControlled }.randomElement()!
        return createSimpleCrisis(type: .spyRingUncovered, title: "Spy Ring Uncovered", country: country, gameState: gameState)
    }

    private func createAssassinationCrisis(gameState: GameState) -> CrisisEvent {
        let country = gameState.countries.filter { !$0.isPlayerControlled }.randomElement()!
        return createSimpleCrisis(type: .assassinationAttempt, title: "Assassination Attempt", country: country, gameState: gameState)
    }

    private func createSimpleCrisis(type: CrisisEventType, title: String, country: Country?, gameState: GameState) -> CrisisEvent {
        return CrisisEvent(
            type: type,
            severity: .moderate,
            title: title,
            description: "Crisis event: \(title)",
            affectedCountries: country.map { [$0.id] } ?? [],
            turn: gameState.turn,
            timeLimit: nil,
            options: [
                CrisisOption(
                    title: "Respond",
                    description: "Take action",
                    consequences: CrisisConsequences(message: "Crisis handled.")
                ),
                CrisisOption(
                    title: "Ignore",
                    description: "Do nothing",
                    consequences: CrisisConsequences(message: "Crisis unresolved.")
                )
            ]
        )
    }

    /// Present crisis to player
    func presentCrisis(_ crisis: CrisisEvent) {
        activeCrisis = crisis
        if let timeLimit = crisis.timeLimit {
            crisisTimeRemaining = timeLimit
            startTimer()
        }
    }

    /// Resolve crisis with chosen option
    func resolveCrisis(optionIndex: Int, gameState: inout GameState) {
        guard var crisis = activeCrisis, optionIndex < crisis.options.count else { return }

        let option = crisis.options[optionIndex]

        // Roll for success
        let success = Double.random(in: 0...1) < option.successChance

        if success {
            applyConsequences(option.consequences, to: &gameState)
        } else {
            // Failed attempt has worse consequences
            let failureMessage = "Attempt failed! Crisis worsens."
            gameState.totalCasualties += Int.random(in: 1000...10000)
        }

        // Mark crisis as resolved
        crisis.resolved = true
        crisis.chosenOption = optionIndex
        crisisHistory.append(crisis)
        activeCrisis = nil
        stopTimer()
    }

    /// Apply consequences to game state
    private func applyConsequences(_ consequences: CrisisConsequences, to gameState: inout GameState) {
        // Apply relationship changes
        for (countryID, change) in consequences.relationshipChanges {
            gameState.modifyRelation(from: gameState.playerCountryID, to: countryID, by: change)
        }

        // Apply DEFCON change
        if consequences.defconChange != 0 {
            let newLevel = max(1, min(5, gameState.defconLevel.rawValue + consequences.defconChange))
            gameState.defconLevel = DefconLevel(rawValue: newLevel) ?? gameState.defconLevel
        }

        // Trigger war if needed
        if consequences.triggersWar, let target = consequences.warTarget {
            let war = War(aggressor: gameState.playerCountryID, defender: target, startTurn: gameState.turn, intensity: 8)
            gameState.activeWars.append(war)
        }
    }

    // MARK: - Timer Management

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.crisisTimeRemaining > 0 {
                self.crisisTimeRemaining -= 1
            } else {
                // Time ran out - force random decision
                self.stopTimer()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        crisisTimeRemaining = 0
    }
}
