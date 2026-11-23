//
//  Bridge.swift
//  GTNWCore
//
//  The JSON bridge a front end drives the engine through (the WebAssembly exports in Wasm/Sources/GTNWWasm, the
//  golden CLI, the package tests). Strings in, strings out, one game per process, single-threaded: every call runs
//  the engine's tasks and deferred work to completion (JobPump) before it returns, so the state it hands back is
//  settled. Errors come back as {"ok":false,"error":"..."}. Documentation/WASM-PORT.md has the API with examples.
//
//    newGame({"player":"USA","year":1962,"seed":"7aa","difficulty":"Normal","turnLength":"month","rules":"full"})
//    act({"action":"Send Ambassador","target":"FRA"})      act({"crisisOption":0})
//    endTurn()   snapshot()   save()   load(<save>)   golden(1962, 0x7aa, 12)
//

#if GTNW_CORE
import Foundation

/// Which world systems run. The app plays `full`; its test runs (and so the golden fixtures) play `golden`, with the
/// systems that `GameStoreService.isTestOrSmokeRun` switches off kept off.
enum Rules: String, Codable {
    case full, golden

    func apply() {
        let quiet = self == .golden
        GameStoreService.isTestOrSmokeRun = quiet
        ChemicalThreats.enabled = !quiet
        CovertAgents.aiEnabled = !quiet
        LandMarket.enabled = !quiet
        Dispatch.enabled = !quiet
        Outbreaks.aiEnabled = !quiet
    }
}

public enum GTNWBridge {

    // MARK: Requests and replies

    struct NewGame: Codable {
        var player: String?
        var year: Int?
        /// Hex digits (a UInt64 does not survive a JSON number in JavaScript); nil = a random seed.
        var seed: String?
        var difficulty: String?
        var turnLength: String?
        var rules: Rules?
    }

    /// One order, in the golden fixtures' `input` shape: answer the waiting crisis and/or give a presidential order.
    struct Order: Codable {
        var action: String?
        var target: String?
        var crisisOption: Int?
    }

    struct Crisis: Codable, Equatable {
        struct Option: Codable, Equatable {
            var title: String
            var description: String
            var successChance: Double
        }
        var title: String
        var description: String
        var severity: Int
        var options: [Option]
    }

    struct Nation: Codable, Equatable {
        var id: String
        var name: String
        var flag: String
        var alignment: String
        var warheads: Int
        var military: Int
        var stability: Int
        var approval: Int
        var destroyed: Bool
        var atWarWith: [String]
        var relationToPlayer: Int?
        var gdp: Double
        var population: Int
    }

    /// The settled state after a call: the golden snapshot's fields plus what a front end shows.
    struct State: Codable, Equatable {
        var turn: Int
        var date: String
        var defcon: Int
        var radiation: Int
        var casualties: Int
        var popularity: Double
        var gameOver: Bool
        var gameOverReason: String
        var rngState: String
        var wars: [String]
        var player: String
        var actionsRemaining: Int
        var crisis: Crisis?
        var nations: [Nation]
    }

    struct Event: Codable, Equatable {
        var kind: String
        var text: String
    }

    struct Reply: Codable {
        var ok: Bool
        var events: [Event]
        var state: State?
        var error: String?
    }

    // MARK: Session

    nonisolated(unsafe) static var engine: GameEngine?
    /// Log lines and ticker items already handed out, so every reply carries only what is new.
    nonisolated(unsafe) static var logSeen = 0
    nonisolated(unsafe) static var tickerSeen: Set<UUID> = []
    nonisolated(unsafe) static var resources: [String: Data] = [:]

    /// Register a bundled data file (nation_cabinets, nation_characters, world_countries, base_rates, open_wars)
    /// before the first game. Without them the engine plays with empty tables, as the app would without its bundle.
    public static func setResource(_ name: String, _ data: Data) {
        resources[name] = data
        GameResources.provider = { name, _ in GTNWBridge.resources[name] }
    }

    public static func newGame(_ json: String) -> String {
        guard let req = decode(NewGame.self, json) else { return failure("newGame: not a valid request") }
        let rules = req.rules ?? .full
        rules.apply()
        JobPump.install()
        CoreRunLoop.reset()
        let difficulty = req.difficulty.flatMap(DifficultyLevel.init(rawValue:)) ?? .normal
        let length = req.turnLength.flatMap(TurnLength.init(rawValue:)) ?? .month
        var seed: UInt64?
        if let s = req.seed {
            guard let v = UInt64(s, radix: 16) else { return failure("newGame: seed must be hex digits") }
            seed = v
        }
        let player = req.player ?? "USA"
        guard (1...8).contains(player.count), player.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_") }) else {
            return failure("newGame: bad player id")
        }
        let e = GameEngine()
        e.startNewGame(playerCountryID: player, difficulty: difficulty, turnLength: length, year: req.year, seed: seed)
        guard e.gameState?.getPlayerCountry() != nil else { return failure("newGame: no country \(player) in that year") }
        engine = e
        logSeen = 0
        tickerSeen = []
        JobPump.pump()
        return reply()
    }

    public static func act(_ json: String) -> String {
        guard let e = engine, let gs = e.gameState else { return failure("act: no game") }
        guard !gs.gameOver else { return failure("act: the game is over") }
        guard let order = decode(Order.self, json) else { return failure("act: not a valid order") }
        if let option = order.crisisOption {
            guard let crisis = e.crisisManager.activeCrisis else { return failure("act: no crisis is waiting") }
            guard crisis.options.indices.contains(option) else { return failure("act: no option \(option)") }
            var g = gs
            e.crisisManager.resolveCrisis(optionIndex: option, gameState: &g)
            JobPump.pump()
        }
        if let name = order.action, name != "none" {
            guard let action = PresidentialAction(rawValue: name) else { return failure("act: unknown action \(name)") }
            guard let target = order.target, let t = gs.getCountry(id: target), !t.isDestroyed else {
                return failure("act: \(name) needs a live target")
            }
            e.executeShadowPresidentAction(action, from: gs.playerCountryID, to: t.id)
            JobPump.pump()
        }
        return reply()
    }

    public static func endTurn() -> String {
        guard let e = engine, let gs = e.gameState else { return failure("endTurn: no game") }
        guard !gs.gameOver else { return failure("endTurn: the game is over") }
        e.endTurn()
        JobPump.pump(while: { e.isProcessingAITurn })
        return reply()
    }

    public static func snapshot() -> String {
        guard engine?.gameState != nil else { return failure("snapshot: no game") }
        return reply(events: false)
    }

    /// The game as the app saves it (`SaveCodec`: the full GameState, RNG included).
    public static func save() -> String {
        guard let gs = engine?.gameState else { return failure("save: no game") }
        do { return String(decoding: try SaveCodec.encode(gs), as: UTF8.self) } catch { return failure("save: \(error)") }
    }

    /// Continue a saved game (validated by `SaveCodec.decode`, like every load in the app).
    public static func load(_ json: String) -> String {
        do {
            let gs = try SaveCodec.decode(Data(json.utf8))
            JobPump.install()
            CoreRunLoop.reset()
            let e = engine ?? GameEngine()
            e.gameState = gs
            engine = e
            logSeen = e.logMessages.count
            tickerSeen = Set(gs.shadow.ticker.map(\.id))
            return reply(events: false)
        } catch {
            return failure("load: \(error)")
        }
    }

    /// One golden game, in the fixture format (`game-<year>-<seed>.json`).
    public static func golden(year: Int, seed: UInt64, turns: Int) -> String {
        encode(GoldenGame.play(year: year, seed: seed, turns: turns))
    }

    /// The manifest's RNG vectors for `seed`.
    public static func goldenVectors(seed: UInt64 = 42) -> String {
        encode(GoldenGame.vectors(seed: seed))
    }

    // MARK: Encoding

    static func decode<T: Decodable>(_ type: T.Type, _ json: String) -> T? {
        guard json.utf8.count <= 64 * 1024 else { return nil }
        return try? JSONDecoder().decode(type, from: Data(json.utf8))
    }

    static func encode<T: Encodable>(_ value: T) -> String {
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return (try? enc.encode(value)).map { String(decoding: $0, as: UTF8.self) } ?? #"{"ok":false,"error":"encoding failed"}"#
    }

    static func failure(_ message: String) -> String {
        encode(Reply(ok: false, events: [], state: nil, error: message))
    }

    static func reply(events: Bool = true) -> String {
        encode(Reply(ok: true, events: events ? newEvents() : [], state: engine?.gameState.map(state), error: nil))
    }

    static func newEvents() -> [Event] {
        guard let e = engine else { return [] }
        var out: [Event] = []
        let log = e.logMessages
        if logSeen > log.count { logSeen = 0 }   // the engine trimmed or restarted its log
        for m in log[logSeen...] where !m.message.isEmpty { out.append(Event(kind: "log.\(m.type)", text: m.message)) }
        logSeen = log.count
        for item in e.gameState?.shadow.ticker ?? [] where !tickerSeen.contains(item.id) {
            tickerSeen.insert(item.id)
            out.append(Event(kind: "ticker.\(item.severity)", text: item.text))
        }
        return out
    }

    static func state(_ gs: GameState) -> State {
        let me = gs.playerCountryID
        let crisis = engine?.crisisManager.activeCrisis.map { c in
            Crisis(title: c.title, description: c.description, severity: c.severity.rawValue,
                   options: c.options.map { Crisis.Option(title: $0.title, description: $0.description, successChance: $0.successChance) })
        }
        return State(
            turn: gs.turn, date: GameCalendar.format(gs.currentDate), defcon: gs.defconLevel.rawValue,
            radiation: gs.globalRadiation, casualties: gs.totalCasualties, popularity: (gs.shadow.popularity * 100).rounded() / 100,
            gameOver: gs.gameOver, gameOverReason: gs.gameOverReason, rngState: GoldenGame.hex(gs.rng.state),
            wars: gs.activeWars.map { "\($0.aggressor)>\($0.defender)" }.sorted(),
            player: me, actionsRemaining: gs.actionsRemaining, crisis: crisis,
            nations: gs.countries.sorted { $0.id < $1.id }.map {
                Nation(id: $0.id, name: $0.name, flag: $0.flag, alignment: $0.alignment.rawValue, warheads: $0.nuclearWarheads,
                       military: $0.militaryStrength, stability: $0.stability, approval: $0.publicApproval,
                       destroyed: $0.isDestroyed, atWarWith: $0.atWarWith.sorted(),
                       relationToPlayer: $0.id == me ? nil : $0.diplomaticRelations[me], gdp: $0.gdp, population: $0.population)
            })
    }
}
#endif
