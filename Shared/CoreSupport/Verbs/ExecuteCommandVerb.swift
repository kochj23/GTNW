//
//  ExecuteCommandVerb.swift
//  GTNWCore
//
//  The command box's EXECUTE (3.34.0): {"verb":"executeCommand","orders":[GameOrder…],"source":"parser"|"model"}, the
//  orders of a plan from the `command` query. `executeCommand` checks every order again (OrderWhitelist,
//  orderProblem) before it runs, so nothing outside the whitelist can be carried out whatever the front end sends.
//  The report's `command` says what was carried out, refused and not reached (the app's CommandResultView).
//

#if GTNW_CORE
import Foundation

extension GTNWBridge {
    /// What a command's orders did (`GameEngine.CommandExecution`).
    struct CommandResult: Codable, Equatable {
        var carried: [GameOrder]
        var refused: [GameOrder]
        var notReached: [GameOrder]
        var lines: [String]
    }
}

enum ExecuteCommandVerb: BridgeVerb {
    static let name = "executeCommand"

    struct Args: Decodable {
        var orders: [GameOrder]
        var source: String?
    }

    static func run(_ args: Args, engine: GameEngine, state: GameState) throws -> GTNWBridge.Report? {
        guard (1...16).contains(args.orders.count) else { throw QueryError("1 to 16 orders") }
        guard !engine.isProcessingAITurn else { throw QueryError("the world is moving") }
        let source = args.source.flatMap(CommandSource.init(rawValue:)) ?? .parser
        let r = engine.executeCommand(args.orders, source: source == .replay ? .parser : source)
        return GTNWBridge.Report(
            title: r.carried.isEmpty ? "NOTHING CARRIED OUT" : "CARRIED OUT: \(r.carried.count) order\(r.carried.count == 1 ? "" : "s")",
            lines: r.lines, success: r.carried.isEmpty ? false : true,
            command: GTNWBridge.CommandResult(carried: r.carried, refused: r.refused, notReached: r.notReached, lines: r.lines))
    }
}
#endif
