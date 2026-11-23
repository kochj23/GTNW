//
//  AdministrationsQuery.swift
//  GTNWCore
//
//  `{"q":"administrations"}`: the U.S. administrations from 1789 (the new-game screen names the president a U.S.
//  game in a given year starts under). Needs no game.
//

#if GTNW_CORE
import Foundation

enum AdministrationsQuery: BridgeQuery {
    static let name = "administrations"

    struct Administration: Encodable {
        var id: String
        var president: String
        var years: String
        var startYear: Int
        var endYear: Int
        var party: String
    }

    struct Result: Encodable { var administrations: [Administration] }

    static func run(_ args: NoArgs, engine: GameEngine?) throws -> Result {
        Result(administrations: Advisor.allAdministrations().map {
            Administration(id: $0.id, president: $0.president, years: $0.years, startYear: $0.startYear, endYear: $0.endYear, party: $0.party)
        })
    }
}
#endif
