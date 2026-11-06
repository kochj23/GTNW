//
//  ElectionCycleTests.swift
//  GTNWTests
//
//  3.21.0: the full election cycle — historical rules, the calendar, term limits, the Electoral College,
//  lame ducks, and election decisions that never get dropped.
//

import XCTest
@testable import GTNW

final class ElectionRulesTests: XCTestCase {

    private func ymd(_ d: Date) -> String { GameCalendar.format(d) }

    func testInaugurationMovedFromMarchToJanuaryWithThe20thAmendment() {
        XCTAssertEqual(ymd(ElectionRules(year: 1932).inauguration), "Mar 4, 1933")
        XCTAssertEqual(ymd(ElectionRules(year: 1936).inauguration), "Jan 20, 1937")
        XCTAssertEqual(ymd(ElectionRules(year: 2028).inauguration), "Jan 20, 2029")
    }

    func testElectoralCollegeSizesAndMajorities() {
        XCTAssertEqual(ElectionHistory.electors(1800), 138)
        XCTAssertEqual(ElectionHistory.majority(1800), 70)
        XCTAssertEqual(ElectionHistory.electors(1960), 537)
        XCTAssertEqual(ElectionHistory.electors(1964), 538)
        XCTAssertEqual(ElectionHistory.majority(2024), 270)
        XCTAssertEqual(ElectionHistory.electors(2040), 538)
    }

    func testNominationMethodFollowsHistory() {
        XCTAssertEqual(NominationMethod.forYear(1792), .acclamation)
        XCTAssertEqual(NominationMethod.forYear(1816), .congressionalCaucus)
        XCTAssertEqual(NominationMethod.forYear(1828), .stateLegislatures)
        XCTAssertEqual(NominationMethod.forYear(1860), .convention)
        XCTAssertEqual(NominationMethod.forYear(1952), .conventionAndPrimaries)
        XCTAssertEqual(NominationMethod.forYear(1976), .primaries)
    }

    func testStagesOnlyExistInTheirEras() {
        XCTAssertNil(ElectionCycle.date(of: .iowa, year: 1968))
        XCTAssertNotNil(ElectionCycle.date(of: .iowa, year: 1972))
        XCTAssertNil(ElectionCycle.date(of: .superTuesday, year: 1984))
        XCTAssertNotNil(ElectionCycle.date(of: .superTuesday, year: 1988))
        XCTAssertNotNil(ElectionCycle.date(of: .debate1, year: 1960))
        XCTAssertNil(ElectionCycle.date(of: .debate1, year: 1968))
        XCTAssertNotNil(ElectionCycle.date(of: .debate1, year: 1976))
        XCTAssertNil(ElectionCycle.date(of: .vpDebate, year: 1980))
        XCTAssertNil(ElectionCycle.date(of: .runningMate, year: 1800), "no tickets before the 12th Amendment")
        XCTAssertNil(ElectionCycle.date(of: .electionNight, year: 2026), "no presidential election in a midterm year")
        XCTAssertNotNil(ElectionCycle.date(of: .midtermNight, year: 2026))
        XCTAssertEqual(ymd(ElectionCycle.date(of: .electionNight, year: 2028)!), "Nov 7, 2028")
    }

    func testAFullModernCycleRunsInOrder() {
        let s = ElectionCycle.stages(from: GameCalendar.date(year: 2027, month: 1, day: 1),
                                     to: GameCalendar.date(year: 2029, month: 2, day: 1))
        let order = s.map(\.stage)
        for stage: ElectionStage in [.decision, .iowa, .newHampshire, .superTuesday, .convention, .debate1, .electionNight, .count, .inauguration] {
            XCTAssertTrue(order.contains(stage), "\(stage) missing")
        }
        XCTAssertLessThan(order.firstIndex(of: .iowa)!, order.firstIndex(of: .newHampshire)!)
        XCTAssertLessThan(order.firstIndex(of: .opponentConvention)!, order.firstIndex(of: .convention)!, "the White House party goes second")
        XCTAssertEqual(order.last, .inauguration)
        XCTAssertEqual(zip(s, s.dropFirst()).filter { $0.date > $1.date }.count, 0, "sorted by date")
    }

    func testOpponentsAreHistorysNominees() {
        XCTAssertEqual(ElectionCycle.opponentName(year: 1980, party: .democratic, incumbent: "Jimmy Carter"), "Ronald Reagan")
        XCTAssertEqual(ElectionCycle.opponentName(year: 1976, party: .republican, incumbent: "Gerald Ford"), "Jimmy Carter")
        XCTAssertEqual(ElectionCycle.opponentName(year: 1860, party: .democratic, incumbent: "James Buchanan"), "Abraham Lincoln")
        XCTAssertFalse(ElectionCycle.opponentName(year: 2032, party: .republican, incumbent: "x").isEmpty)
        XCTAssertEqual(PartyCode.from(label: "Whig (expelled)"), .whig)
        XCTAssertEqual(PartyCode.from(label: "Democratic-Republican"), .democraticRepublican)
        XCTAssertEqual(PartyCode.democratic.opposition(in: 1840), .whig)
    }

    func testHistoricalPrimaryChallengers() {
        XCTAssertEqual(ElectionCycle.intraPartyChallenger(year: 1980, party: .democratic, popularity: 60, roll: 0.99)?.0, "Sen. Ted Kennedy")
        XCTAssertNil(ElectionCycle.intraPartyChallenger(year: 1984, party: .republican, popularity: 60, roll: 0.5),
                     "a popular President draws no challenger")
        XCTAssertNotNil(ElectionCycle.intraPartyChallenger(year: 2028, party: .republican, popularity: 20, roll: 0.1),
                        "an unpopular one usually does")
    }
}

final class TermLimitTests: XCTestCase {

    private func campaign(_ president: String, gameStart: Int) -> CampaignState {
        var c = CampaignState()
        let admin = Advisor.allAdministrations().last { $0.president == president && $0.startYear <= gameStart }
        ElectionCycle.seed(&c, administration: admin, start: GameCalendar.inauguration(year: gameStart))
        return c
    }

    func testReaganInHisSecondTermIsTermLimited() {
        let first = campaign("Ronald Reagan", gameStart: 1981)
        XCTAssertEqual(first.electedBeforeStart, 1)
        XCTAssertFalse(ElectionCycle.termLimited(first, termsWon: 0, year: 1984))
        XCTAssertTrue(ElectionCycle.termLimited(first, termsWon: 1, year: 1988))
        let second = campaign("Ronald Reagan", gameStart: 1985)
        XCTAssertEqual(second.electedBeforeStart, 2)
        XCTAssertTrue(ElectionCycle.termLimited(second, termsWon: 0, year: 1988))
    }

    func testTrumpsSecondNonConsecutiveTermIsHisLast() {
        let c = campaign("Donald Trump", gameStart: 2025)
        XCTAssertEqual(c.electedBeforeStart, 2)
        XCTAssertTrue(ElectionCycle.termLimited(c, termsWon: 0, year: 2028))
    }

    func testTrumanWasExemptAndFordGetsOneElection() {
        let truman = campaign("Harry S. Truman", gameStart: 1949)
        XCTAssertFalse(ElectionCycle.termLimited(truman, termsWon: 0, year: 1952))
        let ford = campaign("Gerald Ford", gameStart: 1975)
        XCTAssertEqual(ford.electedBeforeStart, 0)
        XCTAssertFalse(ElectionCycle.termLimited(ford, termsWon: 0, year: 1976))
        XCTAssertTrue(ElectionCycle.termLimited(ford, termsWon: 1, year: 1980))
        let lbj = campaign("Lyndon B. Johnson", gameStart: 1965)
        XCTAssertFalse(ElectionCycle.termLimited(lbj, termsWon: 0, year: 1968), "14 months of Kennedy's term: LBJ could run in 1968")
    }

    func testNoTermLimitsBefore1952() {
        var c = CampaignState()
        c.electedBeforeStart = 3
        XCTAssertFalse(ElectionCycle.termLimited(c, termsWon: 0, year: 1944))
        XCTAssertLessThan(ElectionCycle.voteShare(popularity: 60, termsWon: 0, campaign: c, year: 1944, noise: 0),
                          ElectionCycle.voteShare(popularity: 60, termsWon: 0, campaign: CampaignState(), year: 1944, noise: 0),
                          "breaking the two-term tradition costs votes")
    }
}

final class ElectoralCollegeTests: XCTestCase {

    func testALandslideAndAClose() {
        let big = ElectionCycle.tally(year: 2028, twoPartyShare: 59)
        XCTAssertGreaterThan(big.playerEV, 450)
        XCTAssertEqual(big.outcome, .won)
        let loss = ElectionCycle.tally(year: 2028, twoPartyShare: 46)
        XCTAssertEqual(loss.outcome, .lost)
        XCTAssertEqual(loss.playerEV + loss.opponentEV + loss.thirdEV, 538)
    }

    func testPopularVoteWinnerCanLoseTheCollege() {
        let t = ElectionCycle.tally(year: 2016, twoPartyShare: 50.6, stateNoise: -1)
        XCTAssertGreaterThan(t.playerPopular, t.opponentPopular)
        XCTAssertEqual(t.outcome, .lost)
    }

    func testAStrongThirdPartyCanThrowItToTheHouse() {
        let t = ElectionCycle.tally(year: 1968, twoPartyShare: 50, thirdPopular: 25)
        XCTAssertGreaterThan(t.thirdEV, 0)
        XCTAssertEqual(t.outcome, .noMajority)
    }

    func testMidtermsUsuallyCostThePresidentsParty() {
        XCTAssertLessThan(ElectionCycle.midtermSeats(popularity: 50, effort: 0, atWar: false, noise: 0), -15)
        XCTAssertGreaterThan(ElectionCycle.midtermSeats(popularity: 72, effort: 8, atWar: false, noise: 0), 0, "1934, 1998, 2002")
    }
}

final class ElectionEngineTests: XCTestCase {

    @MainActor
    func testTermLimitedPresidentIsWarnedThenLeavesOnInaugurationDay() {
        let engine = GameEngine()
        engine.startNewGame(turnLength: .month)   // Trump, 2025: his second term
        let gs = engine.gameState!
        gs.shadow.electionsEnabled = true
        XCTAssertEqual(gs.shadow.campaign.electedBeforeStart, 2)
        XCTAssertTrue(gs.shadow.ticker.contains { $0.text.contains("22nd Amendment") }, "warned at the start")

        engine.processElectionCycle(from: GameCalendar.date(year: 2027, month: 4, day: 1), to: GameCalendar.date(year: 2027, month: 5, day: 1))
        XCTAssertEqual(gs.shadow.campaign.leaveReason, .termLimited)
        XCTAssertEqual(GameCalendar.format(gs.shadow.campaign.leaveOfficeOn!), "Jan 20, 2029")
        XCTAssertNil(gs.shadow.domesticEnding, "still President until noon on Inauguration Day")

        engine.processElectionCycle(from: GameCalendar.date(year: 2028, month: 10, day: 30), to: GameCalendar.date(year: 2029, month: 1, day: 25))
        XCTAssertEqual(gs.shadow.lastElection?.playerName, "Your party's nominee")
        XCTAssertEqual(gs.shadow.domesticEnding, .termLimited)
    }

    @MainActor
    func testLosingMakesALameDuckNotAnInstantGameOver() {
        let engine = GameEngine()
        engine.startNewGame(turnLength: .month, year: 1981)   // Reagan's first term
        let gs = engine.gameState!
        gs.shadow.electionsEnabled = true
        gs.shadow.popularity = 5
        engine.holdElection(on: GameCalendar.electionDay(year: 1984))
        XCTAssertEqual(gs.shadow.lastElection?.won, false)
        XCTAssertEqual(gs.shadow.lastElection?.opponentName, "Walter Mondale")
        XCTAssertNotNil(gs.shadow.lastElection?.playerEV)
        XCTAssertNil(gs.shadow.domesticEnding)
        XCTAssertEqual(gs.shadow.campaign.leaveReason, .lostElection)
        engine.processElectionCycle(from: GameCalendar.date(year: 1984, month: 11, day: 10), to: GameCalendar.date(year: 1985, month: 1, day: 25))
        XCTAssertEqual(gs.shadow.domesticEnding, .lostElection)
    }

    @MainActor
    func testTheDecisionToRunIsADecision() {
        let engine = GameEngine()
        engine.startNewGame(turnLength: .month, year: 1981)
        let gs = engine.gameState!
        gs.shadow.electionsEnabled = true
        engine.crisisManager.activeCrisis = nil
        engine.crisisManager.pendingCrises = []
        engine.processElectionCycle(from: GameCalendar.date(year: 1983, month: 4, day: 1), to: GameCalendar.date(year: 1983, month: 5, day: 1))
        let card = engine.crisisManager.activeCrisis
        XCTAssertEqual(card?.type, .election)
        XCTAssertTrue(card?.options.contains { $0.consequences.electionChoice == "retire" } ?? false)

        // Retiring makes a lame duck who leaves on Inauguration Day 1985.
        var state: GameState = gs
        let retire = card!.options.firstIndex { $0.consequences.electionChoice == "retire" }!
        engine.crisisManager.resolveCrisis(optionIndex: retire, gameState: &state)
        XCTAssertEqual(gs.shadow.campaign.leaveReason, .retired)
        XCTAssertEqual(GameCalendar.format(gs.shadow.campaign.leaveOfficeOn!), "Jan 20, 1985")
    }

    @MainActor
    func testElectionCardsAreNeverDroppedFromAFullDesk() {
        let m = CrisisManager()
        let filler = { CrisisEvent(type: .worldDisaster, severity: .minor, title: "x", description: "", affectedCountries: [], turn: 0, options: []) }
        m.presentCrisis(filler())
        let vote = ElectionCycle.card("Vote", "", [], turn: 0)
        m.presentCrisis(vote)
        for _ in 0..<20 { m.presentCrisis(filler()) }
        XCTAssertEqual(m.pendingCrises.count, CrisisManager.maxPending)
        XCTAssertEqual(m.pendingCrises.first?.id, vote.id, "election decisions jump the queue and survive overflow")
    }

    func testOlderSavesDecodeWithoutACampaign() throws {
        var s = ShadowState()
        s.termsWon = 1
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(s)) as! [String: Any]
        json.removeValue(forKey: "campaign")
        let back = try JSONDecoder().decode(ShadowState.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertFalse(back.campaign.initialized)
        XCTAssertEqual(back.termsWon, 1)
        let old = #"{"date":0,"playerShare":52,"opponentShare":48,"won":true,"opponentName":"X"}"#
        let r = try JSONDecoder().decode(ElectionResult.self, from: Data(old.utf8))
        XCTAssertNil(r.playerEV)
    }

    func testElectionCardsCarryElectionEpigraphs() {
        let card = ElectionCycle.card("Vote", "", [], turn: 0)
        XCTAssertTrue(card.epigraph.tags.contains(.election) || card.epigraph.tags.contains(.leadership))
        XCTAssertEqual(Quotations.all.filter { $0.tags.contains(.election) }.map(\.kind).reduce(into: Set<QuoteKind>()) { $0.insert($1) },
                       Set(QuoteKind.allCases), "every shelf has election lines")
    }
}
