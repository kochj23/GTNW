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

    // Regression (3.1.2 crash, 2026-10-18): End Turn rolled a Military Coup with no armed
    // non-player country left and `randomElement()!` trapped. Every crisis type must
    // return nil or a valid crisis in a world with no eligible country, never crash.
    func testCrisisFactoriesSurviveDisarmedWorld() {
        let manager = CrisisManager()
        var gs = GameState(playerCountryID: "USA")
        for i in gs.countries.indices { gs.countries[i].nuclearWarheads = 0 }
        for type in CrisisEventType.allCases { _ = manager.createCrisis(type: type, gameState: gs) }
        XCTAssertNil(manager.createCrisis(type: .militaryCoup, gameState: gs))

        gs.countries = gs.countries.filter { $0.isPlayerControlled }
        for type in CrisisEventType.allCases { _ = manager.createCrisis(type: type, gameState: gs) }
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
        gs.turn = 61   // 3.16.0: peace victories need five years in office
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

        engine.launchNuclearStrike(from: "USA", to: targetID, warheads: warheads, type: .fission)

        XCTAssertEqual(gs.totalCasualties, warheads * 1_000_000,
                       "1,000,000 casualties per penetrating warhead (fission baseline)")
        XCTAssertEqual(gs.globalRadiation, warheads * 10,
                       "10 radiation points per penetrating warhead (fission baseline)")
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

// MARK: - 3.18.7 Dirty-arsenal expansion self-check (six new tactics, era-gated)
final class DirtyArsenalExpansionTests: XCTestCase {
    func testNewTacticsEraGating() {
        // id, first year possible, a year by which it is no longer plainly legal
        let cases: [(String, Int, Int)] = [
            ("dum_dum", 1897, 1899),
            ("cluster_munitions", 1943, 2010),
            ("depleted_uranium", 1991, 2007),
            ("blinding_lasers", 1980, 1998),
            ("cs_gas", 1959, 1997),
            ("thermobaric", 1969, 2002),
        ]
        for (id, from, constrained) in cases {
            guard let t = DirtyTactics.tactic(id) else { XCTFail("\(id) missing from catalog"); continue }
            XCTAssertFalse(t.exists(in: from - 1), "\(id) must not exist before \(from)")
            XCTAssertTrue(t.exists(in: from), "\(id) must exist from \(from)")
            XCTAssertEqual(t.status(in: from), .legal, "\(id) must start legal")
            XCTAssertNotEqual(t.status(in: constrained), .legal, "\(id) must be constrained by \(constrained)")
            XCTAssertTrue(DirtyTactics.available(in: from).contains { $0.id == id }, "\(id) must be available in \(from)")
        }
    }
}

// MARK: - 3.18.9 Era intervention mood self-check (the shape of the decade's appetite for war)
final class InterventionMoodTests: XCTestCase {
    func testMoodCurveShape() {
        let m = EraMood.interventionMood
        // Jingoist eras are cheaper than neutral; war-weary eras are dearer.
        XCTAssertLessThan(m(1905), 1.0, "imperial high tide should be below neutral")
        XCTAssertLessThan(m(1943), 1.0, "WWII total-war unity should be below neutral")
        XCTAssertGreaterThan(m(1935), 1.0, "isolationist 1930s should be above neutral")
        XCTAssertGreaterThan(m(1968), m(1943), "Vietnam must cost more than WWII")
        XCTAssertGreaterThan(m(1968), m(1905), "Vietnam must cost more than the imperial high tide")
        XCTAssertGreaterThan(m(2015), 1.0, "the forever wars should be above neutral")
    }
}

// MARK: - 3.18.10 National Intelligence Estimate self-check (uncertainty narrows with the era)
final class IntelligenceModelTests: XCTestCase {
    func testEstimateWidensInEarlierEras() {
        func width(_ year: Int) -> Int {
            let r = IntelligenceModel.range(trueValue: 50, year: year)
            return r.high - r.low
        }
        XCTAssertGreaterThan(width(1890), width(1950), "pre-satellite estimates must be fuzzier than Cold War ones")
        XCTAssertGreaterThan(width(1950), width(2000), "Cold War estimates must be fuzzier than modern ones")
        // The true value always sits inside the band.
        for year in [1890, 1944, 1958, 1985, 2020] {
            let r = IntelligenceModel.range(trueValue: 50, year: year)
            XCTAssertLessThanOrEqual(r.low, 50); XCTAssertGreaterThanOrEqual(r.high, 50)
        }
        // Modern confidence is high enough to report an exact, confirmed figure.
        XCTAssertEqual(IntelligenceModel.label(trueValue: 42, year: 2020).tag, "CONFIRMED")
        XCTAssertEqual(IntelligenceModel.label(trueValue: 42, year: 2020).text, "42")
        XCTAssertTrue(IntelligenceModel.label(trueValue: 42, year: 1890).text.contains("–"), "early eras show a range")
    }
}

// MARK: - 3.18.12 The Good Life (butter victory) self-check
final class ProsperityVictoryTests: XCTestCase {
    func testGoodLifeThresholds() {
        // All three conditions must hold.
        XCTAssertTrue(VictoryChecker.isGoodLife(qol: 80, approval: 65, militaryShare: 0.20))
        XCTAssertTrue(VictoryChecker.isGoodLife(qol: 75, approval: 60, militaryShare: 0.24), "at the exact bar")
        XCTAssertFalse(VictoryChecker.isGoodLife(qol: 74, approval: 65, militaryShare: 0.20), "QoL below bar fails")
        XCTAssertFalse(VictoryChecker.isGoodLife(qol: 80, approval: 59, militaryShare: 0.20), "approval below bar fails")
        XCTAssertFalse(VictoryChecker.isGoodLife(qol: 80, approval: 65, militaryShare: 0.25), "military share at/above 25% fails")
        // Eight years, not seven.
        XCTAssertEqual(VictoryChecker.goodLifeDays, 2922)
        XCTAssertTrue(VictoryType.prosperity.baseScore > VictoryType.economicVictory.baseScore)
    }
}

// MARK: - 3.18.14 Disaster consequences self-check (approval + funds now actually apply)
final class DisasterConsequenceTests: XCTestCase {
    func testApprovalAndFundsApplied() {
        let manager = CrisisManager()
        let crisis = CrisisEvent(type: .naturalDisaster, severity: .serious, title: "Quake", description: "d",
            affectedCountries: [], turn: 0, timeLimit: nil,
            options: [CrisisOption(title: "relief", description: "", consequences:
                CrisisConsequences(approvalChange: 10, economicImpact: -8, message: "m"), successChance: 2.0)])
        manager.presentCrisis(crisis)
        var gs = GameState(playerCountryID: "USA")
        gs.shadow.popularity = 50
        gs.shadow.aidRemaining = 20
        manager.resolveCrisis(optionIndex: 0, gameState: &gs)
        XCTAssertEqual(gs.shadow.popularity, 60, accuracy: 0.001, "FEMA relief must raise approval")
        XCTAssertEqual(gs.shadow.aidRemaining, 12, accuracy: 0.001, "relief must cost the treasury")
    }

    func testNaturalDisasterFactoryProducesChoices() {
        let manager = CrisisManager()
        let gs = GameState(playerCountryID: "USA")
        guard let c = manager.createCrisis(type: .naturalDisaster, gameState: gs) else {
            return XCTFail("disaster factory returned nil")
        }
        XCTAssertEqual(c.type, .naturalDisaster)
        XCTAssertGreaterThanOrEqual(c.options.count, 3, "relief / measured / downplay")
    }
}

// MARK: - 3.18.16 Space Force phase 1 self-check (recon satellites sharpen the NIE)
final class SpaceForceReconTests: XCTestCase {
    func testReconNarrowsTheEstimate() {
        // A recon satellite must widen confidence and tighten the band in any era.
        for year in [1960, 1985, 2020] {
            XCTAssertGreaterThan(IntelligenceModel.confidence(year: year, recon: true),
                                 IntelligenceModel.confidence(year: year, recon: false),
                                 "recon must raise confidence in \(year)")
            let wide = IntelligenceModel.range(trueValue: 50, year: year, recon: false)
            let tight = IntelligenceModel.range(trueValue: 50, year: year, recon: true)
            XCTAssertLessThanOrEqual(tight.high - tight.low, wide.high - wide.low, "recon must not widen the band in \(year)")
        }
    }

    func testLaunchAddsToConstellationAndGatesByEra() {
        let engine = GameEngine()
        engine.gameState = ScenarioLoader.makeGameState(.berlin1948)   // 1948, before the space age
        XCTAssertFalse(engine.launchSatellite(.recon), "no launch before 1957")
        engine.gameState?.turn = 0
        engine.gameState?.shadow.satellites = [:]
        // Fast-forward past the space age and give an action.
        engine.gameState = ScenarioLoader.makeGameState(.modern2025)
        let before = engine.gameState?.shadow.satellites["recon"] ?? 0
        _ = engine.launchSatellite(.recon)
        XCTAssertEqual(engine.gameState?.shadow.satellites["recon"] ?? 0, before + 1, "a modern-era launch must add a recon satellite")
    }
}

// MARK: - 3.18.17 Space Force phase 2 self-check (early-warning missile defense)
final class SpaceDefenseTests: XCTestCase {
    func testWarningSatelliteCoverage() {
        XCTAssertEqual(SpaceDefense.coverage(baseSDI: 0, warningSat: false), 0, accuracy: 0.001)
        XCTAssertEqual(SpaceDefense.coverage(baseSDI: 0, warningSat: true), SpaceDefense.warningCoverageBonus, accuracy: 0.001,
                       "early warning gives coverage even with no SDI")
        XCTAssertEqual(SpaceDefense.coverage(baseSDI: 40, warningSat: true), 40 + SpaceDefense.warningCoverageBonus, accuracy: 0.001,
                       "early warning adds on top of SDI")
        XCTAssertEqual(SpaceDefense.coverage(baseSDI: 90, warningSat: true), 100, accuracy: 0.001, "capped at 100%")
    }
}

// MARK: - 3.18.18 National Guard home-front self-check
final class NationalGuardTests: XCTestCase {
    func testHomeFrontCostRisesInCivilRightsEra() {
        let c = GuardModel.homeFrontCost
        XCTAssertLessThan(c(1890).popularity, c(1970).popularity, "19th-c. order costs less approval than Kent-State era")
        XCTAssertLessThan(c(1950).ruthlessness, c(1970).ruthlessness, "troops on citizens cost more after the civil-rights era")
        XCTAssertGreaterThan(c(2010).popularity, 0, "still has a cost in the modern era")
    }

    func testCallGuardRestoresOrderAtACost() {
        let engine = GameEngine()
        engine.gameState = ScenarioLoader.makeGameState(.modern2025)   // USA, no active disaster
        guard let pi = engine.gameState?.countries.firstIndex(where: { $0.id == "USA" }) else { return XCTFail("no USA") }
        engine.gameState?.countries[pi].stability = 50
        engine.gameState?.shadow.popularity = 60
        let approvalBefore = engine.gameState?.shadow.popularity ?? 0
        XCTAssertTrue(engine.callNationalGuard())
        XCTAssertGreaterThan(engine.gameState?.countries[pi].stability ?? 0, 50, "order restored raises stability")
        XCTAssertLessThan(engine.gameState?.shadow.popularity ?? 99, approvalBefore, "suppressing unrest costs approval in the modern era")
    }
}

// MARK: - 3.18.19 Strategic air campaign self-check
final class StrategicAirCampaignTests: XCTestCase {
    func testHeavyBomberEraGateAndWorldCost() {
        XCTAssertFalse(AirForceModel.heavyBombersAvailable(year: 1934))
        XCTAssertTrue(AirForceModel.heavyBombersAvailable(year: 1935))
        XCTAssertGreaterThan(AirForceModel.cityWorldCost(year: 1980), AirForceModel.cityWorldCost(year: 1940),
                             "area bombing costs more standing after Additional Protocol I (1977)")
    }

    func testIndustryBombingCutsEnemyGDP() {
        let engine = GameEngine()
        engine.gameState = ScenarioLoader.makeGameState(.modern2025)
        guard let gs = engine.gameState,
              let ti = gs.countries.firstIndex(where: { $0.id != "USA" && !$0.isTerritory && !$0.isDestroyed }) else { return XCTFail("no enemy") }
        let targetID = gs.countries[ti].id
        gs.countries[ti].atWarWith.insert("USA")
        if let pi = gs.countries.firstIndex(where: { $0.id == "USA" }) { gs.countries[pi].atWarWith.insert(targetID) }
        let gdpBefore = gs.countries[ti].gdp
        XCTAssertNil(engine.strategicBombingProblem(targetID), "at war in 2025 with bombers — should be orderable")
        XCTAssertTrue(engine.conductStrategicBombing(target: targetID, aim: .industry))
        XCTAssertLessThan(engine.gameState!.countries[ti].gdp, gdpBefore, "industry bombing must cut enemy GDP")
    }
}

// MARK: - Nova roast "ANOTHER" cycling self-check (clickable end-game verdict)
final class NovaRoastVariantTests: XCTestCase {
    func testVariantCyclesThroughPoolAndWrapsAround() {
        let engine = GameEngine()
        engine.gameState = ScenarioLoader.makeGameState(.modern2025)
        let gs = engine.gameState!
        let score = GameScore()
        // Election-loss shape: no victory. Each ANOTHER click bumps variant.
        let v0 = NovaCommentary.roastTemplate(gs: gs, score: score, victory: nil, variant: 0)
        let v1 = NovaCommentary.roastTemplate(gs: gs, score: score, victory: nil, variant: 1)
        let v3 = NovaCommentary.roastTemplate(gs: gs, score: score, victory: nil, variant: 3)
        XCTAssertNotEqual(v0, v1, "ANOTHER must give a different verdict")
        XCTAssertEqual(v0, v3, "pool has 3 lines — variant wraps every 3 clicks")
    }
}
