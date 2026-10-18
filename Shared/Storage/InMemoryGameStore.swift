//
//  InMemoryGameStore.swift
//  Global Thermal Nuclear War
//
//  A `GameStore` that lives in memory. Tests use it as the "remote" (with `reachable = false` to simulate
//  the DB being down); it applies the same validation and idempotency rules as `PostgresGameStore`.
//

import Foundation

actor InMemoryGameStore: GameStore {
    private var slots: [Int: SaveRecord] = [:]
    private var board: [UUID: LeaderboardRecord] = [:]
    private var results: [UUID: GameResultRecord] = [:]
    private var progress: [String: ScenarioProgress] = [:]
    private var unlocked: [String: AchievementRecord] = [:]

    /// Flip to false to make every call throw `.unreachable` (simulated outage).
    var reachable = true
    /// Number of calls that reached the store (reachable or not).
    private(set) var callCount = 0

    init() {}

    func setReachable(_ value: Bool) { reachable = value }

    private func gate() throws {
        callCount += 1
        guard reachable else { throw GameStoreError.unreachable("in-memory store is offline") }
    }

    func putSlot(_ record: SaveRecord) async throws {
        try gate()
        try StoreValidation.check(record)
        if let existing = slots[record.slot], existing.updatedAt > record.updatedAt { return }   // last writer wins
        slots[record.slot] = record
    }

    func getSlot(_ slot: Int) async throws -> SaveRecord? { try gate(); return slots[slot] }

    func listSlots() async throws -> [SlotSummary] {
        try gate()
        return slots.values.sorted { $0.slot < $1.slot }.map {
            SlotSummary(slot: $0.slot, label: $0.label, turn: $0.turn, schemaVersion: $0.schemaVersion,
                        size: $0.payload.count, updatedAt: $0.updatedAt)
        }
    }

    func deleteSlot(_ slot: Int) async throws { try gate(); slots[slot] = nil }

    func addLeaderboard(_ record: LeaderboardRecord) async throws {
        try gate()
        try StoreValidation.check(record)
        if board[record.id] == nil { board[record.id] = record }
    }

    func leaderboard(limit: Int) async throws -> [LeaderboardRecord] {
        try gate()
        return Array(board.values.sorted { ($0.finalScore, $1.achievedAt) > ($1.finalScore, $0.achievedAt) }.prefix(max(0, limit)))
    }

    func addResult(_ record: GameResultRecord) async throws {
        try gate()
        try StoreValidation.check(record)
        guard results[record.id] == nil else { return }
        results[record.id] = record
        progress[record.scenarioID] = ScenarioProgress.applying(record, to: progress[record.scenarioID])
    }

    func history(limit: Int) async throws -> [GameResultRecord] {
        try gate()
        return Array(results.values.sorted { $0.endedAt > $1.endedAt }.prefix(max(0, limit)))
    }

    func scenarioProgress() async throws -> [ScenarioProgress] {
        try gate()
        return progress.values.sorted { $0.scenarioID < $1.scenarioID }
    }

    func unlock(_ achievement: AchievementRecord) async throws {
        try gate()
        try StoreValidation.check(achievement)
        if let existing = unlocked[achievement.id], existing.unlockedAt <= achievement.unlockedAt { return }
        unlocked[achievement.id] = achievement
    }

    func achievements() async throws -> [AchievementRecord] {
        try gate()
        return unlocked.values.sorted { $0.id < $1.id }
    }

    func counts() async throws -> StoreCounts {
        try gate()
        return StoreCounts(slots: slots.count, leaderboard: board.count, history: results.count,
                           scenarios: progress.count, achievements: unlocked.count)
    }
}
