//
//  GTNWPerformanceTests.swift
//  GTNWTests
//
//  // MARK: - Performance
//  Response-time, throughput and boundedness checks. Uses plain Date() timing
//  with generous thresholds (no measure{} — symbolication on this machine
//  triggers a TCC prompt that hangs the test host). No network: remote brains
//  use stub transports.
//
//  Created by Jordan Koch on 2026.
//

import XCTest
@testable import GTNW

final class GTNWPerformanceTests: XCTestCase {

    private func time(_ block: () throws -> Void) rethrows -> TimeInterval {
        let start = Date()
        try block()
        return Date().timeIntervalSince(start)
    }

    @MainActor
    private func startedEngine() -> GameEngine {
        let e = GameEngine()
        e.startNewGame(playerCountryID: "USA")
        return e
    }

    // MARK: Startup & turn throughput

    @MainActor
    func testNewGameStartsQuickly() {
        let t = time { _ = startedEngine() }
        XCTAssertLessThan(t, 3.0, "new game took \(t)s")
    }

    @MainActor
    func testScenarioStartIsFast() {
        let e = GameEngine()
        let t = time { e.startScenario(.world1990, turnLength: .month) }
        XCTAssertNotNil(e.gameState)
        XCTAssertLessThan(t, 3.0, "scenario start took \(t)s")
    }

    @MainActor
    func testTwentyTurnsCompleteWithinBudget() {
        let e = startedEngine()
        let t = time { for _ in 0..<20 { e.endTurn() } }
        XCTAssertLessThan(t, 20.0, "20 turns took \(t)s (\(t / 20)s per turn)")
    }

    @MainActor
    func testShadowTurnThroughput() throws {
        let e = GameEngine()
        e.startScenario(.world1990, turnLength: .week)
        let gs = try XCTUnwrap(e.gameState)
        let t = time { for _ in 0..<50 { gs.turn += 1; e.processShadowTurn() } }
        XCTAssertLessThan(t, 10.0, "50 shadow turns took \(t)s")
    }

    // MARK: No N+1 / serial LLM calls

    /// Every country on a remote brain whose answer takes 300ms. The old loop was
    /// serial (~N × latency); the brain loop must run them concurrently.
    @MainActor
    func testRemoteBrainsRunConcurrentlyNotSerially() async throws {
        let e = startedEngine()
        let gs = try XCTUnwrap(e.gameState)
        let ids = gs.countries.filter { !$0.isPlayerControlled && !$0.isDestroyed }.prefix(30).map(\.id)
        XCTAssertGreaterThanOrEqual(ids.count, 10)
        for id in ids { e.setBrain(.gatewayClaude, for: id) }
        e.brainTransportOverride = { _, _ in
            try? await Task.sleep(nanoseconds: 300_000_000)
            return MoveResponse(action: "WAIT")
        }
        let start = Date()
        await e.processAITurnsWithBrains()
        let t = Date().timeIntervalSince(start)
        XCTAssertLessThan(t, Double(ids.count) * 0.3 / 3, "\(ids.count) brains took \(t)s — calls look serial")
        XCTAssertTrue(e.lastTurnFallbackCountryIDs.isDisjoint(with: Set(ids)))
    }

    /// A hung backend must not hang the turn: the brain timeout bounds it.
    @MainActor
    func testHungBackendIsBoundedByTimeout() async throws {
        let e = startedEngine()
        e.setBrain(.model(id: "m", endpoint: "http://127.0.0.1:1/v1", backend: .ollama), for: "RUS")
        e.brainConfig.modelTimeout = 0.5
        e.brainConfig.transport = { _ in
            try await Task.sleep(nanoseconds: 30_000_000_000)
            throw URLError(.timedOut)
        }
        let start = Date()
        await e.processAITurnsWithBrains()
        let t = Date().timeIntervalSince(start)
        XCTAssertLessThan(t, 5.0, "hung backend held the turn for \(t)s")
        XCTAssertTrue(e.lastTurnFallbackCountryIDs.contains("RUS"))
    }

    func testRetryWorstCaseBackoffIsBounded() {
        XCTAssertLessThanOrEqual(RetryPolicy.network.worstCaseSleep, 5.0)
        XCTAssertLessThanOrEqual(RetryPolicy.subprocess.worstCaseSleep, 2.0)
        let silly = RetryPolicy(maxAttempts: 100, baseDelay: 1, multiplier: 10, maxDelay: 2)
        XCTAssertLessThanOrEqual(silly.delay(afterAttempt: 99), 2.0, "maxDelay caps runaway growth")
    }

    // MARK: Serialization & persistence

    @MainActor
    func testGameStateEncodeDecodeThroughput() throws {
        let e = startedEngine()
        let gs = try XCTUnwrap(e.gameState)
        var bytes = 0
        let t = try time {
            for _ in 0..<20 {
                let data = try JSONEncoder().encode(gs)
                bytes = data.count
                _ = try JSONDecoder().decode(GameState.self, from: data)
            }
        }
        XCTAssertLessThan(t, 10.0, "20 save/load round-trips took \(t)s")
        XCTAssertLessThan(bytes, 20_000_000, "save file unexpectedly large: \(bytes) bytes")
    }

    @MainActor
    func testSaveSlotsWriteAndReadQuickly() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("gtnw-perf-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let manager = SaveManager(folder: dir)
        let gs = try XCTUnwrap(startedEngine().gameState)
        let t = try time {
            for slot in 1...SaveManager.slotCount {
                try manager.save(gs, slot: slot)
                _ = try manager.load(slot: slot)
            }
        }
        XCTAssertLessThan(t, 10.0)
        XCTAssertEqual(manager.list().count, SaveManager.slotCount)
    }

    // MARK: Lookups & bounded memory

    @MainActor
    func testCountryLookupIsFast() throws {
        let gs = try XCTUnwrap(startedEngine().gameState)
        let ids = gs.countries.map(\.id)
        let t = time { for i in 0..<20_000 { _ = gs.getCountry(id: ids[i % ids.count]) } }
        XCTAssertLessThan(t, 3.0, "20k lookups took \(t)s")
    }

    @MainActor
    func testBuildMoveRequestsForEveryCountry() throws {
        let e = startedEngine()
        let gs = try XCTUnwrap(e.gameState)
        var n = 0
        let t = time { for c in gs.countries where !c.isDestroyed { if e.buildMoveRequest(for: c.id) != nil { n += 1 } } }
        XCTAssertGreaterThan(n, 0)
        XCTAssertLessThan(t, 3.0, "building \(n) move requests took \(t)s")
    }

    @MainActor
    func testEventLogIsBoundedUnderLoad() {
        let e = GameEngine()
        let t = time { for i in 0..<10_000 { e.addLog("msg \(i)", type: .info) } }
        XCTAssertLessThanOrEqual(e.logMessages.count, 201, "log must stay bounded (memory)")
        XCTAssertLessThan(t, 5.0)
    }

    @MainActor
    func testWorldStateSummaryStaysPromptSized() throws {
        let e = startedEngine()
        let req = try XCTUnwrap(e.buildMoveRequest(for: "RUS"))
        XCTAssertLessThan(req.worldStateSummary.count, 8_000, "prompt context must stay small for local LLMs")
    }
}
