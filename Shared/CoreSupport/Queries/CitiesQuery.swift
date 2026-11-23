//
//  CitiesQuery.swift
//  GTNWCore
//
//  `{"q":"cities","id":"USA"}`: the app's CityView for one country: the level of each city tile (downtown, housing,
//  industry, the military, parks, the nuclear program, the airport; they grow with GDP, quality of life, industry,
//  the military and the arsenal and shrink with damage) and whether the city burns after a nuclear strike.
//

#if GTNW_CORE
import Foundation

enum CitiesQuery: BridgeQuery {
    static let name = "cities"

    struct Args: Decodable { var id: String }

    struct Tile: Encodable {
        var id: String
        var level: Int
        var maxLevel: Int
    }

    struct Result: Encodable {
        var id: String
        var name: String
        var capital: String
        var flag: String
        var burning: Bool
        var destroyed: Bool
        var tiles: [Tile]
    }

    static func run(_ args: Args, engine: GameEngine?) throws -> Result {
        let (_, gs) = try GTNWBridge.game(engine)
        guard let c = gs.getCountry(id: args.id) else { throw QueryError("no country \(args.id)") }
        let layout = CityLayout.layout(for: c, strikes: gs.nuclearStrikes)
        return Result(id: c.id, name: c.name, capital: c.capital, flag: c.flag, burning: layout.burning, destroyed: c.isDestroyed,
                      tiles: CityTile.allCases.map { Tile(id: $0.rawValue, level: layout.levels[$0] ?? 0, maxLevel: $0.maxLevel) })
    }
}
#endif
