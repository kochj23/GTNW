//
//  DeterminismTests.swift
//  GTNWTests
//
//  3.33.0: full determinism. Every gameplay roll goes through the game's `GameRNG` (saved with the game), so two
//  games built from one seed and played with the same orders are the same game. Unit, Functional, Integration,
//  Security and Retry. `ScriptedGame` is also the harness behind the GTNW Lite golden fixtures (GoldenExportTests).
//

import XCTest
@testable import GTNW

// MARK: - Harness

/// One seeded game played with fixed orders through the real turn loop (`endTurn`, including the computer's moves).
@MainActor
enum ScriptedGame {

    /// The orders, in turn order (wrapping). Each is a real Situation Room action aimed at a target chosen by index
    /// into the sorted ids of the live computer-run nations, so the script needs no era-specific country list.
    static let orders: [PresidentialAction] = [.sendAmbassador, .tradeDeal, .militaryExercise, .economicAid, .summit, .demandApology]

    /// What the player did on one turn.
    struct Input: Codable, Equatable {
        var action: String
        var target: String?
        /// The crisis option chosen (always 0) when a decision was waiting, else nil.
        var crisisOption: Int?
    }

    /// The key state after one turn, in a form a port can compare against.
    struct Snapshot: Codable, Equatable {
        struct Nation: Codable, Equatable {
            var id: String
            var warheads: Int
            var military: Int
            var stability: Int
            var approval: Int
            var destroyed: Bool
            var atWarWith: [String]
            var relationToPlayer: Int?
        }
        var turn: Int
        var date: String
        var defcon: Int
        var radiation: Int
        var casualties: Int
        var popularity: Double
        var gameOver: Bool
        /// The RNG's state as 16 hex digits (a UInt64 does not survive a JSON number in JavaScript).
        var rngState: String
        var wars: [String]
        var nations: [Nation]
    }

    static func target(turn: Int, in gs: GameState) -> String? {
        let ids = gs.liveCountries.filter { !$0.isPlayerControlled }.map(\.id).sorted()
        return ids.isEmpty ? nil : ids[(turn * 7) % ids.count]
    }

    static func snapshot(_ gs: GameState) -> Snapshot {
        let me = gs.playerCountryID
        return Snapshot(
            turn: gs.turn, date: GameCalendar.format(gs.currentDate), defcon: gs.defconLevel.rawValue,
            radiation: gs.globalRadiation, casualties: gs.totalCasualties, popularity: (gs.shadow.popularity * 100).rounded() / 100,
            gameOver: gs.gameOver, rngState: String(format: "%016llx", gs.rng.state),
            wars: gs.activeWars.map { "\($0.aggressor)>\($0.defender)" }.sorted(),
            nations: gs.countries.sorted { $0.id < $1.id }.map {
                Snapshot.Nation(id: $0.id, warheads: $0.nuclearWarheads, military: $0.militaryStrength, stability: $0.stability,
                                approval: $0.publicApproval, destroyed: $0.isDestroyed, atWarWith: $0.atWarWith.sorted(),
                                relationToPlayer: $0.id == me ? nil : $0.diplomaticRelations[me])
            })
    }

    /// Wait for the computer's moves (they run in a main-actor Task started by `endTurn`).
    static func settle(_ e: GameEngine) async {
        for _ in 0..<2_000 where e.isProcessingAITurn { await Task.yield() }
        for _ in 0..<500 where e.isProcessingAITurn { try? await Task.sleep(nanoseconds: 2_000_000) }
    }

    /// Play `turns` turns from `year` with `seed`. `onTurn` sees each turn's input and resulting snapshot.
    @discardableResult
    static func play(year: Int, seed: UInt64, turns: Int, difficulty: DifficultyLevel = .normal,
                     onStart: (GameState) -> Void = { _ in },
                     onTurn: (Input, Snapshot) -> Void = { _, _ in }) async -> GameEngine {
        let e = GameEngine()
        e.startNewGame(difficulty: difficulty, turnLength: .month, year: year, seed: seed)
        if let gs = e.gameState { onStart(gs) }
        for t in 0..<turns {
            guard let gs = e.gameState, !gs.gameOver else { break }
            var input = Input(action: "none", target: nil, crisisOption: nil)
            if e.crisisManager.activeCrisis != nil {
                var g = gs
                e.crisisManager.resolveCrisis(optionIndex: 0, gameState: &g)
                input.crisisOption = 0
            }
            let order = orders[t % orders.count]
            if let target = target(turn: t, in: gs) {
                e.executeShadowPresidentAction(order, from: gs.playerCountryID, to: target)
                input.action = order.rawValue
                input.target = target
            }
            e.endTurn()
            await settle(e)
            onTurn(input, snapshot(e.gameState ?? gs))
        }
        return e
    }
}

// MARK: - Unit

final class DeterminismUnitTests: XCTestCase {

    func testSameSeedSameStartingBoard() {
        let a = GameState(playerCountryID: "USA", seed: 42), b = GameState(playerCountryID: "USA", seed: 42)
        XCTAssertEqual(a.rng, b.rng)
        XCTAssertEqual(a.countries.map(\.publicApproval), b.countries.map(\.publicApproval))
        XCTAssertEqual(a.countries.map(\.debtLevel), b.countries.map(\.debtLevel))
        XCTAssertEqual(a.countries.map { $0.diplomaticRelations.sorted { $0.key < $1.key }.map(\.value) },
                       b.countries.map { $0.diplomaticRelations.sorted { $0.key < $1.key }.map(\.value) })
    }

    func testStartingOpinionStaysInItsOldRange() {
        let gs = GameState(playerCountryID: "USA", seed: 7)
        for c in gs.countries {
            XCTAssertTrue((20...100).contains(c.debtLevel), c.id)
            if c.government == .democracy || c.government == .republic {
                XCTAssertTrue((40...60).contains(c.publicApproval), c.id)
                XCTAssertTrue((20...40).contains(c.warSupport), c.id)
            }
        }
    }

    func testTurnScaleIntegerUsesTheGameRNG() {
        var a = GameRNG(seed: 9), b = GameRNG(seed: 9)
        let s = TurnScale(.month)
        let x = (0..<50).map { _ in s.integer(annual: 7, using: &a) }
        let y = (0..<50).map { _ in s.integer(annual: 7, using: &b) }
        XCTAssertEqual(x, y)
        XCTAssertEqual(a, b, "both generators advanced the same")
    }

    @MainActor
    func testGameRollDrawsFromTheGame() {
        let e = GameEngine()
        XCTAssertEqual(e.gameRoll(), 0.5, "no game, nothing to decide")
        e.startNewGame(turnLength: .month, seed: 5)
        let before = e.gameState!.rng
        _ = e.gameRoll()
        XCTAssertNotEqual(e.gameState!.rng, before)
    }
}

// MARK: - Functional

final class DeterminismFunctionalTests: XCTestCase {

    @MainActor
    func testDifferentSeedsDiverge() async {
        var a: [ScriptedGame.Snapshot] = [], b: [ScriptedGame.Snapshot] = []
        await ScriptedGame.play(year: 2025, seed: 1, turns: 3) { a.append($1) }
        await ScriptedGame.play(year: 2025, seed: 2, turns: 3) { b.append($1) }
        XCTAssertNotEqual(a, b)
    }
}

// MARK: - Integration

final class DeterminismIntegrationTests: XCTestCase {

    /// Two games from one seed with the same scripted orders are identical after every turn, in every era.
    @MainActor
    func testSameSeedSameOrdersSameGameAcrossEras() async {
        for year in [1789, 1913, 1962, 2025] {
            var a: [(ScriptedGame.Input, ScriptedGame.Snapshot)] = [], b: [(ScriptedGame.Input, ScriptedGame.Snapshot)] = []
            await ScriptedGame.play(year: year, seed: 0xC0FFEE &+ UInt64(year), turns: 12) { a.append(($0, $1)) }
            await ScriptedGame.play(year: year, seed: 0xC0FFEE &+ UInt64(year), turns: 12) { b.append(($0, $1)) }
            XCTAssertEqual(a.count, b.count, "\(year)")
            XCTAssertGreaterThan(a.count, 0, "\(year)")
            for (x, y) in zip(a, b) {
                XCTAssertEqual(x.0, y.0, "\(year) turn \(x.1.turn): inputs")
                XCTAssertEqual(x.1, y.1, "\(year) turn \(x.1.turn): state")
                if x.1 != y.1 { break }
            }
        }
    }
}

// MARK: - Retry (a save in the middle continues the same sequence)

final class DeterminismRetryTests: XCTestCase {

    @MainActor
    func testRNGStateSurvivesASaveAndLoad() throws {
        let gs = GameState(playerCountryID: "USA", seed: 77)
        _ = (0..<10).map { _ in gs.rng.next() }
        let back = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(gs))
        XCTAssertEqual(back.rng, gs.rng)
        XCTAssertEqual(back.rng.next(), gs.rng.next())
    }
}

// MARK: - Security (no new unseeded gameplay randomness)

final class DeterminismSecurityTests: XCTestCase {

    /// Every random call in the gameplay sources draws from the game's RNG (`using: &…rng`). The only exceptions
    /// carry a `// rng: cosmetic` or `// rng: seed` comment on the same line.
    func testNoUnseededRandomnessInGameplaySources() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let pattern = try NSRegularExpression(pattern: #"\b(Int|Double|Float|CGFloat|UInt64|UInt32|UInt|Bool)\.random\(|\.randomElement\(\)|\.shuffled\(\)|\.shuffle\(\)|arc4random|drand48|SystemRandomNumberGenerator"#)
        var offenders: [String] = []
        var scanned = 0
        for dir in ["Shared/Engine", "Shared/Events", "Shared/Models"] {
            let base = root.appendingPathComponent(dir)
            guard let files = FileManager.default.enumerator(at: base, includingPropertiesForKeys: nil) else { continue }
            for case let url as URL in files where url.pathExtension == "swift" {
                scanned += 1
                let lines = try String(contentsOf: url, encoding: .utf8).components(separatedBy: "\n")
                for (n, line) in lines.enumerated() {
                    let code = line.trimmingCharacters(in: .whitespaces)
                    if code.hasPrefix("//") || code.hasPrefix("///") { continue }
                    let range = NSRange(line.startIndex..., in: line)
                    for m in pattern.matches(in: line, range: range) {
                        guard let r = Range(m.range, in: line) else { continue }
                        let rest = line[r.lowerBound...]
                        // A call that names a generator (`using: &`) on the same line is seeded.
                        if line.contains("// rng: cosmetic") || line.contains("// rng: seed") { continue }
                        if rest.prefix(160).contains("using: &") { continue }
                        offenders.append("\(dir)/\(url.lastPathComponent):\(n + 1): \(code)")
                    }
                }
            }
        }
        XCTAssertGreaterThan(scanned, 50, "the scan found the sources")
        XCTAssertEqual(offenders, [], "unseeded gameplay randomness; use `using: &gs.rng` or mark it `// rng: cosmetic`")
    }
}
