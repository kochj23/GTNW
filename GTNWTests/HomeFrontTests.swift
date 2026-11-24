//
//  HomeFrontTests.swift
//  GTNWTests
//
//  3.36.0: power plays at home (HomeFront*.swift): troops in the states, fixing the numbers, the central bank,
//  equity stakes, staying in power, the missile shield and nuclear tests. Unit (era rules, numbers, parsing),
//  functional (each order through the command box and the turn step), save compatibility and determinism.
//

import XCTest
@testable import GTNW

@MainActor
enum HomeFixtures {
    static func engine(year: Int = 2025, seed: UInt64 = 7) -> GameEngine { CmdFixtures.engine(year: year, seed: seed) }

    /// Plan the typed order and carry it out; the plan must come back.
    @discardableResult
    static func run(_ e: GameEngine, _ text: String, file: StaticString = #filePath, line: UInt = #line) -> GameEngine.CommandExecution? {
        guard let i = CommandParser.parse(text) else { XCTFail("unparsed: \(text)", file: file, line: line); return nil }
        guard case .plan(let p) = e.planCommand(i, source: .parser) else {
            XCTFail("no plan for \(text): \(e.planCommand(i, source: .parser))", file: file, line: line); return nil
        }
        e.gameState?.actionsUsedThisTurn = 0
        return e.executeCommand(p.orders, source: .parser)
    }

    /// Advance turns through the home-front step only (no AI phase), so the test sees just these effects.
    static func turns(_ e: GameEngine, _ n: Int) {
        for _ in 0..<n {
            e.gameState?.turn += 1
            e.processHomeFront()
        }
    }

    static func refusal(_ e: GameEngine, _ text: String) -> String? {
        guard let i = CommandParser.parse(text), case .rejected(let why) = e.planCommand(i, source: .parser) else { return nil }
        return why
    }
}

// MARK: - Unit

final class HomeFrontUnitTests: XCTestCase {

    func testCentralBankByEra() {
        XCTAssertEqual(HomeFrontModel.centralBank(year: 1800, nation: "USA"), "the Bank of the United States")
        XCTAssertEqual(HomeFrontModel.centralBank(year: 1820, nation: "USA"), "the Second Bank of the United States")
        XCTAssertNil(HomeFrontModel.centralBank(year: 1850, nation: "USA"), "the Independent Treasury years")
        XCTAssertNil(HomeFrontModel.centralBank(year: 1913, nation: "USA"))
        XCTAssertEqual(HomeFrontModel.centralBank(year: 1914, nation: "USA"), "the Federal Reserve")
        XCTAssertEqual(HomeFrontModel.centralBank(year: 1800, nation: "GBR"), "the central bank")
        XCTAssertTrue(HomeFrontModel.noBankReason(year: 1850, nation: "USA").contains("1914"))
    }

    func testTestBanEras() {
        func d(_ y: Int) -> Date { GameCalendar.date(year: y, month: 6, day: 1) }
        XCTAssertEqual(HomeFrontModel.testStatus(atmospheric: true, on: d(1955)), .legal)
        XCTAssertEqual(HomeFrontModel.testStatus(atmospheric: true, on: d(1965)), .treatyBanned, "Limited Test Ban Treaty")
        XCTAssertEqual(HomeFrontModel.testStatus(atmospheric: false, on: d(1970)), .legal)
        XCTAssertEqual(HomeFrontModel.testStatus(atmospheric: false, on: d(1995)), .restricted, "the 1992 moratorium")
        XCTAssertEqual(HomeFrontModel.shieldStatus(on: d(1980)), .treatyBanned, "ABM Treaty")
        XCTAssertEqual(HomeFrontModel.shieldStatus(on: d(2005)), .legal)
    }

    func testShieldStopsOnlyAFixedFraction() {
        XCTAssertEqual(HomeFrontModel.intercepted(10, rate: 0.3), 3)
        XCTAssertEqual(HomeFrontModel.intercepted(3, rate: 0.3), 0, "rounded down: a small salvo gets through whole")
        XCTAssertEqual(HomeFrontModel.intercepted(0, rate: 0.3), 0)
        for y in [1960, 1985, 2010, 2030] { XCTAssertLessThan(HomeFrontModel.interceptRate(year: y), 0.5, "never most of them") }
    }

    func testOfficialErrorGrows() {
        let a = HomeFrontModel.officialBias(months: 1), b = HomeFrontModel.officialBias(months: 12)
        XCTAssertGreaterThan(b.growth, a.growth)
        XCTAssertLessThan(b.inflation, a.inflation)
        XCTAssertGreaterThan(HomeFrontModel.leakAnnual(years: 2), HomeFrontModel.leakAnnual(years: 0))
    }

    func testStayingInPowerIsNeverEasy() {
        // The best case anywhere: a loyal Congress, a popular President, a loyal army.
        let best = HomeFrontModel.stages(route: "postpone").reduce(1.0) {
            $0 * HomeFrontModel.stageOdds($1, route: "postpone", congress: 100, popularity: 100, outcry: 0, loyalty: 100, courtsWeakened: false)
        }
        XCTAssertLessThan(best, 0.05, "very hard")
        XCTAssertGreaterThan(best, 0)
        let lawful = HomeFrontModel.stages(route: "amendment").reduce(1.0) {
            $0 * HomeFrontModel.stageOdds($1, route: "amendment", congress: 100, popularity: 100, outcry: 0, loyalty: 100, courtsWeakened: false)
        }
        XCTAssertLessThanOrEqual(lawful, 0.2)
    }

    func testParsing() {
        func i(_ s: String) -> CommandIntent? { CommandParser.parse(s) }
        XCTAssertEqual(i("fire the chief statistician")?.verb, .fixNumbers)
        XCTAssertEqual(i("fire the chief statistician")?.targets, ["fire"])
        XCTAssertEqual(i("rehire an independent statistician")?.targets, ["restore"])
        XCTAssertEqual(i("pressure the Fed to cut rates")?.verb, .leanOnBank)
        XCTAssertEqual(i("overrule the Federal Reserve")?.targets, ["overrule"])
        XCTAssertEqual(i("buy a stake in steel")?.targets, ["buy", "steel"])
        XCTAssertEqual(i("please take an equity stake in the semiconductor industry")?.verb, .buyStake)
        XCTAssertEqual(i("postpone the election")?.targets, ["postpone"])
        XCTAssertEqual(i("repeal the 22nd amendment")?.targets, ["amendment"])
        XCTAssertEqual(i("build a missile shield")?.verb, .missileShield)
        XCTAssertEqual(i("conduct a nuclear test in the atmosphere")?.targets, ["atmospheric"])
        XCTAssertEqual(i("conduct an underground nuclear test")?.targets, ["underground"])
        XCTAssertEqual(i("send federal troops into Texas over the governor's objection")?.targets, ["deploy", "texas"])
        XCTAssertEqual(HomePlayCommands.industryID("chips"), "semiconductors")
        XCTAssertEqual(HomePlayCommands.industryID("the oil industry"), "oil")
        // The old verbs still read the same.
        XCTAssertEqual(i("buy Alaska")?.verb, .buy)
        XCTAssertEqual(i("nuke France")?.verb, .nuke)
    }

    func testOrderRecordsCarryNoFreeText() {
        let o = GameOrder(kind: .homePlay, target: "steel", action: HomePlay.buyStake.rawValue, mission: "buy")
        XCTAssertTrue(Set(o.record.keys).isSubset(of: ["kind", "target", "action", "mission"]))
        XCTAssertFalse(o.isNuclear)
        XCTAssertTrue(GameOrder(kind: .homePlay, target: "USA", action: HomePlay.nuclearTest.rawValue, mission: "underground").isNuclear)
    }
}

// MARK: - Functional

@MainActor
final class HomeFrontFunctionalTests: XCTestCase {

    func testFixingTheNumbersThenTheLeak() throws {
        let e = HomeFixtures.engine()
        let gs = try XCTUnwrap(e.gameState)
        let before = gs.shadow.popularity
        let r = try XCTUnwrap(HomeFixtures.run(e, "fire the chief statistician"))
        XCTAssertEqual(r.carried.count, 1)
        XCTAssertGreaterThan(gs.shadow.popularity, before, "short-term the figures look better")
        XCTAssertGreaterThan(gs.officialEconomy.growth, gs.trueEconomy.growth, "the official figures overstate growth")
        let early = gs.officialEconomy.growth - gs.trueEconomy.growth
        HomeFixtures.turns(e, 6)
        if gs.shadow.homeFront.numbersLeaked == nil {
            XCTAssertGreaterThan(gs.officialEconomy.growth - gs.trueEconomy.growth, early, "the error grows")
        }
        HomeFixtures.turns(e, 48)
        XCTAssertNotNil(gs.shadow.homeFront.numbersLeaked, "the truth comes out within a few years")
        XCTAssertNotNil(gs.shadow.homeFront.leakedGrowth)
        XCTAssertTrue(gs.shadow.ticker.contains { $0.text.hasPrefix("LEAKED") })
        // Rehiring restores honest figures.
        HomeFixtures.run(e, "rehire an independent statistician")
        XCTAssertEqual(gs.officialEconomy, gs.trueEconomy)
    }

    func testCentralBankCheapMoneyThenInflation() throws {
        let e = HomeFixtures.engine()
        let gs = try XCTUnwrap(e.gameState)
        let growth0 = gs.trueEconomy.growth, pop0 = gs.shadow.popularity
        HomeFixtures.run(e, "pressure the Fed to cut rates")
        XCTAssertGreaterThan(gs.trueEconomy.growth, growth0, "growth now")
        XCTAssertGreaterThan(gs.shadow.popularity, pop0, "approval now")
        HomeFixtures.run(e, "overrule the Federal Reserve")
        XCTAssertTrue(gs.shadow.homeFront.bankOverruled)
        let infl0 = try XCTUnwrap(gs.shadow.homeFront.inflation)
        HomeFixtures.turns(e, 24)
        let infl = try XCTUnwrap(gs.shadow.homeFront.inflation)
        XCTAssertGreaterThan(infl, infl0 + 2, "inflation later")
        XCTAssertGreaterThan(gs.trueEconomy.borrowing, 5, "dearer borrowing")
    }

    func testNoCentralBankInTheIndependentTreasuryYears() {
        let e = HomeFixtures.engine(year: 1850)
        XCTAssertTrue(HomeFixtures.refusal(e, "pressure the central bank to cut rates")?.contains("Independent Treasury") == true)
        let early = HomeFixtures.engine(year: 1801)
        XCTAssertNotNil(HomeFixtures.run(early, "lean on the bank")?.carried.first, "the Bank of the United States")
    }

    func testEquityStakePaysAndCanScandalize() throws {
        let e = HomeFixtures.engine()
        let gs = try XCTUnwrap(e.gameState)
        let t0 = try XCTUnwrap(gs.getPlayerCountry()).treasury
        HomeFixtures.run(e, "buy a stake in steel")
        HomeFixtures.run(e, "take a stake in semiconductors")
        HomeFixtures.run(e, "buy into the oil industry")
        XCTAssertEqual(gs.shadow.homeFront.stakes.map(\.industry), ["steel", "semiconductors", "oil"])
        XCTAssertLessThan(try XCTUnwrap(gs.getPlayerCountry()).treasury, t0)
        XCTAssertNotNil(HomeFixtures.refusal(e, "buy a stake in steel"), "one stake per industry")
        XCTAssertTrue(HomeFixtures.refusal(e, "buy a stake in railroads")?.contains("2025") == true, "railroads are an earlier era's industry")
        HomeFixtures.turns(e, 60)
        XCTAssertGreaterThan(gs.shadow.homeFront.stakeIncome, 0)
        XCTAssertGreaterThan(gs.shadow.homeFront.scandals, 0, "five years of three stakes: insiders trade")
        HomeFixtures.run(e, "sell the stake in steel")
        XCTAssertFalse(gs.shadow.homeFront.stakes.contains { $0.industry == "steel" })
    }

    func testMissileShieldInterceptsAFixedShare() throws {
        let e = HomeFixtures.engine()
        let gs = try XCTUnwrap(e.gameState)
        HomeFixtures.run(e, "build a missile shield")
        XCTAssertNotNil(gs.shadow.homeFront.shieldStarted)
        let ready = try XCTUnwrap(gs.shadow.homeFront.shieldReady)
        XCTAssertGreaterThan(ready, gs.currentDate, "years away")
        XCTAssertEqual(e.missileShieldIntercepts(target: "USA", incoming: 10), 0, "not ready yet")
        gs.shadow.homeFront.shieldReady = gs.currentDate
        let rus = try XCTUnwrap(gs.countries.firstIndex { $0.id == "RUS" })
        gs.countries[rus].nuclearWarheads = max(gs.countries[rus].nuclearWarheads, 20)
        let usa = try XCTUnwrap(gs.countries.firstIndex { $0.id == "USA" })
        gs.countries[usa].hasSDI = false
        gs.shadow.satellites["warning"] = 0
        e.launchNuclearStrike(from: "RUS", to: "USA", warheads: 10)
        XCTAssertEqual(gs.shadow.homeFront.shieldIntercepted, 3, "30% of 10, no dice")
        XCTAssertEqual(e.missileShieldIntercepts(target: "FRA", incoming: 10), 0, "it guards only the President's nation")
        XCTAssertNotNil(HomeFixtures.refusal(HomeFixtures.engine(year: 1950), "build a missile shield"), "no missiles to stop yet")
    }

    func testNuclearTestsByEra() throws {
        let e = HomeFixtures.engine(year: 1965)
        let gs = try XCTUnwrap(e.gameState)
        let me0 = try XCTUnwrap(gs.getPlayerCountry())
        let fra0 = try XCTUnwrap(gs.getCountry(id: "FRA")?.diplomaticRelations["USA"])
        guard case .plan(let p) = e.planCommand(try XCTUnwrap(CommandParser.parse("conduct an atmospheric nuclear test")), source: .parser) else {
            return XCTFail("no plan")
        }
        XCTAssertTrue(p.nuclear, "a detonation needs the second press")
        XCTAssertTrue(p.warnings.contains { $0.text.contains("Limited Test Ban") })
        HomeFixtures.run(e, "conduct an atmospheric nuclear test")
        let me = try XCTUnwrap(gs.getPlayerCountry())
        XCTAssertEqual(me.nuclearWarheads, me0.nuclearWarheads - 1)
        XCTAssertEqual(me.treatyViolations, me0.treatyViolations + 1)
        XCTAssertLessThan(try XCTUnwrap(gs.getCountry(id: "FRA")?.diplomaticRelations["USA"]), fra0)
        XCTAssertEqual(gs.shadow.homeFront.tests.last?.status, .treatyBanned)
        XCTAssertNotNil(HomeFixtures.refusal(HomeFixtures.engine(year: 1955), "conduct an underground nuclear test"), "Rainier is 1957")
        XCTAssertNotNil(HomeFixtures.refusal(HomeFixtures.engine(year: 1930), "conduct a nuclear test"))
    }

    func testDefyingTheTermLimitUsuallyEndsInRemoval() throws {
        var removed = 0, backedDown = 0, stayed = 0
        for seed in UInt64(1)...12 {
            let e = HomeFixtures.engine(year: 2025, seed: seed)
            let gs = try XCTUnwrap(e.gameState)
            guard HomeFixtures.run(e, "postpone the election")?.carried.count == 1 else { return XCTFail("postpone refused") }
            XCTAssertNotNil(gs.shadow.homeFront.bid)
            for _ in 0..<6 where gs.shadow.homeFront.bid != nil { HomeFixtures.turns(e, 1) }
            XCTAssertNil(gs.shadow.homeFront.bid, "settled within four stages")
            switch gs.shadow.domesticEnding {
            case .impeached?: removed += 1
            case .ruleExtended?: stayed += 1
            default: backedDown += 1
            }
        }
        XCTAssertGreaterThan(removed, backedDown, "failure usually means removal")
        XCTAssertLessThan(stayed, 3, "never trivial")
    }

    func testRuleExtendedIsAGameEnding() throws {
        let e = HomeFixtures.engine()
        let gs = try XCTUnwrap(e.gameState)
        e.succeedTenureBid(TenureBid(route: "postpone", started: gs.currentDate))
        XCTAssertEqual(gs.shadow.domesticEnding, .ruleExtended)
        XCTAssertFalse(DomesticEnding.ruleExtended.servedOut)
        XCTAssertTrue(VictoryChecker.checkDefeat(gameState: gs).defeated)
    }

    func testRepealingTheAmendmentLetsThePresidentRunAgain() throws {
        let e = HomeFixtures.engine()
        let gs = try XCTUnwrap(e.gameState)
        HomeFixtures.run(e, "repeal the 22nd amendment")
        XCTAssertEqual(gs.shadow.homeFront.bid?.route, "amendment")
        e.succeedTenureBid(try XCTUnwrap(gs.shadow.homeFront.bid))
        XCTAssertTrue(gs.shadow.homeFront.termLimitRepealed)
        XCTAssertFalse(ElectionCycle.termLimited(gs.shadow.campaign, termsWon: 5, year: 2028))
        XCTAssertNil(gs.shadow.domesticEnding, "lawful: the game goes on")
    }

    func testBefore1951AThirdTermIsLegal() {
        let e = HomeFixtures.engine(year: 1938)
        XCTAssertTrue(HomeFixtures.refusal(e, "defy the 22nd amendment")?.contains("No amendment limits") == true)
        XCTAssertTrue(HomeFixtures.refusal(e, "repeal the 22nd amendment")?.contains("before 1951") == true)
        XCTAssertTrue(HomeFixtures.refusal(e, "run for a third term")?.contains("cost votes") == true)
        e.gameState?.shadow.campaign.leaveReason = .retired
        XCTAssertNotNil(HomeFixtures.run(e, "run for a third term")?.carried.first, "back in the race")
        XCTAssertTrue(e.gameState?.shadow.campaign.running == true)
    }

    func testTheCabinetWarnsAndIsOverruled() throws {
        let e = HomeFixtures.engine()
        let gs = try XCTUnwrap(e.gameState)
        guard case .plan(let p) = e.planCommand(try XCTUnwrap(CommandParser.parse("postpone the election")), source: .parser) else { return XCTFail() }
        XCTAssertGreaterThanOrEqual(p.warnings.filter { $0.level == 2 }.count, 3)
        XCTAssertTrue(p.warnings.contains { $0.text.contains("Odds") })
        let econ = gs.advisors.firstIndex { $0.isActive && $0.roleKey == "economic" }
        let loyal0 = econ.map { gs.advisors[$0].loyalty }
        HomeFixtures.run(e, "fire the chief statistician")
        if let i = econ, let l = loyal0 { XCTAssertLessThan(gs.advisors[i].loyalty, l, "overruled") }
    }

    func testNonAmericanPlayersGetTheGenericOrders() throws {
        let e = CmdFixtures.engine(year: 2025, player: "FRA")
        XCTAssertNotNil(HomeFixtures.refusal(e, "postpone the election"))
        XCTAssertNotNil(HomeFixtures.run(e, "pressure the central bank to cut rates")?.carried.first)
        XCTAssertNotNil(HomeFixtures.run(e, "conduct an underground nuclear test")?.carried.first)
    }
}

// MARK: - Chief of staff

@MainActor
final class HomeFrontChatTests: XCTestCase {
    func testChiefOfStaffCanProposeHomePlays() throws {
        let e = HomeFixtures.engine()
        let list = ChatTools.run("actions", arguments: ["category": "domestic"], engine: e).text
        for p in HomePlay.allCases { XCTAssertTrue(list.contains(p.rawValue), p.rawValue) }
        let out = ChatTools.run("propose_orders", arguments: ["steps": [["verb": "buyStake", "targets": ["steel"]],
                                                                        ["verb": "fixNumbers"]]], engine: e, planID: 1)
        XCTAssertFalse(out.isError, out.text)
        let steps = try XCTUnwrap(out.plan?.steps)
        XCTAssertEqual(steps.count, 2)
        for s in steps { guard case .plan = s.outcome else { return XCTFail("\(s.outcome)") } }
        XCTAssertTrue(out.text.contains("NOTHING HAS BEEN EXECUTED"))
    }

    func testEconomyToolShowsOfficialFigures() throws {
        let e = HomeFixtures.engine()
        HomeFixtures.run(e, "fire the chief statistician")
        let text = ChatTools.run("economy", arguments: [:], engine: e).text
        XCTAssertTrue(text.contains("official"))
        let gs = try XCTUnwrap(e.gameState)
        XCTAssertTrue(text.contains("\(ChatTools.round1(gs.officialEconomy.growth))"), "the chief sees what the President sees")
    }
}

// MARK: - Saves and determinism

@MainActor
final class HomeFrontSaveTests: XCTestCase {
    func testOlderSavesLoadWithDefaults() throws {
        let old = try JSONDecoder().decode(ShadowState.self, from: Data(#"{"popularity": 44}"#.utf8))
        XCTAssertFalse(old.homeFront.isActive)
        let partial = try JSONDecoder().decode(HomeFrontState.self, from: Data(#"{"firings": 2, "inflation": 3.5}"#.utf8))
        XCTAssertEqual(partial.firings, 2)
        XCTAssertEqual(partial.inflation, 3.5)
        XCTAssertTrue(partial.stakes.isEmpty)
    }

    func testRoundTrip() throws {
        let e = HomeFixtures.engine()
        let gs = try XCTUnwrap(e.gameState)
        HomeFixtures.run(e, "fire the chief statistician")
        HomeFixtures.run(e, "buy a stake in steel")
        HomeFixtures.run(e, "build a missile shield")
        HomeFixtures.run(e, "conduct an underground nuclear test")
        HomeFixtures.run(e, "repeal the 22nd amendment")
        let data = try JSONEncoder().encode(gs)
        let back = try JSONDecoder().decode(GameState.self, from: data)
        let a = gs.shadow.homeFront, b = back.shadow.homeFront
        XCTAssertEqual(b.statisticianFired, a.statisticianFired)
        XCTAssertEqual(b.stakes, a.stakes)
        XCTAssertEqual(b.shieldReady, a.shieldReady)
        XCTAssertEqual(b.tests, a.tests)
        XCTAssertEqual(b.bid, a.bid)
    }

    func testUnusedHomeFrontDrawsNothing() throws {
        let e = HomeFixtures.engine()
        let gs = try XCTUnwrap(e.gameState)
        let rng = gs.rng
        HomeFixtures.turns(e, 12)
        XCTAssertEqual(gs.rng.state, rng.state, "a game that never uses them plays as before")
    }

    func testSameSeedSameOrdersSameOutcome() throws {
        func play() throws -> (Double, UInt64, Int, Double?) {
            let e = HomeFixtures.engine(seed: 99)
            let gs = try XCTUnwrap(e.gameState)
            HomeFixtures.run(e, "fire the chief statistician")
            HomeFixtures.run(e, "pressure the fed")
            HomeFixtures.run(e, "buy a stake in steel")
            HomeFixtures.run(e, "buy a stake in oil")
            HomeFixtures.turns(e, 36)
            return (gs.shadow.popularity, gs.rng.state, gs.shadow.homeFront.scandals, gs.shadow.homeFront.leakedGrowth)
        }
        let a = try play(), b = try play()
        XCTAssertEqual(a.0, b.0)
        XCTAssertEqual(a.1, b.1)
        XCTAssertEqual(a.2, b.2)
        XCTAssertEqual(a.3, b.3)
    }

    func testNewStringsFollowTheContentRules() {
        let e = HomeFixtures.engine()
        var texts = HomePlay.allCases.flatMap { [$0.title, $0.toolLine] } + [DomesticEnding.ruleExtended.headline]
        for cmd in ["fire the chief statistician", "pressure the fed", "overrule the fed", "buy a stake in steel", "postpone the election",
                    "repeal the 22nd amendment", "build a missile shield", "conduct an atmospheric nuclear test", "send federal troops into Texas"] {
            switch CmdFixtures.plan(e, cmd) {
            case .plan(let p):
                texts += [p.title, p.target] + p.committed + p.warnings.map(\.text)
                e.gameState?.actionsUsedThisTurn = 0
                e.executeCommand(p.orders, source: .parser)
            case .rejected(let w): texts.append(w)
            default: break
            }
        }
        texts += e.gameState?.shadow.ticker.map(\.text) ?? []
        for t in texts {
            let low = t.lowercased()
            for w in R331.banned { XCTAssertFalse(low.contains(w), "\"\(w)\" in: \(t)") }
            for host in ["localhost", "127.0.0.1", "http"] { XCTAssertFalse(low.contains(host), t) }
        }
    }
}
