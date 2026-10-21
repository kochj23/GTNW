//
//  Antarctica.swift
//  Global Thermal Nuclear War
//
//  Antarctica (3.10.0): claimable land in every era, but what claiming it means changes with the Antarctic Treaty
//  (signed 1 Dec 1959, in force 23 Jun 1961). Before then it is open: seven nations made overlapping claims (United
//  Kingdom 1908, New Zealand 1923, France 1924, Australia 1933, Norway 1939, Chile 1940, Argentina 1943) without real
//  sovereignty. Signed but not yet in force it is restricted; from 23 Jun 1961 a claim violates the treaty and is
//  priced like any treaty-banned option (ArsenalCatalog.cost). It is huge and nearly empty: a tiny garrison holds it,
//  but the cold takes 5% of that garrison a month and upkeep is heavy. It yields whaling and sealing (to 1964),
//  science prestige (from the International Geophysical Year, 1957), and minerals and oil only from 2048, when the
//  Madrid Protocol's mining ban (1998) can first be reviewed.
//  Repository: https://github.com/kochj23/GTNW
//

import Foundation

enum Antarctica {
    static let id = "ATA"

    /// Shown on the map near the coast so the label and dot are on screen (the continent runs to 90°S).
    static let template = CountryTemplate(id, "Antarctica", flag: "🇦🇶", capital: "McMurdo Sound",
                                          lat: -71, lon: 20, region: .oceania, gov: .republic, align: .nonAligned,
                                          gdp: 0.1, pop: 0.01, mil: 1, aggr: 0, stab: 80)

    static let treatySigned = GameCalendar.date(year: 1959, month: 12, day: 1)
    static let treatyInForce = GameCalendar.date(year: 1961, month: 6, day: 23)
    static let miningReview = 2048

    /// The seven national claims, by year made.
    static let claims: [(nation: String, year: Int)] = [
        ("United Kingdom", 1908), ("New Zealand", 1923), ("France", 1924), ("Australia", 1933),
        ("Norway", 1939), ("Chile", 1940), ("Argentina", 1943),
    ]

    static func claims(by year: Int) -> [String] { claims.filter { $0.year <= year }.map { "\($0.nation) (\($0.year))" } }

    /// Legal status of a U.S. claim on a date.
    static func legalStatus(on date: Date) -> LegalStatus {
        date >= treatyInForce ? .treatyBanned : (date >= treatySigned ? .restricted : .legal)
    }

    static let neededGarrison = 0.5
    /// Monthly share of the garrison lost to the cold, and upkeep ($B a year) per thousand men.
    static let monthlyAttrition = 0.05
    static let upkeepPerThousand = 0.4
}

extension GameEngine {
    /// Each turn for a U.S. Antarctica: the cold thins the garrison and the upkeep is paid.
    func processAntarctica() {
        guard let gs = gameState, gs.getCountry(id: Antarctica.id)?.territoryOf == gs.playerCountryID,
              let pi = gs.countries.firstIndex(where: { $0.id == gs.playerCountryID }) else { return }
        let months = gs.turnLength.yearFraction * 12
        let g = gs.shadow.garrisons[Antarctica.id] ?? Antarctica.neededGarrison
        let left = max(0.5, g * pow(1 - Antarctica.monthlyAttrition, months))
        gs.shadow.garrisons[Antarctica.id] = left
        gs.countries[pi].gdp -= left * Antarctica.upkeepPerThousand * gs.turnLength.yearFraction / 1000
        if let ai = gs.countries.firstIndex(where: { $0.id == Antarctica.id }) {
            gs.countries[ai].profile.outcry = 0   // nobody to rebel
            gs.countries[ai].stability = 80
        }
        self.gameState = gs
    }
}
