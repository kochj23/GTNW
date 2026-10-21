//
//  WorldPolitics.swift
//  Global Thermal Nuclear War
//
//  The living world (3.14.0). Before this, computer-run nations barely moved before 1945: attacks needed relations
//  below −40 (starting relations bottom out at exactly −40), monarchies' ambition gave war a weight of 0, and
//  Nightmare only multiplied those zeros. Now, scaled by difficulty (Nightmare = relentless):
//    • era rivalries set the real enmities of the day, and the era's wars break out between the powers (the French
//      Revolutionary and Napoleonic wars, the Russo-Turkish wars, the wars of unification, the world wars, …);
//    • the powers claim unclaimed and peoples' land (the Scramble for Africa from the 1880s), and seize colonies from
//      enemies they're at war with, so the player races rivals for territory;
//    • they react to U.S. expansion: protests, proxy revolts, seizing weakly held territories, and coalitions;
//    • alliances form and break, and nations offer the player treaties.
//  Repository: https://github.com/kochj23/GTNW
//

import Foundation

/// A treaty another nation offers the player (accept or decline from the top bar; it lapses after three months).
struct TreatyOffer: Codable, Hashable, Identifiable {
    var id = UUID()
    var from: String
    var type: TreatyType
    var date: Date
}

enum WorldPolitics {
    struct Rivalry {
        let a: String, b: String, from: Int, to: Int
        /// True when war breaks out (a attacks b) as the window opens; false for a cold rivalry.
        let war: Bool
        var key: String { "\(a)-\(b)-\(from)" }
    }

    private static func w(_ a: String, _ b: String, _ from: Int, _ to: Int) -> Rivalry { Rivalry(a: a, b: b, from: from, to: to, war: true) }
    private static func cold(_ a: String, _ b: String, _ from: Int, _ to: Int) -> Rivalry { Rivalry(a: a, b: b, from: from, to: to, war: false) }

    /// The era's enmities and wars (board ids: DEU stands for Prussia / the German states before 1871, TUR for the
    /// Ottoman Empire, CHN for the Qing).
    static let rivalries: [Rivalry] = [
        w("RUS", "TUR", 1787, 1792), w("RUS", "SWE", 1788, 1790),
        w("FRA", "AUT", 1792, 1797), w("DEU", "FRA", 1792, 1795), w("FRA", "GBR", 1793, 1802), w("FRA", "ESP", 1793, 1795),
        w("FRA", "NLD", 1793, 1795), w("AUT", "FRA", 1799, 1801), w("RUS", "FRA", 1799, 1800), w("GBR", "FRA", 1803, 1814),
        w("FRA", "AUT", 1805, 1805), w("FRA", "DEU", 1806, 1807), w("RUS", "TUR", 1806, 1812), w("FRA", "PRT", 1807, 1814),
        w("RUS", "SWE", 1808, 1809), w("FRA", "ESP", 1808, 1814), w("FRA", "RUS", 1812, 1814), w("GBR", "USA", 1812, 1815),
        cold("GBR", "RUS", 1815, 1907), w("RUS", "IRN", 1826, 1828), w("RUS", "TUR", 1828, 1829), w("GBR", "CHN", 1839, 1842),
        w("GBR", "AFG", 1839, 1842), w("AUT", "ITA", 1848, 1849), w("RUS", "TUR", 1853, 1856), w("GBR", "RUS", 1854, 1856),
        w("FRA", "RUS", 1854, 1856), w("GBR", "CHN", 1856, 1860), w("FRA", "AUT", 1859, 1859), w("ESP", "MAR", 1859, 1860),
        w("DEU", "DNK", 1864, 1864), w("PRY", "BRA", 1864, 1870), w("PRY", "ARG", 1864, 1870), w("ESP", "PER", 1865, 1866),
        w("DEU", "AUT", 1866, 1866), w("ITA", "AUT", 1866, 1866), w("FRA", "DEU", 1870, 1871), cold("FRA", "DEU", 1871, 1914),
        w("RUS", "TUR", 1877, 1878), w("SRB", "TUR", 1876, 1878), w("SRB", "BGR", 1885, 1885), w("SRB", "TUR", 1912, 1913),
        w("MNE", "TUR", 1912, 1913), w("BGR", "SRB", 1913, 1913), w("CHL", "PER", 1879, 1884), w("CHL", "BOL", 1879, 1884), w("GBR", "AFG", 1878, 1880),
        w("FRA", "CHN", 1884, 1885), w("JPN", "CHN", 1894, 1895), w("ITA", "ETH", 1895, 1896), w("TUR", "GRC", 1897, 1897),
        w("JPN", "RUS", 1904, 1905), w("ITA", "TUR", 1911, 1912), w("GRC", "TUR", 1912, 1913), w("BGR", "TUR", 1912, 1913),
        w("AUT", "SRB", 1914, 1918), w("DEU", "RUS", 1914, 1917), w("DEU", "FRA", 1914, 1918), w("GBR", "DEU", 1914, 1918),
        w("AUT", "RUS", 1914, 1917), w("TUR", "RUS", 1914, 1917), w("GBR", "TUR", 1914, 1918), w("ITA", "AUT", 1915, 1918),
        w("POL", "RUS", 1919, 1921), w("GRC", "TUR", 1919, 1922), w("JPN", "CHN", 1937, 1945), w("ITA", "ETH", 1935, 1936),
        w("DEU", "POL", 1939, 1939), w("GBR", "DEU", 1939, 1945), w("FRA", "DEU", 1939, 1940), w("RUS", "FIN", 1939, 1940),
        w("DEU", "RUS", 1941, 1945), w("JPN", "GBR", 1941, 1945), w("ITA", "GBR", 1940, 1943),
        w("EGY", "ISR", 1948, 1949), cold("IND", "PAK", 1947, 9999), w("PRK", "KOR", 1950, 1953), cold("PRK", "KOR", 1953, 9999),
        w("ISR", "EGY", 1956, 1956), w("CHN", "IND", 1962, 1962), w("IND", "PAK", 1965, 1965), w("ISR", "EGY", 1967, 1967),
        w("IND", "PAK", 1971, 1971), w("EGY", "ISR", 1973, 1973), w("CHN", "VNM", 1979, 1979), w("IRQ", "IRN", 1980, 1988),
        w("ARG", "GBR", 1982, 1982), w("IRQ", "KWT", 1990, 1991), cold("ISR", "IRN", 1979, 9999), cold("SAU", "IRN", 1979, 9999),
        w("ARM", "AZE", 1992, 1994), w("ETH", "ERI", 1998, 2000), w("RUS", "GEO", 2008, 2008), w("RUS", "UKR", 2022, 9999),
        cold("RUS", "UKR", 2014, 2021), cold("CHN", "TWN", 1949, 9999),
    ]

    /// How busy the computer-run world is: Nightmare is relentless.
    static func activity(_ d: DifficultyLevel) -> Double {
        switch d { case .easy: return 0.6; case .normal: return 1; case .hard: return 1.6; case .nightmare: return 2.6 }
    }

    /// Land claims per great power per year, by era: steady colonisation, the Scramble for Africa from 1880, then
    /// almost none after 1945.
    static func claimRate(year: Int) -> Double {
        year < 1880 ? 0.25 : (year < 1915 ? 1.2 : (year < 1946 ? 0.2 : 0.03))
    }

    /// Player claims in a year that draw a reaction from the powers.
    static func reactionThreshold(_ d: DifficultyLevel) -> Int {
        switch d { case .easy: return 8; case .normal: return 5; case .hard: return 3; case .nightmare: return 2 }
    }

    /// Set the era's enmities (both ways, at most −60) on a fresh board or as their windows open.
    static func applyRivalries(_ gs: GameState) {
        let y = gs.currentYear
        let ids = Set(gs.countries.map(\.id))
        for r in rivalries where r.from <= y && y <= r.to && ids.contains(r.a) && ids.contains(r.b) {
            for (x, z) in [(r.a, r.b), (r.b, r.a)] {
                gs.setRelation(from: x, to: z, value: min(gs.getCountry(id: x)?.diplomaticRelations[z] ?? 0, -60))
            }
        }
    }

    /// Overseas colonial powers and the year they start reaching for distant land; everyone else only takes land
    /// within `nearDegrees` of home.
    static let colonialPowers: [String: Int] = ["GBR": 0, "FRA": 0, "ESP": 0, "PRT": 0, "NLD": 0, "DEU": 1884, "ITA": 1885,
                                                "BEL": 1885, "JPN": 1895]
    static let nearDegrees = 25.0
    /// AI colonial garrisons, as a share of what a land needs (3.14.1).
    static let aiGarrisonShare = 0.6

    static func reachesOverseas(_ id: String, year: Int) -> Bool { colonialPowers[id].map { year >= $0 } ?? false }

    /// The great powers that compete for land: the strongest independent nations (not the player).
    /// The colonial powers of the era always take part, however small their armies.
    static func powers(_ gs: GameState) -> [Country] {
        let others = gs.liveCountries.filter { $0.id != gs.playerCountryID }
        let top = others.filter { $0.militaryStrength >= 20 }.sorted { $0.militaryStrength > $1.militaryStrength }.prefix(8)
        let topIDs = Set(top.map(\.id))
        let colonial = others.filter { reachesOverseas($0.id, year: gs.currentYear) && !topIDs.contains($0.id) }
        return Array(top) + colonial
    }
}

extension GameEngine {
    private func bumpWorld(_ key: String) { gameState?.shadow.worldStats[key, default: 0] += 1 }

    /// Each turn: the era's wars, the race for land, reactions to the U.S., alliances and treaty offers.
    func processWorldPolitics() {
        guard let gs = gameState, !gs.isMultiplayer else { return }
        processRivalries()
        processWorldExpansion()
        processReactionsToPlayer()
        processAllianceChurn()
        processTreatyOffers()
        processAITerritories()
        _ = gs
    }

    private func processRivalries() {
        guard let gs = gameState else { return }
        WorldPolitics.applyRivalries(gs)
        let y = gs.currentYear, me = gs.playerCountryID
        for r in WorldPolitics.rivalries where r.war && r.from <= y && y <= r.to && !gs.shadow.firedRivalries.contains(r.key) {
            guard r.a != me, r.b != me, let a = gs.getCountry(id: r.a), let b = gs.getCountry(id: r.b),
                  !a.isDestroyed, !b.isDestroyed, !a.isTerritory, !b.isTerritory else { continue }
            gs.shadow.firedRivalries.insert(r.key)
            if a.atWarWith.contains(b.id) { continue }
            breakAlliance(a.id, b.id)
            declareWar(aggressor: a.id, defender: b.id)
            bumpWorld("wars")
            gs.shadow.post("\(a.name) declares war on \(b.name).", date: gs.currentDate, severity: 2)
            logPlayEvent("world_war", detail: ["aggressor": a.id, "defender": b.id, "game_date": PlayHistory.day(gs.currentDate)])
        }
        // Wars whose era is over end in a peace.
        for r in WorldPolitics.rivalries where r.war && y > r.to && gs.shadow.firedRivalries.contains(r.key) {
            if gs.getCountry(id: r.a)?.atWarWith.contains(r.b) == true { makePeace(r.a, r.b) }
        }
        self.gameState = gs
    }

    /// End a war between two computer-run nations (no player stats touched).
    func makePeace(_ a: String, _ b: String) {
        guard let gs = gameState else { return }
        if let i = gs.countries.firstIndex(where: { $0.id == a }) { gs.countries[i].atWarWith.remove(b) }
        if let j = gs.countries.firstIndex(where: { $0.id == b }) { gs.countries[j].atWarWith.remove(a) }
        gs.activeWars.removeAll { ($0.aggressor == a && $0.defender == b) || ($0.aggressor == b && $0.defender == a) }
        let na = gs.getCountry(id: a)?.name ?? a, nb = gs.getCountry(id: b)?.name ?? b
        gs.shadow.post("\(na) and \(nb) make peace.", date: gs.currentDate, severity: 1)
        bumpWorld("diplomacy")
        self.gameState = gs
    }

    private func breakAlliance(_ a: String, _ b: String) {
        guard let gs = gameState else { return }
        guard let i = gs.countries.firstIndex(where: { $0.id == a }), gs.countries[i].alliances.contains(b) else { return }
        gs.countries[i].alliances.remove(b)
        if let j = gs.countries.firstIndex(where: { $0.id == b }) { gs.countries[j].alliances.remove(a) }
        gs.treaties.removeAll { $0.type == .alliance && $0.signatories.contains(a) && $0.signatories.contains(b) }
        gs.shadow.post("The alliance between \(gs.getCountry(id: a)?.name ?? a) and \(gs.getCountry(id: b)?.name ?? b) collapses.", date: gs.currentDate, severity: 1)
        bumpWorld("diplomacy")
        self.gameState = gs
    }

    /// A computer-run power takes a land: unclaimed, peoples' land, or a colony of an enemy it is at war with.
    @discardableResult
    func aiTakeLand(_ land: String, by powerID: String) -> Bool {
        guard let gs = gameState, let power = gs.getCountry(id: powerID), gs.getCountry(id: land) == nil,
              let template = WorldCountriesDatabase.template(id: land) else { return false }
        let colony = gs.preState(land)
        let how: String
        if gs.unclaimedLandIDs.contains(land) || colony?.era.kind == .indigenous {
            how = "claims"
        } else if let c = colony, c.era.kind == .colony, power.atWarWith.contains(c.era.owner) {
            how = "seizes"
        } else { return false }
        var taken = CombatModel.claim(template, for: power)
        if let c = colony { taken.name = c.era.name }
        gs.countries.append(taken)
        gs.shadow.claimDates[land] = gs.currentDate   // 3.14.1: AI land ramps up like the player's
        bumpWorld("claims")
        gs.shadow.post("\(power.name) \(how) \(taken.name).", date: gs.currentDate, severity: 1)
        logPlayEvent("world_claim", detail: ["power": powerID, "land": land, "how": how, "game_date": PlayHistory.day(gs.currentDate)])
        self.gameState = gs
        return true
    }

    private func processWorldExpansion() {
        guard let gs = gameState else { return }
        let act = WorldPolitics.activity(gs.difficultyLevel)
        // The U.S. grabbing land spurs the others on.
        let spur = ExpansionModel.takenLastYear(gs, before: gs.currentDate) >= WorldPolitics.reactionThreshold(gs.difficultyLevel) ? 2.0 : 1.0
        let rate = WorldPolitics.claimRate(year: gs.currentYear) * act * spur
        var open = gs.unclaimedLandIDs.filter { $0 != Antarctica.id || gs.currentYear >= 1908 }.union(gs.indigenousLandIDs)
        for p in WorldPolitics.powers(gs) where Double.random(in: 0..<1) < gs.scale.probability(annual: rate) {
            // Colonies of an enemy first; otherwise the nearest open land of a few.
            let enemyColony = gs.colonyLandIDs.first { gs.preState($0).map { p.atWarWith.contains($0.era.owner) } ?? false }
            let overseas = WorldPolitics.reachesOverseas(p.id, year: gs.currentYear)
            let near = open.shuffled().prefix(5).filter { overseas || distance(p, $0) < WorldPolitics.nearDegrees }.min { a, b in
                distance(p, a) < distance(p, b)
            }
            if let land = enemyColony ?? near, aiTakeLand(land, by: p.id) { open.remove(land) }
        }
    }

    private func distance(_ c: Country, _ land: String) -> Double {
        guard let t = WorldCountriesDatabase.template(id: land) else { return .infinity }
        let l = t.toCountry().coordinates
        return hypot(c.coordinates.lat - l.lat, c.coordinates.lon - l.lon)
    }

    /// The powers answer U.S. expansion: protests, proxy revolts, seizing weakly held territories, and coalitions.
    private func processReactionsToPlayer() {
        guard let gs = gameState, let me = gs.getPlayerCountry() else { return }
        let taken = ExpansionModel.takenLastYear(gs, before: gs.currentDate)
        let threshold = WorldPolitics.reactionThreshold(gs.difficultyLevel)
        guard taken >= threshold, gs.shadow.lastReaction.map({ GameCalendar.days(from: $0, to: gs.currentDate) >= 60 }) ?? true else { return }
        let act = WorldPolitics.activity(gs.difficultyLevel)
        guard Double.random(in: 0..<1) < min(1, 0.5 * act) else { return }
        gs.shadow.lastReaction = gs.currentDate
        let rivals = WorldPolitics.powers(gs).filter { !$0.alliances.contains(me.id) }
        guard let lead = rivals.first else { return }
        // Protests.
        for r in rivals.prefix(3) { modifyDiplomaticRelation(from: r.id, to: me.id, by: -6) }
        gs.shadow.post("\(lead.name) leads protests against American expansion.", date: gs.currentDate, severity: 1)
        bumpWorld("diplomacy")
        let mine = gs.countries.filter { $0.territoryOf == me.id && !$0.isDestroyed }
        // Proxy revolt in a U.S. territory.
        if let t = mine.randomElement(), let i = gs.countries.firstIndex(where: { $0.id == t.id }) {
            gs.countries[i].profile.outcry = min(100, gs.countries[i].profile.outcry + 15)
            gs.countries[i].stability = max(0, gs.countries[i].stability - 8)
            gs.shadow.post("\(rivals.randomElement()?.name ?? lead.name) arms rebels in \(t.name).", date: gs.currentDate, severity: 2)
        }
        // A weakly held territory is seized.
        if let weak = mine.first(where: { (gs.shadow.garrisons[$0.id] ?? 5) < OccupationModel.neededGarrison($0) / 2 }),
           let i = gs.countries.firstIndex(where: { $0.id == weak.id }), lead.militaryStrength >= 20 {
            gs.countries[i].territoryOf = lead.id
            gs.shadow.garrisons.removeValue(forKey: weak.id)
            gs.shadow.territoryPolicies.removeValue(forKey: weak.id)
            modifyDiplomaticRelation(from: me.id, to: lead.id, by: -20)
            bumpWorld("claims")
            gs.shadow.post("\(lead.name) seizes lightly garrisoned \(weak.name) from the United States.", date: gs.currentDate, severity: 3)
            logPlayEvent("territory_seized", detail: ["by": lead.id, "land": weak.id, "game_date": PlayHistory.day(gs.currentDate)])
        }
        // A coalition against an overreaching United States; on Hard and Nightmare its leader goes to war.
        if taken >= threshold * 2, rivals.count >= 2 {
            let a = rivals[0], b = rivals[1]
            if !a.alliances.contains(b.id) { formAlliance(country1: a.id, country2: b.id) }
            gs.shadow.post("\(a.name) and \(b.name) form a coalition against the United States.", date: gs.currentDate, severity: 3)
            bumpWorld("diplomacy")
            if act >= 1.5, !a.atWarWith.contains(me.id) {
                declareWar(aggressor: a.id, defender: me.id)
                bumpWorld("wars")
                gs.shadow.post("\(a.name) declares war on the United States.", date: gs.currentDate, severity: 3)
            }
        }
        self.gameState = gs
    }

    /// Alliances between nations that have come to dislike each other collapse; friends form new ones.
    private func processAllianceChurn() {
        guard let gs = gameState else { return }
        let act = WorldPolitics.activity(gs.difficultyLevel)
        for c in gs.liveCountries where c.id != gs.playerCountryID {
            for ally in c.alliances where ally != gs.playerCountryID && (c.diplomaticRelations[ally] ?? 0) < -10
                && Double.random(in: 0..<1) < gs.scale.probability(annual: 0.5 * act) {
                breakAlliance(c.id, ally)
            }
        }
    }

    /// Friendly nations offer the player a treaty now and then (it lapses after three months).
    private func processTreatyOffers() {
        guard let gs = gameState else { return }
        gs.shadow.treatyOffers.removeAll { GameCalendar.days(from: $0.date, to: gs.currentDate) > 92 }
        guard gs.shadow.treatyOffers.count < 3,
              Double.random(in: 0..<1) < gs.scale.probability(annual: 1.5 * WorldPolitics.activity(gs.difficultyLevel)),
              let me = gs.getPlayerCountry() else { return }
        let offered = Set(gs.shadow.treatyOffers.map(\.from))
        let friends = gs.liveCountries.filter { $0.id != me.id && ($0.diplomaticRelations[me.id] ?? 0) > 30 && !offered.contains($0.id) }
        guard let f = friends.randomElement() else { return }
        let rel = f.diplomaticRelations[me.id] ?? 0
        let type: TreatyType = rel > 70 && !me.alliances.contains(f.id) ? .alliance : (rel > 50 ? .nonAggression : .tradeAgreement)
        gs.shadow.treatyOffers.append(TreatyOffer(from: f.id, type: type, date: gs.currentDate))
        gs.shadow.post("\(f.name) proposes a \(type.rawValue.lowercased()) with the United States.", date: gs.currentDate, severity: 1)
        bumpWorld("diplomacy")
        self.gameState = gs
    }

    /// 3.14.1: AI-held territories run on the player's occupation and income model. Colonial garrisons are thin
    /// (60% of what a land needs, under a military governor), so unrest builds; rivals arming rebels push it higher.
    /// Income (the same `annualIncome`) goes to the owner's economy; a territory boiling over (unrest above 70) may
    /// win its independence (30% a year).
    func processAITerritories() {
        guard let gs = gameState else { return }
        let keep = pow(0.7, gs.turnLength.yearFraction / 0.25)
        for i in gs.countries.indices {
            let c = gs.countries[i]
            guard let owner = c.territoryOf, owner != gs.playerCountryID, !c.isDestroyed,
                  let oi = gs.countries.firstIndex(where: { $0.id == owner }) else { continue }
            let needed = OccupationModel.neededGarrison(c)
            let target = OccupationModel.insurgencyTarget(garrison: needed * WorldPolitics.aiGarrisonShare, needed: needed, governance: .militaryGovernor)
            gs.countries[i].profile.outcry = c.profile.outcry * keep + target * (1 - keep)
            let st = OccupationModel.stabilityTarget(insurgency: gs.countries[i].profile.outcry, governance: .militaryGovernor)
            gs.countries[i].stability = Int((Double(c.stability) * keep + Double(st) * (1 - keep)).rounded())
            let income = ExpansionModel.annualIncome(gs.countries[i], in: gs) * gs.turnLength.yearFraction
            gs.countries[oi].gdp += income / 1000
            gs.shadow.worldStats["aiIncomeCents", default: 0] += Int((income * 100).rounded())
            if gs.countries[i].profile.outcry > 70 && Double.random(in: 0..<1) < gs.scale.probability(annual: 0.3) {
                var free = gs.countries[i]
                free.territoryOf = nil
                CombatModel.installChosenGovernment(.provisional, on: &free, by: gs.countries[oi])
                free.diplomaticRelations[owner] = -40
                free.alliances.remove(owner)
                gs.countries[i] = free
                gs.countries[oi].alliances.remove(c.id)
                gs.shadow.worldStats["revolts", default: 0] += 1
                gs.shadow.post("\(c.name) rises against \(gs.countries[oi].name) and declares independence.", date: gs.currentDate, severity: 2)
            }
        }
        self.gameState = gs
    }

    /// Accept or decline an offered treaty.
    @discardableResult
    func answerTreaty(_ id: UUID, accept: Bool) -> Bool {
        guard let gs = gameState, let k = gs.shadow.treatyOffers.firstIndex(where: { $0.id == id }) else { return false }
        let o = gs.shadow.treatyOffers.remove(at: k)
        guard let f = gs.getCountry(id: o.from) else { self.gameState = gs; return false }
        if accept {
            if o.type == .alliance { formAlliance(country1: gs.playerCountryID, country2: f.id) }
            else { gs.treaties.append(Treaty(type: o.type, signatories: [gs.playerCountryID, f.id], turn: gs.turn)) }
            modifyDiplomaticRelation(from: f.id, to: gs.playerCountryID, by: 15)
            gs.shadow.post("The United States signs a \(o.type.rawValue.lowercased()) with \(f.name).", date: gs.currentDate, severity: 1)
        } else {
            modifyDiplomaticRelation(from: f.id, to: gs.playerCountryID, by: -5)
        }
        logPlayEvent("treaty_answered", detail: ["from": f.id, "type": o.type.rawValue, "accepted": accept, "game_date": PlayHistory.day(gs.currentDate)])
        self.gameState = gs
        return true
    }
}
