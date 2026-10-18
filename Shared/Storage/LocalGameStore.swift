//
//  LocalGameStore.swift
//  Global Thermal Nuclear War
//
//  The on-device cache. Save slots stay as JSON files (the `SaveManager` folder, so old saves keep working);
//  leaderboard / history / scenario progress / achievements live in `records.json`; writes that still need to
//  reach the Games DB are queued in `pending.json`. Everything works with no network.
//

import Foundation

/// A write that hasn't reached the Games DB yet. Replayed in order; every op is idempotent remotely.
enum PendingOp: Codable, Equatable, Sendable {
    /// Upload the slot's current local contents (read at sync time, so only the latest save is sent).
    case putSlot(Int)
    case deleteSlot(Int)
    case leaderboard(LeaderboardRecord)
    case result(GameResultRecord)
    case achievement(AchievementRecord)

    var slot: Int? {
        switch self {
        case .putSlot(let s), .deleteSlot(let s): return s
        default: return nil
        }
    }
}

final class LocalGameStore: GameStore, @unchecked Sendable {
    struct Records: Codable, Equatable {
        var leaderboard: [LeaderboardRecord] = []
        var history: [GameResultRecord] = []
        var progress: [ScenarioProgress] = []
        var achievements: [AchievementRecord] = []
    }

    static let maxLeaderboard = 100
    static let maxHistory = 500
    static let maxPending = 2_000

    let saves: SaveManager
    let folder: URL
    private let lock = NSLock()
    private var records: Records
    private var queue: [PendingOp]

    static var defaultFolder: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("GTNW/Store", isDirectory: true)
    }

    /// - Parameters:
    ///   - folder: records + pending queue.
    ///   - saves: the slot folder (defaults to the classic `GTNW/Saves`).
    init(folder: URL = LocalGameStore.defaultFolder, saves: SaveManager = SaveManager()) {
        self.folder = folder
        self.saves = saves
        records = Self.read(Records.self, folder.appendingPathComponent("records.json")) ?? Records()
        queue = Self.read([PendingOp].self, folder.appendingPathComponent("pending.json")) ?? []
    }

    // MARK: File helpers

    private static func read<T: Decodable>(_ type: T.Type, _ url: URL) -> T? {
        guard let size = (try? FileManager.default.attributesOfItem(atPath: url.path))?[.size] as? NSNumber,
              size.intValue <= 32 * 1024 * 1024,
              let data = try? Data(contentsOf: url) else { return nil }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return try? dec.decode(type, from: data)
    }

    private func write<T: Encodable>(_ value: T, _ name: String) {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try enc.encode(value).write(to: folder.appendingPathComponent(name), options: .atomic)
        } catch {
            print("[GameStore] local write \(name) failed: \(error.localizedDescription)")
        }
    }

    private func locked<T>(_ body: () throws -> T) rethrows -> T {
        lock.lock(); defer { lock.unlock() }
        return try body()
    }

    // MARK: Pending queue

    var pending: [PendingOp] { locked { queue } }

    /// Queue a write. A newer slot op replaces any older op for the same slot.
    func enqueue(_ op: PendingOp) {
        locked {
            if let slot = op.slot { queue.removeAll { $0.slot == slot } }
            if !queue.contains(op) { queue.append(op) }
            if queue.count > Self.maxPending { queue.removeFirst(queue.count - Self.maxPending) }
            write(queue, "pending.json")
        }
    }

    /// Drop an op once it reached the DB (or was rejected for good).
    func complete(_ op: PendingOp) {
        locked {
            if let i = queue.firstIndex(of: op) { queue.remove(at: i) }
            write(queue, "pending.json")
        }
    }

    // MARK: Snapshot for the UI

    var snapshot: Records { locked { records } }

    // MARK: GameStore — slots

    func putSlot(_ record: SaveRecord) async throws {
        try StoreValidation.check(record)
        _ = try SaveCodec.decode(record.payload, schemaVersion: record.schemaVersion)
        try saves.write(record.payload, slot: record.slot, modified: record.updatedAt)
    }

    func getSlot(_ slot: Int) async throws -> SaveRecord? { try slotRecord(slot) }

    /// Synchronous read of a slot as a record (validated).
    func slotRecord(_ slot: Int) throws -> SaveRecord? {
        guard StoreValidation.slotRange.contains(slot), let modified = saves.modified(slot: slot) else { return nil }
        let data = try saves.data(slot: slot)
        let gs = try SaveCodec.decode(data)
        return SaveRecord(slot: slot, schemaVersion: SaveCodec.currentSchemaVersion, payload: data,
                          label: SaveCodec.label(for: gs), turn: gs.turn, updatedAt: modified)
    }

    func listSlots() async throws -> [SlotSummary] {
        StoreValidation.slotRange.compactMap { slot in
            guard let r = try? slotRecord(slot) else { return nil }
            return SlotSummary(slot: slot, label: r.label, turn: r.turn, schemaVersion: r.schemaVersion,
                               size: r.payload.count, updatedAt: r.updatedAt)
        }
    }

    func deleteSlot(_ slot: Int) async throws { saves.delete(slot: slot) }

    // MARK: GameStore — records

    func addLeaderboard(_ record: LeaderboardRecord) async throws { try recordLeaderboard(record) }

    func recordLeaderboard(_ record: LeaderboardRecord) throws {
        try StoreValidation.check(record)
        locked {
            guard !records.leaderboard.contains(where: { $0.id == record.id }) else { return }
            records.leaderboard.append(record)
            records.leaderboard = Self.ranked(records.leaderboard)
            write(records, "records.json")
        }
    }

    func leaderboard(limit: Int) async throws -> [LeaderboardRecord] {
        locked { Array(records.leaderboard.prefix(max(0, limit))) }
    }

    func addResult(_ record: GameResultRecord) async throws { try recordResult(record) }

    func recordResult(_ record: GameResultRecord) throws {
        try StoreValidation.check(record)
        locked {
            guard !records.history.contains(where: { $0.id == record.id }) else { return }
            records.history.insert(record, at: 0)
            records.history.sort { $0.endedAt > $1.endedAt }
            if records.history.count > Self.maxHistory { records.history.removeLast(records.history.count - Self.maxHistory) }
            let i = records.progress.firstIndex { $0.scenarioID == record.scenarioID }
            let updated = ScenarioProgress.applying(record, to: i.map { records.progress[$0] })
            if let i { records.progress[i] = updated } else { records.progress.append(updated) }
            write(records, "records.json")
        }
    }

    func history(limit: Int) async throws -> [GameResultRecord] { locked { Array(records.history.prefix(max(0, limit))) } }

    func scenarioProgress() async throws -> [ScenarioProgress] { locked { records.progress } }

    func unlock(_ achievement: AchievementRecord) async throws { try recordAchievement(achievement) }

    func recordAchievement(_ achievement: AchievementRecord) throws {
        try StoreValidation.check(achievement)
        locked {
            if let i = records.achievements.firstIndex(where: { $0.id == achievement.id }) {
                guard achievement.unlockedAt < records.achievements[i].unlockedAt else { return }
                records.achievements[i] = achievement
            } else {
                records.achievements.append(achievement)
            }
            write(records, "records.json")
        }
    }

    func achievements() async throws -> [AchievementRecord] { locked { records.achievements } }

    func counts() async throws -> StoreCounts {
        let slots = StoreValidation.slotRange.filter { saves.modified(slot: $0) != nil }.count
        return locked {
            StoreCounts(slots: slots, leaderboard: records.leaderboard.count, history: records.history.count,
                        scenarios: records.progress.count, achievements: records.achievements.count)
        }
    }

    // MARK: Merge what the DB has (after our pending writes were pushed, the DB is a superset)

    func merge(leaderboard: [LeaderboardRecord], history: [GameResultRecord], progress: [ScenarioProgress],
               achievements: [AchievementRecord]) {
        locked {
            var board = Dictionary(records.leaderboard.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
            for r in leaderboard where (try? StoreValidation.check(r)) != nil { board[r.id] = r }
            records.leaderboard = Self.ranked(Array(board.values))

            var hist = Dictionary(records.history.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
            for r in history where (try? StoreValidation.check(r)) != nil { hist[r.id] = r }
            records.history = Array(hist.values.sorted { $0.endedAt > $1.endedAt }.prefix(Self.maxHistory))

            var prog = Dictionary(records.progress.map { ($0.scenarioID, $0) }, uniquingKeysWith: { a, _ in a })
            for p in progress where StoreValidation.isIdentifier(p.scenarioID) { prog[p.scenarioID] = p }
            records.progress = prog.values.sorted { $0.scenarioID < $1.scenarioID }

            var ach = Dictionary(records.achievements.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
            for a in achievements where StoreValidation.isIdentifier(a.id) {
                if let old = ach[a.id], old.unlockedAt <= a.unlockedAt { continue }
                ach[a.id] = a
            }
            records.achievements = ach.values.sorted { $0.id < $1.id }
            write(records, "records.json")
        }
    }

    static func ranked(_ list: [LeaderboardRecord]) -> [LeaderboardRecord] {
        Array(list.sorted { ($0.finalScore, $1.achievedAt) > ($1.finalScore, $0.achievedAt) }.prefix(maxLeaderboard))
    }
}
