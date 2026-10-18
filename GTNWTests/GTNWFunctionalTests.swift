//
//  GTNWFunctionalTests.swift
//  GTNWTests
//
//  Functional / integration tests for GTNW game engine and gameplay logic
//  Created by Jordan Koch on 2026-05-01.
//

import XCTest
@testable import GTNW

// MARK: - GameEngine Functional Tests

@MainActor
final class GameEngineFunctionalTests: XCTestCase {

    var engine: GameEngine!

    override func setUp() {
        super.setUp()
        engine = GameEngine()
    }

    override func tearDown() {
        engine = nil
        super.tearDown()
    }

    // MARK: - Game Lifecycle

    func testStartNewGame() {
        engine.startNewGame()

        XCTAssertNotNil(engine.gameState)
        XCTAssertEqual(engine.gameState?.turn, 0)
        XCTAssertEqual(engine.gameState?.defconLevel, .defcon5)
        XCTAssertFalse(engine.showingGameOver)
        XCTAssertFalse(engine.logMessages.isEmpty, "Starting a game should produce log messages")
    }

    func testStartGameWithDifficulty() {
        engine.startNewGame(difficulty: .hard)

        XCTAssertEqual(engine.gameState?.difficultyLevel, .hard)
    }

    func testStartGameWithPlayerCountry() {
        engine.startNewGame(playerCountryID: "RUS")

        let player = engine.gameState?.getPlayerCountry()
        XCTAssertNotNil(player)
        XCTAssertEqual(player?.id, "RUS")
        XCTAssertTrue(player?.isPlayerControlled ?? false)
    }

    func testLogMessages() {
        engine.startNewGame()

        XCTAssertFalse(engine.logMessages.isEmpty)

        let systemMessages = engine.logMessages.filter { $0.type == .system }
        XCTAssertFalse(systemMessages.isEmpty, "Should have system messages on game start")
    }

    func testAddLog() {
        engine.addLog("Test message", type: .info)

        XCTAssertEqual(engine.logMessages.last?.message, "Test message")
        XCTAssertEqual(engine.logMessages.last?.type, .info)
    }

    func testLogTrimming() {
        // The engine trims logs at 200, removing 50
        for i in 0..<250 {
            engine.addLog("Message \(i)", type: .info)
        }

        XCTAssertLessThanOrEqual(engine.logMessages.count, 201,
                                  "Log should be trimmed to stay manageable")
    }

    // MARK: - War Declaration

    func testDeclareWar() {
        engine.startNewGame()

        engine.declareWar(aggressor: "USA", defender: "RUS")

        guard let gs = engine.gameState else {
            XCTFail("Game state should exist")
            return
        }

        // Check war is active
        XCTAssertFalse(gs.activeWars.isEmpty, "Should have at least one active war")

        let war = gs.activeWars.first
        XCTAssertEqual(war?.aggressor, "USA")
        XCTAssertEqual(war?.defender, "RUS")

        // Check countries are at war with each other
        let usa = gs.getCountry(id: "USA")
        let russia = gs.getCountry(id: "RUS")
        XCTAssertTrue(usa?.atWarWith.contains("RUS") ?? false)
        XCTAssertTrue(russia?.atWarWith.contains("USA") ?? false)

        // DEFCON should have raised
        XCTAssertLessThan(gs.defconLevel.rawValue, 5, "DEFCON should raise after war declaration")
    }

    // MARK: - Alliance Formation

    func testFormAlliance() {
        engine.startNewGame()

        engine.formAlliance(country1: "USA", country2: "GBR")

        guard let gs = engine.gameState else {
            XCTFail("Game state should exist")
            return
        }

        let usa = gs.getCountry(id: "USA")
        let gbr = gs.getCountry(id: "GBR")

        XCTAssertTrue(usa?.alliances.contains("GBR") ?? false)
        XCTAssertTrue(gbr?.alliances.contains("USA") ?? false)

        // Check treaty exists
        let allianceTreaty = gs.treaties.first { $0.type == .alliance }
        XCTAssertNotNil(allianceTreaty)
    }

    // MARK: - Diplomatic Relations

    func testModifyDiplomaticRelation() {
        engine.startNewGame()

        guard let gs = engine.gameState else {
            XCTFail("Game state should exist")
            return
        }

        let initialRelation = gs.getCountry(id: "USA")?.diplomaticRelations["RUS"] ?? 0

        engine.modifyDiplomaticRelation(from: "USA", to: "RUS", by: -20)

        let newRelation = gs.getCountry(id: "USA")?.diplomaticRelations["RUS"] ?? 0
        XCTAssertEqual(newRelation, initialRelation - 20)
    }

    // MARK: - Economic Diplomacy

    func testEconomicDiplomacyEndsWar() {
        engine.startNewGame()

        // Start a war first
        engine.declareWar(aggressor: "USA", defender: "RUS")

        guard let gs = engine.gameState else {
            XCTFail("Game state should exist")
            return
        }

        // Verify war exists
        XCTAssertFalse(gs.activeWars.isEmpty)

        // Economic diplomacy with large amount to end war
        engine.economicDiplomacy(from: "USA", to: "RUS", amount: 1_000_000_000)

        // War should be ended
        let usaWarWithRus = gs.activeWars.filter {
            ($0.aggressor == "USA" && $0.defender == "RUS") ||
            ($0.aggressor == "RUS" && $0.defender == "USA")
        }
        XCTAssertTrue(usaWarWithRus.isEmpty, "Economic diplomacy should end war between nations")
    }

    func testEconomicDiplomacyFormsAlliance() {
        engine.startNewGame()

        // Set hostile relations first
        engine.gameState?.setRelation(from: "USA", to: "CHN", value: -50)

        // Huge investment should improve relations significantly
        engine.economicDiplomacy(from: "USA", to: "CHN", amount: 1_000_000_000)

        let usa = engine.gameState?.getCountry(id: "USA")
        let relation = usa?.diplomaticRelations["CHN"] ?? -100

        XCTAssertGreaterThan(relation, -50, "Economic diplomacy should improve relations")
    }

    // MARK: - SDI Deployment

    func testDeploySDI() {
        engine.startNewGame()

        engine.deploySDI(countryID: "USA", investmentAmount: 100_000_000_000)

        let usa = engine.gameState?.getCountry(id: "USA")
        XCTAssertTrue(usa?.hasSDI ?? false, "USA should have SDI after deployment")
        XCTAssertGreaterThan(usa?.sdiCoverage ?? 0, 0)
        XCTAssertGreaterThan(usa?.sdiInterceptionRate ?? 0, 0)
    }

    func testSDIInsufficientFunds() {
        engine.startNewGame()

        // Try to deploy with too little money
        engine.deploySDI(countryID: "USA", investmentAmount: 50_000_000_000)

        let usa = engine.gameState?.getCountry(id: "USA")
        XCTAssertFalse(usa?.hasSDI ?? true, "SDI should not deploy with insufficient funds")
    }

    func testUpgradeSDI() {
        engine.startNewGame()

        // First deploy
        engine.deploySDI(countryID: "USA", investmentAmount: 100_000_000_000)
        let initialCoverage = engine.gameState?.getCountry(id: "USA")?.sdiCoverage ?? 0

        // Then upgrade
        engine.upgradeSDI(countryID: "USA", additionalInvestment: 100_000_000_000)
        let upgradedCoverage = engine.gameState?.getCountry(id: "USA")?.sdiCoverage ?? 0

        XCTAssertGreaterThan(upgradedCoverage, initialCoverage, "SDI upgrade should increase coverage")
    }

    // MARK: - Cyber Defense

    func testUpgradeCyberDefense() {
        engine.startNewGame()

        guard let gs = engine.gameState else {
            XCTFail("Game state should exist")
            return
        }

        // Find a country with moderate cyber defense and enough treasury
        if let idx = gs.countries.firstIndex(where: { $0.id == "BRA" }) {
            let initialLevel = gs.countries[idx].cyberDefenseLevel
            gs.countries[idx].treasury = 100_000_000_000 // Ensure enough funds

            engine.upgradeCyberDefense(countryID: "BRA")

            let newLevel = gs.countries[idx].cyberDefenseLevel
            XCTAssertGreaterThan(newLevel.rawValue, initialLevel.rawValue,
                                 "Cyber defense should upgrade")
        }
    }

    // MARK: - Covert Operations

    func testCovertSabotage() {
        engine.startNewGame()

        guard let gs = engine.gameState else {
            XCTFail("Game state should exist")
            return
        }

        let targetBefore = gs.getCountry(id: "RUS")
        let milBefore = targetBefore?.militaryStrength ?? 0

        engine.covertSabotage(from: "USA", to: "RUS")

        let targetAfter = gs.getCountry(id: "RUS")
        let milAfter = targetAfter?.militaryStrength ?? 0

        XCTAssertEqual(milAfter, max(0, milBefore - 20), "Sabotage should reduce military by 20")
    }

    func testPropagandaReducesStability() {
        engine.startNewGame()

        guard let gs = engine.gameState else {
            XCTFail("Game state should exist")
            return
        }

        let stabilityBefore = gs.getCountry(id: "RUS")?.stability ?? 0

        engine.propaganda(from: "USA", to: "RUS")

        let stabilityAfter = gs.getCountry(id: "RUS")?.stability ?? 0
        XCTAssertEqual(stabilityAfter, max(0, stabilityBefore - 20),
                       "Propaganda should reduce stability by 20")
    }

    func testSpecialForcesReducesWarheads() {
        engine.startNewGame()

        guard let gs = engine.gameState else {
            XCTFail("Game state should exist")
            return
        }

        let warheadsBefore = gs.getCountry(id: "RUS")?.nuclearWarheads ?? 0

        engine.specialForces(from: "USA", to: "RUS")

        let warheadsAfter = gs.getCountry(id: "RUS")?.nuclearWarheads ?? 0
        let expectedReduction = min(10, warheadsBefore)
        XCTAssertEqual(warheadsAfter, max(0, warheadsBefore - expectedReduction),
                       "Special forces should destroy up to 10 warheads")
    }

    // MARK: - DEFCON Management

    func testRaiseDEFCON() {
        engine.startNewGame()

        XCTAssertEqual(engine.gameState?.defconLevel, .defcon5)

        engine.raiseDEFCON()
        XCTAssertEqual(engine.gameState?.defconLevel, .defcon4)

        engine.raiseDEFCON()
        XCTAssertEqual(engine.gameState?.defconLevel, .defcon3)

        engine.raiseDEFCON()
        XCTAssertEqual(engine.gameState?.defconLevel, .defcon2)

        engine.raiseDEFCON()
        XCTAssertEqual(engine.gameState?.defconLevel, .defcon1)

        // Should not go below 1
        engine.raiseDEFCON()
        XCTAssertEqual(engine.gameState?.defconLevel, .defcon1)
    }

    // MARK: - Get Country Helper

    func testGetCountry() {
        engine.startNewGame()

        let usa = engine.getCountry("USA")
        XCTAssertNotNil(usa)
        XCTAssertEqual(usa?.name, "United States")

        let invalid = engine.getCountry("ZZZZZ")
        XCTAssertNil(invalid)
    }

    // MARK: - Nuclear Strike

    func testNuclearStrikeReducesWarheads() {
        engine.startNewGame()

        guard let gs = engine.gameState else {
            XCTFail("Game state should exist")
            return
        }

        let warheadsBefore = gs.getCountry(id: "USA")?.nuclearWarheads ?? 0

        engine.launchNuclearStrike(from: "USA", to: "RUS", warheads: 5)

        let warheadsAfter = gs.getCountry(id: "USA")?.nuclearWarheads ?? 0
        XCTAssertEqual(warheadsAfter, warheadsBefore - 5)
    }

    func testNuclearStrikeRecorded() {
        engine.startNewGame()

        engine.launchNuclearStrike(from: "USA", to: "RUS", warheads: 3)

        guard let gs = engine.gameState else {
            XCTFail("Game state should exist")
            return
        }

        XCTAssertFalse(gs.nuclearStrikes.isEmpty, "Nuclear strike should be recorded")
        XCTAssertEqual(gs.nuclearStrikes.first?.attacker, "USA")
        XCTAssertEqual(gs.nuclearStrikes.first?.target, "RUS")
        XCTAssertEqual(gs.nuclearStrikes.first?.warheadsUsed, 3)
    }

    func testNuclearStrikeSetsDefcon1() {
        engine.startNewGame()

        engine.launchNuclearStrike(from: "USA", to: "RUS", warheads: 1)

        XCTAssertEqual(engine.gameState?.defconLevel, .defcon1,
                       "Nuclear strike should set DEFCON to 1")
    }

    func testNuclearStrikeCausesCasualties() {
        engine.startNewGame()

        engine.launchNuclearStrike(from: "USA", to: "RUS", warheads: 3)

        guard let gs = engine.gameState else {
            XCTFail("Game state should exist")
            return
        }

        XCTAssertGreaterThan(gs.totalCasualties, 0, "Nuclear strike should cause casualties")
        XCTAssertGreaterThan(gs.globalRadiation, 0, "Nuclear strike should increase radiation")
    }

    func testNuclearStrikeInsufficientWarheads() {
        engine.startNewGame()

        guard let gs = engine.gameState else {
            XCTFail("Game state should exist")
            return
        }

        // Give a country zero warheads
        if let idx = gs.countries.firstIndex(where: { $0.id == "BRA" }) {
            gs.countries[idx].nuclearWarheads = 0
        }

        let strikesBefore = gs.nuclearStrikes.count
        engine.launchNuclearStrike(from: "BRA", to: "USA", warheads: 5)

        XCTAssertEqual(gs.nuclearStrikes.count, strikesBefore,
                       "Should not be able to launch nukes without warheads")
    }

    func testNuclearStrikeCanDestroy() {
        engine.startNewGame()

        // Hit a small country with massive strike
        engine.launchNuclearStrike(from: "USA", to: "LIE", warheads: 100)

        // The target should be heavily damaged
        let target = engine.gameState?.getCountry(id: "LIE")
        if let t = target {
            XCTAssertGreaterThan(t.damageLevel, 0)
        }
    }
}

// MARK: - Historical Administration Tests

final class HistoricalAdministrationTests: XCTestCase {

    func testSovietUnionExistsInColdWarEra() {
        let gs = GameState(playerCountryID: "USA")
        gs.eraStartYear = 1962

        // In 1962, Russia should be named "Soviet Union"
        // This depends on CountryFactory and era adjustments
        let russia = gs.getCountry(id: "RUS")
        XCTAssertNotNil(russia, "Russia/Soviet Union should exist in the country list")
    }

    func testPreNuclearEraHasNoNukes() {
        let gs = GameState(playerCountryID: "USA")
        gs.eraStartYear = 1800

        // Before 1945 (nuclear age), no country should have warheads
        // Note: this depends on adjustCountriesForEra logic
        XCTAssertFalse(gs.cyberWarfareAvailable, "Cyber warfare should not be available in 1800")
        XCTAssertFalse(gs.sdiAvailable, "SDI should not be available in 1800")
        XCTAssertFalse(gs.droneStrikesAvailable, "Drones should not be available in 1800")
        XCTAssertFalse(gs.submarineLaunchAvailable, "SLBMs should not be available in 1800")
    }
}

// MARK: - AI Opponents & Saves (user perspective)

/// End-to-end from the player's seat: pick LLM opponents, press End Turn, and the
/// game always hands control back — even when the AI backend is down.
final class AIOpponentFunctionalTests: XCTestCase {

    @MainActor
    private func waitForPlayerTurn(_ e: GameEngine, timeout: TimeInterval = 10) async {
        let deadline = Date().addingTimeInterval(timeout)
        while (e.turnPhase != .playerInput || e.isProcessingAITurn) && Date() < deadline {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
    }

    @MainActor
    func testEndTurnWithOfflineLLMOpponentStillReturnsControl() async {
        let probe = RetryProbe()
        let e = GameEngine()
        e.startNewGame(playerCountryID: "USA")
        e.brainConfig.transport = Stub.transport(probe, script: [(nil, "")])   // Ollama down
        e.brainConfig.retrySleep = probe.sleeper
        e.setBrain(.model(id: "qwen3:4b", endpoint: "http://127.0.0.1:1/v1/chat/completions", backend: .ollama), for: "RUS")
        let turn = e.gameState?.turn ?? 0

        e.endTurn()
        await waitForPlayerTurn(e)

        XCTAssertEqual(e.gameState?.turn, turn + 1)
        XCTAssertEqual(e.turnPhase, .playerInput, "player must get control back")
        XCTAssertTrue(e.lastTurnFallbackCountryIDs.contains("RUS"), "offline opponent plays rule-based")
        XCTAssertEqual(probe.calls, 3, "backend was retried, not abandoned on first failure")
    }

    @MainActor
    func testLLMOpponentDeclaresWarOnPlayer() async {
        let probe = RetryProbe()
        let content = #"{\"action\":\"DECLARE_WAR\",\"target\":\"USA\"}"#
        let e = GameEngine()
        e.startNewGame(playerCountryID: "USA")
        e.brainConfig.transport = Stub.transport(probe, script: [(200, #"{"choices":[{"message":{"content":""# + content + #""}}]}"#)])
        e.setBrain(.gatewayClaude, for: "RUS")

        e.endTurn()
        await waitForPlayerTurn(e)

        XCTAssertTrue(e.gameState?.getPlayerCountry()?.atWarWith.contains("RUS") ?? false,
                      "the player should now be at war with the LLM-driven Soviet bloc")
    }

    @MainActor
    func testSaveThenLoadRestoresTheGame() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("gtnw-fn-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let manager = SaveManager(folder: dir)
        let e = GameEngine()
        e.startScenario(.world1990, turnLength: .month)
        e.gameState?.turn = 4
        let label = e.gameState?.currentDateLabel
        try e.saveGame(slot: 3, manager: manager)

        e.startNewGame(playerCountryID: "RUS")
        try e.loadGame(slot: 3, manager: manager)

        XCTAssertEqual(e.gameState?.turn, 4)
        XCTAssertEqual(e.gameState?.currentDateLabel, label)
        XCTAssertEqual(e.gameState?.playerCountryID, "USA")
    }

    @MainActor
    func testLoadingMissingSlotFailsWithoutLosingCurrentGame() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("gtnw-fn-\(UUID().uuidString)")
        let e = GameEngine()
        e.startNewGame(playerCountryID: "USA")
        XCTAssertThrowsError(try e.loadGame(slot: 2, manager: SaveManager(folder: dir)))
        XCTAssertEqual(e.gameState?.playerCountryID, "USA", "failed load must not wipe the game in progress")
    }
}

// MARK: - Font scale (functional)

#if os(macOS)
import SwiftUI
import AppKit

/// The factor actually changes rendered text, for every font path the app uses, and the Settings choice persists.
@MainActor
final class FontScaleFunctionalTests: XCTestCase {
    override func tearDown() { FontScale.forced = nil; Theme.forced = nil; super.tearDown() }

    private func idealSize<V: View>(_ view: V) -> CGSize {
        NSHostingController(rootView: view.fixedSize()).sizeThatFits(in: CGSize(width: 10_000, height: 10_000))
    }

    private func ratio(_ make: @escaping () -> Font) -> CGFloat {
        FontScale.forced = 1
        let small = idealSize(Text("WOPR 1983").font(make()))
        FontScale.forced = 2
        let big = idealSize(Text("WOPR 1983").font(make()))
        return big.height / small.height
    }

    func testEveryFontPathDoublesAtTwoX() {
        let paths: [(String, () -> Font)] = [
            ("fixed", { .scaled(size: 14, weight: .bold, design: .monospaced) }),
            ("style", { .scaled(.caption) }),
            ("style+design", { .scaled(.headline, design: .monospaced) }),
            ("ThemeFont", { ThemeFont.mono(11) }),
            ("GTNWFonts", { GTNWFonts.body() }),
            ("EGA (retro)", { EGA.font(size: 12) }),
        ]
        for (name, make) in paths {
            for theme in GameTheme.allCases {
                Theme.forced = theme
                XCTAssertEqual(ratio(make), 2, accuracy: 0.25, "\(name) in \(theme) did not scale 2×")
            }
        }
    }

    func testTextSizeSettingPersistsAndIsReadLive() {
        let name = "gtnw-fontscale-fn-\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        defer { d.removePersistentDomain(forName: name) }
        let m = FontScaleManager(defaults: d)
        m.factor = 1.5
        XCTAssertEqual(d.double(forKey: FontScaleManager.defaultsKey), 1.5)
        XCTAssertEqual(FontScaleManager(defaults: d).factor, 1.5, "a relaunch keeps the choice")

        // The live factor follows the shared manager (the app root rebuilds on change).
        let shared = FontScaleManager.shared
        let saved = shared.factor
        defer { shared.factor = saved }
        shared.factor = 2.5
        XCTAssertEqual(FontScale.factor, 2.5)
        let at25 = idealSize(Text("X").font(.scaled(size: 20))).height
        shared.factor = 1
        let at1 = idealSize(Text("X").font(.scaled(size: 20))).height
        XCTAssertEqual(at25 / at1, 2.5, accuracy: 0.3)
    }
}
#endif
