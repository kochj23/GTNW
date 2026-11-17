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
    }

    struct OpenWar: Codable {
        var name: String
        var type: String
        var start: String
        var end: String?
        var side_a: [String]
        var side_b: [String]
    }

    private struct RatesFile: Codable { var rates: [String: [String: [String: Rate]]] }
    private struct OpenFile: Codable { var wars: [OpenWar] }

    private static func load<T: Decodable>(_ name: String, _ type: T.Type) -> T? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json"), let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    /// type → era → bucket ("all", "even", "lopsided", "overwhelming") → rate. Empty when the resource is missing.
    static let rates: [String: [String: [String: Rate]]] = load("base_rates", RatesFile.self)?.rates ?? [:]
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

    /// "Interstate wars 1946–1991: median 4.7 months (IQR 2–12); 23% ended in a ceasefire or settlement, 63% decisively."
    static func line(year: Int, strongerShare: Double? = nil) -> String? {
        guard let r = interstate(year: year, strongerShare: strongerShare) else { return nil }
        let label = era(year).replacingOccurrences(of: "-", with: "–")
        return String(format: "Interstate wars %@: median %.1f months (IQR %.0f–%.0f); %d%% ended in a ceasefire or settlement, %d%% decisively.",
                      label, r.median_months, r.q1_months, r.q3_months, Int((r.negotiated * 100).rounded()), Int((r.decisive * 100).rounded()))
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
