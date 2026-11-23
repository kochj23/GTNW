//
//  SendAidVerb.swift
//  GTNWCore
//
//  `{"verb":"sendAid","target":"EGY","humanitarian":2,"economic":1.5}`: AidSheet SEND AID. The report is the
//  recipient's reaction.
//

#if GTNW_CORE
import Foundation

enum SendAidVerb: BridgeVerb {
    static let name = "sendAid"

    struct Args: Decodable {
        var target: String
        var humanitarian: Double?, economic: Double?, intelligence: Double?, military: Double?, nuclear: Double?
    }

    static func run(_ a: Args, engine e: GameEngine, state gs: GameState) throws -> GTNWBridge.Report? {
        var v = AidVector()
        v.humanitarian = a.humanitarian ?? 0; v.economic = a.economic ?? 0; v.intelligence = a.intelligence ?? 0
        v.military = a.military ?? 0; v.nuclear = a.nuclear ?? 0
        guard v.total > 0, v.total.isFinite else { throw QueryError("The package is empty.") }
        guard let t = gs.getCountry(id: a.target), !t.isDestroyed, t.id != gs.playerCountryID else { throw QueryError("Pick a foreign nation.") }
        guard v.total <= gs.shadow.aidRemaining + 0.0001 else {
            throw QueryError(String(format: "Not enough aid money left this year ($%.1fB).", gs.shadow.aidRemaining))
        }
        guard let r = e.sendAid(v, to: a.target) else { throw QueryError("Those orders can't be carried out.") }
        return GTNWBridge.Report(title: r.reaction.label, lines: [r.message], success: r.reaction == .thanks || r.reaction == .partial)
    }
}
#endif
