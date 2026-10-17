//
//  WorldEvaluation.swift
//  Global Thermal Nuclear War
//
//  "Am I winning?" — leadership effectiveness, U.S. share of world influence, U.S. and world quality of life, and a
//  six-band world peace level. Also the stat bands that grow a country's City View.
//  Repository: https://github.com/kochj23/GTNW
//

import Foundation

enum PeaceLevel: Int, CaseIterable, Comparable {
    case lastingPeace = 0, stablePeace, uneasyPeace, coldWar, hotWar, totalWar

    static func < (a: PeaceLevel, b: PeaceLevel) -> Bool { a.rawValue < b.rawValue }

    var label: String {
        switch self {
        case .lastingPeace: return "Lasting Peace"
        case .stablePeace: return "Stable Peace"
        case .uneasyPeace: return "Uneasy Peace"
        case .coldWar: return "Cold War"
        case .hotWar: return "Hot War"
        case .totalWar: return "Total War"
        }
    }
}

struct WorldEvaluation: Equatable {
    var leadership: Double          // 0–100 (U.S. leadership effectiveness)
    var influenceShare: Double      // 0–100 (% of world power)
    var usQualityOfLife: Double     // 0–100
    var worldQualityOfLife: Double  // 0–100 (population-weighted)
    var peaceIndex: Double          // 0 (total war) … 100 (lasting peace)
    var peaceLevel: PeaceLevel

    static func peaceLevel(index: Double) -> PeaceLevel {
        switch index {
        case 85...: return .lastingPeace
        case 70..<85: return .stablePeace
        case 55..<70: return .uneasyPeace
        case 40..<55: return .coldWar
        case 20..<40: return .hotWar
        default: return .totalWar
        }
    }

    static func evaluate(_ gs: GameState) -> WorldEvaluation {
        let alive = gs.countries.filter { !$0.isDestroyed }
        let player = gs.getPlayerCountry()
        let totalPower = alive.reduce(0.0) { $0 + Double($1.powerScore) }
        let share = player.map { Double($0.powerScore) / max(1, totalPower) * 100 } ?? 0
        let pop = alive.reduce(0.0) { $0 + Double(max(1, $1.population)) }
        let worldQoL = alive.reduce(0.0) { $0 + $1.profile.qualityOfLife * Double(max(1, $1.population)) } / max(1, pop)
        let atWarShare = Double(alive.filter { !$0.atWarWith.isEmpty }.count) / Double(max(1, alive.count))
        let anxiety = alive.reduce(0.0) { $0 + $1.profile.anxieties.average } / Double(max(1, alive.count))
        var peace = 100 - atWarShare * 180 - anxiety * 0.5 - Double(5 - gs.defconLevel.rawValue) * 8
        peace -= Double(min(10, gs.nuclearStrikes.count)) * 8
        peace = min(100, max(0, peace))
        return WorldEvaluation(leadership: player?.profile.leadership ?? 0, influenceShare: share,
                               usQualityOfLife: player?.profile.qualityOfLife ?? 0, worldQualityOfLife: worldQoL,
                               peaceIndex: peace, peaceLevel: peaceLevel(index: peace))
    }

    func snapshot(date: Date, popularity: Double) -> PresidencySnapshot {
        PresidencySnapshot(date: date, popularity: popularity, usQualityOfLife: usQualityOfLife,
                           worldQualityOfLife: worldQualityOfLife, worldPeace: peaceIndex, leadership: leadership,
                           influenceShare: influenceShare)
    }
}

// MARK: - City View

/// A family of city tiles and how many growth levels it has (matching the optional pack's sprite sets).
enum CityTile: String, CaseIterable, Identifiable {
    case downtown, housing, industry, military, parks, nuclear, airport
    var id: String { rawValue }

    var maxLevel: Int {
        switch self {
        case .downtown, .housing, .parks: return 9
        case .industry: return 5
        case .military: return 11
        case .nuclear: return 6
        case .airport: return 4
        }
    }
}

struct CityLayout: Equatable {
    var levels: [CityTile: Int]
    var burning: Bool

    static func band(_ value: Double, max: Int) -> Int { Swift.max(0, Swift.min(max, Int((value / 100 * Double(max + 1)).rounded(.down)))) }

    static func layout(for c: Country, strikes: [NuclearStrike]) -> CityLayout {
        let p = c.profile
        let wealth = Double(c.economicStrength)
        var levels: [CityTile: Int] = [:]
        levels[.downtown] = band(wealth * 0.6 + p.qualityOfLife * 0.4, max: 9)
        levels[.housing] = band(p.qualityOfLife, max: 9)
        levels[.industry] = band(wealth, max: 5)
        levels[.military] = band(Double(c.militaryStrength), max: 11)
        levels[.parks] = band(max(0, p.qualityOfLife - Double(c.radiationLevel)), max: 9)
        let nukeScore = c.nuclearWarheads == 0 ? 0 : min(100, 20 + log10(Double(c.nuclearWarheads) + 1) * 20)
        levels[.nuclear] = band(nukeScore, max: 6)
        levels[.airport] = band(wealth * 0.7 + Double(c.stability) * 0.3, max: 4)
        if c.damageLevel > 0 {
            for t in CityTile.allCases {
                levels[t] = Swift.max(0, (levels[t] ?? 0) - c.damageLevel / 20)
            }
        }
        let nuked = strikes.contains { $0.target == c.id }
        return CityLayout(levels: levels, burning: nuked || c.damageLevel >= 50 || c.isDestroyed)
    }
}
