//
//  CrisisEvents.swift
//  Global Thermal Nuclear War
//
//  Dynamic crisis events that create tension and force tough choices
//  Created by Jordan Koch on 2025-12-03.
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
                ),
                CrisisOption(
                    title: "Launch Limited Strike",
                    description: "Strike only military targets, hold reserves",
                    advisorRecommendation: "Pete Hegseth",
                    consequences: CrisisConsequences(
                        relationshipChanges: [enemy.id: -80],
                        approvalChange: -20,
                        triggersWar: true,
                        warTarget: enemy.id,
                        message: "Limited strike on false alarm. Escalation restrained but world horrified. War declared."
                    ),
                    successChance: 0.60
                ),
                CrisisOption(
                    title: "Evacuate Cities, Await Intel",
                    description: "Civil defense activation, wait for more data",
                    advisorRecommendation: "Kristi Noem",
                    consequences: CrisisConsequences(
                        approvalChange: 5,
                        economicImpact: -1000,
                        message: "FALSE ALARM confirmed. Evacuation costly but citizens appreciate caution."
                    ),
                    successChance: 0.95
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
                ),
                CrisisOption(
                    title: "Deploy Military Containment",
                    description: "Send troops to establish quarantine zone",
                    advisorRecommendation: "Pete Hegseth",
                    consequences: CrisisConsequences(
                        relationshipChanges: [country.id: -10],
                        approvalChange: 8,
                        economicImpact: -750,
                        message: "Containment successful. Radiation limited. Military presence resented but effective."
                    ),
                    successChance: 0.80
                ),
                CrisisOption(
                    title: "Demand UN Investigation",
                    description: "Call for international nuclear safety review",
                    advisorRecommendation: "Marco Rubio",
                    consequences: CrisisConsequences(
                        approvalChange: 3,
                        message: "UN investigation launched. Meltdown contained. Safety protocols strengthened globally."
                    ),
                    successChance: 0.70
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
                ),
                CrisisOption(
                    title: "Offer Ransom Payment",
                    description: "Negotiate $100M payment for device return",
                    advisorRecommendation: "Scott Bessent",
                    consequences: CrisisConsequences(
                        approvalChange: -15,
                        economicImpact: -10000,
                        message: "Ransom paid. Device recovered but setting dangerous precedent."
                    ),
                    successChance: 0.85
                ),
                CrisisOption(
                    title: "Evacuate Major Cities",
                    description: "Emergency evacuation, hope they don't detonate",
                    advisorRecommendation: "Kristi Noem",
                    consequences: CrisisConsequences(
                        approvalChange: -5,
                        economicImpact: -5000,
                        message: "Evacuation chaotic. Device detonates in evacuated area - 10K dead vs 100K if unprepared."
                    ),
                    successChance: 0.50
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
                ),
                CrisisOption(
                    title: "Deploy Psychological Operations",
                    description: "Use psyops to confuse/delay commander",
                    advisorRecommendation: "John Ratcliffe",
                    consequences: CrisisConsequences(
                        approvalChange: 18,
                        message: "Psyops successful. Commander becomes disoriented. \(country.name) forces regain control."
                    ),
                    successChance: 0.65
                ),
                CrisisOption(
                    title: "EMP Strike on Silo",
                    description: "Disable electronics without destroying warheads",
                    advisorRecommendation: "Elon Musk",
                    consequences: CrisisConsequences(
                        relationshipChanges: [country.id: -25],
                        approvalChange: 12,
                        message: "EMP disables launch systems. Warheads secured. \(country.name) protests sovereignty violation."
                    ),
                    successChance: 0.75
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
                ),
                CrisisOption(
                    title: "Launch Proportional Cyber Strike",
                    description: "Hit their infrastructure equally hard",
                    advisorRecommendation: "Mike Waltz",
                    consequences: CrisisConsequences(
                        relationshipChanges: [enemy.id: -35],
                        approvalChange: 8,
                        message: "Proportional response. Their power grid down 48 hours. Message sent."
                    ),
                    successChance: 0.75
                ),
                CrisisOption(
                    title: "Activate Cyber Defense Protocol Omega",
                    description: "NSA's most advanced countermeasures",
                    advisorRecommendation: "John Ratcliffe",
                    consequences: CrisisConsequences(
                        approvalChange: 15,
                        economicImpact: -1000,
                        message: "Protocol Omega activated. Attack completely neutralized. Systems hardened."
                    ),
                    successChance: 0.90
                )
            ]
        )
    }

    // Stub implementations for remaining crisis types
    private func createMilitaryCoupCrisis(gameState: GameState) -> CrisisEvent {
        let country = gameState.countries.filter { $0.nuclearWarheads > 0 && !$0.isPlayerControlled }.randomElement()!
        let generalNames = ["General Alexei Volkov", "Colonel Chen Zhao", "General Hassan Al-Sayed", "Marshal Kim Yong-chol", "General Dmitri Petrov"]
        let general = generalNames.randomElement()!
        let units = ["3rd Mechanized Division", "Strategic Rocket Forces", "Republican Guard", "82nd Airborne Brigade", "Naval Infantry Brigade"]
        let unit = units.randomElement()!
        let demands = ["democratic elections", "removal of corrupt officials", "military control", "expulsion of foreign forces", "redistribution of wealth"]
        let demand = demands.randomElement()!

        return CrisisEvent(
            type: .militaryCoup,
            severity: .catastrophic,
            title: "⚔️ MILITARY COUP IN \(country.name.uppercased())",
            description: """
            URGENT: Military coup underway in \(country.name).

            Coup Leader: \(general)
            Forces: \(unit) (\(Int.random(in: 5000...50000)) troops)
            Status: Capital surrounded, president trapped
            Demands: \(demand.capitalized)

            Nuclear Situation:
            • \(country.nuclearWarheads) warheads
            • Launch authority disputed
            • Coup forces control \(Int.random(in: 2...8)) ICBM silos
            • Risk of unauthorized launch HIGH

            International Response:
            • UN Security Council emergency session
            • Neighboring countries mobilizing
            • Markets in free-fall
            • Refugees fleeing borders

            \(general) has made no statements. Intentions unclear.
            """,
            affectedCountries: [country.id],
            turn: gameState.turn,
            timeLimit: 90,
            options: [
                CrisisOption(
                    title: "Support Existing Government",
                    description: "Military aid to help president",
                    advisorRecommendation: "Pete Hegseth",
                    consequences: CrisisConsequences(
                        relationshipChanges: [country.id: 20],
                        approvalChange: 10,
                        economicImpact: -2000,
                        message: "Your support tips balance. Coup fails. Government restored. Relations excellent."
                    ),
                    successChance: 0.65
                ),
                CrisisOption(
                    title: "Recognize Coup Government",
                    description: "Pragmatic: work with whoever wins",
                    advisorRecommendation: "Tulsi Gabbard",
                    consequences: CrisisConsequences(
                        relationshipChanges: [country.id: 15],
                        approvalChange: -15,
                        message: "Coup succeeds. New regime appreciates early recognition. Domestic criticism severe."
                    ),
                    successChance: 0.80
                ),
                CrisisOption(
                    title: "Negotiate with Both Sides",
                    description: "Mediate power-sharing agreement",
                    advisorRecommendation: "Marco Rubio",
                    consequences: CrisisConsequences(
                        relationshipChanges: [country.id: 25],
                        approvalChange: 20,
                        message: "Negotiation successful. Coalition government formed. Civil war averted."
                    ),
                    successChance: 0.55
                ),
                CrisisOption(
                    title: "Secure Nuclear Weapons Only",
                    description: "Special forces seize nuclear sites, ignore politics",
                    advisorRecommendation: "John Ratcliffe",
                    consequences: CrisisConsequences(
                        relationshipChanges: [country.id: -40],
                        approvalChange: 15,
                        message: "Warheads secured. Both sides furious at interference. No nukes launched."
                    ),
                    successChance: 0.75
                ),
                CrisisOption(
                    title: "Economic Sanctions on Coup Leaders",
                    description: "Freeze assets, pressure resignation",
                    advisorRecommendation: "Scott Bessent",
                    consequences: CrisisConsequences(
                        approvalChange: 8,
                        message: "Sanctions bite. Coup leaders negotiate. Peaceful transition achieved."
                    ),
                    successChance: 0.60
                ),
                CrisisOption(
                    title: "Wait and Observe",
                    description: "Let internal politics play out",
                    advisorRecommendation: "Tulsi Gabbard",
                    consequences: CrisisConsequences(
                        defconChange: -1,
                        message: "Coup succeeds violently. \(Int.random(in: 5000...50000)) dead. New regime anti-Western."
                    ),
                    successChance: 1.0
                )
            ]
        )
    }

    private func createEspionageCrisis(gameState: GameState) -> CrisisEvent {
        let country = gameState.countries.filter { !$0.isPlayerControlled }.randomElement()!
        let agentNames = ["Sarah Chen", "Viktor Sokolov", "Abdul Rahman", "Li Wei", "Maria Volkov", "Hassan Al-Din"]
        let agent = agentNames.randomElement()!
        let coverJobs = ["embassy attaché", "trade representative", "journalist", "NGO worker", "academic researcher", "tech company employee"]
        let coverJob = coverJobs.randomElement()!
        let classified = ["nuclear launch codes", "ICBM deployment plans", "SDI technology", "submarine patrol routes", "CIA NOC list", "NSA encryption keys"]
        let documents = classified.randomElement()!
        let yearsActive = Int.random(in: 2...15)

        return CrisisEvent(
            type: .espionageDiscovered,
            severity: .serious,
            title: "🕵️ MAJOR SPY RING UNCOVERED IN \(country.name.uppercased())",
            description: """
            FBI arrests \(agent), deep-cover \(country.name) spy operating as \(coverJob).

            Spy Details:
            • Real name: \(agent)
            • Cover identity: \(Int.random(in: 3...7)) years established
            • Years active: \(yearsActive)
            • Handler: \(country.name) GRU/SVR officer
            • Documents stolen: \(documents)

            Network Extent:
            • \(Int.random(in: 5...20)) co-conspirators identified
            • Penetration of \(["Pentagon", "CIA", "NSA", "State Department", "DOE"].randomElement()!)
            • Damage assessment: SEVERE
            • Ongoing investigation

            \(country.name) denies everything. Ambassador recalled.

            This is the worst intelligence breach since Aldrich Ames.
            """,
            affectedCountries: [country.id],
            turn: gameState.turn,
            timeLimit: nil,
            options: [
                CrisisOption(
                    title: "Public Trial and Execution",
                    description: "Make example of \(agent), deter future spies",
                    advisorRecommendation: "Pete Hegseth",
                    consequences: CrisisConsequences(
                        relationshipChanges: [country.id: -40],
                        approvalChange: 15,
                        message: "Trial televised. \(agent) executed. \(country.name) retaliates by arresting your citizens."
                    ),
                    successChance: 1.0
                ),
                CrisisOption(
                    title: "Prisoner Exchange Negotiation",
                    description: "Trade \(agent) for your captured agents",
                    advisorRecommendation: "Marco Rubio",
                    consequences: CrisisConsequences(
                        relationshipChanges: [country.id: 10],
                        approvalChange: -5,
                        message: "Exchange successful. 3 of your agents returned. Intelligence community furious."
                    ),
                    successChance: 0.85
                ),
                CrisisOption(
                    title: "Turn \(agent) Into Double Agent",
                    description: "Feed false information through spy network",
                    advisorRecommendation: "John Ratcliffe",
                    consequences: CrisisConsequences(
                        approvalChange: 20,
                        message: "\(agent) agrees to cooperate. Feed false intel to \(country.name) for 5 turns. Major advantage."
                    ),
                    successChance: 0.70
                ),
                CrisisOption(
                    title: "Massive Counterintelligence Sweep",
                    description: "Dismantle entire \(country.name) spy network",
                    advisorRecommendation: "John Ratcliffe",
                    consequences: CrisisConsequences(
                        relationshipChanges: [country.id: -30],
                        approvalChange: 25,
                        message: "Sweep successful. \(Int.random(in: 12...35)) \(country.name) agents arrested. Network destroyed."
                    ),
                    successChance: 0.80
                ),
                CrisisOption(
                    title: "Quiet Deportation",
                    description: "Expel spy quietly, avoid diplomatic incident",
                    advisorRecommendation: "Tulsi Gabbard",
                    consequences: CrisisConsequences(
                        relationshipChanges: [country.id: -5],
                        approvalChange: -10,
                        message: "Quiet resolution. Public angry about weakness. \(country.name) continues spying."
                    ),
                    successChance: 1.0
                ),
                CrisisOption(
                    title: "Cyber Retaliation Against \(country.name)",
                    description: "Hack their intelligence services",
                    advisorRecommendation: "Mike Waltz",
                    consequences: CrisisConsequences(
                        relationshipChanges: [country.id: -35],
                        approvalChange: 18,
                        message: "Cyber strike steals their entire spy database. You now know all their agents."
                    ),
                    successChance: 0.75
                )
            ]
        )
    }

    private func createDiplomaticIncidentCrisis(gameState: GameState) -> CrisisEvent {
        let country = gameState.countries.filter { !$0.isPlayerControlled }.randomElement()!
        return createSimpleCrisis(type: .diplomaticIncident, title: "🏛️ Embassy Attack in \(country.name)", country: country, gameState: gameState)
    }

    private func createEconomicCollapseCrisis(gameState: GameState) -> CrisisEvent {
        let country = gameState.countries.filter { !$0.isPlayerControlled }.randomElement()!
        let debtB = Int.random(in: 50...500)
        let unemployment = Int.random(in: 25...60)
        return createDetailedCrisis(
            type: .economicCollapse,
            title: "💰 \(country.name) Economic Collapse",
            description: "\(country.name) economy in free-fall. National debt: $\(debtB)B. Unemployment: \(unemployment)%. Currency worthless. \(Int.random(in: 100...500))K refugees fleeing. Government requesting emergency aid. Risk of state failure.",
            country: country,
            gameState: gameState
        )
    }

    private func createSatelliteFailureCrisis(gameState: GameState) -> CrisisEvent {
        let country = gameState.countries.filter { $0.nuclearWarheads > 10 }.randomElement()!
        let satellites = ["DSP-23", "SBIRS GEO-5", "NRO L-82", "Oko-7"]
        let sat = satellites.randomElement()!
        return createDetailedCrisis(
            type: .satelliteFailure,
            title: "🛰️ \(country.name) Satellite \(sat) Failed",
            description: "\(country.name) early warning satellite \(sat) has failed. Orbit: \(Int.random(in: 500...35000))km. Telemetry lost. \(country.name) blind to missile launches. Early warning time reduced 15min → 5min. Risk of false alarm DRAMATICALLY increased.",
            country: country,
            gameState: gameState
        )
    }

    private func createCivilUnrestCrisis(gameState: GameState) -> CrisisEvent {
        let country = gameState.countries.filter { !$0.isPlayerControlled }.randomElement()!
        let protesters = Int.random(in: 50_000...1_000_000)
        let deaths = Int.random(in: 10...500)
        return createDetailedCrisis(
            type: .civilUnrest,
            title: "🔥 Massive Unrest in \(country.name)",
            description: "Civil unrest in \(country.name) capital. \(protesters.formatted()) protesters demanding reforms. Turned violent. \(deaths) dead, \(deaths * 3) injured. \(country.name) has \(country.nuclearWarheads) warheads. Military loyalty uncertain. Risk of coup.",
            country: country,
            gameState: gameState
        )
    }

    private func createWeaponsMalfunctionCrisis(gameState: GameState) -> CrisisEvent {
        let country = gameState.countries.filter { $0.nuclearWarheads > 5 }.randomElement()!
        let weaponType = ["ICBM", "SLBM", "tactical nuke"].randomElement()!
        let warheads = Int.random(in: 1...5)
        return createDetailedCrisis(
            type: .weaponsMalfunction,
            title: "⚠️ \(country.name) Weapons Malfunction",
            description: "\(country.name) \(weaponType) malfunction. \(warheads) warheads. Launch sequence activated accidentally. Countdown: T-minus \(Int.random(in: 5...15)) minutes. Abort codes not responding. Target: UNKNOWN. Accidental launch imminent. This is BROKEN ARROW.",
            country: country,
            gameState: gameState
        )
    }

    private func createRadiationLeakCrisis(gameState: GameState) -> CrisisEvent {
        let country = gameState.countries.filter { $0.nuclearWarheads > 0 }.randomElement()!
        let facility = ["\(country.name) Nuclear Lab", "Weapons Facility", "Enrichment Plant"].randomElement()!
        let leakAmount = Int.random(in: 100...5000)
        return createDetailedCrisis(
            type: .radiationLeak,
            title: "☢️ Radiation Leak at \(facility)",
            description: "Critical radiation leak at \(facility), \(country.name). \(leakAmount) mSv detected (\(leakAmount > 1000 ? "LETHAL" : "DANGEROUS")). \(Int.random(in: 50...500)) workers exposed. \(Int.random(in: 10_000...500_000).formatted()) population at risk. Containment FAILED. \(country.name) requesting help.",
            country: country,
            gameState: gameState
        )
    }

    private func createSpyRingCrisis(gameState: GameState) -> CrisisEvent {
        let country = gameState.countries.filter { !$0.isPlayerControlled }.randomElement()!
        return createSimpleCrisis(type: .spyRingUncovered, title: "Spy Ring Uncovered", country: country, gameState: gameState)
    }

    private func createAssassinationCrisis(gameState: GameState) -> CrisisEvent {
        let country = gameState.countries.filter { !$0.isPlayerControlled }.randomElement()!
        let leaders = ["Prime Minister", "President", "Supreme Leader", "Chancellor", "King", "General Secretary"]
        let leaderTitle = leaders.randomElement()!
        let leaderNames = ["Vladimir Ivanov", "Chen Wei", "Mohammad Al-Rashid", "Kim Jong-nam", "Dmitri Volkov", "Hassan Rouhani", "Viktor Orban"]
        let leaderName = leaderNames.randomElement()!
        let locations = ["state dinner", "military parade", "UN General Assembly", "peace summit", "nuclear facility inspection", "aircraft carrier visit"]
        let eventLocation = locations.randomElement()!
        let methods = ["sniper", "poison", "car bomb", "insider threat", "drone strike"]
        let attackMethod = methods.randomElement()!

        return CrisisEvent(
            type: .assassinationAttempt,
            severity: .catastrophic,
            title: "🎯 ASSASSINATION ATTEMPT ON \(country.name.uppercased()) LEADER",
            description: """
            BREAKING: Assassination attempt on \(country.name) \(leaderTitle) \(leaderName).

            Location: \(eventLocation.capitalized)
            Method: \(attackMethod.capitalized)
            Status: Leader wounded, condition critical
            Suspects: Unknown, investigation ongoing

            Intelligence Assessment:
            • \(country.name) security forces in chaos
            • Hardliners demanding retaliation
            • Nuclear command authority unclear
            • Some officers calling for immediate strikes

            \(country.name) requesting international assistance but threatening "consequences" if Western involvement discovered.

            CIA believes this may be internal power struggle, NOT foreign attack.
            """,
            affectedCountries: [country.id],
            turn: gameState.turn,
            timeLimit: 75,
            options: [
                CrisisOption(
                    title: "Offer Intelligence Assistance",
                    description: "Share CIA findings, help investigation",
                    advisorRecommendation: "John Ratcliffe",
                    consequences: CrisisConsequences(
                        relationshipChanges: [country.id: 25],
                        approvalChange: 10,
                        message: "Intelligence sharing identifies conspirators. \(leaderName) survives. \(country.name) grateful."
                    ),
                    successChance: 0.75
                ),
                CrisisOption(
                    title: "Send Medical Team",
                    description: "Emergency trauma surgeons and equipment",
                    advisorRecommendation: "Robert F. Kennedy Jr.",
                    consequences: CrisisConsequences(
                        relationshipChanges: [country.id: 30],
                        approvalChange: 15,
                        economicImpact: -200,
                        message: "Medical team saves \(leaderName)'s life. \(country.name) eternally grateful."
                    ),
                    successChance: 0.80
                ),
                CrisisOption(
                    title: "Exploit the Chaos",
                    description: "Launch covert operation during instability",
                    advisorRecommendation: "John Ratcliffe",
                    consequences: CrisisConsequences(
                        relationshipChanges: [country.id: -60],
                        approvalChange: -15,
                        message: "Operation detected. \(country.name) knows you exploited crisis. Relations destroyed."
                    ),
                    successChance: 0.60
                ),
                CrisisOption(
                    title: "Express Condolences, Remain Neutral",
                    description: "Diplomatic statement only, no involvement",
                    advisorRecommendation: "Marco Rubio",
                    consequences: CrisisConsequences(
                        relationshipChanges: [country.id: 5],
                        message: "\(leaderName) dies. Hardliners seize power. New regime hostile."
                    ),
                    successChance: 1.0
                ),
                CrisisOption(
                    title: "Blame Rival Nation",
                    description: "Suggest \(gameState.countries.filter { $0.id != country.id && !$0.isPlayerControlled }.randomElement()?.name ?? "enemy") responsible",
                    advisorRecommendation: "Mike Waltz",
                    consequences: CrisisConsequences(
                        approvalChange: -10,
                        message: "Accusation creates diplomatic incident. No proof. Relations worsen across board."
                    ),
                    successChance: 0.30
                ),
                CrisisOption(
                    title: "Deploy Peacekeeping Force",
                    description: "Stabilize situation with military presence",
                    advisorRecommendation: "Pete Hegseth",
                    consequences: CrisisConsequences(
                        relationshipChanges: [country.id: -20],
                        approvalChange: 8,
                        economicImpact: -1500,
                        message: "Peacekeepers prevent civil war. \(country.name) resents occupation but stabilized."
                    ),
                    successChance: 0.70
                )
            ]
        )
    }

    private func createDetailedCrisis(type: CrisisEventType, title: String, description: String, country: Country, gameState: GameState) -> CrisisEvent {
        return CrisisEvent(
            type: type,
            severity: .serious,
            title: title,
            description: description,
            affectedCountries: [country.id],
            turn: gameState.turn,
            timeLimit: nil,
            options: [
                CrisisOption(
                    title: "Military Response",
                    description: "Deploy forces to address situation",
                    advisorRecommendation: "Pete Hegseth",
                    consequences: CrisisConsequences(
                        relationshipChanges: [country.id: -10],
                        approvalChange: 8,
                        economicImpact: -500,
                        message: "Military intervention successful. \(country.name) resents show of force but crisis resolved."
                    ),
                    successChance: 0.75
                ),
                CrisisOption(
                    title: "Diplomatic Resolution",
                    description: "Negotiate peaceful solution",
                    advisorRecommendation: "Marco Rubio",
                    consequences: CrisisConsequences(
                        relationshipChanges: [country.id: 20],
                        approvalChange: 12,
                        message: "Diplomatic solution reached. Crisis averted peacefully. \(country.name) appreciates mediation."
                    ),
                    successChance: 0.65
                ),
                CrisisOption(
                    title: "Economic Aid Package",
                    description: "Provide financial assistance",
                    advisorRecommendation: "Scott Bessent",
                    consequences: CrisisConsequences(
                        relationshipChanges: [country.id: 25],
                        approvalChange: 5,
                        economicImpact: -5000,
                        message: "Aid stabilizes situation. \(country.name) grateful. Crisis resolved."
                    ),
                    successChance: 0.80
                ),
                CrisisOption(
                    title: "Covert Operation",
                    description: "CIA handles quietly",
                    advisorRecommendation: "John Ratcliffe",
                    consequences: CrisisConsequences(
                        approvalChange: 15,
                        economicImpact: -200,
                        message: "Covert operation successful. Crisis resolved with no public knowledge."
                    ),
                    successChance: 0.60
                ),
                CrisisOption(
                    title: "UN/International Coalition",
                    description: "Build multilateral response",
                    advisorRecommendation: "Marco Rubio",
                    consequences: CrisisConsequences(
                        relationshipChanges: [country.id: 15],
                        approvalChange: 18,
                        economicImpact: -300,
                        message: "Coalition response legitimizes action. Crisis resolved with international support."
                    ),
                    successChance: 0.70
                ),
                CrisisOption(
                    title: "Monitor and Wait",
                    description: "Observe, avoid commitment",
                    advisorRecommendation: "Tulsi Gabbard",
                    consequences: CrisisConsequences(
                        relationshipChanges: [country.id: -10],
                        approvalChange: -5,
                        message: "Situation deteriorates without intervention. Crisis worsens."
                    ),
                    successChance: 0.80
                )
            ]
        )
    }

    private func createSimpleCrisis(type: CrisisEventType, title: String, country: Country?, gameState: GameState) -> CrisisEvent {
        let countryName = country?.name ?? "affected nation"
        let countryID = country?.id

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
                    title: "Military Response",
                    description: "Deploy military forces to address situation",
                    advisorRecommendation: "Pete Hegseth",
                    consequences: CrisisConsequences(
                        relationshipChanges: countryID.map { [$0: -10] } ?? [:],
                        approvalChange: 5,
                        economicImpact: -500,
                        message: "Military intervention successful. \(countryName) resents show of force but crisis resolved."
                    ),
                    successChance: 0.70
                ),
                CrisisOption(
                    title: "Diplomatic Resolution",
                    description: "Negotiate peaceful solution",
                    advisorRecommendation: "Marco Rubio",
                    consequences: CrisisConsequences(
                        relationshipChanges: countryID.map { [$0: 15] } ?? [:],
                        approvalChange: 10,
                        message: "Diplomatic solution reached. Crisis averted peacefully. Relations improved."
                    ),
                    successChance: 0.60
                ),
                CrisisOption(
                    title: "Economic Pressure",
                    description: "Apply sanctions or economic leverage",
                    advisorRecommendation: "Scott Bessent",
                    consequences: CrisisConsequences(
                        relationshipChanges: countryID.map { [$0: -20] } ?? [:],
                        approvalChange: 8,
                        message: "Economic pressure forces compliance. Crisis resolved but relations damaged."
                    ),
                    successChance: 0.65
                ),
                CrisisOption(
                    title: "Covert Operation",
                    description: "CIA handles situation quietly",
                    advisorRecommendation: "John Ratcliffe",
                    consequences: CrisisConsequences(
                        approvalChange: 12,
                        economicImpact: -200,
                        message: "Covert operation successful. Crisis resolved with no public knowledge."
                    ),
                    successChance: 0.55
                ),
                CrisisOption(
                    title: "International Coalition",
                    description: "Build UN/NATO consensus for action",
                    advisorRecommendation: "Marco Rubio",
                    consequences: CrisisConsequences(
                        approvalChange: 15,
                        economicImpact: -300,
                        message: "Coalition response legitimizes action. Crisis resolved with international support."
                    ),
                    successChance: 0.75
                ),
                CrisisOption(
                    title: "Monitor and Wait",
                    description: "Observe situation, avoid commitment",
                    advisorRecommendation: "Tulsi Gabbard",
                    consequences: CrisisConsequences(
                        relationshipChanges: countryID.map { [$0: -5] } ?? [:],
                        approvalChange: -3,
                        message: "Situation deteriorates without intervention. Minimal impact but crisis worsens."
                    ),
                    successChance: 0.80
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
