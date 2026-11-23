//
//  NationsQuery.swift
//  GTNWCore
//
//  `{"q":"nations","year":1914}`: every nation that exists on Inauguration Day of that year, with its leader on the
//  day and whether its real cabinet is in the research data (the app's NationPickerSheet). Needs no game.
//

#if GTNW_CORE
import Foundation

enum NationsQuery: BridgeQuery {
    static let name = "nations"

    struct Args: Decodable { var year: Int? }

    struct Nation: Encodable {
        var id: String
        var name: String
        var flag: String
        var region: String
        var government: String
        var alignment: String
        var warheads: Int
        /// "President Woodrow Wilson", or the generic title when the record has a gap.
        var leader: String
        var realCabinet: Bool
    }

    struct Result: Encodable {
        var year: Int
        var nations: [Nation]
    }

    static func run(_ args: Args, engine: GameEngine?) throws -> Result {
        let year = args.year ?? 2025
        guard (1789...2100).contains(year) else { throw QueryError("year must be 1789…2100") }
        let date = GameCalendar.inauguration(year: year)
        let president = Advisor.allAdministrations().last { $0.startYear <= year }?.president
        let nations = CountryFactory.createCountriesForYear(year).sorted { $0.name < $1.name }.map { c -> Nation in
            let leader: String
            if c.id == "USA" {
                leader = president.map { "President \($0)" } ?? "President"
            } else {
                let l = NationModel.leader(for: c, on: date)
                leader = l.generic ? l.title : "\(l.title) \(l.name)".trimmingCharacters(in: .whitespaces)
            }
            return Nation(id: c.id, name: c.name, flag: c.flag, region: c.region.rawValue, government: c.government.rawValue,
                          alignment: c.alignment.rawValue, warheads: c.nuclearWarheads, leader: leader,
                          realCabinet: c.id == "USA" || NationModel.nation(c.id) != nil)
        }
        return Result(year: year, nations: nations)
    }
}
#endif
