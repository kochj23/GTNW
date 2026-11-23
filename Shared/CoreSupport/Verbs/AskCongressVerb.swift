//
//  AskCongressVerb.swift
//  GTNWCore
//
//  `{"verb":"askCongress","target":"CUB","kind":"declaration"|"useOfForce"}`: ask Congress for a declaration of
//  war or an authorization to use force (CongressSheet's REQUEST; one action). The chambers vote at once.
//

#if GTNW_CORE
import Foundation

enum AskCongressVerb: BridgeVerb {
    static let name = "askCongress"

    struct Args: Decodable { var target: String; var kind: String }

    static func run(_ a: Args, engine e: GameEngine, state gs: GameState) throws -> GTNWBridge.Report? {
        guard let kind = WarAuthorizationKind(rawValue: a.kind) else { throw QueryError("kind is declaration or useOfForce") }
        guard gs.playerCountryID == "USA" else { throw QueryError("only the U.S. Congress votes on war") }
        guard gs.actionsRemaining > 0 else { throw QueryError("no actions left this turn") }
        guard !e.isAuthorized(a.target) else { throw QueryError("Congress has already authorized hostilities") }
        guard let v = e.requestAuthorization(target: a.target, kind: kind) else { throw QueryError("Congress can't be asked about \(a.target)") }
        return GTNWBridge.Report(title: "\(kind.title): \(v.passed ? "passed" : "failed")",
                                 lines: ["House \(v.houseYes)% yes, Senate \(v.senateYes)% yes."], success: v.passed)
    }
}
#endif
