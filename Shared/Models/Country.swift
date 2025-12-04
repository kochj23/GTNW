//
//  Country.swift
//  Global Thermal Nuclear War
//
//  Represents a nation in the game with nuclear capabilities
//

import Foundation
import SwiftUI

/// Nuclear capability status of a nation
enum NuclearStatus: String, Codable, CaseIterable {
    case declared = "Declared Nuclear Power"
    case undeclared = "Undeclared"
    case suspected = "Suspected"
    case developing = "Developing"
    case none = "Non-Nuclear"
}

/// Political alignment
enum PoliticalAlignment: String, Codable {
    case western = "Western Alliance"
    case eastern = "Eastern Bloc"
    case nonAligned = "Non-Aligned"
    case independent = "Independent"
}

/// Government type
enum GovernmentType: String, Codable {
    case democracy = "Democracy"
    case republic = "Republic"
    case monarchy = "Constitutional Monarchy"
    case communist = "Communist State"
    case authoritarian = "Authoritarian"
    case theocracy = "Theocratic"
    case military = "Military Regime"
}

/// Geographic coordinates
struct Coordinates: Codable, Hashable {
    var lat: Double
    var lon: Double
}

/// Represents a nation in the game
struct Country: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let code: String // ISO 3166-1 alpha-3
    let flag: String // Emoji flag

    // Geographic
    var capital: String
    var region: WorldRegion
    var coordinates: Coordinates

    // Military capabilities
    var nuclearStatus: NuclearStatus
    var nuclearWarheads: Int
    var icbmCount: Int
    var submarineLaunchedMissiles: Int
    var bombers: Int
    var militaryStrength: Int // 1-100 scale

    // Economic
    var gdp: Double // In trillions USD
    var population: Int // In millions
    var economicStrength: Int // 1-100 scale

    // Political
    var government: GovernmentType
    var alignment: PoliticalAlignment
    var stability: Int // 1-100 scale
    var diplomaticRelations: [String: Int] // CountryID -> relationship (-100 to 100)

    // Game state
    var isPlayerControlled: Bool
    var isDestroyed: Bool
    var damageLevel: Int // 0-100, percentage of destruction
    var radiationLevel: Int // 0-100
    var alliances: Set<String> // CountryIDs
    var atWarWith: Set<String> // CountryIDs

    // Threat assessment
    var threatLevel: ThreatLevel
    var aggressionLevel: Int // 1-100, how likely to strike first

    // SDI / Star Wars Defense System
    var hasSDI: Bool // Has Strategic Defense Initiative deployed
    var sdiCoverage: Int // 0-100, percentage coverage
    var sdiInterceptionRate: Int // 0-100, success rate per warhead

    // Intelligence & Espionage
    var intelligenceLevel: Int // 0-100, quality of intel gathering
    var spyNetworks: [String: Int] // CountryID -> spy strength (0-100)
    var counterIntelligence: Int // 0-100, ability to detect foreign spies

    // Public Opinion & Politics
    var publicApproval: Int // 0-100, approval rating
    var warSupport: Int // 0-100, public support for military action
    var electionCycle: Int // Turns until next election (0 = not applicable for non-democracies)
    var congressionalSupport: Int // 0-100, legislative support

    // Economic System
    var treasury: Int // Current funds in dollars
    var annualGDP: Int // Annual GDP in dollars
    var militaryBudget: Int // Military spending per year
    var debtLevel: Int // National debt as percentage of GDP
    var tradeAgreements: Set<String> // CountryIDs with trade deals
    var economicSanctions: Set<String> // Countries sanctioning this nation

    // Defense Systems
    var hasNORAD: Bool // Early warning system
    var bunkerCapacity: Int // 0-100, percentage of population protected
    var civilDefenseLevel: Int // 0-100, civil defense preparedness
    var hasDeadHand: Bool // Automatic retaliation system

    // Conventional Military
    var groundForces: Int // 0-100, army strength
    var navalForces: Int // 0-100, navy strength
    var airForces: Int // 0-100, air force strength
    var troops: [String: Int] // CountryID -> troop deployments
    var supplyLines: [String: Int] // CountryID -> supply strength (0-100)

    // Nuclear Arsenal Details
    var firstStrikeCapability: Bool // Can launch surprise attack
    var secondStrikeCapability: Bool // Can retaliate after being hit
    var tacticalNukes: Int // Battlefield nuclear weapons
    var strategicNukes: Int // City-destroying warheads

    // Refugees & Humanitarian
    var refugeeCount: Int // People fleeing this country
    var acceptedRefugees: Int // People this country has taken in
    var foodSecurity: Int // 0-100, ability to feed population
    var medicalCapacity: Int // 0-100, healthcare system strength

    // Cyber Warfare
    var cyberDefenseLevel: CyberDefenseLevel // Defensive capability
    var cyberOffenseLevel: Int // 0-100, hacking capability
    var activeCyberOperations: [UUID] // IDs of ongoing operations
    var cyberAttacksReceived: Int // Total attacks suffered
    var cyberAttacksLaunched: Int // Total attacks conducted
    var isUnderCyberAttack: Bool // Currently being hacked

    // Prohibited Weapons Programs (SALT I/II violations)
    var activeWeaponPrograms: [UUID] // IDs of secret weapons development
    var deployedProhibitedWeapons: [SALTProhibitedWeapon] // Completed treaty violations
    var hasABMSystem: Bool // Anti-Ballistic Missile system (beyond SDI)
    var hasMIRVTechnology: Bool // Multiple Independent Reentry Vehicles
    var hasMobileLaunchers: Bool // Mobile ICBM capability
    var hasASATWeapons: Bool // Anti-Satellite weapons
    var treatyViolations: Int // Count of detected violations

    enum CodingKeys: String, CodingKey {
        case id, name, code, flag, capital, region, coordinates
        case nuclearStatus, nuclearWarheads, icbmCount, submarineLaunchedMissiles, bombers, militaryStrength
        case gdp, population, economicStrength
        case government, alignment, stability, diplomaticRelations
        case isPlayerControlled, isDestroyed, damageLevel, radiationLevel, alliances, atWarWith
        case threatLevel, aggressionLevel
        case hasSDI, sdiCoverage, sdiInterceptionRate
        case intelligenceLevel, spyNetworks, counterIntelligence
        case publicApproval, warSupport, electionCycle, congressionalSupport
        case treasury, annualGDP, militaryBudget, debtLevel, tradeAgreements, economicSanctions
        case hasNORAD, bunkerCapacity, civilDefenseLevel, hasDeadHand
        case groundForces, navalForces, airForces, troops, supplyLines
        case firstStrikeCapability, secondStrikeCapability, tacticalNukes, strategicNukes
        case refugeeCount, acceptedRefugees, foodSecurity, medicalCapacity
        case cyberDefenseLevel, cyberOffenseLevel, activeCyberOperations
        case cyberAttacksReceived, cyberAttacksLaunched, isUnderCyberAttack
        case activeWeaponPrograms, deployedProhibitedWeapons, hasABMSystem
        case hasMIRVTechnology, hasMobileLaunchers, hasASATWeapons, treatyViolations
    }

    // Initializer
    init(id: String, name: String, code: String, flag: String, capital: String, region: WorldRegion,
         lat: Double, lon: Double, nuclearStatus: NuclearStatus, nuclearWarheads: Int, icbmCount: Int,
         submarineLaunchedMissiles: Int, bombers: Int, militaryStrength: Int, gdp: Double, population: Int,
         economicStrength: Int, government: GovernmentType, alignment: PoliticalAlignment, stability: Int,
         diplomaticRelations: [String: Int] = [:], isPlayerControlled: Bool = false, isDestroyed: Bool = false,
         damageLevel: Int = 0, radiationLevel: Int = 0, alliances: Set<String> = [], atWarWith: Set<String> = [],
         threatLevel: ThreatLevel = .moderate, aggressionLevel: Int = 50,
         hasSDI: Bool = false, sdiCoverage: Int = 0, sdiInterceptionRate: Int = 0) {
        self.id = id
        self.name = name
        self.code = code
        self.flag = flag
        self.capital = capital
        self.region = region
        self.coordinates = Coordinates(lat: lat, lon: lon)
        self.nuclearStatus = nuclearStatus
        self.nuclearWarheads = nuclearWarheads
        self.icbmCount = icbmCount
        self.submarineLaunchedMissiles = submarineLaunchedMissiles
        self.bombers = bombers
        self.militaryStrength = militaryStrength
        self.gdp = gdp
        self.population = population
        self.economicStrength = economicStrength
        self.government = government
        self.alignment = alignment
        self.stability = stability
        self.diplomaticRelations = diplomaticRelations
        self.isPlayerControlled = isPlayerControlled
        self.isDestroyed = isDestroyed
        self.damageLevel = damageLevel
        self.radiationLevel = radiationLevel
        self.alliances = alliances
        self.atWarWith = atWarWith
        self.threatLevel = threatLevel
        self.aggressionLevel = aggressionLevel
        self.hasSDI = hasSDI
        self.sdiCoverage = sdiCoverage
        self.sdiInterceptionRate = sdiInterceptionRate

        // Intelligence defaults
        self.intelligenceLevel = militaryStrength / 2
        self.spyNetworks = [:]
        self.counterIntelligence = militaryStrength / 3

        // Public opinion defaults (varies by government type)
        switch government {
        case .democracy, .republic:
            self.publicApproval = 50 + Int.random(in: -10...10)
            self.warSupport = 30 + Int.random(in: -10...10)
            self.electionCycle = 8 // 8 turns until election
            self.congressionalSupport = 50 + Int.random(in: -10...10)
        case .authoritarian, .military, .communist, .theocracy:
            self.publicApproval = 70 // Propaganda inflates numbers
            self.warSupport = 60
            self.electionCycle = 0 // No elections
            self.congressionalSupport = 80 // Rubber stamp legislature
        case .monarchy:
            self.publicApproval = 60
            self.warSupport = 40
            self.electionCycle = 0
            self.congressionalSupport = 50
        }

        // Economic defaults
        self.treasury = Int(gdp * 1_000_000_000_000 * 0.2) // 20% of GDP
        self.annualGDP = Int(gdp * 1_000_000_000_000)
        self.militaryBudget = Int(Double(annualGDP) * Double(militaryStrength) / 1000.0)
        self.debtLevel = Int.random(in: 20...100)
        self.tradeAgreements = []
        self.economicSanctions = []

        // Defense systems (major powers only)
        let isMajorPower = ["USA", "RUS", "CHN", "GBR", "FRA"].contains(id)
        self.hasNORAD = isMajorPower
        self.bunkerCapacity = isMajorPower ? 10 : 2
        self.civilDefenseLevel = militaryStrength / 2
        self.hasDeadHand = (id == "RUS") // Only Russia has Dead Hand

        // Conventional forces
        self.groundForces = militaryStrength
        self.navalForces = militaryStrength - 10
        self.airForces = militaryStrength - 5
        self.troops = [:]
        self.supplyLines = [:]

        // Nuclear arsenal details
        self.firstStrikeCapability = nuclearWarheads >= 100
        self.secondStrikeCapability = submarineLaunchedMissiles > 0 || hasDeadHand
        self.tacticalNukes = nuclearWarheads / 5
        self.strategicNukes = nuclearWarheads - tacticalNukes

        // Humanitarian defaults
        self.refugeeCount = 0
        self.acceptedRefugees = 0
        self.foodSecurity = economicStrength
        self.medicalCapacity = economicStrength

        // Cyber warfare defaults
        // Major powers have advanced cyber capabilities
        if isMajorPower {
            self.cyberDefenseLevel = .advanced
            self.cyberOffenseLevel = 80
        } else {
            self.cyberDefenseLevel = .moderate
            self.cyberOffenseLevel = intelligenceLevel / 2
        }
        self.activeCyberOperations = []
        self.cyberAttacksReceived = 0
        self.cyberAttacksLaunched = 0
        self.isUnderCyberAttack = false

        // Prohibited weapons defaults
        // Major powers may have secretly developed some capabilities
        self.activeWeaponPrograms = []
        self.deployedProhibitedWeapons = []
        self.hasABMSystem = false
        self.hasMIRVTechnology = isMajorPower // USA/USSR had MIRV by 1970s
        self.hasMobileLaunchers = (id == "RUS") // Russia has mobile SS-25/SS-27
        self.hasASATWeapons = (id == "USA" || id == "RUS" || id == "CHN") // Space powers
        self.treatyViolations = 0
    }

    /// Calculate total nuclear capability score
    var nuclearCapability: Int {
        return nuclearWarheads + (icbmCount * 10) + (submarineLaunchedMissiles * 15) + (bombers * 5)
    }

    /// Calculate overall power score
    var powerScore: Int {
        return (militaryStrength + economicStrength + min(nuclearCapability / 10, 100)) / 3
    }

    /// Color representation for UI
    var color: Color {
        switch alignment {
        case .western:
            return .blue
        case .eastern:
            return .red
        case .nonAligned:
            return .green
        case .independent:
            return .purple
        }
    }
}

/// Threat level assessment
enum ThreatLevel: String, Codable {
    case minimal = "Minimal"
    case low = "Low"
    case moderate = "Moderate"
    case high = "High"
    case critical = "Critical"
    case imminent = "Imminent"
}

/// World regions for organizing countries
enum WorldRegion: String, Codable, CaseIterable {
    case northAmerica = "North America"
    case southAmerica = "South America"
    case europe = "Europe"
    case asia = "Asia"
    case middleEast = "Middle East"
    case africa = "Africa"
    case oceania = "Oceania"
}

/// Factory for creating all countries in the game
struct CountryFactory {

    /// Create all countries with real-world data
    static func createAllCountries() -> [Country] {
        return [
            // ===== DECLARED NUCLEAR POWERS =====

            // United States
            Country(
                id: "USA", name: "United States of America", code: "USA", flag: "🇺🇸",
                capital: "Washington D.C.", region: .northAmerica, lat: 38.9072, lon: -77.0369,
                nuclearStatus: .declared, nuclearWarheads: 5428, icbmCount: 400, submarineLaunchedMissiles: 240,
                bombers: 66, militaryStrength: 100, gdp: 25.5, population: 331, economicStrength: 100,
                government: .republic, alignment: .western, stability: 85,
                threatLevel: .moderate, aggressionLevel: 40
            ),

            // Russia
            Country(
                id: "RUS", name: "Russian Federation", code: "RUS", flag: "🇷🇺",
                capital: "Moscow", region: .europe, lat: 55.7558, lon: 37.6173,
                nuclearStatus: .declared, nuclearWarheads: 5977, icbmCount: 320, submarineLaunchedMissiles: 176,
                bombers: 60, militaryStrength: 95, gdp: 1.8, population: 144, economicStrength: 45,
                government: .authoritarian, alignment: .eastern, stability: 70,
                threatLevel: .high, aggressionLevel: 65
            ),

            // China
            Country(
                id: "CHN", name: "People's Republic of China", code: "CHN", flag: "🇨🇳",
                capital: "Beijing", region: .asia, lat: 39.9042, lon: 116.4074,
                nuclearStatus: .declared, nuclearWarheads: 350, icbmCount: 90, submarineLaunchedMissiles: 48,
                bombers: 20, militaryStrength: 92, gdp: 17.9, population: 1439, economicStrength: 95,
                government: .communist, alignment: .eastern, stability: 80,
                threatLevel: .moderate, aggressionLevel: 50
            ),

            // United Kingdom
            Country(
                id: "GBR", name: "United Kingdom", code: "GBR", flag: "🇬🇧",
                capital: "London", region: .europe, lat: 51.5074, lon: -0.1278,
                nuclearStatus: .declared, nuclearWarheads: 225, icbmCount: 0, submarineLaunchedMissiles: 48,
                bombers: 0, militaryStrength: 75, gdp: 3.1, population: 67, economicStrength: 70,
                government: .monarchy, alignment: .western, stability: 88,
                threatLevel: .low, aggressionLevel: 25
            ),

            // France
            Country(
                id: "FRA", name: "France", code: "FRA", flag: "🇫🇷",
                capital: "Paris", region: .europe, lat: 48.8566, lon: 2.3522,
                nuclearStatus: .declared, nuclearWarheads: 290, icbmCount: 0, submarineLaunchedMissiles: 48,
                bombers: 40, militaryStrength: 78, gdp: 2.9, population: 67, economicStrength: 72,
                government: .republic, alignment: .western, stability: 82,
                threatLevel: .low, aggressionLevel: 28
            ),

            // India
            Country(
                id: "IND", name: "India", code: "IND", flag: "🇮🇳",
                capital: "New Delhi", region: .asia, lat: 28.6139, lon: 77.2090,
                nuclearStatus: .declared, nuclearWarheads: 164, icbmCount: 12, submarineLaunchedMissiles: 16,
                bombers: 8, militaryStrength: 82, gdp: 3.4, population: 1393, economicStrength: 68,
                government: .republic, alignment: .nonAligned, stability: 75,
                threatLevel: .moderate, aggressionLevel: 35
            ),

            // Pakistan
            Country(
                id: "PAK", name: "Pakistan", code: "PAK", flag: "🇵🇰",
                capital: "Islamabad", region: .asia, lat: 33.6844, lon: 73.0479,
                nuclearStatus: .declared, nuclearWarheads: 170, icbmCount: 0, submarineLaunchedMissiles: 0,
                bombers: 6, militaryStrength: 68, gdp: 0.35, population: 225, economicStrength: 32,
                government: .republic, alignment: .nonAligned, stability: 55,
                threatLevel: .high, aggressionLevel: 60
            ),

            // North Korea
            Country(
                id: "PRK", name: "North Korea", code: "PRK", flag: "🇰🇵",
                capital: "Pyongyang", region: .asia, lat: 39.0392, lon: 125.7625,
                nuclearStatus: .declared, nuclearWarheads: 30, icbmCount: 10, submarineLaunchedMissiles: 0,
                bombers: 0, militaryStrength: 55, gdp: 0.028, population: 26, economicStrength: 15,
                government: .authoritarian, alignment: .eastern, stability: 40,
                threatLevel: .critical, aggressionLevel: 85
            ),

            // Israel
            Country(
                id: "ISR", name: "Israel", code: "ISR", flag: "🇮🇱",
                capital: "Jerusalem", region: .middleEast, lat: 31.7683, lon: 35.2137,
                nuclearStatus: .undeclared, nuclearWarheads: 90, icbmCount: 0, submarineLaunchedMissiles: 16,
                bombers: 0, militaryStrength: 85, gdp: 0.52, population: 9, economicStrength: 65,
                government: .democracy, alignment: .western, stability: 70,
                threatLevel: .moderate, aggressionLevel: 55
            ),

            // ===== COUNTRIES WITH SUSPECTED/DEVELOPING PROGRAMS =====

            // Iran
            Country(
                id: "IRN", name: "Iran", code: "IRN", flag: "🇮🇷",
                capital: "Tehran", region: .middleEast, lat: 35.6892, lon: 51.3890,
                nuclearStatus: .developing, nuclearWarheads: 0, icbmCount: 0, submarineLaunchedMissiles: 0,
                bombers: 0, militaryStrength: 72, gdp: 0.37, population: 84, economicStrength: 38,
                government: .theocracy, alignment: .independent, stability: 60,
                threatLevel: .high, aggressionLevel: 70
            ),

            // Saudi Arabia
            Country(
                id: "SAU", name: "Saudi Arabia", code: "SAU", flag: "🇸🇦",
                capital: "Riyadh", region: .middleEast, lat: 24.7136, lon: 46.6753,
                nuclearStatus: .suspected, nuclearWarheads: 0, icbmCount: 0, submarineLaunchedMissiles: 0,
                bombers: 0, militaryStrength: 65, gdp: 0.83, population: 35, economicStrength: 58,
                government: .monarchy, alignment: .western, stability: 68,
                threatLevel: .moderate, aggressionLevel: 45
            ),

            // ===== MAJOR POWERS (NON-NUCLEAR) =====

            // Germany
            Country(
                id: "DEU", name: "Germany", code: "DEU", flag: "🇩🇪",
                capital: "Berlin", region: .europe, lat: 52.5200, lon: 13.4050,
                nuclearStatus: .none, nuclearWarheads: 0, icbmCount: 0, submarineLaunchedMissiles: 0,
                bombers: 0, militaryStrength: 70, gdp: 4.2, population: 83, economicStrength: 88,
                government: .republic, alignment: .western, stability: 92,
                threatLevel: .minimal, aggressionLevel: 15
            ),

            // Japan
            Country(
                id: "JPN", name: "Japan", code: "JPN", flag: "🇯🇵",
                capital: "Tokyo", region: .asia, lat: 35.6762, lon: 139.6503,
                nuclearStatus: .none, nuclearWarheads: 0, icbmCount: 0, submarineLaunchedMissiles: 0,
                bombers: 0, militaryStrength: 68, gdp: 4.9, population: 125, economicStrength: 85,
                government: .monarchy, alignment: .western, stability: 95,
                threatLevel: .minimal, aggressionLevel: 10
            ),

            // South Korea
            Country(
                id: "KOR", name: "South Korea", code: "KOR", flag: "🇰🇷",
                capital: "Seoul", region: .asia, lat: 37.5665, lon: 126.9780,
                nuclearStatus: .none, nuclearWarheads: 0, icbmCount: 0, submarineLaunchedMissiles: 0,
                bombers: 0, militaryStrength: 72, gdp: 1.8, population: 52, economicStrength: 75,
                government: .republic, alignment: .western, stability: 85,
                threatLevel: .low, aggressionLevel: 20
            ),

            // Brazil
            Country(
                id: "BRA", name: "Brazil", code: "BRA", flag: "🇧🇷",
                capital: "Brasília", region: .southAmerica, lat: -15.8267, lon: -47.9218,
                nuclearStatus: .none, nuclearWarheads: 0, icbmCount: 0, submarineLaunchedMissiles: 0,
                bombers: 0, militaryStrength: 58, gdp: 1.9, population: 213, economicStrength: 55,
                government: .republic, alignment: .nonAligned, stability: 70,
                threatLevel: .low, aggressionLevel: 25
            ),

            // Canada
            Country(
                id: "CAN", name: "Canada", code: "CAN", flag: "🇨🇦",
                capital: "Ottawa", region: .northAmerica, lat: 45.4215, lon: -75.6972,
                nuclearStatus: .none, nuclearWarheads: 0, icbmCount: 0, submarineLaunchedMissiles: 0,
                bombers: 0, militaryStrength: 55, gdp: 2.1, population: 38, economicStrength: 78,
                government: .monarchy, alignment: .western, stability: 95,
                threatLevel: .minimal, aggressionLevel: 5
            ),

            // Australia
            Country(
                id: "AUS", name: "Australia", code: "AUS", flag: "🇦🇺",
                capital: "Canberra", region: .oceania, lat: -35.2809, lon: 149.1300,
                nuclearStatus: .none, nuclearWarheads: 0, icbmCount: 0, submarineLaunchedMissiles: 0,
                bombers: 0, militaryStrength: 52, gdp: 1.7, population: 26, economicStrength: 72,
                government: .monarchy, alignment: .western, stability: 93,
                threatLevel: .minimal, aggressionLevel: 8
            ),

            // Italy
            Country(
                id: "ITA", name: "Italy", code: "ITA", flag: "🇮🇹",
                capital: "Rome", region: .europe, lat: 41.9028, lon: 12.4964,
                nuclearStatus: .none, nuclearWarheads: 0, icbmCount: 0, submarineLaunchedMissiles: 0,
                bombers: 0, militaryStrength: 60, gdp: 2.1, population: 60, economicStrength: 68,
                government: .republic, alignment: .western, stability: 75,
                threatLevel: .minimal, aggressionLevel: 12
            ),

            // Spain
            Country(
                id: "ESP", name: "Spain", code: "ESP", flag: "🇪🇸",
                capital: "Madrid", region: .europe, lat: 40.4168, lon: -3.7038,
                nuclearStatus: .none, nuclearWarheads: 0, icbmCount: 0, submarineLaunchedMissiles: 0,
                bombers: 0, militaryStrength: 58, gdp: 1.4, population: 47, economicStrength: 65,
                government: .monarchy, alignment: .western, stability: 82,
                threatLevel: .minimal, aggressionLevel: 10
            ),

            // Turkey
            Country(
                id: "TUR", name: "Turkey", code: "TUR", flag: "🇹🇷",
                capital: "Ankara", region: .middleEast, lat: 39.9334, lon: 32.8597,
                nuclearStatus: .none, nuclearWarheads: 0, icbmCount: 0, submarineLaunchedMissiles: 0,
                bombers: 0, militaryStrength: 75, gdp: 0.82, population: 85, economicStrength: 52,
                government: .republic, alignment: .western, stability: 60,
                threatLevel: .moderate, aggressionLevel: 48
            ),

            // Egypt
            Country(
                id: "EGY", name: "Egypt", code: "EGY", flag: "🇪🇬",
                capital: "Cairo", region: .africa, lat: 30.0444, lon: 31.2357,
                nuclearStatus: .none, nuclearWarheads: 0, icbmCount: 0, submarineLaunchedMissiles: 0,
                bombers: 0, militaryStrength: 62, gdp: 0.43, population: 104, economicStrength: 42,
                government: .military, alignment: .nonAligned, stability: 65,
                threatLevel: .low, aggressionLevel: 30
            ),

            // South Africa
            Country(
                id: "ZAF", name: "South Africa", code: "ZAF", flag: "🇿🇦",
                capital: "Pretoria", region: .africa, lat: -25.7479, lon: 28.2293,
                nuclearStatus: .none, nuclearWarheads: 0, icbmCount: 0, submarineLaunchedMissiles: 0,
                bombers: 0, militaryStrength: 48, gdp: 0.42, population: 60, economicStrength: 45,
                government: .republic, alignment: .nonAligned, stability: 72,
                threatLevel: .minimal, aggressionLevel: 15
            ),

            // Ukraine
            Country(
                id: "UKR", name: "Ukraine", code: "UKR", flag: "🇺🇦",
                capital: "Kyiv", region: .europe, lat: 50.4501, lon: 30.5234,
                nuclearStatus: .none, nuclearWarheads: 0, icbmCount: 0, submarineLaunchedMissiles: 0,
                bombers: 0, militaryStrength: 55, gdp: 0.16, population: 44, economicStrength: 28,
                government: .republic, alignment: .western, stability: 50,
                threatLevel: .high, aggressionLevel: 35
            ),

            // Poland
            Country(
                id: "POL", name: "Poland", code: "POL", flag: "🇵🇱",
                capital: "Warsaw", region: .europe, lat: 52.2297, lon: 21.0122,
                nuclearStatus: .none, nuclearWarheads: 0, icbmCount: 0, submarineLaunchedMissiles: 0,
                bombers: 0, militaryStrength: 62, gdp: 0.69, population: 38, economicStrength: 58,
                government: .republic, alignment: .western, stability: 80,
                threatLevel: .low, aggressionLevel: 22
            ),

            // Netherlands
            Country(
                id: "NLD", name: "Netherlands", code: "NLD", flag: "🇳🇱",
                capital: "Amsterdam", region: .europe, lat: 52.3676, lon: 4.9041,
                nuclearStatus: .none, nuclearWarheads: 0, icbmCount: 0, submarineLaunchedMissiles: 0,
                bombers: 0, militaryStrength: 52, gdp: 1.0, population: 17, economicStrength: 75,
                government: .monarchy, alignment: .western, stability: 92,
                threatLevel: .minimal, aggressionLevel: 8
            ),

            // Belgium
            Country(
                id: "BEL", name: "Belgium", code: "BEL", flag: "🇧🇪",
                capital: "Brussels", region: .europe, lat: 50.8503, lon: 4.3517,
                nuclearStatus: .none, nuclearWarheads: 0, icbmCount: 0, submarineLaunchedMissiles: 0,
                bombers: 0, militaryStrength: 48, gdp: 0.59, population: 12, economicStrength: 72,
                government: .monarchy, alignment: .western, stability: 88,
                threatLevel: .minimal, aggressionLevel: 5
            ),

            // Sweden
            Country(
                id: "SWE", name: "Sweden", code: "SWE", flag: "🇸🇪",
                capital: "Stockholm", region: .europe, lat: 59.3293, lon: 18.0686,
                nuclearStatus: .none, nuclearWarheads: 0, icbmCount: 0, submarineLaunchedMissiles: 0,
                bombers: 0, militaryStrength: 50, gdp: 0.63, population: 10, economicStrength: 70,
                government: .monarchy, alignment: .western, stability: 95,
                threatLevel: .minimal, aggressionLevel: 3
            ),

            // Norway
            Country(
                id: "NOR", name: "Norway", code: "NOR", flag: "🇳🇴",
                capital: "Oslo", region: .europe, lat: 59.9139, lon: 10.7522,
                nuclearStatus: .none, nuclearWarheads: 0, icbmCount: 0, submarineLaunchedMissiles: 0,
                bombers: 0, militaryStrength: 45, gdp: 0.48, population: 5, economicStrength: 72,
                government: .monarchy, alignment: .western, stability: 96,
                threatLevel: .minimal, aggressionLevel: 2
            ),

            // Finland
            Country(
                id: "FIN", name: "Finland", code: "FIN", flag: "🇫🇮",
                capital: "Helsinki", region: .europe, lat: 60.1695, lon: 24.9354,
                nuclearStatus: .none, nuclearWarheads: 0, icbmCount: 0, submarineLaunchedMissiles: 0,
                bombers: 0, militaryStrength: 48, gdp: 0.30, population: 6, economicStrength: 68,
                government: .republic, alignment: .western, stability: 94,
                threatLevel: .minimal, aggressionLevel: 5
            ),

            // Switzerland
            Country(
                id: "CHE", name: "Switzerland", code: "CHE", flag: "🇨🇭",
                capital: "Bern", region: .europe, lat: 46.9480, lon: 7.4474,
                nuclearStatus: .none, nuclearWarheads: 0, icbmCount: 0, submarineLaunchedMissiles: 0,
                bombers: 0, militaryStrength: 42, gdp: 0.84, population: 9, economicStrength: 85,
                government: .republic, alignment: .nonAligned, stability: 98,
                threatLevel: .minimal, aggressionLevel: 1
            ),

            // Austria
            Country(
                id: "AUT", name: "Austria", code: "AUT", flag: "🇦🇹",
                capital: "Vienna", region: .europe, lat: 48.2082, lon: 16.3738,
                nuclearStatus: .none, nuclearWarheads: 0, icbmCount: 0, submarineLaunchedMissiles: 0,
                bombers: 0, militaryStrength: 40, gdp: 0.48, population: 9, economicStrength: 70,
                government: .republic, alignment: .western, stability: 92,
                threatLevel: .minimal, aggressionLevel: 3
            ),

            // Mexico
            Country(
                id: "MEX", name: "Mexico", code: "MEX", flag: "🇲🇽",
                capital: "Mexico City", region: .northAmerica, lat: 19.4326, lon: -99.1332,
                nuclearStatus: .none, nuclearWarheads: 0, icbmCount: 0, submarineLaunchedMissiles: 0,
                bombers: 0, militaryStrength: 52, gdp: 1.3, population: 129, economicStrength: 55,
                government: .republic, alignment: .nonAligned, stability: 65,
                threatLevel: .low, aggressionLevel: 18
            ),

            // Argentina
            Country(
                id: "ARG", name: "Argentina", code: "ARG", flag: "🇦🇷",
                capital: "Buenos Aires", region: .southAmerica, lat: -34.6037, lon: -58.3816,
                nuclearStatus: .none, nuclearWarheads: 0, icbmCount: 0, submarineLaunchedMissiles: 0,
                bombers: 0, militaryStrength: 48, gdp: 0.49, population: 45, economicStrength: 45,
                government: .republic, alignment: .nonAligned, stability: 68,
                threatLevel: .low, aggressionLevel: 20
            ),

            // Indonesia
            Country(
                id: "IDN", name: "Indonesia", code: "IDN", flag: "🇮🇩",
                capital: "Jakarta", region: .asia, lat: -6.2088, lon: 106.8456,
                nuclearStatus: .none, nuclearWarheads: 0, icbmCount: 0, submarineLaunchedMissiles: 0,
                bombers: 0, militaryStrength: 58, gdp: 1.3, population: 275, economicStrength: 52,
                government: .republic, alignment: .nonAligned, stability: 70,
                threatLevel: .low, aggressionLevel: 22
            ),

            // Thailand
            Country(
                id: "THA", name: "Thailand", code: "THA", flag: "🇹🇭",
                capital: "Bangkok", region: .asia, lat: 13.7563, lon: 100.5018,
                nuclearStatus: .none, nuclearWarheads: 0, icbmCount: 0, submarineLaunchedMissiles: 0,
                bombers: 0, militaryStrength: 52, gdp: 0.51, population: 70, economicStrength: 48,
                government: .monarchy, alignment: .nonAligned, stability: 72,
                threatLevel: .low, aggressionLevel: 15
            ),

            // Vietnam
            Country(
                id: "VNM", name: "Vietnam", code: "VNM", flag: "🇻🇳",
                capital: "Hanoi", region: .asia, lat: 21.0285, lon: 105.8542,
                nuclearStatus: .none, nuclearWarheads: 0, icbmCount: 0, submarineLaunchedMissiles: 0,
                bombers: 0, militaryStrength: 60, gdp: 0.41, population: 98, economicStrength: 45,
                government: .communist, alignment: .nonAligned, stability: 75,
                threatLevel: .low, aggressionLevel: 28
            ),

            // Singapore
            Country(
                id: "SGP", name: "Singapore", code: "SGP", flag: "🇸🇬",
                capital: "Singapore", region: .asia, lat: 1.3521, lon: 103.8198,
                nuclearStatus: .none, nuclearWarheads: 0, icbmCount: 0, submarineLaunchedMissiles: 0,
                bombers: 0, militaryStrength: 50, gdp: 0.40, population: 6, economicStrength: 82,
                government: .republic, alignment: .western, stability: 90,
                threatLevel: .minimal, aggressionLevel: 10
            ),

            // New Zealand
            Country(
                id: "NZL", name: "New Zealand", code: "NZL", flag: "🇳🇿",
                capital: "Wellington", region: .oceania, lat: -41.2865, lon: 174.7762,
                nuclearStatus: .none, nuclearWarheads: 0, icbmCount: 0, submarineLaunchedMissiles: 0,
                bombers: 0, militaryStrength: 35, gdp: 0.25, population: 5, economicStrength: 62,
                government: .monarchy, alignment: .western, stability: 96,
                threatLevel: .minimal, aggressionLevel: 2
            ),
        ]
    }
}
