//
//  CartographyHall.swift
//  Global Thermal Nuclear War
//
//  3.36.0: the Hall of Cartography, every name the President has given a land or a nation, across all his games:
//  which game, the date in that game, the old name and the new one. It is kept beside the local game store
//  (`cartography.json` in the store's folder), never in a save, a replay or the determinism checks. In the
//  WebAssembly engine and under tests it lives in memory unless a folder is set.
//
//  Read API for other features: `CartographyHall.lastName(forLand:)` (the last name the President gave a land in
//  any game, e.g. to offer it again when he claims Antarctica).
//  Repository: https://github.com/kochj23/GTNW
//

import Foundation

/// One name the President gave, in one game.
struct CartographyEntry: Codable, Hashable, Identifiable, Sendable {
    var id = UUID()
    /// Which game: seed, nation and start date (the chat transcript's key).
    var game: String
    /// "United States, 1962".
    var gameLabel: String
    /// The renamed thing's id (a country or land id; another kind's own id) and kind ("nation", "land", …).
    var targetID: String
    var kind: String
    var from: String
    var to: String
    /// The in-game date of the rename.
    var gameDate: Date
    /// When it happened on the President's clock.
    var recordedAt: Date
}

enum CartographyHall {
    static let cap = 2_000
    static let fileName = "cartography.json"

    /// Where the hall is kept; nil keeps it in memory only.
    #if GTNW_CORE
    nonisolated(unsafe) static var folder: URL? = nil
    #else
    nonisolated(unsafe) static var folder: URL? = AudioGate.underXCTest ? nil : LocalGameStore.defaultFolder
    #endif

    private static let lock = NSLock()
    nonisolated(unsafe) private static var cache: [CartographyEntry]?
    nonisolated(unsafe) private static var cacheFolder: URL?

    static func gameKey(_ gs: GameState) -> String {
        "\(String(gs.rng.seed, radix: 16))-\(gs.playerCountryID)-\(Int(gs.startDate.timeIntervalSince1970))"
    }

    static func gameLabel(_ gs: GameState) -> String {
        let nation = WorldCountriesDatabase.template(id: gs.playerCountryID)?.name ?? gs.playerCountryID
        return "\(nation), \(GameCalendar.year(of: gs.startDate))"
    }

    /// Every name, newest first.
    static func entries() -> [CartographyEntry] {
        lock.lock(); defer { lock.unlock() }
        return loaded().reversed()
    }

    /// The last name the President gave this land (or nation), in any game; nil if he never named it.
    static func lastName(forLand id: String) -> String? {
        lock.lock(); defer { lock.unlock() }
        return loaded().last { $0.targetID == id && !NameScreen.isBlocked($0.to) }?.to
    }

    static func record(_ t: RenameTarget, kind: String, from: String, to: String, in gs: GameState, at now: Date = Date()) {
        lock.lock(); defer { lock.unlock() }
        var all = loaded()
        all.append(CartographyEntry(game: gameKey(gs), gameLabel: gameLabel(gs), targetID: t.id, kind: kind, from: from, to: to,
                                    gameDate: gs.currentDate, recordedAt: now))
        if all.count > cap { all.removeFirst(all.count - cap) }
        cache = all
        guard let folder else { return }
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try JSONEncoder().encode(all).write(to: folder.appendingPathComponent(fileName), options: .atomic)
        } catch {
            // The hall is a keepsake; a failed write never stops the game.
        }
    }

    /// Forget the in-memory copy (tests, or after the folder changes).
    static func reset() {
        lock.lock(); defer { lock.unlock() }
        cache = nil
        cacheFolder = nil
    }

    /// Call with the lock held.
    private static func loaded() -> [CartographyEntry] {
        if let cache, cacheFolder == folder { return cache }
        var all: [CartographyEntry] = []
        if let folder, let data = try? Data(contentsOf: folder.appendingPathComponent(fileName)),
           let decoded = try? JSONDecoder().decode([CartographyEntry].self, from: data) {
            all = Array(decoded.suffix(cap))
        }
        cache = all
        cacheFolder = folder
        return all
    }
}
