//
//  SettleVerb.swift
//  GTNWCore
//
//  `{"verb":"settle","id":"<settlement>","choice":"annex","name":"New Name"}` or `"choice":"democraticRepublic"`:
//  SettlementSheet. Annex the loser (optionally renamed) or install one of the post-war governments.
//

#if GTNW_CORE
import Foundation

enum SettleVerb: BridgeVerb {
    static let name = "settle"

    struct Args: Decodable { var id: String; var choice: String; var name: String? }

    static func run(_ a: Args, engine e: GameEngine, state gs: GameState) throws -> GTNWBridge.Report? {
        let id = try WarSupport.uuid(a.id)
        guard gs.shadow.pendingSettlements.contains(where: { $0.id == id }) else { throw QueryError("No such surrender is waiting.") }
        let choice: SettlementChoice
        if a.choice == "annex" { choice = .annex }
        else if let g = PostWarGovernment(rawValue: a.choice) { choice = .government(g) }
        else { throw QueryError("unknown choice \(a.choice)") }
        let rename = choice == .annex && !(a.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if rename, let why = NameScreen.check(a.name ?? "").reason { throw QueryError(why) }
        let loser = gs.shadow.pendingSettlements.first { $0.id == id }?.loser ?? ""
        guard e.settle(id, choice: choice) else { throw QueryError("Those orders can't be carried out.") }
        if rename { e.renameTerritory(loser, to: a.name ?? "") }
        return nil
    }
}
#endif
