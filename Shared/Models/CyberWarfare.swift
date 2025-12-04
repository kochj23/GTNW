//
//  CyberWarfare.swift
//  Global Thermal Nuclear War
//
//  Advanced cyber warfare and government hacking system
//

import Foundation

/// Cyber attack types with varying effects and detection risks
enum CyberAttackType: String, Codable, CaseIterable {
    case reconnaissance = "Reconnaissance"
    case dataTheft = "Data Theft"
    case infrastructureDisruption = "Infrastructure Disruption"
    case financialSabotage = "Financial Sabotage"
    case militarySystemsHack = "Military Systems Hack"
    case electionInterference = "Election Interference"
    case propagandaCampaign = "Propaganda Campaign"
    case nuclearSystemsPenetration = "Nuclear Systems Penetration"
    case powerGridAttack = "Power Grid Attack"
    case communicationsBlackout = "Communications Blackout"
    case supplyChainsDisruption = "Supply Chain Disruption"
    case bankingSystemCollapse = "Banking System Collapse"

    var detectability: Int {
        switch self {
        case .reconnaissance: return 5
        case .dataTheft: return 15
        case .propagandaCampaign: return 25
        case .electionInterference: return 30
        case .infrastructureDisruption: return 40
        case .supplyChainsDisruption: return 35
        case .financialSabotage: return 45
        case .communicationsBlackout: return 50
        case .powerGridAttack: return 55
        case .militarySystemsHack: return 60
        case .bankingSystemCollapse: return 65
        case .nuclearSystemsPenetration: return 70
        }
    }

    var severity: CyberAttackSeverity {
        switch self {
        case .reconnaissance, .dataTheft: return .minor
        case .propagandaCampaign, .electionInterference: return .moderate
        case .infrastructureDisruption, .supplyChainsDisruption, .financialSabotage: return .major
        case .communicationsBlackout, .powerGridAttack, .militarySystemsHack: return .critical
        case .bankingSystemCollapse, .nuclearSystemsPenetration: return .catastrophic
        }
    }

    var cost: Int {
        switch self {
        case .reconnaissance: return 10_000_000
        case .dataTheft: return 25_000_000
        case .propagandaCampaign: return 50_000_000
        case .electionInterference: return 100_000_000
        case .infrastructureDisruption: return 150_000_000
        case .supplyChainsDisruption: return 200_000_000
        case .financialSabotage: return 250_000_000
        case .communicationsBlackout: return 300_000_000
        case .powerGridAttack: return 400_000_000
        case .militarySystemsHack: return 500_000_000
        case .bankingSystemCollapse: return 750_000_000
        case .nuclearSystemsPenetration: return 1_000_000_000
        }
    }

    var duration: Int {
        // Number of turns to complete
        switch self {
        case .reconnaissance: return 1
        case .dataTheft, .propagandaCampaign: return 2
        case .electionInterference, .infrastructureDisruption, .supplyChainsDisruption: return 3
        case .financialSabotage, .communicationsBlackout: return 4
        case .powerGridAttack, .militarySystemsHack: return 5
        case .bankingSystemCollapse, .nuclearSystemsPenetration: return 6
        }
    }
}

enum CyberAttackSeverity: String, Codable {
    case minor = "Minor"
    case moderate = "Moderate"
    case major = "Major"
    case critical = "Critical"
    case catastrophic = "Catastrophic"
}

/// Active cyber operation
struct CyberOperation: Identifiable, Codable {
    let id: UUID
    let attackerID: String
    let targetID: String
    let type: CyberAttackType
    let startTurn: Int
    var completionTurn: Int
    var isCompleted: Bool
    var wasDetected: Bool
    var detectedOnTurn: Int?
    var success: Bool?

    init(attackerID: String, targetID: String, type: CyberAttackType, startTurn: Int) {
        self.id = UUID()
        self.attackerID = attackerID
        self.targetID = targetID
        self.type = type
        self.startTurn = startTurn
        self.completionTurn = startTurn + type.duration
        self.isCompleted = false
        self.wasDetected = false
        self.detectedOnTurn = nil
        self.success = nil
    }
}

/// Cyber attack effects on target country
struct CyberAttackEffect: Codable {
    var economicDamage: Int // Lost GDP percentage
    var militaryDegradation: Int // Lost military strength
    var stabilityLoss: Int // Lost stability points
    var intelligenceLeak: Bool // Secrets exposed
    var relationsDamage: Int // Diplomatic fallout
    var warheadsCompromised: Int // Nuclear arsenal affected
    var civilianCasualties: Int // Deaths from infrastructure collapse
    var durationInTurns: Int // How long effects last

    static func effectsFor(attackType: CyberAttackType, targetCountry: Country) -> CyberAttackEffect {
        switch attackType {
        case .reconnaissance:
            return CyberAttackEffect(
                economicDamage: 0,
                militaryDegradation: 0,
                stabilityLoss: 0,
                intelligenceLeak: true,
                relationsDamage: 0,
                warheadsCompromised: 0,
                civilianCasualties: 0,
                durationInTurns: 1
            )

        case .dataTheft:
            return CyberAttackEffect(
                economicDamage: 2,
                militaryDegradation: 5,
                stabilityLoss: 3,
                intelligenceLeak: true,
                relationsDamage: -10,
                warheadsCompromised: 0,
                civilianCasualties: 0,
                durationInTurns: 2
            )

        case .propagandaCampaign:
            return CyberAttackEffect(
                economicDamage: 0,
                militaryDegradation: 0,
                stabilityLoss: 15,
                intelligenceLeak: false,
                relationsDamage: -20,
                warheadsCompromised: 0,
                civilianCasualties: 0,
                durationInTurns: 5
            )

        case .electionInterference:
            return CyberAttackEffect(
                economicDamage: 0,
                militaryDegradation: 0,
                stabilityLoss: 25,
                intelligenceLeak: false,
                relationsDamage: -30,
                warheadsCompromised: 0,
                civilianCasualties: 0,
                durationInTurns: 8 // Lasts until next election
            )

        case .infrastructureDisruption:
            return CyberAttackEffect(
                economicDamage: 10,
                militaryDegradation: 10,
                stabilityLoss: 15,
                intelligenceLeak: false,
                relationsDamage: -25,
                warheadsCompromised: 0,
                civilianCasualties: 1_000,
                durationInTurns: 3
            )

        case .supplyChainsDisruption:
            return CyberAttackEffect(
                economicDamage: 15,
                militaryDegradation: 20,
                stabilityLoss: 10,
                intelligenceLeak: false,
                relationsDamage: -20,
                warheadsCompromised: 0,
                civilianCasualties: 5_000,
                durationInTurns: 4
            )

        case .financialSabotage:
            return CyberAttackEffect(
                economicDamage: 20,
                militaryDegradation: 5,
                stabilityLoss: 20,
                intelligenceLeak: false,
                relationsDamage: -30,
                warheadsCompromised: 0,
                civilianCasualties: 10_000,
                durationInTurns: 6
            )

        case .communicationsBlackout:
            return CyberAttackEffect(
                economicDamage: 15,
                militaryDegradation: 25,
                stabilityLoss: 25,
                intelligenceLeak: false,
                relationsDamage: -35,
                warheadsCompromised: 0,
                civilianCasualties: 20_000,
                durationInTurns: 3
            )

        case .powerGridAttack:
            return CyberAttackEffect(
                economicDamage: 25,
                militaryDegradation: 30,
                stabilityLoss: 30,
                intelligenceLeak: false,
                relationsDamage: -40,
                warheadsCompromised: 0,
                civilianCasualties: 50_000,
                durationInTurns: 5
            )

        case .militarySystemsHack:
            return CyberAttackEffect(
                economicDamage: 5,
                militaryDegradation: 40,
                stabilityLoss: 15,
                intelligenceLeak: true,
                relationsDamage: -50,
                warheadsCompromised: 0,
                civilianCasualties: 0,
                durationInTurns: 4
            )

        case .bankingSystemCollapse:
            return CyberAttackEffect(
                economicDamage: 40,
                militaryDegradation: 15,
                stabilityLoss: 40,
                intelligenceLeak: false,
                relationsDamage: -60,
                warheadsCompromised: 0,
                civilianCasualties: 100_000,
                durationInTurns: 10
            )

        case .nuclearSystemsPenetration:
            return CyberAttackEffect(
                economicDamage: 0,
                militaryDegradation: 50,
                stabilityLoss: 20,
                intelligenceLeak: true,
                relationsDamage: -80,
                warheadsCompromised: min(10, targetCountry.nuclearWarheads / 10),
                civilianCasualties: 0,
                durationInTurns: 8
            )
        }
    }
}

/// Cyber defense measures
enum CyberDefenseLevel: Int, Codable {
    case none = 0
    case basic = 1
    case moderate = 2
    case advanced = 3
    case elite = 4
    case impenetrable = 5

    var detectionBonus: Int {
        return self.rawValue * 20
    }

    var preventionBonus: Int {
        return self.rawValue * 15
    }

    var cost: Int {
        return self.rawValue * 100_000_000
    }

    var description: String {
        switch self {
        case .none: return "No Cyber Defense"
        case .basic: return "Basic Firewalls"
        case .moderate: return "Active Monitoring"
        case .advanced: return "AI-Powered Defense"
        case .elite: return "Quantum Encryption"
        case .impenetrable: return "Air-Gapped Systems"
        }
    }
}

/// Hacker group types (for plausible deniability)
enum HackerGroup: String, Codable, CaseIterable {
    case governmentAgency = "Government Agency"
    case privateContractor = "Private Contractor"
    case hacktivists = "Hacktivist Group"
    case organizedCrime = "Organized Crime"
    case terroristGroup = "Terrorist Organization"
    case independentHacker = "Independent Hacker"

    var plausibleDeniability: Int {
        switch self {
        case .governmentAgency: return 10
        case .privateContractor: return 30
        case .hacktivists: return 70
        case .organizedCrime: return 60
        case .terroristGroup: return 50
        case .independentHacker: return 80
        }
    }
}

/// Cyber warfare incident report
struct CyberIncident: Identifiable, Codable {
    let id: UUID
    let turn: Int
    let attackType: CyberAttackType
    let suspectedSource: String? // Country ID or "Unknown"
    let targetID: String
    let effects: CyberAttackEffect
    let attributionConfidence: Int // 0-100
    let timestamp: Date

    init(turn: Int, attackType: CyberAttackType, suspectedSource: String?, targetID: String,
         effects: CyberAttackEffect, attributionConfidence: Int) {
        self.id = UUID()
        self.turn = turn
        self.attackType = attackType
        self.suspectedSource = suspectedSource
        self.targetID = targetID
        self.effects = effects
        self.attributionConfidence = attributionConfidence
        self.timestamp = Date()
    }
}
