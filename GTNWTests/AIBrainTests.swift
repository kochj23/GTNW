//
//  AIBrainTests.swift
//  GTNWTests
//
//  Network-free tests for the "brain per country" system and the new
//  reversible agency verbs.
//
//  Created by Jordan Koch on 2026.
//

import XCTest
@testable import GTNW

final class AIBrainTests: XCTestCase {

    @MainActor
    private func makeEngine(player: String = "USA") -> GameEngine {
        let e = GameEngine()
        e.startNewGame(playerCountryID: player)
        return e
    }

    // MARK: - buildMoveRequest

    @MainActor
    func testBuildMoveRequestLegalActionsAndSummary() {
        let e = makeEngine()
        guard let req = e.buildMoveRequest(for: "RUS") else { return XCTFail("no request") }
        XCTAssertEqual(req.countryId, "RUS")
        XCTAssertEqual(req.year, e.gameState?.currentYear)
        XCTAssertEqual(req.defcon, 5)
        XCTAssertTrue(req.legalActions.contains("DECLARE_WAR"))
        XCTAssertTrue(req.legalActions.contains("LAUNCH_NUKE"), "RUS has warheads")
        XCTAssertTrue(req.legalActions.contains("BUILD_NUKES"), "2025 is nuclear age")
        XCTAssertFalse(req.legalActions.contains("SUE_FOR_PEACE"), "not at war")
        XCTAssertFalse(req.worldStateSummary.isEmpty)
    }

    @MainActor
    func testNonNuclearCountryHasNoLaunchOption() {
        let e = makeEngine()
        guard let gs = e.gameState,
              let nonNuke = gs.countries.first(where: { $0.nuclearWarheads == 0 && !$0.isDestroyed && $0.id != "USA" }),
              let req = e.buildMoveRequest(for: nonNuke.id) else { return XCTFail() }
        XCTAssertFalse(req.legalActions.contains("LAUNCH_NUKE"))
        XCTAssertFalse(req.legalActions.contains("THREATEN_NUKE"))
    }

    // MARK: - applyMove maps to the right verb

    @MainActor
    func testApplyMoveDeclareWar() {
        let e = makeEngine()
        XCTAssertEqual(e.applyMove(MoveResponse(action: "DECLARE_WAR", target: "CHN"), for: "RUS"),
                       .applied("DECLARE_WAR"))
        XCTAssertTrue(e.gameState!.getCountry(id: "RUS")!.atWarWith.contains("CHN"))
    }

    @MainActor
    func testApplyMoveFormAllianceAndImproveRelations() {
        let e = makeEngine()
        XCTAssertEqual(e.applyMove(MoveResponse(action: "FORM_ALLIANCE", target: "GBR"), for: "FRA"),
                       .applied("FORM_ALLIANCE"))
        XCTAssertTrue(e.gameState!.getCountry(id: "FRA")!.alliances.contains("GBR"))

        let before = e.gameState!.getCountry(id: "FRA")!.diplomaticRelations["IND"] ?? 0
        XCTAssertEqual(e.applyMove(MoveResponse(action: "IMPROVE_RELATIONS", target: "IND"), for: "FRA"),
                       .applied("IMPROVE_RELATIONS"))
        let after = e.gameState!.getCountry(id: "FRA")!.diplomaticRelations["IND"] ?? 0
        XCTAssertGreaterThan(after, before)
    }

    @MainActor
    func testApplyMoveBuildNukes() {
        let e = makeEngine()
        let before = e.gameState!.getCountry(id: "CHN")!.nuclearWarheads
        XCTAssertEqual(e.applyMove(MoveResponse(action: "BUILD_NUKES"), for: "CHN"), .applied("BUILD_NUKES"))
        XCTAssertEqual(e.gameState!.getCountry(id: "CHN")!.nuclearWarheads, before + 5)
    }

    @MainActor
    func testApplyMoveLaunchNukeRecordsStrike() {
        let e = makeEngine()
        let r = MoveResponse(action: "LAUNCH_NUKE", target: "CHN", params: ["warheads": 2])
        XCTAssertEqual(e.applyMove(r, for: "RUS"), .applied("LAUNCH_NUKE"))
        XCTAssertFalse(e.gameState!.nuclearStrikes.isEmpty)
    }

    @MainActor
    func testApplyMoveWaitIsNoOp() {
        let e = makeEngine()
        XCTAssertEqual(e.applyMove(MoveResponse(action: "WAIT"), for: "RUS"), .noOp)
    }

    @MainActor
    func testApplyMoveRejectsIllegal() {
        let e = makeEngine()
        // Unknown verb
        XCTAssertEqual(e.applyMove(MoveResponse(action: "NUKE_THE_MOON"), for: "RUS"), .rejectedIllegal)
        // LAUNCH_NUKE from a country with no warheads is not a legal action
        guard let gs = e.gameState,
              let nonNuke = gs.countries.first(where: { $0.nuclearWarheads == 0 && !$0.isDestroyed && $0.id != "USA" }) else { return XCTFail() }
        XCTAssertEqual(e.applyMove(MoveResponse(action: "LAUNCH_NUKE", target: "USA"), for: nonNuke.id), .rejectedIllegal)
        // Target-requiring verb with missing / bad target
        XCTAssertEqual(e.applyMove(MoveResponse(action: "DECLARE_WAR", target: nil), for: "RUS"), .rejectedIllegal)
        XCTAssertEqual(e.applyMove(MoveResponse(action: "DECLARE_WAR", target: "ZZZ"), for: "RUS"), .rejectedIllegal)
    }

    // MARK: - Brain assignment default + round-trip

    @MainActor
    func testBrainDefaultsAndAssignmentRoundTrip() {
        let e = makeEngine(player: "USA")
        XCTAssertEqual(e.brain(for: "USA"), .human, "player is human")
        XCTAssertEqual(e.brain(for: "RUS"), .ruleBased, "unassigned defaults to rule-based")
        e.setBrain(.gatewayClaude, for: "RUS")
        XCTAssertEqual(e.brain(for: "RUS"), .gatewayClaude)
        let m = AIBrain.model(id: "qwen3:4b", endpoint: "http://localhost:11434/v1/chat/completions", backend: .ollama)
        e.setBrain(m, for: "CHN")
        XCTAssertEqual(e.brain(for: "CHN"), m)
    }

    func testBrainCodableRoundTrip() throws {
        let brains: [AIBrain] = [
            .human, .ruleBased, .liveSession, .gatewayClaude,
            .model(id: "x", endpoint: "http://y", backend: .openRouter)
        ]
        for b in brains {
            let data = try JSONEncoder().encode(b)
            XCTAssertEqual(try JSONDecoder().decode(AIBrain.self, from: data), b)
        }
    }

    // MARK: - Timeout → fallback

    func testWithMoveTimeoutReturnsNilWhenSlow() async {
        let start = Date()
        let result = await withMoveTimeout(0.3) {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            return MoveResponse(action: "WAIT")
        }
        XCTAssertNil(result)
        XCTAssertLessThan(Date().timeIntervalSince(start), 2.0, "must time out fast, not wait 5s")
    }

    func testWithMoveTimeoutReturnsValueWhenFast() async {
        let result = await withMoveTimeout(2.0) {
            MoveResponse(action: "DECLARE_WAR", target: "CHN")
        }
        XCTAssertEqual(result?.action, "DECLARE_WAR")
    }

    @MainActor
    func testLiveSessionTimeoutFallsBackToRuleBased() async {
        let e = makeEngine(player: "USA")
        e.setBrain(.liveSession, for: "RUS")
        // Simulate "no live session answered" — the transport yields nil.
        e.brainTransportOverride = { _, _ in nil }
        await e.processAITurnsWithBrains()
        XCTAssertTrue(e.lastTurnFallbackCountryIDs.contains("RUS"),
                      "RUS should fall back to rule-based when its session doesn't answer")
    }

    // MARK: - parseOllamaTags

    func testParseOllamaTags() {
        let body = #"{"models":[{"name":"qwen3:4b","size":2600000000},{"name":"llama3:8b","size":4700000000}]}"#.data(using: .utf8)!
        let models = ModelRegistry.parseOllamaTags(body)
        XCTAssertEqual(models.count, 2)
        XCTAssertEqual(models.first?.name, "qwen3:4b")
        XCTAssertEqual(ModelRegistry.parseOllamaTags(Data()), [])
        XCTAssertEqual(ModelRegistry.parseOllamaTags("garbage".data(using: .utf8)!), [])
        XCTAssertEqual(ModelRegistry.parseOllamaTags("{}".data(using: .utf8)!), [])
    }

    // MARK: - MoveResponse decoding (incl. malformed)

    func testMoveResponseDecoding() {
        let good = #"{"action":"DECLARE_WAR","target":"CHN","params":{"warheads":3},"rationale":"x"}"#.data(using: .utf8)!
        let r = MoveResponse.decode(from: good)
        XCTAssertEqual(r?.action, "DECLARE_WAR")
        XCTAssertEqual(r?.target, "CHN")
        XCTAssertEqual(r?.params?["warheads"], 3)

        let wrapped = "Sure! Here is my move:\n```json\n{\"action\":\"WAIT\"}\n```\nGood luck."
        XCTAssertEqual(MoveResponse.decode(fromText: wrapped)?.action, "WAIT")

        XCTAssertNil(MoveResponse.decode(from: "not json".data(using: .utf8)!))
        XCTAssertNil(MoveResponse.decode(from: #"{"target":"CHN"}"#.data(using: .utf8)!), "no action field")
    }

    // MARK: - New reversible verbs

    @MainActor
    func testSueForPeaceClearsWars() {
        // Use two non-bloc nations so NATO/Warsaw collective defense doesn't
        // spawn extra wars — isolates the sue-for-peace clearing behavior.
        let e = makeEngine()
        e.declareWar(aggressor: "BRA", defender: "ARG")
        XCTAssertTrue(e.gameState!.getCountry(id: "BRA")!.atWarWith.contains("ARG"))
        XCTAssertTrue(e.sueForPeace(from: "BRA", to: "ARG"))
        XCTAssertFalse(e.gameState!.getCountry(id: "BRA")!.atWarWith.contains("ARG"))
        XCTAssertFalse(e.gameState!.getCountry(id: "ARG")!.atWarWith.contains("BRA"))
        // No BRA↔ARG war remains in the active list.
        XCTAssertFalse(e.gameState!.activeWars.contains {
            ($0.aggressor == "BRA" && $0.defender == "ARG") ||
            ($0.aggressor == "ARG" && $0.defender == "BRA")
        })
    }

    @MainActor
    func testLeaveAllianceMutatesAndBumpsStat() {
        let e = makeEngine()
        e.formAlliance(country1: "USA", country2: "GBR")
        XCTAssertTrue(e.gameState!.getCountry(id: "USA")!.alliances.contains("GBR"))
        let before = e.gameState!.alliancesBroken
        XCTAssertTrue(e.leaveAlliance(country: "USA", from: "GBR"))
        XCTAssertFalse(e.gameState!.getCountry(id: "USA")!.alliances.contains("GBR"))
        XCTAssertFalse(e.gameState!.getCountry(id: "GBR")!.alliances.contains("USA"))
        XCTAssertEqual(e.gameState!.alliancesBroken, before + 1)
    }

    @MainActor
    func testLeaveAllianceFailsWhenNotAllied() {
        let e = makeEngine()
        XCTAssertFalse(e.leaveAlliance(country: "USA", from: "RUS"))
    }

    @MainActor
    func testAbortLaunchCancelsBeforeFiring() {
        let e = makeEngine()
        e.scheduleLaunch(from: "USA", to: "RUS", warheads: 5)
        XCTAssertNotNil(e.pendingLaunch)
        XCTAssertTrue(e.abortLaunch())
        XCTAssertNil(e.pendingLaunch)
        XCTAssertTrue(e.gameState!.nuclearStrikes.isEmpty, "aborted launch never fires")
    }

    @MainActor
    func testResolvePendingLaunchFires() {
        let e = makeEngine()
        e.scheduleLaunch(from: "USA", to: "RUS", warheads: 3)
        XCTAssertTrue(e.resolvePendingLaunch())
        XCTAssertNil(e.pendingLaunch)
        XCTAssertFalse(e.gameState!.nuclearStrikes.isEmpty)
    }
}
