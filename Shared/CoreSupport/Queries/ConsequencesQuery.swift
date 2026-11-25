//
//  ConsequencesQuery.swift
//  GTNWCore
//
//  `{"q":"consequences","target":"…"?}` (3.37): what the world remembers (Consequences.swift, 3.36.0): the acts on
//  the record that a court could charge (tribunal cases, written when they happened), emergency alliance councils
//  and expulsions, refugee waves and the President's answers, lands that broke away from a victim, and the trial the
//  end screen shows if the presidency ended that way. With `target`: whether that nation is protected (surrendered,
//  at peace under signed terms, a friend) and the warnings the command card adds before a hostile order on it.
//  Refugees reaching the President's border arrive as a crisis (the `crisis` query); this only reads.
//

#if GTNW_CORE
import Foundation

enum ConsequencesQuery: BridgeQuery {
    static let name = "consequences"

    struct Args: Decodable { var target: String? }

    struct Count: Encodable { var charge: String; var target: String; var date: String; var text: String; var triable: Bool }
    struct Council: Encodable { var alliance: String; var victim: String; var opened: String; var expelled: Bool; var closed: Bool; var members: [String] }
    struct Wave: Encodable { var origin: String; var cause: String; var date: String; var thousands: Int; var toYou: Int?; var choice: String? }
    struct Warning: Encodable { var text: String; var level: Int }
    struct Protection: Encodable { var target: String; var status: String?; var warnings: [Warning] }
    struct Block: Encodable { var title: String; var body: String }

    struct Result: Encodable {
        var counts: [Count]
        var court: String?
        var councils: [Council]
        var waves: [Wave]
        var expelledFrom: [String]
        var brokenAway: [String]
        var trial: Block?
        var protection: Protection?
    }

    static func run(_ a: Args, engine: GameEngine?) throws -> Result {
        let (e, gs) = try GTNWBridge.game(engine)
        let c = gs.shadow.consequences
        func name(_ id: String) -> String { gs.getCountry(id: id)?.name ?? id }
        let counts = Consequences.counts(gs).map {
            Count(charge: $0.kind.charge, target: $0.target.isEmpty ? "" : name($0.target), date: GameCalendar.format($0.date), text: $0.text,
                  triable: GameCalendar.year(of: $0.date) >= Consequences.courtsFrom)
        }
        let councils = c.councils.suffix(12).reversed().map {
            Council(alliance: $0.alliance, victim: name($0.victim), opened: GameCalendar.format($0.opened), expelled: $0.expelled, closed: $0.closed,
                    members: $0.members.map(name))
        }
        let waves = c.waves.suffix(12).reversed().map {
            Wave(origin: name($0.origin), cause: name($0.cause), date: GameCalendar.format($0.date), thousands: $0.total,
                 toYou: $0.receivers[gs.playerCountryID], choice: $0.playerChoice)
        }
        var protection: Protection?
        if let t = a.target, let target = gs.getCountry(id: t), t != gs.playerCountryID {
            let status: String?
            switch Consequences.protection(of: t, in: gs) {
            case .surrendered?: status = "surrendered"
            case .peace?: status = "peace"
            case .friend?: status = "friend"
            case nil: status = nil
            }
            protection = Protection(target: target.name, status: status,
                                    warnings: e.consequenceWarnings(target, in: gs, nuclear: true).map { Warning(text: $0.text, level: $0.level) })
        }
        return Result(counts: counts, court: gs.currentYear >= Consequences.courtsFrom ? Consequences.court(year: gs.currentYear) : nil,
                      councils: councils, waves: waves, expelledFrom: c.expelledFrom, brokenAway: c.brokenAway.map(name),
                      trial: Consequences.trial(gs).map { Block(title: $0.title, body: $0.body) }, protection: protection)
    }
}
#endif
