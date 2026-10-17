//
//  GTNWIntegrationTests.swift
//  GTNWTests
//
//  // MARK: - Integration
//  Components working together: GameEngine → BrainClient → HTTP transport
//  (stubbed) → MoveResponse → applyMove → GameState; live-session bus; save
//  manager ↔ engine. No real network, no real saves (temp folders only).
//
//  Created by Jordan Koch on 2026.
//

import XCTest
@testable import GTNW

final class BrainPipelineIntegrationTests: XCTestCase {

    @MainActor
    private func engine(retry: RetryPolicy = .network, probe: RetryProbe, transport: @escaping HTTPTransport) -> GameEngine {
        let e = GameEngine()
        e.startNewGame(playerCountryID: "USA")
        e.brainConfig.transport = transport
        e.brainConfig.retryPolicy = retry
        e.brainConfig.retrySleep = probe.sleeper
        e.brainConfig.modelTimeout = 5
        e.brainConfig.gatewayTimeout = 5
        e.brainConfig.liveSessionTimeout = 2
        e.brainConfig.liveSessionPollInterval = 0.1
        return e
    }

    private static func chat(_ json: String) -> String {
        let escaped = json.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        return #"{"choices":[{"message":{"content":""# + escaped + #""}}]}"#
    }

    @MainActor
    func testLLMMoveFlowsThroughToGameState() async throws {
        let probe = RetryProbe()
        let body = Self.chat(#"{"action":"DECLARE_WAR","target":"CHN","rationale":"test"}"#)
        let e = engine(probe: probe, transport: Stub.transport(probe, script: [(200, body)]))
        e.setBrain(.model(id: "qwen3:4b", endpoint: "http://127.0.0.1:1/v1/chat/completions", backend: .ollama), for: "RUS")

        await e.processAITurnsWithBrains()

        let rus = try XCTUnwrap(e.gameState?.getCountry(id: "RUS"))
        XCTAssertTrue(rus.atWarWith.contains("CHN"), "LLM's DECLARE_WAR should land in game state")
        XCTAssertFalse(e.lastTurnFallbackCountryIDs.contains("RUS"))
        XCTAssertEqual(probe.calls, 1)
    }

    @MainActor
    func testTransientFailureIsRetriedAndMoveStillApplied() async throws {
        let probe = RetryProbe()
        let body = Self.chat(#"{"action":"DECLARE_WAR","target":"CHN"}"#)
        let e = engine(probe: probe, transport: Stub.transport(probe, script: [(nil, ""), (503, ""), (200, body)]))
        e.setBrain(.gatewayClaude, for: "RUS")

        await e.processAITurnsWithBrains()

        XCTAssertTrue(e.gameState?.getCountry(id: "RUS")?.atWarWith.contains("CHN") ?? false)
        XCTAssertFalse(e.lastTurnFallbackCountryIDs.contains("RUS"))
        XCTAssertEqual(probe.calls, 3)
    }

    @MainActor
    func testPersistentFailureFallsBackToRuleBasedAfterRetries() async {
        let probe = RetryProbe()
        let e = engine(probe: probe, transport: Stub.transport(probe, script: [(nil, "")]))
        e.setBrain(.gatewayClaude, for: "RUS")

        await e.processAITurnsWithBrains()

        XCTAssertTrue(e.lastTurnFallbackCountryIDs.contains("RUS"))
        XCTAssertEqual(probe.calls, RetryPolicy.network.maxAttempts, "retried before falling back")
    }

    @MainActor
    func testIllegalLLMMoveFallsBack() async {
        let probe = RetryProbe()
        let body = Self.chat(#"{"action":"LAUNCH_EVERYTHING","target":"MARS"}"#)
        let e = engine(probe: probe, transport: Stub.transport(probe, script: [(200, body)]))
        e.setBrain(.gatewayClaude, for: "RUS")

        await e.processAITurnsWithBrains()

        XCTAssertTrue(e.lastTurnFallbackCountryIDs.contains("RUS"))
    }

    @MainActor
    func testLiveSessionPostThenPollAnswer() async throws {
        let probe = RetryProbe()
        let posted = RetryProbe()
        let answer = #"{"action":"DECLARE_WAR","target":"CHN"}"#
        let transport: HTTPTransport = { req in
            probe.hit()
            if req.httpMethod == "POST" {
                // First POST drops, retry succeeds.
                if posted.hit() == 1 { throw URLError(.networkConnectionLost) }
                return (Data(), Stub.response(202))
            }
            XCTAssertTrue(req.url?.path.contains("/move/") ?? false)
            return (Data(answer.utf8), Stub.response(200))
        }
        let e = engine(probe: probe, transport: transport)
        e.setBrain(.liveSession, for: "RUS")

        await e.processAITurnsWithBrains()

        XCTAssertEqual(posted.calls, 2)
        XCTAssertTrue(e.gameState?.getCountry(id: "RUS")?.atWarWith.contains("CHN") ?? false)
    }

    @MainActor
    func testMixedBrainsInOneTurn() async {
        let probe = RetryProbe()
        let body = Self.chat(#"{"action":"WAIT"}"#)
        let e = engine(probe: probe, transport: Stub.transport(probe, script: [(200, body)]))
        e.setBrain(.gatewayClaude, for: "RUS")
        e.setBrain(.model(id: "m", endpoint: "http://127.0.0.1:1/v1", backend: .ollama), for: "CHN")
        e.setBrain(.human, for: "GBR")

        await e.processAITurnsWithBrains()

        XCTAssertEqual(probe.calls, 2, "exactly the two remote brains are consulted")
        XCTAssertTrue(e.lastTurnFallbackCountryIDs.isEmpty)
    }

    @MainActor
    func testMoveRequestContractRoundTripsAsJSON() throws {
        let e = GameEngine()
        e.startNewGame(playerCountryID: "USA")
        let req = try XCTUnwrap(e.buildMoveRequest(for: "RUS"))
        let back = try JSONDecoder().decode(MoveRequest.self, from: JSONEncoder().encode(req))
        XCTAssertEqual(back, req)
        XCTAssertTrue(back.legalActions.contains("WAIT"))
    }
}

final class PersistenceIntegrationTests: XCTestCase {

    @MainActor
    func testSaveLoadThenContinuePlaying() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("gtnw-int-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let manager = SaveManager(folder: dir)

        let e = GameEngine()
        e.startScenario(.world1990, turnLength: .month)
        let gs = try XCTUnwrap(e.gameState)
        gs.turn += 1; e.processShadowTurn()
        try manager.save(gs, slot: 1)

        let loaded = try manager.load(slot: 1)
        let e2 = GameEngine()
        e2.gameState = loaded
        XCTAssertEqual(loaded.turn, gs.turn)
        XCTAssertEqual(loaded.countries.count, gs.countries.count)
        e2.endTurn()
        XCTAssertEqual(e2.gameState?.turn, gs.turn + 1, "a loaded game must keep playing")
    }

    @MainActor
    func testAutosaveWritesSlotZeroOnEndTurn() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("gtnw-auto-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let e = GameEngine()
        e.autosaveManager = SaveManager(folder: dir)
        e.startNewGame(playerCountryID: "USA")
        e.endTurn()
        XCTAssertTrue(FileManager.default.fileExists(atPath: SaveManager(folder: dir).url(slot: 0).path))
    }
}
