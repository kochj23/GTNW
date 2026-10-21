//
//  ManpowerModel.swift
//  Global Thermal Nuclear War
//
//  Draft and mobilization (3.9.0). U.S. troop numbers are finite and era-based: the regular army plus the organized
//  militia / National Guard of the day, and draftees while a draft is in force. Historical drafts apply on their dates
//  (Civil War 1863–65, 1917–18, Selective Service 1940–47 and 1948–73); after 1973 the force is all-volunteer and a
//  draft or a reserve mobilization must be called, at a political cost, with time to train. You can't send troops you
//  don't have: sizing (3.4.0), expeditions and garrisons all draw on this pool.
//  Figures are rounded, encyclopedia-level ground-force strengths in thousands (see Documentation/arsenal,
//  option land_infantry, scale_note); the step table is a design simplification.
//  Repository: https://github.com/kochj23/GTNW
//

import Foundation

enum ManpowerKind: String, Codable { case draft, mobilization }

/// A draft or reserve mobilization the President called (historical drafts need no record).
struct Mobilization: Codable, Hashable {
    var kind: ManpowerKind
    var started: Date
}

enum ManpowerModel {
    /// Regulars + organized militia / Guard (thousands) from a year on: small early republic, the War of 1812 army,
    /// the frontier army, Civil War volunteers, the post-war army, 1898 volunteers, the pre-WWI army and Guard,
    /// the interwar army, the post-WWII and Cold War forces, the post-Cold-War all-volunteer force.
    static let standing: [(from: Int, thousands: Double)] = [
        (1789, 3), (1798, 8), (1812, 50), (1816, 15), (1846, 60), (1849, 20), (1861, 600), (1866, 60), (1870, 45),
        (1898, 250), (1899, 160), (1903, 200), (1917, 400), (1919, 300), (1922, 250), (1940, 450), (1946, 900),
        (1950, 1000), (1954, 1300), (1973, 1300), (1991, 1100), (2001, 1150), (2015, 1100),
    ]

    /// Historical drafts in force, and how many draftees they add at full strength (thousands).
    static let historicalDrafts: [(name: String, from: Date, to: Date, thousands: Double)] = [
        ("Enrollment Act (Civil War)", GameCalendar.date(year: 1863, month: 3, day: 3), GameCalendar.date(year: 1865, month: 5, day: 1), 400),
        ("Selective Service Act of 1917", GameCalendar.date(year: 1917, month: 5, day: 18), GameCalendar.date(year: 1918, month: 11, day: 11), 2800),
        ("Selective Training and Service Act", GameCalendar.date(year: 1940, month: 9, day: 16), GameCalendar.date(year: 1947, month: 3, day: 31), 7000),
        ("Selective Service Act of 1948", GameCalendar.date(year: 1948, month: 6, day: 24), GameCalendar.date(year: 1973, month: 1, day: 27), 700),
    ]

    /// End of the draft: the all-volunteer force from 27 Jan 1973.
    static let allVolunteer = GameCalendar.date(year: 1973, month: 1, day: 27)

    /// Weeks of training before called-up men count: a draft takes about six months, a reserve call-up one.
    static func trainingMonths(_ kind: ManpowerKind) -> Double { kind == .draft ? 6 : 1 }

    static func standing(year: Int) -> Double { standing.last { $0.from <= year }?.thousands ?? standing[0].thousands }

    static func historicalDraft(on date: Date) -> (name: String, from: Date, to: Date, thousands: Double)? {
        historicalDrafts.first { date >= $0.from && date < $0.to }
    }

    /// What a called draft or mobilization adds at full strength: a draft doubles the standing force (at least
    /// 500K), a mobilization adds 30%.
    static func callUpSize(_ kind: ManpowerKind, year: Int) -> Double {
        kind == .draft ? max(500, standing(year: year)) : standing(year: year) * 0.3
    }

    /// Political cost of calling one (design choice): a draft −8 approval and −5 Congress (−3 / −2 at war),
    /// a mobilization −2 / −1.
    static func callCost(_ kind: ManpowerKind, atWar: Bool) -> (popularity: Double, congress: Int) {
        switch kind {
        case .draft: return atWar ? (-3, -2) : (-8, -5)
        case .mobilization: return (-2, -1)
        }
    }

    /// Ramp from 0 to 1 over the training time.
    static func trained(since: Date, now: Date, kind: ManpowerKind) -> Double {
        let months = Double(GameCalendar.days(from: since, to: now)) / 30.4
        return max(0, min(1, months / trainingMonths(kind)))
    }

    /// All U.S. ground troops (thousands) on a date: standing force, a historical draft in force (trained over six
    /// months from its start), and any draft or mobilization the President called.
    static func total(on date: Date, called: [Mobilization]) -> Double {
        let year = GameCalendar.year(of: date)
        var t = standing(year: year)
        if let h = historicalDraft(on: date) { t += h.thousands * trained(since: h.from, now: date, kind: .draft) }
        for m in called where historicalDraft(on: date) == nil || m.kind == .mobilization {
            t += callUpSize(m.kind, year: year) * trained(since: m.started, now: date, kind: m.kind)
        }
        return t
    }
}

// MARK: - Engine

extension GameEngine {
    /// True when the player is the United States (manpower tables are U.S. figures; others use the force pool).
    var playerIsUS: Bool { gameState?.playerCountryID == "USA" }

    /// Can the President call one now? Nil when allowed, else why not.
    func callUpProblem(_ kind: ManpowerKind) -> String? {
        guard let gs = gameState else { return "No game." }
        if gs.playerCountryID != "USA" { return "Drafts are modelled for the United States only." }
        if gs.actionsRemaining == 0 { return "No actions left this \(gs.turnLength.displayName.lowercased())." }
        if gs.shadow.mobilizations.contains(where: { $0.kind == kind }) { return "Already called." }
        if kind == .draft, let h = ManpowerModel.historicalDraft(on: gs.currentDate) { return "The \(h.name) is already in force." }
        return nil
    }

    /// Call a draft or mobilize the reserves (one action), at a political cost; troops arrive as they finish training.
    @discardableResult
    func callUp(_ kind: ManpowerKind) -> Bool {
        guard callUpProblem(kind) == nil, let gs = gameState, let pi = gs.countries.firstIndex(where: { $0.id == gs.playerCountryID }) else { return false }
        let atWar = !gs.countries[pi].atWarWith.isEmpty
        let cost = ManpowerModel.callCost(kind, atWar: atWar)
        gs.shadow.mobilizations.append(Mobilization(kind: kind, started: gs.currentDate))
        gs.shadow.popularity = PopularityModel.clamp(gs.shadow.popularity + cost.popularity)
        gs.countries[pi].congressionalSupport = max(0, gs.countries[pi].congressionalSupport + cost.congress)
        let size = Int(ManpowerModel.callUpSize(kind, year: gs.currentYear))
        gs.shadow.post(kind == .draft ? "The President orders a military draft: \(size)K men to be trained over six months."
                                      : "The President mobilizes the reserves: \(size)K troops within a month.", date: gs.currentDate, severity: 2)
        logPlayEvent(kind == .draft ? "draft_called" : "mobilization_called", detail: ["thousands": size, "game_date": PlayHistory.day(gs.currentDate)])
        self.gameState = gs
        completePlayerAction()
        return true
    }

    /// Stand down a called draft or mobilization (free); its men leave the pool at once.
    @discardableResult
    func standDown(_ kind: ManpowerKind) -> Bool {
        guard let gs = gameState, let i = gs.shadow.mobilizations.firstIndex(where: { $0.kind == kind }) else { return false }
        gs.shadow.mobilizations.remove(at: i)
        gs.shadow.popularity = PopularityModel.clamp(gs.shadow.popularity + (kind == .draft ? 3 : 1))
        gs.shadow.post(kind == .draft ? "The draft ends." : "The reserves stand down.", date: gs.currentDate, severity: 1)
        self.gameState = gs
        return true
    }
}
