//
//  ReportBooksTests.swift
//  GTNWTests
//
//  3.36.0: regression tests for the bugs Nova's game reports found (ReportBooks.swift): claimed land that "paid $0",
//  approval that jumped 48 → 95 in a poll with no reason given, seven wars won and none started, Greenland garbled by
//  the chief of staff, and "claim all of Africa" turned down. Unit, functional and save round-trip.
//

import XCTest
@testable import GTNW

@MainActor
enum RB {
    static func engine(year: Int, turn: TurnLength = .month, player: String = "USA", seed: UInt64 = 7) -> (GameEngine, GameState) {
        let e = GameEngine()
        e.startNewGame(playerCountryID: player, turnLength: turn, year: year, seed: seed)
        e.crisisManager.activeCrisis = nil
        e.crisisManager.pendingCrises = []
        return (e, e.gameState!)
    }

    /// A one-option crisis card that always works.
    static func card(_ title: String, approval: Int) -> CrisisEvent {
        CrisisEvent(type: .falseAlarm, severity: .moderate, title: title, description: "A test card.", affectedCountries: [], turn: 0,
                    options: [CrisisOption(title: "Act", description: "Act.", consequences: CrisisConsequences(approvalChange: approval, message: "Done."),
                                           successChance: 1)])
    }

    static func resolve(_ e: GameEngine, _ card: CrisisEvent) {
        e.crisisManager.activeCrisis = card
        var gs = e.gameState!
        e.crisisManager.resolveCrisis(optionIndex: 0, gameState: &gs)
        e.gameState = gs
    }

    static func summary(_ gs: GameState) -> [String: Any] {
        let d = PlaySummary.build(gs, session: .init(id: UUID(), startTurn: 0, resumedFromTurn: nil, gameDateAtStart: ""))
        return (try? JSONSerialization.jsonObject(with: d)) as? [String: Any] ?? [:]
    }

    /// End turns until a new poll is taken; returns it.
    static func nextPoll(_ e: GameEngine) -> PollRecord? {
        let gs = e.gameState!
        let n = gs.shadow.polls.count
        for _ in 0..<10 {
            e.crisisManager.activeCrisis = nil
            e.crisisManager.pendingCrises = []
            e.endTurn()
            if gs.shadow.polls.count > n { return gs.shadow.polls.last }
        }
        return nil
    }
}

// MARK: - Unit

final class ReportBooksUnitTests: XCTestCase {
    /// Unit: a card moves approval at most ±10 and good news never lifts it past 90.
    func testCardApprovalIsCappedAndCeilinged() {
        XCTAssertEqual(PopularityModel.cardEffect(25, current: 48.3), 10)
        XCTAssertEqual(PopularityModel.cardEffect(25, current: 85), 5, accuracy: 1e-9)
        XCTAssertEqual(PopularityModel.cardEffect(8, current: 95), 0, "a rise never becomes a fall")
        XCTAssertEqual(PopularityModel.cardEffect(-30, current: 50), -10)
        XCTAssertEqual(PopularityModel.cardEffect(-3, current: 50), -3)
    }

    /// Unit: a poll's main cause is the biggest move in the same direction; what nothing recorded is "other events".
    func testPollCauseIsTheBiggestMoveTheSameWay() {
        var sh = ShadowState()
        sh.popularity = 50
        sh.moveApproval(9, because: "the decision on \"A\"")
        sh.moveApproval(-2, because: "land claims")
        sh.noteApproval(1, because: PopularityModel.driftCause)
        XCTAssertEqual(sh.popularity, 57)
        XCTAssertEqual(sh.pollCause(change: 8), "the decision on \"A\"")
        XCTAssertEqual(sh.pollCause(change: 30), "other events", "22 points nothing recorded outweigh the 9 that were")
        XCTAssertEqual(sh.pollCause(change: -12), "other events")
        sh.books.approvalCauses = [:]
        XCTAssertEqual(sh.pollCause(change: 0.5), PopularityModel.driftCause, "nothing at all: the mood")
    }

    /// Unit: science is prestige, not money; a fresh claim develops over 24 months, an investment buys six.
    @MainActor
    func testLandMoneyAndDevelopmentMonths() throws {
        XCTAssertEqual(LandDevelopment.money(ResourceDeposit(kind: .science, from: 1957, value: 0.5)), 0)
        XCTAssertEqual(LandDevelopment.money(ResourceDeposit(kind: .whaling, from: 1789, value: 1.5)), 1.5)
        let (e, gs) = RB.engine(year: 1890)
        XCTAssertTrue(e.claimLand("CMR"))
        XCTAssertEqual(LandDevelopment.monthsToDevelop("CMR", in: gs), 24)
        gs.shadow.books.developed["CMR"] = 0.5
        XCTAssertEqual(LandDevelopment.monthsToDevelop("CMR", in: gs), 18)
        XCTAssertEqual(LandDevelopment.monthsToDevelop("FRA", in: gs), 0, "land held from the start counts as developed")
        let cmr = try XCTUnwrap(gs.getCountry(id: "CMR"))
        XCTAssertGreaterThan(ExpansionModel.annualIncome(cmr, in: gs, developed: true), 0.05)
        XCTAssertGreaterThanOrEqual(LandDevelopment.investCost(cmr, in: gs), 5 * ClaimCampaigns.landingCost(year: 1890) - 1e-9)
    }

    /// Unit: "all of Africa" reaches the planner as a region; "invest in" is the new order.
    func testParserReadsRegionsAndInvest() {
        XCTAssertEqual(CommandParser.parse("claim all of Africa")?.targets, ["africa"])
        XCTAssertEqual(CommandParser.parse("buy the whole of Asia")?.targets, ["asia"])
        XCTAssertEqual(CommandParser.parse("claim all of the Middle East")?.targets, ["middle east"])
        XCTAssertEqual(CommandParser.parse("invest in Madagascar")?.verb, .develop)
        XCTAssertEqual(CommandParser.parse("invest in Madagascar")?.targets, ["madagascar"])
        XCTAssertEqual(CommandParser.parse("attack France with all forces")?.targets, ["france"], "the force word still ends a name")
    }

    /// Unit: a region's lands for a land verb come from each land's own template, and only what the verb can take.
    @MainActor
    func testRegionLandsAreDataDrivenAndTakeable() {
        let (e, gs) = RB.engine(year: 1890)
        let claim = CommandTargets.regionLands(.africa, verb: .claim, in: gs, engine: e)
        XCTAssertGreaterThan(claim.count, 10)
        for t in claim {
            XCTAssertTrue(gs.claimableLandIDs.contains(t.id), t.id)
            XCTAssertEqual(ClaimCampaigns.region(of: t.id), .africa, t.id)
        }
        let buy = CommandTargets.regionLands(.asia, verb: .buy, in: gs, engine: e)
        XCTAssertFalse(buy.isEmpty)
        for t in buy { XCTAssertNotNil(e.colonyTarget(t.id), t.id) }
        XCTAssertTrue(CommandTargets.regionLands(.africa, verb: .sanction, in: gs, engine: e).isEmpty)
    }
}

// MARK: - Functional

final class ReportBooksFunctionalTests: XCTestCase {
    /// Regression (1923 sandbox, Dec 1): two good crisis cards in one month took approval from 48.3 to 94.8 with no
    /// reason in the log. Now each moves it at most 10, and the poll names the cause.
    @MainActor
    func testGoodNewsCannotDoubleApprovalAndThePollSaysWhy() throws {
        let (e, gs) = RB.engine(year: 1923, turn: .week)
        gs.shadow.popularity = 48.3
        gs.shadow.books.approvalCauses = [:]
        RB.resolve(e, RB.card("Treaty Triumph", approval: 25))
        RB.resolve(e, RB.card("Hero's Welcome", approval: 20))
        XCTAssertLessThanOrEqual(gs.shadow.popularity, 68.3 + 1e-9, "two cards, ten points each at most")
        XCTAssertGreaterThan(gs.shadow.popularity, 60)
        let poll = try XCTUnwrap(RB.nextPoll(e))
        XCTAssertLessThan(poll.popularity, 70)
        let cause = try XCTUnwrap(poll.cause, "a move over 10 points names its cause")
        XCTAssertTrue(cause.hasPrefix("the decision on"), cause)
        XCTAssertTrue(gs.shadow.ticker.contains { $0.text.contains("Main cause: the decision on") && $0.severity >= 2 },
                      "in the news, at a severity the play history keeps")
        let polls = try XCTUnwrap(RB.summary(gs)["polls"] as? [[String: Any]])
        XCTAssertTrue(polls.contains { ($0["cause"] as? String)?.hasPrefix("the decision on") == true }, "Nova's report data has it")
        // A quiet month names no cause.
        let quiet = try XCTUnwrap(RB.nextPoll(e))
        if abs(quiet.popularity - poll.popularity) <= PopularityModel.explainedPollMove { XCTAssertNil(quiet.cause) }
    }

    /// Every poll that moves more than 10 points in a long game says why.
    @MainActor
    func testEveryBigPollMoveHasACause() {
        let (e, gs) = RB.engine(year: 1962, seed: 11)
        for _ in 0..<36 {
            if gs.gameOver { break }
            e.crisisManager.activeCrisis = nil
            e.crisisManager.pendingCrises = []
            if gs.turn == 3 { e.declareWar(aggressor: "USA", defender: "CUB") }
            e.endTurn()
        }
        for (a, b) in zip(gs.shadow.polls, gs.shadow.polls.dropFirst()) where abs(b.popularity - a.popularity) > PopularityModel.explainedPollMove {
            XCTAssertNotNil(b.cause, "\(a.popularity) → \(b.popularity)")
        }
    }

    /// Regression (1797/1913 reports): claimed land said "now producing timber" with income 0. It shows when it
    /// develops and its full-output income, pays once developed, and INVEST brings it closer.
    @MainActor
    func testClaimedLandShowsWhenItPaysAndInvestmentSpeedsIt() throws {
        let (e, gs) = RB.engine(year: 1913)
        XCTAssertTrue(e.claimLand("GAB"))
        let gab = try XCTUnwrap(gs.getCountry(id: "GAB"))
        let note = try XCTUnwrap(LandDevelopment.note(gab, in: gs))
        XCTAssertTrue(note.hasPrefix("Develops in 24 months"), note)
        XCTAssertFalse(note.contains("$0.00B a year at full"), note)
        // Invest: one action, era-priced, six months closer.
        gs.actionsUsedThisTurn = 0
        gs.shadow.aidRemaining = 10
        let cost = LandDevelopment.investCost(gab, in: gs)
        XCTAssertNil(LandDevelopment.problem("GAB", in: gs))
        XCTAssertTrue(e.investInLand("GAB"))
        XCTAssertEqual(gs.shadow.aidRemaining, 10 - cost, accuracy: 1e-9)
        XCTAssertEqual(gs.actionsUsedThisTurn, 1)
        XCTAssertEqual(LandDevelopment.monthsToDevelop("GAB", in: gs), 18)
        // It starts producing a month later (bought six months covers the six-month wait) and says what it will pay.
        gs.turn += 1
        e.processTerritoryEconomy()
        let line = try XCTUnwrap(gs.shadow.ticker.last { $0.text.contains("is now producing") && $0.text.contains(gab.name) }?.text)
        XCTAssertTrue(line.contains("a year at full output, reached in"), line)
        XCTAssertFalse(line.contains("$0.00B"), line)
        // Four years on it pays its full rate into the funds.
        for _ in 0..<48 { gs.turn += 1; e.processTerritoryEconomy() }
        XCTAssertNil(LandDevelopment.note(try XCTUnwrap(gs.getCountry(id: "GAB")), in: gs), "developed: nothing more to say")
        XCTAssertGreaterThan(gs.shadow.resourceEarnings, 1)
        XCTAssertNotNil(LandDevelopment.problem("GAB", in: gs), "nothing left to invest in")
        let s = RB.summary(gs)
        XCTAssertGreaterThan(s["land_income_b_per_year"] as? Double ?? 0, 0.1)
        XCTAssertGreaterThan(s["land_earned_b"] as? Double ?? 0, 1)
    }

    /// INVEST is an order: the command box and the chief of staff can give it, on the President's own land only.
    @MainActor
    func testInvestIsAnOrder() throws {
        let (e, gs) = RB.engine(year: 1913)
        XCTAssertTrue(e.claimLand("MDG"))
        gs.actionsUsedThisTurn = 0
        gs.shadow.aidRemaining = 10
        let p = try XCTUnwrap(CmdFixtures.confirmedPlan(e, "invest in Madagascar"))
        XCTAssertEqual(p.orders, [GameOrder(kind: .developLand, target: "MDG")])
        let run = e.executeCommand(p.orders, source: .parser)
        XCTAssertEqual(run.carried.count, 1)
        XCTAssertEqual(LandDevelopment.monthsToDevelop("MDG", in: gs), 18)
        XCTAssertNotNil(e.orderProblem(GameOrder(kind: .developLand, target: "FRA")), "not the President's land")
        XCTAssertEqual(e.orderProblem(GameOrder(kind: .claimLand, target: "MDG", troops: 5)) != nil, true)
        let out = ChatTools.run("propose_orders", arguments: ["steps": [["verb": "develop", "targets": ["Madagascar"]]]], engine: e, planID: 1)
        XCTAssertFalse(out.isError, out.text)
    }

    /// Antarctica pays no money in the Treaty years unless developed, and says so plainly.
    @MainActor
    func testAntarcticaPaysNothingUnlessDeveloped() throws {
        let (e, gs) = RB.engine(year: 2025)
        XCTAssertTrue(ChatTools.run("country", arguments: ["name": "Antarctica"], engine: e).text.contains("pays no money unless developed"))
        XCTAssertTrue(e.claimLand("ATA"))
        let ata = try XCTUnwrap(gs.getCountry(id: "ATA"))
        XCTAssertEqual(ExpansionModel.annualIncome(ata, in: gs, developed: true), 0, "science is prestige, not money")
        XCTAssertTrue(try XCTUnwrap(LandDevelopment.note(ata, in: gs)).hasPrefix("Pays no money unless developed"))
        gs.actionsUsedThisTurn = 0
        XCTAssertTrue(e.investInLand("ATA"))
        XCTAssertGreaterThan(ExpansionModel.annualIncome(try XCTUnwrap(gs.getCountry(id: "ATA")), in: gs, developed: true), 0)
        // Before the Treaty, whaling pays, and the note says it.
        let (e2, gs2) = RB.engine(year: 1923)
        XCTAssertTrue(e2.claimLand("ATA"))
        let old = try XCTUnwrap(LandDevelopment.note(try XCTUnwrap(gs2.getCountry(id: "ATA")), in: gs2))
        XCTAssertTrue(old.hasPrefix("Whaling and sealing pay"), old)
    }

    /// Regression (1829 report): seven wars won, "wars started: 0". Declarations count; won as attacker, as
    /// defender and lost are kept; the summary matches the war log.
    @MainActor
    func testWarBooksMatchTheWarLog() throws {
        let (e, gs) = RB.engine(year: 2025)
        XCTAssertTrue(e.executeOrder(GameOrder(kind: .declareWar, target: "CUB")))
        XCTAssertEqual(gs.warsStarted, 1)
        XCTAssertEqual(gs.shadow.playerWarsStarted, 1)
        e.syncFronts()
        let i = try XCTUnwrap(gs.shadow.fronts.firstIndex { $0.defender == "CUB" && $0.status == .fighting })
        e.resolveFront(index: i, verdict: .attackerWon)
        XCTAssertEqual(gs.warsWon, 1)
        XCTAssertEqual(gs.shadow.books.warsWonAttacking, 1)
        // A war on the President, beaten back.
        e.declareWar(aggressor: "VEN", defender: "USA")
        e.syncFronts()
        let j = try XCTUnwrap(gs.shadow.fronts.firstIndex { $0.attacker == "VEN" && $0.status == .fighting })
        e.resolveFront(index: j, verdict: .defenderWon)
        XCTAssertEqual(gs.shadow.books.warsWonDefending, 1)
        XCTAssertEqual(gs.warsStarted, 1, "a war declared on the President is not one he started")
        let s = RB.summary(gs)
        XCTAssertEqual(s["wars_started"] as? Int, 1)
        XCTAssertEqual(s["wars_won"] as? Int, 2)
        XCTAssertEqual(s["wars_won_as_attacker"] as? Int, 1)
        XCTAssertEqual(s["wars_won_as_defender"] as? Int, 1)
        XCTAssertEqual(s["wars_lost"] as? Int, 0)
        // Wars between other nations' alliances are not the President's.
        let before = gs.warsStarted
        e.declareWar(aggressor: "RUS", defender: "POL")
        XCTAssertEqual(gs.warsStarted, before)
    }

    /// Regression (2025 chat): Greenland is part of Denmark; the country tool says so in one plain line, and an order
    /// naming it asks before aiming at Denmark.
    @MainActor
    func testGreenlandIsPlainlyDenmarks() throws {
        let (e, gs) = RB.engine(year: 2025)
        let out = ChatTools.run("country", arguments: ["name": "Greenland"], engine: e).text
        XCTAssertTrue(out.contains("Greenland: part of Denmark in 2025"), out)
        XCTAssertFalse(out.contains("unclaimed"), out)
        guard case .one(.nation("DNK"), let note) = CommandTargets.resolve("Greenland", in: gs) else { return XCTFail("Greenland → Denmark") }
        XCTAssertEqual(note, "Greenland is part of Denmark in 2025, not a separate land.")
        // Every dossier carries a plain status.
        XCTAssertTrue(ChatTools.run("country", arguments: ["name": "France"], engine: e).text.contains("France: an independent nation in 2025."))
        XCTAssertTrue(ChatTools.run("country", arguments: ["name": "Antarctica"], engine: e).text.contains("Antarctica: unclaimed land"))
        XCTAssertTrue(e.claimLand("ATA"))
        XCTAssertTrue(ChatTools.run("country", arguments: ["name": "Antarctica"], engine: e).text.contains("Antarctica: your territory."))
        // Puerto Rico is a U.S. territory on the board, not "part of" anything: the normal dossier.
        XCTAssertNil(CommandTargets.partOf("France", in: gs))
    }

    /// "Claim all of Africa": every free land there, nations left out, one action each.
    @MainActor
    func testClaimAllOfAfricaTakesItsFreeLands() throws {
        let (e, gs) = RB.engine(year: 1890)
        let p = try XCTUnwrap(CmdFixtures.confirmedPlan(e, "claim all of Africa"))
        XCTAssertGreaterThan(p.orders.count, 10)
        XCTAssertTrue(p.orders.allSatisfy { $0.kind == .claimLand })
        XCTAssertTrue(p.orders.allSatisfy { gs.claimableLandIDs.contains($0.target) })
        XCTAssertTrue(p.warnings.contains { $0.text.hasPrefix("Needs ") })
        let run = e.executeCommand(p.orders, source: .parser)
        XCTAssertGreaterThanOrEqual(run.carried.count, 1)
        XCTAssertLessThanOrEqual(run.carried.count, 2, "two actions a month")
        XCTAssertEqual(run.carried.count + run.refused.count + run.notReached.count, p.orders.count)
        // Buying a region's colonies; a region with nothing to take is a plain refusal.
        let (e2, _) = RB.engine(year: 1890)
        let buy = try XCTUnwrap(CmdFixtures.confirmedPlan(e2, "buy all of Asia"))
        XCTAssertTrue(buy.orders.allSatisfy { $0.kind == .buyColony })
        let (e3, _) = RB.engine(year: 2025)
        guard case .rejected(let why) = e3.planCommand(CommandParser.parse("claim all of Africa")!, source: .parser) else { return XCTFail() }
        XCTAssertTrue(why.contains("No land in Africa"), why)
    }

    /// Content: every new line is plain English with no hostnames.
    @MainActor
    func testNewTextIsPlain() throws {
        let (e, gs) = RB.engine(year: 1913)
        XCTAssertTrue(e.claimLand("GAB"))
        let lines = [LandDevelopment.note(try XCTUnwrap(gs.getCountry(id: "GAB")), in: gs) ?? "", PopularityModel.driftCause,
                     CommandTargets.ownershipLine(.unclaimed("ATA"), in: gs, engine: e)]
        for l in lines {
            XCTAssertFalse(l.isEmpty)
            XCTAssertNil(l.range(of: #"\d+\.\d+\.\d+\.\d+|https?:"#, options: .regularExpression), l)
            XCTAssertFalse(l.contains("colour") || l.contains("favour"), "American spelling: \(l)")
        }
    }
}

// MARK: - Saves

final class ReportBooksSaveTests: XCTestCase {
    /// The books and a poll's cause survive a save; older saves without them load with empty books.
    @MainActor
    func testBooksRoundTripAndOldSavesLoad() throws {
        let (e, gs) = RB.engine(year: 1913)
        XCTAssertTrue(e.claimLand("GAB"))
        gs.shadow.books.developed["GAB"] = 0.5
        gs.shadow.books.warsWonAttacking = 3
        gs.shadow.books.approvalCauses["land claims"] = -1.5
        gs.shadow.polls.append(PollRecord(date: gs.currentDate, popularity: 61, cause: "the decision on \"X\""))
        let back = try JSONDecoder().decode(GameState.self, from: try JSONEncoder().encode(gs))
        XCTAssertEqual(back.shadow.books, gs.shadow.books)
        XCTAssertEqual(back.shadow.polls.last?.cause, "the decision on \"X\"")
        XCTAssertEqual(LandDevelopment.monthsToDevelop("GAB", in: back), LandDevelopment.monthsToDevelop("GAB", in: gs))
        // An older save: no books, polls without causes.
        var obj = try XCTUnwrap(JSONSerialization.jsonObject(with: try JSONEncoder().encode(gs.shadow)) as? [String: Any])
        obj["books"] = nil
        obj["polls"] = [["date": 0, "popularity": 50]]
        let old = try JSONDecoder().decode(ShadowState.self, from: try JSONSerialization.data(withJSONObject: obj))
        XCTAssertEqual(old.books, ReportBooks())
        XCTAssertNil(old.polls.first?.cause)
        XCTAssertEqual(try JSONDecoder().decode(ReportBooks.self, from: Data("{}".utf8)), ReportBooks())
    }
}
