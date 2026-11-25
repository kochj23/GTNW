//
//  PresidencyRecordTests.swift
//  GTNWTests
//
//  3.36.0: the record of his presidency — awards for how he plays, "I told you so" (leaks, resignations that quote
//  the warning, impeachment testimony), and the epilogue (the history books, the library, fifty years later).
//

import XCTest
import SwiftUI
@testable import GTNW

enum R336E {
    @MainActor
    static func game(_ year: Int? = nil, player: String = "USA", difficulty: DifficultyLevel = .normal,
                     seed: UInt64 = 336) throws -> (GameEngine, GameState) {
        let e = GameEngine()
        e.startNewGame(playerCountryID: player, difficulty: difficulty, year: year, seed: seed)
        return (e, try XCTUnwrap(e.gameState))
    }

    /// A cabinet member who can be overruled (not the Vice President).
    static func adviserIndex(_ gs: GameState) throws -> Int {
        try XCTUnwrap(gs.advisors.firstIndex { $0.isActive && !$0.title.contains("President") })
    }

    /// Make `id` one of the player's territories.
    @MainActor
    static func annex(_ gs: GameState, _ id: String) throws {
        let i = try XCTUnwrap(gs.countries.firstIndex { $0.id == id })
        CombatModel.annex(&gs.countries[i], to: try XCTUnwrap(gs.getPlayerCountry()))
    }

    static let warning = "Mr. President, I advise against it. Denmark is a friend (relations 68). Turning on them now contradicts everything our policy has built."
}

// MARK: - Unit

final class PresidencyRecordUnitTests: XCTestCase {
    /// Unit: the quote skips the stock opener and is a verbatim run of the record.
    func testQuoteIsVerbatimAndSkipsTheOpener() {
        let q = ToldYouSo.quote(R336E.warning)
        XCTAssertTrue(R336E.warning.contains(q), "the quote is verbatim")
        XCTAssertFalse(q.hasPrefix("Mr. President"), "the stock opener is not the quote")
        XCTAssertTrue(q.hasPrefix("Denmark is a friend"))
        XCTAssertTrue(q.hasSuffix("."))
        XCTAssertEqual(ToldYouSo.quote("Short."), "Short.")
        let long = String(repeating: "word ", count: 120)
        XCTAssertLessThanOrEqual(ToldYouSo.quote(long).count, 201)
    }

    /// Unit: keyboard smashes and single letters are told apart from real names.
    func testKeyboardSmashAndSingleLetters() {
        for smash in ["Asdfghjkl", "Qwerty", "Fjdksl", "Xkcdq", "lkjhg", "Zxcvbn Land"] {
            XCTAssertTrue(PresidencyAwards.isKeyboardSmash(smash), smash)
        }
        for real in ["Antarctica", "Strength", "Rhythm", "Kyrgyzstan", "New Freedonia", "Port Liberty", "Bob", "Iceland"] {
            XCTAssertFalse(PresidencyAwards.isKeyboardSmash(real), real)
        }
        XCTAssertTrue(PresidencyAwards.isSingleLetter("Q"))
        XCTAssertTrue(PresidencyAwards.isSingleLetter(" X. "))
        XCTAssertFalse(PresidencyAwards.isSingleLetter("7"))
        XCTAssertFalse(PresidencyAwards.isSingleLetter("QQ"))
    }

    /// Unit: every award has a unique id, a name, a known rarity and an achievement in the achievements list.
    @MainActor
    func testAwardsAreListedAsAchievements() {
        let ids = PresidencyAwards.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
        XCTAssertGreaterThanOrEqual(ids.count, 16)
        for a in PresidencyAwards.all {
            XCTAssertNotNil(AchievementRarity(rawValue: a.rarity), a.id)
            XCTAssertFalse(a.name.isEmpty)
            XCTAssertTrue(AchievementEngine.presidencyAchievements.contains { $0.id == a.id && $0.category == .presidency })
        }
    }

    /// Unit: the career adds a game and says "N wars, M wins".
    @MainActor
    func testCareerAddsAGame() throws {
        let (_, gs) = try R336E.game(2025)
        gs.shadow.playerWarsStarted = 3
        gs.warsWon = 1
        gs.shadow.claimDates[Antarctica.id] = gs.currentDate
        var c = PresidencyCareer()
        c.warsStarted = 69; c.warsWon = 1
        let after = PresidencyAwards.adding(gs, to: c)
        XCTAssertEqual(after.games, 1)
        XCTAssertEqual(after.antarcticaGames, 1)
        XCTAssertEqual(after.line, "72 wars, 2 wins")
        XCTAssertEqual(PresidencyCareer().line, "0 wars, 0 wins")
    }

    /// Unit: "much smaller" is a fifth of the economy or less and a weaker military.
    @MainActor
    func testMuchSmaller() throws {
        let (_, gs) = try R336E.game(2025)
        let us = try XCTUnwrap(gs.getCountry(id: "USA"))
        var afg = try XCTUnwrap(gs.getCountry(id: "AFG"))
        XCTAssertTrue(GameEngine.muchSmaller(afg, than: us))
        afg.gdp = us.gdp
        XCTAssertFalse(GameEngine.muchSmaller(afg, than: us))
    }
}

// MARK: - Awards (functional)

final class PresidencyAwardRuleTests: XCTestCase {
    /// Functional: each award's rule, one game state at a time.
    @MainActor
    func testRulesFromTheEndState() throws {
        let (_, gs) = try R336E.game(2025, difficulty: .easy)
        let none = PresidencyAwards.earned(gs, career: PresidencyCareer(), realSeconds: nil)
        XCTAssertTrue(none.isEmpty, "a fresh game has earned nothing: \(none)")

        gs.shadow.domesticEnding = .impeached
        var e = PresidencyAwards.earned(gs, career: PresidencyCareer(), realSeconds: 240)
        XCTAssertTrue(e.contains("impeached_on_easy"))
        XCTAssertTrue(e.contains("removed_under_5_minutes"))
        XCTAssertTrue(e.contains("zero_orders_removed"))
        XCTAssertFalse(PresidencyAwards.earned(gs, career: PresidencyCareer(), realSeconds: 301).contains("removed_under_5_minutes"))
        XCTAssertFalse(PresidencyAwards.earned(gs, career: PresidencyCareer(), realSeconds: nil).contains("removed_under_5_minutes"),
                       "a resumed game has no real-time claim")
        gs.shadow.presidency.orders = 1
        XCTAssertFalse(PresidencyAwards.earned(gs, career: PresidencyCareer(), realSeconds: nil).contains("zero_orders_removed"))

        gs.shadow.domesticEnding = .termLimited
        gs.shadow.presidency.orders = 0
        e = PresidencyAwards.earned(gs, career: PresidencyCareer(), realSeconds: nil)
        XCTAssertTrue(e.contains("served_the_full_term"))
        XCTAssertTrue(e.contains("museum_docent"))
        XCTAssertFalse(e.contains("impeached_on_easy"))

        for (n, land) in ["ISL", "GRL", "NZL", "IRL", "CUB"].enumerated() {
            gs.shadow.renames.append(RenameRecord(land: land, from: land, to: ["A", "B", "C", "D", "E"][n], date: gs.currentDate))
        }
        e = PresidencyAwards.earned(gs, career: PresidencyCareer(), realSeconds: nil)
        XCTAssertTrue(e.contains("colonized_the_alphabet"))
        XCTAssertFalse(e.contains("museum_docent"), "renaming lands is giving orders")
        XCTAssertFalse(e.contains("keyboard_smash_cartographer"))
        gs.shadow.renames.append(RenameRecord(land: "MEX", from: "Mexico", to: "Asdfjkl", date: gs.currentDate))
        XCTAssertTrue(PresidencyAwards.earned(gs, career: PresidencyCareer(), realSeconds: nil).contains("keyboard_smash_cartographer"))

        gs.shadow.presidency.friendsNuked = ["URY"]
        gs.shadow.presidency.surrenderedNuked = ["BLZ"]
        gs.shadow.presidency.microstatesNuked = ["NRU"]
        gs.shadow.presidency.friendsAttacked = ["DNK"]
        gs.shadow.presidency.lostToSmaller = ["AFG"]
        gs.shadow.presidency.overruledPosts = ["state", "defense", "nsa", "the Joint Chiefs"]
        e = PresidencyAwards.earned(gs, career: PresidencyCareer(), realSeconds: nil)
        for id in ["nuked_a_friend", "nuked_the_surrendered", "overkill", "friendly_fire", "fired_by_afghanistan", "ignored_whole_cabinet"] {
            XCTAssertTrue(e.contains(id), id)
        }
        gs.shadow.presidency.followed = 1
        XCTAssertFalse(PresidencyAwards.earned(gs, career: PresidencyCareer(), realSeconds: nil).contains("ignored_whole_cabinet"))

        var career = PresidencyCareer()
        career.antarcticaGames = 5; career.warsStarted = 72; career.warsWon = 2
        e = PresidencyAwards.earned(gs, career: career, realSeconds: nil)
        XCTAssertTrue(e.contains("antarctica_again"))
        XCTAssertTrue(e.contains("many_wars_few_wins"))
        career.warsWon = 8
        XCTAssertFalse(PresidencyAwards.earned(gs, career: career, realSeconds: nil).contains("many_wars_few_wins"))
    }

    /// Functional: a strike on a friend, on a microstate, on a nation that already surrendered — whichever screen fired it.
    @MainActor
    func testNuclearStrikesAreJudged() throws {
        let (e, gs) = try R336E.game(2025)
        let i = try XCTUnwrap(gs.countries.firstIndex { $0.id == "USA" })
        gs.countries[i].nuclearWarheads = max(gs.countries[i].nuclearWarheads, 50)
        gs.countries[i].diplomaticRelations["NRU"] = 64
        if let n = gs.countries.firstIndex(where: { $0.id == "NRU" }) { gs.countries[n].population = 0 }
        e.launchNuclearStrike(from: "USA", to: "NRU", warheads: 1)
        XCTAssertEqual(gs.shadow.presidency.friendsNuked, ["NRU"])
        XCTAssertEqual(gs.shadow.presidency.microstatesNuked, ["NRU"])
        gs.shadow.presidency.surrendered = ["CUB"]
        gs.countries[i].diplomaticRelations["CUB"] = -50
        e.launchNuclearStrike(from: "USA", to: "CUB", warheads: 1)
        XCTAssertEqual(gs.shadow.presidency.surrenderedNuked, ["CUB"])
        XCTAssertEqual(gs.shadow.presidency.friendsNuked, ["NRU"], "an enemy is not a friend")
        e.launchNuclearStrike(from: "RUS", to: "NRU", warheads: 1)
        XCTAssertEqual(gs.shadow.presidency.friendsNuked, ["NRU"], "only the player's strikes count")
    }

    /// Functional: a front lost to a far smaller power is remembered; a nation that gives up is "surrendered".
    @MainActor
    func testWarsLostAndSurrenders() throws {
        let (e, gs) = try R336E.game(2025)
        let f = WarFront(attacker: "USA", defender: "AFG", startDate: gs.currentDate, lastBattle: gs.currentDate,
                         attackerTroops: 10, defenderTroops: 10, attackerInitial: 10, defenderInitial: 10)
        e.noteFrontResolved(f, verdict: .defenderWon)
        XCTAssertEqual(gs.shadow.presidency.lostTo, ["AFG"])
        XCTAssertEqual(gs.shadow.presidency.lostToSmaller, ["AFG"])
        let g = WarFront(attacker: "USA", defender: "CUB", startDate: gs.currentDate, lastBattle: gs.currentDate,
                         attackerTroops: 10, defenderTroops: 10, attackerInitial: 10, defenderInitial: 10)
        e.noteFrontResolved(g, verdict: .attackerWon)
        XCTAssertEqual(gs.shadow.presidency.surrendered, ["CUB"])
        XCTAssertEqual(gs.shadow.presidency.lostTo, ["AFG"], "a win is not a loss")
    }

    /// Functional: declaring war on a friend is noted.
    @MainActor
    func testWarOnAFriend() throws {
        let (e, gs) = try R336E.game(2025)
        gs.setRelation(from: "USA", to: "DNK", value: 68)
        e.declareWar(aggressor: "USA", defender: "DNK")
        XCTAssertEqual(gs.shadow.presidency.friendsAttacked, ["DNK"])
    }
}

// MARK: - I told you so

final class ToldYouSoTests: XCTestCase {
    /// Functional: overruled twice → the warning leaks (approval −1.5, once); three times → a resignation that
    /// quotes the first warning and its date.
    @MainActor
    func testLeakThenResignationQuotingTheWarning() throws {
        let (e, gs) = try R336E.game(2025)
        let i = try R336E.adviserIndex(gs)
        gs.advisors[i].loyalty = 72
        let a = gs.advisors[i]
        XCTAssertNil(AdviceEngine.registerOverrule(advisorIndex: i, in: gs, warning: R336E.warning, order: "Ground Invasion → Denmark"))
        XCTAssertEqual(gs.shadow.presidency.warnings.count, 1)
        XCTAssertEqual(gs.shadow.presidency.warnings[0].text, R336E.warning, "kept verbatim")
        e.processPresidencyRecord()
        XCTAssertFalse(gs.shadow.ticker.contains { $0.text.hasPrefix("Leak:") }, "once is not a pattern")

        XCTAssertNil(AdviceEngine.registerOverrule(advisorIndex: i, in: gs, warning: "Second warning.", order: "x"))
        let before = gs.shadow.popularity
        e.processPresidencyRecord()
        let leak = try XCTUnwrap(gs.shadow.ticker.last { $0.text.hasPrefix("Leak:") })
        XCTAssertTrue(leak.text.contains(ToldYouSo.quote(R336E.warning)))
        XCTAssertTrue(leak.text.contains(GameCalendar.format(gs.currentDate)))
        XCTAssertEqual(gs.shadow.popularity, PopularityModel.clamp(before - ToldYouSo.leakCost), accuracy: 0.001)
        e.processPresidencyRecord()
        XCTAssertEqual(gs.shadow.ticker.filter { $0.text.hasPrefix("Leak:") }.count, 1, "an adviser leaks once")

        let msg = try XCTUnwrap(AdviceEngine.registerOverrule(advisorIndex: i, in: gs, warning: "Third.", order: "y"))
        XCTAssertTrue(msg.contains(a.name))
        XCTAssertTrue(msg.contains(ToldYouSo.quote(R336E.warning)), msg)
        XCTAssertTrue(msg.contains(GameCalendar.format(gs.currentDate)))
        XCTAssertFalse(msg.contains("\n"), "one line")
        XCTAssertEqual(gs.advisors[i].status, .resigned)
    }

    /// Functional: with nothing on the record, the old resignation line stands.
    @MainActor
    func testResignationWithoutARecord() throws {
        let gs = GameState(playerCountryID: "USA")
        let i = try R336E.adviserIndex(gs)
        gs.advisors[i].loyalty = 72
        var message: String?
        for _ in 0..<3 { message = AdviceEngine.registerOverrule(advisorIndex: i, in: gs) ?? message }
        XCTAssertTrue(message?.contains("fundamental disagreements") ?? false)
    }

    /// Functional: when Congress moves, the overruled testify — the news quotes the warning and its date; one
    /// witness a stage; the departed first; it starts over if Congress drops it.
    @MainActor
    func testImpeachmentTestimony() throws {
        let (e, gs) = try R336E.game(2025)
        let i = try R336E.adviserIndex(gs)
        ToldYouSo.record(gs, advisor: gs.advisors[i], text: R336E.warning, order: "Ground Invasion → Denmark")
        ToldYouSo.recordDangers(gs, warnings: [AdvisorWarning(who: "Joint Chiefs", text: "Expect retaliation: up to 40 warheads on us.", level: 2),
                                               AdvisorWarning(who: "Joint Chiefs", text: "Calm.", level: 0)], order: "Nuclear Strike → Russia")
        XCTAssertEqual(gs.shadow.presidency.warnings.count, 2, "only danger warnings are overruled warnings")
        e.processPresidencyRecord()
        XCTAssertFalse(gs.shadow.ticker.contains { $0.text.contains("Impeachment hearings") })

        gs.shadow.impeachmentStage = 1
        e.processPresidencyRecord()
        var hearings = gs.shadow.ticker.filter { $0.text.hasPrefix("Impeachment hearings") }
        XCTAssertEqual(hearings.count, 1)
        XCTAssertTrue(hearings[0].text.contains(ToldYouSo.quote(R336E.warning)))
        XCTAssertTrue(hearings[0].text.contains(GameCalendar.format(gs.currentDate)))
        e.processPresidencyRecord()
        XCTAssertEqual(gs.shadow.ticker.filter { $0.text.hasPrefix("Impeachment hearings") }.count, 1, "one witness a stage")

        gs.shadow.impeachmentStage = 2
        e.processPresidencyRecord()
        hearings = gs.shadow.ticker.filter { $0.text.hasPrefix("Impeachment hearings") }
        XCTAssertEqual(hearings.count, 2)
        XCTAssertTrue(hearings[1].text.contains("the Joint Chiefs"))
        XCTAssertTrue(hearings[1].text.contains("Expect retaliation"))
        XCTAssertTrue(gs.shadow.presidency.warnings.allSatisfy(\.testified))

        gs.shadow.impeachmentStage = 0
        e.processPresidencyRecord()
        XCTAssertEqual(gs.shadow.presidency.testifiedStage, 0)
    }

    /// Functional: the departed testify before those still serving.
    @MainActor
    func testTheDepartedTestifyFirst() throws {
        let (_, gs) = try R336E.game(2025)
        let serving = gs.advisors.indices.filter { gs.advisors[$0].isActive && !gs.advisors[$0].title.contains("President") }
        XCTAssertGreaterThanOrEqual(serving.count, 2)
        ToldYouSo.record(gs, advisor: gs.advisors[serving[0]], text: "First, still serving.", order: "a")
        ToldYouSo.record(gs, advisor: gs.advisors[serving[1]], text: "Second, resigned.", order: "b")
        gs.advisors[serving[1]].status = .resigned
        let w = try XCTUnwrap(ToldYouSo.nextWitness(gs))
        XCTAssertEqual(w.text, "Second, resigned.")
        XCTAssertTrue(ToldYouSo.testimonyText(w, gs: gs).contains("former "))
    }

    /// Functional: a real order the Secretary opposed goes on the record with its order label; REJECT records the
    /// recommendation; taking advice counts as following it.
    @MainActor
    func testOrdersFeedTheRecord() throws {
        let (e, gs) = try R336E.game(2025)
        let i = try R336E.adviserIndex(gs)
        let adv = gs.advisors[i]
        let advice = ActionAdvice(advisorID: adv.id, advisorName: adv.name, advisorTitle: adv.title, stance: .oppose,
                                  reason: R336E.warning, successEstimate: 0.5)
        e.performAdvisedAction(.sanctions, targetID: "DNK", advice: advice)
        XCTAssertEqual(gs.shadow.presidency.orders, 1)
        let w = try XCTUnwrap(gs.shadow.presidency.warnings.first)
        XCTAssertEqual(w.text, R336E.warning)
        XCTAssertTrue(w.order.contains("Denmark"), w.order)
        let approve = ActionAdvice(advisorID: adv.id, advisorName: adv.name, advisorTitle: adv.title, stance: .approve,
                                   reason: "Fine.", successEstimate: 0.9)
        gs.actionsUsedThisTurn = 0
        e.performAdvisedAction(.foodAid, targetID: "DNK", advice: approve)
        XCTAssertEqual(gs.shadow.presidency.followed, 1)
        if let j = gs.advisors.firstIndex(where: { $0.isActive && $0.recommendedAction != nil }) {
            let before = gs.shadow.presidency.warnings.count
            e.rejectRecommendation(advisorID: gs.advisors[j].id)
            XCTAssertEqual(gs.shadow.presidency.warnings.count, before + 1)
            XCTAssertTrue(gs.shadow.presidency.warnings.last?.order.hasPrefix("Rejected") ?? false)
        }
    }
}

// MARK: - Epilogue

final class PresidencyEpilogueTests: XCTestCase {
    /// Functional: fifty years later his names survive on held, stable land and revert elsewhere; a name that
    /// breaks the content rules is struck from the record.
    @MainActor
    func testFiftyYearsLater() throws {
        let (e, gs) = try R336E.game(2025)
        try R336E.annex(gs, "ISL"); try R336E.annex(gs, "NOR"); try R336E.annex(gs, "IRL")
        XCTAssertTrue(e.renameTerritory("ISL", to: "Q"))
        XCTAssertTrue(e.renameTerritory("NOR", to: "Asdfjkl"))
        // 3.36.0: the content check refuses it now; an older save may still hold it.
        XCTAssertFalse(e.renameTerritory("IRL", to: "Sarin Bay"))
        let irl = try XCTUnwrap(gs.countries.firstIndex { $0.id == "IRL" })
        gs.shadow.renames.append(RenameRecord(land: "IRL", from: gs.countries[irl].name, to: "Sarin Bay", date: gs.currentDate))
        gs.countries[irl].name = "Sarin Bay"
        let isl = try XCTUnwrap(gs.countries.firstIndex { $0.id == "ISL" })
        gs.countries[isl].stability = 80
        let grl = try XCTUnwrap(gs.countries.firstIndex { $0.id == "NOR" })
        gs.countries[grl].territoryOf = nil   // lost
        let later = Dictionary(uniqueKeysWithValues: PresidencyEpilogue.fiftyYearsLater(gs).map { ($0.land, $0) })
        XCTAssertEqual(later["ISL"]?.survives, true)
        XCTAssertTrue(later["ISL"]?.line.hasPrefix("Q is still Q.") ?? false)
        XCTAssertEqual(later["NOR"]?.survives, false)
        XCTAssertTrue(later["NOR"]?.line.contains("Norway") ?? false, later["NOR"]?.line ?? "")
        XCTAssertEqual(later["IRL"]?.survives, false)
        XCTAssertFalse(later["IRL"]?.line.contains("Sarin") ?? true, "a blocked name is never shown")
        XCTAssertEqual(PresidencyEpilogue.fiftyYearsLater(gs), PresidencyEpilogue.fiftyYearsLater(gs), "deterministic")
    }

    /// Functional: the library is named for the President and stands in his newest held, renamed land.
    @MainActor
    func testLibraryName() throws {
        let (e, gs) = try R336E.game(2025)
        XCTAssertTrue(PresidencyEpilogue.library(gs).contains("Presidential Library"))
        XCTAssertTrue(PresidencyEpilogue.library(gs).contains(gs.getPlayerCountry()?.name ?? "?"))
        try R336E.annex(gs, "ISL")
        XCTAssertTrue(e.renameTerritory("ISL", to: "Freedonia"))
        let lib = PresidencyEpilogue.library(gs)
        XCTAssertTrue(lib.contains("Freedonia (formerly Iceland)"), lib)
        XCTAssertTrue(lib.hasPrefix("The \(PresidencyEpilogue.leaderName(gs)) Presidential Library"), lib)
    }

    /// Functional: the history books' paragraph is built from the record and quotes the first overruled warning.
    @MainActor
    func testVerdictTemplate() throws {
        let (e, gs) = try R336E.game(2025)
        ToldYouSo.record(gs, advisor: gs.advisors[try R336E.adviserIndex(gs)], text: R336E.warning, order: "x")
        gs.shadow.playerWarsStarted = 2
        gs.shadow.presidency.lostToSmaller = ["AFG"]
        gs.shadow.domesticEnding = .impeached
        try R336E.annex(gs, "ISL")
        XCTAssertTrue(e.renameTerritory("ISL", to: "Q"))
        let v = PresidencyEpilogue.verdictTemplate(gs, victory: nil)
        XCTAssertTrue(v.contains("removed from office by Congress"))
        XCTAssertTrue(v.contains("started 2 wars"))
        XCTAssertTrue(v.contains("Afghanistan"))
        XCTAssertTrue(v.contains("renamed 1 land"))
        XCTAssertTrue(v.contains(ToldYouSo.quote(R336E.warning)))
        XCTAssertFalse(ChatSafety.violates(v))
        XCTAssertEqual(v, PresidencyEpilogue.verdictTemplate(gs, victory: nil), "deterministic")
        XCTAssertEqual(PresidencyEpilogue.verdict(gs, victory: nil), v, "the template stands without an AI")
    }

    /// Security: an AI polish that invents a number or a name, carries a link, or breaks the content rules is
    /// thrown away; a faithful one is kept.
    func testPolishMustKeepToTheFacts() {
        let template = "Jane Doe led Ruritania from 2025 to 2027 and was removed from office by Congress. It started 3 wars and won 1. Approval stood at 22% at the end."
        let good = "Jane Doe led Ruritania from 2025 to 2027, started 3 wars, won 1, and was removed from office by Congress with approval at 22%."
        XCTAssertEqual(PresidencyEpilogue.cleanPolish(good, template: template), good)
        XCTAssertNil(PresidencyEpilogue.cleanPolish(good.replacingOccurrences(of: "3 wars", with: "7 wars"), template: template), "invented number")
        XCTAssertNil(PresidencyEpilogue.cleanPolish(good + " Bismarck approved.", template: template), "invented name")
        XCTAssertNil(PresidencyEpilogue.cleanPolish(good + " See https://example.com", template: template))
        XCTAssertNil(PresidencyEpilogue.cleanPolish("Hmm, the user wants me to rewrite this paragraph as a historian would do it.", template: template))
        XCTAssertNil(PresidencyEpilogue.cleanPolish("Short.", template: template))
    }
}

// MARK: - Integration (game over)

final class PresidencyGameOverTests: XCTestCase {
    private var dir: URL!
    override func setUp() { super.setUp(); dir = StoreFixtures.tempDir() }
    override func tearDown() { try? FileManager.default.removeItem(at: dir); PresidencyEpilogue.polisher = nil; super.tearDown() }

    /// Integration: impeached on Easy with no orders → the awards, the career, and achievement_unlocked play events
    /// Nova's journal can quote; once per game.
    @MainActor
    func testGameOverAwardsAndPlayEvents() async throws {
        PresidencyCareer.save(PresidencyCareer())
        let remote = InMemoryGameStore()
        let (e, service) = PlayFixtures.engine(dir, remote: remote)
        e.startNewGame(playerCountryID: "USA", difficulty: .easy, year: 2025, seed: 7)
        let gs = try XCTUnwrap(e.gameState)
        let id = try XCTUnwrap(gs.shadow.playSessionID)
        gs.shadow.domesticEnding = .impeached
        gs.gameOver = true
        gs.gameOverReason = "Removed"
        let score = GameScore.calculate(from: gs, victoryType: nil)
        e.recordGameOver(gs, score: score, victory: nil)
        e.recordGameOver(gs, score: score, victory: nil)
        let r = gs.shadow.presidency
        XCTAssertTrue(r.closed)
        XCTAssertTrue(r.awards.contains("impeached_on_easy"))
        XCTAssertTrue(r.awards.contains("zero_orders_removed"))
        XCTAssertTrue(r.awards.contains("removed_under_5_minutes"), "the whole game took less than five real minutes")
        XCTAssertEqual(r.firstAwards, r.awards)
        let career = PresidencyCareer.load()
        XCTAssertEqual(career.games, 1, "once per game")
        XCTAssertTrue(Set(r.awards).isSubset(of: Set(career.awards)))
        XCTAssertTrue(service.records.achievements.contains { $0.id == "impeached_on_easy" })

        _ = await service.syncNow()
        let events = await remote.events(id)
        let unlocked = events.filter { $0.kind == "achievement_unlocked" }.map(PlayFixtures.detail)
        XCTAssertEqual(Set(unlocked.compactMap { $0["id"] as? String }), Set(r.awards))
        XCTAssertTrue(unlocked.allSatisfy { ($0["first_time"] as? Bool) == true && $0["name"] is String })
        XCTAssertTrue(events.contains { $0.kind == "history_verdict" })
        XCTAssertEqual(events.last?.kind, "game_over")

        // A second game: the same awards are no longer first.
        e.startNewGame(playerCountryID: "USA", difficulty: .easy, year: 2025, seed: 8)
        let g2 = try XCTUnwrap(e.gameState)
        g2.shadow.domesticEnding = .impeached
        g2.gameOver = true
        e.recordGameOver(g2, score: GameScore.calculate(from: g2, victoryType: nil), victory: nil)
        XCTAssertTrue(g2.shadow.presidency.awards.contains("impeached_on_easy"))
        XCTAssertFalse(g2.shadow.presidency.firstAwards.contains("impeached_on_easy"))
        XCTAssertEqual(PresidencyCareer.load().games, 2)
    }

    /// Integration: a watch game earns nothing and leaves the career alone.
    @MainActor
    func testWatchGamesEarnNothing() throws {
        PresidencyCareer.save(PresidencyCareer())
        let e = GameEngine()
        e.startNewGame(playerCountryID: "USA", year: 2025, spectate: true, seed: 3)
        let gs = try XCTUnwrap(e.gameState)
        gs.shadow.domesticEnding = .impeached
        gs.gameOver = true
        e.recordGameOver(gs, score: GameScore.calculate(from: gs, victoryType: nil), victory: nil)
        XCTAssertTrue(gs.shadow.presidency.awards.isEmpty)
        XCTAssertEqual(PresidencyCareer.load().games, 0)
    }

    /// Integration: a local AI's faithful polish replaces the template; one that strays leaves it.
    @MainActor
    func testVerdictPolish() async throws {
        let (e, gs) = try R336E.game(2025)
        gs.shadow.domesticEnding = .termLimited
        gs.gameOver = true
        let template = PresidencyEpilogue.verdictTemplate(gs, victory: nil)
        PresidencyEpilogue.polisher = { prompt in
            XCTAssertTrue(prompt.contains(template))
            return template.replacingOccurrences(of: " led ", with: " governed ")
        }
        e.recordGameOver(gs, score: GameScore.calculate(from: gs, victoryType: nil), victory: nil)
        for _ in 0..<50 where gs.shadow.presidency.verdict == nil { try await Task.sleep(nanoseconds: 20_000_000) }
        XCTAssertEqual(gs.shadow.presidency.verdict, template.replacingOccurrences(of: " led ", with: " governed "))

        let (e2, g2) = try R336E.game(2025, seed: 9)
        g2.gameOver = true
        PresidencyEpilogue.polisher = { _ in "Abraham Lincoln won 99 wars and the ages belong to him, said every historian in 1865 and after." }
        e2.recordGameOver(g2, score: GameScore.calculate(from: g2, victoryType: nil), victory: nil)
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertNil(g2.shadow.presidency.verdict, "invented facts never replace the template")
    }
}

// MARK: - Saves, determinism, frames

final class PresidencyRecordPersistenceTests: XCTestCase {
    /// Save round-trip: the record survives encode/decode; a save from before 3.36 loads with an empty record; the
    /// encoding is byte-stable.
    @MainActor
    func testSaveRoundTripAndOldSaves() throws {
        let (e, gs) = try R336E.game(2025)
        ToldYouSo.record(gs, advisor: gs.advisors[try R336E.adviserIndex(gs)], text: R336E.warning, order: "Ground Invasion → Denmark")
        gs.shadow.presidency.friendsNuked = ["NRU"]
        gs.shadow.presidency.awards = ["nuked_a_friend"]
        gs.shadow.presidency.verdict = "A verdict."
        gs.shadow.presidency.testifiedStage = 2
        e.notePresidentialOrder(.sanctions, targetID: "DNK", relationBefore: 68)
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        let data = try enc.encode(gs.shadow)
        XCTAssertEqual(data, try enc.encode(gs.shadow), "byte-stable")
        let back = try JSONDecoder().decode(ShadowState.self, from: data)
        XCTAssertEqual(back.presidency, gs.shadow.presidency)

        var obj = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        obj["presidency"] = nil
        let old = try JSONDecoder().decode(ShadowState.self, from: JSONSerialization.data(withJSONObject: obj))
        XCTAssertEqual(old.presidency, PresidencyRecord())
        // A partial record (a field added later) still loads.
        obj["presidency"] = ["orders": 4, "warnings": [["text": "Only text."]]]
        let partial = try JSONDecoder().decode(ShadowState.self, from: JSONSerialization.data(withJSONObject: obj))
        XCTAssertEqual(partial.presidency.orders, 4)
        XCTAssertEqual(partial.presidency.warnings.first?.text, "Only text.")
        XCTAssertEqual(partial.presidency.nextWarningID, 1)
    }

    /// Determinism: the same seed and the same orders keep the same record, turn for turn.
    @MainActor
    func testSameSeedSameRecord() throws {
        func play() throws -> Data {
            let (e, gs) = try R336E.game(2025, seed: 42)
            let i = try R336E.adviserIndex(gs)
            let adv = gs.advisors[i]
            for t in ["DNK", "IRL", "NOR"] {
                gs.actionsUsedThisTurn = 0
                e.performAdvisedAction(.sanctions, targetID: t, advice: ActionAdvice(advisorID: adv.id, advisorName: adv.name, advisorTitle: adv.title,
                                                                                     stance: .oppose, reason: R336E.warning, successEstimate: 0.5))
                e.endTurn()
            }
            gs.shadow.impeachmentStage = 1
            e.processPresidencyRecord()
            var r = gs.shadow.presidency
            r.warnings = r.warnings.map { var w = $0; w.date = Date(timeIntervalSince1970: 0); return w }
            let enc = JSONEncoder()
            enc.outputFormatting = [.sortedKeys]
            return try enc.encode(r)
        }
        XCTAssertEqual(try play(), try play())
    }

    @MainActor private func renders<V: View>(_ v: V, _ what: String) {
        defer { Theme.forced = nil }
        for theme in GameTheme.allCases {
            Theme.forced = theme
            let r = ImageRenderer(content: v)
            r.scale = 1
            XCTAssertNotNil(r.cgImage, "\(what) failed to render in \(theme)")
        }
    }

    /// Frame: the epilogue (with awards and a struck name) and the AWARDS tab render in both skins.
    @MainActor
    func testEpilogueAndAwardsRender() throws {
        let (e, gs) = try R336E.game(2025)
        try R336E.annex(gs, "ISL")
        XCTAssertTrue(e.renameTerritory("ISL", to: "Q"))
        ToldYouSo.record(gs, advisor: gs.advisors[try R336E.adviserIndex(gs)], text: R336E.warning, order: "x")
        gs.shadow.presidency.awards = ["colonized_the_alphabet", "impeached_on_easy"]
        gs.shadow.presidency.firstAwards = ["impeached_on_easy"]
        gs.shadow.presidency.careerLine = "72 wars, 2 wins"
        renders(PresidencyEpilogueView(gameState: gs, victoryType: nil).frame(width: 900), "epilogue")
        renders(PresidencyAwardsPanel(gameState: gs).frame(width: 620), "awards")
        renders(RecordsSheet(gameState: gs, hall: [:], tab: .awards), "records awards")
    }

    /// Security: everything the record shows passes the content rules (the fixed text, and the generated lines).
    @MainActor
    func testShownTextPassesContentRules() throws {
        let (_, gs) = try R336E.game(2025)
        ToldYouSo.record(gs, advisor: gs.advisors[try R336E.adviserIndex(gs)], text: R336E.warning, order: "x")
        var texts = PresidencyAwards.all.flatMap { [$0.name, $0.description] }
        texts += [PresidencyEpilogue.verdictTemplate(gs, victory: nil), PresidencyEpilogue.library(gs)]
        texts += gs.shadow.presidency.warnings.flatMap { [ToldYouSo.leakText($0), ToldYouSo.testimonyText($0, gs: gs)] }
        for t in texts {
            XCTAssertFalse(ChatSafety.violates(t), t)
            XCTAssertFalse(t.contains("http"), t)
        }
    }

    /// Performance: the awards and the epilogue for a long record stay cheap.
    @MainActor
    func testEpiloguePerformance() throws {
        let (_, gs) = try R336E.game(2025)
        for n in 0..<500 { gs.shadow.renames.append(RenameRecord(land: "L\(n % 60)", from: "Old\(n)", to: "N\(n)", date: gs.currentDate)) }
        for _ in 0..<80 { ToldYouSo.record(gs, advisor: nil, title: "the Joint Chiefs", text: R336E.warning, order: "x") }
        let start = Date()
        for _ in 0..<20 {
            _ = PresidencyAwards.earned(gs, career: PresidencyCareer(), realSeconds: nil)
            _ = PresidencyEpilogue.verdictTemplate(gs, victory: nil)
            _ = PresidencyEpilogue.fiftyYearsLater(gs)
        }
        XCTAssertLessThan(Date().timeIntervalSince(start), 2.0)
        XCTAssertEqual(gs.shadow.presidency.warnings.count, PresidencyRecord.maxWarnings)
    }
}
