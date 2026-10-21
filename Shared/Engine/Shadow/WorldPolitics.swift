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
        if gs.shadow.startOutputShare == 0 { gs.shadow.startOutputShare = PeaceModel.outputShare(gs) }   // 3.16.0 baseline
        processRivalries()
        processWorldExpansion()
        processReactionsToPlayer()
        processAllianceChurn()
        processTreatyOffers()
        processAITerritories()
        processAITactics()   // 3.17.6: the other powers fight dirty too
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

// MARK: - Era transitions (3.15.0)

extension GameState {
    /// The board a new game in `year` would have (names, governments, flags), for era transitions.
    static func eraBoard(year: Int) -> [Country] {
        let admin = Advisor.allAdministrations().last { $0.startYear <= year }
        return GameState(playerCountryID: "USA", administration: admin, startDate: GameCalendar.date(year: year, month: 1, day: 20),
                         boardYear: year).countries
    }
}

extension GameEngine {
    /// Once a game year: nations whose story still follows history take their era's name, government and flag
    /// (Principality → Kingdom of Serbia in 1882, the Qing → the Republic of China in 1912, the Russian Empire → the
    /// Soviet Union). Like evolving cabinets, this stops for a nation once its story diverges: it was conquered or
    /// made a territory, or its government was changed by anything other than history.
    func processEraTransitions() {
        guard let gs = gameState, gs.currentYear != gs.shadow.eraSyncYear else { return }
        let first = gs.shadow.eraSyncYear == 0
        gs.shadow.eraSyncYear = gs.currentYear
        let board = Dictionary(GameState.eraBoard(year: gs.currentYear).map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        if first {   // remember each nation's starting government and the era's nations; nothing to change yet
            for c in gs.countries { gs.shadow.eraGovernment[c.id] = c.government.rawValue }
            gs.shadow.eraBoardIDs = Set(board.keys)
            self.gameState = gs
            return
        }
        let lastBoard = gs.shadow.eraBoardIDs
        processWorldAtrocities()   // 3.17.6
        processFoundings(board)
        processAbsorptions(board, lastBoard: lastBoard)
        for i in gs.countries.indices {
            let c = gs.countries[i]
            guard c.id != gs.playerCountryID, !c.isDestroyed, !c.isTerritory, !gs.shadow.eraDiverged.contains(c.id),
                  let h = board[c.id] else { continue }
            if let was = gs.shadow.eraGovernment[c.id], was != c.government.rawValue {
                gs.shadow.eraDiverged.insert(c.id)   // someone other than history changed its government
                continue
            }
            guard h.name != c.name || h.government != c.government || h.flag != c.flag else { continue }
            gs.countries[i].name = h.name
            gs.countries[i].government = h.government
            gs.countries[i].flag = h.flag
            gs.countries[i].alignment = h.alignment
            gs.shadow.eraGovernment[c.id] = h.government.rawValue
            if h.name != c.name {
                gs.shadow.post("\(c.name) becomes \(h.name).", date: gs.currentDate, severity: 1)
                gs.shadow.worldStats["transitions", default: 0] += 1
                logPlayEvent("era_transition", detail: ["country": c.id, "from": PlayHistory.text(c.name), "to": PlayHistory.text(h.name),
                                                        "game_date": PlayHistory.day(gs.currentDate)])
            }
        }
        self.gameState = gs
    }
}

// MARK: - Mid-game foundings (3.16.1)

extension GameEngine {
    /// Nations founded since the last era sync (on the era board now, not last year): Serbia 1817, Greece 1829,
    /// Belgium 1830, the post-WWI states, decolonisation… If the land is still held by its historical owner (a colony
    /// of an era power, a dependency, or nobody), the nation is founded with its historical government. If the
    /// player or a computer-run power took the land, history has diverged: no automatic founding, but an independence
    /// movement presses (unrest +20, stability −10). Successor states absorb their parts still on their historical
    /// path (Yugoslavia takes Serbia and Montenegro as constituent lands).
    func processFoundings(_ board: [String: Country]) {
        guard let gs = gameState else { return }
        let fresh = Set(board.keys).subtracting(gs.shadow.eraBoardIDs)
        gs.shadow.eraBoardIDs = Set(board.keys)
        for id in fresh.sorted() {
            guard var h = board[id] else { continue }
            if let held = gs.countries.firstIndex(where: { $0.id == id }) {
                guard let owner = gs.countries[held].territoryOf else { continue }   // already independent
                if gs.shadow.historicalAbsorptions[id] == owner { continue }   // history restores it (processAbsorptions)
                gs.countries[held].profile.outcry = min(100, gs.countries[held].profile.outcry + 20)
                gs.countries[held].stability = max(0, gs.countries[held].stability - 10)
                let ownerName = owner == gs.playerCountryID ? "the United States" : (gs.getCountry(id: owner)?.name ?? owner)
                gs.shadow.post("An independence movement in \(gs.countries[held].name) demands freedom from \(ownerName).", date: gs.currentDate, severity: 2)
                logPlayEvent("independence_movement", detail: ["land": id, "owner": owner, "game_date": PlayHistory.day(gs.currentDate)])
                continue
            }
            let ids = Set(gs.countries.map(\.id))
            h.alliances = []
            h.atWarWith = []
            h.diplomaticRelations = h.diplomaticRelations.filter { ids.contains($0.key) }
            gs.countries.append(h)
            for i in gs.countries.indices where gs.countries[i].id != id {
                gs.countries[i].diplomaticRelations[id] = h.diplomaticRelations[gs.countries[i].id] ?? 0
            }
            gs.shadow.eraGovernment[id] = h.government.rawValue
            gs.shadow.worldStats["foundings", default: 0] += 1
            // Constituent lands still on their historical path join the new state.
            for part in WorldMapData.historicalOwners[id] ?? [] {
                guard let k = gs.countries.firstIndex(where: { $0.id == part }), part != gs.playerCountryID,
                      !gs.countries[k].isTerritory, !gs.shadow.eraDiverged.contains(part), board[part] == nil else { continue }
                gs.countries[k].territoryOf = id
                gs.countries[k].atWarWith = []
                gs.countries[k].alliances = []
                gs.shadow.post("\(gs.countries[k].name) joins \(h.name).", date: gs.currentDate, severity: 1)
            }
            gs.shadow.post("\(h.name) is founded.", date: gs.currentDate, severity: 2)
            logPlayEvent("nation_founded", detail: ["country": id, "name": PlayHistory.text(h.name), "game_date": PlayHistory.day(gs.currentDate)])
        }
        self.gameState = gs
    }
}

// MARK: - Historical absorptions (3.16.2)

extension WorldPolitics {
    /// Absorptions the era boards don't encode (the board drops Korea in 1910 and the Baltic states in 1940 by
    /// itself): (land, absorber, year, year it is restored).
    static let absorptions: [(land: String, by: String, from: Int, until: Int)] = [
        ("POL", "RUS", 1795, 1918),   // the third partition (Prussia and Austria took the rest)
        ("AUT", "DEU", 1938, 1945),   // the Anschluss
        ("CSK", "DEU", 1939, 1945),
        ("POL", "DEU", 1939, 1945),
    ]
}

extension GameEngine {
    /// A nation still following history is absorbed on the real date into the nation that took it, if that nation is
    /// following history too. If the target is the player's ally or treaty partner, it becomes a crisis instead: the
    /// absorber moves by force. Absorbed nations are restored on their historical dates (or when the era board brings
    /// them back) while their absorber still follows history.
    func processAbsorptions(_ board: [String: Country], lastBoard: Set<String>) {
        guard let gs = gameState else { return }
        let y = gs.currentYear, ids = Set(board.keys)
        var due: [(String, String)] = []
        // Nations the era board dropped this year, with the owner history gave their land.
        for id in lastBoard.subtracting(ids).sorted() {
            let era = PreStateModel.era(for: id, year: y)
            let by = era.flatMap { $0.kind == .colony && ids.contains($0.owner) ? $0.owner : nil }
                ?? WorldMapData.owner(of: id, in: ids, year: y)
            if let by, by != id { due.append((id, by)) }
        }
        for a in WorldPolitics.absorptions where a.from <= y && y < a.until && !gs.shadow.firedRivalries.contains("absorb-\(a.land)-\(a.from)") {
            gs.shadow.firedRivalries.insert("absorb-\(a.land)-\(a.from)")
            due.append((a.land, a.by))
        }
        let me = gs.playerCountryID
        for (land, by) in due {
            guard land != me, by != me, !gs.shadow.eraDiverged.contains(land), !gs.shadow.eraDiverged.contains(by),
                  let absorber = gs.getCountry(id: by), !absorber.isDestroyed, !absorber.isTerritory else { continue }
            guard let t = gs.countries.firstIndex(where: { $0.id == land }) else {
                if gs.preState(land)?.era.kind == .indigenous, aiTakeLand(land, by: by) { gs.shadow.historicalAbsorptions[land] = by }
                continue
            }
            let target = gs.countries[t]
            guard !target.isDestroyed, !target.isTerritory else { continue }
            let guaranteed = target.alliances.contains(me)
                || gs.treaties.contains { $0.signatories.contains(me) && $0.signatories.contains(land) && [.alliance, .mutualDefense].contains($0.type) }
            if guaranteed {
                gs.shadow.post("\(absorber.name) moves to annex \(target.name). \(target.name), under American protection, appeals to Washington.", date: gs.currentDate, severity: 3)
                if !absorber.atWarWith.contains(land) { declareWar(aggressor: by, defender: land) }
                logPlayEvent("annexation_crisis", detail: ["land": land, "by": by, "game_date": PlayHistory.day(gs.currentDate)])
                continue
            }
            gs.activeWars.removeAll { $0.aggressor == land || $0.defender == land }
            for i in gs.countries.indices {
                gs.countries[i].atWarWith.remove(land)
                gs.countries[i].alliances.remove(land)
            }
            gs.countries[t].atWarWith = []
            gs.countries[t].alliances = []
            gs.countries[t].territoryOf = by
            gs.shadow.historicalAbsorptions[land] = by
            gs.shadow.worldStats["absorptions", default: 0] += 1
            gs.shadow.post("\(target.name) is annexed by \(absorber.name).", date: gs.currentDate, severity: 2)
            logPlayEvent("nation_absorbed", detail: ["land": land, "by": by, "game_date": PlayHistory.day(gs.currentDate)])
        }
        // Restorations: on the table's date, or when the era board has the nation again.
        for (land, by) in gs.shadow.historicalAbsorptions {
            let restoreYear = WorldPolitics.absorptions.first { $0.land == land && $0.by == by && $0.from <= y }?.until
            guard (restoreYear.map { y >= $0 } ?? false) || (ids.contains(land) && !lastBoard.contains(land)),
                  let t = gs.countries.firstIndex(where: { $0.id == land }), gs.countries[t].territoryOf == by,
                  !gs.shadow.eraDiverged.contains(by) else { continue }
            gs.countries[t].territoryOf = nil
            if let h = board[land] { gs.countries[t].name = h.name; gs.countries[t].government = h.government; gs.countries[t].flag = h.flag }
            gs.shadow.historicalAbsorptions.removeValue(forKey: land)
            gs.shadow.post("\(gs.countries[t].name) regains its independence.", date: gs.currentDate, severity: 2)
        }
        self.gameState = gs
    }
}

// MARK: - The record of the age (3.17.6)

/// Something another power did, on its real date. The player can never order any of these: GTNW has no action for
/// slavery or slave labour and none for genocide or ethnic cleansing, and it never will. They are here as history —
/// the world the President is playing in — and the Hall of Infamy keeps the record.
struct WorldAtrocity: Hashable {
    let id: String
    /// Board id of the power that did it; empty when it is the age itself rather than one state.
    let actor: String
    let from: Int
    let to: Int
    let text: String
    /// How far the rest of the world's opinion of the actor falls once it is known (0 = nobody is blamed).
    let worldCost: Int
    /// Abolition and the like: recorded, but not in the Hall of Infamy.
    let isAtrocity: Bool
}

extension WorldPolitics {
    private static func a(_ id: String, _ actor: String, _ from: Int, _ to: Int, _ cost: Int, _ text: String) -> WorldAtrocity {
        WorldAtrocity(id: id, actor: actor, from: from, to: to, text: text, worldCost: cost, isAtrocity: true)
    }
    private static func note(_ id: String, _ actor: String, _ from: Int, _ text: String) -> WorldAtrocity {
        WorldAtrocity(id: id, actor: actor, from: from, to: from, text: text, worldCost: 0, isAtrocity: false)
    }

    /// The age's own record, in order. Board ids: TUR is the Ottoman Empire, RUS the Russian Empire and then the
    /// Soviet Union, DEU the German states and then Germany, CHN the Qing and then China.
    static let atrocities: [WorldAtrocity] = [
        note("slave_economy", "", 1789, "Slave labour underpins the cotton economy of the American South, the sugar islands of the Caribbean and the plantations of Brazil."),
        note("slave_trade_act", "GBR", 1807, "Britain's Slave Trade Act abolishes the Atlantic slave trade for British ships."),
        note("us_import_ban", "USA", 1808, "The United States prohibits the importation of slaves from 1 January 1808."),
        note("abolition_1833", "GBR", 1833, "The Slavery Abolition Act ends slavery across most of the British Empire."),
        a("opium_war_1", "GBR", 1839, 1842, 8, "Britain goes to war to keep the opium trade into China open. The Treaty of Nanking follows in 1842."),
        a("opium_war_2", "GBR", 1856, 1860, 8, "A second war over the opium trade ends with the Convention of Peking, which legalises it."),
        note("emancipation", "USA", 1863, "The Emancipation Proclamation takes effect on 1 January 1863."),
        note("thirteenth", "USA", 1865, "The Thirteenth Amendment is ratified on 6 December 1865. Slavery is abolished in the United States."),
        a("congo_free_state", "BEL", 1885, 1908, 14, "Rubber quotas and the Force Publique in the Congo Free State. Roger Casement reports on it in 1904; Belgium annexes the colony in 1908."),
        a("boer_camps", "GBR", 1900, 1902, 12, "British camps in South Africa hold Boer and Black African families. Some 28,000 Boers and at least 14,000 Black Africans die in them."),
        a("herero", "DEU", 1904, 1908, 18, "German forces drive the Herero and Nama into the Omaheke. Lothar von Trotha's extermination order is dated 2 October 1904."),
        a("armenian", "TUR", 1915, 1917, 18, "The Ottoman government begins mass deportations of its Armenian population on 24 April 1915."),
        a("unrestricted_1917", "DEU", 1917, 1918, 12, "Germany resumes unrestricted submarine warfare on 1 February 1917, sinking neutral shipping without warning."),
        a("rif_gas", "ESP", 1921, 1927, 10, "Spain drops chemical bombs on villages in the Rif."),
        a("mukden", "JPN", 1931, 1931, 10, "Japanese officers blow up a length of their own railway outside Mukden on 18 September 1931 and take Manchuria for it."),
        a("holodomor", "RUS", 1932, 1933, 16, "Grain requisitions in Soviet Ukraine turn into a famine that kills millions."),
        a("unit731", "JPN", 1932, 1945, 18, "A Japanese army unit at Pingfang begins weapons experiments on prisoners."),
        a("ethiopia_gas", "ITA", 1935, 1936, 12, "Italy uses mustard gas in Ethiopia while a party to the 1925 Geneva Protocol."),
        a("guernica", "DEU", 1937, 1937, 10, "German aircraft burn Guernica on 26 April 1937."),
        a("nanjing", "JPN", 1937, 1938, 16, "Japanese forces take Nanjing on 13 December 1937 and massacre its population."),
        a("gleiwitz", "DEU", 1939, 1939, 10, "An attack on a German radio station at Gleiwitz on 31 August 1939 turns out to have been staged by the SS."),
        a("blitz", "DEU", 1940, 1941, 10, "German bombers turn from airfields to cities. London is bombed for fifty-seven nights."),
        a("holocaust", "DEU", 1941, 1945, 25, "Germany begins the systematic extermination of Europe's Jews."),
        a("bernhard", "DEU", 1942, 1945, 6, "Forged Bank of England notes printed by prisoners at Sachsenhausen reach the neutral markets."),
        a("greif", "DEU", 1944, 1944, 6, "German commandos in American uniform are taken behind the Ardennes front."),
        a("khmer", "KHM", 1975, 1979, 20, "The Khmer Rouge empty Cambodia's cities. A quarter of the country will not survive it."),
        a("rwanda", "RWA", 1994, 1994, 18, "Rwanda's Hutu Power government organises the massacre of the Tutsi population."),
    ]

    /// The era's dirty tactics a computer-run power might use in a war it is already fighting.
    static func aiTacticIDs(year: Int) -> [String] {
        DirtyTactics.available(in: year).filter { $0.target == .nation && !$0.isStance }.map(\.id)
    }
}

extension GameEngine {
    /// Once a game year, with the era sync: the age's own record. A power still following history does what it did,
    /// on the real date; the world's opinion of it falls, and the Hall of Infamy keeps the line.
    func processWorldAtrocities() {
        guard let gs = gameState, !gs.isMultiplayer else { return }
        let y = gs.currentYear
        for a in WorldPolitics.atrocities where a.from <= y && y <= a.to && !gs.shadow.firedRivalries.contains("atrocity-\(a.id)") {
            if !a.actor.isEmpty {
                guard let actor = gs.getCountry(id: a.actor), !actor.isDestroyed, !actor.isTerritory,
                      !gs.shadow.eraDiverged.contains(a.actor) else { continue }
                if a.actor == gs.playerCountryID && a.isAtrocity { continue }   // the player's own record is his own
            }
            gs.shadow.firedRivalries.insert("atrocity-\(a.id)")
            let item = TickerItem(date: gs.currentDate, text: a.text, severity: a.isAtrocity ? 3 : 1)
            gs.shadow.ticker.append(item)
            gs.shadow.worldAtrocities.append(item)
            if gs.shadow.worldAtrocities.count > 40 { gs.shadow.worldAtrocities.removeFirst() }
            gs.shadow.worldStats["atrocities", default: 0] += a.isAtrocity ? 1 : 0
            if a.worldCost > 0 && !a.actor.isEmpty {
                for o in gs.countries where o.id != a.actor && !o.isDestroyed && !o.isTerritory {
                    modifyDiplomaticRelation(from: o.id, to: a.actor, by: -a.worldCost)
                }
            }
            logPlayEvent("world_atrocity", detail: ["id": a.id, "actor": a.actor, "game_date": PlayHistory.day(gs.currentDate)])
        }
        self.gameState = gs
    }

    /// Each turn: a computer-run power at war may reach for the same dirty tactics the President can. It uses what
    /// its era allows, the world hears about it (there is no covert option for a power the player cannot see
    /// inside), and the Hall of Infamy keeps the line.
    func processAITactics() {
        guard let gs = gameState, !gs.isMultiplayer else { return }
        let ids = WorldPolitics.aiTacticIDs(year: gs.currentYear)
        guard !ids.isEmpty else { return }
        let rate = 0.25 * WorldPolitics.activity(gs.difficultyLevel)
        for w in gs.activeWars where w.aggressor != gs.playerCountryID {
            guard Double.random(in: 0..<1) < gs.scale.probability(annual: rate),
                  let a = gs.getCountry(id: w.aggressor), !a.isDestroyed, !a.isTerritory,
                  let di = gs.countries.firstIndex(where: { $0.id == w.defender }), !gs.countries[di].isDestroyed,
                  let t = ids.randomElement().flatMap(DirtyTactics.tactic) else { continue }
            let d = gs.countries[di]
            // Effects on game stats only, a third of what the President's own order would do.
            gs.countries[di].gdp *= 0.985
            gs.countries[di].stability = max(0, d.stability - 5)
            gs.countries[di].profile.anxieties.military += 12
            gs.totalCasualties += Int(Double(max(1, d.population)) * 300)
            frontBlow(d.id, will: 0.05, troops: 0.02)
            let status = t.status(in: gs.currentYear)
            let line = "\(a.name) uses \(t.name.lowercased()) against \(d.name)." + (status == .treatyBanned ? " It is banned by treaty." : "")
            let item = TickerItem(date: gs.currentDate, text: line, severity: status == .legal ? 2 : 3)
            gs.shadow.ticker.append(item)
            gs.shadow.worldAtrocities.append(item)
            if gs.shadow.worldAtrocities.count > 40 { gs.shadow.worldAtrocities.removeFirst() }
            gs.shadow.worldStats["aiTactics", default: 0] += 1
            let cost = ArsenalCatalog.cost(status)
            for o in gs.countries where o.id != a.id && !o.isDestroyed && !o.isTerritory {
                modifyDiplomaticRelation(from: o.id, to: a.id, by: -cost.world)
            }
            logPlayEvent("ai_tactic", detail: ["actor": a.id, "target": d.id, "tactic": t.id,
                                               "legal_status": status.rawValue, "game_date": PlayHistory.day(gs.currentDate)])
        }
        self.gameState = gs
    }
}
