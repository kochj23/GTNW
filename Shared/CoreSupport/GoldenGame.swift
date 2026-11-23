//
//  GoldenGame.swift
//  GTNWCore
//
//  The golden games, played by the core. The same seeded games and scripted orders as `ScriptedGame` /
//  `GoldenExporter` in GTNWTests (DeterminismTests.swift, GoldenExportTests.swift), producing the same JSON, so a
//  GTNWCore build (native or WebAssembly) can be checked against the fixtures the app exported: one game, same
//  bytes. Documentation/GOLDEN.md has the format; Wasm/parity.sh runs the check.
//

#if GTNW_CORE
import Foundation

public enum GoldenGame {
    static let format = "gtnw-golden"
    static let version = 1

    /// The orders, in turn order (wrapping): `ScriptedGame.orders`.
    static let orders: [PresidentialAction] = [.sendAmbassador, .tradeDeal, .militaryExercise, .economicAid, .summit, .demandApology]

    struct Input: Codable, Equatable {
        var action: String
        var target: String?
        var crisisOption: Int?
    }

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
        var rngState: String
        var wars: [String]
        var nations: [Nation]
    }

    struct GameInfo: Codable, Equatable {
        var file: String
        var year: Int
        var seed: String
        var player: String
        var difficulty: String
        var turnLength: String
        var turns: Int
    }

    struct Turn: Codable, Equatable {
        var turn: Int
        var input: Input
        var state: Snapshot
    }

    struct Game: Codable, Equatable {
        var format: String
        var version: Int
        var game: GameInfo
        var initial: Snapshot
        var turns: [Turn]
    }

    struct RNGVectors: Codable, Equatable {
        var seed: String
        var next: [String]
        var unitDoubles: [Double]
        var d100: [Int]
    }

    static func hex(_ v: UInt64) -> String {
        let digits = String(v, radix: 16)
        return String(repeating: "0", count: max(0, 16 - digits.count)) + digits
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
            gameOver: gs.gameOver, rngState: hex(gs.rng.state),
            wars: gs.activeWars.map { "\($0.aggressor)>\($0.defender)" }.sorted(),
            nations: gs.countries.sorted { $0.id < $1.id }.map {
                Snapshot.Nation(id: $0.id, warheads: $0.nuclearWarheads, military: $0.militaryStrength, stability: $0.stability,
                                approval: $0.publicApproval, destroyed: $0.isDestroyed, atWarWith: $0.atWarWith.sorted(),
                                relationToPlayer: $0.id == me ? nil : $0.diplomaticRelations[me])
            })
    }

    /// The generator's first outputs (the manifest's `rngVectors`).
    static func vectors(seed: UInt64 = 42) -> RNGVectors {
        var a = GameRNG(seed: seed), b = GameRNG(seed: seed), c = GameRNG(seed: seed)
        return RNGVectors(seed: hex(seed),
                          next: (0..<8).map { _ in hex(a.next()) },
                          unitDoubles: (0..<8).map { _ in Double.random(in: 0..<1, using: &b) },
                          d100: (0..<8).map { _ in Int.random(in: 1...100, using: &c) })
    }

    /// Play one game as `ScriptedGame.play` does: the engine's tasks run (JobPump) where the test awaits them.
    static func play(year: Int, seed: UInt64, turns: Int) -> Game {
        Rules.golden.apply()
        JobPump.install()
        let info = GameInfo(file: "game-\(year)-\(hex(seed)).json", year: year, seed: hex(seed), player: "USA",
                            difficulty: DifficultyLevel.normal.rawValue, turnLength: TurnLength.month.rawValue, turns: turns)
        let e = GameEngine()
        e.startNewGame(difficulty: .normal, turnLength: .month, year: year, seed: seed)
        guard let start = e.gameState else { return Game(format: format, version: version, game: info, initial: Snapshot(
            turn: 0, date: "", defcon: 5, radiation: 0, casualties: 0, popularity: 0, gameOver: true, rngState: "", wars: [], nations: []),
            turns: []) }
        let initial = snapshot(start)
        var rows: [Turn] = []
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
            JobPump.pump(while: { e.isProcessingAITurn })
            let state = snapshot(e.gameState ?? gs)
            rows.append(Turn(turn: state.turn, input: input, state: state))
        }
        var game = info
        game.turns = rows.count
        return Game(format: format, version: version, game: game, initial: initial, turns: rows)
    }
}
#endif
