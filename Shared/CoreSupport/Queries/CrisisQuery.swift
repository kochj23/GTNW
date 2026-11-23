//
//  CrisisQuery.swift
//  GTNWCore
//
//  `{"q":"crisis"}`: the decision on the President's desk as the app's DetailedCrisisView shows it: severity,
//  title, the brief, its epigraph (Quotations, stable for the crisis), how many more decisions wait behind it, the
//  response time limit (a front end counts it down; the engine has no clock), and each option with the advisor who
//  recommends it (the post resolved to the name serving now) and its odds. Answer it with `act` `{"crisisOption":i}`.
//  `crisis` is null when nothing is waiting.
//

#if GTNW_CORE
import Foundation

enum CrisisQuery: BridgeQuery {
    static let name = "crisis"

    struct Quote: Encodable {
        var text: String
        var source: String
        /// Sacred texts, Science fiction, Military doctrine
        var shelf: String
    }

    struct Option: Encodable {
        var title: String
        var description: String
        /// The advisor's name, or the post when nobody holds it.
        var recommendedBy: String?
        var successChance: Double
    }

    struct Crisis: Encodable {
        var id: String
        var type: String
        var severity: Int
        /// MINOR … CATASTROPHIC
        var severityLabel: String
        var title: String
        var description: String
        var affected: [String]
        /// Seconds to answer, or nil.
        var timeLimit: Int?
        var epigraph: Quote
        var options: [Option]
    }

    struct Result: Encodable {
        var crisis: Crisis?
        var pending: Int
    }

    static func quote(_ q: Quotation) -> Quote { Quote(text: q.text, source: q.source, shelf: q.kind.rawValue) }

    static func run(_ args: NoArgs, engine: GameEngine?) throws -> Result {
        let (e, gs) = try GTNWBridge.game(engine)
        let m = e.crisisManager
        guard let c = m.activeCrisis else { return Result(crisis: nil, pending: m.pendingCrises.count) }
        let options = c.options.map { o in
            // DetailedCrisisView: the role title resolved to the advisor serving in this era.
            let name = o.advisorRecommendation.map { role in
                gs.advisors.first { $0.title == role || $0.title.contains(role) || role.contains($0.title) }?.name ?? role
            }
            return Option(title: o.title, description: o.description, recommendedBy: name, successChance: QueryText.round2(o.successChance))
        }
        return Result(crisis: Crisis(
            id: c.id.uuidString, type: c.type.rawValue, severity: c.severity.rawValue, severityLabel: c.severity.description,
            title: c.title, description: c.description,
            affected: c.affectedCountries.map { gs.getCountry(id: $0)?.name ?? $0 },
            timeLimit: c.timeLimit, epigraph: quote(c.epigraph), options: options), pending: m.pendingCrises.count)
    }
}
#endif
