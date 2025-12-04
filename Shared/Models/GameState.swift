//
//  GameState.swift
//  Global Thermal Nuclear War
//
//  Represents the current state of the game
//

import Foundation
import SwiftUI

/// Represents the current state of the game
class GameState: ObservableObject, Codable {
    @Published var turn: Int = 0
    @Published var defconLevel: DefconLevel = .defcon5
    @Published var countries: [Country]
    @Published var activeWars: [War]
    @Published var treaties: [Treaty]
    @Published var nuclearStrikes: [NuclearStrike]
    @Published var globalRadiation: Int = 0
    @Published var totalCasualties: Int = 0
    @Published var playerCountryID: String
    @Published var gameOver: Bool = false
    @Published var gameOverReason: String = ""
    @Published var difficultyLevel: DifficultyLevel
    @Published var turnHistory: [TurnEvent]

    // Consolidated game systems
    @Published var systems = SystemsManager()
    @Published var peaceTurns: Int = 0
    @Published var isMultiplayer: Bool
    @Published var currentPlayerIndex: Int = 0
    @Published var playerCountries: [String]
    @Published var activeCyberOperations: [CyberOperation]
    @Published var cyberIncidents: [CyberIncident]
    @Published var activeWeaponPrograms: [WeaponsDevelopmentProgram]

    enum CodingKeys: String, CodingKey {
        case turn, defconLevel, countries, activeWars, treaties, nuclearStrikes
        case globalRadiation, totalCasualties, playerCountryID, gameOver
        case gameOverReason, difficultyLevel, turnHistory, peaceTurns
        case isMultiplayer, currentPlayerIndex, playerCountries
        case activeCyberOperations, cyberIncidents, activeWeaponPrograms
    }

    init(playerCountryID: String, difficultyLevel: DifficultyLevel = .normal, scenario: Scenario? = nil, isMultiplayer: Bool = false) {
        self.playerCountryID = playerCountryID
        self.difficultyLevel = difficultyLevel
        self.countries = CountryFactory.createAllCountries()
        self.activeWars = []
        self.treaties = []
        self.nuclearStrikes = []
        self.turnHistory = []
        self.isMultiplayer = isMultiplayer
        self.playerCountries = isMultiplayer ? [playerCountryID] : []
        self.activeCyberOperations = []
        self.cyberIncidents = []
        self.activeWeaponPrograms = []

        if let s = scenario {
            systems.scenario = s
            defconLevel = s.defcon
        }

        if let index = countries.firstIndex(where: { $0.id == playerCountryID }) {
            countries[index].isPlayerControlled = true
        }
        initializeDiplomaticRelations()
    }

    // MARK: - Codable

    required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        turn = try c.decode(Int.self, forKey: .turn)
        defconLevel = try c.decode(DefconLevel.self, forKey: .defconLevel)
        countries = try c.decode([Country].self, forKey: .countries)
        activeWars = try c.decode([War].self, forKey: .activeWars)
        treaties = try c.decode([Treaty].self, forKey: .treaties)
        nuclearStrikes = try c.decode([NuclearStrike].self, forKey: .nuclearStrikes)
        globalRadiation = try c.decode(Int.self, forKey: .globalRadiation)
        totalCasualties = try c.decode(Int.self, forKey: .totalCasualties)
        playerCountryID = try c.decode(String.self, forKey: .playerCountryID)
        gameOver = try c.decode(Bool.self, forKey: .gameOver)
        gameOverReason = try c.decode(String.self, forKey: .gameOverReason)
        difficultyLevel = try c.decode(DifficultyLevel.self, forKey: .difficultyLevel)
        turnHistory = try c.decode([TurnEvent].self, forKey: .turnHistory)
        peaceTurns = try c.decodeIfPresent(Int.self, forKey: .peaceTurns) ?? 0
        isMultiplayer = try c.decodeIfPresent(Bool.self, forKey: .isMultiplayer) ?? false
        currentPlayerIndex = try c.decodeIfPresent(Int.self, forKey: .currentPlayerIndex) ?? 0
        playerCountries = try c.decodeIfPresent([String].self, forKey: .playerCountries) ?? []
        activeCyberOperations = try c.decodeIfPresent([CyberOperation].self, forKey: .activeCyberOperations) ?? []
        cyberIncidents = try c.decodeIfPresent([CyberIncident].self, forKey: .cyberIncidents) ?? []
        activeWeaponPrograms = try c.decodeIfPresent([WeaponsDevelopmentProgram].self, forKey: .activeWeaponPrograms) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(turn, forKey: .turn)
        try c.encode(defconLevel, forKey: .defconLevel)
        try c.encode(countries, forKey: .countries)
        try c.encode(activeWars, forKey: .activeWars)
        try c.encode(treaties, forKey: .treaties)
        try c.encode(nuclearStrikes, forKey: .nuclearStrikes)
        try c.encode(globalRadiation, forKey: .globalRadiation)
        try c.encode(totalCasualties, forKey: .totalCasualties)
        try c.encode(playerCountryID, forKey: .playerCountryID)
        try c.encode(gameOver, forKey: .gameOver)
        try c.encode(gameOverReason, forKey: .gameOverReason)
        try c.encode(difficultyLevel, forKey: .difficultyLevel)
        try c.encode(turnHistory, forKey: .turnHistory)
        try c.encode(peaceTurns, forKey: .peaceTurns)
        try c.encode(isMultiplayer, forKey: .isMultiplayer)
        try c.encode(currentPlayerIndex, forKey: .currentPlayerIndex)
        try c.encode(playerCountries, forKey: .playerCountries)
        try c.encode(activeCyberOperations, forKey: .activeCyberOperations)
        try c.encode(cyberIncidents, forKey: .cyberIncidents)
        try c.encode(activeWeaponPrograms, forKey: .activeWeaponPrograms)
    }

    // MARK: - Game Logic

    /// Initialize diplomatic relations based on real-world alliances
    private func initializeDiplomaticRelations() {
        for i in countries.indices {
            var relations: [String: Int] = [:]

            for otherCountry in countries where otherCountry.id != countries[i].id {
                // Base relationship on alignment
                let baseRelation: Int
                if countries[i].alignment == otherCountry.alignment {
                    baseRelation = 50 // Friendly
                } else if countries[i].alignment == .nonAligned || otherCountry.alignment == .nonAligned {
                    baseRelation = 0 // Neutral
                } else {
                    baseRelation = -30 // Unfriendly
                }

                // Add some randomness
                let randomAdjustment = Int.random(in: -10...10)
                relations[otherCountry.id] = max(-100, min(100, baseRelation + randomAdjustment))
            }

            countries[i].diplomaticRelations = relations
        }

        // Special relations
        setSpecialRelations()
    }

    /// Set special diplomatic relations (rivals, allies, etc.)
    private func setSpecialRelations() {
        // USA-Russia rivalry
        setRelation(from: "USA", to: "RUS", value: -60)
        setRelation(from: "RUS", to: "USA", value: -60)

        // USA-China tension
        setRelation(from: "USA", to: "CHN", value: -20)
        setRelation(from: "CHN", to: "USA", value: -20)

        // India-Pakistan rivalry
        setRelation(from: "IND", to: "PAK", value: -70)
        setRelation(from: "PAK", to: "IND", value: -70)

        // Israel-Iran hostility
        setRelation(from: "ISR", to: "IRN", value: -85)
        setRelation(from: "IRN", to: "ISR", value: -85)

        // North Korea isolationism
        setRelation(from: "PRK", to: "USA", value: -90)
        setRelation(from: "PRK", to: "KOR", value: -95)
        setRelation(from: "PRK", to: "JPN", value: -80)

        // NATO allies
        let natoMembers = ["USA", "GBR", "FRA", "DEU", "ITA", "ESP", "POL", "CAN", "TUR", "NLD", "BEL", "NOR"]
        for member1 in natoMembers {
            for member2 in natoMembers where member1 != member2 {
                setRelation(from: member1, to: member2, value: 80)
            }
        }

        // EU cooperation
        let euMembers = ["FRA", "DEU", "ITA", "ESP", "POL", "NLD", "BEL", "AUT", "SWE", "FIN"]
        for member1 in euMembers {
            for member2 in euMembers where member1 != member2 {
                modifyRelation(from: member1, to: member2, by: 20)
            }
        }
    }

    /// Set diplomatic relation between two countries
    func setRelation(from: String, to: String, value: Int) {
        guard let index = countries.firstIndex(where: { $0.id == from }) else { return }
        countries[index].diplomaticRelations[to] = max(-100, min(100, value))
    }

    /// Modify diplomatic relation
    func modifyRelation(from: String, to: String, by: Int) {
        guard let index = countries.firstIndex(where: { $0.id == from }),
              let currentRelation = countries[index].diplomaticRelations[to] else { return }
        countries[index].diplomaticRelations[to] = max(-100, min(100, currentRelation + by))
    }

    /// Get player's country
    func getPlayerCountry() -> Country? {
        return countries.first { $0.id == playerCountryID }
    }

    /// Get country by ID
    func getCountry(id: String) -> Country? {
        return countries.first { $0.id == id }
    }
}

/// DEFCON level (Defense Condition)
enum DefconLevel: Int, Codable, CaseIterable {
    case defcon5 = 5 // Peacetime
    case defcon4 = 4 // Increased intelligence and security
    case defcon3 = 3 // Increase in readiness
    case defcon2 = 2 // Armed forces ready to deploy in 6 hours
    case defcon1 = 1 // Maximum readiness, nuclear war imminent/in progress

    var description: String {
        switch self {
        case .defcon5: return "DEFCON 5 - Peacetime"
        case .defcon4: return "DEFCON 4 - Increased Intelligence"
        case .defcon3: return "DEFCON 3 - Increased Readiness"
        case .defcon2: return "DEFCON 2 - Armed Forces Ready"
        case .defcon1: return "DEFCON 1 - NUCLEAR WAR"
        }
    }

    var color: Color {
        switch self {
        case .defcon5: return .blue
        case .defcon4: return AppSettings.terminalGreen
        case .defcon3: return AppSettings.terminalAmber
        case .defcon2: return .orange
        case .defcon1: return AppSettings.terminalRed
        }
    }
}

/// War between countries
struct War: Identifiable, Codable {
    let id: UUID
    let aggressor: String // Country ID
    let defender: String // Country ID
    var allies: [String: [String]] // Side -> [Country IDs]
    var startTurn: Int
    var intensity: Int // 1-10 scale

    init(aggressor: String, defender: String, startTurn: Int, intensity: Int = 5) {
        self.id = UUID()
        self.aggressor = aggressor
        self.defender = defender
        self.allies = ["aggressor": [], "defender": []]
        self.startTurn = startTurn
        self.intensity = intensity
    }
}

/// Nuclear strike event
struct NuclearStrike: Identifiable, Codable {
    let id: UUID
    let attacker: String // Country ID
    let target: String // Country ID
    let warheadsUsed: Int
    let turn: Int
    let casualties: Int
    let radiationSpread: Int

    init(attacker: String, target: String, warheadsUsed: Int, turn: Int, casualties: Int, radiationSpread: Int) {
        self.id = UUID()
        self.attacker = attacker
        self.target = target
        self.warheadsUsed = warheadsUsed
        self.turn = turn
        self.casualties = casualties
        self.radiationSpread = radiationSpread
    }
}

/// Treaty between countries
struct Treaty: Identifiable, Codable {
    let id: UUID
    let type: TreatyType
    let signatories: [String] // Country IDs
    let turn: Int

    init(type: TreatyType, signatories: [String], turn: Int) {
        self.id = UUID()
        self.type = type
        self.signatories = signatories
        self.turn = turn
    }
}

/// Types of treaties
enum TreatyType: String, Codable {
    case nonAggression = "Non-Aggression Pact"
    case alliance = "Military Alliance"
    case tradeAgreement = "Trade Agreement"
    case nuclearDisarmament = "Nuclear Disarmament"
    case mutualDefense = "Mutual Defense Pact"
}

/// Difficulty levels
enum DifficultyLevel: String, Codable, CaseIterable {
    case easy = "Easy"
    case normal = "Normal"
    case hard = "Hard"
    case nightmare = "Nightmare"

    var aiAggressionMultiplier: Double {
        switch self {
        case .easy: return 0.5
        case .normal: return 1.0
        case .hard: return 1.5
        case .nightmare: return 2.0
        }
    }
}

/// Turn event for history
struct TurnEvent: Identifiable, Codable {
    let id: UUID
    let turn: Int
    let event: String
    let timestamp: Date

    init(turn: Int, event: String) {
        self.id = UUID()
        self.turn = turn
        self.event = event
        self.timestamp = Date()
    }
}
