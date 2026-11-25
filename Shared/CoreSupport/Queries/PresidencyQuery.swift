//
//  PresidencyQuery.swift
//  GTNWCore
//
//  `{"q":"presidency"}` (3.37): the record of the presidency (PresidencyRecord.swift) as the app's end screen and
//  Records → AWARDS tab show it (PresidencyEpilogueView, PresidencyAwardsPanel): every award with whether it was earned
//  this game (and first earned this game) or in an earlier one, the career line, the overruled warnings ("I told you
//  so"), and once the game is over the epilogue: the history books' verdict, the library, fifty years later, and the
//  trial (Consequences.trial). `career` is the career as kept (the front end stores it between visits and gives it
//  back with the `presidencyCareer` verb, as the app keeps it in its defaults).
//

#if GTNW_CORE
import Foundation

enum PresidencyQuery: BridgeQuery {
    static let name = "presidency"

    struct Award: Encodable {
        var id: String
        var name: String
        var description: String
        var rarity: String
        /// Earned this game / first earned this game / earned in any game (the career).
        var thisGame: Bool
        var isNew: Bool
        var earned: Bool
    }

    struct Warning: Encodable {
        var date: String
        var speaker: String
        var order: String
        var quote: String
        var testified: Bool
    }

    struct Afterlife: Encodable {
        var land: String
        var hisName: String
        var original: String
        var survives: Bool
        var line: String
    }

    struct Block: Encodable { var title: String; var body: String }

    struct Epilogue: Encodable {
        var verdict: String
        /// The verdict was polished by a model (never in the core; kept for the shape the app shows).
        var polished: Bool
        var library: String
        var fiftyYearsLater: [Afterlife]
        var trial: Block?
    }

    struct Career: Encodable {
        var games: Int
        var antarcticaGames: Int
        var warsStarted: Int
        var warsWon: Int
        var line: String
        var earned: Int
        var total: Int
    }

    struct Result: Encodable {
        var awards: [Award]
        var careerLine: String?
        var career: Career
        /// The career as stored (JSON), for the front end to keep and restore.
        var stored: String
        var warnings: [Warning]
        var overruledPosts: [String]
        var followed: Int
        var orders: Int
        var closed: Bool
        /// "4 lands held abroad: 3 territories and 1 government installed (Cuba)." (3.37), nil when none.
        var landsHeld: String?
        var epilogue: Epilogue?
    }

    static func run(_ args: NoArgs, engine: GameEngine?) throws -> Result {
        let (e, gs) = try GTNWBridge.game(engine)
        let r = gs.shadow.presidency
        let career = PresidencyCareer.load()
        let awards = PresidencyAwards.all.map { a in
            Award(id: a.id, name: a.name, description: a.description, rarity: a.rarity, thisGame: r.awards.contains(a.id),
                  isNew: r.firstAwards.contains(a.id), earned: career.awards.contains(a.id) || r.awards.contains(a.id))
        }
        let warnings = r.warnings.suffix(10).reversed().map {
            Warning(date: GameCalendar.format($0.date), speaker: $0.speaker, order: $0.order, quote: ToldYouSo.quote($0.text), testified: $0.testified)
        }
        var epilogue: Epilogue?
        if gs.gameOver {
            let victory = e.victoryType ?? gs.victoryType
            epilogue = Epilogue(verdict: PresidencyEpilogue.verdict(gs, victory: victory), polished: r.verdict != nil,
                                library: PresidencyEpilogue.library(gs),
                                fiftyYearsLater: PresidencyEpilogue.fiftyYearsLater(gs).map {
                                    Afterlife(land: $0.land, hisName: $0.hisName, original: $0.original, survives: $0.survives, line: $0.line)
                                },
                                trial: Consequences.trial(gs).map { Block(title: $0.title, body: $0.body) })
        }
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]   // the same text in every process (hash order differs)
        let stored = (try? enc.encode(career)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        return Result(awards: awards, careerLine: r.careerLine,
                      career: Career(games: career.games, antarcticaGames: career.antarcticaGames, warsStarted: career.warsStarted,
                                     warsWon: career.warsWon, line: career.line, earned: awards.filter(\.earned).count, total: awards.count),
                      stored: stored, warnings: warnings, overruledPosts: r.overruledPosts, followed: r.followed, orders: r.orders,
                      closed: r.closed, landsHeld: PresidencyEpilogue.landsHeld(gs), epilogue: epilogue)
    }
}
#endif
