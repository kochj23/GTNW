//
//  GameStoreTests.swift
//  GTNWTests
//
//  The durable-state store (Shared/Storage) in all seven categories. Everything here uses temp folders, the
//  in-memory fake as the "Games DB", and stub credentials: no network, no real Keychain, no real UserDefaults,
//  no real saves. (First draft by Nova / qwen3-coder:30b, reviewed and fixed.)
//

import XCTest
import SwiftUI
#if os(macOS)
import AppKit
#endif
@testable import GTNW

enum StoreFixtures {
    static func leaderboard(score: Int, id: UUID = UUID(), at: Date = Date()) -> LeaderboardRecord {
        LeaderboardRecord(id: id, playerName: "Player", finalScore: score, baseScore: score, turnsPlayed: 10, nuclearVirgin: false,
                          difficultyMultiplier: 1.0, victoryType: nil, playerCountry: "USA", achievedAt: at)
    }

    static func result(scenario: String = "world1990", won: Bool, score: Int, id: UUID = UUID()) -> GameResultRecord {
        GameResultRecord(id: id, scenarioID: scenario, playerCountry: "USA", won: won, victoryType: nil, reason: "",
                         finalScore: score, turns: 50, gameDate: "June 1, 1990", casualties: 100, nuclearStrikes: 0, endedAt: Date())
    }

    static func tempDir() -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("GTNWTests.store.\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Short backoff gaps are skipped; the long reconnect gap really waits, so no background retry fires mid-test.
    static let sleeper: RetrySleeper = { seconds in
        guard seconds >= 60 else { return }
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }

    static func service(_ dir: URL, remote: GameStore?, attempts: Int = 2) -> GameStoreService {
        GameStoreService(local: LocalGameStore(folder: dir, saves: SaveManager(folder: dir.appendingPathComponent("Saves"))),
                         remote: remote, localOnlyReason: "test", sleeper: sleeper,
                         passPolicy: RetryPolicy(maxAttempts: attempts, baseDelay: 0),
                         reconnectPolicy: RetryPolicy(maxAttempts: 2, baseDelay: 3600, maxDelay: 3600))
    }

    static func assertInvalid(_ body: () async throws -> Void, file: StaticString = #filePath, line: UInt = #line) async {
        do {
            try await body()
            XCTFail("expected GameStoreError.invalid", file: file, line: line)
        } catch let e as GameStoreError {
            guard case .invalid = e else { return XCTFail("expected .invalid, got \(e)", file: file, line: line) }
        } catch {
            XCTFail("unexpected \(error)", file: file, line: line)
        }
    }
}

/// Stub credentials (never the Keychain).
struct StubCredentials: GameStoreCredentials {
    var passwords: [String: String] = [:]
    func password(account: String) -> String? { passwords[account] }
}

// MARK: - Unit

final class GameStoreUnitTests: XCTestCase {

    func testScenarioProgressApplying() {
        let first = ScenarioProgress.applying(StoreFixtures.result(won: true, score: 100), to: nil)
        XCTAssertEqual([first.plays, first.wins, first.bestScore], [1, 1, 100])
        let second = ScenarioProgress.applying(StoreFixtures.result(won: false, score: 40), to: first)
        XCTAssertEqual([second.plays, second.wins, second.bestScore], [2, 1, 100])
        XCTAssertFalse(second.lastWon)
    }

    func testCleanStripsControlCharactersAndCaps() {
        XCTAssertEqual(StoreValidation.clean("\u{0007}hello\u{0007}", max: 10), "hello")
        XCTAssertEqual(StoreValidation.clean(String(repeating: "x", count: 100), max: 5).count, 5)
    }

    func testIsIdentifier() {
        XCTAssertTrue(StoreValidation.isIdentifier("world1990"))
        XCTAssertFalse(StoreValidation.isIdentifier("a b"))
        XCTAssertFalse(StoreValidation.isIdentifier("../x"))
        XCTAssertFalse(StoreValidation.isIdentifier(""))
    }

    func testSaveCodecRoundTrip() throws {
        let gs = GameState(playerCountryID: "USA", turnLength: .month)
        gs.turn = 42
        let record = try SaveCodec.record(gs, slot: 1)
        XCTAssertEqual(try SaveCodec.decode(record.payload, schemaVersion: record.schemaVersion).turn, 42)
        XCTAssertEqual(record.sha256.count, 32)
    }

    func testLegacyLeaderboardEntryWithoutIdGetsStableId() throws {
        let json = Data(#"[{"playerName":"A","rank":1,"score":{"baseScore":0,"turnsPlayed":3,"nuclearVirgin":true,"casualtyPenalty":0,"allianceBonus":0,"treatyBonus":0,"economicBonus":0,"difficultyMultiplier":1,"finalScore":77,"playerCountry":"USA","dateAchieved":0}}]"#.utf8)
        let a = try JSONDecoder().decode([LeaderboardEntry].self, from: json)
        let b = try JSONDecoder().decode([LeaderboardEntry].self, from: json)
        XCTAssertEqual(a[0].id, b[0].id, "re-importing the same legacy entry must give the same id")
        XCTAssertEqual(LeaderboardRecord(entry: a[0]).finalScore, 77)
    }
}

// MARK: - Functional

final class GameStoreFunctionalTests: XCTestCase {
    private var dir: URL!
    override func setUp() { super.setUp(); dir = StoreFixtures.tempDir() }
    override func tearDown() { try? FileManager.default.removeItem(at: dir); super.tearDown() }

    private func store() -> LocalGameStore { LocalGameStore(folder: dir, saves: SaveManager(folder: dir.appendingPathComponent("Saves"))) }

    func testLocalSlotRoundTripListAndDelete() async throws {
        let store = store()
        let gs = GameState(playerCountryID: "USA", turnLength: .month)
        gs.turn = 3
        try await store.putSlot(SaveCodec.record(gs, slot: 1))
        let back = try await store.getSlot(1)
        XCTAssertEqual(back?.turn, 3)
        let v1 = try await store.listSlots().map(\.slot)
        XCTAssertEqual(v1, [1])
        try await store.deleteSlot(1)
        let v2 = try await store.getSlot(1)
        XCTAssertNil(v2)
    }

    func testLeaderboardSortedDescending() async throws {
        let store = store()
        try await store.addLeaderboard(StoreFixtures.leaderboard(score: 100))
        try await store.addLeaderboard(StoreFixtures.leaderboard(score: 200))
        let v3 = try await store.leaderboard(limit: 10).map(\.finalScore)
        XCTAssertEqual(v3, [200, 100])
    }

    func testAddResultTwiceCountsOnce() async throws {
        let store = store()
        let result = StoreFixtures.result(won: true, score: 100)
        try await store.addResult(result)
        try await store.addResult(result)
        let v4 = try await store.history(limit: 10).count
        XCTAssertEqual(v4, 1)
        let v5 = try await store.scenarioProgress().first?.plays
        XCTAssertEqual(v5, 1)
    }

    func testNewerSlotOpReplacesOlder() {
        let store = store()
        store.enqueue(.putSlot(1))
        store.enqueue(.deleteSlot(1))
        XCTAssertEqual(store.pending, [.deleteSlot(1)])
    }

    func testRecordsAndQueueSurviveRestart() throws {
        try store().recordLeaderboard(StoreFixtures.leaderboard(score: 5))
        store().enqueue(.putSlot(2))
        let reopened = store()
        XCTAssertEqual(reopened.snapshot.leaderboard.count, 1)
        XCTAssertEqual(reopened.pending, [.putSlot(2)])
    }
}

// MARK: - Security

final class GameStoreSecurityTests: XCTestCase {

    func testDecodeRejectsOversizedPayload() {
        XCTAssertThrowsError(try SaveCodec.decode(Data(repeating: 0x41, count: StoreValidation.maxPayloadBytes + 1)))
    }

    func testDecodeRejectsNonJSON() {
        XCTAssertThrowsError(try SaveCodec.decode(Data("{not json".utf8)))
    }

    func testDecodeRejectsNewerSchema() throws {
        let data = try SaveCodec.encode(GameState(playerCountryID: "USA", turnLength: .month))
        XCTAssertThrowsError(try SaveCodec.decode(data, schemaVersion: 99))
    }

    func testDecodeRejectsGameWithMissingPlayerCountry() throws {
        let gs = GameState(playerCountryID: "USA", turnLength: .month)
        gs.playerCountryID = "ZZZ"
        let data = try JSONEncoder().encode(gs)
        XCTAssertThrowsError(try SaveCodec.decode(data))
    }

    func testStoreRejectsBadSlotAndNegativeScore() async throws {
        let store = InMemoryGameStore()
        var record = try SaveCodec.record(GameState(playerCountryID: "USA", turnLength: .month), slot: 1)
        record.slot = 9
        await StoreFixtures.assertInvalid { try await store.putSlot(record) }
        await StoreFixtures.assertInvalid { try await store.addLeaderboard(StoreFixtures.leaderboard(score: -5)) }
        await StoreFixtures.assertInvalid { try await store.addResult(StoreFixtures.result(scenario: "x'; DROP TABLE", won: true, score: 1)) }
    }

    func testMissingCredentialsMeansNotConfiguredNotAPrompt() async throws {
        let pg = PostgresGameStore(config: .defaults, credentials: StubCredentials(), caPEM: Data())
        do {
            _ = try await pg.listSlots()
            XCTFail("must not connect without credentials")
        } catch let e as GameStoreError {
            guard case .notConfigured = e else { return XCTFail("got \(e)") }
            XCTAssertFalse(e.isRetryable)
        }
    }

    func testCredentialHandoffAcceptsOnlyOneLinePasswords() {
        XCTAssertEqual(GameStoreSetup.clean("  s3cretPassw0rd-xyz\n"), "s3cretPassw0rd-xyz")
        XCTAssertTrue(GameStoreSetup.isPlausiblePassword("s3cretPassw0rd-xyz"))
        XCTAssertFalse(GameStoreSetup.isPlausiblePassword("short"))
        XCTAssertFalse(GameStoreSetup.isPlausiblePassword("two words here"))
        XCTAssertFalse(GameStoreSetup.isPlausiblePassword("line1\nline2xxxx"))
        XCTAssertFalse(GameStoreSetup.isPlausiblePassword(String(repeating: "a", count: 300)))
        XCTAssertFalse(GameStoreSetup.isPlausiblePassword("pässwörd-unicode"))
    }

    func testConfigRejectsHostileHostAndNovaDatabase() {
        var c = GameStoreConfig.defaults
        c.host = "bad host;"
        XCTAssertThrowsError(try c.validate())
        c = .defaults
        c.database = "nova_ops"
        XCTAssertThrowsError(try c.validate(), "the game must never point at Nova's own database")
    }
}

// MARK: - Integration

final class GameStoreIntegrationTests: XCTestCase {
    private var dirs: [URL] = []
    override func tearDown() { dirs.forEach { try? FileManager.default.removeItem(at: $0) }; super.tearDown() }
    private func dir() -> URL { let d = StoreFixtures.tempDir(); dirs.append(d); return d }

    func testEverythingReachesTheDB() async throws {
        let remote = InMemoryGameStore()
        let service = StoreFixtures.service(dir(), remote: remote)
        try service.local.saves.save(GameState(playerCountryID: "USA", turnLength: .month), slot: 1)
        service.slotSaved(1)
        service.recordGameOver(result: StoreFixtures.result(won: true, score: 100), leaderboard: StoreFixtures.leaderboard(score: 100))
        service.unlockAchievement("first_strike")

        let ok = await service.syncNow()
        XCTAssertTrue(ok)
        XCTAssertEqual(service.pendingCount, 0)
        let counts = try await remote.counts()
        XCTAssertEqual(counts, StoreCounts(slots: 1, leaderboard: 1, history: 1, scenarios: 1, achievements: 1))
    }

    func testSecondDevicePullsSlotsAndRecords() async throws {
        let remote = InMemoryGameStore()
        let first = StoreFixtures.service(dir(), remote: remote)
        try first.local.saves.save(GameState(playerCountryID: "USA", turnLength: .month), slot: 1)
        first.slotSaved(1)
        first.recordGameOver(result: StoreFixtures.result(won: true, score: 100), leaderboard: StoreFixtures.leaderboard(score: 100))
        _ = await first.syncNow()

        let second = StoreFixtures.service(dir(), remote: remote)
        let ok = await second.syncNow()
        XCTAssertTrue(ok)
        XCTAssertNotNil(second.local.saves.modified(slot: 1))
        XCTAssertEqual(second.records.leaderboard.count, 1)
        XCTAssertEqual(second.records.progress.first?.plays, 1)
    }

    @MainActor
    func testGameOverAndSaveFlowThroughTheEngine() async throws {
        let remote = InMemoryGameStore()
        let service = StoreFixtures.service(dir(), remote: remote)
        let e = GameEngine()
        e.store = service
        e.startScenario(.world1990, turnLength: .month)
        try e.saveGame(slot: 2, manager: service.local.saves)
        let gs = try XCTUnwrap(e.gameState)
        e.recordGameOver(gs, score: GameScore.calculate(from: gs, victoryType: .peaceMaker), victory: .peaceMaker)
        let ok = await service.syncNow()
        XCTAssertTrue(ok)
        let counts = try await remote.counts()
        XCTAssertEqual(counts.slots, 1)
        XCTAssertEqual(counts.history, 1)
        let v6 = try await remote.scenarioProgress().first?.scenarioID
        XCTAssertEqual(v6, "world1990")
        XCTAssertEqual(e.leaderboardManager.entries.count, 1)
    }

    func testLegacyImportBacksUpImportsAndIsIdempotent() async throws {
        let suite = "GTNWTests.store.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var score = GameScore(); score.finalScore = 900; score.playerCountry = "USA"
        defaults.set(try JSONEncoder().encode([LeaderboardEntry(playerName: "Old", score: score)]), forKey: LegacyStoreImport.leaderboardKey)
        defaults.set(["peacemaker"], forKey: LegacyStoreImport.achievementsKey)
        let remote = InMemoryGameStore()
        let service = StoreFixtures.service(dir(), remote: remote)
        try service.local.saves.save(GameState(playerCountryID: "USA", turnLength: .month), slot: 0)
        let backups = dir()

        let report = await LegacyStoreImport.run(service: service, defaults: defaults, domain: suite, backupRoot: backups)
        XCTAssertTrue(report.verified, report.note)
        XCTAssertEqual([report.legacyLeaderboard, report.legacyAchievements, report.legacySlots], [1, 1, 1])
        XCTAssertNil(defaults.object(forKey: LegacyStoreImport.leaderboardKey), "legacy key removed once verified")
        let backupFolder = try XCTUnwrap(report.backupFolder)
        XCTAssertTrue(FileManager.default.fileExists(atPath: backupFolder + "/Saves/autosave.json"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: backupFolder + "/\(suite).plist"))

        let again = await LegacyStoreImport.run(service: service, defaults: defaults, domain: suite, backupRoot: backups)
        XCTAssertTrue(again.verified)
        let counts = try await remote.counts()
        XCTAssertEqual(counts, StoreCounts(slots: 1, leaderboard: 1, history: 0, scenarios: 0, achievements: 1), "rerun adds nothing")
    }
}

// MARK: - Retry / offline

final class GameStoreRetryTests: XCTestCase {
    private var dir: URL!
    override func setUp() { super.setUp(); dir = StoreFixtures.tempDir() }
    override func tearDown() { try? FileManager.default.removeItem(at: dir); super.tearDown() }

    func testOfflineKeepsWritesPendingThenSyncsWhenBack() async throws {
        let remote = InMemoryGameStore()
        await remote.setReachable(false)
        let service = StoreFixtures.service(dir, remote: remote)
        service.recordGameOver(result: StoreFixtures.result(won: true, score: 100), leaderboard: StoreFixtures.leaderboard(score: 100))

        let offline = await service.syncNow()
        XCTAssertFalse(offline)
        XCTAssertEqual(service.pendingCount, 2, "result + leaderboard stay queued")
        XCTAssertEqual(service.records.leaderboard.count, 1, "play continues: the local cache has it")

        await remote.setReachable(true)
        let online = await service.syncNow()
        XCTAssertTrue(online)
        XCTAssertEqual(service.pendingCount, 0)
        let v7 = try await remote.counts().leaderboard
        XCTAssertEqual(v7, 1)
    }

    func testEachPassRetriesWithBackoff() async throws {
        let remote = InMemoryGameStore()
        await remote.setReachable(false)
        let service = StoreFixtures.service(dir, remote: remote, attempts: 3)
        service.local.enqueue(.result(StoreFixtures.result(won: true, score: 1)))
        let before = await remote.callCount
        _ = await service.syncNow()
        let after = await remote.callCount
        XCTAssertGreaterThanOrEqual(after - before, 3)
    }

    func testStatusGoesOfflineThenOnline() async throws {
        let remote = InMemoryGameStore()
        await remote.setReachable(false)
        let service = StoreFixtures.service(dir, remote: remote)
        service.local.enqueue(.achievement(AchievementRecord(id: "x", unlockedAt: Date())))
        _ = await service.syncNow()
        await MainActor.run {}
        XCTAssertEqual(service.status, .offline(pending: 1))
        await remote.setReachable(true)
        _ = await service.syncNow()
        await MainActor.run {}
        XCTAssertEqual(service.status, .online)
    }

    func testLocalOnlyServiceNeverSyncs() async {
        let service = StoreFixtures.service(dir, remote: nil)
        XCTAssertEqual(service.status, .localOnly("test"))
        let ok = await service.syncNow()
        XCTAssertFalse(ok)
    }

    func testRejectedWriteIsDroppedNotRetriedForever() async throws {
        let remote = InMemoryGameStore()
        let service = StoreFixtures.service(dir, remote: remote)
        service.local.enqueue(.leaderboard(StoreFixtures.leaderboard(score: -1)))
        let ok = await service.syncNow()
        XCTAssertTrue(ok)
        XCTAssertEqual(service.pendingCount, 0)
    }
}

// MARK: - Performance (wall-clock budgets, no measure{})

final class GameStorePerformanceTests: XCTestCase {
    private var dir: URL!
    override func setUp() { super.setUp(); dir = StoreFixtures.tempDir() }
    override func tearDown() { try? FileManager.default.removeItem(at: dir); super.tearDown() }

    func testManyLeaderboardRecordsStayFastAndCapped() async throws {
        let store = LocalGameStore(folder: dir, saves: SaveManager(folder: dir.appendingPathComponent("Saves")))
        let start = Date()
        for i in 0..<200 { try store.recordLeaderboard(StoreFixtures.leaderboard(score: i)) }
        XCTAssertLessThan(Date().timeIntervalSince(start), 2.0)
        let v8 = try await store.leaderboard(limit: 1000).count
        XCTAssertEqual(v8, LocalGameStore.maxLeaderboard)
    }

    func testSyncingFiftyPendingResultsIsQuick() async throws {
        let remote = InMemoryGameStore()
        await remote.setReachable(false)
        let service = StoreFixtures.service(dir, remote: remote)
        for i in 0..<50 { service.recordGameOver(result: StoreFixtures.result(won: i % 2 == 0, score: i), leaderboard: nil) }
        await remote.setReachable(true)
        let start = Date()
        let ok = await service.syncNow()
        XCTAssertTrue(ok)
        XCTAssertLessThan(Date().timeIntervalSince(start), 2.0)
        let v9 = try await remote.counts().history
        XCTAssertEqual(v9, 50)
    }
}

// MARK: - Frame

final class GameStoreFrameTests: XCTestCase {

    func testEveryStatusHasALabel() {
        for s in [StoreStatus.localOnly("x"), .offline(pending: 2), .syncing, .online] {
            XCTAssertFalse(s.shortLabel.isEmpty)
            XCTAssertFalse(s.detail.isEmpty)
        }
        XCTAssertEqual(StoreStatus.offline(pending: 2).shortLabel, "OFFLINE · 2")
    }

    #if os(macOS)
    @MainActor
    func testBadgeRendersInBothSkins() {
        let dir = StoreFixtures.tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let service = StoreFixtures.service(dir, remote: nil)
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

    func testDefaultConfigIsValidAndTestHostIsLocalOnly() {
        XCTAssertNoThrow(try GameStoreConfig.defaults.validate())
        XCTAssertTrue(GameStoreService.isTestOrSmokeRun)
        XCTAssertNil(GameStoreService.shared.remote, "the test host must never talk to the real Games DB or Keychain")
    }
}
