//
//  WorldWatchTests.swift
//  GTNWTests
//
//  3.20.0: epigraphs (Quotations), world emergencies (EmergencyCatalog), the world watch that turns new wars and
//  changes of power into decisions, and the crisis queue.
//  Created by Jordan Koch.
//

import XCTest
@testable import GTNW

final class QuotationTests: XCTestCase {
    func testEveryShelfIsStockedAndClean() {
        for kind in QuoteKind.allCases {
            XCTAssertGreaterThanOrEqual(Quotations.all.filter { $0.kind == kind }.count, 20, "\(kind) shelf too thin")
        }
        for q in Quotations.all {
            XCTAssertFalse(q.text.isEmpty); XCTAssertFalse(q.source.isEmpty); XCTAssertFalse(q.tags.isEmpty, q.text)
            XCTAssertFalse(q.text.hasPrefix("“"), "quote marks are added by the view: \(q.text)")
        }
        XCTAssertEqual(Set(Quotations.all.map(\.text)).count, Quotations.all.count, "duplicate quote")
    }

    func testPickIsStableAndMatchesTheSubject() {
        let a = Quotations.pick([.disaster, .mercy], seed: "seed-1")
        XCTAssertEqual(a, Quotations.pick([.disaster, .mercy], seed: "seed-1"))
        for kind in QuoteKind.allCases {
            XCTAssertFalse(Quotations.pick([.disaster, .mercy], seed: "x", kind: kind).tags.isDisjoint(with: [.disaster, .mercy]))
        }
        XCTAssertEqual(Set(Quotations.triad([.war], seed: "s").map(\.kind)), Set(QuoteKind.allCases))
        XCTAssertEqual(Quotations.stableHash("abc"), Quotations.stableHash("abc"))
    }

    func testEveryCrisisTypeGetsAnOnTopicQuoteFromEveryShelf() {
        for type in CrisisEventType.allCases {
            for kind in QuoteKind.allCases {
                let q = Quotations.pick(type.quoteTags, seed: type.rawValue, kind: kind)
                XCTAssertFalse(q.tags.isDisjoint(with: type.quoteTags), "\(type) / \(kind) got an off-topic line")
            }
        }
    }

    func testEveryScenarioHasAnEpigraph() {
        for s in ScenarioDefinition.all {
            XCTAssertNotNil(ScenarioDefinition.epigraphTags[s.id], "\(s.id) has no epigraph subject")
            XCTAssertFalse(s.epigraph.text.isEmpty)
        }
    }
}

final class EmergencyCatalogTests: XCTestCase {
    func testCatalogCoversTheWorldsEmergencies() {
        let all = EmergencyCatalog.all
        XCTAssertGreaterThanOrEqual(all.count, 45)
        XCTAssertEqual(Set(all.map(\.kind)).count, all.count, "duplicate emergency kind")
        for e in all {
            XCTAssertFalse(e.responses.isEmpty, e.kind)
            XCTAssertTrue(e.headline.contains("{C}"), e.kind)
            for h in e.hotspots { XCTAssertTrue(h.count == 3 && h == h.uppercased(), "\(e.kind): bad id \(h)") }
        }
        for kind in ["Hurricane", "Earthquake", "Tsunami", "Volcano", "Floods", "Wildfires", "Famine", "Cholera", "Coup", "Cyberattack"] {
            XCTAssertTrue(all.contains { $0.kind == kind }, "missing \(kind)")
        }
    }

    func testHurricanesCanHitCubaWithAnAidDecision() throws {
        let gs = GameState(playerCountryID: "USA")
        let cuba = try XCTUnwrap(gs.getCountry(id: "CUB"))
        let hurricane = try XCTUnwrap(EmergencyCatalog.all.first { $0.kind == "Hurricane" })
        let c = WorldWatch.emergencyCrisis(hurricane, in: cuba, gs: gs)
        XCTAssertEqual(c.type, .worldDisaster)
        XCTAssertTrue(c.title.contains("CUBA"))
        XCTAssertTrue(c.options.contains { $0.title.lowercased().contains("relief") })
        XCTAssertTrue(c.options.count >= 3)
        XCTAssertFalse(c.epigraph.tags.isDisjoint(with: [.disaster, .mercy, .fear]))
    }

    func testDisastersStrikeOtherNationsOfTheEra() {
        let gs = GameState(playerCountryID: "USA")
        for _ in 0..<200 {
            guard let c = WorldWatch.disasterCrisis(gameState: gs) else { return XCTFail("no emergency produced") }
            XCTAssertNotEqual(c.affectedCountries.first, gs.playerCountryID)
            XCTAssertNotNil(gs.liveCountries.first { $0.id == c.affectedCountries.first })
        }
    }

    func testModernEmergenciesWaitForTheirEra() throws {
        let e = GameEngine()
        e.startNewGame(turnLength: .month, year: 1861)
        let gs = try XCTUnwrap(e.gameState)
        for _ in 0..<300 {
            guard let c = WorldWatch.disasterCrisis(gameState: gs) else { continue }
            XCTAssertFalse(c.title.contains("CYBERATTACK") || c.title.contains("IT MELTDOWN") || c.title.contains("NUCLEAR PLANT"), c.title)
        }
    }

    func testAidCostsMoneyAndWinsFriends() throws {
        let gs = GameState(playerCountryID: "USA")
        gs.shadow.aidRemaining = 1_000
        let cuba = try XCTUnwrap(gs.getCountry(id: "CUB"))
        let before = gs.getCountry(id: "CUB")?.diplomaticRelations["USA"] ?? 0
        let hurricane = try XCTUnwrap(EmergencyCatalog.all.first { $0.kind == "Hurricane" })
        let m = CrisisManager()
        m.presentCrisis(WorldWatch.emergencyCrisis(hurricane, in: cuba, gs: gs))
        let relief = try XCTUnwrap(m.activeCrisis?.options.firstIndex { $0.title.lowercased().contains("relief") })
        var state = gs
        m.resolveCrisis(optionIndex: relief, gameState: &state)
        XCTAssertLessThan(gs.shadow.aidRemaining, 1_000)
        XCTAssertGreaterThan(gs.getCountry(id: "CUB")?.diplomaticRelations["USA"] ?? 0, before)
    }
}

final class WorldWatchTests: XCTestCase {
    private func goToWar(_ gs: GameState, _ a: String, _ b: String) {
        if let i = gs.countries.firstIndex(where: { $0.id == a }) { gs.countries[i].atWarWith.insert(b) }
        if let i = gs.countries.firstIndex(where: { $0.id == b }) { gs.countries[i].atWarWith.insert(a) }
        gs.activeWars.append(War(aggressor: a, defender: b, startTurn: gs.turn))
    }

    func testANewWarAbroadBecomesADecision() {
        let gs = GameState(playerCountryID: "USA")
        let base = WorldWatch.snapshot(gs)
        goToWar(gs, "RUS", "EST")
        let found = WorldWatch.changes(from: base, to: gs)
        let c = found.decisions.first { $0.type == .warOutbreak }
        XCTAssertNotNil(c)
        XCTAssertEqual(c?.affectedCountries, ["RUS", "EST"])
        XCTAssertTrue(c?.options.contains { $0.consequences.ceasefireBetween == ["RUS", "EST"] } ?? false)
        XCTAssertTrue(found.headlines.contains { $0.contains("at war") })
    }

    func testBeingAttackedIsADecisionButStartingAWarIsNot() {
        let gs = GameState(playerCountryID: "USA")
        var base = WorldWatch.snapshot(gs)
        goToWar(gs, "CUB", "USA")
        XCTAssertTrue(WorldWatch.changes(from: base, to: gs).decisions.first?.title.contains("ATTACKED US") ?? false)
        base = WorldWatch.snapshot(gs)
        goToWar(gs, "USA", "VEN")
        let found = WorldWatch.changes(from: base, to: gs)
        XCTAssertTrue(found.decisions.isEmpty)
        XCTAssertFalse(found.headlines.isEmpty)
    }

    func testChangesOfPowerBecomeDecisions() throws {
        let gs = GameState(playerCountryID: "USA")
        let base = WorldWatch.snapshot(gs)
        let ukr = try XCTUnwrap(gs.countries.firstIndex { $0.id == "UKR" })
        gs.countries[ukr].territoryOf = "RUS"
        let ven = try XCTUnwrap(gs.countries.firstIndex { $0.id == "VEN" })
        gs.countries[ven].government = gs.countries[ven].government == .military ? .democracy : .military
        let found = WorldWatch.changes(from: base, to: gs)
        XCTAssertTrue(found.decisions.contains { $0.type == .regimeChange && $0.title.contains("UKRAINE") })
        XCTAssertTrue(found.decisions.contains { $0.type == .regimeChange && $0.title.contains("VENEZUELA") })
    }

    func testAPlayerAnnexationIsNotADecision() throws {
        let gs = GameState(playerCountryID: "USA")
        let base = WorldWatch.snapshot(gs)
        let i = try XCTUnwrap(gs.countries.firstIndex { $0.id == "CUB" })
        gs.countries[i].territoryOf = "USA"
        XCTAssertTrue(WorldWatch.changes(from: base, to: gs).decisions.isEmpty)
    }

    func testDecisionsPerTurnAreCapped() {
        let gs = GameState(playerCountryID: "USA")
        let base = WorldWatch.snapshot(gs)
        for (a, b) in [("RUS", "EST"), ("CHN", "TWN"), ("IND", "PAK"), ("IRN", "ISR"), ("PRK", "KOR"), ("ARM", "AZE")] { goToWar(gs, a, b) }
        let found = WorldWatch.changes(from: base, to: gs)
        XCTAssertLessThanOrEqual(found.decisions.count, WorldWatch.maxDecisionsPerTurn)
        XCTAssertGreaterThanOrEqual(found.headlines.count, 6)
    }

    func testQueueAndStaleDecisions() {
        let gs = GameState(playerCountryID: "USA")
        let m = CrisisManager()
        goToWar(gs, "RUS", "EST")
        let est = gs.getCountry(id: "EST")!, rus = gs.getCountry(id: "RUS")!
        let war1 = WorldWatch.warCrisis(aggressor: rus, defender: est, gs: gs)!
        goToWar(gs, "CHN", "TWN")
        let war2 = WorldWatch.warCrisis(aggressor: gs.getCountry(id: "CHN")!, defender: gs.getCountry(id: "TWN")!, gs: gs)!
        m.presentCrisis(war1); m.presentCrisis(war2)
        XCTAssertEqual(m.activeCrisis?.id, war1.id)
        XCTAssertEqual(m.pendingCrises.count, 1)
        // The second war ends before the President gets to it: it is dropped, not shown.
        if let i = gs.countries.firstIndex(where: { $0.id == "CHN" }) { gs.countries[i].atWarWith.remove("TWN") }
        var state = gs
        let stayOut = war1.options.count - 1
        m.resolveCrisis(optionIndex: stayOut, gameState: &state)
        XCTAssertNil(m.activeCrisis)
        XCTAssertTrue(m.pendingCrises.isEmpty)
    }

    func testCeasefireAndJoiningAWar() {
        let gs = GameState(playerCountryID: "USA")
        goToWar(gs, "RUS", "EST")
        let m = CrisisManager()
        let peace = CrisisEvent(type: .warOutbreak, severity: .serious, title: "t", description: "d", affectedCountries: ["RUS", "EST"], turn: 0,
                                options: [CrisisOption(title: "cf", description: "", consequences: CrisisConsequences(message: "m", ceasefireBetween: ["RUS", "EST"])),
                                          CrisisOption(title: "join", description: "", consequences: CrisisConsequences(message: "m", joinWarAgainst: "RUS"))])
        var state = gs
        m.presentCrisis(peace); m.resolveCrisis(optionIndex: 0, gameState: &state)
        XCTAssertFalse(gs.getCountry(id: "RUS")!.atWarWith.contains("EST"))
        m.presentCrisis(peace); m.resolveCrisis(optionIndex: 1, gameState: &state)
        XCTAssertTrue(gs.getCountry(id: "USA")!.atWarWith.contains("RUS"))
        XCTAssertTrue(gs.getCountry(id: "RUS")!.atWarWith.contains("USA"))
    }

    func testMutualRelationsMoveBothWays() {
        let gs = GameState(playerCountryID: "USA")
        let m = CrisisManager()
        let us0 = gs.getCountry(id: "USA")!.diplomaticRelations["MEX"] ?? 0
        let them0 = gs.getCountry(id: "MEX")!.diplomaticRelations["USA"] ?? 0
        let c = CrisisEvent(type: .worldDisaster, severity: .serious, title: "t", description: "d", affectedCountries: ["MEX"], turn: 0,
                            options: [CrisisOption(title: "aid", description: "", consequences: CrisisConsequences(message: "m", mutualRelations: ["MEX": 10]))])
        var state = gs
        m.presentCrisis(c); m.resolveCrisis(optionIndex: 0, gameState: &state)
        XCTAssertEqual(gs.getCountry(id: "USA")!.diplomaticRelations["MEX"], min(100, us0 + 10))
        XCTAssertEqual(gs.getCountry(id: "MEX")!.diplomaticRelations["USA"], min(100, them0 + 10))
    }

    func testTheEngineWatchesTheWorldEachTurn() throws {
        let e = GameEngine()
        e.startNewGame(turnLength: .month)
        let gs = try XCTUnwrap(e.gameState)
        XCTAssertNotNil(e.crisisManager.worldBaseline)
        goToWar(gs, "RUS", "EST")
        e.watchWorld()
        let desk = [e.crisisManager.activeCrisis].compactMap { $0 } + e.crisisManager.pendingCrises
        XCTAssertTrue(desk.contains { $0.type == .warOutbreak })
        XCTAssertTrue(gs.shadow.ticker.contains { $0.text.contains("at war") })
    }
}
