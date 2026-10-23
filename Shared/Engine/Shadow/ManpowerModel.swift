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
    /// 3.14.0: before 1861 a "mobilization" is a militia call (the Whiskey Rebellion call was ~13K; War of 1812
    /// and Mexican War calls ~50K), and there is no federal draft before the Enrollment Act of 1863.
    static func callUpSize(_ kind: ManpowerKind, year: Int) -> Double {
        if kind == .draft { return max(500, standing(year: year)) }
        return max(standing(year: year) * 0.3, year < 1812 ? 13 : (year < 1861 ? 50 : 0))
    }

    static let firstDraftYear = 1863
    static func militiaEra(_ year: Int) -> Bool { year < 1861 }

    /// "CALL OUT THE MILITIA" before 1861, "MOBILIZE THE RESERVES" after.
    static func title(_ kind: ManpowerKind, year: Int) -> String {
        kind == .draft ? "Call a draft" : (militiaEra(year) ? "Call out the militia" : "Mobilize the reserves")
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
        if kind == .draft && gs.currentYear < ManpowerModel.firstDraftYear { return "No federal draft before the Enrollment Act of 1863: call out the militia instead." }
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
        let size = max(1, Int(ManpowerModel.callUpSize(kind, year: gs.currentYear).rounded()))
        gs.shadow.post(kind == .draft ? "The President orders a military draft: \(size)K men to be trained over six months."
                       : (ManpowerModel.militiaEra(gs.currentYear) ? "The President calls out the militia: \(size)K men within a month."
                          : "The President mobilizes the reserves: \(size)K troops within a month."), date: gs.currentDate, severity: 2)
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

// MARK: - National Guard at home (3.18.18)

/// The domestic National Guard: troops on American soil for disaster relief or to restore order. Relief is popular;
/// putting soldiers between the government and its own citizens is not, and the public's tolerance for it collapses
/// in the civil-rights era (Little Rock 1957, Kent State 1970) and never fully recovers. DESIGN CHOICES.
enum GuardModel {
    /// The political cost of calling the Guard out to restore order at home (ruthlessness up, approval down), by era.
    static func homeFrontCost(year: Int) -> (ruthlessness: Double, popularity: Double) {
        switch year {
        case ..<1900: return (2, 1)    // routine; the militia keeping order was unremarkable
        case ..<1960: return (5, 3)    // the Bonus Army (1932), Little Rock (1957) — it draws notice
        case ..<1992: return (12, 8)   // Kent State (1970), the civil-rights era — troops on citizens is explosive
        default:      return (10, 7)   // posse-comitatus norms; heavy, somewhat normalized after 2001
        }
    }
}

extension GameEngine {
    /// Call out the National Guard on the home front (U.S., one action). During a natural disaster it is relief —
    /// stability and approval rise. Otherwise it is restoring order — stability rises and unrest falls, but at the
    /// era's political cost (ruthlessness up, approval down); the post-1960s public recoils at troops in the streets.
    @discardableResult
    func callNationalGuard() -> Bool {
        guard let gs = gameState, gs.playerCountryID == "USA", gs.actionsRemaining > 0,
              let pi = gs.countries.firstIndex(where: { $0.id == gs.playerCountryID }) else { return false }
        let disaster = crisisManager.activeCrisis?.type == .naturalDisaster
        gs.countries[pi].stability = min(100, gs.countries[pi].stability + (disaster ? 12 : 15))
        gs.countries[pi].profile.anxieties.social = max(0, gs.countries[pi].profile.anxieties.social - 20)
        gs.countries[pi].profile.outcry = max(0, gs.countries[pi].profile.outcry - (disaster ? 10 : 25))
        if disaster {
            gs.shadow.popularity = PopularityModel.clamp(gs.shadow.popularity + 6)
            gs.shadow.post("The National Guard deploys for disaster relief. The country is grateful.", date: gs.currentDate, severity: 2)
        } else {
            let cost = GuardModel.homeFrontCost(year: gs.currentYear)
            gs.shadow.ruthlessness += cost.ruthlessness
            gs.shadow.popularity = PopularityModel.clamp(gs.shadow.popularity - cost.popularity)
            gs.shadow.post("The National Guard is called out to restore order. Troops are in American streets.", date: gs.currentDate, severity: 2)
        }
        logPlayEvent("national_guard", detail: ["mission": disaster ? "relief" : "order", "game_date": PlayHistory.day(gs.currentDate)])
        self.gameState = gs
        completePlayerAction()
        return true
    }
}
