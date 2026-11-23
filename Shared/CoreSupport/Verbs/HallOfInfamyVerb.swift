//
//  HallOfInfamyVerb.swift
//  GTNWCore
//
//  `{"verb":"hallOfInfamy","hall":"{…}"}`: restore the Hall of Infamy the front end kept between visits (the
//  `records` query's `hall`). The app keeps it in its defaults; the core keeps it for the page's lifetime.
//

#if GTNW_CORE
import Foundation

enum HallOfInfamyVerb: BridgeVerb {
    static let name = "hallOfInfamy"

    struct Args: Decodable { var hall: String }

    static func run(_ a: Args, engine e: GameEngine, state gs: GameState) throws -> GTNWBridge.Report? {
        guard a.hall.utf8.count <= 16 * 1024 else { throw QueryError("hall too large") }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .secondsSince1970
        guard let raw = try? dec.decode([String: InfamyEntry].self, from: Data(a.hall.utf8)) else { throw QueryError("not a hall") }
        let hall = Dictionary(uniqueKeysWithValues: raw.compactMap { k, v in
            InfamyRecord(rawValue: k).flatMap { v.value.isFinite ? ($0, InfamyEntry(value: v.value, who: String(v.who.prefix(80)), gameDate: v.gameDate, setAt: v.setAt)) : nil }
        })
        HallOfInfamy.save(hall)
        return nil
    }
}
#endif
