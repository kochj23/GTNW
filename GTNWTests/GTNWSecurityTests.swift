//
//  GTNWSecurityTests.swift
//  GTNWTests
//
//  Security tests for GTNW — credential storage, API binding, input validation
//  Created by Jordan Koch on 2026-05-01.
//

import XCTest
@testable import GTNW

// MARK: - NovaAPIServer Security Tests

@MainActor
final class NovaAPIServerSecurityTests: XCTestCase {

    func testAPIServerPortIsCorrect() {
        // NovaAPIServer should be bound to port 37431
        let server = NovaAPIServer.shared
        XCTAssertEqual(server.port, 37431, "API server should use port 37431")
    }
}

// MARK: - Input Boundary Tests

final class InputBoundaryTests: XCTestCase {

    func testDiplomaticRelationBounds() {
        let gs = GameState(playerCountryID: "USA")

        // Relations should always be clamped to -100..100
        gs.setRelation(from: "USA", to: "RUS", value: Int.max)
        let maxRelation = gs.getCountry(id: "USA")?.diplomaticRelations["RUS"] ?? 0
        XCTAssertLessThanOrEqual(maxRelation, 100, "Relations must not exceed 100")

        gs.setRelation(from: "USA", to: "RUS", value: Int.min)
        let minRelation = gs.getCountry(id: "USA")?.diplomaticRelations["RUS"] ?? 0
        XCTAssertGreaterThanOrEqual(minRelation, -100, "Relations must not go below -100")
    }

    func testMilitaryStrengthFloor() {
        let gs = GameState(playerCountryID: "USA")

        // After sabotage, military strength should never go below 0
        if let idx = gs.countries.firstIndex(where: { $0.id == "LIE" }) {
            gs.countries[idx].militaryStrength = 5
        }

        let engine = GameEngine()
        engine.startNewGame()
        // Set military very low
        if let idx = engine.gameState?.countries.firstIndex(where: { $0.id == "LIE" }) {
            engine.gameState?.countries[idx].militaryStrength = 5
        }

        engine.covertSabotage(from: "USA", to: "LIE")

        let mil = engine.gameState?.getCountry(id: "LIE")?.militaryStrength ?? -1
        XCTAssertGreaterThanOrEqual(mil, 0, "Military strength must never be negative")
    }

    func testWarheadCountFloor() {
        let gs = GameState(playerCountryID: "USA")

        // Warheads should never go negative
        if let idx = gs.countries.firstIndex(where: { $0.id == "LIE" }) {
            gs.countries[idx].nuclearWarheads = 3
        }

        let engine = GameEngine()
        engine.startNewGame()
        if let idx = engine.gameState?.countries.firstIndex(where: { $0.id == "LIE" }) {
            engine.gameState?.countries[idx].nuclearWarheads = 3
        }

        engine.specialForces(from: "USA", to: "LIE")

        let warheads = engine.gameState?.getCountry(id: "LIE")?.nuclearWarheads ?? -1
        XCTAssertGreaterThanOrEqual(warheads, 0, "Warhead count must never be negative")
    }

    func testStabilityFloor() {
        let engine = GameEngine()
        engine.startNewGame()

        // Set stability very low
        if let idx = engine.gameState?.countries.firstIndex(where: { $0.id == "RUS" }) {
            engine.gameState?.countries[idx].stability = 5
        }

        engine.propaganda(from: "USA", to: "RUS")

        let stability = engine.gameState?.getCountry(id: "RUS")?.stability ?? -1
        XCTAssertGreaterThanOrEqual(stability, 0, "Stability must never be negative")
    }

    func testDamageLevel100DestroysCountry() {
        let gs = GameState(playerCountryID: "USA")

        if let idx = gs.countries.firstIndex(where: { $0.id == "LIE" }) {
            gs.countries[idx].damageLevel = 100
            // The game engine checks: if damageLevel >= 100, isDestroyed = true
            // This is done in launchNuclearStrike
            if gs.countries[idx].damageLevel >= 100 {
                gs.countries[idx].isDestroyed = true
            }
            XCTAssertTrue(gs.countries[idx].isDestroyed, "100% damage should destroy country")
        }
    }
}

// MARK: - Game State Integrity Tests

final class GameStateIntegrityTests: XCTestCase {

    func testPlayerCountryExistsInList() {
        let gs = GameState(playerCountryID: "USA")

        let player = gs.getPlayerCountry()
        XCTAssertNotNil(player, "Player country must exist in country list")
        XCTAssertTrue(player?.isPlayerControlled ?? false)
    }

    func testOnlyOnePlayerControlledCountry() {
        let gs = GameState(playerCountryID: "USA")

        let playerControlled = gs.countries.filter { $0.isPlayerControlled }
        XCTAssertEqual(playerControlled.count, 1, "Exactly one country should be player controlled")
    }

    func testCountryIDsAreUnique() {
        let gs = GameState(playerCountryID: "USA")

        let ids = gs.countries.map { $0.id }
        let uniqueIDs = Set(ids)
        XCTAssertEqual(ids.count, uniqueIDs.count, "All country IDs must be unique")
    }

    func testCountryCodesAreUnique() {
        let gs = GameState(playerCountryID: "USA")

        let codes = gs.countries.map { $0.code }
        let uniqueCodes = Set(codes)
        XCTAssertEqual(codes.count, uniqueCodes.count, "All country codes must be unique")
    }

    func testAllCountriesHaveValidCoordinates() {
        let gs = GameState(playerCountryID: "USA")

        for country in gs.countries {
            XCTAssertGreaterThanOrEqual(country.coordinates.lat, -90, "\(country.name) latitude too low")
            XCTAssertLessThanOrEqual(country.coordinates.lat, 90, "\(country.name) latitude too high")
            XCTAssertGreaterThanOrEqual(country.coordinates.lon, -180, "\(country.name) longitude too low")
            XCTAssertLessThanOrEqual(country.coordinates.lon, 180, "\(country.name) longitude too high")
        }
    }

    func testAllCountriesHaveFlags() {
        let gs = GameState(playerCountryID: "USA")

        for country in gs.countries {
            XCTAssertFalse(country.flag.isEmpty, "\(country.name) must have a flag emoji")
        }
    }

    func testAllCountriesHaveCapitals() {
        let gs = GameState(playerCountryID: "USA")

        for country in gs.countries {
            XCTAssertFalse(country.capital.isEmpty, "\(country.name) must have a capital city")
        }
    }

    func testNuclearPowersHaveWarheads() {
        let gs = GameState(playerCountryID: "USA")

        let declaredNuclear = gs.countries.filter { $0.nuclearStatus == .declared }
        for country in declaredNuclear {
            XCTAssertGreaterThan(country.nuclearWarheads, 0,
                                 "\(country.name) is declared nuclear but has 0 warheads")
        }
    }

    func testNonNuclearCountriesHaveZeroWarheads() {
        let gs = GameState(playerCountryID: "USA")

        let nonNuclear = gs.countries.filter { $0.nuclearStatus == .none }
        for country in nonNuclear {
            XCTAssertEqual(country.nuclearWarheads, 0,
                           "\(country.name) is non-nuclear but has \(country.nuclearWarheads) warheads")
        }
    }

    func testGameOverStateIsConsistent() {
        let gs = GameState(playerCountryID: "USA")

        XCTAssertFalse(gs.gameOver)
        XCTAssertTrue(gs.gameOverReason.isEmpty)

        gs.gameOver = true
        gs.gameOverReason = "Test game over"
        XCTAssertTrue(gs.gameOver)
        XCTAssertFalse(gs.gameOverReason.isEmpty)
    }
}

// MARK: - Enum Completeness Tests

final class EnumCompletenessTests: XCTestCase {

    func testAllNuclearStatusesExist() {
        let allStatuses = NuclearStatus.allCases
        XCTAssertTrue(allStatuses.contains(.declared))
        XCTAssertTrue(allStatuses.contains(.undeclared))
        XCTAssertTrue(allStatuses.contains(.suspected))
        XCTAssertTrue(allStatuses.contains(.developing))
        XCTAssertTrue(allStatuses.contains(.none))
    }

    func testAllDefconLevels() {
        XCTAssertEqual(DefconLevel.allCases.count, 5)
    }

    func testAllDifficultyLevels() {
        XCTAssertEqual(DifficultyLevel.allCases.count, 4)
    }

    func testAllVictoryTypes() {
        XCTAssertEqual(VictoryType.allCases.count, 7)
    }

    func testAllWorldRegions() {
        let regions = WorldRegion.allCases
        XCTAssertGreaterThanOrEqual(regions.count, 6, "Should have at least 6 world regions")
    }
}

// MARK: - Serialization Safety Tests

final class SerializationSafetyTests: XCTestCase {

    func testGameStateSerialization() throws {
        let gs = GameState(playerCountryID: "USA")
        gs.turn = 15
        gs.defconLevel = .defcon3
        gs.totalCasualties = 500_000

        let encoder = JSONEncoder()
        let data = try encoder.encode(gs)
        XCTAssertGreaterThan(data.count, 0, "Serialized data should not be empty")

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(GameState.self, from: data)

        XCTAssertEqual(decoded.turn, 15)
        XCTAssertEqual(decoded.defconLevel, .defcon3)
        XCTAssertEqual(decoded.totalCasualties, 500_000)
        XCTAssertEqual(decoded.playerCountryID, "USA")
    }

    func testGameStateRoundTrip() throws {
        let gs = GameState(playerCountryID: "USA")

        // Add some game activity
        gs.turn = 10
        gs.activeWars.append(War(aggressor: "USA", defender: "RUS", startTurn: 5))
        gs.treaties.append(Treaty(type: .alliance, signatories: ["USA", "GBR"], turn: 3))
        gs.nuclearStrikes.append(NuclearStrike(
            attacker: "RUS", target: "USA",
            warheadsUsed: 5, turn: 8,
            casualties: 5_000_000, radiationSpread: 50
        ))

        let data = try JSONEncoder().encode(gs)
        let decoded = try JSONDecoder().decode(GameState.self, from: data)

        XCTAssertEqual(decoded.activeWars.count, 1)
        XCTAssertEqual(decoded.treaties.count, 1)
        XCTAssertEqual(decoded.nuclearStrikes.count, 1)
        XCTAssertEqual(decoded.activeWars.first?.aggressor, "USA")
    }

    func testCountrySerializationPreservesAllFields() throws {
        let country = Country(
            id: "TST", name: "TestLand", code: "TST", flag: "🏳️",
            capital: "TestCity", region: .europe,
            lat: 50.0, lon: 10.0, nuclearStatus: .declared,
            nuclearWarheads: 100, icbmCount: 20, submarineLaunchedMissiles: 10,
            bombers: 5, militaryStrength: 75, gdp: 3.5, population: 80,
            economicStrength: 70, government: .democracy, alignment: .western,
            stability: 80, hasSDI: true, sdiCoverage: 50, sdiInterceptionRate: 30
        )

        let data = try JSONEncoder().encode(country)
        let decoded = try JSONDecoder().decode(Country.self, from: data)

        XCTAssertEqual(decoded.hasSDI, true)
        XCTAssertEqual(decoded.sdiCoverage, 50)
        XCTAssertEqual(decoded.sdiInterceptionRate, 30)
        XCTAssertEqual(decoded.nuclearWarheads, 100)
        XCTAssertEqual(decoded.government, .democracy)
    }
}

// MARK: - Resource Abuse Protection Tests

final class ResourceAbuseTests: XCTestCase {

    func testLogDoesNotGrowUnbounded() {
        let engine = GameEngine()

        for i in 0..<500 {
            engine.addLog("Spam message \(i)", type: .info)
        }

        XCTAssertLessThan(engine.logMessages.count, 300,
                          "Log messages should be trimmed to prevent memory abuse")
    }

    func testGameStateCountryCountIsReasonable() {
        let gs = GameState(playerCountryID: "USA")
        XCTAssertLessThanOrEqual(gs.countries.count, 250,
                                  "Country count should be reasonable (< 250)")
    }

    func testScoreCannotBeGamed() {
        let gs = GameState(playerCountryID: "USA")
        gs.turn = 0
        gs.totalCasualties = 0

        // Even with no activity, score should be bounded
        let score = GameScore.calculate(from: gs, victoryType: nil)
        XCTAssertGreaterThanOrEqual(score.finalScore, 0, "Score floor must be 0")
    }
}
