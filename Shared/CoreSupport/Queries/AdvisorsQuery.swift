//
//  AdvisorsQuery.swift
//  GTNWCore
//
//  `{"q":"advisors","country":"FRA"}`: the cabinet in rail order (the seven Situation Room posts first, then anyone
//  else), each with their spoken advice, standing recommendation (ACCEPT / REJECT / SOMETHING ELSE through `act`) and
//  a briefing about `country` (or the world). Departed advisors are listed with their status.
//

#if GTNW_CORE
import Foundation

enum AdvisorsQuery: BridgeQuery {
    static let name = "advisors"

    struct Args: Decodable { var country: String? }

    struct Recommendation: Encodable {
        var action: String
        var target: String
        var targetName: String
    }

    struct Advisor: Encodable {
        var id: String
        var name: String
        var title: String
        var role: String?
        /// active, resigned, fired, killed, scandal
        var status: String
        var statusLabel: String
        var loyalty: Int
        var hawkishness: Int
        var advice: String?
        var recommendation: Recommendation?
        var briefing: String?
    }

    struct Result: Encodable { var advisors: [Advisor] }

    static func run(_ args: Args, engine: GameEngine?) throws -> Result {
        let (_, gs) = try GTNWBridge.game(engine)
        let country = args.country.flatMap { gs.getCountry(id: $0) }.flatMap { $0.isPlayerControlled ? nil : $0 }
        let order = AdviceEngine.roleOrder
        let sorted = gs.advisors.enumerated().sorted { l, r in
            let a = l.element.roleKey.flatMap { order.firstIndex(of: $0) } ?? order.count
            let b = r.element.roleKey.flatMap { order.firstIndex(of: $0) } ?? order.count
            return (a, l.element.isActive ? 0 : 1, l.offset) < (b, r.element.isActive ? 0 : 1, r.offset)
        }.map(\.element)
        return Result(advisors: sorted.map { a in
            let rec = a.recommendedAction.flatMap { act in a.recommendedTarget.map { t in
                Recommendation(action: act, target: t, targetName: gs.getCountry(id: t)?.name ?? t) } }
            let status = a.status ?? .active
            return Advisor(id: a.id, name: a.name, title: a.title, role: a.roleKey, status: status.rawValue, statusLabel: status.label,
                           loyalty: a.loyalty, hawkishness: a.hawkishness, advice: a.currentAdvice,
                           recommendation: a.isActive ? rec : nil,
                           briefing: a.isActive ? a.roleKey.map { AdviceEngine.briefing(role: $0, country: country, gameState: gs) } : nil)
        })
    }
}
#endif
