//
//  AdviceQuery.swift
//  GTNWCore
//
//  `{"q":"advice","action":"Air Strike","target":"CUB"}`: what the responsible cabinet post says about one order
//  (AdviceEngine.advise: APPROVE / CAUTION / OPPOSE with reasons and the odds), the three-line warning before a
//  major order (Joint Chiefs, State, Vice President), and the standard size of a sized attack. `act` with
//  `"advised":true` carries the order out with this same advice; `"decline":true` backs off.
//

#if GTNW_CORE
import Foundation

enum AdviceQuery: BridgeQuery {
    static let name = "advice"

    struct Args: Decodable {
        var action: String
        var target: String
    }

    struct Advice: Encodable {
        var advisorId: String?
        var advisorName: String
        var advisorTitle: String
        /// approve, caution, oppose
        var stance: String
        var reason: String
        var odds: Double
    }

    struct Warning: Encodable {
        var who: String
        var text: String
        /// 0 calm, 1 caution, 2 danger
        var level: Int
    }

    struct Size: Encodable {
        var troops: Double
        var aircraft: Int
        var warheads: Int
    }

    struct Result: Encodable {
        var action: String
        var target: String
        var description: String
        var advice: Advice
        var warnings: [Warning]
        var problem: String?
        /// The standard (pre-3.4) size, for sized attacks.
        var size: Size?
        /// The warhead an order uses by default ("Thermonuclear (H-Bomb)"), for nuclear orders.
        var warhead: String?
    }

    static func run(_ args: Args, engine: GameEngine?) throws -> Result {
        let (e, gs) = try GTNWBridge.game(engine)
        guard let a = PresidentialAction(rawValue: args.action) else { throw QueryError("unknown action \(args.action)") }
        guard let player = gs.getPlayerCountry(), let target = gs.getCountry(id: args.target) else { throw QueryError("no country \(args.target)") }
        let adv = AdviceEngine.advise(action: a, player: player, target: target, gameState: gs)
        let kinds = AttackSizing.kinds(for: a)
        let size = kinds.isEmpty ? nil : AttackSizing.standard(a, in: gs)
        let warnings = MajorAction.isMajor(a) ? e.advisorWarnings(for: .attack(a, target: target.id, size: size)) : []
        return Result(
            action: a.rawValue, target: target.id, description: a.description,
            advice: Advice(advisorId: adv.advisorID, advisorName: adv.advisorName, advisorTitle: adv.advisorTitle,
                           stance: adv.stance.rawValue, reason: adv.reason, odds: QueryText.round2(adv.successEstimate)),
            warnings: warnings.map { Warning(who: $0.who, text: $0.text, level: $0.level) },
            problem: a.wmd != nil ? e.wmdProblem(a) : nil,
            size: size.map { Size(troops: $0.troops, aircraft: $0.aircraft, warheads: $0.warheads) },
            warhead: kinds.contains(.warheads) ? GTNWBridge.defaultWarhead(a, year: gs.currentYear).title : nil)
    }
}
#endif
