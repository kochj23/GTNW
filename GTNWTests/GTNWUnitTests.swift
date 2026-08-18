//
//  GTNWUnitTests.swift
//  GTNWTests
//
//  Unit tests for GTNW core models and game logic
//  Created by Jordan Koch on 2026-05-01.
//

import XCTest
@testable import GTNW

// MARK: - Country Model Tests

final class CountryTests: XCTestCase {

    func testCountryInitialization() {
        let usa = Country(
            id: "USA", name: "United States", code: "USA", flag: "🇺🇸",
            capital: "Washington D.C.", region: .northAmerica,
            lat: 38.9, lon: -77.0, nuclearStatus: .declared,
            nuclearWarheads: 5500, icbmCount: 400, submarineLaunchedMissiles: 280,
            bombers: 66, militaryStrength: 95, gdp: 25.0, population: 330,
            economicStrength: 90, government: .republic, alignment: .western,
            stability: 80
        )

        XCTAssertEqual(usa.id, "USA")
        XCTAssertEqual(usa.name, "United States")
        XCTAssertEqual(usa.nuclearWarheads, 5500)
        XCTAssertFalse(usa.isPlayerControlled)
        XCTAssertFalse(usa.isDestroyed)
        XCTAssertEqual(usa.damageLevel, 0)
        XCTAssertEqual(usa.radiationLevel, 0)
    }

    func testNuclearCapabilityCalculation() {
        let country = Country(
            id: "TST", name: "TestLand", code: "TST", flag: "🏳️",
            capital: "Test City", region: .europe,
            lat: 0, lon: 0, nuclearStatus: .declared,
            nuclearWarheads: 100, icbmCount: 20, submarineLaunchedMissiles: 10,
            bombers: 8, militaryStrength: 50, gdp: 1.0, population: 50,
            economicStrength: 50, government: .democracy, alignment: .western,
            stability: 70
        )

        // nuclearWarheads + (icbmCount * 10) + (slbm * 15) + (bombers * 5)
        let expected = 100 + (20 * 10) + (10 * 15) + (8 * 5)
        XCTAssertEqual(country.nuclearCapability, expected)
    }

    func testPowerScoreCalculation() {
        let country = Country(
            id: "TST", name: "TestLand", code: "TST", flag: "🏳️",
            capital: "Test City", region: .europe,
            lat: 0, lon: 0, nuclearStatus: .declared,
            nuclearWarheads: 100, icbmCount: 10, submarineLaunchedMissiles: 5,
            bombers: 5, militaryStrength: 80, gdp: 5.0, population: 100,
            economicStrength: 70, government: .democracy, alignment: .western,
            stability: 75
        )

        let score = country.powerScore
        XCTAssertGreaterThan(score, 0)
        XCTAssertLessThanOrEqual(score, 100)
    }

    func testDefaultDefenseSystemsForMajorPower() {
        let usa = Country(
            id: "USA", name: "United States", code: "USA", flag: "🇺🇸",
            capital: "Washington D.C.", region: .northAmerica,
            lat: 38.9, lon: -77.0, nuclearStatus: .declared,
            nuclearWarheads: 5500, icbmCount: 400, submarineLaunchedMissiles: 280,
            bombers: 66, militaryStrength: 95, gdp: 25.0, population: 330,
            economicStrength: 90, government: .republic, alignment: .western,
            stability: 80
        )

        XCTAssertTrue(usa.hasNORAD, "USA should have NORAD")
        XCTAssertEqual(usa.bunkerCapacity, 10)
        XCTAssertTrue(usa.firstStrikeCapability, "USA with 5500 warheads should have first strike capability")
        XCTAssertTrue(usa.secondStrikeCapability, "USA with SLBMs should have second strike capability")
    }

    func testDefaultDefenseSystemsForMinorPower() {
        let minor = Country(
            id: "LIE", name: "Liechtenstein", code: "LIE", flag: "🇱🇮",
            capital: "Vaduz", region: .europe,
            lat: 47.1, lon: 9.5, nuclearStatus: .none,
            nuclearWarheads: 0, icbmCount: 0, submarineLaunchedMissiles: 0,
            bombers: 0, militaryStrength: 5, gdp: 0.007, population: 1,
            economicStrength: 60, government: .monarchy, alignment: .western,
            stability: 95
        )

        XCTAssertFalse(minor.hasNORAD)
        XCTAssertEqual(minor.bunkerCapacity, 2)
        XCTAssertFalse(minor.firstStrikeCapability)
        XCTAssertFalse(minor.hasDeadHand)
    }

    func testRussiaHasDeadHand() {
        let russia = Country(
            id: "RUS", name: "Russia", code: "RUS", flag: "🇷🇺",
            capital: "Moscow", region: .europe,
            lat: 55.7, lon: 37.6, nuclearStatus: .declared,
            nuclearWarheads: 6257, icbmCount: 310, submarineLaunchedMissiles: 192,
            bombers: 71, militaryStrength: 88, gdp: 2.0, population: 143,
            economicStrength: 55, government: .authoritarian, alignment: .eastern,
            stability: 65
        )

        XCTAssertTrue(russia.hasDeadHand, "Only Russia should have Dead Hand system")
    }

    func testCyberDefaultsForMajorVsMinorPower() {
        let major = Country(
            id: "GBR", name: "United Kingdom", code: "GBR", flag: "🇬🇧",
            capital: "London", region: .europe,
            lat: 51.5, lon: -0.12, nuclearStatus: .declared,
            nuclearWarheads: 225, icbmCount: 0, submarineLaunchedMissiles: 48,
            bombers: 0, militaryStrength: 80, gdp: 3.1, population: 67,
            economicStrength: 78, government: .monarchy, alignment: .western,
            stability: 75
        )

        XCTAssertEqual(major.cyberDefenseLevel, .advanced)
        XCTAssertEqual(major.cyberOffenseLevel, 80)

        let minor = Country(
            id: "BRA", name: "Brazil", code: "BRA", flag: "🇧🇷",
            capital: "Brasilia", region: .southAmerica,
            lat: -15.8, lon: -47.9, nuclearStatus: .none,
            nuclearWarheads: 0, icbmCount: 0, submarineLaunchedMissiles: 0,
            bombers: 0, militaryStrength: 50, gdp: 2.0, population: 215,
            economicStrength: 50, government: .democracy, alignment: .nonAligned,
            stability: 55
        )

        XCTAssertEqual(minor.cyberDefenseLevel, .moderate)
    }
}

// MARK: - GameState Tests

final class GameStateTests: XCTestCase {

    func testGameStateInitialization() {
        let gs = GameState(playerCountryID: "USA")

        XCTAssertEqual(gs.turn, 0)
        XCTAssertEqual(gs.defconLevel, .defcon5)
        XCTAssertEqual(gs.playerCountryID, "USA")
        XCTAssertFalse(gs.gameOver)
        XCTAssertTrue(gs.activeWars.isEmpty)
        XCTAssertTrue(gs.nuclearStrikes.isEmpty)
        XCTAssertEqual(gs.globalRadiation, 0)
        XCTAssertEqual(gs.totalCasualties, 0)
    }

    func testPlayerCountryIsMarked() {
        let gs = GameState(playerCountryID: "USA")

        let player = gs.getPlayerCountry()
        XCTAssertNotNil(player)
        XCTAssertTrue(player!.isPlayerControlled)
        XCTAssertEqual(player!.id, "USA")
    }

    func testCountriesArePopulated() {
        let gs = GameState(playerCountryID: "USA")

        // Should have 195 countries for modern era
        XCTAssertGreaterThanOrEqual(gs.countries.count, 100, "Modern era should have 100+ countries")
    }

    func testGetCountryByID() {
        let gs = GameState(playerCountryID: "USA")

        let russia = gs.getCountry(id: "RUS")
        XCTAssertNotNil(russia)
        XCTAssertEqual(russia!.code, "RUS")

        let nonexistent = gs.getCountry(id: "ZZZZZ")
        XCTAssertNil(nonexistent)
    }

    func testDiplomaticRelationsInitialized() {
        let gs = GameState(playerCountryID: "USA")

        guard let usa = gs.getCountry(id: "USA") else {
            XCTFail("USA not found")
            return
        }

        // USA should have diplomatic relations with other countries
        XCTAssertFalse(usa.diplomaticRelations.isEmpty, "USA should have diplomatic relations")
    }

    func testSetRelation() {
        let gs = GameState(playerCountryID: "USA")

        gs.setRelation(from: "USA", to: "RUS", value: -80)

        let usa = gs.getCountry(id: "USA")
        XCTAssertEqual(usa?.diplomaticRelations["RUS"], -80)
    }

    func testRelationClamped() {
        let gs = GameState(playerCountryID: "USA")

        gs.setRelation(from: "USA", to: "RUS", value: -200)
        let usa = gs.getCountry(id: "USA")
        XCTAssertEqual(usa?.diplomaticRelations["RUS"], -100, "Relations should clamp to -100")

        gs.setRelation(from: "USA", to: "RUS", value: 200)
        let usaAfter = gs.getCountry(id: "USA")
        XCTAssertEqual(usaAfter?.diplomaticRelations["RUS"], 100, "Relations should clamp to 100")
    }

    func testDifficultyLevels() {
        XCTAssertEqual(DifficultyLevel.easy.aiAggressionMultiplier, 0.5)
        XCTAssertEqual(DifficultyLevel.normal.aiAggressionMultiplier, 1.0)
        XCTAssertEqual(DifficultyLevel.hard.aiAggressionMultiplier, 1.5)
        XCTAssertEqual(DifficultyLevel.nightmare.aiAggressionMultiplier, 2.0)
    }
}

// MARK: - DefconLevel Tests

final class DefconLevelTests: XCTestCase {

    func testDefconRawValues() {
        XCTAssertEqual(DefconLevel.defcon5.rawValue, 5)
        XCTAssertEqual(DefconLevel.defcon4.rawValue, 4)
        XCTAssertEqual(DefconLevel.defcon3.rawValue, 3)
        XCTAssertEqual(DefconLevel.defcon2.rawValue, 2)
        XCTAssertEqual(DefconLevel.defcon1.rawValue, 1)
    }

    func testDefconDescriptions() {
        XCTAssertTrue(DefconLevel.defcon5.description.contains("Peacetime"))
        XCTAssertTrue(DefconLevel.defcon1.description.contains("NUCLEAR WAR"))
    }

    func testDefconCaseIterable() {
        XCTAssertEqual(DefconLevel.allCases.count, 5)
    }
}

// MARK: - Era System Tests

final class EraSystemTests: XCTestCase {

    func testDeliverySystemLabels() {
        let gs1945 = GameState(playerCountryID: "USA")
        gs1945.eraStartYear = 1950
        XCTAssertEqual(gs1945.deliverySystemLabel, "Atom Bombs")

        let gs1960 = GameState(playerCountryID: "USA")
        gs1960.eraStartYear = 1965
        XCTAssertEqual(gs1960.deliverySystemLabel, "ICBMs")
    }

    func testCyberWarfareAvailability() {
        let gs = GameState(playerCountryID: "USA")

        gs.eraStartYear = 1985
        XCTAssertFalse(gs.cyberWarfareAvailable, "Cyber warfare should not exist before 1990")

        gs.eraStartYear = 2000
        XCTAssertTrue(gs.cyberWarfareAvailable, "Cyber warfare should exist after 1990")
    }

    func testSDIAvailability() {
        let gs = GameState(playerCountryID: "USA")

        gs.eraStartYear = 1975
        XCTAssertFalse(gs.sdiAvailable, "SDI should not exist before 1983")

        gs.eraStartYear = 1985
        XCTAssertTrue(gs.sdiAvailable, "SDI should exist after 1983")
    }

    func testDroneStrikesAvailability() {
        let gs = GameState(playerCountryID: "USA")

        gs.eraStartYear = 1999
        XCTAssertFalse(gs.droneStrikesAvailable, "Drone strikes should not exist before 2001")

        gs.eraStartYear = 2010
        XCTAssertTrue(gs.droneStrikesAvailable, "Drone strikes should exist after 2001")
    }

    func testEraDiplomacyAmountScaling() {
        let gs = GameState(playerCountryID: "USA")

        gs.eraStartYear = 1800
        let preIndustrial = gs.eraDiplomacyAmount
        XCTAssertEqual(preIndustrial, 100_000)

        gs.eraStartYear = 2025
        let modern = gs.eraDiplomacyAmount
        XCTAssertEqual(modern, 5_000_000_000)

        XCTAssertGreaterThan(modern, preIndustrial, "Modern diplomacy costs should exceed 19th century")
    }

    func testNewsOutletsByEra() {
        let gs = GameState(playerCountryID: "USA")

        gs.eraStartYear = 1920
        let earlyOutlets = gs.availableNewsOutlets
        XCTAssertTrue(earlyOutlets.contains("Associated Press"))
        XCTAssertTrue(earlyOutlets.contains("Reuters"))
        XCTAssertFalse(earlyOutlets.contains("CNN"), "CNN should not exist in 1920")

        gs.eraStartYear = 2020
        let modernOutlets = gs.availableNewsOutlets
        XCTAssertTrue(modernOutlets.contains("CNN"))
        XCTAssertTrue(modernOutlets.contains("FOX News"))
        XCTAssertTrue(modernOutlets.contains("Twitter/X News"))
    }
}

// MARK: - Scoring System Tests

final class ScoringSystemTests: XCTestCase {

    func testVictoryTypeBaseScores() {
        XCTAssertEqual(VictoryType.secretEnding.baseScore, 2000)
        XCTAssertEqual(VictoryType.peaceMaker.baseScore, 1500)
        XCTAssertEqual(VictoryType.diplomaticVictory.baseScore, 1200)
        XCTAssertEqual(VictoryType.economicVictory.baseScore, 1000)
        XCTAssertEqual(VictoryType.supremacy.baseScore, 800)
        XCTAssertEqual(VictoryType.survival.baseScore, 600)
        XCTAssertEqual(VictoryType.pyrrhicVictory.baseScore, 200)
    }

    func testScoreCalculationNoVictory() {
        let gs = GameState(playerCountryID: "USA")
        gs.turn = 10

        let score = GameScore.calculate(from: gs, victoryType: nil)
        XCTAssertEqual(score.baseScore, 0)
        XCTAssertTrue(score.nuclearVirgin, "No nukes launched should be nuclear virgin")
        XCTAssertEqual(score.casualtyPenalty, 0, "No casualties should mean no penalty")
    }

    func testScoreWithVictory() {
        let gs = GameState(playerCountryID: "USA")
        gs.turn = 50

        let score = GameScore.calculate(from: gs, victoryType: .secretEnding)
        XCTAssertEqual(score.baseScore, 2000)
        XCTAssertGreaterThan(score.finalScore, 0)
    }

    func testDifficultyMultiplier() {
        let gsEasy = GameState(playerCountryID: "USA", difficultyLevel: .easy)
        gsEasy.turn = 20
        let scoreEasy = GameScore.calculate(from: gsEasy, victoryType: .peaceMaker)

        let gsHard = GameState(playerCountryID: "USA", difficultyLevel: .hard)
        gsHard.turn = 20
        let scoreHard = GameScore.calculate(from: gsHard, victoryType: .peaceMaker)

        XCTAssertGreaterThan(scoreHard.finalScore, scoreEasy.finalScore,
                             "Hard difficulty should produce higher scores")
    }

    func testNuclearVirginBonus() {
        let gs = GameState(playerCountryID: "USA")
        gs.turn = 10

        let virginScore = GameScore.calculate(from: gs, victoryType: .peaceMaker)
        XCTAssertTrue(virginScore.nuclearVirgin)

        // Add a nuclear strike by player
        let strike = NuclearStrike(attacker: "USA", target: "RUS", warheadsUsed: 5,
                                   turn: 5, casualties: 5_000_000, radiationSpread: 50)
        gs.nuclearStrikes.append(strike)
        gs.totalCasualties = 5_000_000

        let nonVirginScore = GameScore.calculate(from: gs, victoryType: .peaceMaker)
        XCTAssertFalse(nonVirginScore.nuclearVirgin)
        XCTAssertLessThan(nonVirginScore.finalScore, virginScore.finalScore,
                          "Launching nukes should reduce score")
    }

    func testScoreNeverNegative() {
        let gs = GameState(playerCountryID: "USA")
        gs.totalCasualties = 999_999_999 // massive casualties
        gs.turn = 1

        let score = GameScore.calculate(from: gs, victoryType: nil)
        XCTAssertGreaterThanOrEqual(score.finalScore, 0, "Score should never be negative")
    }
}

// MARK: - Victory Condition Tests

final class VictoryCheckerTests: XCTestCase {

    func testNoVictoryAtStart() {
        let gs = GameState(playerCountryID: "USA")

        let victory = VictoryChecker.checkVictory(gameState: gs)
        XCTAssertNil(victory, "No victory should be achievable at game start")
    }

    func testDefeatWhenPlayerDestroyed() {
        let gs = GameState(playerCountryID: "USA")

        if let idx = gs.countries.firstIndex(where: { $0.id == "USA" }) {
            gs.countries[idx].isDestroyed = true
        }

        let result = VictoryChecker.checkDefeat(gameState: gs)
        XCTAssertTrue(result.defeated)
        XCTAssertTrue(result.reason.contains("destroyed"))
    }

    func testDefeatFromRadiation() {
        let gs = GameState(playerCountryID: "USA")
        gs.globalRadiation = 501

        let result = VictoryChecker.checkDefeat(gameState: gs)
        XCTAssertTrue(result.defeated)
        XCTAssertTrue(result.reason.lowercased().contains("uninhabitable") ||
                       result.reason.lowercased().contains("extinct"))
    }

    func testDefeatFromCasualties() {
        let gs = GameState(playerCountryID: "USA")
        gs.totalCasualties = 1_000_000_001

        let result = VictoryChecker.checkDefeat(gameState: gs)
        XCTAssertTrue(result.defeated)
        XCTAssertTrue(result.reason.lowercased().contains("billion") ||
                       result.reason.lowercased().contains("collapsed"))
    }

    func testNoDefeatAtStart() {
        let gs = GameState(playerCountryID: "USA")

        let result = VictoryChecker.checkDefeat(gameState: gs)
        XCTAssertFalse(result.defeated)
    }

    func testSecretEndingRequirements() {
        let gs = GameState(playerCountryID: "USA")
        gs.turn = 50

        // Secret ending: 50+ turns, no wars, no nuclear strikes
        // Wars and strikes should already be empty from init
        let victory = VictoryChecker.checkVictory(gameState: gs)
        XCTAssertEqual(victory, .secretEnding, "50 turns with no wars/nukes should trigger secret ending")
    }

    func testPeaceMakerRequirements() {
        let gs = GameState(playerCountryID: "USA")
        gs.turn = 25

        // Peace Maker: 20+ turns, no active wars, no player-launched nukes
        let victory = VictoryChecker.checkVictory(gameState: gs)
        // Could be secretEnding at turn 25 since turn >= 50 is false, check peaceMaker
        // Actually at turn 25, no wars, no nukes -> peaceMaker (not secretEnding since turn < 50)
        XCTAssertEqual(victory, .peaceMaker)
    }
}

// MARK: - War & Treaty Model Tests

final class WarAndTreatyTests: XCTestCase {

    func testWarCreation() {
        let war = War(aggressor: "USA", defender: "RUS", startTurn: 5)

        XCTAssertEqual(war.aggressor, "USA")
        XCTAssertEqual(war.defender, "RUS")
        XCTAssertEqual(war.startTurn, 5)
        XCTAssertEqual(war.intensity, 5) // default
    }

    func testTreatyCreation() {
        let treaty = Treaty(type: .alliance, signatories: ["USA", "GBR"], turn: 10)

        XCTAssertEqual(treaty.type, .alliance)
        XCTAssertEqual(treaty.signatories.count, 2)
        XCTAssertEqual(treaty.turn, 10)
    }

    func testNuclearStrikeCreation() {
        let strike = NuclearStrike(attacker: "RUS", target: "USA",
                                   warheadsUsed: 10, turn: 15,
                                   casualties: 10_000_000, radiationSpread: 100)

        XCTAssertEqual(strike.attacker, "RUS")
        XCTAssertEqual(strike.target, "USA")
        XCTAssertEqual(strike.warheadsUsed, 10)
        XCTAssertEqual(strike.casualties, 10_000_000)
    }

    func testTurnEventCreation() {
        let event = TurnEvent(turn: 3, event: "War declared")

        XCTAssertEqual(event.turn, 3)
        XCTAssertEqual(event.event, "War declared")
    }
}

// MARK: - Leaderboard Tests

final class LeaderboardTests: XCTestCase {

    // LeaderboardManager persists to UserDefaults.standard["GTNW_Leaderboard"], which is
    // shared process-wide. Without clearing it, entries accumulate across tests (and prior
    // runs), polluting sort/rank assertions. Reset before and after each test for hermeticity.
    private let leaderboardKey = "GTNW_Leaderboard"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: leaderboardKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: leaderboardKey)
        super.tearDown()
    }

    func testLeaderboardSorting() {
        let manager = LeaderboardManager()

        var score1 = GameScore()
        score1.finalScore = 100

        var score2 = GameScore()
        score2.finalScore = 500

        var score3 = GameScore()
        score3.finalScore = 300

        manager.addEntry(playerName: "Player1", score: score1)
        manager.addEntry(playerName: "Player2", score: score2)
        manager.addEntry(playerName: "Player3", score: score3)

        let top = manager.getTopEntries(count: 3)
        XCTAssertEqual(top[0].score.finalScore, 500)
        XCTAssertEqual(top[1].score.finalScore, 300)
        XCTAssertEqual(top[2].score.finalScore, 100)
    }

    func testLeaderboardRanking() {
        let manager = LeaderboardManager()

        var score1 = GameScore()
        score1.finalScore = 1000

        manager.addEntry(playerName: "TopPlayer", score: score1)

        let rank = manager.getRank(for: 500)
        XCTAssertEqual(rank, 2, "Score of 500 should rank below 1000")
    }

    func testBestScore() {
        let manager = LeaderboardManager()

        var score = GameScore()
        score.finalScore = 750
        manager.addEntry(playerName: "TestPlayer", score: score)

        let best = manager.getBestScore(playerName: "TestPlayer")
        XCTAssertNotNil(best)
        XCTAssertEqual(best?.score.finalScore, 750)

        let notFound = manager.getBestScore(playerName: "NonExistent")
        XCTAssertNil(notFound)
    }
}

// MARK: - Codable Tests

final class CodableTests: XCTestCase {

    func testCountryCodable() throws {
        let country = Country(
            id: "TST", name: "TestLand", code: "TST", flag: "🏳️",
            capital: "TestCity", region: .europe,
            lat: 50.0, lon: 10.0, nuclearStatus: .declared,
            nuclearWarheads: 50, icbmCount: 10, submarineLaunchedMissiles: 5,
            bombers: 3, militaryStrength: 60, gdp: 2.0, population: 80,
            economicStrength: 65, government: .democracy, alignment: .western,
            stability: 75
        )

        let data = try JSONEncoder().encode(country)
        let decoded = try JSONDecoder().decode(Country.self, from: data)

        XCTAssertEqual(decoded.id, country.id)
        XCTAssertEqual(decoded.nuclearWarheads, country.nuclearWarheads)
        XCTAssertEqual(decoded.alignment, country.alignment)
    }

    func testWarCodable() throws {
        let war = War(aggressor: "USA", defender: "RUS", startTurn: 5, intensity: 8)
        let data = try JSONEncoder().encode(war)
        let decoded = try JSONDecoder().decode(War.self, from: data)

        XCTAssertEqual(decoded.aggressor, war.aggressor)
        XCTAssertEqual(decoded.defender, war.defender)
        XCTAssertEqual(decoded.intensity, 8)
    }

    func testDefconLevelCodable() throws {
        let level = DefconLevel.defcon2
        let data = try JSONEncoder().encode(level)
        let decoded = try JSONDecoder().decode(DefconLevel.self, from: data)

        XCTAssertEqual(decoded, level)
    }

    func testVictoryTypeCodable() throws {
        for victoryType in VictoryType.allCases {
            let data = try JSONEncoder().encode(victoryType)
            let decoded = try JSONDecoder().decode(VictoryType.self, from: data)
            XCTAssertEqual(decoded, victoryType)
        }
    }
}
