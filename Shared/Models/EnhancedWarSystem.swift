//
//  EnhancedWarSystem.swift
//  Global Thermal Nuclear War
//
//  Comprehensive war statistics and management system
//  Created by Jordan Koch on 2025-12-11.
//

import Foundation

// MARK: - Military Units

struct MilitaryDeployment: Codable, Hashable {
    var infantry: Int           // Number of soldiers
    var tanks: Int              // Armored vehicles
    var artillery: Int          // Artillery pieces
    var aircraft: Int           // Combat aircraft
    var ships: Int              // Naval vessels
    var nuclearWarheads: Int    // Nuclear weapons deployed

    static var zero: MilitaryDeployment {
        MilitaryDeployment(infantry: 0, tanks: 0, artillery: 0, aircraft: 0, ships: 0, nuclearWarheads: 0)
    }

    var totalUnits: Int {
        infantry + tanks + artillery + aircraft + ships
    }

    var isEmpty: Bool {
        totalUnits == 0 && nuclearWarheads == 0
    }
}

// MARK: - Combat Casualties

struct CombatCasualties: Codable, Hashable {
    var dead: Int               // Killed in action
    var wounded: Int            // Wounded but alive
    var missing: Int            // Missing in action
    var captured: Int           // Prisoners of war

    var total: Int {
        dead + wounded + missing + captured
    }

    static var zero: CombatCasualties {
        CombatCasualties(dead: 0, wounded: 0, missing: 0, captured: 0)
    }
}

// MARK: - Equipment Losses

struct EquipmentLosses: Codable, Hashable {
    var tanksDestroyed: Int
    var artilleryDestroyed: Int
    var aircraftDestroyed: Int
    var shipsDestroyed: Int

    var totalLosses: Int {
        tanksDestroyed + artilleryDestroyed + aircraftDestroyed + shipsDestroyed
    }

    static var zero: EquipmentLosses {
        EquipmentLosses(tanksDestroyed: 0, artilleryDestroyed: 0, aircraftDestroyed: 0, shipsDestroyed: 0)
    }
}

// MARK: - Combat Statistics (Per Turn)

struct CombatStatistics: Identifiable, Codable {
    let id: UUID
    let turn: Int
    let warID: UUID

    // Casualties by side
    var aggressorCasualties: CombatCasualties
    var defenderCasualties: CombatCasualties

    // Equipment losses by side
    var aggressorEquipmentLosses: EquipmentLosses
    var defenderEquipmentLosses: EquipmentLosses

    // Territory control
    var territoryGained: Int        // Square km gained by aggressor (negative = defender gained)
    var citiesCaptured: Int         // Number of cities captured this turn

    // Nuclear strikes this turn
    var nuclearStrikesThisTurn: Int
    var nuclearCasualties: Int

    // Combat intensity
    var battlesThisTurn: Int        // Number of engagements
    var intensity: Int              // 1-10 scale

    init(turn: Int, warID: UUID) {
        self.id = UUID()
        self.turn = turn
        self.warID = warID
        self.aggressorCasualties = .zero
        self.defenderCasualties = .zero
        self.aggressorEquipmentLosses = .zero
        self.defenderEquipmentLosses = .zero
        self.territoryGained = 0
        self.citiesCaptured = 0
        self.nuclearStrikesThisTurn = 0
        self.nuclearCasualties = 0
        self.battlesThisTurn = 0
        self.intensity = 5
    }

    var totalCasualties: Int {
        aggressorCasualties.total + defenderCasualties.total + nuclearCasualties
    }

    var totalEquipmentLosses: Int {
        aggressorEquipmentLosses.totalLosses + defenderEquipmentLosses.totalLosses
    }
}

// MARK: - War Side Statistics

struct WarSideStatistics: Codable, Hashable {
    var countryID: String
    var deployment: MilitaryDeployment
    var totalCasualties: CombatCasualties
    var totalEquipmentLosses: EquipmentLosses
    var warCrimes: Int              // Number of documented war crimes
    var morale: Int                 // 0-100 (affects combat effectiveness)

    init(countryID: String, deployment: MilitaryDeployment = .zero) {
        self.countryID = countryID
        self.deployment = deployment
        self.totalCasualties = .zero
        self.totalEquipmentLosses = .zero
        self.warCrimes = 0
        self.morale = 75  // Start at 75% morale
    }
}

// MARK: - Enhanced War

struct EnhancedWar: Identifiable, Codable {
    let id: UUID
    let aggressor: String           // Country ID
    let defender: String            // Country ID
    var allies: [String: [String]]  // Side -> [Country IDs]
    let startTurn: Int
    var currentTurn: Int

    // Military deployments
    var aggressorStats: WarSideStatistics
    var defenderStats: WarSideStatistics
    var alliesStats: [String: WarSideStatistics]  // Ally country ID -> stats

    // Per-turn combat statistics
    var combatHistory: [CombatStatistics]

    // War status
    var intensity: Int              // 1-10 scale (current)
    var warType: WarType
    var territoryControlled: Int    // Positive = aggressor controls, negative = defender controls
    var citiesHeld: [String: Int]   // CountryID -> number of cities held

    // Economic impact
    var economicCostAggressor: Double  // In billions USD
    var economicCostDefender: Double   // In billions USD

    // International response
    var warCrimesReported: Int
    var sanctionsImposed: Int
    var humanitarianAid: Double    // In billions USD

    // Victory conditions
    var victoryPoints: [String: Int]  // CountryID -> victory points

    init(aggressor: String, defender: String, startTurn: Int, intensity: Int = 5) {
        self.id = UUID()
        self.aggressor = aggressor
        self.defender = defender
        self.allies = ["aggressor": [], "defender": []]
        self.startTurn = startTurn
        self.currentTurn = startTurn

        self.aggressorStats = WarSideStatistics(countryID: aggressor)
        self.defenderStats = WarSideStatistics(countryID: defender)
        self.alliesStats = [:]

        self.combatHistory = []
        self.intensity = intensity
        self.warType = .conventional
        self.territoryControlled = 0
        self.citiesHeld = [:]

        self.economicCostAggressor = 0.0
        self.economicCostDefender = 0.0

        self.warCrimesReported = 0
        self.sanctionsImposed = 0
        self.humanitarianAid = 0.0

        self.victoryPoints = [:]
    }

    // Convert to legacy War format for compatibility
    func toLegacyWar() -> War {
        War(aggressor: aggressor, defender: defender, startTurn: startTurn, intensity: intensity)
    }

    // MARK: - Statistics Aggregation

    var totalCasualties: CombatCasualties {
        var total = aggressorStats.totalCasualties
        total.dead += defenderStats.totalCasualties.dead
        total.wounded += defenderStats.totalCasualties.wounded
        total.missing += defenderStats.totalCasualties.missing
        total.captured += defenderStats.totalCasualties.captured

        // Add allies
        for stats in alliesStats.values {
            total.dead += stats.totalCasualties.dead
            total.wounded += stats.totalCasualties.wounded
            total.missing += stats.totalCasualties.missing
            total.captured += stats.totalCasualties.captured
        }

        return total
    }

    var totalEquipmentLosses: EquipmentLosses {
        var total = aggressorStats.totalEquipmentLosses
        total.tanksDestroyed += defenderStats.totalEquipmentLosses.tanksDestroyed
        total.artilleryDestroyed += defenderStats.totalEquipmentLosses.artilleryDestroyed
        total.aircraftDestroyed += defenderStats.totalEquipmentLosses.aircraftDestroyed
        total.shipsDestroyed += defenderStats.totalEquipmentLosses.shipsDestroyed

        // Add allies
        for stats in alliesStats.values {
            total.tanksDestroyed += stats.totalEquipmentLosses.tanksDestroyed
            total.artilleryDestroyed += stats.totalEquipmentLosses.artilleryDestroyed
            total.aircraftDestroyed += stats.totalEquipmentLosses.aircraftDestroyed
            total.shipsDestroyed += stats.totalEquipmentLosses.shipsDestroyed
        }

        return total
    }

    var durationInTurns: Int {
        currentTurn - startTurn
    }

    var latestCombatStats: CombatStatistics? {
        combatHistory.last
    }

    // MARK: - War Phase

    var warPhase: WarPhase {
        let duration = durationInTurns
        let totalDeaths = totalCasualties.dead

        if totalDeaths > 1_000_000 {
            return .apocalyptic
        } else if totalDeaths > 500_000 || duration > 50 {
            return .totalWar
        } else if totalDeaths > 100_000 || duration > 20 {
            return .escalated
        } else if duration > 10 {
            return .prolonged
        } else if duration > 3 {
            return .active
        } else {
            return .initial
        }
    }
}

// MARK: - War Type

enum WarType: String, Codable, CaseIterable {
    case conventional = "Conventional War"
    case proxy = "Proxy War"
    case nuclear = "Nuclear War"
    case cyber = "Cyber Warfare"
    case hybrid = "Hybrid Warfare"
    case civilWar = "Civil War"
    case insurgency = "Insurgency"
    case terrorism = "Counter-Terrorism"
}

// MARK: - War Phase

enum WarPhase: String, Codable {
    case initial = "Initial Conflict"
    case active = "Active Combat"
    case prolonged = "Prolonged War"
    case escalated = "Escalated Conflict"
    case totalWar = "Total War"
    case apocalyptic = "Apocalyptic War"

    var color: String {
        switch self {
        case .initial: return "yellow"
        case .active: return "orange"
        case .prolonged: return "orange"
        case .escalated: return "red"
        case .totalWar: return "darkred"
        case .apocalyptic: return "black"
        }
    }
}

// MARK: - Military Action

struct MilitaryAction: Identifiable {
    let id = UUID()
    let type: ActionType
    let units: MilitaryDeployment
    let target: String  // Country ID

    enum ActionType: String, CaseIterable {
        case deploy = "Deploy Forces"
        case reinforce = "Reinforce"
        case withdraw = "Withdraw"
        case nuclearStrike = "Nuclear Strike"
        case airstrike = "Airstrike"
        case navalBombardment = "Naval Bombardment"
        case groundAssault = "Ground Assault"
        case siegeOperation = "Siege Operation"
    }
}
