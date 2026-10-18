//
//  LegacyStoreImport.swift
//  Global Thermal Nuclear War
//
//  One-time move of pre-Games-DB state into the store:
//    - UserDefaults `GTNW_Leaderboard` (JSON [LeaderboardEntry]) → leaderboard
//    - UserDefaults `gtnw_achievements` ([String])               → achievements
//    - save files in Application Support/GTNW/Saves             → save_slots (queued for upload)
//  Backs up the preferences domain and the save files first. Idempotent: ids are deterministic and slot
//  writes are upserts, so running it again changes nothing. The legacy UserDefaults keys are removed only
//  after the Games DB confirms it holds at least as many rows as were imported.
//

import Foundation

struct LegacyImportReport: Codable, Equatable {
    var backupFolder: String?
    var legacyLeaderboard = 0
    var legacyAchievements = 0
    var legacySlots = 0
    var localAfter = StoreCountsCodable()
    var remoteAfter: StoreCountsCodable?
    var synced = false
    var verified = false
    var legacyKeysRemoved = false
    var note = ""

    struct StoreCountsCodable: Codable, Equatable {
        var slots = 0, leaderboard = 0, history = 0, scenarios = 0, achievements = 0
        init() {}
        init(_ c: StoreCounts) {
            slots = c.slots; leaderboard = c.leaderboard; history = c.history; scenarios = c.scenarios; achievements = c.achievements
        }
    }
}

enum LegacyStoreImport {
    static let leaderboardKey = "GTNW_Leaderboard"
    static let achievementsKey = "gtnw_achievements"
    /// Set once the import is verified against the DB (a flag, not game state).
    static let doneKey = "GTNW.store.legacyImport.v1"
    /// Path of the backup taken before the first import, so later retries don't back up again.
    static let backupKey = "GTNW.store.legacyBackup.v1"

    static var defaultBackupRoot: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("GTNW/Backups", isDirectory: true)
    }

    static func hasLegacyData(_ defaults: UserDefaults) -> Bool {
        defaults.object(forKey: leaderboardKey) != nil || defaults.object(forKey: achievementsKey) != nil
    }

    /// Run at app start: imports when there's legacy data or the import was never verified.
    static func runIfNeeded(service: GameStoreService, defaults: UserDefaults = .standard) async -> LegacyImportReport? {
        guard hasLegacyData(defaults) || !defaults.bool(forKey: doneKey) else { return nil }
        return await run(service: service, defaults: defaults, domain: Bundle.main.bundleIdentifier, backupRoot: defaultBackupRoot)
    }

    /// - Parameters:
    ///   - domain: the UserDefaults persistent domain to back up (bundle id, or a test suite name).
    ///   - backupRoot: a timestamped folder is created inside it before anything changes.
    static func run(service: GameStoreService, defaults: UserDefaults, domain: String?, backupRoot: URL,
                    now: Date = Date(), alwaysBackup: Bool = false) async -> LegacyImportReport {
        var report = LegacyImportReport()
        let saves = service.local.saves
        let slotNumbers = StoreValidation.slotRange.filter { saves.modified(slot: $0) != nil }
        let legacyBoard: [LeaderboardEntry] = defaults.data(forKey: leaderboardKey)
            .flatMap { $0.count <= 4 * 1024 * 1024 ? $0 : nil }
            .flatMap { try? JSONDecoder().decode([LeaderboardEntry].self, from: $0) } ?? []
        let legacyAchievements = (defaults.array(forKey: achievementsKey) as? [String] ?? []).filter { StoreValidation.isIdentifier($0) }
        report.legacyLeaderboard = legacyBoard.count
        report.legacyAchievements = legacyAchievements.count
        report.legacySlots = slotNumbers.count

        // 1. Back up first (once, and only if there is anything to back up).
        if !alwaysBackup, let previous = defaults.string(forKey: backupKey) {
            report.backupFolder = previous
        } else if alwaysBackup || !legacyBoard.isEmpty || !legacyAchievements.isEmpty || !slotNumbers.isEmpty {
            do {
                let folder = try backup(defaults: defaults, domain: domain, saves: saves, slots: slotNumbers, root: backupRoot, now: now)
                report.backupFolder = folder.path
                defaults.set(folder.path, forKey: backupKey)
            } catch {
                report.note = "backup failed, nothing imported: \(error.localizedDescription)"
                return report
            }
        }

        // 2. Import into the local cache and queue for the DB (idempotent).
        for entry in legacyBoard {
            let r = LeaderboardRecord(entry: entry)
            if (try? service.local.recordLeaderboard(r)) != nil { service.local.enqueue(.leaderboard(r)) }
        }
        for id in legacyAchievements {
            let a = AchievementRecord(id: id, unlockedAt: now)
            if (try? service.local.recordAchievement(a)) != nil { service.local.enqueue(.achievement(a)) }
        }
        for slot in slotNumbers where (try? service.local.slotRecord(slot)) != nil {
            service.local.enqueue(.putSlot(slot))
        }
        if let local = try? await service.local.counts() { report.localAfter = .init(local) }

        // 3. Sync and verify against the DB.
        guard let remote = service.remote else {
            report.note = "Games DB not configured; imported into the local cache, will sync later"
            return report
        }
        report.synced = await service.syncNow()
        guard report.synced, let counts = try? await remote.counts() else {
            report.note = "Games DB unreachable; imported into the local cache, pending sync"
            return report
        }
        report.remoteAfter = .init(counts)
        let distinctBoard = Set(legacyBoard.map(\.id)).count
        report.verified = service.local.pending.isEmpty
            && counts.leaderboard >= distinctBoard
            && counts.achievements >= Set(legacyAchievements).count
            && counts.slots >= slotNumbers.count
        if report.verified {
            defaults.removeObject(forKey: leaderboardKey)
            defaults.removeObject(forKey: achievementsKey)
            defaults.set(true, forKey: doneKey)
            report.legacyKeysRemoved = true
        } else {
            report.note = "DB counts lower than imported; legacy keys kept"
        }
        return report
    }

    /// Copy the preferences domain (as a plist) and the save files into `<root>/<yyyyMMdd-HHmmss>/`.
    static func backup(defaults: UserDefaults, domain: String?, saves: SaveManager, slots: [Int], root: URL, now: Date) throws -> URL {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyyMMdd-HHmmss"
        let folder = root.appendingPathComponent(f.string(from: now), isDirectory: true)
        let fm = FileManager.default
        try fm.createDirectory(at: folder.appendingPathComponent("Saves"), withIntermediateDirectories: true)
        var prefs = domain.flatMap { defaults.persistentDomain(forName: $0) } ?? [:]
        for key in [leaderboardKey, achievementsKey] { if let v = defaults.object(forKey: key) { prefs[key] = v } }
        let plist = try PropertyListSerialization.data(fromPropertyList: prefs, format: .xml, options: 0)
        try plist.write(to: folder.appendingPathComponent("\(domain ?? "gtnw-defaults").plist"), options: .atomic)
        for slot in slots {
            let src = saves.url(slot: slot)
            try fm.copyItem(at: src, to: folder.appendingPathComponent("Saves").appendingPathComponent(src.lastPathComponent))
        }
        return folder
    }
}

extension GameStoreService {
    /// App start: one-time legacy import (if needed), then a first sync.
    func start(defaults: UserDefaults = .standard) {
        guard !Self.isTestOrSmokeRun else { return }
        Task {
            if let report = await LegacyStoreImport.runIfNeeded(service: self, defaults: defaults) {
                print("[GameStore] legacy import: \(report)")
            }
            await self.syncNow()
        }
    }
}
