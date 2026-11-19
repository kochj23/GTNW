//
//  Empire.swift
//  Global Thermal Nuclear War
//
//  The empire release (3.29.0), built on 3.3.0 claims, 3.7.0 resources and 3.13.0 colonies:
//  - Land that pays: every territory yields from the CIA World Factbook's natural resources for its land, its arable
//    share and its coastline, valued against the owner's economy, ramping up with the years held.
//  - Empire victories: Manifest Destiny (all of North America), The Sun Never Sets (land in every region), Every Rock
//    (all 32 small islands), with a progress read-out.
//  - Claim campaigns: one order, one action, then flags planted turn after turn until done, out of troops or money.
//  - Your names on the map: every rename is recorded (the Names tab) and renamed lands are labelled on the map.
//  - A land market: rival bidders, auctions of unwanted colonies, and powers offering the President land they want
//    rid of.
//  Game-balance numbers are design choices, documented where they're defined.
//  Repository: https://github.com/kochj23/GTNW
//

import Foundation

// MARK: - Land that pays

extension ExpansionModel {
    /// Yield points per Factbook resource, from the year it was worth exploiting at scale (design choice).
    static let resourcePoints: [NaturalResource: (points: Double, from: Int)] = [
        .oil: (3, 1900), .naturalGas: (2, 1950), .coal: (1, 1800), .uranium: (2, 1945), .gold: (2, 1789), .diamonds: (2, 1870),
        .copper: (1, 1850), .lithium: (2, 2000), .rareEarths: (2, 1990), .iron: (1, 1800), .agriculture: (1, 1789),
        .timber: (0.5, 1789), .fish: (0.5, 1789), .water: (0.2, 1900), .phosphates: (0.5, 1850), .nickel: (1, 1900),
        .bauxite: (1, 1900), .cobalt: (1, 1950),
    ]

    /// The Factbook resources a land yields this year.
    static func landResources(_ id: String, year: Int) -> [NaturalResource] {
        guard WorldFactbookDatabase.records[id] != nil else { return [.fish] }
        return WorldFactbookDatabase.record(for: id).naturalResources
            .filter { year >= (resourcePoints[$0]?.from ?? 9999) }
            .sorted { $0.rawValue < $1.rawValue }
    }

    /// Yield points of a land: its resources, + arable % / 20, + coastline / 4,000 km (at most 2). Lands without a
    /// Factbook record (islands, Antarctica) count a fishery and a harbour: 0.75. At most 10.
    static func landPoints(_ id: String, year: Int) -> Double {
        guard WorldFactbookDatabase.records[id] != nil else { return 0.75 }
        let r = WorldFactbookDatabase.record(for: id)
        let res = landResources(id, year: year).reduce(0) { $0 + (resourcePoints[$1]?.points ?? 0) }
        return min(10, res + Double(r.arableLandPercent) / 20 + min(2, Double(r.coastlineKm) / 4000))
    }

    /// $B a yield point is worth a year to an owner: 0.02% of the owner's output (0.2 × GDP in trillions), so land
    /// matters in every era against the national budget (≈ 18% of output) without running away: thirty average
    /// territories add about 2% of output.
    static func pointValue(ownerGDP: Double) -> Double { max(0, ownerGDP) * 0.2 }

    /// Years of development: +0% until two years held, then up to +50% at ten.
    static func maturity(yearsHeld: Double) -> Double { 1 + min(0.5, max(0, yearsHeld - 2) / 16) }

    /// The Factbook yield of a territory at full production ($B a year), before ramp-up, hold and extraction.
    static func landYield(_ c: Country, in gs: GameState) -> Double {
        let owner = c.territoryOf.flatMap { gs.getCountry(id: $0) }
        return landPoints(c.id, year: gs.currentYear) * pointValue(ownerGDP: owner?.gdp ?? 0)
    }
}

// MARK: - Empire victories

enum EmpireGoal: String, CaseIterable, Identifiable {
    case manifestDestiny, sunNeverSets, everyRock
    var id: String { rawValue }

    var victory: VictoryType {
        switch self {
        case .manifestDestiny: return .manifestDestiny
        case .sunNeverSets: return .sunNeverSets
        case .everyRock: return .everyRock
        }
    }

    var title: String { victory.rawValue }
}

enum EmpireModel {
    /// The player holds a land: it is the player, or the player's territory.
    static func holds(_ id: String, in gs: GameState) -> Bool {
        id == gs.playerCountryID || gs.getCountry(id: id).map { !$0.isDestroyed && $0.territoryOf == gs.playerCountryID } == true
    }

    /// Every North American land in this game: its countries (and territories), and the colonies, peoples' lands and
    /// unclaimed lands whose template lies in North America.
    static func northAmerica(_ gs: GameState) -> Set<String> {
        var out = Set(gs.countries.filter { !$0.isDestroyed && $0.region == .northAmerica }.map(\.id))
        for id in gs.unclaimedLandIDs.union(gs.indigenousLandIDs).union(gs.colonyLandIDs)
            where (WorldCountriesDatabase.template(id: id) ?? PreStateModel.template(id))?.region == .northAmerica {
            out.insert(id)
        }
        return out
    }

    /// Regions where the player holds land.
    static func regionsHeld(_ gs: GameState) -> Set<WorldRegion> {
        Set(gs.countries.filter { !$0.isDestroyed && ($0.id == gs.playerCountryID || $0.territoryOf == gs.playerCountryID) }.map(\.region))
    }

    /// Progress toward a goal: lands (or regions) held, of how many.
    static func progress(_ g: EmpireGoal, _ gs: GameState) -> (held: Int, total: Int) {
        switch g {
        case .manifestDestiny:
            let na = northAmerica(gs)
            return (na.filter { holds($0, in: gs) }.count, na.count)
        case .sunNeverSets:
            return (regionsHeld(gs).count, WorldRegion.allCases.count)
        case .everyRock:
            return (Islands.all.filter { holds($0.id, in: gs) }.count, Islands.all.count)
        }
    }

    /// Met now (Manifest Destiny needs at least three lands, so an empty continent never counts).
    static func isMet(_ g: EmpireGoal, _ gs: GameState) -> Bool {
        let p = progress(g, gs)
        return p.total >= (g == .manifestDestiny ? 3 : 1) && p.held >= p.total
    }

    /// The goals met at the start of a game don't count (Britain in 1850 already spans the globe).
    static func baseline(_ gs: GameState) -> [String] { EmpireGoal.allCases.filter { isMet($0, gs) }.map(\.rawValue) }

    /// The empire victory earned now, if any.
    static func victory(_ gs: GameState) -> VictoryType? {
        if gs.shadow.empireAtStart == nil { gs.shadow.empireAtStart = baseline(gs) }   // older saves: from now on
        let already = Set(gs.shadow.empireAtStart ?? [])
        return EmpireGoal.allCases.first { !already.contains($0.rawValue) && isMet($0, gs) }?.victory
    }
}

// MARK: - Claim campaigns

/// One order to take many lands, a flag (or a few) a turn.
struct ClaimCampaign: Codable, Hashable {
    var name: String
    var queue: [String]
    var planted: [String] = []
    var failed: [String] = []
    var started: Date
}

enum ClaimCampaigns {
    static let maxLands = 200

    /// Landings a turn: one a day or week, two a month, six a year.
    static func perTurn(_ t: TurnLength) -> Int {
        switch t {
        case .day, .week: return 1
        case .month: return 2
        case .year: return 6
        }
    }

    /// $B a landing costs (ships, stores, a survey party): 0.02 before 1900, 0.1 before 1950, 0.5 after.
    static func landingCost(year: Int) -> Double { year < 1900 ? 0.02 : (year < 1950 ? 0.1 : 0.5) }

    /// Troops a landing takes: 1K on an empty island, else the standard 5K expedition.
    static func troops(for id: String) -> Double { Islands.uninhabited(id) ? 1 : AttackSizing.expeditionStandard }

    /// The sets the UNCLAIMED list offers.
    enum Selection: Hashable {
        case emptyIslands
        case region(WorldRegion)
        case custom([String])
    }

    static func region(of id: String) -> WorldRegion? {
        Islands.byID[id]?.region ?? WorldCountriesDatabase.template(id: id)?.region ?? PreStateModel.template(id)?.region
    }
}

extension GameState {
    /// Lands a claim can take now (unclaimed or peoples' land).
    var claimableLandIDs: Set<String> { unclaimedLandIDs.union(indigenousLandIDs) }

    /// The lands a campaign selection covers now. Empty islands need a coast to sail from.
    func campaignTargets(_ s: ClaimCampaigns.Selection) -> [String] {
        switch s {
        case .emptyIslands:
            guard Reach.isCoastal(playerCountryID, in: self) else { return [] }
            return unclaimedLands.filter { $0.kind == .emptyIsland }.map(\.id)
        case .region(let r):
            return unclaimedLands.filter { ClaimCampaigns.region(of: $0.id) == r }.map(\.id)
        case .custom(let ids):
            let ok = claimableLandIDs
            var seen = Set<String>()
            return ids.filter { ok.contains($0) && seen.insert($0).inserted }
        }
    }
}

extension GameEngine {
    /// Launch a claim campaign (one action). Lands that can't be claimed are dropped; at most 200. False when there
    /// is nothing to claim, no action left, or a campaign is already under way.
    @discardableResult
    func launchClaimCampaign(_ s: ClaimCampaigns.Selection, name: String) -> Bool {
        guard let gs = gameState, gs.actionsRemaining > 0, gs.shadow.claimCampaign == nil else { return false }
        let lands = Array(gs.campaignTargets(s).prefix(ClaimCampaigns.maxLands))
        guard !lands.isEmpty else { return false }
        let label = WorldBriefModel.sanitize(name, max: 60)
        gs.shadow.claimCampaign = ClaimCampaign(name: label, queue: lands, started: gs.currentDate)
        gs.shadow.post("Claim campaign \"\(label)\" launched: \(lands.count) land\(lands.count == 1 ? "" : "s"), \(ClaimCampaigns.perTurn(gs.turnLength)) a \(gs.turnLength.displayName.lowercased()).",
                       date: gs.currentDate, severity: 2)
        logPlayEvent("claim_campaign", detail: ["name": PlayHistory.text(label), "lands": lands.count, "game_date": PlayHistory.day(gs.currentDate)])
        self.gameState = gs
        completePlayerAction()
        return true
    }

    /// Call the campaign off (no action).
    func cancelClaimCampaign() {
        guard let gs = gameState, let c = gs.shadow.claimCampaign else { return }
        gs.shadow.claimCampaign = nil
        gs.shadow.post("Claim campaign \"\(c.name)\" called off: \(c.planted.count) flag\(c.planted.count == 1 ? "" : "s") planted, \(c.queue.count) land\(c.queue.count == 1 ? "" : "s") left.", date: gs.currentDate, severity: 1)
        self.gameState = gs
    }

    /// Each turn: the campaign's next landings, under the ordinary claim rules (odds, outcry, the spree's politics).
    /// It halts when troops or money run out. `roll` fixes indigenous landings' luck for tests.
    func processClaimCampaign(roll: Double? = nil) {
        guard let gs = gameState, var c = gs.shadow.claimCampaign else { return }
        var left = ClaimCampaigns.perTurn(gs.turnLength)
        var halt: String?
        while left > 0, !c.queue.isEmpty {
            let id = c.queue.removeFirst()
            guard gs.claimableLandIDs.contains(id) else { continue }   // someone else got there first
            let troops = ClaimCampaigns.troops(for: id)
            let cost = ClaimCampaigns.landingCost(year: gs.currentYear)
            guard AttackSizing.freeTroops(gs) >= troops else { c.queue.insert(id, at: 0); halt = "no troops are free"; break }
            let gdp = gs.getPlayerCountry()?.gdp ?? 0
            guard gs.shadow.aidRemaining >= cost || gdp * 1000 > cost * 200 else { c.queue.insert(id, at: 0); halt = "the money has run out"; break }
            spendFunds(cost)
            let ok: Bool
            if gs.unclaimedLandIDs.contains(id) {
                ok = claimLand(id, troops: troops, spendAction: false)
            } else {
                ok = claimIndigenousLand(id, troops: troops, roll: roll ?? Double.random(in: 0..<1, using: &gs.rng), spendAction: false) == true
            }
            if ok { c.planted.append(id) } else { c.failed.append(id) }
            left -= 1
        }
        if let why = halt {
            gs.shadow.post("Claim campaign \"\(c.name)\" halts: \(why). \(c.queue.count) land\(c.queue.count == 1 ? "" : "s") left.", date: gs.currentDate, severity: 2)
            gs.shadow.claimCampaign = nil
        } else if c.queue.isEmpty {
            gs.shadow.post("Claim campaign \"\(c.name)\" complete: \(c.planted.count) flag\(c.planted.count == 1 ? "" : "s") planted\(c.failed.isEmpty ? "" : ", \(c.failed.count) landing\(c.failed.count == 1 ? "" : "s") driven off").",
                           date: gs.currentDate, severity: 2)
            gs.shadow.claimCampaign = nil
        } else {
            gs.shadow.claimCampaign = c
        }
        self.gameState = gs
    }
}

// MARK: - Your names on the map

/// One rename the President ordered.
struct RenameRecord: Codable, Hashable {
    var land: String
    var from: String
    var to: String
    var date: Date
}

extension GameState {
    /// Lands the President renamed: original name → current name, with the date of the last rename. Newest first.
    var nameBook: [(land: String, original: String, current: String, date: Date)] {
        var first: [String: RenameRecord] = [:], last: [String: RenameRecord] = [:]
        for r in shadow.renames {
            if first[r.land] == nil { first[r.land] = r }
            last[r.land] = r
        }
        return last.values.sorted { $0.date > $1.date }.map { r in
            (r.land, first[r.land]?.from ?? r.from, getCountry(id: r.land)?.name ?? r.to, r.date)
        }
    }

    /// Lands to label with the President's name for them: renamed and still held.
    var namedLands: Set<String> {
        Set(shadow.renames.map(\.land)).filter { getCountry(id: $0)?.territoryOf == playerCountryID }
    }
}

// MARK: - A land market

/// A price war, an auction or an offer to sell.
struct LandBid: Codable, Identifiable, Hashable {
    enum Kind: String, Codable { case priceWar, auction, offer }
    var id = UUID()
    var kind: Kind
    var land: String
    /// A historical acquisition this bid is for (Alaska…), else nil.
    var acquisition: String?
    var owner: String
    var rival: String?
    var label: String
    /// What the President offered (price war) or the asking price (offer), $B.
    var price: Double
    /// The rival's bid or an auction's reserve, $B.
    var rivalPrice: Double
    var opened: Date
    var deadline: Date
}

enum LandMarket {
    /// Off under tests and smoke runs unless a test passes rolls (keeps older tests' purchases deterministic).
    nonisolated(unsafe) static var enabled = !GameStoreService.isTestOrSmokeRun

    /// Chance a rival power bids against a purchase: 40% in the imperial age (before 1919), 25% after.
    static func rivalChance(year: Int) -> Double { year < 1919 ? 0.4 : 0.25 }

    /// The rival's bid: 10–40% over the price.
    static func rivalPrice(_ price: Double, roll: Double) -> Double { price * (1.1 + 0.3 * min(max(roll, 0), 1)) }

    /// The President's single raise: 20% over the rival (auctions: 10% over the reserve or rival).
    static func raise(_ b: LandBid) -> Double { b.rivalPrice * (b.kind == .auction ? 1.1 : 1.2) }

    /// Odds the seller takes the President's raise: 0.55 + (relations with the President − with the rival) / 400,
    /// 0.2…0.9; an auction nobody else bids in is won outright.
    static func raiseOdds(playerRelation: Int, rivalRelation: Int, contested: Bool) -> Double {
        contested ? min(0.9, max(0.2, 0.55 + Double(playerRelation - rivalRelation) / 400)) : 1
    }

    /// Why a power would rather be rid of a land (nil = it wants it): unrest, instability, or distance (over 6,000 km).
    static func unwanted(_ land: Country?, owner: Country, coordinates: Coordinates) -> String? {
        if let l = land {
            if l.stability < 35 { return "unstable" }
            if l.profile.outcry > 70 { return "in revolt" }
        }
        return Reach.distanceKm(owner.coordinates, coordinates) > 6000 ? "too far from home" : nil
    }

    /// How long an auction or offer stays open: three months, at least one turn.
    static func deadline(from date: Date, turnLength: TurnLength) -> Date {
        let threeMonths = GameCalendar.calendar.date(byAdding: .month, value: 3, to: date) ?? date
        return max(threeMonths, GameCalendar.advance(date, by: turnLength, turns: 1))
    }
}

extension GameEngine {
    /// A rival power that would bid for `land` against the President: a great or colonial power other than the
    /// seller, not at war with it, that can reach the land, the one friendliest with the seller.
    func rivalBidder(for land: String, owner: String) -> Country? {
        guard let gs = gameState else { return nil }
        let at = gs.getCountry(id: land)?.coordinates ?? WorldCountriesDatabase.template(id: land).map { Coordinates(lat: $0.lat, lon: $0.lon) }
        let seller = gs.getCountry(id: owner)
        return WorldPolitics.powers(gs).filter { p in
            guard p.id != owner, p.id != gs.playerCountryID, !p.atWarWith.contains(owner), p.gdp > 0 else { return false }
            guard let at else { return true }
            return Reach.distanceKm(p.coordinates, at) <= Reach.seaRangeKm(p, year: gs.currentYear, coastal: Reach.isCoastal(p.id, in: gs))
                || Reach.shareBorder(p.id, owner, in: gs)
        }.max { (seller?.diplomaticRelations[$0.id] ?? 0, $1.id) < (seller?.diplomaticRelations[$1.id] ?? 0, $0.id) }
    }

    /// Open a price war if a rival turns up (roll < chance). Returns the bid, or nil when nobody bids.
    @discardableResult
    func openPriceWar(land: String, acquisition: String?, owner: String, label: String, price: Double, roll: Double, priceRoll: Double = 0.5) -> LandBid? {
        guard let gs = gameState, roll < LandMarket.rivalChance(year: gs.currentYear),
              let rival = rivalBidder(for: land.isEmpty ? owner : land, owner: owner) else { return nil }
        let bid = LandBid(kind: .priceWar, land: land, acquisition: acquisition, owner: owner, rival: rival.id, label: label, price: price,
                          rivalPrice: LandMarket.rivalPrice(price, roll: priceRoll), opened: gs.currentDate,
                          deadline: GameCalendar.advance(gs.currentDate, by: gs.turnLength, turns: 1))
        gs.shadow.landBids.append(bid)
        gs.shadow.post(String(format: "PRICE WAR: %@ outbids you for %@ at $%.1fB. Raise once to $%.1fB or walk away before the next %@.",
                              rival.name, label, bid.rivalPrice, LandMarket.raise(bid), gs.turnLength.displayName.lowercased()),
                       date: gs.currentDate, severity: 2)
        gs.flash([rival.id, owner], .hostile, "\(rival.name) bids for \(label)")
        logPlayEvent("land_price_war", detail: ["land": land, "acquisition": acquisition ?? "", "owner": owner, "rival": rival.id,
                                                "price_b": PlayHistory.num(price), "rival_b": PlayHistory.num(bid.rivalPrice), "game_date": PlayHistory.day(gs.currentDate)])
        self.gameState = gs
        return bid
    }

    /// The President raises (price war) or bids (auction) once. No action. Returns whether he won the land.
    @discardableResult
    func raiseBid(_ id: UUID, roll: Double? = nil) -> Bool? {
        let roll = roll ?? gameRoll()
        guard let gs = gameState, let k = gs.shadow.landBids.firstIndex(where: { $0.id == id }), let me = gs.getPlayerCountry() else { return nil }
        let b = gs.shadow.landBids[k]
        guard b.kind != .offer else { return nil }
        let rival = b.rival.flatMap { gs.getCountry(id: $0) }
        let seller = gs.getCountry(id: b.owner)
        let odds = LandMarket.raiseOdds(playerRelation: seller?.diplomaticRelations[me.id] ?? 0,
                                        rivalRelation: rival.flatMap { seller?.diplomaticRelations[$0.id] } ?? 0, contested: rival != nil)
        gs.shadow.landBids.remove(at: k)
        let cost = LandMarket.raise(b)
        let won = roll < odds
        if won {
            spendFunds(cost)
            completeSale(b, price: cost)
        } else {
            gs.shadow.post(String(format: "%@ takes %@'s bid for %@ over your $%.1fB.", seller?.name ?? b.owner, rival?.name ?? "a rival", b.label, cost),
                           date: gs.currentDate, severity: 2)
            rivalTakes(b)
        }
        logPlayEvent("land_bid_raised", detail: ["land": b.land, "kind": b.kind.rawValue, "won": won, "price_b": PlayHistory.num(cost),
                                                 "game_date": PlayHistory.day(gs.currentDate)])
        self.gameState = gs
        return won
    }

    /// Walk away from a price war or auction (the rival wins) or decline an offer.
    func walkAway(_ id: UUID) {
        guard let gs = gameState, let k = gs.shadow.landBids.firstIndex(where: { $0.id == id }) else { return }
        let b = gs.shadow.landBids.remove(at: k)
        if b.kind == .offer {
            gs.shadow.post("You decline \(gs.getCountry(id: b.owner)?.name ?? b.owner)'s offer of \(b.label).", date: gs.currentDate)
        } else {
            rivalTakes(b)
        }
        self.gameState = gs
    }

    /// Accept a power's offer to sell (one action): paid from the funds, the land becomes the President's.
    @discardableResult
    func acceptLandOffer(_ id: UUID) -> Bool {
        guard let gs = gameState, gs.actionsRemaining > 0, let k = gs.shadow.landBids.firstIndex(where: { $0.id == id && $0.kind == .offer }) else { return false }
        let b = gs.shadow.landBids.remove(at: k)
        guard colonyTarget(b.land) != nil else {
            gs.shadow.post("\(b.label) is no longer \(gs.getCountry(id: b.owner)?.name ?? b.owner)'s to sell.", date: gs.currentDate, severity: 1)
            self.gameState = gs
            return false
        }
        spendFunds(b.price)
        completeSale(b, price: b.price)
        self.gameState = gs
        completePlayerAction()
        return true
    }

    /// The land changes hands to the President.
    func completeSale(_ b: LandBid, price: Double) {
        guard let gs = gameState else { return }
        if let a = b.acquisition, let acq = PreStateModel.acquisitions.first(where: { $0.id == a }) {
            gs.shadow.acquired.insert(acq.id)
            if acq.land == "VIR", gs.preState("VIR") != nil { annexLand("VIR", troops: 1, stability: 70, outcry: 5) }
            gs.shadow.acquisitionIncome += acq.value
        } else if let col = colonyTarget(b.land) {
            takeColony(b.land, col, troops: 1, stability: 60, outcry: 15)
        }
        gs.shadow.post(String(format: "%@ sells %@ to %@ for $%.1fB.", gs.getCountry(id: b.owner)?.name ?? b.owner, b.label,
                              gs.getPlayerCountry()?.name ?? "you", price), date: gs.currentDate, severity: 2)
        logPlayEvent("land_purchased", detail: ["land": b.land, "acquisition": b.acquisition ?? "", "seller": b.owner, "sold": true,
                                                "price_b": PlayHistory.num(price), "market": b.kind.rawValue, "game_date": PlayHistory.day(gs.currentDate)])
        self.gameState = gs
    }

    /// The rival buys the land (a historical offer is lost for good). With no rival, it stays with its owner.
    func rivalTakes(_ b: LandBid) {
        guard let gs = gameState else { return }
        guard let rivalID = b.rival, let rival = gs.getCountry(id: rivalID) else {
            gs.shadow.post("No buyer for \(b.label); it stays with \(gs.getCountry(id: b.owner)?.name ?? b.owner).", date: gs.currentDate)
            self.gameState = gs
            return
        }
        if let a = b.acquisition {
            gs.shadow.lostOffers.insert(a)
        } else if let col = colonyTarget(b.land) {
            if let i = col.territory {
                if let oi = gs.countries.firstIndex(where: { $0.id == col.owner.id }) { gs.countries[oi].alliances.remove(b.land) }
                gs.countries[i].territoryOf = rival.id
                gs.countries[i].alliances = [rival.id]
            } else if let t = PreStateModel.template(b.land) {
                var c = CombatModel.claim(t, for: rival)
                c.name = gs.preState(b.land)?.era.name ?? c.name
                gs.countries.append(c)
                gs.shadow.claimDates[b.land] = gs.currentDate
            }
        }
        gs.shadow.post(String(format: "%@ buys %@ for $%.1fB.", rival.name, b.label, b.rivalPrice), date: gs.currentDate, severity: 2)
        logPlayEvent("land_sold_to_rival", detail: ["land": b.land, "acquisition": b.acquisition ?? "", "rival": rival.id,
                                                    "price_b": PlayHistory.num(b.rivalPrice), "game_date": PlayHistory.day(gs.currentDate)])
        self.gameState = gs
    }

    /// Each turn: bids past their deadline close (the rival wins an unanswered price war or auction; offers lapse),
    /// and now and then (60% a year) a power puts an unwanted land up for auction or offers it to the President.
    /// `roll` for tests.
    func processLandMarket(roll: Double? = nil) {
        guard let gs = gameState else { return }
        for b in gs.shadow.landBids where b.deadline <= gs.currentDate {
            gs.shadow.landBids.removeAll { $0.id == b.id }
            if b.kind == .offer {
                gs.shadow.post("\(gs.getCountry(id: b.owner)?.name ?? b.owner)'s offer of \(b.label) lapses.", date: gs.currentDate)
            } else {
                rivalTakes(b)
            }
        }
        guard LandMarket.enabled || roll != nil else { self.gameState = gs; return }
        let r = roll ?? Double.random(in: 0..<1, using: &gs.rng)
        if r < gs.scale.probability(annual: 0.6), gs.shadow.landBids.count < 3 { openMarketListing(roll: r) }
        self.gameState = gs
    }

    /// Lands computer-run powers would sell: their territories and colonies that are unstable, in revolt or far away.
    func unwantedLands() -> [(land: String, owner: Country, label: String, why: String)] {
        guard let gs = gameState else { return [] }
        let listed = Set(gs.shadow.landBids.map(\.land))
        var out: [(String, Country, String, String)] = []
        let candidates = gs.colonyLandIDs.union(gs.countries.filter { $0.territoryOf != nil && $0.territoryOf != gs.playerCountryID && !$0.isDestroyed }.map(\.id))
        for land in candidates.sorted() where !listed.contains(land) {
            guard let col = colonyTarget(land), col.owner.id != gs.playerCountryID else { continue }
            let here = col.territory.map { gs.countries[$0] }
            let at = here?.coordinates ?? WorldCountriesDatabase.template(id: land).map { Coordinates(lat: $0.lat, lon: $0.lon) } ?? col.owner.coordinates
            if let why = LandMarket.unwanted(here, owner: col.owner, coordinates: at) { out.append((land, col.owner, col.label, why)) }
        }
        return out
    }

    /// Put one unwanted land on the market: an auction (a rival may bid) or an offer to the President.
    @discardableResult
    func openMarketListing(roll: Double) -> LandBid? {
        guard let gs = gameState else { return nil }
        let lands = unwantedLands()
        guard !lands.isEmpty else { return nil }
        let pick = lands[Int(roll * 7919) % lands.count]
        let rel = pick.owner.diplomaticRelations[gs.playerCountryID] ?? 0
        let base = PreStateModel.price(pick.land, year: gs.currentYear, relation: rel)
        let auction = Int(roll * 104_729) % 2 == 0
        let rival = auction ? rivalBidder(for: pick.land, owner: pick.owner.id) : nil
        let bid = LandBid(kind: auction ? .auction : .offer, land: pick.land, acquisition: nil, owner: pick.owner.id, rival: rival?.id,
                          label: pick.label, price: base * (auction ? 0.8 : 0.7), rivalPrice: base * 0.8, opened: gs.currentDate,
                          deadline: LandMarket.deadline(from: gs.currentDate, turnLength: gs.turnLength))
        gs.shadow.landBids.append(bid)
        let close = GameCalendar.format(bid.deadline)
        gs.shadow.post(auction
                       ? String(format: "AUCTION: %@ puts %@ (%@) up for sale, reserve $%.1fB. Bids close %@.", pick.owner.name, pick.label, pick.why, bid.rivalPrice, close)
                       : String(format: "%@ offers to sell you %@ (%@) for $%.1fB, until %@.", pick.owner.name, pick.label, pick.why, bid.price, close),
                       date: gs.currentDate, severity: 2)
        logPlayEvent(auction ? "land_auction" : "land_offer", detail: ["land": pick.land, "owner": pick.owner.id, "why": pick.why,
                                                                       "price_b": PlayHistory.num(bid.price), "game_date": PlayHistory.day(gs.currentDate)])
        self.gameState = gs
        return bid
    }
}
