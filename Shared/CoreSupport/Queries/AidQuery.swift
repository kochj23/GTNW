//
//  AidQuery.swift
//  GTNWCore
//
//  `{"q":"aid","id":"EGY"}`: AidSheet. The aid money left this year and, for each of the five kinds of aid, what
//  the country needs and what has been sent this year. Sent with the `sendAid` verb.
//

#if GTNW_CORE
import Foundation

enum AidQuery: BridgeQuery {
    static let name = "aid"

    struct Args: Decodable { var id: String }
    struct Category: Encodable { var id: String; var label: String; var need: Double; var sent: Double }

    struct Result: Encodable {
        var id: String
        var name: String
        var title: String
        var remaining: Double
        var remainingLine: String
        /// False for the player's own country, a destroyed one, or a land with no government.
        var canSend: Bool
        var categories: [Category]
        var maxEach: Double
        var step: Double
    }

    static func run(_ args: Args, engine: GameEngine?) throws -> Result {
        let (_, gs) = try GTNWBridge.game(engine)
        let c = gs.getCountry(id: args.id)
        let name = c?.name ?? args.id
        return Result(
            id: args.id, name: name, title: "Foreign Aid — \(name)", remaining: QueryText.round2(gs.shadow.aidRemaining),
            remainingLine: String(format: "Aid budget remaining this year: $%.1fB", gs.shadow.aidRemaining),
            canSend: c.map { !$0.isDestroyed && $0.id != gs.playerCountryID } ?? false,
            categories: c.map { c in
                AidCategory.allCases.map { k in
                    Category(id: k.rawValue, label: k.label, need: QueryText.round2(c.profile.aidNeed[k]), sent: QueryText.round2(gs.shadow.aidSent[args.id]?[k] ?? 0))
                }
            } ?? [],
            maxEach: 50, step: 0.5)
    }
}
#endif
