//
//  Doctrines.swift
//  Global Thermal Nuclear War
//
//  3.32.3: what worked once becomes what the room recommends. Every instrument the President or a computer-run
//  power uses successfully is remembered — a blockade that brought a country to terms, a nuclear bluff that was
//  not called, a war won in a season, a dirty tactic nobody traced — and the memory tilts the next recommendation
//  toward doing it again, including in a year when none of the conditions that made it work still hold.
//  The tilt is never a hidden dice roll: the cabinet says why it likes the move ("it worked in 1912, Mr.
//  President"), and when the lesson is old or the conditions have changed it says that too, so the player can see
//  the reason is a habit rather than an argument. Victory teaches dangerous lessons as readily as defeat teaches
//  useful ones.
//  Weights and the staleness threshold are design choices.
//  Repository: https://github.com/kochj23/GTNW
//

import Foundation

/// An instrument a government can form a habit about.
enum Doctrine: String, Codable, CaseIterable, Identifiable {
    case blockade, bluff, rapidWar, dirtyTactic, covert, diplomacy, sanctions
    var id: String { rawValue }

    var title: String {
        switch self {
        case .blockade: return "the blockade"
        case .bluff: return "the nuclear bluff"
        case .rapidWar: return "the short, sharp war"
        case .dirtyTactic: return "the quiet method"
        case .covert: return "the covert hand"
        case .diplomacy: return "the conference table"
        case .sanctions: return "economic pressure"
        }
    }

    /// Which action belongs to which habit.
    static func of(_ action: PresidentialAction) -> Doctrine? {
        switch action {
        case .navalBlockade: return .blockade
        case .groundInvasion, .airStrike: return .rapidWar
        case .sanctions, .freezeAssets: return .sanctions
        case .assassinate, .stageCoup, .infiltrate, .cyberAttack, .sabotageNuke, .bribe: return .covert
        case .economicAid, .proposeTreaty, .stateVisit, .sendAmbassador, .forgiveDebt: return .diplomacy
        default: return action.rung == .nuclear ? .bluff : nil
        }
    }
}

/// What a government remembers about an instrument.
struct DoctrineRecord: Codable, Hashable {
    var wins = 0
    var losses = 0
    var lastWinYear: Int?
    var lastWinNote: String?

    /// How strongly the room leans on it: wins count, losses argue back, and nothing above 1.5.
    var pull: Double { min(1.5, max(0, Double(wins) * 0.5 - Double(losses) * 0.25)) }
}

enum Doctrines {
    /// Years after which a lesson is old enough that leaning on it is a habit, not an argument.
    static let staleYears = 15
    /// Records kept (the player's own, plus the great powers').
    static let keep = 60

    static func key(_ actor: String, _ d: Doctrine) -> String { "\(actor):\(d.rawValue)" }

    /// The cabinet's own words for why it likes a move — and, when the lesson is old, why that is not an argument.
    static func reason(_ d: Doctrine, _ r: DoctrineRecord, year: Int) -> String? {
        guard r.wins > 0, let won = r.lastWinYear else { return nil }
        let note = r.lastWinNote ?? "it worked"
        let age = year - won
        if age >= staleYears {
            return "We have done this before: \(note) in \(won). That was \(age) years ago, Mr. President, and a different world — but it is what the building knows."
        }
        return "We have done this before: \(note) in \(won). It worked then, and the room likes what it knows."
    }

    /// What a nation's habits add to a move's weight in the living world.
    static func pull(_ actor: String, _ d: Doctrine, in gs: GameState) -> Double {
        gs.shadow.doctrines[key(actor, d)]?.pull ?? 0
    }
}

extension GameEngine {
    /// A war only teaches the short, sharp war when it was short: a year or less (design choice).
    func recordDoctrine(_ d: Doctrine, actor: String, won: Bool, days: Int, note: String) {
        guard !won || days <= 365 else { return recordDoctrine(d, actor: actor, won: false, note: note + ", but it took years") }
        recordDoctrine(d, actor: actor, won: won, note: note + " in \(max(1, days / 30)) months")
    }

    /// Remember how an instrument turned out. `note` is the room's own phrase for it.
    func recordDoctrine(_ d: Doctrine, actor: String, won: Bool, note: String) {
        guard let gs = gameState else { return }
        let k = Doctrines.key(actor, d)
        var r = gs.shadow.doctrines[k] ?? DoctrineRecord()
        if won {
            r.wins += 1
            r.lastWinYear = gs.currentYear
            r.lastWinNote = note
        } else {
            r.losses += 1
        }
        gs.shadow.doctrines[k] = r
        if gs.shadow.doctrines.count > Doctrines.keep, let oldest = gs.shadow.doctrines.first(where: { $0.value.wins == 0 })?.key {
            gs.shadow.doctrines.removeValue(forKey: oldest)
        }
        if actor == gs.playerCountryID, won {
            logPlayEvent("doctrine_learned", detail: ["doctrine": d.rawValue, "wins": r.wins,
                                                      "note": PlayHistory.text(note), "game_date": PlayHistory.day(gs.currentDate)])
        }
        self.gameState = gs
    }
}
