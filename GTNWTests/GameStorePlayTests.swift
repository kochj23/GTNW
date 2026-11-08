//
//  GameStorePlayTests.swift
//  GTNWTests
//
//  Play-session logging (Shared/Storage/PlayHistory.swift → schema `play`) in all seven categories.
//  The "Games DB" is the in-memory fake (same upsert / immutability / FK rules as play.sql); temp folders only,
//  never the real DB, Keychain or saves.
//

import XCTest
import SwiftUI
#if os(macOS)
import AppKit
#endif
@testable import GTNW

enum PlayFixtures {
    @MainActor
    static func engine(_ dir: URL, remote: GameStore? = InMemoryGameStore()) -> (GameEngine, GameStoreService) {
        let service = StoreFixtures.service(dir, remote: remote)
        let e = GameEngine()
        e.store = service
        return (e, service)
    }

    static func summary(_ r: PlaySessionRecord?) -> [String: Any] {
        guard let d = r?.summary, let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { return [:] }
        return o
    }

    static func detail(_ e: PlayEventRecord) -> [String: Any] {
        (try? JSONSerialization.jsonObject(with: e.detail) as? [String: Any]) ?? [:]
    }

    static func session(id: UUID = UUID(), start: Date = Date(), ended: Date? = nil, actions: Int = 0,
                        summary: String = "{}") -> PlaySessionRecord {
        PlaySessionRecord(id: id, client: "mac", startedAt: start, lastSeenAt: ended ?? start, endedAt: ended,
                          outcome: ended == nil ? nil : "defeat", score: nil, actions: actions, summary: Data(summary.utf8))
    }

    static func event(_ session: UUID, seq: Int, kind: String = "ticker", detail: String = "{\"text\":\"x\"}") -> PlayEventRecord {
        PlayEventRecord(sessionID: session, seq: seq, ts: Date(), kind: kind, detail: Data(detail.utf8))
    }

    /// Fake a turn's worth of drama without running the whole turn loop.
    static func drama(_ gs: GameState) {
        gs.shadow.post("Routine: markets steady.", date: gs.currentDate, severity: 0)
        gs.shadow.post("FLASH: Soviet tanks cross the border.", date: gs.currentDate, severity: 3)
        gs.nuclearStrikes.append(NuclearStrike(attacker: "USA", target: "RUS", warheadsUsed: 5, turn: gs.turn,
                                               casualties: 5_000_000, radiationSpread: 10))
    }
}

/// A Games DB whose `play` schema isn't there (no grant / table): play calls fail with schemaNotReady.
actor NoPlaySchemaStore: GameStore {
    let inner = InMemoryGameStore()
    func putSlot(_ record: SaveRecord) async throws { try await inner.putSlot(record) }
    func getSlot(_ slot: Int) async throws -> SaveRecord? { try await inner.getSlot(slot) }
    func listSlots() async throws -> [SlotSummary] { try await inner.listSlots() }
    func deleteSlot(_ slot: Int) async throws { try await inner.deleteSlot(slot) }
    func addLeaderboard(_ record: LeaderboardRecord) async throws { try await inner.addLeaderboard(record) }
    func leaderboard(limit: Int) async throws -> [LeaderboardRecord] { try await inner.leaderboard(limit: limit) }
    func addResult(_ record: GameResultRecord) async throws { try await inner.addResult(record) }
    func history(limit: Int) async throws -> [GameResultRecord] { try await inner.history(limit: limit) }
    func scenarioProgress() async throws -> [ScenarioProgress] { try await inner.scenarioProgress() }
    func unlock(_ achievement: AchievementRecord) async throws { try await inner.unlock(achievement) }
    func achievements() async throws -> [AchievementRecord] { try await inner.achievements() }
    func upsertPlaySession(_ record: PlaySessionRecord) async throws { throw GameStoreError.schemaNotReady("database said 42501") }
    func addPlayEvent(_ event: PlayEventRecord) async throws { throw GameStoreError.schemaNotReady("database said 42501") }
    func counts() async throws -> StoreCounts { try await inner.counts() }
}

// MARK: - Unit

final class PlayHistoryUnitTests: XCTestCase {

    func testSessionIDRoundTripsAndOldSavesDecodeWithout() throws {
        var s = ShadowState()
        s.playSessionID = UUID()
        s.playSessionStartedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let back = try JSONDecoder().decode(ShadowState.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(back.playSessionID, s.playSessionID)
        XCTAssertEqual(back.playSessionStartedAt, s.playSessionStartedAt)
        let old = try JSONDecoder().decode(ShadowState.self, from: Data(#"{"popularity":61}"#.utf8))
        XCTAssertNil(old.playSessionID, "saves from before 3.1.2 load with no session")
        XCTAssertEqual(old.popularity, 61)
    }

    func testKindAndRecordValidationMirrorPlaySQL() {
        for ok in ["ticker", "nuclear_strike", "game.over", "a", "x-1"] { XCTAssertTrue(PlayHistory.isKind(ok), ok) }
        for bad in ["", "Ticker", "_x", "a b", String(repeating: "a", count: 49), "drop;table"] {
            XCTAssertFalse(PlayHistory.isKind(bad), bad)
        }
        XCTAssertNoThrow(try StoreValidation.check(PlayFixtures.session()))
        XCTAssertThrowsError(try StoreValidation.check(PlayFixtures.session(summary: "[1,2]")), "summary must be an object")
        XCTAssertThrowsError(try StoreValidation.check(PlayFixtures.session(actions: -1)))
        var early = PlayFixtures.session(start: Date())
        early.endedAt = early.startedAt.addingTimeInterval(-1)
        XCTAssertThrowsError(try StoreValidation.check(early), "ended before it started")
        var nan = PlayFixtures.session(); nan.score = .nan
        XCTAssertThrowsError(try StoreValidation.check(nan))
        XCTAssertThrowsError(try StoreValidation.check(PlayFixtures.event(UUID(), seq: -1)))
        XCTAssertThrowsError(try StoreValidation.check(PlayFixtures.event(UUID(), seq: 0, detail: "\"str\"")))
    }

    func testSummaryHasContractKeysAndCaps() throws {
        let gs = GameState(playerCountryID: "USA", turnLength: .month)
        for i in 0..<110 { gs.shadow.post("item \(i)", date: gs.currentDate, severity: i % 3) }
        for i in 0..<90 { gs.shadow.logWar("battle \(i)") }
        for i in 0..<80 { gs.shadow.polls.append(PollRecord(date: gs.currentDate, popularity: Double(i))) }
        gs.turn = 12
        gs.gameOver = true
        gs.gameOverReason = "Impeached"
        var score = GameScore(); score.finalScore = 4200; score.baseScore = 2800
        let id = UUID()
        let data = PlaySummary.build(gs, session: .init(id: id, startTurn: 4, resumedFromTurn: 4, gameDateAtStart: "May 1, 2025"),
                                     score: score, victory: nil, historyID: id)
        let s = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        for key in ["scenario", "country", "difficulty", "turn_length", "game_date_start", "game_date_end", "turns", "won",
                    "reason", "final_score", "base_score", "casualties", "nuclear_strikes", "warheads_launched", "wars_started",
                    "wars_won", "covert_ops_succeeded", "conflicts_mediated", "sanctions_imposed", "defcon", "global_radiation",
                    "impeachment_stage", "terms_won", "popularity_start", "popularity_peak", "popularity_end",
                    "congressional_support", "war_support", "polls", "strikes", "fronts", "budget", "ticker", "war_log",
                    "history_id", "resumed_from_turn"] {
            XCTAssertNotNil(s[key], "missing \(key)")
        }
        XCTAssertEqual(s["final_score"] as? Int, 4200)
        XCTAssertEqual(s["won"] as? Bool, false)
        XCTAssertEqual(s["turns_this_session"] as? Int, 8)
        XCTAssertEqual(s["history_id"] as? String, id.uuidString.lowercased())
        XCTAssertLessThanOrEqual((s["ticker"] as? [Any])?.count ?? 99, 60)
        XCTAssertTrue(((s["ticker"] as? [[String: Any]]) ?? []).allSatisfy { ($0["severity"] as? Int ?? 0) >= 1 })
        XCTAssertLessThanOrEqual((s["war_log"] as? [Any])?.count ?? 99, 40)
        XCTAssertLessThanOrEqual((s["polls"] as? [Any])?.count ?? 99, 60)
    }
}

// MARK: - Functional (the engine's session lifecycle)

final class PlayHistoryFunctionalTests: XCTestCase {
    private var dir: URL!
    override func setUp() { super.setUp(); dir = StoreFixtures.tempDir() }
    override func tearDown() { try? FileManager.default.removeItem(at: dir); super.tearDown() }

    @MainActor
    func testNewGameScenarioAndLoadEachStartANewSession() async throws {
        let remote = InMemoryGameStore()
        let (e, service) = PlayFixtures.engine(dir, remote: remote)
        e.startNewGame(playerCountryID: "USA", turnLength: .month)
        let first = try XCTUnwrap(e.gameState?.shadow.playSessionID)
        XCTAssertNotNil(e.gameState?.shadow.playSessionStartedAt)

        e.startScenario(.world1990, turnLength: .month)
        let second = try XCTUnwrap(e.gameState?.shadow.playSessionID)
        XCTAssertNotEqual(first, second)
        e.gameState?.turn = 7
        try e.saveGame(slot: 2, manager: service.local.saves)
        try e.loadGame(slot: 2, manager: service.local.saves)
        let third = try XCTUnwrap(e.gameState?.shadow.playSessionID)
        XCTAssertNotEqual(third, second, "continuing a save is a new session")
        XCTAssertEqual(e.playSession?.resumedFromTurn, 7)

        let synced1 = await service.syncNow()

        XCTAssertTrue(synced1)
        let sessions = await remote.playSessions
        XCTAssertEqual(sessions[first]?.outcome, "abandoned", "starting over closes the old session")
        XCTAssertEqual(sessions[second]?.outcome, "abandoned")
        XCTAssertNil(sessions[third]?.endedAt)
        XCTAssertEqual(PlayFixtures.summary(sessions[third])["resumed_from_turn"] as? Int, 7)
        let start = await remote.events(third).first
        XCTAssertEqual(start?.kind, "game_start")
    }

    @MainActor
    func testGameOverHistoryRowSharesTheSessionID() async throws {
        let remote = InMemoryGameStore()
        let (e, service) = PlayFixtures.engine(dir, remote: remote)
        e.startScenario(.world1990, turnLength: .month)
        let id = try XCTUnwrap(e.gameState?.shadow.playSessionID)
        let gs = try XCTUnwrap(e.gameState)
        gs.turn = 3
        gs.gameOver = true
        gs.gameOverReason = "Peace in our time"
        let score = GameScore.calculate(from: gs, victoryType: .peaceMaker)
        e.recordGameOver(gs, score: score, victory: .peaceMaker)
        e.recordGameOver(gs, score: score, victory: .peaceMaker)   // a replay must not log a second game

        let synced2 = await service.syncNow()

        XCTAssertTrue(synced2)
        let history = try await remote.history(limit: 10)
        XCTAssertEqual(history.map(\.id), [id], "game_history id == play session id")
        let s = await remote.playSessions[id]
        XCTAssertEqual(s?.outcome, "victory")
        XCTAssertEqual(s?.score, Double(score.finalScore))
        XCTAssertEqual(s?.actions, 3)
        XCTAssertNotNil(s?.endedAt)
        XCTAssertEqual(PlayFixtures.summary(s)["history_id"] as? String, id.uuidString.lowercased())
        XCTAssertEqual(PlayFixtures.summary(s)["victory_type"] as? String, VictoryType.peaceMaker.rawValue)
        let kinds = await remote.events(id).map(\.kind)
        XCTAssertEqual(kinds.first, "game_start")
        XCTAssertEqual(kinds.last, "game_over")
        XCTAssertEqual(kinds.filter { $0 == "game_over" }.count, 1)
    }

    @MainActor
    func testLoadingAFinishedGameStartsNoSession() throws {
        let (e, service) = PlayFixtures.engine(dir, remote: nil)
        e.startNewGame(playerCountryID: "USA", turnLength: .month)
        e.gameState?.gameOver = true
        try service.local.saves.save(try XCTUnwrap(e.gameState), slot: 4)
        try e.loadGame(slot: 4, manager: service.local.saves)
        XCTAssertNil(e.playSession)
    }
}

// MARK: - Integration (a whole sitting reaches the DB in order)

final class PlayHistoryIntegrationTests: XCTestCase {
    private var dir: URL!
    override func setUp() { super.setUp(); dir = StoreFixtures.tempDir() }
    override func tearDown() { try? FileManager.default.removeItem(at: dir); super.tearDown() }

    @MainActor
    func testTurnsTickerAndStrikesBecomeEventsAndActions() async throws {
        let remote = InMemoryGameStore()
        let (e, service) = PlayFixtures.engine(dir, remote: remote)
        e.startScenario(.world1990, turnLength: .month)
        let id = try XCTUnwrap(e.gameState?.shadow.playSessionID)
        e.endTurn()
        // The computer's moves resolve asynchronously; let them finish so they can't post news between the two syncs.
        for _ in 0..<500 where e.isProcessingAITurn { try await Task.sleep(nanoseconds: 10_000_000) }
        PlayFixtures.drama(try XCTUnwrap(e.gameState))
        e.gameState?.turn += 1
        e.playSessionTurnEnded()

        let synced3 = await service.syncNow()

        XCTAssertTrue(synced3)
        let s = await remote.playSessions[id]
        XCTAssertEqual(s?.actions, 2)
        XCTAssertNil(s?.endedAt)
        XCTAssertEqual(PlayFixtures.summary(s)["in_progress"] as? Bool, true)
        let events = await remote.events(id)
        XCTAssertEqual(events.map(\.seq), Array(0..<events.count), "seq is 0,1,2… with no gaps")
        XCTAssertTrue(events.contains { $0.kind == "ticker" && (PlayFixtures.detail($0)["text"] as? String)?.contains("FLASH") == true })
        XCTAssertFalse(events.contains { $0.kind == "ticker" && (PlayFixtures.detail($0)["severity"] as? Int ?? 0) < 2 },
                       "routine ticker items are not events")
        let strike = try XCTUnwrap(events.first { $0.kind == "nuclear_strike" })
        XCTAssertEqual(PlayFixtures.detail(strike)["target"] as? String, "RUS")
        XCTAssertEqual(PlayFixtures.detail(strike)["warheads"] as? Int, 5)

        e.playSessionTurnEnded()
        let synced4 = await service.syncNow()
        XCTAssertTrue(synced4)
        let again = await remote.events(id).count
        XCTAssertEqual(again, events.count, "nothing is logged twice")
    }

    func testSessionUpsertStaysAheadOfItsEventsInTheQueue() async throws {
        let remote = InMemoryGameStore()
        await remote.setReachable(false)
        let service = StoreFixtures.service(dir, remote: remote)
        let id = UUID(), t0 = Date()
        let ev = PlayFixtures.event(id, seq: 0)
        service.playSessionUpdated(PlayFixtures.session(id: id, start: t0))
        service.playEvent(ev)
        var later = PlayFixtures.session(id: id, start: t0, actions: 5)
        later.lastSeenAt = t0.addingTimeInterval(60)
        service.playSessionUpdated(later)
        XCTAssertEqual(service.local.pending, [.playSession(later), .playEvent(ev)],
                       "newer upsert replaced the old one in place")
        await remote.setReachable(true)
        let synced5 = await service.syncNow()
        XCTAssertTrue(synced5)
        let s = await remote.playSessions[id]
        XCTAssertEqual(s?.actions, 5)
        let n = await remote.events(id).count
        XCTAssertEqual(n, 1)
    }

    func testEndedSessionIsFrozen() async throws {
        let remote = InMemoryGameStore()
        let id = UUID(), t0 = Date()
        try await remote.upsertPlaySession(PlayFixtures.session(id: id, start: t0, ended: t0.addingTimeInterval(30), actions: 9))
        try await remote.upsertPlaySession(PlayFixtures.session(id: id, start: t0, actions: 1))
        let s = await remote.playSessions[id]
        XCTAssertEqual(s?.actions, 9)
        XCTAssertNotNil(s?.endedAt)
    }
}

// MARK: - Retry / offline

final class PlayHistoryRetryTests: XCTestCase {
    private var dir: URL!
    override func setUp() { super.setUp(); dir = StoreFixtures.tempDir() }
    override func tearDown() { try? FileManager.default.removeItem(at: dir); super.tearDown() }

    @MainActor
    func testOfflineSessionStaysQueuedAndSyncsWhenBack() async throws {
        let remote = InMemoryGameStore()
        await remote.setReachable(false)
        let (e, service) = PlayFixtures.engine(dir, remote: remote)
        e.startScenario(.world1990, turnLength: .month)
        let id = try XCTUnwrap(e.gameState?.shadow.playSessionID)
        let offline = await service.syncNow()
        XCTAssertFalse(offline)
        XCTAssertGreaterThanOrEqual(service.pendingCount, 2, "session + game_start wait locally")
        await remote.setReachable(true)
        let synced6 = await service.syncNow()
        XCTAssertTrue(synced6)
        XCTAssertEqual(service.pendingCount, 0)
        let s = await remote.playSessions[id]
        XCTAssertNotNil(s)
    }

    func testRejectedPlayWritesAreDroppedNotRetried() async throws {
        let remote = InMemoryGameStore()
        let service = StoreFixtures.service(dir, remote: remote)
        service.local.enqueue(.playEvent(PlayFixtures.event(UUID(), seq: 0)))   // no session row: FK violation
        let synced7 = await service.syncNow()
        XCTAssertTrue(synced7)
        XCTAssertEqual(service.pendingCount, 0)
    }

    func testMissingPlaySchemaNeverBlocksGameWrites() async throws {
        let remote = NoPlaySchemaStore()
        let service = StoreFixtures.service(dir, remote: remote)
        let id = UUID()
        service.playSessionUpdated(PlayFixtures.session(id: id))
        service.playEvent(PlayFixtures.event(id, seq: 0))
        service.recordGameOver(result: StoreFixtures.result(won: true, score: 10, id: id), leaderboard: nil)
        let synced8 = await service.syncNow()
        XCTAssertTrue(synced8)
        XCTAssertEqual(service.pendingCount, 0)
        let history = try await remote.inner.counts().history
        XCTAssertEqual(history, 1)
    }
}

// MARK: - Security

final class PlayHistorySecurityTests: XCTestCase {
    private var dir: URL!
    override func setUp() { super.setUp(); dir = StoreFixtures.tempDir() }
    override func tearDown() { try? FileManager.default.removeItem(at: dir); super.tearDown() }

    func testHostileTextIsCleanedCappedAndStaysValidJSON() throws {
        let gs = GameState(playerCountryID: "USA", turnLength: .month)
        gs.shadow.post("\u{0007}\u{001B}[31mevil\n\"},{\"x\":1" + String(repeating: "A", count: 5000), date: gs.currentDate, severity: 3)
        gs.shadow.popularity = .nan
        let data = PlaySummary.build(gs, session: .init(id: UUID(), startTurn: 0, resumedFromTurn: nil, gameDateAtStart: ""))
        let s = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let text = try XCTUnwrap((s["ticker"] as? [[String: Any]])?.last?["text"] as? String)
        XCTAssertLessThanOrEqual(text.count, PlayHistory.maxText)
        XCTAssertFalse(text.unicodeScalars.contains { CharacterSet.controlCharacters.contains($0) })
        XCTAssertEqual(s["popularity_end"] as? Double, 0, "NaN never reaches JSONSerialization")
    }

    func testOversizedOrMalformedEntriesNeverQueue() {
        let service = StoreFixtures.service(dir, remote: InMemoryGameStore())
        service.playEvent(PlayFixtures.event(UUID(), seq: 0, detail: "{\"t\":\"" + String(repeating: "x", count: 5000) + "\"}"))
        service.playEvent(PlayFixtures.event(UUID(), seq: 0, kind: "DROP TABLE"))
        service.playSessionUpdated(PlayFixtures.session(summary: "not json"))
        XCTAssertEqual(service.pendingCount, 0)
    }

    @MainActor
    func testLocalOnlyRunWritesNoPlayHistory() {
        let (e, service) = PlayFixtures.engine(dir, remote: nil)
        e.startScenario(.world1990, turnLength: .month)
        PlayFixtures.drama(e.gameState!)
        e.playSessionTurnEnded()
        XCTAssertNotNil(e.gameState?.shadow.playSessionID, "the id is still kept on the game")
        XCTAssertEqual(service.pendingCount, 0, "no Games DB, nothing queued")
        XCTAssertNil(GameStoreService.shared.remote, "the test host never reaches the real DB")
    }
}

// MARK: - Performance (wall-clock budgets)

final class PlayHistoryPerformanceTests: XCTestCase {
    private var dir: URL!
    override func setUp() { super.setUp(); dir = StoreFixtures.tempDir() }
    override func tearDown() { try? FileManager.default.removeItem(at: dir); super.tearDown() }

    func testBigGameSummaryIsFastAndUnderTheCap() {
        let gs = GameState(playerCountryID: "USA", turnLength: .week)
        for i in 0..<120 { gs.shadow.post(String(repeating: "headline \(i) ", count: 40), date: gs.currentDate, severity: 2) }
        for i in 0..<200 { gs.shadow.logWar(String(repeating: "front \(i) ", count: 40)) }
        for i in 0..<500 { gs.shadow.polls.append(PollRecord(date: gs.currentDate, popularity: Double(i % 100))) }
        for i in 0..<200 {
            gs.nuclearStrikes.append(NuclearStrike(attacker: "USA", target: "RUS", warheadsUsed: 1, turn: i, casualties: 1, radiationSpread: 1))
        }
        let session = PlaySummary.Session(id: UUID(), startTurn: 0, resumedFromTurn: nil, gameDateAtStart: "")
        let start = Date()
        var size = 0
        for _ in 0..<50 { size = PlaySummary.build(gs, session: session).count }
        XCTAssertLessThan(Date().timeIntervalSince(start), 3.0)
        XCTAssertLessThanOrEqual(size, PlayHistory.maxSummaryBytes)
    }

    func testFullQueueShedsPlayEventsBeforeGameWrites() throws {
        let id = UUID()
        var ops: [PendingOp] = [.result(StoreFixtures.result(won: true, score: 1))]
        ops += (0..<(LocalGameStore.maxPending - 1)).map { .playEvent(PlayFixtures.event(id, seq: $0)) }
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
        try enc.encode(ops).write(to: dir.appendingPathComponent("pending.json"))
        let store = LocalGameStore(folder: dir, saves: SaveManager(folder: dir.appendingPathComponent("Saves")))
        let start = Date()
        store.enqueue(.achievement(AchievementRecord(id: "a", unlockedAt: Date())))
        store.enqueue(.achievement(AchievementRecord(id: "b", unlockedAt: Date())))
        XCTAssertLessThan(Date().timeIntervalSince(start), 2.0)
        let q = store.pending
        XCTAssertEqual(q.count, LocalGameStore.maxPending)
        if case .result = q.first {} else { XCTFail("the game result survived") }
        XCTAssertEqual(q.suffix(2).compactMap { if case .achievement(let a) = $0 { return a.id } else { return nil } }, ["a", "b"])
    }
}

// MARK: - Frame

final class PlayHistoryFrameTests: XCTestCase {

    #if os(macOS)
    @MainActor
    func testBadgeCountsQueuedPlayHistoryInBothSkins() async {
        let dir = StoreFixtures.tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let remote = InMemoryGameStore()
        await remote.setReachable(false)
        let service = StoreFixtures.service(dir, remote: remote)
        service.playSessionUpdated(PlayFixtures.session())
        _ = await service.syncNow()
        await MainActor.run {}
        XCTAssertEqual(service.status, .offline(pending: 1))
        defer { Theme.forced = nil }
        for theme in GameTheme.allCases {
            Theme.forced = theme
            let view = NSHostingView(rootView: StoreStatusBadge(store: service))
            view.frame = NSRect(x: 0, y: 0, width: 160, height: 30)
            view.layoutSubtreeIfNeeded()
            XCTAssertGreaterThan(view.fittingSize.width, 0)
        }
    }
    #endif

    @MainActor
    func testGameStartsAndEndsWithoutAStore() throws {
        let e = GameEngine()   // no store: logging is a no-op, the game is unaffected
        e.startNewGame(playerCountryID: "USA", turnLength: .month)
        let gs = try XCTUnwrap(e.gameState)
        gs.gameOver = true
        e.recordGameOver(gs, score: GameScore.calculate(from: gs, victoryType: nil), victory: nil)
        XCTAssertTrue(e.playSession?.ended ?? false)
    }
}

// MARK: - 3.22.0: the roast log (every order, what the cabinet said, crisis calls, elections, swings, post-mortem)

enum RoastFixtures {
    static let oppose = ActionAdvice(advisorID: nil, advisorName: "Jane Hawk", advisorTitle: "Secretary of State",
                                     stance: .oppose, reason: "This will start a war we cannot win.", successEstimate: 0.22)
    static let danger = [AdvisorWarning(who: "Joint Chiefs", text: "We lose two carriers.", level: 2),
                         AdvisorWarning(who: "Vice President", text: "Approval drops 12.", level: 1)]

    @MainActor
    static func started(_ dir: URL, remote: GameStore? = InMemoryGameStore()) throws -> (GameEngine, GameStoreService, GameState, UUID) {
        let (e, service) = PlayFixtures.engine(dir, remote: remote)
        e.startNewGame(playerCountryID: "USA", turnLength: .month)
        let gs = try XCTUnwrap(e.gameState)
        return (e, service, gs, try XCTUnwrap(gs.shadow.playSessionID))
    }

    static func card(chance: Double = 1.0) -> CrisisEvent {
        let c = CrisisConsequences(approvalChange: 0, message: "x")
        return CrisisEvent(type: .election, severity: .serious, title: "The October Surprise",
                           description: "A tape surfaces a week before the vote.", affectedCountries: ["USA"], turn: 1,
                           options: [CrisisOption(title: "Deny everything", description: "It's a fake.", consequences: c, successChance: chance),
                                     CrisisOption(title: "Come clean", description: "Own it.", advisorRecommendation: "Press Secretary",
                                                  consequences: c, successChance: chance),
                                     CrisisOption(title: "Change the subject", description: "Bomb something.", consequences: c, successChance: chance)])
    }
}

final class RoastLogUnitTests: XCTestCase {

    func testStatsJSONAndRecentOrdersAreCapped() {
        var s = PlayStats()
        for i in 0..<20 { s.noteOrder("order \(i)") }
        XCTAssertEqual(s.lastOrders.count, PlayHistory.recentOrders)
        XCTAssertEqual(s.lastOrders.last, "order 19")
        XCTAssertEqual(s.lastOrders.first, "order 12")
        let j = s.json
        for k in ["orders_given", "advisors_overruled", "danger_warnings_ignored", "backed_down_after_advice",
                  "crises_failed", "advisors_resigned", "biggest_one_turn_approval_drop", "last_orders"] {
            XCTAssertNotNil(j[k], k)
        }
        XCTAssertTrue(JSONSerialization.isValidJSONObject(j))
    }

    @MainActor
    func testSwingsFireAtTheirThresholdsAndMoveTheBaseline() throws {
        let e = GameEngine()
        e.startNewGame(playerCountryID: "USA", turnLength: .month)
        let gs = try XCTUnwrap(e.gameState)
        let t = PlaySessionTracker(id: UUID(), startedAt: Date(), gs: gs, resumedFromTurn: nil)
        XCTAssertTrue(PlayHistory.swings(gs, t).isEmpty, "nothing moved")

        gs.shadow.popularity = t.lastPopularity - 4.9
        XCTAssertTrue(PlayHistory.swings(gs, t).isEmpty, "a 4.9-point dip is noise")
        gs.shadow.popularity -= 5
        let drop = PlayHistory.swings(gs, t)
        XCTAssertEqual(drop.map(\.0), ["approval_swing"])
        XCTAssertEqual(drop.first?.1["change"] as? Double, -5)
        XCTAssertEqual(t.stats.biggestApprovalDrop, 5, accuracy: 0.01)
        XCTAssertTrue(PlayHistory.swings(gs, t).isEmpty, "the baseline moved: the same drop is not logged twice")

        gs.defconLevel = DefconLevel(rawValue: max(1, t.lastDefcon - 1))!
        gs.shadow.impeachmentStage = t.lastImpeachmentStage + 1
        let pi = try XCTUnwrap(gs.countries.firstIndex { $0.id == "USA" })
        gs.countries[pi].congressionalSupport = (t.lastCongress ?? 50) - PlayHistory.congressSwing
        XCTAssertEqual(PlayHistory.swings(gs, t).map(\.0), ["defcon_change", "impeachment_track", "congress_swing"])
    }

    func testNovaWarningOnlyWhenNovaWontSeeTheGame() {
        let now = Date()
        XCTAssertNotNil(StoreStatus.novaWarning(.localOnly("DB credentials not set up yet"), offlineSince: nil, now: now))
        XCTAssertTrue(StoreStatus.novaWarning(.localOnly("no CA"), offlineSince: nil, now: now)!.contains("no CA"))
        XCTAssertNil(StoreStatus.novaWarning(.online, offlineSince: nil, now: now))
        XCTAssertNil(StoreStatus.novaWarning(.syncing, offlineSince: now.addingTimeInterval(-3600), now: now))
        XCTAssertNil(StoreStatus.novaWarning(.offline(pending: 3), offlineSince: now.addingTimeInterval(-60), now: now),
                     "a short blip isn't worth a banner")
        let long = StoreStatus.novaWarning(.offline(pending: 3), offlineSince: now.addingTimeInterval(-StoreStatus.novaGrace - 60), now: now)
        XCTAssertTrue(long?.contains("11 MIN") == true, long ?? "nil")
        XCTAssertTrue(long?.contains("3 change") == true)
    }
}

final class RoastLogFunctionalTests: XCTestCase {
    private var dir: URL!
    override func setUp() { super.setUp(); dir = StoreFixtures.tempDir() }
    override func tearDown() { try? FileManager.default.removeItem(at: dir); super.tearDown() }

    @MainActor
    func testOverruledOrderCarriesTheAdviceTheWarningsAndTheResult() async throws {
        let remote = InMemoryGameStore()
        let (e, service, gs, id) = try RoastFixtures.started(dir, remote: remote)
        let report = ActionReport(title: "Air Strike — China", lines: ["❌ AIR STRIKE — FAILED", "   The jets turned back.", "a", "b", "c"],
                                  success: false)
        gs.shadow.popularity = 41
        e.logPresidentialOrder(.airStrike, targetID: "CHN", advice: RoastFixtures.oppose, warnings: RoastFixtures.danger,
                               size: AttackSize(troops: 0, aircraft: 40, warheads: 0), warhead: nil,
                               popularityBefore: 48, report: report, resignation: "Jane Hawk has resigned.")
        e.playSessionTurnEnded()
        let synced = await service.syncNow()
        XCTAssertTrue(synced)

        let fetched1 = await remote.events(id)
        let order = try XCTUnwrap(fetched1.first { $0.kind == "president_order" })
        let d = PlayFixtures.detail(order)
        XCTAssertEqual(d["action"] as? String, "Air Strike")
        XCTAssertEqual(d["target_name"] as? String, "People's Republic of China")
        XCTAssertEqual(d["overruled_advisor"] as? Bool, true)
        XCTAssertEqual(d["advisor_stance"] as? String, "oppose")
        XCTAssertEqual(d["advisor_said"] as? String, "This will start a war we cannot win.")
        XCTAssertEqual(d["advisor_odds"] as? Double, 0.22)
        XCTAssertEqual(d["danger_warnings_ignored"] as? Int, 1)
        XCTAssertEqual((d["cabinet_warnings"] as? [[String: Any]])?.count, 2)
        XCTAssertEqual(d["worked"] as? Bool, false)
        XCTAssertEqual((d["result"] as? [String])?.count, PlayHistory.orderLines)
        XCTAssertEqual(d["approval_before"] as? Double, 48)
        XCTAssertEqual(d["approval_after"] as? Double, 41)
        XCTAssertEqual(d["resignation"] as? String, "Jane Hawk has resigned.")

        let fetched2 = await remote.playSessions[id]
        let stats = try XCTUnwrap(PlayFixtures.summary(fetched2)["session_stats"] as? [String: Any])
        XCTAssertEqual(stats["orders_given"] as? Int, 1)
        XCTAssertEqual(stats["orders_failed"] as? Int, 1)
        XCTAssertEqual(stats["advisors_overruled"] as? Int, 1)
        XCTAssertEqual(stats["danger_warnings_ignored"] as? Int, 1)
        XCTAssertEqual(stats["advisors_resigned"] as? Int, 1)
        XCTAssertEqual((stats["last_orders"] as? [String])?.first,
                       "Air Strike -> People's Republic of China (overruled Secretary of State; ignored 1 danger warning; FAILED)")
    }

    @MainActor
    func testRealOrderThroughTheAdviceFlowIsLoggedOnce() async throws {
        let remote = InMemoryGameStore()
        let (e, service, _, id) = try RoastFixtures.started(dir, remote: remote)
        e.performAdvisedAction(.sanctions, targetID: "CHN", advice: RoastFixtures.oppose)
        let synced = await service.syncNow()
        XCTAssertTrue(synced)
        let orders = await remote.events(id).filter { $0.kind == "president_order" }
        XCTAssertEqual(orders.count, 1)
        let d = PlayFixtures.detail(try XCTUnwrap(orders.first))
        XCTAssertEqual(d["action"] as? String, PresidentialAction.sanctions.rawValue)
        XCTAssertNotNil(d["result"], "the outcome lines the President saw")
        XCTAssertEqual(e.playSession?.stats.orders, 1)
    }

    @MainActor
    func testBackingDownAndRecommendationsAreLogged() async throws {
        let remote = InMemoryGameStore()
        let (e, service, gs, id) = try RoastFixtures.started(dir, remote: remote)
        e.declineAdvisedAction(advice: RoastFixtures.oppose, action: .airStrike, targetID: "CHN")
        e.declineAdvisedAction(advice: nil)   // no advice: nothing to log
        let i = try XCTUnwrap(gs.advisors.indices.first { gs.advisors[$0].isActive })
        gs.advisors[i].recommendedAction = PresidentialAction.sanctions.rawValue
        gs.advisors[i].recommendedTarget = "CHN"
        gs.advisors[i].currentAdvice = "Squeeze them."
        e.rejectRecommendation(advisorID: gs.advisors[i].id)
        let synced = await service.syncNow()
        XCTAssertTrue(synced)

        let events = await remote.events(id)
        let back = try XCTUnwrap(events.first { $0.kind == "backed_down" })
        XCTAssertEqual(PlayFixtures.detail(back)["action"] as? String, "Air Strike")
        XCTAssertEqual(events.filter { $0.kind == "backed_down" }.count, 1)
        let rec = PlayFixtures.detail(try XCTUnwrap(events.first { $0.kind == "recommendation" }))
        XCTAssertEqual(rec["accepted"] as? Bool, false)
        XCTAssertEqual(rec["advice"] as? String, "Squeeze them.")
        XCTAssertEqual(rec["target_name"] as? String, "People's Republic of China")
        XCTAssertEqual(e.playSession?.stats.backedDown, 1)
        XCTAssertEqual(e.playSession?.stats.recommendationsRejected, 1)
    }

    @MainActor
    func testCrisisDecisionFromAnyScreenIsLoggedWithTheRoadsNotTaken() async throws {
        let remote = InMemoryGameStore()
        var (e, service, gs, id) = try RoastFixtures.started(dir, remote: remote)
        e.crisisManager.presentCrisis(RoastFixtures.card(chance: 0))
        e.crisisManager.resolveCrisis(optionIndex: 2, gameState: &gs)
        let synced = await service.syncNow()
        XCTAssertTrue(synced)
        let fetched3 = await remote.events(id)
        let d = PlayFixtures.detail(try XCTUnwrap(fetched3.first { $0.kind == "crisis_decision" }))
        XCTAssertEqual(d["title"] as? String, "The October Surprise")
        XCTAssertEqual(d["chose"] as? String, "Change the subject")
        XCTAssertEqual(d["worked"] as? Bool, false)
        XCTAssertEqual(d["other_options"] as? [String], ["Deny everything", "Come clean"])
        XCTAssertEqual(d["passed_over_advised"] as? [String], ["Come clean (Press Secretary)"])
        XCTAssertEqual(e.playSession?.stats.crisesFailed, 1)
    }

    @MainActor
    func testGameOverPostMortemHasTheLastOrders() async throws {
        let remote = InMemoryGameStore()
        let (e, service, gs, id) = try RoastFixtures.started(dir, remote: remote)
        for _ in 0..<3 {
            e.logPresidentialOrder(.airStrike, targetID: "CHN", advice: RoastFixtures.oppose, warnings: [], size: nil, warhead: nil,
                                   popularityBefore: 50, report: nil, resignation: nil)
        }
        gs.gameOver = true
        gs.gameOverReason = "Impeached and removed from office"
        e.recordGameOver(gs, score: GameScore.calculate(from: gs, victoryType: nil), victory: nil)
        let synced = await service.syncNow()
        XCTAssertTrue(synced)
        let fetched4 = await remote.events(id)
        let d = PlayFixtures.detail(try XCTUnwrap(fetched4.first { $0.kind == "game_over" }))
        XCTAssertEqual((d["last_orders"] as? [String])?.count, 3)
        XCTAssertEqual(d["advisors_overruled"] as? Int, 3)
        XCTAssertNotNil(d["approval_end"])
        XCTAssertNotNil(d["impeachment_stage"])
    }
}

final class RoastLogIntegrationTests: XCTestCase {
    private var dir: URL!
    override func setUp() { super.setUp(); dir = StoreFixtures.tempDir() }
    override func tearDown() { try? FileManager.default.removeItem(at: dir); super.tearDown() }

    @MainActor
    func testElectionNightAndSwingsReachTheDB() async throws {
        let remote = InMemoryGameStore()
        let (e, service, gs, id) = try RoastFixtures.started(dir, remote: remote)
        let year = gs.currentYear + (4 - gs.currentYear % 4) % 4
        e.holdElection(on: ElectionRules(year: year).electionDay)
        gs.shadow.popularity -= 12
        e.playSessionTurnEnded()
        let synced = await service.syncNow()
        XCTAssertTrue(synced)
        let events = await remote.events(id)
        let d = PlayFixtures.detail(try XCTUnwrap(events.first { $0.kind == "election_result" }))
        XCTAssertEqual(d["year"] as? Int, year)
        let ev = (d["electoral_votes"] as? Int ?? 0) + (d["opponent_electoral_votes"] as? Int ?? 0) + (d["third_electoral_votes"] as? Int ?? 0)
        XCTAssertEqual(ev, d["electors"] as? Int)
        XCTAssertTrue(["won", "lost", "no_majority"].contains(d["outcome"] as? String ?? ""))
        XCTAssertTrue(events.contains { $0.kind == "approval_swing" })
        XCTAssertEqual(events.map(\.seq), Array(0..<events.count))
    }
}

final class RoastLogSecurityTests: XCTestCase {
    private var dir: URL!
    override func setUp() { super.setUp(); dir = StoreFixtures.tempDir() }
    override func tearDown() { try? FileManager.default.removeItem(at: dir); super.tearDown() }

    @MainActor
    func testHostileAdviceAndWarningTextIsCleanedAndUnderTheCap() async throws {
        let remote = InMemoryGameStore()
        let (e, service, _, id) = try RoastFixtures.started(dir, remote: remote)
        let nasty = String(repeating: "\u{0007}<script>alert(1)</script>\u{202E}Robert'); --", count: 400)
        let advice = ActionAdvice(advisorID: nil, advisorName: nasty, advisorTitle: nasty, stance: .oppose, reason: nasty, successEstimate: .nan)
        let warnings = (0..<20).map { _ in AdvisorWarning(who: nasty, text: nasty, level: 2) }
        let report = ActionReport(title: nasty, lines: Array(repeating: nasty, count: 50), success: false)
        e.logPresidentialOrder(.airStrike, targetID: nasty, advice: advice, warnings: warnings, size: nil, warhead: nil,
                               popularityBefore: .infinity, report: report, resignation: nasty)
        let synced = await service.syncNow()
        XCTAssertTrue(synced)
        let fetched5 = await remote.events(id)
        let order = try XCTUnwrap(fetched5.first { $0.kind == "president_order" })
        XCTAssertLessThanOrEqual(order.detail.count, PlayHistory.maxDetailBytes)
        let text = String(decoding: order.detail, as: UTF8.self)
        XCTAssertFalse(text.contains("\u{0007}"))
        XCTAssertFalse(text.contains("\u{202E}"))
        let d = PlayFixtures.detail(order)
        XCTAssertLessThanOrEqual((d["advisor_said"] as? String ?? "").count, PlayHistory.maxText)
        XCTAssertEqual(d["advisor_odds"] as? Double, 0, "NaN never reaches the JSON")
    }
}

final class RoastLogPerformanceTests: XCTestCase {

    @MainActor
    func testAThousandOrdersLogQuickly() throws {
        let dir = StoreFixtures.tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let (e, _, _, _) = try RoastFixtures.started(dir)
        let start = Date()
        for _ in 0..<1000 {
            e.logPresidentialOrder(.airStrike, targetID: "CHN", advice: RoastFixtures.oppose, warnings: RoastFixtures.danger,
                                   size: nil, warhead: nil, popularityBefore: 50, report: nil, resignation: nil)
        }
        XCTAssertLessThan(Date().timeIntervalSince(start), 2.0)
        XCTAssertEqual(e.playSession?.stats.orders, 1000)
        XCTAssertEqual(e.playSession?.stats.lastOrders.count, PlayHistory.recentOrders, "memory stays bounded")
    }
}

final class RoastLogRetryTests: XCTestCase {

    @MainActor
    func testOfflineClockStartsOnceAndClearsWhenBack() async throws {
        let dir = StoreFixtures.tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let remote = InMemoryGameStore()
        await remote.setReachable(false)
        let service = StoreFixtures.service(dir, remote: remote)
        service.playSessionUpdated(PlayFixtures.session())
        _ = await service.syncNow()
        await MainActor.run {}
        let since = try XCTUnwrap(service.offlineSince)
        _ = await service.syncNow()
        await MainActor.run {}
        XCTAssertEqual(service.offlineSince, since, "a second failed pass doesn't restart the clock")
        XCTAssertNil(service.novaWarning(), "tests never show the banner")
        await remote.setReachable(true)
        let synced = await service.syncNow()
        await MainActor.run {}
        XCTAssertTrue(synced)
        XCTAssertNil(service.offlineSince)
    }
}

final class RoastLogFrameTests: XCTestCase {

    #if os(macOS)
    @MainActor
    func testBannerShowsInBothSkinsAndVanishesWhenFine() {
        defer { Theme.forced = nil }
        for theme in GameTheme.allCases {
            Theme.forced = theme
            let shown = NSHostingView(rootView: NovaSyncBanner(text: "NOVA CAN'T SEE THIS GAME: test").frame(width: 600))
            shown.layoutSubtreeIfNeeded()
            XCTAssertGreaterThan(shown.fittingSize.height, 10, "\(theme)")
            let hidden = NSHostingView(rootView: NovaSyncBanner().frame(width: 600))
            hidden.layoutSubtreeIfNeeded()
            XCTAssertLessThan(hidden.fittingSize.height, 2, "no banner in a test run")
        }
    }
    #endif
}

final class RoastLogFitTests: XCTestCase {
    /// Security / unit: an over-cap detail is shortened, never silently dropped; small ones are untouched.
    func testOversizedDetailIsShortenedNotDropped() throws {
        let small: [String: Any] = ["a": "short", "n": 3]
        XCTAssertEqual(PlayHistory.fitted(small), PlayHistory.json(small))
        let big: [String: Any] = ["lines": Array(repeating: String(repeating: "x", count: 300), count: 30), "n": 7]
        let d = try XCTUnwrap(PlayHistory.fitted(big))
        XCTAssertLessThanOrEqual(d.count, PlayHistory.maxDetailBytes)
        let back = try XCTUnwrap(try JSONSerialization.jsonObject(with: d) as? [String: Any])
        XCTAssertEqual(back["n"] as? Int, 7, "numbers survive the cut")
    }
}
