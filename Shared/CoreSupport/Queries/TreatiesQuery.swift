//
//  TreatiesQuery.swift
//  GTNWCore
//
//  `{"q":"treaties"}`: TreatyOffersSheet. The treaties other nations are offering (they lapse after three months).
//  Answered with the `answerTreaty` verb.
//

#if GTNW_CORE
import Foundation

enum TreatiesQuery: BridgeQuery {
    static let name = "treaties"

    struct Offer: Encodable { var id: String; var from: String; var fromName: String; var type: String; var date: String }
    struct Result: Encodable { var offers: [Offer] }

    static func run(_ args: NoArgs, engine: GameEngine?) throws -> Result {
        let (_, gs) = try GTNWBridge.game(engine)
        return Result(offers: gs.shadow.treatyOffers.map {
            Offer(id: $0.id.uuidString, from: $0.from, fromName: gs.getCountry(id: $0.from)?.name ?? $0.from, type: $0.type.rawValue,
                  date: GameCalendar.format($0.date))
        })
    }
}
#endif
