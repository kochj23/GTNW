//
//  GTNWAuditTests.swift
//  GTNWTests
//
//  Focused regression tests added during the 2026 engineering audit.
//  Covers deterministic game logic that was previously untested:
//    • Crisis-resolution index bounds (guards the NovaAPIServer
//      POST /api/game/:id/crisis/resolve path, which passes an
//      unbounded optionIndex straight to CrisisManager.resolveCrisis)
//    • DEFCON clamping in crisis consequences
//    • GameScore arithmetic (casualty penalty, difficulty multiplier,
//      alliance/treaty bonuses, nuclear-virgin attribution)
//    • VictoryChecker boundary conditions (radiation / casualties /
//      supremacy / economic victory)
//    • launchNuclearStrike casualty & radiation math and DEFCON side effects
//    • GameScore Codable round-trip
//
//  Created by the audit pass on 2026-08-18.
//

import XCTest
@testable import GTNW

// MARK: - Crisis Resolution Safety

final class CrisisResolutionSafetyTests: XCTestCase {

    private func makeCrisis(optionCount: Int = 2, defconChange: Int = 0,
                            successChance: Double = 2.0) -> CrisisEvent {
        var options: [CrisisOption] = []
        for i in 0..<optionCount {
            options.append(CrisisOption(
                title: "Option \(i)",
                description: "Choice number \(i)",
                consequences: CrisisConsequences(defconChange: defconChange,
                                                 message: "Resolved via option \(i)"),
                successChance: successChance
            ))
        }
        return CrisisEvent(
            type: .diplomaticIncident, severity: .serious,
            title: "Test Crisis", description: "A synthetic crisis for testing",
            affectedCountries: ["USA"], turn: 3, timeLimit: nil, options: options
        )
    }

    // Regression: a negative optionIndex must NOT crash and must NOT resolve.
    // Previously the guard only checked `optionIndex < count`, so -1 passed the
    // guard and then `crisis.options[-1]` trapped (out-of-range crash) — reachable
    // from the loopback API via {"optionIndex": -1}.
    func testNegativeOptionIndexIsSafe() {
        let manager = CrisisManager()
        manager.presentCrisis(makeCrisis())
        var gs = GameState(playerCountryID: "USA")

        manager.resolveCrisis(optionIndex: -1, gameState: &gs)

        XCTAssertNotNil(manager.activeCrisis, "Negative index should be rejected, crisis stays active")
        XCTAssertTrue(manager.crisisHistory.isEmpty, "No crisis should be recorded for an invalid index")
    }

    func testOutOfRangeHighIndexIsSafe() {
        let manager = CrisisManager()
        manager.presentCrisis(makeCrisis(optionCount: 2))
        var gs = GameState(playerCountryID: "USA")

        manager.resolveCrisis(optionIndex: 99, gameState: &gs)

        XCTAssertNotNil(manager.activeCrisis, "Too-large index should be rejected")
        XCTAssertTrue(manager.crisisHistory.isEmpty)
    }

    func testValidIndexResolvesCrisis() {
        let manager = CrisisManager()
        manager.presentCrisis(makeCrisis(optionCount: 2, successChance: 2.0))
        var gs = GameState(playerCountryID: "USA")

        manager.resolveCrisis(optionIndex: 0, gameState: &gs)

        XCTAssertNil(manager.activeCrisis, "A valid resolution clears the active crisis")
        XCTAssertEqual(manager.crisisHistory.count, 1)
        XCTAssertEqual(manager.crisisHistory.first?.chosenOption, 0)
    }

    func testDefconClampsUpAtFive() {
        let manager = CrisisManager()
        manager.presentCrisis(makeCrisis(defconChange: 10, successChance: 2.0))
        var gs = GameState(playerCountryID: "USA")
        gs.defconLevel = .defcon3

        manager.resolveCrisis(optionIndex: 0, gameState: &gs)

        XCTAssertEqual(gs.defconLevel, .defcon5, "defconChange +10 from DEFCON 3 must clamp to 5")
    }

    func testDefconClampsDownAtOne() {
        let manager = CrisisManager()
        manager.presentCrisis(makeCrisis(defconChange: -10, successChance: 2.0))
        var gs = GameState(playerCountryID: "USA")
        gs.defconLevel = .defcon3

        manager.resolveCrisis(optionIndex: 0, gameState: &gs)

        XCTAssertEqual(gs.defconLevel, .defcon1, "defconChange -10 from DEFCON 3 must clamp to 1")
    }
}

// MARK: - GameScore Arithmetic

final class GameScoreArithmeticTests: XCTestCase {

    func testCasualtyPenaltyIsMinusOnePerThousand() {
        let gs = GameState(playerCountryID: "USA")
        gs.totalCasualties = 250_000

        let score = GameScore.calculate(from: gs, victoryType: nil)
        XCTAssertEqual(score.casualtyPenalty, -250, "Penalty is -1 per 1000 casualties")
    }

    func testDifficultyMultiplierValues() {
        let expected: [DifficultyLevel: Double] = [
            .easy: 1.0, .normal: 1.5, .hard: 2.0, .nightmare: 2.5
        ]
        for (level, mult) in expected {
            let gs = GameState(playerCountryID: "USA", difficultyLevel: level)
            let score = GameScore.calculate(from: gs, victoryType: nil)
            XCTAssertEqual(score.difficultyMultiplier, mult,
                           "\(level) should score-multiply by \(mult)")
        }
    }

    func testNuclearVirginCountsOnlyPlayerStrikes() {
        let gs = GameState(playerCountryID: "USA")
        // An opponent launching does NOT cost the player nuclear-virgin status.
        gs.nuclearStrikes.append(NuclearStrike(attacker: "RUS", target: "USA",
                                               warheadsUsed: 5, turn: 2,
                                               casualties: 5_000_000, radiationSpread: 50))
        let score = GameScore.calculate(from: gs, victoryType: nil)
        XCTAssertTrue(score.nuclearVirgin, "Opponent strikes should not void nuclear-virgin bonus")

        // The player launching DOES.
        gs.nuclearStrikes.append(NuclearStrike(attacker: "USA", target: "RUS",
                                               warheadsUsed: 5, turn: 3,
                                               casualties: 5_000_000, radiationSpread: 50))
        let score2 = GameScore.calculate(from: gs, victoryType: nil)
        XCTAssertFalse(score2.nuclearVirgin, "A player-launched strike voids the bonus")
    }

    func testAllianceBonusIsTwentyPerTreaty() {
        let gs = GameState(playerCountryID: "USA")
        gs.treaties.append(Treaty(type: .alliance, signatories: ["USA", "GBR"], turn: 1))
        gs.treaties.append(Treaty(type: .alliance, signatories: ["FRA", "GBR"], turn: 1))
        gs.treaties.append(Treaty(type: .nonAggression, signatories: ["USA", "CHN"], turn: 1))

        let score = GameScore.calculate(from: gs, victoryType: nil)
        XCTAssertEqual(score.allianceBonus, 60, "+20 per treaty × 3 treaties")
        // treatyBonus is +15 per treaty the player has signed (2 of the 3 here)
        XCTAssertEqual(score.treatyBonus, 30, "+15 per player-signed treaty × 2")
    }

    func testBaseScoreTracksVictoryType() {
        let gs = GameState(playerCountryID: "USA")
        gs.turn = 30
        let score = GameScore.calculate(from: gs, victoryType: .diplomaticVictory)
        XCTAssertEqual(score.baseScore, 1200)
        XCTAssertEqual(score.turnsPlayed, 30)
    }

    func testScoreCodableRoundTrip() throws {
        let gs = GameState(playerCountryID: "USA")
        gs.turn = 42
        gs.totalCasualties = 12_000
        let score = GameScore.calculate(from: gs, victoryType: .peaceMaker)

        let data = try JSONEncoder().encode(score)
        let decoded = try JSONDecoder().decode(GameScore.self, from: data)

        XCTAssertEqual(decoded.finalScore, score.finalScore)
        XCTAssertEqual(decoded.baseScore, score.baseScore)
        XCTAssertEqual(decoded.casualtyPenalty, score.casualtyPenalty)
        XCTAssertEqual(decoded.victoryType, score.victoryType)
    }
}

// MARK: - Victory / Defeat Boundaries

final class VictoryBoundaryTests: XCTestCase {

    func testRadiationDefeatBoundary() {
        let gs = GameState(playerCountryID: "USA")

        gs.globalRadiation = 500
        XCTAssertFalse(VictoryChecker.checkDefeat(gameState: gs).defeated,
                       "Radiation of exactly 500 is survivable (defeat is > 500)")

        gs.globalRadiation = 501
        XCTAssertTrue(VictoryChecker.checkDefeat(gameState: gs).defeated,
                      "Radiation of 501 is fatal")
    }

    func testCasualtyDefeatBoundary() {
        let gs = GameState(playerCountryID: "USA")

        gs.totalCasualties = 1_000_000_000
        XCTAssertFalse(VictoryChecker.checkDefeat(gameState: gs).defeated,
                       "Exactly 1 billion casualties is not yet defeat (uses strict >)")

        gs.totalCasualties = 1_000_000_001
        XCTAssertTrue(VictoryChecker.checkDefeat(gameState: gs).defeated,
                      "Over 1 billion casualties is defeat")
    }

    func testEconomicVictory() {
        let gs = GameState(playerCountryID: "USA")
        gs.turn = 5
        // Force an active war so the earlier peaceMaker branch cannot short-circuit.
        gs.activeWars.append(War(aggressor: "RUS", defender: "CHN", startTurn: 1))
        // Zero every non-player economy so the player's GDP exceeds all others combined.
        for i in gs.countries.indices where !gs.countries[i].isPlayerControlled {
            gs.countries[i].gdp = 0
        }
        XCTAssertEqual(VictoryChecker.checkVictory(gameState: gs), .economicVictory)
    }

    func testNuclearSupremacyVictory() {
        let gs = GameState(playerCountryID: "USA")
        gs.turn = 5
        gs.activeWars.append(War(aggressor: "RUS", defender: "CHN", startTurn: 1))
        // Make the player the only surviving nuclear power.
        for i in gs.countries.indices where !gs.countries[i].isPlayerControlled {
            gs.countries[i].nuclearWarheads = 0
        }
        guard let player = gs.getPlayerCountry(), player.nuclearWarheads > 0 else {
            return XCTFail("Player should retain warheads")
        }
        XCTAssertEqual(VictoryChecker.checkVictory(gameState: gs), .supremacy)
    }
}

// MARK: - Nuclear Strike Math

@MainActor
final class NuclearStrikeMathTests: XCTestCase {

    func testStrikeCasualtyAndRadiationMath() throws {
        let engine = GameEngine()
        engine.startNewGame(playerCountryID: "USA")
        guard let gs = engine.gameState else { return XCTFail("no state") }

        // Target a non-nuclear, non-SDI minor power: no retaliation, full penetration.
        let targetID = "BRA"
        guard let target = gs.getCountry(id: targetID), !target.hasSDI else {
            throw XCTSkip("Target unexpectedly has SDI; casualty math would be probabilistic")
        }
        let warheads = 3
        let attackerBefore = gs.getCountry(id: "USA")?.nuclearWarheads ?? 0

        engine.launchNuclearStrike(from: "USA", to: targetID, warheads: warheads)

        XCTAssertEqual(gs.totalCasualties, warheads * 1_000_000,
                       "1,000,000 casualties per penetrating warhead")
        XCTAssertEqual(gs.globalRadiation, warheads * 10,
                       "10 radiation points per penetrating warhead")
        XCTAssertEqual(gs.getCountry(id: "USA")?.nuclearWarheads, attackerBefore - warheads,
                       "Attacker arsenal is decremented by warheads used")
        XCTAssertEqual(gs.defconLevel, .defcon1, "Any nuclear launch forces DEFCON 1")
        XCTAssertEqual(gs.nuclearStrikes.count, 1)
    }

    func testStrikeDestroysTargetAboveDamageThreshold() throws {
        let engine = GameEngine()
        engine.startNewGame(playerCountryID: "USA")
        guard let gs = engine.gameState else { return XCTFail("no state") }
        guard let target = gs.getCountry(id: "BRA"), !target.hasSDI else {
            throw XCTSkip("Target has SDI; destruction is probabilistic")
        }

        // 15 warheads → damageLevel 150 (≥100) → destroyed.
        engine.launchNuclearStrike(from: "USA", to: "BRA", warheads: 15)
        XCTAssertTrue(gs.getCountry(id: "BRA")?.isDestroyed ?? false,
                      "damageLevel ≥ 100 must destroy the target")
    }

    func testStrikeWithInsufficientWarheadsIsNoOp() {
        let engine = GameEngine()
        engine.startNewGame(playerCountryID: "USA")
        guard let gs = engine.gameState else { return XCTFail("no state") }

        // Brazil has no warheads; it cannot launch.
        let casualtiesBefore = gs.totalCasualties
        engine.launchNuclearStrike(from: "BRA", to: "USA", warheads: 5)
        XCTAssertEqual(gs.totalCasualties, casualtiesBefore,
                       "A launch without sufficient warheads must be a no-op")
        XCTAssertTrue(gs.nuclearStrikes.isEmpty)
    }
}
