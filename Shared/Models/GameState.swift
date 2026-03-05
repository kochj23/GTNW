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
    @Published var advisors: [Advisor] = []
    @Published var aiActionSummary: [String] = []
    @Published var hasUsedActionThisTurn: Bool = false

    // MARK: - Stats tracking (for achievements, analytics)
    @Published var presidentsPlayed: [String] = []
    @Published var warsStarted: Int = 0
    @Published var warsWon: Int = 0
    @Published var nukesLaunched: Int = 0
    @Published var totalWarheadsLaunched: Int = 0
    @Published var conflictsMediated: Int = 0
    @Published var successfulCovertOps: Int = 0
    @Published var spyNetworksEstablished: Int = 0
    @Published var successfulCoups: Int = 0
    @Published var sanctionsImposed: Int = 0
    @Published var alliancesBroken: Int = 0
    @Published var militaryActionsUsed: Int = 0
    @Published var crisisesCompleted: Set<String> = []
    @Published var reachedDEFCON1: Bool = false
    @Published var nuclearWinterSurvived: Bool = false
    @Published var civilWarWon: Bool = false
    @Published var victoryType: VictoryType?

    // MARK: - Convenience computed properties
    var gameEnded: Bool { gameOver }
    var turnNumber: Int { turn }
    var recentEvents: [String] { turnHistory.suffix(20).map { $0.event } }

    /// The in-game year, anchored to the era start year stored at init time.
    @Published var eraStartYear: Int = 2025
    var currentYear: Int { eraStartYear + turn }

    // MARK: - Era-aware delivery system labels

    /// Label for the icbmCount stat — changes based on what actually existed in the era.
    var deliverySystemLabel: String {
        switch eraStartYear {
        case ..<1957: return "Atom Bombs"       // Gravity bombs on B-29/B-47, no ICBMs yet
        case 1957..<1960: return "Missiles"     // Early Atlas/R-7 ballistic missiles
        case 1960..<1970: return "ICBMs"        // Atlas, Titan, Minuteman operational
        default:          return "ICBMs"
        }
    }

    /// Label for submarineLaunchedMissiles — pre-Polaris eras had no SLBMs.
    var slbmLabel: String {
        switch eraStartYear {
        case ..<1960: return "Sub-Launched Missiles" // Polaris first patrol Nov 1960
        case 1960..<1972: return "Polaris Missiles"  // UGM-27 Polaris era
        case 1972..<1990: return "Poseidon Missiles" // UGM-73 Poseidon era
        default:          return "SLBMs"
        }
    }

    /// Generic delivery system name for use in prose / crisis event text.
    var deliverySystemProse: String {
        switch eraStartYear {
        case ..<1957: return "nuclear-armed bombers"
        case 1957..<1960: return "ballistic missiles"
        default: return "ICBMs"
        }
    }

    // MARK: - Era-gated technology

    /// Returns true if cyber warfare capabilities existed in this era.
    var cyberWarfareAvailable: Bool { eraStartYear >= 1990 }

    /// Returns true if reconnaissance satellites were available.
    var satelliteSurveillanceAvailable: Bool { eraStartYear >= 1957 }

    /// Returns true if the SDI / Star Wars missile defense program existed.
    var sdiAvailable: Bool { eraStartYear >= 1983 }

    /// Returns true if precision-guided munitions (smart bombs) were available.
    var precisionMunitionsAvailable: Bool { eraStartYear >= 1970 }

    /// Returns true if drone strikes were a viable option.
    var droneStrikesAvailable: Bool { eraStartYear >= 2001 }

    /// Returns true if SLBM / Polaris submarines were operational.
    var submarineLaunchAvailable: Bool { eraStartYear >= 1960 }

    /// Human-readable label for the era's primary intelligence-gathering method.
    var intelMethodLabel: String {
        switch eraStartYear {
        case ..<1957: return "Human Intelligence (HUMINT)"
        case 1957..<1970: return "Satellite & HUMINT"
        case 1970..<1990: return "SIGINT & Satellite"
        default: return "NSA/SIGINT/Cyber Intelligence"
        }
    }

    // MARK: - Era-appropriate news outlets

    /// News outlets that existed and were relevant in this era.
    var availableNewsOutlets: [String] {
        var outlets: [String] = []
        outlets.append("Associated Press")   // Founded 1846
        outlets.append("Reuters")            // Founded 1851
        if eraStartYear >= 1927 { outlets.append("BBC") }
        if eraStartYear >= 1943 { outlets.append("TASS (Soviet)") }   // Cold War era
        if eraStartYear >= 1950 { outlets.append("Voice of America") }
        if eraStartYear >= 1960 { outlets.append("Pravda") }          // USSR state paper
        if eraStartYear >= 1980 { outlets.append("CNN") }             // Founded 1980
        if eraStartYear >= 1991 { outlets.append("C-SPAN") }
        if eraStartYear >= 1996 { outlets.append("FOX News") }        // Founded 1996
        if eraStartYear >= 1996 { outlets.append("Al Jazeera") }      // Founded 1996
        if eraStartYear >= 2005 { outlets.append("RT (Russia Today)") } // Founded 2005
        if eraStartYear >= 2006 { outlets.append("Twitter/X News") }
        return outlets
    }

    // MARK: - Era flavor text

    /// Key doctrine or slogan of the era, shown in briefing header.
    var eraDoctrine: String {
        switch eraStartYear {
        case 1945..<1953: return "Containment Policy — Stop Soviet Expansion"
        case 1953..<1961: return "Massive Retaliation — Any Attack Answered with Nuclear Force"
        case 1961..<1963: return "Flexible Response — Proportional Military Options"
        case 1963..<1969: return "Domino Theory — If One Falls, All Fall"
        case 1969..<1977: return "Détente — Managed Competition with the Soviet Union"
        case 1977..<1981: return "Human Rights & Containment — Carter Doctrine"
        case 1981..<1989: return "Peace Through Strength — The Evil Empire Must Fall"
        case 1989..<1993: return "New World Order — Post-Cold War Architecture"
        case 1993..<2001: return "Engagement & Enlargement — Democracy & Markets"
        case 2001..<2009: return "Global War on Terror — You're Either With Us or Against Us"
        case 2009..<2017: return "Smart Power — Drone Strikes, Sanctions, Diplomacy"
        case 2017..<2021: return "America First — Transactional Foreign Policy"
        case 2021..<2025: return "Democracy Alliance — Rules-Based International Order"
        default:           return "America First (II) — Maximum Pressure"
        }
    }

    /// The dominant adversary framing for this era.
    var primaryThreatLabel: String {
        switch eraStartYear {
        case ..<1991: return "Soviet Union"
        case 1991..<2001: return "Regional Instability"
        case 2001..<2021: return "International Terrorism"
        default: return "China & Russia"
        }
    }

    enum CodingKeys: String, CodingKey {
        case turn, defconLevel, countries, activeWars, treaties, nuclearStrikes
        case globalRadiation, totalCasualties, playerCountryID, gameOver
        case gameOverReason, difficultyLevel, turnHistory, peaceTurns
        case isMultiplayer, currentPlayerIndex, playerCountries
        case activeCyberOperations, cyberIncidents, activeWeaponPrograms, advisors
    }

    init(playerCountryID: String, difficultyLevel: DifficultyLevel = .normal, scenario: Scenario? = nil, isMultiplayer: Bool = false, administration: Administration? = nil) {
        self.playerCountryID = playerCountryID
        self.difficultyLevel = difficultyLevel
        // Use era-appropriate country list when playing as a historical administration
        let eraYear = administration?.startYear ?? 2025
        self.countries = CountryFactory.createCountriesForYear(eraYear)
        self.activeWars = []
        self.treaties = []
        self.nuclearStrikes = []
        self.turnHistory = []
        self.isMultiplayer = isMultiplayer
        self.playerCountries = isMultiplayer ? [playerCountryID] : []
        self.activeCyberOperations = []
        self.cyberIncidents = []
        self.activeWeaponPrograms = []

        // Use selected administration or default to Trump 2025
        if let admin = administration {
            self.advisors = admin.advisors
            self.eraStartYear = admin.startYear
            // Era country adjustments (nuclear arsenals, Soviet rename, etc.) are handled
            // by WorldCountriesDatabase.countriesForYear() above.
            // Apply additional fine-grained nuclear tweaks for the specific year:
            adjustCountriesForEra(year: admin.startYear)
        } else {
            self.advisors = Advisor.trumpCabinet()
            self.eraStartYear = 2025
        }

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
        advisors = try c.decodeIfPresent([Advisor].self, forKey: .advisors) ?? []
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
        try c.encode(advisors, forKey: .advisors)
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

    // MARK: - Historical Era Adjustment

    /// Adjust country data to match a historical year.
    /// Fixes nuclear arsenals, country names, and geopolitical alignment for the era.
    private func adjustCountriesForEra(year: Int) {
        for i in countries.indices {
            var country = countries[i]

            switch country.id {

            // ── Soviet Union / Russia ───────────────────────────────────────
            case "RUS":
                if year < 1991 {
                    // Soviet Union era
                    country = adjustedCountry(country,
                        name: "Soviet Union",
                        nukes: historicalSovietNukes(year: year),
                        icbm: historicalSovietICBMs(year: year),
                        slbm: year >= 1960 ? 48 : 0,
                        bombers: year >= 1955 ? 150 : 30,
                        military: 90,
                        gdp: year < 1960 ? 0.5 : year < 1980 ? 1.2 : 0.9,
                        alignment: .eastern,
                        government: .communist
                    )
                }

            // ── China ───────────────────────────────────────────────────────
            case "CHN":
                if year < 1949 {
                    // Civil War — Nationalist government
                    country = adjustedCountry(country,
                        name: "Republic of China",
                        nukes: 0, icbm: 0, slbm: 0, bombers: 20,
                        military: 40, gdp: 0.1,
                        alignment: .western, government: .military
                    )
                } else if year < 1964 {
                    // PRC before nuclear test
                    country = adjustedCountry(country,
                        name: "People's Republic of China",
                        nukes: 0, icbm: 0, slbm: 0, bombers: 30,
                        military: 65, gdp: 0.08,
                        alignment: .eastern, government: .communist
                    )
                } else if year < 1980 {
                    country = adjustedCountry(country,
                        nukes: year < 1970 ? 5 : 75,
                        icbm: year < 1970 ? 0 : 10,
                        slbm: 0, bombers: 40,
                        military: 72, gdp: 0.1,
                        alignment: .independent, government: .communist
                    )
                }

            // ── United Kingdom ───────────────────────────────────────────────
            case "GBR":
                if year < 1952 {
                    // UK tested first nuke 1952
                    country = adjustedCountry(country,
                        nukes: 0, icbm: 0, slbm: 0, bombers: 40,
                        military: 70, gdp: 0.5,
                        alignment: .western, government: .monarchy
                    )
                } else if year < 1970 {
                    country = adjustedCountry(country,
                        nukes: year < 1960 ? 15 : 80,
                        icbm: 0, slbm: year >= 1960 ? 16 : 0, bombers: 50,
                        military: 72, gdp: 0.6
                    )
                }

            // ── France ───────────────────────────────────────────────────────
            case "FRA":
                if year < 1960 {
                    // France tested first nuke 1960
                    country = adjustedCountry(country,
                        nukes: 0, icbm: 0, slbm: 0, bombers: 30,
                        military: 65, gdp: 0.3
                    )
                } else if year < 1980 {
                    country = adjustedCountry(country,
                        nukes: year < 1970 ? 30 : 100,
                        icbm: 0, slbm: year >= 1970 ? 16 : 0, bombers: 40,
                        military: 70, gdp: 0.4
                    )
                }

            // ── India ────────────────────────────────────────────────────────
            case "IND":
                if year < 1974 {
                    // India tested first nuke 1974
                    country = adjustedCountry(country,
                        nukes: 0, icbm: 0, slbm: 0, bombers: 10,
                        military: 50, gdp: 0.05
                    )
                }

            // ── Pakistan ─────────────────────────────────────────────────────
            case "PAK":
                if year < 1998 {
                    // Pakistan tested nukes 1998
                    country = adjustedCountry(country,
                        nukes: 0, icbm: 0, slbm: 0, bombers: 5,
                        military: 45, gdp: 0.03
                    )
                }

            // ── North Korea ──────────────────────────────────────────────────
            case "PRK":
                if year < 2006 {
                    // North Korea first nuclear test 2006
                    country = adjustedCountry(country,
                        nukes: 0, icbm: 0, slbm: 0, bombers: 0,
                        military: 40, gdp: 0.01
                    )
                }

            // ── Israel ───────────────────────────────────────────────────────
            case "ISR":
                if year < 1967 {
                    country = adjustedCountry(country,
                        nukes: 0, icbm: 0, slbm: 0, bombers: 0,
                        military: 55, gdp: 0.03
                    )
                }

            // ── United States ────────────────────────────────────────────────
            case "USA":
                if year <= 1945 {
                    country = adjustedCountry(country,
                        nukes: 9, icbm: 0, slbm: 0, bombers: 60,
                        military: 95, gdp: 2.2
                    )
                } else if year <= 1953 {
                    // End of Truman: ~1,169 warheads
                    country = adjustedCountry(country,
                        nukes: Int(Double(year - 1945) / 8.0 * 1169),
                        icbm: 0, slbm: 0, bombers: 100,
                        military: 100, gdp: 2.5
                    )
                } else if year <= 1961 {
                    // Eisenhower buildup: peaked at ~22,000
                    country = adjustedCountry(country,
                        nukes: 5000 + (year - 1953) * 2000,
                        icbm: year >= 1959 ? 60 : 0,
                        slbm: year >= 1960 ? 48 : 0, bombers: 600,
                        military: 100, gdp: 3.0
                    )
                } else if year <= 1970 {
                    country = adjustedCountry(country,
                        nukes: 28000, icbm: 1054, slbm: 160, bombers: 500,
                        military: 100, gdp: 4.5
                    )
                } else if year <= 1991 {
                    country = adjustedCountry(country,
                        nukes: 24000, icbm: 1000, slbm: 640, bombers: 300,
                        military: 100, gdp: 6.0
                    )
                }

            default:
                // Countries that didn't exist yet get reduced capabilities
                if year < 1991 {
                    // USSR satellite states had less independence
                    if ["UKR", "BLR", "KAZ"].contains(country.id) {
                        country = adjustedCountry(country,
                            name: "Soviet Territory",
                            nukes: 0, icbm: 0, slbm: 0, bombers: 0,
                            military: 0, gdp: 0.0,
                            alignment: .eastern, government: .communist
                        )
                    }
                }
            }

            countries[i] = country
        }
    }

    /// Returns a copy of a country with updated military/nuclear stats.
    private func adjustedCountry(
        _ country: Country,
        name: String? = nil,
        nukes: Int,
        icbm: Int,
        slbm: Int,
        bombers: Int,
        military: Int,
        gdp: Double? = nil,
        alignment: PoliticalAlignment? = nil,
        government: GovernmentType? = nil
    ) -> Country {
        var c = country
        if let name = name { c = renamedCountry(c, name: name) }
        c.nuclearWarheads = max(0, nukes)
        c.icbmCount = max(0, icbm)
        c.submarineLaunchedMissiles = max(0, slbm)
        c.bombers = max(0, bombers)
        c.militaryStrength = max(1, min(100, military))
        if let gdp = gdp { c.gdp = gdp }
        if let alignment = alignment { c.alignment = alignment }
        if let government = government { c.government = government }
        // Derived fields
        c.tacticalNukes = c.nuclearWarheads / 5
        c.strategicNukes = c.nuclearWarheads - c.tacticalNukes
        c.firstStrikeCapability = c.nuclearWarheads >= 100
        c.secondStrikeCapability = c.submarineLaunchedMissiles > 0
        c.nuclearStatus = c.nuclearWarheads > 0 ? .declared : .none
        return c
    }

    /// Returns a copy of a country with a new name (id/code unchanged).
    private func renamedCountry(_ country: Country, name: String) -> Country {
        var c = country
        c.name = name
        return c
    }

    private func historicalSovietNukes(year: Int) -> Int {
        switch year {
        case ..<1949: return 0         // No nukes before first test
        case 1949:    return 1         // First test
        case 1950:    return 5
        case 1951:    return 25
        case 1952:    return 50
        case 1953:    return 120
        case 1954...1959: return 120 + (year - 1953) * 300
        case 1960...1969: return 1600 + (year - 1960) * 700
        case 1970...1979: return 11000 + (year - 1970) * 400
        case 1980...1991: return 30000
        default:      return 5977      // Post-Soviet modern numbers
        }
    }

    private func historicalSovietICBMs(year: Int) -> Int {
        switch year {
        case ..<1957: return 0    // First ICBM test 1957
        case 1957...1959: return 4
        case 1960...1964: return 50 + (year - 1960) * 30
        case 1965...1970: return 250 + (year - 1965) * 100
        default: return 320
        }
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
