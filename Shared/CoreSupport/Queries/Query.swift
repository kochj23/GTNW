//
//  Query.swift
//  GTNWCore
//
//  The bridge's read-only `query` op (op 10): typed questions a front end asks the engine (the nation list for a
//  year, a dossier, who owns which land on the map, the actions on offer with their odds and the cabinet's advice…).
//  A query never changes the game: no RNG draw, no state written, no job run. `QueryTests` checks that a save taken
//  after every query is byte-identical to one taken before.
//
//  Request: `{"q":"<name>", ...that query's own fields}`. Reply: `{"ok":true,"result":{...}}` or
//  `{"ok":false,"error":"..."}`.
//
//  Adding a query: one file in this folder with a type that conforms to `BridgeQuery`, plus one line in
//  `QueryRegistry.all` (kept alphabetical). Queries never call each other, so screens can add theirs in parallel.
//  Documentation/WASM-PORT.md lists them; NovaGames games/gtnw-lite/docs/SCREENS.md says which screen uses which.
//

#if GTNW_CORE
import Foundation

/// One read-only query. `Args` is decoded from the whole request object (unknown keys, `q` included, are ignored).
protocol BridgeQuery {
    associatedtype Args: Decodable
    associatedtype Result: Encodable
    /// The `q` value.
    static var name: String { get }
    /// Answer from the current game (`engine` is nil before the first newGame/load; throw `QueryError.noGame`
    /// if the query needs one).
    static func run(_ args: Args, engine: GameEngine?) throws -> Result
}

/// No fields.
struct NoArgs: Decodable {}

struct QueryError: Error {
    let message: String
    init(_ message: String) { self.message = message }
    static let noGame = QueryError("no game")
}

/// Every query, by name. Alphabetical; one line each.
enum QueryRegistry {
    static let all: [any BridgeQuery.Type] = [
        ActionsQuery.self,
        AdministrationsQuery.self,
        AdviceQuery.self,
        AdvisorsQuery.self,
        AidQuery.self,
        AirCampaignQuery.self,
        ArsenalQuery.self,
        BudgetQuery.self,
        CoalitionsQuery.self,
        CommandQuery.self,
        CountryQuery.self,
        CrisisQuery.self,
        FleetsQuery.self,
        FrontsQuery.self,
        GroupActionQuery.self,
        ManpowerQuery.self,
        MapQuery.self,
        MessagesQuery.self,
        NationsQuery.self,
        NewsQuery.self,
        PeaceQuery.self,
        ResourcesQuery.self,
        ScenariosQuery.self,
        SettlementsQuery.self,
        TopBarQuery.self,
        TreatiesQuery.self,
        WarRecordQuery.self,
    ]

    static let byName: [String: any BridgeQuery.Type] = Dictionary(all.map { ($0.name, $0) }, uniquingKeysWith: { a, _ in a })
}

extension GTNWBridge {
    private struct QueryName: Decodable { var q: String }
    private struct QueryReply<R: Encodable>: Encodable { var ok = true; var result: R }

    /// Run one query: `{"q":"country","id":"FRA"}` → `{"ok":true,"result":{...}}`.
    public static func query(_ json: String) -> String {
        guard let head = decode(QueryName.self, json) else { return failure("query: not a valid request") }
        guard let type = QueryRegistry.byName[head.q] else { return failure("query: unknown query \(head.q)") }
        return answer(type, json)
    }

    private static func answer<Q: BridgeQuery>(_ type: Q.Type, _ json: String) -> String {
        guard let args = decode(Q.Args.self, json) else { return failure("query \(Q.name): bad arguments") }
        do {
            return encode(QueryReply(result: try Q.run(args, engine: engine)))
        } catch let e as QueryError {
            return failure("query \(Q.name): \(e.message)")
        } catch {
            return failure("query \(Q.name): \(error)")
        }
    }

    /// The live game, or `QueryError.noGame`.
    static func game(_ engine: GameEngine?) throws -> (GameEngine, GameState) {
        guard let e = engine, let gs = e.gameState else { throw QueryError.noGame }
        return (e, gs)
    }
}

/// Small encoding helpers shared by the queries.
enum QueryText {
    /// Dollars as a Double (JSON numbers past 2^53 lose precision, and no figure in the game is that large).
    static func dollars(_ v: Int64) -> Double { Double(v) }
    /// A rounded figure for display (two decimals).
    static func round2(_ v: Double) -> Double { (v * 100).rounded() / 100 }
}
#endif
