//
//  Release329Tests.swift
//  GTNWTests
//
//  3.29.0 in all seven categories: land that pays, empire victories, claim campaigns, the President's names on the
//  map, the land market, theocracies of any faith, attacks only where physically possible, the real-world brief, and
//  wars of attrition.
//

import XCTest
import SwiftUI
@testable import GTNW

enum R329 {
    @MainActor
    static func game(_ year: Int? = nil, player: String = "USA") throws -> (GameEngine, GameState) {
        let e = GameEngine()
        e.startNewGame(playerCountryID: player, year: year)
        return (e, try XCTUnwrap(e.gameState))
    }

    static let brief = """
    {"generated":"2026-11-15T06:00:00Z","window_days":7,"items":120,
     "countries":{"RUS":{"military":95,"cyber":80,"mentions":400,"headline":"Front lines shift near Pokrovsk"},
                  "UKR":{"military":90,"cyber":40,"mentions":380,"headline":"Kyiv asks for more air defence"},
                  "PRK":{"military":40,"cyber":75,"mentions":30,"headline":"Crypto theft attributed to Lazarus"}},
     "pairs":[{"a":"RUS","b":"UKR","kind":"war","weight":100,"headline":"Russia–Ukraine war, ongoing since 2022"},
              {"a":"CHN","b":"TWN","kind":"tension","weight":60,"headline":"PLA drills around Taiwan"},
              {"a":"PRK","b":"USA","kind":"cyber","weight":70,"headline":"Hackers hit U.S. exchanges"}]}
    """

    /// The front between two countries, if it is still fighting.
    @MainActor
    static func fighting(_ gs: GameState, _ a: String, _ d: String) -> Bool {
        gs.shadow.fronts.contains { $0.attacker == a && $0.defender == d && $0.status == .fighting }
    }

    /// Run `months` monthly turns of combat only.
    @MainActor
    static func fight(_ e: GameEngine, _ gs: GameState, months: Int) {
        for _ in 0..<months {
            gs.turn += 1
            e.processCombat(from: gs.previousTurnDate, to: gs.currentDate)
        }
    }
}

struct FixtureBrief: WorldBriefProvider {
    let json: String
    func latestBrief() async -> (day: String?, json: Data)? { ("2026-11-15", Data(json.utf8)) }
}

// MARK: - Unit

final class Release329UnitTests: XCTestCase {
    /// Unit: land points come from the Factbook and its era (oil only from 1900); development adds up to 50%.
    func testLandPointsFollowTheFactbookAndTheEra() {
        XCTAssertGreaterThan(ExpansionModel.landPoints("SAU", year: 2025), ExpansionModel.landPoints("SAU", year: 1850))
        XCTAssertTrue(ExpansionModel.landResources("SAU", year: 2025).contains(.oil))
        XCTAssertFalse(ExpansionModel.landResources("SAU", year: 1850).contains(.oil))
        XCTAssertEqual(ExpansionModel.landPoints("NOPE", year: 2025), 0.75)
        for id in ["SAU", "USA", "RUS", "AUS", "CHN"] { XCTAssertLessThanOrEqual(ExpansionModel.landPoints(id, year: 2025), 10) }
        XCTAssertEqual(ExpansionModel.maturity(yearsHeld: 0), 1)
        XCTAssertEqual(ExpansionModel.maturity(yearsHeld: 10), 1.5)
        XCTAssertEqual(ExpansionModel.maturity(yearsHeld: 50), 1.5)
    }

    /// Unit: every faith has a founding year and a name that renders; Wicca can't appear before 1954.
    func testEveryFaithHasAFromYearAndAName() {
        XCTAssertGreaterThanOrEqual(Faith.allCases.count, 55)
        for f in Faith.allCases {
            XCTAssertTrue((-6000...2000).contains(f.from), "\(f) from \(f.from)")
            let name = f.stateName("Cuba")
            XCTAssertTrue(name.hasSuffix("of Cuba") && name.count > 10, name)
            XCTAssertFalse(f.proclamation(of: "Cuba").isEmpty)
        }
        XCTAssertEqual(Faith.latterDaySaint.stateName("Cuba"), "Latter-day Saint Theocracy of Cuba")
        XCTAssertEqual(Faith.vodou.stateName("Haiti"), "Vodou Republic of Haiti")
        XCTAssertEqual(Faith.shia.stateName("Iran"), "Islamic Republic of Iran")
        XCTAssertEqual(Faith.latterDaySaint.from, 1830)
        XCTAssertEqual(Faith.wicca.from, 1954)
        XCTAssertEqual(Faith.scientology.from, 1954)
        XCTAssertFalse(Faith.available(year: 1953).contains(.wicca))
        for i in 0..<1000 { XCTAssertNotEqual(Faith.pick(for: "GBR", year: 1953, roll: Double(i) / 1000), .wicca) }
    }

    /// Unit: Cuba in 2025 can turn Latter-day Saint (seeded), with only a mild lean toward its Catholic tradition.
    func testCubaCanRollLatterDaySaint() {
        var rng = GameRNG(seed: 2025)
        var counts: [Faith: Int] = [:]
        for _ in 0..<4000 { counts[Faith.pick(for: "CUB", year: 2025, roll: Double.random(in: 0..<1, using: &rng)), default: 0] += 1 }
        XCTAssertGreaterThan(counts[.latterDaySaint] ?? 0, 0)
        XCTAssertGreaterThan(counts.count, 50, "any faith can come up")
        let own = Faith.from(WorldFactbookDatabase.record(for: "CUB").dominantReligion)
        if let own { XCTAssertLessThan(counts[own] ?? 0, 1000, "the lean toward the country's own faith is mild") }
    }

    /// Unit: reach: Afghanistan can't strike Paraguay (1950, 2025); France and Germany share a border.
    @MainActor
    func testReachRules() throws {
        for year in [1950, 2025] {
            let (_, gs) = try R329.game(year)
            XCTAssertFalse(Reach.canReach("AFG", "PRY", in: gs), "\(year)")
        }
        let (_, gs) = try R329.game(2025)
        XCTAssertTrue(Reach.shareBorder("FRA", "DEU", in: gs))
        XCTAssertEqual(Reach.how("FRA", "DEU", in: gs), .land)
        XCTAssertFalse(Reach.shareBorder("AFG", "PRY", in: gs))
    }

    /// Unit: brief numbers are clamped, kinds checked and headlines cut to 140 characters.
    func testBriefParsing() throws {
        let b = try XCTUnwrap(WorldBriefModel.parse(Data(R329.brief.utf8), day: nil, valid: ["RUS", "UKR", "PRK", "USA", "CHN", "TWN"]))
        XCTAssertEqual(b.day, "2026-11-15")
        XCTAssertEqual(b.pairs.count, 3)
        XCTAssertEqual(b.topPairs.first?.a, "RUS")
        XCTAssertEqual(b.military["RUS"], 95)
        XCTAssertEqual(WorldBriefModel.relationHit(b.pairs[0]), 60)
        XCTAssertEqual(WorldBriefModel.sanitize(String(repeating: "x", count: 500)).count, 140)
    }
}

// MARK: - Functional

final class Release329FunctionalTests: XCTestCase {
    /// Functional: a claim campaign takes one action, then plants flags turn after turn until done.
    @MainActor
    func testClaimCampaignPlantsFlags() throws {
        let (e, gs) = try R329.game(1800)
        gs.turnLength = .month
        let targets = gs.campaignTargets(.emptyIslands)
        XCTAssertFalse(targets.isEmpty)
        let actions = gs.actionsRemaining
        XCTAssertTrue(e.launchClaimCampaign(.emptyIslands, name: "Empty Islands"))
        XCTAssertEqual(gs.actionsRemaining, actions - 1)
        XCTAssertFalse(e.launchClaimCampaign(.emptyIslands, name: "Again"), "one campaign at a time")
        for _ in 0..<targets.count { e.processClaimCampaign(roll: 0) }
        XCTAssertNil(gs.shadow.claimCampaign, "done")
        let planted = targets.filter { gs.getCountry(id: $0)?.territoryOf == "USA" }
        XCTAssertGreaterThan(planted.count, 0)
        XCTAssertTrue(gs.shadow.ticker.contains { $0.text.contains("complete") || $0.text.contains("halts") })
    }

    /// Functional: renames are recorded (original → new), labelled on the map, and the news uses the current name.
    @MainActor
    func testRenamesAreRecordedAndUsedInTheNews() throws {
        let (e, gs) = try R329.game(1900)
        let original = try XCTUnwrap(gs.getCountry(id: "MID")?.name)
        XCTAssertTrue(e.renameTerritory("MID", to: "New Albion"))
        XCTAssertTrue(e.renameTerritory("MID", to: "Port Liberty"))
        let entry = try XCTUnwrap(gs.nameBook.first { $0.land == "MID" })
        XCTAssertEqual(entry.original, original)
        XCTAssertEqual(entry.current, "Port Liberty")
        XCTAssertTrue(gs.namedLands.contains("MID"))
        e.declareWar(aggressor: "GBR", defender: "MID")
        XCTAssertTrue(gs.mapFlashes.last?.text.contains("Port Liberty") ?? false)
    }

    /// Functional: a theocracy proclaimed in Cuba gets a faith, a styled name and a government line.
    @MainActor
    func testProclaimTheocracyOfAnyFaith() throws {
        let (e, gs) = try R329.game(2025)
        let i = try XCTUnwrap(gs.countries.firstIndex { $0.id == "CUB" })
        let lds = (0..<1000).map { Double($0) / 1000 }.first { Faith.pick(for: "CUB", year: 2025, roll: $0) == .latterDaySaint }
        let f = e.proclaimTheocracy(i, roll: try XCTUnwrap(lds))
        XCTAssertEqual(f, .latterDaySaint)
        let cuba = try XCTUnwrap(gs.getCountry(id: "CUB"))
        XCTAssertEqual(cuba.government, .theocracy)
        XCTAssertEqual(cuba.stateFaith, .latterDaySaint)
        XCTAssertTrue(cuba.governmentLine.contains("Latter-day Saint"))
        XCTAssertEqual(FaithNames.styled("Islamic Republic of Cuba", faith: .vodou), "Vodou Republic of Cuba")
    }

    /// Functional: Manifest Destiny / The Sun Never Sets / Every Rock: progress and the victory, never for goals met at
    /// the start.
    @MainActor
    func testEmpireVictories() throws {
        let (_, gs) = try R329.game(2025)
        XCTAssertEqual(EmpireModel.progress(.everyRock, gs).total, Islands.all.count)
        XCTAssertGreaterThanOrEqual(EmpireModel.progress(.manifestDestiny, gs).total, 3)
        XCTAssertNil(EmpireModel.victory(gs))
        gs.shadow.empireAtStart = []
        for r in WorldRegion.allCases where !EmpireModel.regionsHeld(gs).contains(r) {
            if let i = gs.countries.firstIndex(where: { $0.region == r && $0.id != "USA" && !$0.isDestroyed }) { gs.countries[i].territoryOf = "USA" }
        }
        XCTAssertTrue(EmpireModel.isMet(.sunNeverSets, gs))
        XCTAssertEqual(EmpireModel.victory(gs), .sunNeverSets)
        gs.shadow.empireAtStart = [EmpireGoal.sunNeverSets.rawValue]
        XCTAssertNotEqual(EmpireModel.victory(gs), .sunNeverSets, "held at the start doesn't count")
        XCTAssertEqual(VictoryType.sunNeverSets.baseScore, 1200)
    }
}

// MARK: - Integration

final class Release329IntegrationTests: XCTestCase {
    /// Integration (item 9): in a 2025 start, a Russia–Ukraine war is still running after 24 monthly turns in a large
    /// majority of 20 seeds.
    @MainActor
    func testRussiaUkraineIsAWarOfAttrition() throws {
        let (e, gs) = try R329.game(2025)
        gs.turnLength = .month
        let countries = gs.countries, wars = gs.activeWars, fronts = gs.shadow.fronts, turn = gs.turn
        var running = 0
        for seed in 1...20 {
            gs.countries = countries; gs.activeWars = wars; gs.shadow.fronts = fronts; gs.turn = turn
            gs.rng = GameRNG(seed: UInt64(seed))
            e.declareWar(aggressor: "RUS", defender: "UKR")
            e.syncFronts()
            XCTAssertTrue(R329.fighting(gs, "RUS", "UKR"))
            R329.fight(e, gs, months: 24)
            if R329.fighting(gs, "RUS", "UKR") { running += 1 }
        }
        XCTAssertGreaterThanOrEqual(running, 16, "still fighting in \(running)/20")
    }

    /// Integration (item 9): a great power still beats a micro-state quickly.
    @MainActor
    func testGreatPowerBeatsAMicroStateQuickly() throws {
        let (e, gs) = try R329.game(2025)
        gs.turnLength = .month
        let micro = try XCTUnwrap(["MCO", "AND", "LIE", "SMR", "LUX"].first { gs.getCountry(id: $0) != nil })
        let a = try XCTUnwrap(gs.getCountry(id: "FRA")), d = try XCTUnwrap(gs.getCountry(id: micro))
        XCTAssertTrue(AttritionModel.isMismatch(attacker: a, defender: d))
        e.declareWar(aggressor: "FRA", defender: micro)
        e.syncFronts()
        R329.fight(e, gs, months: 6)
        XCTAssertFalse(R329.fighting(gs, "FRA", micro), "over within six months")
    }

    /// Integration: a fixture brief applied on turn 1 sours relations along its pairs and adds the WORLD BRIEF line;
    /// cyber crises are pinned on the real actors.
    @MainActor
    func testWorldBriefApplies() throws {
        let (e, gs) = try R329.game(2025)
        let before = gs.getCountry(id: "RUS")?.diplomaticRelations["UKR"] ?? 0
        XCTAssertTrue(e.applyWorldBrief(Data(R329.brief.utf8), day: "2026-11-15"))
        XCTAssertLessThan(gs.getCountry(id: "RUS")?.diplomaticRelations["UKR"] ?? 0, before)
        XCTAssertTrue(gs.shadow.ticker.contains { $0.text.hasPrefix("WORLD BRIEF 2026-11-15") })
        XCTAssertEqual(WorldBriefModel.cyberActor(gs), "PRK")
        e.processWorldBrief(roll: 0)
        XCTAssertTrue(gs.shadow.ticker.contains { $0.text.hasPrefix("💻 CYBER:") })
        XCTAssertFalse(e.applyWorldBrief(Data(R329.brief.utf8), day: "2026-11-15"), "applied once")
    }

    /// Integration: the injected provider is fetched in the background for a modern start, never for 1950.
    @MainActor
    func testWorldBriefProviderInjection() async throws {
        let (e, gs) = try R329.game(2025)
        e.requestWorldBrief(provider: FixtureBrief(json: R329.brief), timeout: 2)
        for _ in 0..<40 where gs.shadow.worldBrief == nil { try await Task.sleep(nanoseconds: 50_000_000) }
        XCTAssertEqual(gs.shadow.worldBrief?.day, "2026-11-15")
        let (old, ogs) = try R329.game(1950)
        old.requestWorldBrief(provider: FixtureBrief(json: R329.brief), timeout: 2)
        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertNil(ogs.shadow.worldBrief)
    }

    /// Integration: a rival outbids the President for a colony; he raises once and wins, or walks away and the rival
    /// buys it. A lost historical offer is gone for good.
    @MainActor
    func testPriceWarsAndAuctions() throws {
        func game() throws -> (GameEngine, GameState) {
            let (e, gs) = try R329.game(2025)
            let gbr = try XCTUnwrap(gs.getCountry(id: "GBR"))
            let i = try XCTUnwrap(gs.countries.firstIndex { $0.id == "IRL" })
            CombatModel.annex(&gs.countries[i], to: gbr)
            return (e, gs)
        }
        var (e, gs) = try game()
        XCTAssertEqual(e.purchaseColony("IRL", roll: 0, rivalRoll: 0), false)
        let bid = try XCTUnwrap(gs.shadow.landBids.first)
        XCTAssertEqual(bid.kind, .priceWar)
        XCTAssertEqual(e.raiseBid(bid.id, roll: 0), true)
        XCTAssertEqual(gs.getCountry(id: "IRL")?.territoryOf, "USA")
        (e, gs) = try game()
        _ = e.purchaseColony("IRL", roll: 0, rivalRoll: 0)
        let b2 = try XCTUnwrap(gs.shadow.landBids.first)
        e.walkAway(b2.id)
        XCTAssertEqual(gs.getCountry(id: "IRL")?.territoryOf, b2.rival)
        // Auctions and offers of unwanted lands
        (e, gs) = try game()
        if let i = gs.countries.firstIndex(where: { $0.id == "IRL" }) { gs.countries[i].stability = 10 }
        XCTAssertTrue(e.unwantedLands().contains { $0.land == "IRL" })
        let listing = try XCTUnwrap(e.openMarketListing(roll: 0.5))
        XCTAssertTrue([.auction, .offer].contains(listing.kind))
        XCTAssertTrue(gs.shadow.ticker.contains { $0.text.contains("AUCTION") || $0.text.contains("offers to sell") })
        // A historical acquisition lost to a rival
        let (h, hs) = try R329.game(1867)
        XCTAssertNotNil(h.openAcquisitions().first { $0.id == "alaska" })
        XCTAssertFalse(h.acceptAcquisition("alaska", rivalRoll: 0))
        let ab = try XCTUnwrap(hs.shadow.landBids.first { $0.acquisition == "alaska" })
        h.walkAway(ab.id)
        XCTAssertTrue(hs.shadow.lostOffers.contains("alaska"))
        XCTAssertNil(h.openAcquisitions().first { $0.id == "alaska" })
    }

    /// Integration: territory income includes the land's own yield.
    @MainActor
    func testLandPaysIntoTerritoryIncome() throws {
        let (_, gs) = try R329.game(2025)
        let usa = try XCTUnwrap(gs.getCountry(id: "USA"))
        let i = try XCTUnwrap(gs.countries.firstIndex { $0.id == "SAU" })
        CombatModel.annex(&gs.countries[i], to: usa)
        let sau = gs.countries[i]
        let y = ExpansionModel.landYield(sau, in: gs)
        XCTAssertGreaterThan(y, 0)
        XCTAssertLessThan(y, usa.gdp * 1000 * 0.005, "meaningful but never runaway: under 0.5% of the owner's output")
    }
}

// MARK: - Security

final class Release329SecurityTests: XCTestCase {
    /// Security: a hostile brief: unknown ids, lower-case and injected ids, control characters, booleans, NaN-ish and
    /// huge numbers, endless pairs and oversized payloads are all dropped or clamped.
    func testHostileBriefIsSanitized() throws {
        var pairs: [[String: Any]] = (0..<500).map { _ in ["a": "RUS", "b": "UKR", "kind": "war", "weight": 1e9, "headline": "x"] }
        pairs.insert(["a": "rus", "b": "UKR", "kind": "war", "weight": 50], at: 0)
        pairs.insert(["a": "RUS'; DROP", "b": "UKR", "kind": "war", "weight": 50], at: 0)
        pairs.insert(["a": "XXX", "b": "UKR", "kind": "war", "weight": 50], at: 0)
        pairs.insert(["a": "RUS", "b": "UKR", "kind": "nuke", "weight": 50], at: 0)
        pairs.insert(["a": "RUS", "b": "UKR", "kind": "war", "weight": true], at: 0)
        pairs.insert(["a": "RUS", "b": "RUS", "kind": "war", "weight": 50], at: 0)
        let json: [String: Any] = [
            "generated": "2026-11-15\u{0007}\u{001B}[31m",
            "countries": ["RUS": ["military": -5, "cyber": 400, "headline": "Line\u{0000}one\n\t\u{202E}" + String(repeating: "y", count: 900)],
                          "ZZZ": ["military": 50]],
            "pairs": pairs,
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let b = try XCTUnwrap(WorldBriefModel.parse(data, day: nil, valid: ["RUS", "UKR"]))
        XCTAssertEqual(b.pairs.count, WorldBriefModel.maxPairs)
        XCTAssertTrue(b.pairs.allSatisfy { $0.a == "RUS" && $0.b == "UKR" && $0.kind == "war" && $0.weight == 100 })
        XCTAssertEqual(b.military["RUS"], 0)
        XCTAssertEqual(b.cyber["RUS"], 100)
        XCTAssertNil(b.military["ZZZ"])
        let h = try XCTUnwrap(b.headlines["RUS"])
        XCTAssertLessThanOrEqual(h.count, 140)
        XCTAssertFalse(h.unicodeScalars.contains { CharacterSet.controlCharacters.contains($0) })
        XCTAssertFalse(b.day.unicodeScalars.contains { CharacterSet.controlCharacters.contains($0) })
        XCTAssertNil(WorldBriefModel.parse(Data(count: WorldBriefModel.maxBytes + 1), day: nil, valid: ["RUS"]))
        XCTAssertNil(WorldBriefModel.parse(Data("[1,2]".utf8), day: nil, valid: ["RUS"]))
        XCTAssertNil(GameEngine.worldBriefProvider, "no Games DB under tests")
        XCTAssertFalse(LandMarket.enabled, "no random rival bids under tests")
    }

    /// Security: a landlocked minor can't blockade; nobody attacks what it can't reach; the U.S. reaches anything.
    @MainActor
    func testAttacksOnlyWherePhysicallyPossible() throws {
        let (e, gs) = try R329.game(2025)
        XCTAssertFalse(Reach.canBlockade("AFG", "PAK", in: gs))
        for c in gs.countries where !c.isDestroyed && c.id != "USA" { XCTAssertTrue(Reach.canReach("USA", c.id, in: gs), c.id) }
        let afg = try XCTUnwrap(gs.getCountry(id: "AFG"))
        switch Reach.fallback(for: afg, against: "PRY") {
        case .attack: XCTFail("an unreachable target is never attacked")
        default: break
        }
        let wars = gs.activeWars.count
        if case .success = e.validateMove(MoveResponse(action: "DECLARE_WAR", target: "PRY"), for: "AFG") {
            XCTFail("Afghanistan can't declare war on Paraguay")
        }
        XCTAssertEqual(gs.activeWars.count, wars)
    }

    /// Security: campaign names are cleaned; custom selections keep only claimable lands, once each.
    @MainActor
    func testCampaignInputIsChecked() throws {
        let (e, gs) = try R329.game(1800)
        let land = try XCTUnwrap(gs.campaignTargets(.emptyIslands).first)
        XCTAssertEqual(gs.campaignTargets(.custom([land, land, "USA", "NOPE", "'; DROP"])), [land])
        XCTAssertTrue(e.launchClaimCampaign(.custom([land]), name: "Evil\u{0000}\u{001B}name " + String(repeating: "z", count: 200)))
        let name = try XCTUnwrap(gs.shadow.claimCampaign?.name)
        XCTAssertLessThanOrEqual(name.count, 60)
        XCTAssertFalse(name.unicodeScalars.contains { CharacterSet.controlCharacters.contains($0) })
        XCTAssertFalse(e.launchClaimCampaign(.custom(["NOPE"]), name: "x"))
    }
}

// MARK: - Retry

final class Release329RetryTests: XCTestCase {
    /// Retry: a save from before 3.29.0 (no renames, campaign, bids, brief, empire baseline, faith) still loads.
    @MainActor
    func testOldSavesLoad() throws {
        let (_, gs) = try R329.game(2025)
        gs.shadow.renames = [RenameRecord(land: "MID", from: "Midway", to: "X", date: gs.currentDate)]
        var obj = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(gs.shadow)) as? [String: Any])
        for k in ["renames", "claimCampaign", "landBids", "lostOffers", "empireAtStart", "worldBrief"] { obj[k] = nil }
        let old = try JSONDecoder().decode(ShadowState.self, from: JSONSerialization.data(withJSONObject: obj))
        XCTAssertTrue(old.renames.isEmpty)
        XCTAssertNil(old.claimCampaign)
        XCTAssertNil(old.empireAtStart)
        XCTAssertNil(old.worldBrief)
        let iran = try XCTUnwrap(gs.getCountry(id: "IRN"))
        var c = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(iran)) as? [String: Any])
        c["faith"] = nil
        let loaded = try JSONDecoder().decode(Country.self, from: JSONSerialization.data(withJSONObject: c))
        XCTAssertNil(loaded.faith)
        if loaded.government == .theocracy { XCTAssertEqual(loaded.stateFaith, .shia) }
        let round = try JSONDecoder().decode(ShadowState.self, from: JSONEncoder().encode(gs.shadow))
        XCTAssertEqual(round.renames.first?.to, "X")
    }

    /// Retry: a campaign skips lands someone else took meanwhile, and a cancelled campaign can be relaunched.
    @MainActor
    func testCampaignSkipsTakenLandsAndRelaunches() throws {
        let (e, gs) = try R329.game(1800)
        let lands = Array(gs.campaignTargets(.emptyIslands).prefix(2))
        XCTAssertEqual(lands.count, 2)
        XCTAssertTrue(e.launchClaimCampaign(.custom(lands), name: "Two"))
        e.cancelClaimCampaign()
        XCTAssertNil(gs.shadow.claimCampaign)
        gs.actionsUsedThisTurn = 0
        XCTAssertTrue(e.launchClaimCampaign(.custom(lands), name: "Two again"))
        gs.shadow.claimCampaign?.queue.insert("NOPE", at: 0)
        e.processClaimCampaign(roll: 0)
        XCTAssertFalse(gs.shadow.claimCampaign?.failed.contains("NOPE") ?? false, "not claimable: skipped, not a failed landing")
    }

    /// Retry: an unanswered price war closes at its deadline (the rival wins) without an action.
    @MainActor
    func testUnansweredBidsClose() throws {
        let (e, gs) = try R329.game(2025)
        let i = try XCTUnwrap(gs.countries.firstIndex { $0.id == "IRL" })
        CombatModel.annex(&gs.countries[i], to: try XCTUnwrap(gs.getCountry(id: "GBR")))
        _ = e.purchaseColony("IRL", roll: 0, rivalRoll: 0)
        XCTAssertEqual(gs.shadow.landBids.count, 1)
        gs.turn += 2
        e.processLandMarket()
        XCTAssertTrue(gs.shadow.landBids.isEmpty)
        XCTAssertNotEqual(gs.getCountry(id: "IRL")?.territoryOf, "USA")
    }
}

// MARK: - Performance

final class Release329PerformanceTests: XCTestCase {
    /// Performance: reach checks are cheap enough for every AI move.
    @MainActor
    func testReachIsCheap() throws {
        let (_, gs) = try R329.game(2025)
        let ids = gs.countries.prefix(40).map(\.id)
        _ = Reach.canReach("RUS", "UKR", in: gs)
        measure { for a in ids.prefix(10) { for b in ids { _ = Reach.canReach(a, b, in: gs) } } }
    }

    /// Performance: the resources ledger with land yields and the empire progress.
    @MainActor
    func testLedgerAndEmpireProgress() throws {
        let (_, gs) = try R329.game(1900)
        measure {
            _ = ExpansionModel.ledger(gs)
            for g in EmpireGoal.allCases { _ = EmpireModel.progress(g, gs) }
            _ = gs.nameBook
        }
    }
}

// MARK: - Frame

#if os(macOS)
final class Release329FrameTests: XCTestCase {
    @MainActor
    private func renders<V: View>(_ v: V, _ what: String) {
        defer { Theme.forced = nil }
        for theme in GameTheme.allCases {
            Theme.forced = theme
            let r = ImageRenderer(content: v)
            r.scale = 1
            XCTAssertNotNil(r.cgImage, "\(what) failed to render in \(theme)")
        }
    }

    /// Frame: the Records sheet (Names and Empire tabs), the land market and the campaign list render.
    @MainActor
    func testNewSheetsRender() throws {
        let (e, gs) = try R329.game(1900)
        _ = e.renameTerritory("MID", to: "Port Liberty")
        for tab in RecordsSheet.Tab.allCases {
            renders(RecordsSheet(gameState: gs, hall: [:], tab: tab), "records \(tab)")
        }
        renders(AcquisitionSheet(gameState: gs).environmentObject(e), "market")
        let (e2, early) = try R329.game(1800)
        renders(UnclaimedLandsSheet(gameState: early, engine: e2) { _ in }.frame(width: 560, height: 600), "unclaimed")
        XCTAssertTrue(e2.launchClaimCampaign(.emptyIslands, name: "Empty Islands"))
        renders(UnclaimedLandsSheet(gameState: early, engine: e2) { _ in }.frame(width: 560, height: 600), "campaign")
    }

    /// Frame: the map draws the President's names and the Situation Room the WORLD BRIEF line.
    @MainActor
    func testMapNamesAndBriefLine() throws {
        let (e, gs) = try R329.game(2025)
        let i = try XCTUnwrap(gs.countries.firstIndex { $0.id == "ISL" })
        CombatModel.annex(&gs.countries[i], to: try XCTUnwrap(gs.getCountry(id: "USA")))
        XCTAssertTrue(e.renameTerritory("ISL", to: "Red, White and Blue Land"))
        XCTAssertTrue(gs.namedLands.contains("ISL"))
        renders(VectorWorldMap(gameState: gs, selectedCountryID: .constant(nil), zoom: .constant(.world), filter: .constant(.alignment))
            .frame(width: 1000, height: 500), "map")
        XCTAssertTrue(e.applyWorldBrief(Data(R329.brief.utf8), day: "2026-11-15"))
        let line = WorldBriefModel.line(try XCTUnwrap(gs.shadow.worldBrief), in: gs)
        XCTAssertTrue(line.contains("Russia") && line.contains("(war)"))
    }
}
#endif
