//
//  PreStateModel.swift
//  Global Thermal Nuclear War
//
//  Land before its modern country exists (3.13.0), on every continent. `TerritoryData.swift` (generated from
//  Documentation/territories/data.py) says who held each modern country's land, by era:
//  - a colony of an era power in the game (New Spain under Spain, British North America, Ottoman Mesopotamia…),
//    drawn in the owner's colour with a hatch and a "Name (Owner)" label. It can be seized by force (sized troops,
//    an amphibious fleet, a coalition against the owner), bought by treaty (the historical U.S. purchases appear as
//    offers in their real windows; anything else can be negotiated at a price set by its value and relations), or
//    freed by backing its independence, which becomes an allied state;
//  - land held by peoples or states the game doesn't model (Aotearoa before 1840, the Konbaung kingdom, the Arabian
//    emirates…): claimable like 3.3.0 land, but its people resist, and taking it costs stability, brings an
//    insurgency, and is judged by the standards of the era.
//  Taken land becomes an ordinary territory (3.7.0 resources, 3.9.0 governance and statehood). Africa keeps its 3.3.0
//  rules. Encyclopedia-level facts only.
//  Repository: https://github.com/kochj23/GTNW
//

import Foundation

enum PreStateKind: String, Codable { case colony, indigenous }

struct PreStateEra: Hashable {
    let land: String
    let from: Int
    /// The year this status ends (exclusive).
    let to: Int
    let kind: PreStateKind
    /// Game id of the era power holding a colony; empty for indigenous land.
    let owner: String
    let name: String
    /// Colony: the historical independence or transfer year. Indigenous: resistance strength 0–100.
    let extra: Int
}

/// A historical acquisition offered to a U.S. President in its real window.
struct HistoricalAcquisition: Hashable, Identifiable {
    let id: String
    let name: String
    let owner: String
    let from: Int
    /// End of the window (exclusive).
    let to: Int
    let price: String
    /// The map outline it transfers, if any (Louisiana, Florida and Gadsden lie inside the U.S. outline).
    let land: String
    /// Yearly resource value it adds ($B), like a territory's.
    let value: Double
}

/// What a piece of pre-state land is right now.
struct PreStateStatus: Hashable {
    let era: PreStateEra
    /// The owner is in the game (a colony that can be bought, seized or freed).
    let ownerPresent: Bool
    var label: String { era.kind == .colony ? "\(era.name) (\(PreStateModel.ownerName(era.owner)))" : era.name }
}

enum PreStateModel {
    /// The Alaska rings of the U.S. outline, split out so Russian America can be drawn (3.13.0).
    static let alaska = "USA_AK"

    static let ownerNames: [String: String] = [
        "GBR": "UK", "ESP": "Spain", "PRT": "Portugal", "FRA": "France", "NLD": "Netherlands", "RUS": "Russia",
        "TUR": "Ottoman Empire", "CHN": "China", "JPN": "Japan", "THA": "Siam", "AUT": "Austria", "DNK": "Denmark",
        "SWE": "Sweden", "IND": "British India", "AUS": "Australia", "PAK": "Pakistan", "HTI": "Haiti",
    ]
    static func ownerName(_ id: String) -> String { ownerNames[id] ?? id }

    /// The era covering a land in a year; past the last era the last one holds (the game never re-creates a country).
    static func era(for land: String, year: Int) -> PreStateEra? {
        let all = eras.filter { $0.land == land }
        return all.first { year >= $0.from && year < $0.to } ?? all.last.flatMap { year >= $0.to ? $0 : nil }
    }

    /// Lands with a pre-state record.
    static let lands: Set<String> = Set(eras.map(\.land))

    /// Templates for the special outline (Alaska); every other land uses its modern country template.
    static let alaskaTemplate = CountryTemplate(alaska, "Alaska", flag: "🇺🇸", capital: "Sitka",
                                                lat: 61.2, lon: -149.9, region: .northAmerica, gov: .republic, align: .western,
                                                gdp: 1, pop: 0.05, mil: 1, aggr: 0, stab: 70)

    static let virginIslandsTemplate = CountryTemplate("VIR", "Virgin Islands", flag: "🇻🇮", capital: "Charlotte Amalie",
                                                        lat: 18.34, lon: -64.93, region: .northAmerica, gov: .republic, align: .western,
                                                        gdp: 4, pop: 0.1, mil: 1, aggr: 0, stab: 70)

    static func template(_ land: String) -> CountryTemplate? { WorldCountriesDatabase.template(id: land) }

    /// The value of a land now ($B a year from its resources), used for purchase prices.
    static func value(_ land: String, year: Int) -> Double {
        ExpansionModel.deposits(for: land, year: year).reduce(0) { $0 + $1.value }
    }

    /// Price to buy a colony by negotiation ($B, game money): ten years of its value, at least $1B, higher the worse
    /// relations are (× 1.5 at −100, × 0.5 at +100).
    static func price(_ land: String, year: Int, relation: Int) -> Double {
        max(1, value(land, year: year) * 10) * (1 - Double(relation) / 200)
    }

    /// Chance the owner sells: 0.2 + relations / 150, never while at war; a historical offer in its window stands
    /// (the seller made it) unless the two are at war.
    static func saleOdds(relation: Int, atWar: Bool, historical: Bool) -> Double {
        if atWar { return 0 }
        if historical { return 1 }
        return min(0.9, max(0.02, 0.2 + Double(relation) / 150))
    }

    /// Chance a backed revolt succeeds: 0.15, +0.35 within five years of the real independence date, +0.15 if the
    /// owner is at war with the player, + up to 0.2 as the owner's stability falls.
    static func revoltOdds(year: Int, independence: Int, ownerAtWarWithPlayer: Bool, ownerStability: Int) -> Double {
        var p = 0.15
        if year >= independence - 5 { p += 0.35 }
        if ownerAtWarWithPlayer { p += 0.15 }
        p += Double(max(0, 60 - ownerStability)) / 300
        return min(0.9, p)
    }

    /// Colonial garrison (thousands) a seizure meets: 1.5% of the owner's force pool, at least 2K (design choice:
    /// colonies were held by small garrisons far from home).
    static func garrison(owner: Country) -> Double { max(2, CombatModel.forcePool(owner) * 0.015) }

    /// Odds an expedition of `troops` takes land held by a garrison or a resisting people: the War Room's power ratio
    /// r as r² / (1 + r²).
    static func seizeOdds(troops: Double, attackerStrength: Int, defenders: Double, defenderStrength: Int) -> Double {
        let pa = CombatModel.power(troops: troops, will: 0.8, strength: attackerStrength, defending: false)
        let pd = CombatModel.power(troops: defenders, will: 0.85, strength: defenderStrength, defending: true)
        let r = pa / max(0.001, pd)
        return r * r / (1 + r * r)
    }

    /// A resisting people's fighting strength (thousands) from its resistance score.
    static func resistanceTroops(_ resistance: Int) -> Double { Double(resistance) * 0.15 }
}

extension GameState {
    /// Pre-state status of a land now, or nil when the land is a country in the game (or, for Alaska, part of the U.S.).
    func preState(_ land: String) -> PreStateStatus? {
        guard PreStateModel.lands.contains(land), getCountry(id: land) == nil else { return nil }
        if land == PreStateModel.alaska && (shadow.acquired.contains("alaska") || currentYear >= 1867) { return nil }
        guard let era = PreStateModel.era(for: land, year: currentYear) else { return nil }
        let present = era.kind == .colony && getCountry(id: era.owner).map { !$0.isDestroyed } == true
        if era.kind == .colony && !present {
            // The owner isn't in the game: treat the land as unheld.
            return PreStateStatus(era: PreStateEra(land: land, from: era.from, to: era.to, kind: .indigenous, owner: "",
                                                   name: era.name, extra: 10), ownerPresent: false)
        }
        return PreStateStatus(era: era, ownerPresent: present)
    }

    /// Indigenous / unheld pre-state land, claimable like 3.3.0 land.
    var indigenousLandIDs: Set<String> {
        Set(PreStateModel.lands.filter { preState($0)?.era.kind == .indigenous })
    }

    /// Colonies held by an era power in the game.
    var colonyLandIDs: Set<String> {
        Set(PreStateModel.lands.filter { preState($0)?.era.kind == .colony })
    }
}

// MARK: - Engine

extension GameEngine {
    /// Make a taken land a territory of the player, like a 3.3.0 claim. Returns the new territory.
    @discardableResult
    private func annexLand(_ land: String, troops: Double, stability: Int, outcry: Double) -> Country? {
        guard let gs = gameState, let owner = gs.getPlayerCountry(), let t = PreStateModel.template(land),
              let oi = gs.countries.firstIndex(where: { $0.id == owner.id }) else { return nil }
        var c = CombatModel.claim(t, for: owner, troops: troops)
        c.stability = stability
        var p = c.profile; p.outcry = outcry; c.profile = p
        gs.countries.append(c)
        gs.countries[oi].alliances.insert(land)
        gs.countries[oi].diplomaticRelations[land] = 100
        gs.shadow.garrisons[land] = troops
        gs.shadow.expansionLog.append(gs.currentDate)
        gs.shadow.claimDates[land] = gs.currentDate
        self.gameState = gs
        return c
    }

    /// Seize a colony from its owner by force (one action). Opens a war with the owner if there isn't one; the
    /// colonial garrison fights the expedition. `roll` 0..<1 for tests.
    @discardableResult
    func seizeColony(_ land: String, troops: Double, roll: Double = Double.random(in: 0..<1), spendAction: Bool = true) -> Bool? {
        guard let gs = gameState, !spendAction || gs.actionsRemaining > 0, let st = gs.preState(land), st.era.kind == .colony,
              let owner = gs.getCountry(id: st.era.owner), let me = gs.getPlayerCountry(),
              troops.isFinite, troops >= 1, !spendAction || troops <= AttackSizing.freeTroops(gs) else { return nil }
        if !owner.atWarWith.contains(me.id) { declareWar(aggressor: me.id, defender: owner.id) }
        let odds = PreStateModel.seizeOdds(troops: troops, attackerStrength: me.militaryStrength,
                                           defenders: PreStateModel.garrison(owner: owner), defenderStrength: owner.militaryStrength)
        let won = roll < odds
        if won {
            annexLand(land, troops: troops, stability: 40, outcry: 45)
            let pol = ExpansionModel.politics(year: gs.currentYear, nth: ExpansionModel.takenLastYear(gs, before: gs.currentDate))
            gs.shadow.ruthlessness += pol.ruthlessness
            modifyDiplomaticRelation(from: owner.id, to: me.id, by: -40)
            gs.shadow.post("\(st.label) falls to \(me.name). It is now a territory.", date: gs.currentDate, severity: 3)
        } else {
            gs.shadow.post("The expedition against \(st.label) is beaten back.", date: gs.currentDate, severity: 2)
        }
        logPlayEvent("colony_seized", detail: ["land": land, "name": PlayHistory.text(st.label), "owner": owner.id, "troops_k": Int(troops),
                                               "success": won, "odds": PlayHistory.num(odds, places: 100), "game_date": PlayHistory.day(gs.currentDate)])
        self.gameState = gs
        if spendAction { completePlayerAction() }
        return won
    }

    /// Each turn: announce historical offers as their windows open (U.S. player only).
    func processPreState() {
        guard let gs = gameState else { return }
        for a in openAcquisitions() where !gs.shadow.announcedOffers.contains(a.id) {
            gs.shadow.announcedOffers.insert(a.id)
            gs.shadow.post("\(gs.getCountry(id: a.owner)?.name ?? a.owner) offers to sell: the \(a.name), for \(a.price).", date: gs.currentDate, severity: 2)
        }
        self.gameState = gs
    }

    /// The historical offers open now (U.S. player only), not yet taken.
    func openAcquisitions() -> [HistoricalAcquisition] {
        guard let gs = gameState, gs.playerCountryID == "USA" else { return [] }
        return PreStateModel.acquisitions.filter { a in
            gs.currentYear >= a.from && gs.currentYear < a.to && !gs.shadow.acquired.contains(a.id) && gs.getCountry(id: a.owner) != nil
        }
    }

    /// Accept a historical offer (one action): the land (if it has an outline) becomes U.S. land and its value is added
    /// as income from then on.
    @discardableResult
    func acceptAcquisition(_ id: String) -> Bool {
        guard let gs = gameState, gs.actionsRemaining > 0, let a = openAcquisitions().first(where: { $0.id == id }),
              let owner = gs.getCountry(id: a.owner), let me = gs.getPlayerCountry() else { return false }
        let rel = owner.diplomaticRelations[me.id] ?? 0
        guard PreStateModel.saleOdds(relation: rel, atWar: owner.atWarWith.contains(me.id), historical: true) >= 1 else {
            gs.shadow.post("\(owner.name) withdraws the offer: the two nations are at war.", date: gs.currentDate, severity: 1)
            self.gameState = gs
            return false
        }
        gs.shadow.acquired.insert(a.id)
        if a.land == "VIR", gs.preState("VIR") != nil { annexLand("VIR", troops: 1, stability: 70, outcry: 5) }
        gs.shadow.acquisitionIncome += a.value
        modifyDiplomaticRelation(from: owner.id, to: me.id, by: 10)
        gs.shadow.post("The \(a.name) is signed: \(a.price) to \(owner.name).", date: gs.currentDate, severity: 2)
        logPlayEvent("land_purchased", detail: ["acquisition": a.id, "name": a.name, "seller": owner.id, "price": a.price,
                                                "game_date": PlayHistory.day(gs.currentDate)])
        self.gameState = gs
        completePlayerAction()
        return true
    }

    /// Negotiate to buy a colony (one action): price from value and relations, paid out of national output. `roll`
    /// 0..<1 for tests. Returns whether the owner sold.
    @discardableResult
    func purchaseColony(_ land: String, roll: Double = Double.random(in: 0..<1)) -> Bool? {
        guard let gs = gameState, gs.actionsRemaining > 0, let st = gs.preState(land), st.era.kind == .colony,
              let owner = gs.getCountry(id: st.era.owner), let me = gs.getPlayerCountry(),
              let pi = gs.countries.firstIndex(where: { $0.id == me.id }) else { return nil }
        let rel = owner.diplomaticRelations[me.id] ?? 0
        let price = PreStateModel.price(land, year: gs.currentYear, relation: rel)
        let sold = roll < PreStateModel.saleOdds(relation: rel, atWar: owner.atWarWith.contains(me.id), historical: false)
        if sold {
            gs.countries[pi].gdp -= price / 1000
            annexLand(land, troops: 1, stability: 60, outcry: 15)
            gs.shadow.post(String(format: "%@ sells %@ for $%.1fB.", owner.name, st.label, price), date: gs.currentDate, severity: 2)
        } else {
            modifyDiplomaticRelation(from: owner.id, to: me.id, by: -3)
            gs.shadow.post("\(owner.name) will not sell \(st.label).", date: gs.currentDate, severity: 1)
        }
        logPlayEvent("land_purchased", detail: ["land": land, "name": PlayHistory.text(st.label), "seller": owner.id, "sold": sold,
                                                "price_b": PlayHistory.num(price), "game_date": PlayHistory.day(gs.currentDate)])
        self.gameState = gs
        completePlayerAction()
        return sold
    }

    /// Back a colony's independence (one action, $2B). Success makes it a sovereign state allied to the player.
    @discardableResult
    func supportIndependence(_ land: String, roll: Double = Double.random(in: 0..<1)) -> Bool? {
        guard let gs = gameState, gs.actionsRemaining > 0, let st = gs.preState(land), st.era.kind == .colony,
              let owner = gs.getCountry(id: st.era.owner), let me = gs.getPlayerCountry(),
              let pi = gs.countries.firstIndex(where: { $0.id == me.id }), let t = PreStateModel.template(land) else { return nil }
        let odds = PreStateModel.revoltOdds(year: gs.currentYear, independence: st.era.extra,
                                            ownerAtWarWithPlayer: owner.atWarWith.contains(me.id), ownerStability: owner.stability)
        let won = roll < odds
        gs.countries[pi].gdp -= 2.0 / 1000
        modifyDiplomaticRelation(from: owner.id, to: me.id, by: -30)
        if won {
            var c = t.toCountry()
            c.alliances.insert(me.id)
            c.diplomaticRelations[me.id] = 70
            c.diplomaticRelations[owner.id] = -60
            gs.countries.append(c)
            gs.countries[pi].alliances.insert(land)
            gs.countries[pi].diplomaticRelations[land] = 70
            gs.shadow.post("\(c.name) declares its independence from \(owner.name), with \(me.name)'s backing.", date: gs.currentDate, severity: 3)
        } else {
            gs.shadow.post("The revolt in \(st.label) is crushed by \(owner.name).", date: gs.currentDate, severity: 2)
        }
        logPlayEvent("independence_backed", detail: ["land": land, "name": PlayHistory.text(st.label), "owner": owner.id, "success": won,
                                                     "odds": PlayHistory.num(odds, places: 100), "game_date": PlayHistory.day(gs.currentDate)])
        self.gameState = gs
        completePlayerAction()
        return won
    }

    /// Claim indigenous-held land (one action): its people resist (odds from troops against resistance); success
    /// brings a restless territory, and after 1945 the world condemns it as colonial conquest. `roll` for tests.
    @discardableResult
    func claimIndigenousLand(_ land: String, troops: Double, roll: Double = Double.random(in: 0..<1), spendAction: Bool = true) -> Bool? {
        guard let gs = gameState, !spendAction || gs.actionsRemaining > 0, let st = gs.preState(land), st.era.kind == .indigenous,
              let me = gs.getPlayerCountry(), troops.isFinite, troops >= 1, troops <= max(5, AttackSizing.freeTroops(gs)) else { return nil }
        let resisters = PreStateModel.resistanceTroops(st.era.extra)
        let odds = PreStateModel.seizeOdds(troops: troops, attackerStrength: me.militaryStrength, defenders: max(0.5, resisters), defenderStrength: 30)
        let won = roll < odds
        let pol = ExpansionModel.politics(year: gs.currentYear, nth: ExpansionModel.takenLastYear(gs, before: gs.currentDate) + 1)
        if won {
            annexLand(land, troops: troops, stability: max(15, 50 - st.era.extra / 2), outcry: min(95, 30 + Double(st.era.extra)))
            gs.shadow.ruthlessness += pol.ruthlessness + Double(st.era.extra) / 10
            gs.shadow.popularity = PopularityModel.clamp(gs.shadow.popularity + pol.popularity)
            let world = Int((2 * pol.worldFactor + Double(st.era.extra) / 20).rounded())
            for c in gs.countries where c.id != me.id && !c.isTerritory && !c.isDestroyed { modifyDiplomaticRelation(from: c.id, to: me.id, by: -world) }
            gs.shadow.post("\(me.name) takes \(st.label) by force. Its people do not accept it; resistance continues.", date: gs.currentDate, severity: 2)
        } else {
            gs.shadow.post("The expedition into \(st.label) is driven off by its people.", date: gs.currentDate, severity: 2)
        }
        logPlayEvent("claimed_land", detail: ["land": land, "name": PlayHistory.text(st.label), "indigenous": true, "success": won,
                                              "troops_k": Int(troops), "game_date": PlayHistory.day(gs.currentDate)])
        self.gameState = gs
        if spendAction { completePlayerAction() }
        return won
    }
}
