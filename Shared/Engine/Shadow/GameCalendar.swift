//
//  GameCalendar.swift
//  Global Thermal Nuclear War
//
//  A real game calendar. Every game starts on Inauguration Day (Jan 20) of its era year (scenarios may pick another
//  date) and each turn advances the clock by a fixed length: a day, a week, a month (the default) or a year.
//  Everything that used to treat "one turn" as "one year" asks the calendar instead, so a monthly game runs at the
//  same historical speed as a yearly one — just with twelve times the decisions.
//  Repository: https://github.com/kochj23/GTNW
//

import Foundation

/// How much game time one turn covers.
enum TurnLength: String, Codable, CaseIterable, Identifiable {
    case day, week, month, year

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .day: return "Day"
        case .week: return "Week"
        case .month: return "Month"
        case .year: return "Year"
        }
    }

    /// Fraction of a year one turn represents (used to scale annual rates).
    var yearFraction: Double {
        switch self {
        case .day: return 1.0 / 365.25
        case .week: return 7.0 / 365.25
        case .month: return 1.0 / 12.0
        case .year: return 1.0
        }
    }

    /// Player actions allowed per turn. Short turns get one decision; long turns get several.
    var actionsPerTurn: Int {
        switch self {
        case .day, .week: return 1
        case .month: return 2
        case .year: return 4
        }
    }

    var calendarComponent: Calendar.Component {
        switch self {
        case .day: return .day
        case .week: return .weekOfYear
        case .month: return .month
        case .year: return .year
        }
    }

    /// Default for new games, read from Settings (UserDefaults key `GTNW.turnLength`). Month unless changed.
    static func defaultForNewGames(_ defaults: UserDefaults = .standard) -> TurnLength {
        defaults.string(forKey: GameCalendar.turnLengthDefaultsKey).flatMap(TurnLength.init(rawValue:)) ?? .month
    }
}

/// Pure calendar math shared by GameState, the simulation and tests.
enum GameCalendar {
    static let turnLengthDefaultsKey = "GTNW.turnLength"

    /// Gregorian calendar pinned to UTC so dates never wobble with the player's time zone.
    static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    static func date(year: Int, month: Int, day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)) ?? Date(timeIntervalSince1970: 0)
    }

    /// Inauguration Day of a given year — the default start of every presidency.
    static func inauguration(year: Int) -> Date { date(year: year, month: 1, day: 20) }

    static func advance(_ start: Date, by length: TurnLength, turns: Int) -> Date {
        calendar.date(byAdding: length.calendarComponent, value: turns, to: start) ?? start
    }

    static func year(of date: Date) -> Int { calendar.component(.year, from: date) }

    /// U.S. presidential election day: the Tuesday after the first Monday of November, in years divisible by 4.
    static func electionDay(year: Int) -> Date {
        let nov1 = date(year: year, month: 11, day: 1)
        let weekday = calendar.component(.weekday, from: nov1)      // 1 = Sunday, 2 = Monday
        let daysToMonday = (2 - weekday + 7) % 7
        return calendar.date(byAdding: .day, value: daysToMonday + 1, to: nov1) ?? nov1
    }

    /// The first presidential election on or after `date`.
    static func nextElection(after date: Date) -> Date {
        var y = year(of: date)
        while true {
            if y % 4 == 0 {
                let e = electionDay(year: y)
                if e >= calendar.startOfDay(for: date) { return e }
            }
            y += 1
        }
    }

    static func days(from a: Date, to b: Date) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: a), to: calendar.startOfDay(for: b)).day ?? 0
    }

    static func years(from a: Date, to b: Date) -> Double {
        b.timeIntervalSince(a) / (365.2425 * 86_400)
    }

    /// True when `moment` falls in the half-open window (from, to].
    static func window(from: Date, to: Date, contains moment: Date) -> Bool {
        moment > from && moment <= to
    }

    /// True when the window (from, to] contains a given month/day anniversary in any year.
    static func window(from: Date, to: Date, containsMonth month: Int, day: Int) -> Bool {
        guard to > from else { return false }
        for y in year(of: from)...year(of: to) {
            if window(from: from, to: to, contains: date(year: y, month: month, day: day)) { return true }
        }
        return false
    }

    static let shortFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "MMM d, yyyy"
        return f
    }()

    static func format(_ date: Date) -> String { shortFormatter.string(from: date) }
}

// MARK: - Rate scaling

/// Converts per-year game rates into per-turn ones. All simulation code goes through these helpers so a Month
/// game is not twelve times faster (or more violent) than a Year game.
struct TurnScale {
    let yearFraction: Double

    init(_ length: TurnLength) { yearFraction = length.yearFraction }
    init(yearFraction: Double) { self.yearFraction = yearFraction }

    /// Probability that an event with annual probability `p` happens during one turn.
    func probability(annual p: Double) -> Double {
        let clamped = min(max(p, 0), 1)
        if clamped >= 1 { return 1 }
        return 1 - pow(1 - clamped, yearFraction)
    }

    /// An annual amount spread over one turn.
    func amount(annual x: Double) -> Double { x * yearFraction }

    /// An annual integer amount for one turn, rounded stochastically so small per-turn shares are not lost.
    func integer(annual x: Double, roll: Double = Double.random(in: 0..<1)) -> Int {
        let v = x * yearFraction
        let base = v.rounded(.towardZero)
        let frac = abs(v - base)
        return Int(base) + (roll < frac ? (v < 0 ? -1 : 1) : 0)
    }

    /// Exponential drift: the per-turn multiplier for an annual growth rate `g` (0.03 = 3%/year).
    func growthFactor(annual g: Double) -> Double { pow(1 + g, yearFraction) }

    /// How many turns cover `years` (at least one).
    func turns(forYears years: Double) -> Int { max(1, Int((years / yearFraction).rounded())) }
}
