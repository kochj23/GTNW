//
//  GoldenExportTests.swift
//  GTNWTests
//
//  Golden fixtures for GTNW Lite (the browser port). A test-only exporter plays a few seeded games with the scripted
//  orders of `ScriptedGame` and writes, per turn, the inputs and the key resulting state as JSON, so a TypeScript port
//  can compare itself against the real game. Format: Documentation/GOLDEN.md.
//
//  It writes only when asked:
//      TEST_RUNNER_GTNW_EXPORT_GOLDEN=/path/to/dir xcodebuild test ... -only-testing:GTNWTests/GoldenExportIntegrationTests
//  (xcodebuild passes TEST_RUNNER_-prefixed variables to the test host without the prefix.)
//

import XCTest
@testable import GTNW

@MainActor
enum GoldenExporter {
    static let format = "gtnw-golden"
    static let version = 1
    static let environmentKey = "GTNW_EXPORT_GOLDEN"

    /// The games exported: an early, a Cold War and a modern board, twelve monthly turns each.
    static let games: [(year: Int, seed: UInt64, turns: Int)] = [(1789, 1789, 12), (1962, 1962, 12), (2025, 2025, 12)]

    struct GameInfo: Codable, Equatable {
        var file: String
        var year: Int
        var seed: String
        var player: String
        var difficulty: String
        var turnLength: String
        var turns: Int
    }

    struct Manifest: Codable, Equatable {
        var format: String
        var version: Int
        var generator: String
        var orders: [String]
        var rngVectors: RNGVectors
        var games: [GameInfo]
    }

    /// The generator's first outputs, so a port can check its SplitMix64 and its float and integer conversions.
    struct RNGVectors: Codable, Equatable {
        var seed: String
        var next: [String]
        var unitDoubles: [Double]
        var d100: [Int]
    }

    struct Turn: Codable, Equatable {
        var turn: Int
        var input: ScriptedGame.Input
        var state: ScriptedGame.Snapshot
    }

    struct Game: Codable, Equatable {
        var format: String
        var version: Int
        var game: GameInfo
        var initial: ScriptedGame.Snapshot
        var turns: [Turn]
    }

    static func hex(_ v: UInt64) -> String { String(format: "%016llx", v) }

    static func vectors(seed: UInt64 = 42) -> RNGVectors {
        var a = GameRNG(seed: seed), b = GameRNG(seed: seed), c = GameRNG(seed: seed)
        return RNGVectors(seed: hex(seed),
                          next: (0..<8).map { _ in hex(a.next()) },
                          unitDoubles: (0..<8).map { _ in Double.random(in: 0..<1, using: &b) },
                          d100: (0..<8).map { _ in Int.random(in: 1...100, using: &c) })
    }

    /// Play one game and return its fixture.
    static func play(year: Int, seed: UInt64, turns: Int) async -> Game {
        let info = GameInfo(file: "game-\(year)-\(hex(seed)).json", year: year, seed: hex(seed), player: "USA",
                            difficulty: DifficultyLevel.normal.rawValue, turnLength: TurnLength.month.rawValue, turns: turns)
        var initial: ScriptedGame.Snapshot?
        var rows: [Turn] = []
        await ScriptedGame.play(year: year, seed: seed, turns: turns, onStart: { initial = ScriptedGame.snapshot($0) }) { input, state in
            rows.append(Turn(turn: state.turn, input: input, state: state))
        }
        var game = info
        game.turns = rows.count
        return Game(format: format, version: version, game: game, initial: initial!, turns: rows)
    }

    /// Write the manifest and one file per game into `dir` (created if missing). Writes nothing else, anywhere.
    @discardableResult
    static func export(to dir: URL, games: [(year: Int, seed: UInt64, turns: Int)]? = nil) async throws -> Manifest {
        let games = games ?? Self.games
        guard dir.isFileURL, dir.path.hasPrefix("/") else { throw CocoaError(.fileWriteInvalidFileName) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        var infos: [GameInfo] = []
        for g in games {
            let game = await play(year: g.year, seed: g.seed, turns: g.turns)
            try enc.encode(game).write(to: dir.appendingPathComponent(game.game.file), options: .atomic)
            infos.append(game.game)
        }
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let manifest = Manifest(format: format, version: Self.version, generator: "GTNW \(version)",
                                orders: ScriptedGame.orders.map(\.rawValue), rngVectors: vectors(), games: infos)
        try enc.encode(manifest).write(to: dir.appendingPathComponent("manifest.json"), options: .atomic)
        return manifest
    }
}

// MARK: - Unit

final class GoldenExportUnitTests: XCTestCase {

    @MainActor
    func testRNGVectorsMatchTheGenerator() {
        let v = GoldenExporter.vectors(seed: 42)
        var r = GameRNG(seed: 42)
        XCTAssertEqual(v.next.first, GoldenExporter.hex(r.next()))
        XCTAssertEqual(v.next.count, 8)
        XCTAssertTrue(v.unitDoubles.allSatisfy { (0..<1).contains($0) })
        XCTAssertTrue(v.d100.allSatisfy { (1...100).contains($0) })
        XCTAssertEqual(v, GoldenExporter.vectors(seed: 42), "vectors are reproducible")
    }

    @MainActor
    func testSnapshotKeysAreTheDocumentedOnes() throws {
        let gs = GameState(playerCountryID: "USA", seed: 1)
        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(ScriptedGame.snapshot(gs))) as? [String: Any]
        XCTAssertEqual(Set((json ?? [:]).keys), ["turn", "date", "defcon", "radiation", "casualties", "popularity", "gameOver",
                                                 "rngState", "wars", "nations"])
        let nation = (json?["nations"] as? [[String: Any]])?.first ?? [:]
        XCTAssertEqual(Set(nation.keys).subtracting(["relationToPlayer"]),
                       ["id", "warheads", "military", "stability", "approval", "destroyed", "atWarWith"])
    }
}

// MARK: - Functional

final class GoldenExportFunctionalTests: XCTestCase {

    @MainActor
    func testExportWritesAManifestAndOneFilePerGame() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("gtnw-golden-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let m = try await GoldenExporter.export(to: dir, games: [(2025, 7, 2)])
        let files = try FileManager.default.contentsOfDirectory(atPath: dir.path).sorted()
        XCTAssertEqual(files, ["game-2025-0000000000000007.json", "manifest.json"])
        let game = try JSONDecoder().decode(GoldenExporter.Game.self, from: Data(contentsOf: dir.appendingPathComponent(files[0])))
        XCTAssertEqual(game.format, "gtnw-golden")
        XCTAssertEqual(game.turns.map(\.turn), [1, 2])
        XCTAssertEqual(game.initial.turn, 0)
        XCTAssertEqual(m.games.first?.turns, 2)
    }
}

// MARK: - Security

final class GoldenExportSecurityTests: XCTestCase {

    @MainActor
    func testExportRefusesARelativePath() async {
        do {
            try await GoldenExporter.export(to: URL(string: "relative/dir")!, games: [])
            XCTFail("a relative path must be refused")
        } catch {}
    }

    func testExporterIsTestOnly() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let files = try XCTUnwrap(FileManager.default.enumerator(at: root.appendingPathComponent("Shared"), includingPropertiesForKeys: nil))
        var scanned = 0
        for case let url as URL in files where url.pathExtension == "swift" {
            scanned += 1
            XCTAssertFalse(try String(contentsOf: url, encoding: .utf8).contains("GTNW_EXPORT_GOLDEN"), url.lastPathComponent)
        }
        XCTAssertGreaterThan(scanned, 50)
    }
}

// MARK: - Integration (the real export, only when asked)

final class GoldenExportIntegrationTests: XCTestCase {

    @MainActor
    func testExportGoldenFixturesWhenAsked() async throws {
        guard let path = ProcessInfo.processInfo.environment[GoldenExporter.environmentKey], !path.isEmpty else {
            throw XCTSkip("set TEST_RUNNER_\(GoldenExporter.environmentKey)=<dir> to write the GTNW Lite golden fixtures")
        }
        let m = try await GoldenExporter.export(to: URL(fileURLWithPath: path, isDirectory: true))
        XCTAssertEqual(m.games.count, GoldenExporter.games.count)
        XCTAssertTrue(m.games.allSatisfy { $0.turns > 0 })
    }
}
