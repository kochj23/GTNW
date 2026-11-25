//
//  PresidencyCareerVerb.swift
//  GTNWCore
//
//  `{"verb":"presidencyCareer","career":"{…}"}` (3.37): restore the record of the presidency's career (games played,
//  wars, awards earned in earlier games) the front end kept between visits (the `presidency` query's `stored`). The
//  app keeps it in its defaults; the core keeps it for the page's lifetime. Nothing in the game changes until the
//  awards are decided at game over.
//

#if GTNW_CORE
import Foundation

enum PresidencyCareerVerb: BridgeVerb {
    static let name = "presidencyCareer"

    struct Args: Decodable { var career: String }

    static func run(_ a: Args, engine e: GameEngine, state gs: GameState) throws -> GTNWBridge.Report? {
        guard a.career.utf8.count <= 16 * 1024 else { throw QueryError("career too large") }
        guard var c = try? JSONDecoder().decode(PresidencyCareer.self, from: Data(a.career.utf8)) else { throw QueryError("not a career") }
        let known = Set(PresidencyAwards.all.map(\.id))
        c.awards = c.awards.filter { known.contains($0) }.reduce(into: []) { if !$0.contains($1) { $0.append($1) } }
        guard [c.games, c.antarcticaGames, c.warsStarted, c.warsWon].allSatisfy({ (0...1_000_000).contains($0) }) else {
            throw QueryError("not a career")
        }
        PresidencyCareer.save(c)
        return nil
    }
}
#endif
