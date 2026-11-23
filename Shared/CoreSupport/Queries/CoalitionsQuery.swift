//
//  CoalitionsQuery.swift
//  GTNWCore
//
//  `{"q":"coalitions","target":"IRQ"}`: CoalitionSheet. Who is already in the coalition against the target, and
//  every ally or friend who could be asked, with the odds each joins (the same function the vote uses). Asked with
//  the `requestCoalition` verb.
//

#if GTNW_CORE
import Foundation

enum CoalitionsQuery: BridgeQuery {
    static let name = "coalitions"

    struct Args: Decodable { var target: String }
    struct Candidate: Encodable { var id: String; var name: String; var odds: Double }

    struct Result: Encodable {
        var target: String
        var targetName: String
        var members: [String]
        var candidates: [Candidate]
        var askTitle: String
        var canAsk: Bool
    }

    static func run(_ args: Args, engine: GameEngine?) throws -> Result {
        let (e, gs) = try GTNWBridge.game(engine)
        let odds = e.coalitionOdds(against: args.target)
        return Result(
            target: args.target, targetName: gs.getCountry(id: args.target)?.name ?? args.target,
            members: gs.shadow.coalitions[args.target]?.members.compactMap { gs.getCountry(id: $0)?.name } ?? [],
            candidates: odds.map { Candidate(id: $0.id, name: gs.getCountry(id: $0.id)?.name ?? $0.id, odds: QueryText.round2($0.odds)) },
            askTitle: "Ask \(odds.count) nation\(odds.count == 1 ? "" : "s") to join",
            canAsk: !odds.isEmpty && gs.actionsRemaining > 0)
    }
}
#endif
