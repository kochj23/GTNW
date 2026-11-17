//
//  HistoricalWars.swift
//  Global Thermal Nuclear War
//
//  3.30.0: the historical record of war, from Documentation/wars/build.py. `base_rates.json` holds aggregate
//  statistics only (median / quartile duration and outcome shares by war type × era × capability ratio), computed
//  from the Correlates of War data, UCDP and a curated 1789–1815 list; `open_wars.json` holds per-war records only
//  from UCDP (CC BY 4.0) and the curated list. The base rates are a target for the attrition model and a line in
//  the AI brains' prompt, never a script: randomness stays.
//  Repository: https://github.com/kochj23/GTNW
//

import Foundation

enum HistoricalWars {
    struct Rate: Codable, Equatable {
        var n: Int
        var median_months: Double
        var q1_months: Double
        var q3_months: Double
        var decisive: Double
        var negotiated: Double
        /// 3.32.2: of the wars in this cell with a coded initiator, the share the initiator's side won. The record
        /// holds the wars that were fought, not the ones wisely declined, so this is the survivorship correction.
        var initiator_won: Double?
    }

    /// 3.32.2: one nation's own war record in an era (aggregates only).
    struct NationRate: Codable, Equatable {
        var n: Int
        var as_initiator: Int
        var initiator_won: Double?
        var lost: Double
        var median_months: Double
    }

    /// 3.32.2: what this kind of war cost in that century, and how often the side that started it lost.
    struct Stakes: Codable, Equatable {
        var n: Int
        var median_battle_deaths: Int?
        var share_decisive: Double
        var share_initiator_lost: Double?
    }

    struct OpenWar: Codable {
        var name: String
        var type: String
        var start: String
        var end: String?
        var side_a: [String]
        var side_b: [String]
    }

    private struct RatesFile: Codable {
        var rates: [String: [String: [String: Rate]]]
        var nations: [String: [String: NationRate]]?
        var stakes: [String: Stakes]?
    }
    private struct OpenFile: Codable { var wars: [OpenWar] }

    private static func load<T: Decodable>(_ name: String, _ type: T.Type) -> T? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json"), let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    /// type → era → bucket ("all", "even", "lopsided", "overwhelming") → rate. Empty when the resource is missing.
    private static let file = load("base_rates", RatesFile.self)
    static let rates: [String: [String: [String: Rate]]] = file?.rates ?? [:]
    /// 3.32.2: per-nation records (only nations with at least three interstate wars in an era) and era stakes.
    static let nations: [String: [String: NationRate]] = file?.nations ?? [:]
    static let stakes: [String: Stakes] = file?.stakes ?? [:]
    static let openWars: [OpenWar] = load("open_wars", OpenFile.self)?.wars ?? []

    /// The dataset's era for a year.
    static func era(_ year: Int) -> String {
        switch year {
        case ..<1816: return "1789-1815"
        case ..<1871: return "1816-1870"
        case ..<1914: return "1871-1913"
        case ..<1946: return "1914-1945"
        case ..<1992: return "1946-1991"
        default: return "1992-present"
        }
    }

    /// The stronger side's share of combined strength → the dataset's bucket.
    static func bucket(strongerShare s: Double) -> String { s < 0.65 ? "even" : (s < 0.9 ? "lopsided" : "overwhelming") }

    /// The base rate for an interstate war in `year` at that strength share: the bucket when it holds at least five
    /// wars, else the era's whole row.
    static func interstate(year: Int, strongerShare: Double? = nil) -> Rate? {
        let row = rates["interstate"]?[era(year)]
        if let s = strongerShare, let r = row?[bucket(strongerShare: s)], r.n >= 5 { return r }
        return row?["all"]
    }

    /// "Interstate wars 1946–1991: median 4.7 months (IQR 2–12); 23% ended in a ceasefire or settlement, 63%
    /// decisively; the side that started them won 37%." 3.32.2: the initiator's share is the survivorship
    /// correction — this record holds the wars that were fought, not the ones wisely declined.
    static func line(year: Int, strongerShare: Double? = nil) -> String? {
        guard let r = interstate(year: year, strongerShare: strongerShare) else { return nil }
        let label = era(year).replacingOccurrences(of: "-", with: "–")
        var out = String(format: "Interstate wars %@: median %.1f months (IQR %.0f–%.0f); %d%% ended in a ceasefire or settlement, %d%% decisively.",
                         label, r.median_months, r.q1_months, r.q3_months, Int((r.negotiated * 100).rounded()), Int((r.decisive * 100).rounded()))
        if let w = r.initiator_won {
            out += " The side that started them won \(Int((w * 100).rounded()))% — and these are the wars that were fought, not the ones wisely declined."
        }
        if let s = stakes[era(year)] {
            if let d = s.median_battle_deaths {
                out += String(format: " A war of this kind cost about %@ dead in this century", bigNumber(d))
                out += s.share_initiator_lost.map { String(format: ", and the side that began it lost outright %d%% of the time.", Int(($0 * 100).rounded())) } ?? "."
            } else if let l = s.share_initiator_lost {
                out += " The side that began such a war lost outright \(Int((l * 100).rounded()))% of the time."
            }
        }
        return out
    }

    /// 3.32.2: a nation's own record, where it has one. "France has fought 6 interstate wars since 1816; it began
    /// 2 of them and won 1; its wars ran 11 months at the median."
    static func nationLine(_ id: String, year: Int, name: String? = nil) -> String? {
        guard let r = nations[id]?[era(year)] else { return nil }
        let who = name ?? id
        var out = String(format: "%@'s own record in %@: %d wars, %d of them its own doing", who,
                         era(year).replacingOccurrences(of: "-", with: "–"), r.n, r.as_initiator)
        if let w = r.initiator_won { out += String(format: ", of which it won %d%%", Int((w * 100).rounded())) }
        out += String(format: "; it was beaten in %d%% of them; the median ran %.0f months.", Int((r.lost * 100).rounded()), r.median_months)
        return out
    }

    /// The chance the record gives the side that starts a war of this kind, or nil when the record is silent.
    static func initiatorOdds(year: Int, strongerShare: Double? = nil) -> Double? {
        interstate(year: year, strongerShare: strongerShare)?.initiator_won
            ?? stakes[era(year)]?.share_initiator_lost.map { 1 - $0 }
    }

    static func bigNumber(_ n: Int) -> String {
        n >= 1_000_000 ? String(format: "%.1f million", Double(n) / 1_000_000) : (n >= 1000 ? "\(n / 1000),000" : "\(n)")
    }

    /// Interstate wars from the open records as (aggressor, defender, from, to): the first named side-A state
    /// against each side-B state. Ongoing wars are left out (the rivalries table already holds the ones the game
    /// starts with).
    static func openPairs() -> [(a: String, b: String, from: Int, to: Int)] {
        func state(_ s: String) -> Bool { s.count == 3 && s.allSatisfy { $0.isUppercase } }
        var out: [(String, String, Int, Int)] = []
        for w in openWars where w.type == "interstate" {
            guard let a = w.side_a.first(where: state), let end = w.end, let from = Int(w.start.prefix(4)), let to = Int(end.prefix(4)) else { continue }
            for b in w.side_b where state(b) && b != a { out.append((a, b, from, to)) }
        }
        return out
    }
}
