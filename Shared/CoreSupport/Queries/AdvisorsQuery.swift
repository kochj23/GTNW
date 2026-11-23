//
//  AdvisorsQuery.swift
//  GTNWCore
//
//  `{"q":"advisors","country":"FRA"}`: the cabinet in rail order (the seven Situation Room posts first, then anyone
//  else), each with their spoken advice, standing recommendation (ACCEPT / REJECT / SOMETHING ELSE through `act`) and
//  a briefing about `country` (or the world). Departed advisors are listed with their status. `posts` is the app's
//  AdvisorRail: the seven Situation Room posts in order, who holds each (or vacant), the post's title as the rail
//  shows it, its briefing and who held it before. The profile fields (expertise … fiscal conservatism, department,
//  bio, advice areas) are the app's AdvisorDetailView. Dismissing an advisor is `act` `{"fire":"<id>"}`.
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
        var expertise: Int
        var influence: Int
        var publicSupport: Int
        var interventionism: Int
        var fiscalConservatism: Int
        var department: String
        var bio: String
        var adviceAreas: [String]
        /// Not the President (the President can't be dismissed).
        var canFire: Bool
    }

    struct Former: Encodable { var name: String; var status: String; var statusLabel: String }

    struct Post: Encodable {
        var role: String
        /// The rail's heading: the U.S. post title, or the holder's own office in another nation's cabinet.
        var title: String
        var advisorId: String?
        var name: String?
        var briefing: String
        var former: [Former]
    }

    struct Result: Encodable { var advisors: [Advisor]; var posts: [Post] }

    static func run(_ args: Args, engine: GameEngine?) throws -> Result {
        let (_, gs) = try GTNWBridge.game(engine)
        let country = args.country.flatMap { gs.getCountry(id: $0) }.flatMap { $0.isPlayerControlled ? nil : $0 }
        let order = AdviceEngine.roleOrder
        let sorted = gs.advisors.enumerated().sorted { l, r in
            let a = l.element.roleKey.flatMap { order.firstIndex(of: $0) } ?? order.count
            let b = r.element.roleKey.flatMap { order.firstIndex(of: $0) } ?? order.count
            return (a, l.element.isActive ? 0 : 1, l.offset) < (b, r.element.isActive ? 0 : 1, r.offset)
        }.map(\.element)
        let posts = order.map { role -> Post in
            let adv = AdviceEngine.advisor(for: role, in: gs.advisors)
            return Post(role: role,
                        title: gs.playerCountryID == "USA" ? AdviceEngine.roleTitle(role) : (adv?.title ?? AdviceEngine.roleTitle(role)),
                        advisorId: adv?.id, name: adv?.name,
                        briefing: AdviceEngine.briefing(role: role, country: country, gameState: gs),
                        former: gs.advisors.filter { $0.roleKey == role && !$0.isActive }.map { Former(name: $0.name, status: ($0.status ?? .active).rawValue, statusLabel: ($0.status ?? .active).label) })
        }
        return Result(advisors: sorted.map { a in
            let rec = a.recommendedAction.flatMap { act in a.recommendedTarget.map { t in
                Recommendation(action: act, target: t, targetName: gs.getCountry(id: t)?.name ?? t) } }
            let status = a.status ?? .active
            return Advisor(id: a.id, name: a.name, title: a.title, role: a.roleKey, status: status.rawValue, statusLabel: status.label,
                           loyalty: a.loyalty, hawkishness: a.hawkishness, advice: a.currentAdvice,
                           recommendation: a.isActive ? rec : nil,
                           briefing: a.isActive ? a.roleKey.map { AdviceEngine.briefing(role: $0, country: country, gameState: gs) } : nil,
                           expertise: a.expertise, influence: a.influence, publicSupport: a.publicSupport,
                           interventionism: a.interventionism, fiscalConservatism: a.fiscalConservatism,
                           department: a.department, bio: a.bio, adviceAreas: a.adviceAreas.map(\.rawValue),
                           canFire: !a.title.contains("President"))
        }, posts: posts)
    }
}
#endif
