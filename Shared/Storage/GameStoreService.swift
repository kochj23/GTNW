//
//  GameStoreService.swift
//  Global Thermal Nuclear War
//
//  What the game talks to. Every write lands in the local cache first (so play never waits on the network)
//  and is queued; a sync pass pushes the queue to the Games DB and pulls back anything newer. If the DB is
//  unreachable the game keeps going, writes stay pending, and the service retries with backoff
//  (`Retry.run` per pass, growing gaps between passes). `status` drives the top-bar indicator.
//

import Foundation

enum StoreStatus: Equatable {
    /// No DB configured for this run (no CA / credentials, disabled in Settings, tests, iOS without a DB).
    case localOnly(String)
    case offline(pending: Int)
    case syncing
    case online

    var shortLabel: String {
        switch self {
        case .localOnly: return "LOCAL"
        case .offline(let n): return n > 0 ? "OFFLINE · \(n)" : "OFFLINE"
        case .syncing: return "SYNCING"
        case .online: return "DB ONLINE"
        }
    }

    var detail: String {
        switch self {
        case .localOnly(let why): return "Saving on this device only (\(why))."
        case .offline(let n): return "Games DB unreachable. \(n) change(s) saved locally, will sync when it's back."
        case .syncing: return "Syncing with the Games DB…"
        case .online: return "Saved to the Games DB."
        }
    }
}

extension RetryPolicy {
    /// Gap between sync passes while the DB is down: 10s, 20s, 40s … capped at 5 min.
    static let storeReconnect = RetryPolicy(maxAttempts: .max, baseDelay: 10, multiplier: 2, maxDelay: 300)
}

final class GameStoreService: ObservableObject, @unchecked Sendable {

    /// The app's store. Under XCTest or `--launch-smoke` it is a throwaway, local-only store.
    static let shared: GameStoreService = makeDefault()

    @Published private(set) var status: StoreStatus
    /// Bumped whenever cached records change, so views re-read `records`.
    @Published private(set) var revision = 0

    let local: LocalGameStore
    private let lock = NSLock()
    private var _remote: GameStore?
    private var localOnlyReason: String
    private let sleeper: RetrySleeper
    private let passPolicy: RetryPolicy
    private let reconnectPolicy: RetryPolicy
    private lazy var driver = SyncDriver(service: self)

    var remote: GameStore? { lock.lock(); defer { lock.unlock() }; return _remote }
    var records: LocalGameStore.Records { local.snapshot }
    var pendingCount: Int { local.pending.count }

    init(local: LocalGameStore, remote: GameStore?, localOnlyReason: String = "no Games DB configured",
         sleeper: @escaping RetrySleeper = Retry.realSleep, passPolicy: RetryPolicy = .network,
         reconnectPolicy: RetryPolicy = .storeReconnect) {
        self.local = local
        self._remote = remote
        self.localOnlyReason = localOnlyReason
        self.sleeper = sleeper
        self.passPolicy = passPolicy
        self.reconnectPolicy = reconnectPolicy
        self.status = remote == nil ? .localOnly(localOnlyReason) : .offline(pending: local.pending.count)
    }

    // MARK: Factory

    static var isTestOrSmokeRun: Bool {
        NSClassFromString("XCTestCase") != nil
            || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || CommandLine.arguments.contains("--launch-smoke")
    }

    static func makeDefault(defaults: UserDefaults = .standard) -> GameStoreService {
        if isTestOrSmokeRun {
            let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("gtnw-store-\(UUID().uuidString)")
            return GameStoreService(local: LocalGameStore(folder: tmp, saves: SaveManager(folder: tmp.appendingPathComponent("Saves"))),
                                    remote: nil, localOnlyReason: "test run")
        }
        let (remote, reason) = makeRemote(GameStoreConfig.load(defaults))
        return GameStoreService(local: LocalGameStore(), remote: remote, localOnlyReason: reason)
    }

    /// Build the Postgres store from config + CA, or explain why we can't.
    static func makeRemote(_ config: GameStoreConfig) -> (GameStore?, String) {
        guard config.enabled else { return (nil, "Games DB disabled in Settings") }
        do { try config.validate() } catch { return (nil, "\(error)") }
        guard let ca = GameStoreCA.pem() else { return (nil, "no games-pg CA certificate") }
        return (PostgresGameStore(config: config, credentials: KeychainGameStoreCredentials(), caPEM: ca), "")
    }

    /// Settings changed: rebuild the remote and reconnect.
    func reconfigure(_ config: GameStoreConfig) {
        guard !Self.isTestOrSmokeRun else { return }
        let (remote, reason) = Self.makeRemote(config)
        lock.lock(); _remote = remote; localOnlyReason = reason; lock.unlock()
        publish(status: remote == nil ? .localOnly(reason) : .offline(pending: pendingCount))
        requestSync()
    }

    // MARK: Writes (local first, then queue)

    /// A slot file in `local.saves` was just written.
    func slotSaved(_ slot: Int) { enqueue(.putSlot(slot)) }

    func slotDeleted(_ slot: Int) {
        local.saves.delete(slot: slot)
        enqueue(.deleteSlot(slot))
    }

    func recordGameOver(result: GameResultRecord, leaderboard: LeaderboardRecord?) {
        do {
            try local.recordResult(result)
            local.enqueue(.result(result))
            if let leaderboard {
                try local.recordLeaderboard(leaderboard)
                local.enqueue(.leaderboard(leaderboard))
            }
        } catch {
            print("[GameStore] game result rejected: \(error)")
        }
        changed()
    }

    func unlockAchievement(_ id: String, at date: Date = Date()) {
        let a = AchievementRecord(id: id, unlockedAt: date)
        guard (try? local.recordAchievement(a)) != nil else { return }
        enqueue(.achievement(a))
    }

    private func enqueue(_ op: PendingOp) {
        local.enqueue(op)
        changed()
    }

    private func changed() {
        if remote != nil, status != .syncing { publish(status: .offline(pending: pendingCount)) }
        bump()
        requestSync()
    }

    // MARK: Sync

    /// Kick a sync in the background (coalesces with one already running).
    func requestSync() {
        guard remote != nil else { return }
        Task { await driver.run() }
    }

    /// Run a sync pass now and wait for it. Returns true when everything pending reached the DB.
    @discardableResult
    func syncNow() async -> Bool { await driver.run() }

    enum PassOutcome { case ok, retryLater, giveUp }

    /// One pass: push the queue, then pull. Retried a few times with backoff before giving up for now.
    fileprivate func syncPass() async -> PassOutcome {
        guard let remote else { return .giveUp }
        publish(status: .syncing)
        do {
            try await Retry.run("Games DB sync", policy: passPolicy, sleep: sleeper,
                                shouldRetry: { ($0 as? GameStoreError)?.isRetryable ?? true }) {
                try await self.push(to: remote)
                try await self.pull(from: remote)
            }
            publish(status: .online)
            bump()
            return .ok
        } catch {
            let e = (error as? GameStoreError) ?? .unreachable(String(describing: type(of: error)))
            print("[GameStore] sync failed: \(e)")
            if case .notConfigured(let why) = e {
                publish(status: .localOnly(why))
                return .giveUp   // e.g. no Keychain item: don't nag; retried on next launch / Settings change
            }
            publish(status: .offline(pending: pendingCount))
            return .retryLater
        }
    }

    fileprivate func reconnectDelay(failures: Int) -> TimeInterval { reconnectPolicy.delay(afterAttempt: failures) }
    fileprivate var sleep: RetrySleeper { sleeper }

    private func push(to remote: GameStore) async throws {
        for op in local.pending {
            do {
                switch op {
                case .putSlot(let slot):
                    if let r = try local.slotRecord(slot) { try await remote.putSlot(r) }
                case .deleteSlot(let slot): try await remote.deleteSlot(slot)
                case .leaderboard(let r): try await remote.addLeaderboard(r)
                case .result(let r): try await remote.addResult(r)
                case .achievement(let a): try await remote.unlock(a)
                }
                local.complete(op)
            } catch let e as GameStoreError {
                guard case .invalid = e else { throw e }
                print("[GameStore] dropping a write the store rejected: \(e)")   // never retry hostile/corrupt data
                local.complete(op)
            }
        }
    }

    private func pull(from remote: GameStore) async throws {
        let pendingSlots = Set(local.pending.compactMap(\.slot))
        for summary in try await remote.listSlots() where !pendingSlots.contains(summary.slot) {
            let mine = local.saves.modified(slot: summary.slot)
            guard mine == nil || summary.updatedAt.timeIntervalSince(mine!) > 1 else { continue }
            guard let record = try await remote.getSlot(summary.slot) else { continue }
            do { try await local.putSlot(record) } catch { print("[GameStore] ignoring remote slot \(summary.slot): \(error)") }
        }
        local.merge(leaderboard: try await remote.leaderboard(limit: LocalGameStore.maxLeaderboard),
                    history: try await remote.history(limit: LocalGameStore.maxHistory),
                    progress: try await remote.scenarioProgress(),
                    achievements: try await remote.achievements())
    }

    // MARK: Publishing (main thread)

    private func publish(status s: StoreStatus) {
        if Thread.isMainThread { if status != s { status = s } } else { DispatchQueue.main.async { if self.status != s { self.status = s } } }
    }

    private func bump() {
        if Thread.isMainThread { revision += 1 } else { DispatchQueue.main.async { self.revision += 1 } }
    }
}

/// Serializes sync passes and owns the reconnect backoff. A caller that arrives while a pass is running
/// waits for it, and the running loop does one more pass so the caller's new writes are included.
private actor SyncDriver {
    private unowned let service: GameStoreService
    private var inflight: Task<Bool, Never>?
    private var again = false
    private var failures = 0
    private var retryTask: Task<Void, Never>?

    init(service: GameStoreService) { self.service = service }

    @discardableResult
    func run() async -> Bool {
        if let t = inflight { again = true; return await t.value }
        retryTask?.cancel(); retryTask = nil
        let t = Task { await self.loop() }
        inflight = t
        return await t.value
    }

    private func loop() async -> Bool {
        var outcome: GameStoreService.PassOutcome
        repeat {
            again = false
            outcome = await service.syncPass()
        } while again && outcome == .ok
        inflight = nil   // same actor turn as the final `again` check: no caller can slip in between
        switch outcome {
        case .ok: failures = 0; return true
        case .giveUp: return false
        case .retryLater:
            failures += 1
            let delay = service.reconnectDelay(failures: failures), sleep = service.sleep
            retryTask = Task { [weak self] in
                await sleep(delay)
                guard !Task.isCancelled else { return }
                await self?.run()
            }
            return false
        }
    }
}

// MARK: - CA certificate

enum GameStoreCA {
    /// Override: drop a CA at Application Support/GTNW/games-pg-ca.crt. Otherwise the copy bundled with the app.
    static var overrideURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("GTNW/games-pg-ca.crt")
    }

    static func pem(bundle: Bundle = .main) -> Data? {
        for url in [overrideURL, bundle.url(forResource: "games-pg-ca", withExtension: "crt")].compactMap({ $0 }) {
            if let d = try? Data(contentsOf: url), d.count < 64 * 1024,
               String(decoding: d, as: UTF8.self).contains("-----BEGIN CERTIFICATE-----") { return d }
        }
        return nil
    }
}
