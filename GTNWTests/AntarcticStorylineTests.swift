//
//  AntarcticStorylineTests.swift
//  GTNWTests
//
//  3.36.0: Antarctica as a storyline (Shared/Engine/Shadow/AntarcticStoryline.swift): stations, the treaty as
//  diplomacy, rival expeditions and counter-claims, the ice, the stranded party, the penguins, the name carried
//  over, the chief of staff's view and orders. 1890, 1950 and 2025 games; saves; determinism.
//

import XCTest
@testable import GTNW

@MainActor
final class AntarcticStorylineTests: XCTestCase {

    private func engine(_ year: Int, seed: UInt64 = 36) -> (GameEngine, GameState) {
        let e = CmdFixtures.engine(year: year, seed: seed)
        return (e, e.gameState!)
    }

    /// Jump to the turn whose window (previous, current] holds `date`, then run the storyline for that turn.
    private func run(_ e: GameEngine, through date: Date) {
        let gs = e.gameState!
        var t = gs.turn
        while gs.date(atTurn: t) < date { t += 1 }
        gs.turn = t
        e.processAntarcticStoryline()
    }

    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date { GameCalendar.date(year: y, month: m, day: d) }

    private func news(_ gs: GameState) -> [String] { gs.shadow.ticker.map(\.text) }

    // MARK: Unit

    func testOrdersParseToTheirVerbs() {
        let cases: [(String, CommandVerb)] = [
            ("build a research station in Antarctica", .researchStation), ("please build a research station", .researchStation),
            ("withdraw from the Antarctic Treaty", .leaveAntarcticTreaty), ("pull out of the antarctic treaty", .leaveAntarcticTreaty),
            ("rejoin the Antarctic Treaty", .joinAntarcticTreaty), ("sign the antarctic treaty", .joinAntarcticTreaty),
            ("renegotiate the Antarctic Treaty", .renegotiateAntarcticTreaty),
        ]
        for (text, verb) in cases { XCTAssertEqual(CommandParser.parse(text)?.verb, verb, text) }
        XCTAssertEqual(CommandParser.parse("withdraw from Iraq")?.verb, .withdrawTroops, "the shorter phrase still means troops")
        for op in AntarcticOrder.allCases { XCTAssertEqual(op.verb.antarcticOrder, op); XCTAssertEqual(op.verb.title, op.title) }
    }

    func testCostsAndScheduleAreEraAppropriate() {
        XCTAssertLessThan(Antarctica.stationCost(year: 1910), Antarctica.stationCost(year: 1960))
        XCTAssertLessThan(Antarctica.stationCost(year: 1960), Antarctica.stationCost(year: 2025))
        XCTAssertEqual(Antarctica.claimSectors.map(\.year), Antarctica.claims.map(\.year), "the same seven claims as 3.10.0")
        XCTAssertEqual(Antarctica.signatories.count, 12)
        XCTAssertEqual(Set(Antarctica.sites).count, Antarctica.sites.count)
    }

    // MARK: 1890

    func testIn1890ItIsOpenIceWithNoStationsAndNoTreaty() throws {
        let (e, gs) = engine(1890)
        XCTAssertEqual(gs.antarcticStanding, .noTreaty)
        XCTAssertEqual(gs.antarcticClaimStatus, .legal)
        XCTAssertTrue(try XCTUnwrap(e.antarcticProblem(.station)).contains("1890"))
        XCTAssertTrue(try XCTUnwrap(e.antarcticProblem(.leave)).contains("no Antarctic Treaty"))
        guard case .rejected(let why) = CmdFixtures.plan(e, "build a research station in Antarctica") else { return XCTFail("planned in 1890") }
        XCTAssertTrue(why.contains("permanent base"), why)
        let w = e.advisorWarnings(for: .claim(land: Antarctica.id, troops: 1))
        XCTAssertTrue(w.contains { $0.text.contains("No nation has claimed it yet") }, "no 'seven nations' before 1908")
        // The British claim lands as news when the calendar reaches 1908.
        run(e, through: day(1908, 1, 1))
        XCTAssertTrue(news(gs).contains { $0.contains("Falkland Islands Dependencies") })
    }

    func testAClaimBeforeTheBritishOneDrawsACounterClaim() throws {
        let (e, gs) = engine(1905)
        XCTAssertTrue(e.claimLand(Antarctica.id, troops: 1))
        let before = gs.getCountry(id: "GBR")?.diplomaticRelations["USA"] ?? 0
        run(e, through: day(1908, 1, 1))
        XCTAssertTrue(news(gs).contains { $0.contains("rejecting the U.S. claim") })
        XCTAssertLessThan(gs.getCountry(id: "GBR")?.diplomaticRelations["USA"] ?? 0, before)
    }

    // MARK: 1950

    func testIn1950StationsAreCheapAndTheTreatyArrivesOnTime() throws {
        let (e, gs) = engine(1950)
        XCTAssertEqual(gs.antarcticStanding, .noTreaty)
        let plan = try XCTUnwrap(CmdFixtures.confirmedPlan(e, "build a research station in Antarctica"))
        XCTAssertEqual(plan.orders, [GameOrder(kind: .antarctic, target: Antarctica.id, mission: "station")])
        gs.shadow.aidRemaining = 10
        let pop = gs.shadow.popularity, funds = gs.shadow.aidRemaining
        let out = e.executeCommand(plan.orders, source: .parser)
        XCTAssertEqual(out.carried.count, 1)
        XCTAssertEqual(gs.shadow.antarctic.stations.map(\.site), ["Ross Island"])
        XCTAssertGreaterThan(gs.shadow.popularity, pop, "science prestige")
        XCTAssertEqual(gs.shadow.aidRemaining, funds - Antarctica.stationCost(year: 1950), accuracy: 0.0001)
        XCTAssertTrue(news(gs).contains { $0.contains("research station opens at Ross Island") })
        XCTAssertFalse(Antarctica.programLines(gs).isEmpty)
        // No pole station before 1956: the third site is the Peninsula, the fourth skips the Pole.
        gs.shadow.antarctic.stations += [AntarcticStation(site: "the Bay of Whales", built: gs.currentDate),
                                         AntarcticStation(site: "the Antarctic Peninsula", built: gs.currentDate)]
        XCTAssertEqual(e.nextAntarcticSite(gs), "Marie Byrd Land")
        // The treaty: signed, then in force.
        run(e, through: day(1959, 12, 1))
        XCTAssertTrue(news(gs).contains { $0.contains("sign the Antarctic Treaty") })
        XCTAssertEqual(gs.antarcticStanding, .party)
        XCTAssertEqual(gs.antarcticClaimStatus, .restricted)
        XCTAssertNotNil(e.antarcticProblem(.renegotiate), "not before it is in force")
        run(e, through: day(1961, 6, 23))
        XCTAssertEqual(gs.antarcticClaimStatus, .treatyBanned)
    }

    // MARK: 2025

    func testWithdrawalTakesTwoYearsAndSoftensAClaim() throws {
        let (e, gs) = engine(2025)
        XCTAssertEqual(gs.antarcticStanding, .party)
        XCTAssertEqual(gs.antarcticClaimStatus, .treatyBanned)
        let plan = try XCTUnwrap(CmdFixtures.confirmedPlan(e, "withdraw from the Antarctic Treaty"))
        XCTAssertTrue(plan.warnings.contains { $0.level == 2 })
        let gbr = gs.getCountry(id: "GBR")?.diplomaticRelations["USA"] ?? 0
        XCTAssertEqual(e.executeCommand(plan.orders, source: .parser).carried.count, 1)
        XCTAssertLessThan(gs.getCountry(id: "GBR")?.diplomaticRelations["USA"] ?? 0, gbr)
        guard case .withdrawing = gs.antarcticStanding else { return XCTFail("\(gs.antarcticStanding)") }
        XCTAssertEqual(gs.antarcticClaimStatus, .treatyBanned, "still bound during the notice")
        XCTAssertNotNil(e.antarcticProblem(.leave))
        gs.turn += 25
        XCTAssertEqual(gs.antarcticStanding, .withdrawn)
        XCTAssertEqual(gs.antarcticClaimStatus, .restricted)
        XCTAssertTrue(e.advisorWarnings(for: .claim(land: Antarctica.id, troops: 1)).contains { $0.text.contains("bad faith") })
        gs.actionsUsedThisTurn = 0
        XCTAssertTrue(e.runAntarcticOrder(.join))
        XCTAssertEqual(gs.antarcticStanding, .party)
    }

    func testRenegotiationIsDecidedByStationsAndGoodwill() throws {
        let (e, gs) = engine(2025)
        guard case .plan(let refused) = CmdFixtures.plan(e, "renegotiate the Antarctic Treaty") else { return XCTFail("no card") }
        XCTAssertTrue(refused.warnings.contains { $0.text.contains("at least 2") }, "the card says it will fail and why")
        XCTAssertTrue(e.runAntarcticOrder(.renegotiate))
        XCTAssertNil(gs.shadow.antarctic.renegotiated)
        XCTAssertTrue(try XCTUnwrap(e.antarcticProblem(.renegotiate)).contains("won't meet again"))
        // Five years on, with two stations and friends, they agree.
        gs.turn += 61
        gs.actionsUsedThisTurn = 0
        gs.shadow.antarctic.stations = [AntarcticStation(site: "Ross Island", built: gs.currentDate), AntarcticStation(site: "the South Pole", built: gs.currentDate)]
        for id in Antarctica.signatories where id != "USA" { gs.setRelation(from: id, to: "USA", value: 40) }
        XCTAssertTrue(e.renegotiationOutlook(gs).agrees)
        XCTAssertTrue(e.runAntarcticOrder(.renegotiate))
        XCTAssertNotNil(gs.shadow.antarctic.renegotiated)
        XCTAssertEqual(gs.antarcticClaimStatus, .restricted)
    }

    func testStationsAreDevelopmentNotAParallelIncomeAndIceShelvesCostRepairs() {
        let (e, gs) = engine(2025)
        gs.shadow.antarctic.stations = [AntarcticStation(site: "Ross Island", built: day(2000, 1, 1))]
        gs.turn = 1
        gs.shadow.aidRemaining = 10
        let funds = gs.shadow.aidRemaining
        e.processAntarcticStoryline()
        let cost = Antarctica.stationCost(year: 2025)
        XCTAssertEqual(funds - gs.shadow.aidRemaining, cost * Antarctica.upkeepShare / 12, accuracy: 0.0001, "upkeep only, no station income")
        XCTAssertEqual(LandDevelopment.bought(Antarctica.id, in: gs), 0, "not held: nothing to develop")
        // Held: each station counts as one INVEST, so Antarctica's own yield starts paying (ReportBooks.swift).
        XCTAssertTrue(e.claimLand(Antarctica.id, troops: 1, spendAction: false))
        XCTAssertEqual(LandDevelopment.bought(Antarctica.id, in: gs), LandDevelopment.investYears)
        XCTAssertTrue(LandDevelopment.landYieldPays(Antarctica.id, in: gs))
        gs.shadow.books.developed[Antarctica.id] = 2   // INVEST bought more: a station never lowers it
        e.processAntarcticStoryline()
        XCTAssertEqual(LandDevelopment.bought(Antarctica.id, in: gs), 2)
        run(e, through: day(2030, 2, 1))
        XCTAssertTrue(news(gs).contains { $0.contains("Another ice shelf") })
        XCTAssertTrue(news(gs).contains { $0.contains("to repair") })
    }

    func testTheHeldIceDrawsRivalsARescueAndPenguins() throws {
        let (e, gs) = engine(2025)
        XCTAssertTrue(e.claimLand(Antarctica.id, troops: 1))
        e.crisisManager.activeCrisis = nil
        XCTAssertTrue(e.renameTerritory(Antarctica.id, to: "Freedonia Australis"))
        XCTAssertTrue(news(gs).contains(Antarctica.penguinLines[0]), "the penguins were not consulted")
        run(e, through: day(2025, 12, 1))
        XCTAssertTrue(news(gs).contains { $0.hasPrefix("Rival expedition:") })
        XCTAssertTrue(news(gs).contains(Antarctica.penguinLines[1]))
        XCTAssertNil(e.crisisManager.activeCrisis, "no rescue in the first season")
        run(e, through: day(2026, 12, 1))
        let card = try XCTUnwrap(e.crisisManager.activeCrisis)
        XCTAssertEqual(card.title, "STRANDED ON THE ICE")
        XCTAssertTrue(gs.shadow.antarctic.rescuePending)
        let ask = try XCTUnwrap(card.options.firstIndex { $0.title.hasPrefix("Ask ") })
        let friend = try XCTUnwrap(card.options[ask].consequences.shadowChoice?.split(separator: "|").last.map(String.init))
        let rel = gs.getCountry(id: friend)?.diplomaticRelations["USA"] ?? 0
        var state: GameState = gs
        e.crisisManager.resolveCrisis(optionIndex: ask, gameState: &state)
        XCTAssertEqual(gs.shadow.antarctic.rescues, 1)
        XCTAssertFalse(gs.shadow.antarctic.rescuePending)
        XCTAssertGreaterThan(gs.getCountry(id: friend)?.diplomaticRelations["USA"] ?? 0, rel)
        XCTAssertTrue(e.renameTerritory(Antarctica.id, to: "Antarctica"))
        XCTAssertEqual(news(gs).last, Antarctica.penguinsPleased)
    }

    func testAStationOrderWorksWhenTheIceFliesOurFlag() throws {
        let (e, gs) = engine(2025)
        XCTAssertTrue(e.claimLand(Antarctica.id, troops: 1))
        XCTAssertNil(e.orderProblem(GameOrder(kind: .antarctic, target: Antarctica.id, mission: "station")))
        XCTAssertNotNil(e.orderProblem(GameOrder(kind: .antarctic, target: "MEX", mission: "station")))
        XCTAssertNotNil(e.orderProblem(GameOrder(kind: .antarctic, target: Antarctica.id, mission: "mine")))
        guard case .rejected(let why) = CmdFixtures.plan(e, "build a research station in Mexico") else { return XCTFail("planned in Mexico") }
        XCTAssertTrue(why.contains("for Antarctica"), why)
        XCTAssertTrue(e.runAntarcticOrder(.station))
        XCTAssertEqual(gs.shadow.antarctic.stations.count, 1)
    }

    // MARK: The chief of staff

    func testChiefOfStaffReportsAndProposesAntarcticOrders() throws {
        let (e, gs) = engine(2025)
        let dossier = ChatTools.run("country", arguments: ["name": "Antarctica"], engine: e).text
        XCTAssertTrue(dossier.contains("treaty_standing") && dossier.contains("Party to the Antarctic Treaty"), dossier)
        XCTAssertTrue(dossier.contains("researchStation: available"), dossier)
        let all = ChatTools.run("actions", arguments: ["category": "all"], engine: e).text
        XCTAssertTrue(all.contains("\"researchStation\""), all)
        let offer = ChatTools.run("propose_orders", arguments: ["steps": [["verb": "researchStation", "targets": ["Antarctica"]],
                                                                         ["verb": "leaveAntarcticTreaty", "targets": ["Antarctica"]]]], engine: e, planID: 1)
        let steps = try XCTUnwrap(offer.plan?.steps)
        XCTAssertTrue(steps.allSatisfy(\.isReady), offer.text)
        XCTAssertTrue(gs.shadow.antarctic.stations.isEmpty, "nothing runs before EXECUTE")
        XCTAssertEqual(e.executeCommand(steps.compactMap(\.plan).flatMap(\.orders), source: .chat).carried.count, 2)
        let after = ChatTools.run("country", arguments: ["name": "Antarctica"], engine: e).text
        XCTAssertTrue(after.contains("Ross Island (2025)") && after.contains("Withdrawing"), after)
        XCTAssertEqual(gs.shadow.commandLog.last?.orders.map(\.kind), [.antarctic, .antarctic])
    }

    // MARK: A name carried over

    func testANameIsOfferedBackInTheNextGameAndGoesUpWithTheFlag() throws {
        // The Hall of Cartography, in memory (no folder under tests).
        AntarcticaNames.offers = true
        CartographyHall.reset()
        defer { AntarcticaNames.offers = false; CartographyHall.reset() }
        let (e1, g1) = engine(2025)
        XCTAssertTrue(e1.claimLand(Antarctica.id, troops: 1))
        XCTAssertTrue(e1.renameTerritory(Antarctica.id, to: "Icelandia"))
        XCTAssertTrue(e1.renameTerritory(Antarctica.id, to: "Penguinia"))
        XCTAssertEqual(AntarcticaNames.last(), "Penguinia", "the newest name for Antarctica")

        let e = GameEngine()
        e.startNewGame(turnLength: .month, year: 1950, seed: 9)
        let card = try XCTUnwrap(e.crisisManager.activeCrisis)
        XCTAssertTrue(card.description.contains("Restore your name for Antarctica: Penguinia?"), card.description)
        var gs = try XCTUnwrap(e.gameState)
        e.crisisManager.resolveCrisis(optionIndex: 0, gameState: &gs)
        XCTAssertEqual(gs.shadow.antarctic.restoredName, "Penguinia")
        XCTAssertTrue(e.claimLand(Antarctica.id, troops: 1))
        XCTAssertEqual(gs.getCountry(id: Antarctica.id)?.name, "Penguinia")
        XCTAssertTrue(news(gs).contains(Antarctica.penguinLines[0]))

        // Nothing to offer: back to the plain name, or offers off (tests, the headless engine).
        XCTAssertTrue(e1.renameTerritory(Antarctica.id, to: "Antarctica"))
        XCTAssertNil(AntarcticaNames.last())
        XCTAssertEqual(news(g1).last, Antarctica.penguinsPleased)
        AntarcticaNames.offers = false
        XCTAssertTrue(e1.renameTerritory(Antarctica.id, to: "Penguinia"))
        XCTAssertNil(AntarcticaNames.last())
    }

    func testNoOfferWhenThereIsNothingToCarryOver() {
        let e = GameEngine()
        e.startNewGame(turnLength: .month, year: 2025, seed: 3)
        XCTAssertNil(e.gameState?.shadow.antarctic.offeredName)
    }

    // MARK: Saves and determinism

    func testProgramSurvivesASaveAndOlderSavesLoad() throws {
        let (e, gs) = engine(2025)
        XCTAssertTrue(e.runAntarcticOrder(.station))
        XCTAssertTrue(e.runAntarcticOrder(.leave))
        gs.shadow.antarctic.restoredName = "Penguinia"
        let data = try JSONEncoder().encode(gs.shadow)
        let back = try JSONDecoder().decode(ShadowState.self, from: data)
        XCTAssertEqual(back.antarctic, gs.shadow.antarctic)
        var raw = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        raw["antarctic"] = nil
        let old = try JSONDecoder().decode(ShadowState.self, from: JSONSerialization.data(withJSONObject: raw))
        XCTAssertEqual(old.antarctic, AntarcticProgram())
        let partial = try JSONDecoder().decode(AntarcticProgram.self, from: Data(#"{"penguinProtests":3}"#.utf8))
        XCTAssertEqual(partial.penguinProtests, 3)
        XCTAssertTrue(partial.stations.isEmpty)
    }

    func testSameSeedAndOrdersPlayTheSameAntarcticGame() async {
        func play() async -> (ScriptedGame.Snapshot, [String]) {
            let e = CmdFixtures.engine(year: 2025, seed: 77)
            // No action spent: a spent-out turn would schedule its own end and race the loop.
            _ = e.claimLand(Antarctica.id, troops: 1, spendAction: false)
            e.gameState!.shadow.antarctic.stations = [AntarcticStation(site: "Ross Island", built: e.gameState!.currentDate)]
            for _ in 0..<12 {
                if e.crisisManager.activeCrisis != nil, var g = e.gameState { e.crisisManager.resolveCrisis(optionIndex: 0, gameState: &g) }
                e.endTurn()
                await ScriptedGame.settle(e)
            }
            let gs = e.gameState!
            // The storyline's own lines (the modern world brief arrives in the background and is not compared).
            let ours = gs.shadow.ticker.map(\.text).filter { $0.contains("Antarctic") || $0.contains("penguin") || $0.hasPrefix("Rival expedition") }
            return (ScriptedGame.snapshot(gs), ours)
        }
        let a = await play(), b = await play()
        XCTAssertEqual(a.0, b.0)
        XCTAssertEqual(a.1, b.1)
        XCTAssertTrue(a.1.contains { $0.hasPrefix("Rival expedition:") }, "a season passed")
    }

    // MARK: Content

    func testEveryLineStaysInsideTheContentRules() {
        var texts = Antarctica.penguinLines + [Antarctica.penguinsPleased] + Antarctica.history.map(\.text) + AntarcticOrder.hints
        texts += AntarcticOrder.allCases.map(\.title) + Antarctica.claimSectors.map(\.sector)
        for t in texts {
            XCTAssertFalse(ChatSafety.violates(t), t)
            XCTAssertFalse(t.lowercased().contains("colour") || t.lowercased().contains("favour"), "American spelling: \(t)")
        }
    }
}
