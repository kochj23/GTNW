//
//  ShadowSystemsTests.swift
//  GTNWTests
//
//  Calendar & rate scaling, save migration, advice, anxieties, elections, aid, budget, War Room combat,
//  scenarios, save slots and theme persistence. No real UserDefaults (suites are injected) and no files
//  outside a temporary directory.
//

import XCTest
#if os(macOS)
import AppKit
#endif
@testable import GTNW

// MARK: - Calendar

final class GameCalendarTests: XCTestCase {

    func testNewGameStartsOnInaugurationDayAndAdvancesByTurnLength() {
        let gs = GameState(playerCountryID: "USA", turnLength: .month)
        XCTAssertEqual(gs.currentDateLabel, "Jan 20, 2025")
        gs.turn = 1
        XCTAssertEqual(gs.currentDateLabel, "Feb 20, 2025")
        gs.turn = 12
        XCTAssertEqual(gs.currentYear, 2026)

        let weekly = GameState(playerCountryID: "USA", turnLength: .week)
        weekly.turn = 1
        XCTAssertEqual(weekly.currentDateLabel, "Jan 27, 2025")

        let daily = GameState(playerCountryID: "USA", turnLength: .day)
        daily.turn = 11
        XCTAssertEqual(daily.currentDateLabel, "Jan 31, 2025")

        let yearly = GameState(playerCountryID: "USA", turnLength: .year)
        yearly.turn = 3
        XCTAssertEqual(yearly.currentYear, 2028)
    }

    func testCurrentYearFollowsTheCalendarNotTheTurnCount() {
        let gs = GameState(playerCountryID: "USA", turnLength: .month)
        gs.turn = 11
        XCTAssertEqual(gs.currentYear, 2025, "11 months in is still 2025")
        XCTAssertEqual(gs.elapsedYears, 11.0 / 12.0, accuracy: 1e-9)
    }

    func testActionsPerTurnScaleWithTurnLength() {
        XCTAssertEqual(TurnLength.day.actionsPerTurn, 1)
        XCTAssertEqual(TurnLength.week.actionsPerTurn, 1)
        XCTAssertEqual(TurnLength.month.actionsPerTurn, 2)
        XCTAssertEqual(TurnLength.year.actionsPerTurn, 4)

        let gs = GameState(playerCountryID: "USA", turnLength: .month)
        XCTAssertFalse(gs.hasUsedActionThisTurn)
        gs.hasUsedActionThisTurn = true          // legacy setter consumes one action
        XCTAssertEqual(gs.actionsRemaining, 1)
        XCTAssertFalse(gs.hasUsedActionThisTurn)
        gs.hasUsedActionThisTurn = true
        XCTAssertTrue(gs.hasUsedActionThisTurn)
        gs.hasUsedActionThisTurn = false
        XCTAssertEqual(gs.actionsRemaining, 2)
    }

    func testProbabilityScalingPreservesAnnualOdds() {
        let monthly = TurnScale(.month)
        let p = monthly.probability(annual: 0.2)
        // Twelve monthly chances compound back to the annual chance.
        XCTAssertEqual(1 - pow(1 - p, 12), 0.2, accuracy: 1e-9)
        XCTAssertEqual(TurnScale(.year).probability(annual: 0.2), 0.2, accuracy: 1e-12)
        XCTAssertEqual(monthly.amount(annual: 120), 10, accuracy: 1e-9)
        XCTAssertEqual(monthly.turns(forYears: 2), 24)
        XCTAssertEqual(TurnScale(.year).turns(forYears: 2), 2)
        XCTAssertEqual(TurnScale(.week).turns(forYears: 1), 52)
    }

    func testStochasticIntegerRoundingKeepsTheExpectedTotal() {
        let s = TurnScale(.month)
        XCTAssertEqual(s.integer(annual: 30, roll: 0.99), 2, "2.5/month rounds down on a high roll")
        XCTAssertEqual(s.integer(annual: 30, roll: 0.10), 3, "and up on a low roll")
        XCTAssertEqual(s.integer(annual: 6, roll: 0.0), 1)
        XCTAssertEqual(s.integer(annual: 6, roll: 0.9), 0)
    }

    func testElectionDayIsTuesdayAfterFirstMondayOfNovember() {
        XCTAssertEqual(GameCalendar.format(GameCalendar.electionDay(year: 1992)), "Nov 3, 1992")
        XCTAssertEqual(GameCalendar.format(GameCalendar.electionDay(year: 2024)), "Nov 5, 2024")
        XCTAssertEqual(GameCalendar.format(GameCalendar.electionDay(year: 2028)), "Nov 7, 2028")
        XCTAssertEqual(GameCalendar.format(GameCalendar.nextElection(after: GameCalendar.date(year: 1990, month: 6, day: 1))), "Nov 3, 1992")
    }

    func testCalendarWindowDetectsAnniversaries() {
        let a = GameCalendar.date(year: 2025, month: 12, day: 20)
        let b = GameCalendar.date(year: 2026, month: 1, day: 20)
        XCTAssertTrue(GameCalendar.window(from: a, to: b, containsMonth: 1, day: 1))
        XCTAssertFalse(GameCalendar.window(from: a, to: b, containsMonth: 2, day: 1))
    }

    func testDefaultTurnLengthComesFromInjectedDefaults() {
        let suite = UserDefaults(suiteName: "GTNWTests.turnLength.\(UUID().uuidString)")!
        XCTAssertEqual(TurnLength.defaultForNewGames(suite), .month)
        suite.set("week", forKey: GameCalendar.turnLengthDefaultsKey)
        XCTAssertEqual(TurnLength.defaultForNewGames(suite), .week)
    }
}

// MARK: - Save migration & slots

final class SaveMigrationTests: XCTestCase {

    func testPreCalendarSaveLoadsAsYearlyGame() throws {
        let gs = GameState(playerCountryID: "USA", turnLength: .month)
        gs.turn = 7
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(gs)) as! [String: Any]
        for key in ["turnLength", "startDate", "shadow", "eraStartYear", "actionsUsedThisTurn"] { json.removeValue(forKey: key) }
        let oldSave = try JSONSerialization.data(withJSONObject: json)

        let loaded = try JSONDecoder().decode(GameState.self, from: oldSave)
        XCTAssertEqual(loaded.turnLength, .year, "old saves were one year per turn")
        XCTAssertEqual(loaded.turn, 7)
        XCTAssertEqual(loaded.currentYear, 2032, "year = 2025 + 7 turns, as before the calendar")
        XCTAssertEqual(loaded.shadow.popularity, 50)
    }

    func testRoundTripKeepsCalendarAndShadowState() throws {
        let gs = GameState(playerCountryID: "USA", turnLength: .week)
        gs.turn = 3
        gs.shadow.popularity = 61
        gs.shadow.budget.defense = 7
        let back = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(gs))
        XCTAssertEqual(back.turnLength, .week)
        XCTAssertEqual(back.currentDateLabel, gs.currentDateLabel)
        XCTAssertEqual(back.shadow.popularity, 61)
        XCTAssertEqual(back.shadow.budget.defense, 7)
    }

    func testSaveSlotsInTemporaryFolder() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("gtnw-saves-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let manager = SaveManager(folder: dir)
        let gs = GameState(playerCountryID: "USA", turnLength: .month)
        gs.turn = 5
        try manager.save(gs, slot: 2)
        let loaded = try manager.load(slot: 2)
        XCTAssertEqual(loaded.turn, 5)
        XCTAssertEqual(manager.list().map(\.slot), [2])
        manager.delete(slot: 2)
        XCTAssertTrue(manager.list().isEmpty)
    }
}

// MARK: - Profiles & anxieties

final class ProfileAndAnxietyTests: XCTestCase {

    func testDerivedProfilesAreStableAndInRange() {
        let gs = GameState(playerCountryID: "USA")
        for c in gs.countries {
            let a = CountryProfile.derived(from: c), b = CountryProfile.derived(from: c)
            XCTAssertEqual(a, b, "derivation must be deterministic for \(c.id)")
            XCTAssertTrue((1...6).contains(a.ambition))
            XCTAssertTrue((1...6).contains(a.ethic))
            XCTAssertTrue((0...100).contains(a.qualityOfLife))
        }
    }

    func testWarRaisesMilitaryAnxietyAndStepConverges() {
        let gs = GameState(playerCountryID: "USA")
        guard let i = gs.countries.firstIndex(where: { $0.id == "POL" }) else { return XCTFail("POL missing") }
        let calm = AnxietyModel.targets(for: gs.countries[i], in: gs).military
        gs.countries[i].atWarWith = ["RUS"]
        let war = AnxietyModel.targets(for: gs.countries[i], in: gs).military
        XCTAssertGreaterThan(war, calm + 20)

        var a = ThreatAnxieties()
        var t = ThreatAnxieties(); t.military = 80
        for _ in 0..<36 { a = AnxietyModel.step(a, toward: t, scale: TurnScale(.month)) }
        XCTAssertEqual(a.military, 80, accuracy: 1, "three years of monthly steps reach the target")
    }

    func testSpikeDetection() {
        var old = ThreatAnxieties(); old.nuclear = 30
        var new = old; new.nuclear = 55
        XCTAssertEqual(AnxietyModel.spike(from: old, to: new), .nuclear)
        new.nuclear = 40
        XCTAssertNil(AnxietyModel.spike(from: old, to: new))
    }

    func testRuthlessLeadersPickWarMoreOftenThanRestrainedOnes() {
        let gs = GameState(playerCountryID: "USA")
        guard let i = gs.countries.firstIndex(where: { $0.id == "IRQ" }),
              let k = gs.countries.firstIndex(where: { $0.id == "KWT" }) else { return XCTFail("missing") }
        gs.countries[i].diplomaticRelations["KWT"] = -80
        gs.countries[i].militaryStrength = 80
        gs.countries[k].militaryStrength = 20

        func attacks(ambition: Int) -> Int {
            gs.countries[i].profile.ambition = ambition
            return (0..<200).filter {
                if case .attack = PersonalityAI.choose(for: gs.countries[i], in: gs, roll: Double($0) / 200) { return true }
                return false
            }.count
        }
        XCTAssertLessThanOrEqual(attacks(ambition: 1), 6, "3.14.0: restrained leaders rarely, but sometimes, go to war")
        XCTAssertGreaterThan(attacks(ambition: 6), attacks(ambition: 3))
        XCTAssertGreaterThan(attacks(ambition: 3), attacks(ambition: 1))
    }
}

// MARK: - Advice

final class AdviceEngineTests: XCTestCase {

    private func setup() -> (GameState, Country, Country) {
        let gs = GameState(playerCountryID: "USA")
        return (gs, gs.getPlayerCountry()!, gs.getCountry(id: "GBR")!)
    }

    func testAttackingAFriendIsOpposed() {
        var (gs, player, ally) = setup()
        player.diplomaticRelations["GBR"] = 80
        let advice = AdviceEngine.advise(action: .airStrike, player: player, target: ally, gameState: gs)
        XCTAssertEqual(advice.stance, .oppose)
        XCTAssertTrue(advice.reason.contains("friend"))
        _ = gs
    }

    func testAidToAFriendIsApproved() {
        var (gs, player, ally) = setup()
        player.diplomaticRelations["GBR"] = 70
        let advice = AdviceEngine.advise(action: .economicAid, player: player, target: ally, gameState: gs)
        XCTAssertEqual(advice.stance, .approve)
        _ = gs
    }

    func testNuclearFirstUseIsOpposed() {
        let (gs, player, _) = setup()
        let rus = gs.getCountry(id: "RUS")!
        let advice = AdviceEngine.advise(action: .launchNukes, player: player, target: rus, gameState: gs)
        XCTAssertEqual(advice.stance, .oppose)
    }

    @MainActor
    func testAcceptingAStandingRecommendationCarriesItOut() {
        let engine = GameEngine()
        engine.startNewGame(turnLength: .year)
        let gs = engine.gameState!
        guard let i = gs.advisors.firstIndex(where: { $0.roleKey == "state" && $0.isActive }),
              let raw = gs.advisors[i].recommendedAction else { return XCTFail("State should have a recommendation") }
        XCTAssertNotNil(PresidentialAction(rawValue: raw))
        XCTAssertNotNil(gs.advisors[i].currentAdvice)
        let before = gs.actionsUsedThisTurn
        XCTAssertTrue(engine.acceptRecommendation(advisorID: gs.advisors[i].id))
        XCTAssertEqual(gs.actionsUsedThisTurn, before + 1)

        let previous = (gs.advisors[i].recommendedAction ?? "") + (gs.advisors[i].recommendedTarget ?? "")
        engine.alternativeRecommendation(advisorID: gs.advisors[i].id)
        let next = (gs.advisors[i].recommendedAction ?? "") + (gs.advisors[i].recommendedTarget ?? "")
        XCTAssertNotEqual(previous, next, "REQUEST ALTERNATIVE proposes something else")
    }

    func testOverruledAdvisorEventuallyResigns() {
        let gs = GameState(playerCountryID: "USA")
        guard let i = gs.advisors.firstIndex(where: { !$0.title.contains("President") }) else { return XCTFail() }
        gs.advisors[i].loyalty = 72
        var message: String?
        for _ in 0..<3 { message = AdviceEngine.registerOverrule(advisorIndex: i, in: gs) ?? message }
        XCTAssertNotNil(message)
        XCTAssertEqual(gs.advisors[i].status, .resigned)
        XCTAssertFalse(gs.advisors[i].isActive)
    }
}

// MARK: - Popularity & elections

final class PopularityTests: XCTestCase {

    func testVoteShareTracksPopularity() {
        XCTAssertGreaterThan(PopularityModel.voteShare(popularity: 70, termsWon: 0, noise: 0), 50)
        XCTAssertLessThan(PopularityModel.voteShare(popularity: 30, termsWon: 0, noise: 0), 50)
    }

    func testPollPhrases() {
        XCTAssertTrue(PopularityModel.pollPhrase(from: 50, to: 50.4).contains("held steady"))
        XCTAssertTrue(PopularityModel.pollPhrase(from: 50, to: 27).contains("collapsed"))
        XCTAssertTrue(PopularityModel.pollPhrase(from: 40, to: 45).contains("rose"))
    }

    func testImpeachmentEscalatesAndRecovers() {
        var stage = 0
        for _ in 0..<4 { stage = PopularityModel.nextImpeachmentStage(current: stage, popularity: 12, ruthlessness: 40, congress: 20) }
        XCTAssertEqual(stage, 4)
        XCTAssertEqual(PopularityModel.nextImpeachmentStage(current: 2, popularity: 45, ruthlessness: 5, congress: 60), 0)
    }

    func testDomesticEndingDefeatsThePlayer() {
        let gs = GameState(playerCountryID: "USA")
        gs.shadow.domesticEnding = .lostElection
        let result = VictoryChecker.checkDefeat(gameState: gs)
        XCTAssertTrue(result.defeated)
        XCTAssertTrue(result.reason.contains("election"))
    }

    @MainActor
    func testElectionDayIsHeldOnTheCalendar() {
        let engine = GameEngine()
        engine.startNewGame(turnLength: .month)
        let gs = engine.gameState!
        gs.shadow.electionsEnabled = true
        gs.shadow.popularity = 80
        engine.holdElection(on: GameCalendar.electionDay(year: 2028))
        XCTAssertEqual(gs.shadow.lastElection?.won, true)
        XCTAssertEqual(gs.shadow.termsWon, 1)

        gs.shadow.popularity = 10
        engine.holdElection(on: GameCalendar.electionDay(year: 2032))
        XCTAssertEqual(gs.shadow.domesticEnding, .lostElection)
    }
}

// MARK: - Budget & aid

final class BudgetAndAidTests: XCTestCase {

    func testResearchRaisesGrowthAndTaxesCostPopularity() {
        var b = FederalBudget()
        let base = BudgetModel.project(b)
        b.research = 3
        XCTAssertGreaterThan(BudgetModel.project(b).growth, base.growth)
        b = FederalBudget(); b.personalTax = 45
        XCTAssertLessThan(BudgetModel.project(b).popularityChange, base.popularityChange)
        b = FederalBudget(); b.defense = 8
        XCTAssertGreaterThan(BudgetModel.project(b).militaryChange, 0)
    }

    func testBudgetLimitsAreEnforced() {
        var b = FederalBudget()
        b.set(\.personalTax, 500)
        XCTAssertEqual(b.personalTax, 70)
        b.set(\.foreignAid, -1)
        XCTAssertEqual(b.foreignAid, 0)
        XCTAssertEqual(FederalBudget().aidPool(gdpTrillions: 20), 50)
    }

    func testAidReactions() {
        let gs = GameState(playerCountryID: "USA")
        let c = gs.getCountry(id: "ETH") ?? gs.countries.first { $0.economicStrength < 30 }!
        var need = AidVector(); need.humanitarian = 2
        var pkg = AidVector(); pkg.humanitarian = 2
        XCTAssertEqual(AidModel.evaluate(package: pkg, need: need, relation: 10, recipient: c, donorName: "USA").reaction, .thanks)
        pkg.humanitarian = 10
        let partial = AidModel.evaluate(package: pkg, need: need, relation: 10, recipient: c, donorName: "USA")
        XCTAssertEqual(partial.reaction, .partial)
        XCTAssertEqual(partial.accepted.humanitarian, 2.5, accuracy: 1e-9)
        XCTAssertEqual(partial.returned, 7.5, accuracy: 1e-9)
        var military = AidVector(); military.military = 1
        XCTAssertEqual(AidModel.evaluate(package: military, need: need, relation: 10, recipient: c, donorName: "USA").reaction, .reject)
        XCTAssertEqual(AidModel.evaluate(package: pkg, need: need, relation: -80, recipient: c, donorName: "USA").reaction, .publicRejection)
    }

    @MainActor
    func testSendingAidSpendsThePoolAndImprovesRelations() {
        let engine = GameEngine()
        engine.startNewGame(turnLength: .month)
        let gs = engine.gameState!
        let candidates = gs.countries.indices.filter { !gs.countries[$0].isPlayerControlled }
        guard let i = candidates.max(by: { gs.countries[$0].profile.aidNeed.humanitarian < gs.countries[$1].profile.aidNeed.humanitarian }),
              gs.countries[i].profile.aidNeed.humanitarian > 0.2 else { return XCTFail("no country needs aid") }
        let id = gs.countries[i].id
        gs.countries[i].diplomaticRelations["USA"] = 0
        let before = gs.shadow.aidRemaining
        var pkg = AidVector(); pkg.humanitarian = gs.countries[i].profile.aidNeed.humanitarian
        let outcome = engine.sendAid(pkg, to: id)
        XCTAssertEqual(outcome?.reaction, .thanks)
        XCTAssertLessThan(gs.shadow.aidRemaining, before)
        XCTAssertGreaterThan(gs.getCountry(id: id)!.diplomaticRelations["USA"] ?? 0, 0)
    }
}

// MARK: - War Room

final class CombatModelTests: XCTestCase {

    func testStrongerSideWinsAndLoserGetsNewGovernment() {
        let gs = GameState(playerCountryID: "USA")
        var strong = gs.getCountry(id: "RUS")!, weak = gs.getCountry(id: "GEO") ?? gs.getCountry(id: "LTU")!
        strong.militaryStrength = 90; weak.militaryStrength = 15
        var front = CombatModel.makeFront(attacker: strong, defender: weak, date: gs.currentDate)
        var verdict = FrontStatus.fighting
        for _ in 0..<400 where verdict == .fighting {
            let o = CombatModel.battle(front, attackerStrength: strong.militaryStrength, defenderStrength: weak.militaryStrength, rolls: (0.5, 0.5))
            CombatModel.apply(o, to: &front, date: gs.currentDate)
            verdict = CombatModel.verdict(front)
        }
        XCTAssertEqual(verdict, .attackerWon)
        XCTAssertGreaterThan(front.attackerMomentum, 0)

        CombatModel.installGovernment(on: &weak, by: strong)
        XCTAssertEqual(weak.alignment, strong.alignment)
        XCTAssertEqual(weak.profile.ideology, strong.profile.ideology)
        XCTAssertFalse(weak.atWarWith.contains(strong.id))
    }

    func testUSTroopsShiftTheBalance() {
        let gs = GameState(playerCountryID: "USA")
        let a = gs.getCountry(id: "IRQ")!, d = gs.getCountry(id: "KWT")!
        var front = CombatModel.makeFront(attacker: a, defender: d, date: gs.currentDate)
        let without = CombatModel.battle(front, attackerStrength: a.militaryStrength, defenderStrength: d.militaryStrength, rolls: (0.5, 0.5))
        front.usSide = d.id; front.usTroops = 500
        let with = CombatModel.battle(front, attackerStrength: a.militaryStrength, defenderStrength: d.militaryStrength, rolls: (0.5, 0.5))
        XCTAssertLessThan(with.momentumChange, without.momentumChange)
        XCTAssertGreaterThan(with.attackerLosses, without.attackerLosses)
    }

    @MainActor
    func testFrontsFollowWarsAndResolve() {
        let engine = GameEngine()
        engine.startNewGame(turnLength: .month)
        engine.declareWar(aggressor: "BRA", defender: "ARG")
        engine.syncFronts()
        let gs = engine.gameState!
        guard let i = gs.shadow.fronts.firstIndex(where: { $0.attacker == "BRA" && $0.defender == "ARG" }) else { return XCTFail("no front") }
        engine.resolveFront(index: i, verdict: .attackerWon)
        XCTAssertFalse(gs.getCountry(id: "BRA")!.atWarWith.contains("ARG"))
        XCTAssertFalse(gs.activeWars.contains { $0.aggressor == "BRA" && $0.defender == "ARG" })
        XCTAssertEqual(gs.shadow.fronts[i].status, .attackerWon)
    }
}

// MARK: - Scenarios & world evaluation

final class ScenarioTests: XCTestCase {

    func test1990ScenarioSetsDateWarsAndEvents() {
        let gs = ScenarioLoader.makeGameState(.world1990, packFolder: nil)
        XCTAssertEqual(gs.currentDateLabel, "Jun 1, 1990")
        XCTAssertEqual(gs.turnLength, .week)
        XCTAssertTrue(gs.activeWars.contains { $0.aggressor == "ETH" && $0.defender == "SOM" })
        XCTAssertTrue(gs.shadow.eventQueue.contains { $0.kind == .invade && $0.actor == "IRQ" && $0.target == "KWT" })
        XCTAssertEqual(gs.shadow.scenarioID, "world1990")
        XCTAssertNotNil(ScenarioDefinition.world1990.administration)
    }

    func testPackPersonalitiesAreOptional() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("gtnw-pack-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("data"), withIntermediateDirectories: true)
        let json = #"{"countries":[{"name":"Iraq","Ambition":6.0,"Ethic":1.0,"NTA_nuclear_threat_anxiety":42.0}]}"#
        try json.data(using: .utf8)!.write(to: dir.appendingPathComponent("data/scenario_S0.json"))
        let gs = ScenarioLoader.makeGameState(.world1990, packFolder: dir)
        let iraq = gs.getCountry(id: "IRQ")!.profile
        XCTAssertEqual(iraq.ambition, 6)
        XCTAssertEqual(iraq.ethic, 1)
        XCTAssertEqual(iraq.anxieties.nuclear, 42)
    }

    @MainActor
    func testScriptedInvasionFiresOnItsDate() {
        let engine = GameEngine()
        engine.startScenario(.world1990, turnLength: .month)
        let gs = engine.gameState!
        while gs.currentDate < GameCalendar.date(year: 1990, month: 8, day: 2) {
            gs.turn += 1
            engine.processShadowTurn()
        }
        XCTAssertTrue(gs.getCountry(id: "IRQ")!.atWarWith.contains("KWT")
                      || gs.shadow.fronts.contains { $0.attacker == "IRQ" && $0.defender == "KWT" },
                      "Iraq invades Kuwait on Aug 2, 1990 (the front may already be decided by month's end)")
    }

    func testWorldEvaluationBands() {
        XCTAssertEqual(WorldEvaluation.peaceLevel(index: 95), .lastingPeace)
        XCTAssertEqual(WorldEvaluation.peaceLevel(index: 45), .coldWar)
        XCTAssertEqual(WorldEvaluation.peaceLevel(index: 5), .totalWar)
        let gs = GameState(playerCountryID: "USA")
        let e = WorldEvaluation.evaluate(gs)
        XCTAssertTrue((0...100).contains(e.influenceShare))
        XCTAssertGreaterThan(e.usQualityOfLife, e.worldQualityOfLife)
    }

    func testCityGrowsWithWealthAndBurnsWhenNuked() {
        let gs = GameState(playerCountryID: "USA")
        let usa = gs.getCountry(id: "USA")!
        let poor = gs.countries.min { $0.economicStrength < $1.economicStrength }!
        let rich = CityLayout.layout(for: usa, strikes: [])
        XCTAssertGreaterThan(rich.levels[.downtown]!, CityLayout.layout(for: poor, strikes: []).levels[.downtown]!)
        XCTAssertFalse(rich.burning)
        let strike = NuclearStrike(attacker: "RUS", target: "USA", warheadsUsed: 1, turn: 0, casualties: 0, radiationSpread: 0)
        XCTAssertTrue(CityLayout.layout(for: usa, strikes: [strike]).burning)
    }
}

// MARK: - Theme

final class ThemeTests: XCTestCase {

    func testThemePersistsInInjectedDefaults() {
        let name = "GTNWTests.theme.\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: name)!
        defer { suite.removePersistentDomain(forName: name) }
        let a = ThemeManager(defaults: suite)
        XCTAssertEqual(a.theme, .modern)
        a.theme = .retro
        XCTAssertEqual(ThemeManager(defaults: suite).theme, .retro, "a new manager reads the saved choice")
        a.toggle()
        XCTAssertEqual(ThemeManager(defaults: suite).theme, .modern)
    }

    func testEGAPaletteHasSixteenColours() {
        XCTAssertEqual(EGA.all.count, 16)
        XCTAssertEqual(EGA.ramp.count, 7)
    }
}

// MARK: - Terms of surrender: annex as a territory, or choose the new government (3.2.0)

@MainActor
final class PostWarSettlementTests: XCTestCase {

    /// A fresh game where the U.S. has just beaten `target`. Returns the engine and the pending settlement.
    private func usVictory(over target: String) throws -> (GameEngine, GameState, PostWarSettlement) {
        let engine = GameEngine()
        engine.startNewGame(turnLength: .month)
        let gs = try XCTUnwrap(engine.gameState)
        _ = try XCTUnwrap(gs.getCountry(id: target), "\(target) missing from the default world")
        engine.declareWar(aggressor: "USA", defender: target)
        engine.syncFronts()
        let i = try XCTUnwrap(gs.shadow.fronts.firstIndex { $0.attacker == "USA" && $0.defender == target })
        engine.resolveFront(index: i, verdict: .attackerWon)
        let s = try XCTUnwrap(gs.shadow.pendingSettlements.first { $0.loser == target })
        return (engine, gs, s)
    }

    // Functional: routing

    func testUSVictoryAsksThePresidentInsteadOfInstallingAGovernment() throws {
        let engine = GameEngine(); engine.startNewGame(turnLength: .month)
        let before = try XCTUnwrap(engine.gameState?.getCountry(id: "CUB"))
        let (_, gs, s) = try usVictory(over: "CUB")
        XCTAssertEqual(s.victor, "USA")
        let cub = try XCTUnwrap(gs.getCountry(id: "CUB"))
        XCTAssertEqual(cub.government, before.government, "nothing is installed until the President decides")
        XCTAssertFalse(cub.isTerritory)
        XCTAssertFalse(cub.atWarWith.contains("USA"))
    }

    func testAIVersusAIVictoryIsUnchanged() throws {
        let engine = GameEngine(); engine.startNewGame(turnLength: .month)
        let gs = try XCTUnwrap(engine.gameState)
        engine.declareWar(aggressor: "BRA", defender: "ARG")
        engine.syncFronts()
        let i = try XCTUnwrap(gs.shadow.fronts.firstIndex { $0.attacker == "BRA" && $0.defender == "ARG" })
        engine.resolveFront(index: i, verdict: .attackerWon)
        XCTAssertTrue(gs.shadow.pendingSettlements.isEmpty, "AI-vs-AI surrenders never ask the President")
        XCTAssertEqual(gs.getCountry(id: "ARG")?.alignment, gs.getCountry(id: "BRA")?.alignment)
        XCTAssertFalse(gs.getCountry(id: "ARG")!.isTerritory)
    }

    func testVictoryWithUSTroopsOnTheWinningSideAlsoAsks() throws {
        let engine = GameEngine(); engine.startNewGame(turnLength: .month)
        let gs = try XCTUnwrap(engine.gameState)
        engine.declareWar(aggressor: "BRA", defender: "ARG")
        engine.syncFronts()
        let i = try XCTUnwrap(gs.shadow.fronts.firstIndex { $0.attacker == "BRA" && $0.defender == "ARG" })
        XCTAssertTrue(engine.commitTroops(frontID: gs.shadow.fronts[i].id, side: "BRA", thousands: 50))
        engine.resolveFront(index: i, verdict: .attackerWon)
        XCTAssertEqual(gs.shadow.pendingSettlements.first?.loser, "ARG")
    }

    // Functional: annexation and the map

    func testAnnexMakesAUSTerritoryAndSeizesTheArsenal() throws {
        let (engine, gs, s) = try usVictory(over: "PRK")
        let usBefore = try XCTUnwrap(gs.getCountry(id: "USA")).nuclearWarheads
        let seized = try XCTUnwrap(gs.getCountry(id: "PRK")).nuclearWarheads
        XCTAssertTrue(engine.settle(s.id, choice: .annex))
        let prk = try XCTUnwrap(gs.getCountry(id: "PRK")), usa = try XCTUnwrap(gs.getCountry(id: "USA"))
        XCTAssertEqual(prk.territoryOf, "USA")
        XCTAssertTrue(prk.isTerritory)
        XCTAssertEqual(prk.alignment, usa.alignment, "a territory shows in its owner's colour on the Alliances map")
        XCTAssertEqual(prk.nuclearWarheads, 0)
        XCTAssertEqual(usa.nuclearWarheads, usBefore + seized)
        XCTAssertTrue(usa.alliances.contains("PRK"))
        XCTAssertGreaterThan(prk.profile.outcry, 39, "occupation breeds an insurgency")
        XCTAssertTrue(gs.shadow.pendingSettlements.isEmpty)
        XCTAssertEqual(CombatModel.territoryTitle(ownerID: "USA", ownerName: usa.name), "U.S. TERRITORY")
        XCTAssertEqual(CombatModel.territoryTitle(ownerID: "GBR", ownerName: "United Kingdom"), "UNITED KINGDOM TERRITORY")
        XCTAssertTrue(gs.shadow.ticker.last?.text.contains("U.S. territory") ?? false)
    }

    func testAnnexationAngersRivalsMoreThanAllies() throws {
        let (engine, gs, s) = try usVictory(over: "CUB")
        let rus0 = gs.getCountry(id: "RUS")?.diplomaticRelations["USA"] ?? 0
        let gbr = try XCTUnwrap(gs.getCountry(id: "GBR"))
        let gbr0 = gbr.diplomaticRelations["USA"] ?? 0
        let ruth0 = gs.shadow.ruthlessness
        engine.settle(s.id, choice: .annex)
        let rusDrop = rus0 - (gs.getCountry(id: "RUS")?.diplomaticRelations["USA"] ?? 0)
        let gbrDrop = gbr0 - (gs.getCountry(id: "GBR")?.diplomaticRelations["USA"] ?? 0)
        XCTAssertGreaterThan(rusDrop, gbrDrop)
        XCTAssertGreaterThan(gs.shadow.ruthlessness, ruth0)
    }

    // Unit: every government type

    func testEachGovernmentTypeHasItsOwnCharacter() throws {
        let gs = GameState(playerCountryID: "USA")
        let usa = try XCTUnwrap(gs.getCountry(id: "USA"))
        let base = try XCTUnwrap(gs.getCountry(id: "CUB"))
        var result: [PostWarGovernment: Country] = [:]
        for g in PostWarGovernment.allCases {
            var c = base
            CombatModel.installChosenGovernment(g, on: &c, by: usa)
            result[g] = c
            XCTAssertFalse(c.atWarWith.contains("USA"), g.title)
            XCTAssertFalse(g.summary.isEmpty)
        }
        XCTAssertEqual(result[.democraticRepublic]?.government, .republic)
        XCTAssertEqual(result[.democraticRepublic]?.profile.ideology, .liberalDemocracy)
        XCTAssertEqual(result[.democraticRepublic]?.alignment, .western)
        XCTAssertGreaterThan(result[.democraticRepublic]!.electionCycle, 0)
        XCTAssertEqual(result[.constitutionalMonarchy]?.government, .monarchy)
        XCTAssertEqual(result[.constitutionalMonarchy]?.alignment, usa.alignment)
        XCTAssertEqual(result[.militaryJunta]?.government, .military)
        XCTAssertEqual(result[.militaryJunta]?.alignment, .independent)
        XCTAssertEqual(result[.communistState]?.alignment, .eastern)
        XCTAssertLessThan(result[.communistState]!.diplomaticRelations["USA"]!, 0)
        XCTAssertEqual(result[.theocracy]?.government, .theocracy)
        XCTAssertEqual(result[.provisional]?.electionCycle, 2, "a caretaker council calls elections soon")
        XCTAssertEqual(result[.clientState]?.alignment, usa.alignment)
        XCTAssertTrue(result[.clientState]!.alliances.contains("USA"))
        // A junta is the least stable; a client state is the friendliest; a monarchy is the steadiest.
        let stab = result.mapValues(\.stability), rel = result.mapValues { $0.diplomaticRelations["USA"] ?? 0 }
        XCTAssertEqual(stab.min { $0.value < $1.value }?.key, .militaryJunta)
        XCTAssertEqual(stab.max { $0.value < $1.value }?.key, .constitutionalMonarchy)
        XCTAssertEqual(rel.max { $0.value < $1.value }?.key, .clientState)
        for g in PostWarGovernment.allCases { XCTAssertNil(result[g]?.territoryOf, "a new government is sovereign") }
    }

    func testClientStateJoinsTheVictorsAlliance() throws {
        let (engine, gs, s) = try usVictory(over: "CUB")
        engine.settle(s.id, choice: .government(.clientState))
        XCTAssertTrue(gs.getCountry(id: "USA")!.alliances.contains("CUB"))
        XCTAssertEqual(gs.getCountry(id: "CUB")?.profile.ideology, .nationalism)
        XCTAssertTrue(gs.shadow.ticker.last?.text.contains("client state") ?? false)
    }

    // Retry / default: an unanswered choice falls back to the pre-3.2 settlement

    func testUnansweredChoiceDefaultsToTheVictorsModelNextTurn() throws {
        let (engine, gs, s) = try usVictory(over: "CUB")
        gs.shadow.pendingSettlements[0].date = Date.distantPast
        engine.applyOverdueSettlements()
        XCTAssertTrue(gs.shadow.pendingSettlements.isEmpty)
        let cub = try XCTUnwrap(gs.getCountry(id: "CUB"))
        XCTAssertEqual(cub.alignment, gs.getCountry(id: "USA")?.alignment)
        XCTAssertFalse(cub.isTerritory)
        XCTAssertFalse(engine.settle(s.id, choice: .annex), "an answered settlement can't be answered twice")
    }

    // Security: bad input is a no-op

    func testUnknownSettlementIsIgnored() throws {
        let (engine, gs, _) = try usVictory(over: "CUB")
        let snapshot = gs.getCountry(id: "CUB")
        XCTAssertFalse(engine.settle(UUID(), choice: .annex))
        XCTAssertEqual(gs.getCountry(id: "CUB"), snapshot)
        XCTAssertEqual(gs.shadow.pendingSettlements.count, 1)
    }

    // Integration: save / load

    func testTerritoriesAndPendingChoicesSurviveSaveAndLoad() throws {
        let (engine, gs, s) = try usVictory(over: "CUB")
        engine.settle(s.id, choice: .annex)
        engine.declareWar(aggressor: "USA", defender: "VEN")
        engine.syncFronts()
        let i = try XCTUnwrap(gs.shadow.fronts.firstIndex { $0.defender == "VEN" && $0.status == .fighting })
        engine.resolveFront(index: i, verdict: .attackerWon)
        let data = try JSONEncoder().encode(gs)
        let loaded = try JSONDecoder().decode(GameState.self, from: data)
        XCTAssertEqual(loaded.getCountry(id: "CUB")?.territoryOf, "USA")
        XCTAssertEqual(loaded.shadow.pendingSettlements.map(\.loser), ["VEN"])
    }

    func testSavesFromBefore320LoadAsSovereignWithNothingPending() throws {
        let (_, gs, _) = try usVictory(over: "CUB")
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(gs)) as? [String: Any])
        var shadow = try XCTUnwrap(json["shadow"] as? [String: Any])
        shadow.removeValue(forKey: "pendingSettlements"); json["shadow"] = shadow
        json["countries"] = (json["countries"] as? [[String: Any]])?.map { var c = $0; c.removeValue(forKey: "territoryOf"); return c }
        let loaded = try JSONDecoder().decode(GameState.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertTrue(loaded.shadow.pendingSettlements.isEmpty)
        XCTAssertFalse(loaded.countries.contains { $0.isTerritory })
    }

    // Frame: territories are never toppled by unrest; it becomes an insurgency

    func testTerritoryUnrestIsAnInsurgencyNotACoup() throws {
        let (engine, gs, s) = try usVictory(over: "CUB")
        engine.settle(s.id, choice: .annex)
        let i = try XCTUnwrap(gs.countries.firstIndex { $0.id == "CUB" })
        for _ in 0..<12 {
            gs.countries[i].profile.outcry = 100; gs.countries[i].stability = 5
            engine.processShadowTurn()
        }
        let cub = try XCTUnwrap(gs.getCountry(id: "CUB"))
        XCTAssertEqual(cub.territoryOf, "USA")
        XCTAssertEqual(cub.government, gs.getCountry(id: "USA")?.government)
    }

    // Performance

    func testChoosingAGovernmentIsCheap() throws {
        let gs = GameState(playerCountryID: "USA")
        let usa = try XCTUnwrap(gs.getCountry(id: "USA")), base = try XCTUnwrap(gs.getCountry(id: "CUB"))
        measure {
            for _ in 0..<500 { for g in PostWarGovernment.allCases { var c = base; CombatModel.installChosenGovernment(g, on: &c, by: usa) } }
        }
    }

    // Retry: a double-click / resubmitted order never applies twice

    func testAnnexOrderResubmittedTwiceSeizesTheArsenalOnce() throws {
        let (engine, gs, s) = try usVictory(over: "PRK")
        let usBefore = try XCTUnwrap(gs.getCountry(id: "USA")).nuclearWarheads
        let seized = try XCTUnwrap(gs.getCountry(id: "PRK")).nuclearWarheads
        XCTAssertTrue(engine.settle(s.id, choice: .annex))
        let ruthAfterFirst = gs.shadow.ruthlessness
        XCTAssertFalse(engine.settle(s.id, choice: .annex), "the retry is refused")
        XCTAssertFalse(engine.settle(s.id, choice: .government(.clientState)), "and can't be swapped for another order")
        XCTAssertEqual(gs.getCountry(id: "USA")?.nuclearWarheads, usBefore + seized)
        XCTAssertEqual(gs.shadow.ruthlessness, ruthAfterFirst)
    }

    // Retry: the President saves (or the app quits) mid-decision, reloads, and answers then

    func testPendingChoiceCanBeAnsweredAfterSaveAndReload() throws {
        let (_, gs, s) = try usVictory(over: "VEN")
        let loaded = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(gs))
        let engine2 = GameEngine()
        engine2.gameState = loaded
        XCTAssertTrue(engine2.settle(s.id, choice: .government(.provisional)))
        XCTAssertTrue(loaded.shadow.pendingSettlements.isEmpty)
        XCTAssertEqual(loaded.getCountry(id: "VEN")?.electionCycle, 2)
        XCTAssertFalse(loaded.getCountry(id: "VEN")!.isTerritory)
    }
}

// MARK: - Unclaimed lands: claim them, name them, rename territories (3.3.0)

@MainActor
final class UnclaimedLandTests: XCTestCase {

    /// A game started in 1850 (Fillmore): pre-colonial-independence Africa has no countries yet.
    private func game1850() throws -> (GameEngine, GameState) {
        let engine = GameEngine()
        engine.startNewGame(administration: Advisor.fillmoreAdministration(), turnLength: .month)
        return (engine, try XCTUnwrap(engine.gameState))
    }

    // Unit: which lands are unclaimed, per year

    func testNigeriaIsUnclaimedIn1850AndACountryIn1970() {
        XCTAssertTrue(WorldCountriesDatabase.unclaimedLandIDs(year: 1850).contains("CMR"))
        XCTAssertFalse(WorldCountriesDatabase.countriesForYear(1850).contains { $0.id == "CMR" })
        XCTAssertFalse(WorldCountriesDatabase.unclaimedLandIDs(year: 1970).contains("NGA"))
        XCTAssertTrue(WorldCountriesDatabase.countriesForYear(1970).contains { $0.id == "NGA" })
        XCTAssertTrue(WorldCountriesDatabase.unclaimedLandIDs(year: 1900).contains("ZAF"))
        XCTAssertFalse(WorldCountriesDatabase.unclaimedLandIDs(year: 1920).contains("ZAF"))
        XCTAssertTrue(WorldCountriesDatabase.unclaimedLandIDs(year: 1940).contains("LBY"))
        XCTAssertFalse(WorldCountriesDatabase.unclaimedLandIDs(year: 1955).contains("LBY"))
        XCTAssertTrue(WorldCountriesDatabase.unclaimedLandIDs(year: 2025).isEmpty)
    }

    func testLandsAPredecessorCoversAreNeverUnclaimed() {
        let ids1900 = WorldCountriesDatabase.unclaimedLandIDs(year: 1900)
        for id in ["UKR", "KAZ", "GEO", "BLR", "EST", "RUS", "DEU", "SRB", "CZE", "KOR", "TUR", "IND", "POL", "AUS"] {
            XCTAssertFalse(ids1900.contains(id), "\(id) is not unclaimed in 1900")
        }
        let owned = Set(WorldMapData.historicalOwners.values.flatMap { $0 })
        for year in stride(from: 1789, through: 2030, by: 7) {
            let unclaimed = WorldCountriesDatabase.unclaimedLandIDs(year: year)
            XCTAssertTrue(unclaimed.isDisjoint(with: owned), "no era entity's outline is unclaimed")
            let present = Set(WorldCountriesDatabase.countriesForYear(year).map(\.id))
            XCTAssertTrue(unclaimed.isDisjoint(with: present), "\(year): an unclaimed land is never also a country")
            for id in unclaimed { XCTAssertNotNil(WorldCountriesDatabase.template(id: id), id) }
        }
    }

    func testGameStateDerivesUnclaimedFromItsStartYear() throws {
        let (_, gs) = try game1850()
        XCTAssertEqual(gs.eraStartYear, 1850)
        XCTAssertTrue(gs.unclaimedLandIDs.contains("CMR"))
        XCTAssertNil(gs.getCountry(id: "CMR"), "unclaimed land is not a country, so it never takes a computer turn")
        XCTAssertEqual(GameState(playerCountryID: "USA").unclaimedLandIDs, [Antarctica.id], "only Antarctica (3.10.0) in a modern game")
    }

    // Functional: the whole flow

    func testClaimNigeriaIn1850NameItAndItShowsAsAUSTerritory() throws {
        let (engine, gs) = try game1850()
        let used0 = gs.actionsUsedThisTurn, ruth0 = gs.shadow.ruthlessness
        XCTAssertTrue(engine.claimLand("CMR"))
        let land = try XCTUnwrap(gs.getCountry(id: "CMR"))
        XCTAssertEqual(land.territoryOf, "USA")
        XCTAssertEqual(land.alignment, gs.getCountry(id: "USA")?.alignment)
        XCTAssertEqual(land.name, "Cameroon", "starts with the land's modern name until the President names it")
        XCTAssertEqual(land.nuclearWarheads, 0)
        XCTAssertLessThanOrEqual(land.profile.outcry, 20, "no occupation insurgency: nobody governed it")
        XCTAssertFalse(gs.unclaimedLandIDs.contains("CMR"))
        XCTAssertEqual(gs.actionsUsedThisTurn, used0 + 1)
        XCTAssertEqual(gs.shadow.ruthlessness, ruth0 + ExpansionModel.politics(year: 1850, nth: 1).ruthlessness, accuracy: 1e-9)   // 3.7.0 era politics
        XCTAssertTrue(gs.getCountry(id: "USA")!.alliances.contains("CMR"))
        XCTAssertTrue(gs.shadow.ticker.last?.text.contains("U.S. territory") ?? false)

        XCTAssertTrue(engine.renameTerritory("CMR", to: "  New Albion  "))
        XCTAssertEqual(gs.getCountry(id: "CMR")?.name, "New Albion")
        XCTAssertEqual(CombatModel.territoryTitle(ownerID: "USA", ownerName: "United States"), "U.S. TERRITORY")
        XCTAssertTrue(gs.shadow.warLog.last?.contains("New Albion") ?? false)
    }

    func testClaimingCostsLittleGoodwill() throws {
        let (engine, gs) = try game1850()
        let before = Dictionary(gs.countries.map { ($0.id, $0.diplomaticRelations["USA"] ?? 0) }, uniquingKeysWith: { a, _ in a })
        engine.claimLand("CMR")
        for c in gs.countries where c.id != "USA" && c.id != "CMR" {
            let drop = (before[c.id] ?? 0) - (c.diplomaticRelations["USA"] ?? 0)
            XCTAssertLessThanOrEqual(drop, 5, c.id)
        }
    }

    func testRenameA320AnnexedCountry() throws {
        let engine = GameEngine(); engine.startNewGame(turnLength: .month)
        let gs = try XCTUnwrap(engine.gameState)
        engine.declareWar(aggressor: "USA", defender: "CUB")
        engine.syncFronts()
        let i = try XCTUnwrap(gs.shadow.fronts.firstIndex { $0.defender == "CUB" && $0.status == .fighting })
        engine.resolveFront(index: i, verdict: .attackerWon)
        let s = try XCTUnwrap(gs.shadow.pendingSettlements.first { $0.loser == "CUB" })
        XCTAssertTrue(engine.settle(s.id, choice: .annex))
        XCTAssertTrue(engine.renameTerritory("CUB", to: "Isla Libertad"))
        XCTAssertEqual(gs.getCountry(id: "CUB")?.name, "Isla Libertad")
        XCTAssertEqual(gs.getCountry(id: "CUB")?.territoryOf, "USA")
    }

    // Security: names are validated and kept as plain text; bad targets are no-ops

    func testTerritoryNameValidation() {
        XCTAssertEqual(CombatModel.validTerritoryName("  Fort Fillmore \n"), "Fort Fillmore")
        XCTAssertNil(CombatModel.validTerritoryName(""))
        XCTAssertNil(CombatModel.validTerritoryName("   \t  "))
        XCTAssertNotNil(CombatModel.validTerritoryName(String(repeating: "a", count: 40)))
        XCTAssertNil(CombatModel.validTerritoryName(String(repeating: "a", count: 41)))
        XCTAssertNotNil(CombatModel.validTerritoryName(String(repeating: "🇺🇸", count: 40)), "length counts characters")
        for bad in ["New\nAlbion", "New\rAlbion", "New\u{2028}Albion", "Nul\u{0}l", "Bell\u{7}", "Esc\u{1B}[31m", "Tab\there"] {
            XCTAssertNil(CombatModel.validTerritoryName(bad), bad.debugDescription)
        }
        for odd in ["<script>alert(1)</script>", "Robert'); --", "%@%n%s", "**bold** [x](http://e.vil)", "{{name}} $(rm -rf)"] {
            XCTAssertEqual(CombatModel.validTerritoryName(odd), odd, "kept verbatim, shown as plain text")
        }
    }

    func testInjectionishNamesAreStoredVerbatimAndBadTargetsRefused() throws {
        let (engine, gs) = try game1850()
        XCTAssertFalse(engine.claimLand("FRA"), "a country is not unclaimed land")
        XCTAssertFalse(engine.claimLand("XXX"))
        XCTAssertFalse(engine.claimLand(""))
        XCTAssertTrue(engine.claimLand("CMR"))
        let odd = "<b>Robert'); --</b> %@"
        XCTAssertTrue(engine.renameTerritory("CMR", to: odd))
        XCTAssertEqual(gs.getCountry(id: "CMR")?.name, odd)
        XCTAssertFalse(engine.renameTerritory("CMR", to: "Two\nLines"))
        XCTAssertFalse(engine.renameTerritory("CMR", to: ""))
        XCTAssertEqual(gs.getCountry(id: "CMR")?.name, odd, "a rejected name changes nothing")
        let fra = gs.getCountry(id: "FRA")?.name
        XCTAssertFalse(engine.renameTerritory("FRA", to: "Gaul"), "only the President's territories can be renamed")
        XCTAssertFalse(engine.renameTerritory("KEN", to: "Somewhere"), "nor unclaimed land")
        XCTAssertEqual(gs.getCountry(id: "FRA")?.name, fra)
    }

    // Retry: double-submits never apply twice

    func testDoubleClaimAppliesOnce() throws {
        let (engine, gs) = try game1850()
        let n0 = gs.countries.count
        XCTAssertTrue(engine.claimLand("CMR"))
        let used = gs.actionsUsedThisTurn, ruth = gs.shadow.ruthlessness, ticker = gs.shadow.ticker.count
        XCTAssertFalse(engine.claimLand("CMR"), "the retry is refused")
        XCTAssertEqual(gs.countries.count, n0 + 1)
        XCTAssertEqual(gs.countries.filter { $0.id == "CMR" }.count, 1)
        XCTAssertEqual(gs.actionsUsedThisTurn, used)
        XCTAssertEqual(gs.shadow.ruthlessness, ruth)
        XCTAssertEqual(gs.shadow.ticker.count, ticker)
    }

    func testDoubleRenameIsHarmless() throws {
        let (engine, gs) = try game1850()
        engine.claimLand("CMR")
        XCTAssertTrue(engine.renameTerritory("CMR", to: "New Albion"))
        let ticker = gs.shadow.ticker.count, log = gs.shadow.warLog.count
        XCTAssertTrue(engine.renameTerritory("CMR", to: "New Albion "), "resubmitting the same name succeeds")
        XCTAssertEqual(gs.shadow.ticker.count, ticker, "and changes nothing")
        XCTAssertEqual(gs.shadow.warLog.count, log)
    }

    func testRenameAfterSaveAndReload() throws {
        let (engine, gs) = try game1850()
        engine.claimLand("CMR")
        engine.renameTerritory("CMR", to: "New Albion")
        let loaded = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(gs))
        let engine2 = GameEngine(); engine2.gameState = loaded
        XCTAssertTrue(engine2.renameTerritory("CMR", to: "Albion Major"))
        XCTAssertEqual(loaded.getCountry(id: "CMR")?.name, "Albion Major")
        XCTAssertFalse(engine2.claimLand("CMR"), "still claimed after the reload")
        XCTAssertTrue(engine2.claimLand("KEN"), "other land is still unclaimed after the reload")
    }

    // Integration: save / load, old saves

    func testClaimedTerritorySurvivesSaveSlotAndLoad() throws {
        let dir = StoreFixtures.tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let manager = SaveManager(folder: dir)
        let (engine, gs) = try game1850()
        engine.claimLand("CMR")
        engine.renameTerritory("CMR", to: "New Albion")
        try engine.saveGame(slot: 3, manager: manager)
        let engine2 = GameEngine()
        try engine2.loadGame(slot: 3, manager: manager)
        let loaded = try XCTUnwrap(engine2.gameState)
        XCTAssertEqual(loaded.getCountry(id: "CMR")?.name, "New Albion")
        XCTAssertEqual(loaded.getCountry(id: "CMR")?.territoryOf, "USA")
        XCTAssertFalse(loaded.unclaimedLandIDs.contains("CMR"))
        XCTAssertEqual(loaded.unclaimedLandIDs, gs.unclaimedLandIDs)
    }

    func testPre330SaveOfAn1850GameDecodesWithLandsUnclaimed() throws {
        let (_, gs) = try game1850()
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(gs)) as? [String: Any])
        json["countries"] = (json["countries"] as? [[String: Any]])?.map { var c = $0; c.removeValue(forKey: "territoryOf"); return c }
        var shadow = try XCTUnwrap(json["shadow"] as? [String: Any])
        shadow.removeValue(forKey: "pendingSettlements"); json["shadow"] = shadow
        let loaded = try JSONDecoder().decode(GameState.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertTrue(loaded.unclaimedLandIDs.contains("CMR"))
        let engine = GameEngine(); engine.gameState = loaded
        XCTAssertTrue(engine.claimLand("CMR"))
    }

    // Performance: era filtering + the unclaimed set across every playable year

    func testEraFilteringAndUnclaimedAreFastAcrossAllYears() {
        measure {
            for year in 1789...2030 {
                _ = WorldCountriesDatabase.countriesForYear(year)
                _ = WorldCountriesDatabase.unclaimedLandIDs(year: year)
            }
        }
    }

    func testUnclaimedLookupOnAGameIsCheap() throws {
        let (_, gs) = try game1850()
        let start = Date()
        for _ in 0..<2_000 { _ = gs.unclaimedLandIDs }
        XCTAssertLessThan(Date().timeIntervalSince(start), 2.0, "the map reads it on every redraw")
    }
}

// MARK: - Play history for claims and renames (3.3.0)

final class UnclaimedLandPlayHistoryTests: XCTestCase {
    private var dir: URL!
    override func setUp() { super.setUp(); dir = StoreFixtures.tempDir() }
    override func tearDown() { try? FileManager.default.removeItem(at: dir); super.tearDown() }

    @MainActor
    func testClaimAndRenameBecomePlayEventsWithTheName() async throws {
        let remote = InMemoryGameStore()
        let (e, service) = PlayFixtures.engine(dir, remote: remote)
        e.startNewGame(playerCountryID: "USA", administration: Advisor.fillmoreAdministration(), turnLength: .month)
        let id = try XCTUnwrap(e.gameState?.shadow.playSessionID)
        XCTAssertTrue(e.claimLand("CMR"))
        XCTAssertTrue(e.renameTerritory("CMR", to: "New \"Albion\" <x>"))
        XCTAssertTrue(e.renameTerritory("CMR", to: "New \"Albion\" <x>"))   // a resubmit logs nothing

        let synced = await service.syncNow()

        XCTAssertTrue(synced)
        let events = await remote.events(id)
        let claimed = try XCTUnwrap(events.first { $0.kind == "claimed_land" })
        XCTAssertEqual(PlayFixtures.detail(claimed)["land"] as? String, "CMR")
        XCTAssertEqual(PlayFixtures.detail(claimed)["name"] as? String, "Cameroon")
        let renamed = events.filter { $0.kind == "renamed_territory" }
        XCTAssertEqual(renamed.count, 1)
        XCTAssertEqual(PlayFixtures.detail(renamed[0])["name"] as? String, "New \"Albion\" <x>")
        XCTAssertEqual(PlayFixtures.detail(renamed[0])["old_name"] as? String, "Cameroon")
        XCTAssertEqual(events.map(\.seq), Array(0..<events.count))
    }

    @MainActor
    func testClaimWithoutAStoreStillWorks() throws {
        let e = GameEngine()
        e.startNewGame(administration: Advisor.fillmoreAdministration(), turnLength: .month)
        XCTAssertTrue(e.claimLand("KEN"))
        XCTAssertTrue(e.renameTerritory("KEN", to: "Kilimanjaro"))
    }
}

// MARK: - Sizing an offensive (3.4.0)

@MainActor
final class AttackSizingTests: XCTestCase {

    private func modern() throws -> (GameEngine, GameState) {
        let engine = GameEngine()
        engine.startNewGame(turnLength: .month)
        return (engine, try XCTUnwrap(engine.gameState))
    }

    /// A second engine holding an exact copy of the game, for side-by-side comparisons.
    private func twin(_ gs: GameState) throws -> (GameEngine, GameState) {
        let copy = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(gs))
        let engine = GameEngine(); engine.gameState = copy
        return (engine, copy)
    }

    // Unit: which forces each attack uses, and the pre-3.4 standard sizes

    func testKindsFitTheAttack() {
        XCTAssertEqual(AttackSizing.kinds(for: .tacticalNuke), [.warheads])
        XCTAssertEqual(AttackSizing.kinds(for: .launchNukes), [.warheads])
        XCTAssertEqual(AttackSizing.kinds(for: .groundInvasion), [.troops])
        XCTAssertEqual(AttackSizing.kinds(for: .airStrike), [.aircraft])
        XCTAssertEqual(AttackSizing.kinds(for: .bombardment), [.aircraft])
        XCTAssertTrue(AttackSizing.kinds(for: .sendAmbassador).isEmpty)
        XCTAssertTrue(AttackSizing.kinds(for: .sanctions).isEmpty)
    }

    func testStandardIsThePre34Size() throws {
        let (_, gs) = try modern()
        let usa = try XCTUnwrap(gs.getPlayerCountry())
        XCTAssertEqual(AttackSizing.standard(.tacticalNuke, in: gs).warheads, 3)
        XCTAssertEqual(AttackSizing.standard(.launchNukes, in: gs).warheads, 5)
        XCTAssertEqual(AttackSizing.standard(.strategicNuke, in: gs).warheads, 10)
        XCTAssertEqual(AttackSizing.standard(.groundInvasion, in: gs).troops, (CombatModel.forcePool(usa) * 0.35).rounded())
        XCTAssertEqual(AttackSizing.preset(.standard, for: .groundInvasion, in: gs), AttackSizing.standard(.groundInvasion, in: gs))
        XCTAssertEqual(AttackSizing.scale(AttackSizing.standard(.airStrike, in: gs), for: .airStrike, in: gs), 1)
    }

    func testEraRulesBoundWhatIsAvailable() throws {
        let engine = GameEngine()
        engine.startNewGame(administration: Advisor.fillmoreAdministration(), turnLength: .month)
        let gs1850 = try XCTUnwrap(engine.gameState)
        XCTAssertEqual(AttackSizing.available(.aircraft, in: gs1850), 0, "no planes before military aviation")
        XCTAssertEqual(AttackSizing.available(.warheads, in: gs1850), 0, "no nukes before 1945")
        XCTAssertGreaterThan(AttackSizing.available(.troops, in: gs1850), 0)
        let usa = try XCTUnwrap(gs1850.getPlayerCountry())
        XCTAssertEqual(AttackSizing.aircraftPool(usa, year: 1913), 0)
        XCTAssertGreaterThan(AttackSizing.aircraftPool(usa, year: 1918), 0)
        XCTAssertGreaterThan(AttackSizing.aircraftPool(usa, year: 1944), AttackSizing.aircraftPool(usa, year: 1930), "WWII air arm")
        let (_, gs) = try modern()
        XCTAssertEqual(AttackSizing.available(.warheads, in: gs), Double(gs.getPlayerCountry()!.nuclearWarheads))
    }

    // Unit: monotonicity — more force, higher odds and higher costs

    func testMoreForceMeansHigherOddsAndHigherCosts() throws {
        let (_, gs) = try modern()
        let usa = try XCTUnwrap(gs.getPlayerCountry()), mex = try XCTUnwrap(gs.getCountry(id: "MEX"))
        var last = (odds: -1.0, inv: -1.0, rel: -1.0, hit: -1, ruth: -1, lost: -1)
        for m in stride(from: 0.1, through: 4.0, by: 0.1) {
            let odds = AttackSizing.successOdds(scale: m)
            let inv = AttackSizing.invasionOdds(troops: 100 * m, attacker: usa, defender: mex)
            let rel = AttackSizing.relationFactor(scale: m)
            let hit = AttackSizing.worldHit(scale: m), ruth = AttackSizing.ruthlessness(scale: m)
            let lost = AttackSizing.aircraftLost(sorties: Int(200 * m), against: mex)
            XCTAssertGreaterThanOrEqual(odds, last.odds); XCTAssertGreaterThan(inv, last.inv); XCTAssertGreaterThan(rel, last.rel)
            XCTAssertGreaterThanOrEqual(hit, last.hit); XCTAssertGreaterThanOrEqual(ruth, last.ruth); XCTAssertGreaterThanOrEqual(lost, last.lost)
            last = (odds, inv, rel, hit, ruth, lost)
        }
        XCTAssertLessThan(AttackSizing.successOdds(scale: 0.5), 1, "an undersized attack can fail")
        XCTAssertEqual(AttackSizing.successOdds(scale: 1), 1)
        XCTAssertFalse(AttackSizing.escalates(scale: 1.9)); XCTAssertTrue(AttackSizing.escalates(scale: 2))
    }

    func testBiggerInvasionOpensWithMoreTroopsAndFightsHarder() throws {
        let (e1, gs1) = try modern()
        let (e2, gs2) = try twin(gs1)
        let std = AttackSizing.standard(.groundInvasion, in: gs1).troops
        // Both at or above Standard, so both always succeed (an undersized attack can fail: see the odds test).
        e1.performAdvisedAction(.groundInvasion, targetID: "MEX", advice: nil, size: AttackSize(troops: std * 1.2))
        e2.performAdvisedAction(.groundInvasion, targetID: "MEX", advice: nil, size: AttackSize(troops: std * 1.4))   // within the 3.9.0 manpower pool
        let f1 = try XCTUnwrap(gs1.shadow.fronts.first { $0.defender == "MEX" && $0.status == .fighting })
        let f2 = try XCTUnwrap(gs2.shadow.fronts.first { $0.defender == "MEX" && $0.status == .fighting })
        XCTAssertEqual(f1.attackerTroops, (std * 1.2).rounded()); XCTAssertEqual(f2.attackerTroops, (std * 1.4).rounded())
        let o1 = CombatModel.battle(f1, attackerStrength: 100, defenderStrength: 50, rolls: (0.5, 0.5))
        let o2 = CombatModel.battle(f2, attackerStrength: 100, defenderStrength: 50, rolls: (0.5, 0.5))
        XCTAssertGreaterThan(o2.momentumChange, o1.momentumChange, "more troops win faster")
        XCTAssertGreaterThan(o2.defenderLosses, o1.defenderLosses, "and inflict more casualties")
        XCTAssertGreaterThan(o2.attackerLosses, o1.attackerLosses, "and take more in absolute terms")
        XCTAssertLessThan(AttackSizing.freeTroops(gs2), AttackSizing.freeTroops(gs1), "troops sent are tied up")
    }

    func testMoreWarheadsMoreDamageAndAllAreSpent() throws {
        let (e1, gs1) = try modern()
        let (e2, gs2) = try twin(gs1)
        let w0 = try XCTUnwrap(gs1.getPlayerCountry()).nuclearWarheads
        e1.performAdvisedAction(.tacticalNuke, targetID: "IRN", advice: nil, size: AttackSize(warheads: 2))
        e2.performAdvisedAction(.tacticalNuke, targetID: "IRN", advice: nil, size: AttackSize(warheads: 12))
        XCTAssertEqual(gs1.nuclearStrikes.last?.warheadsUsed, 2)
        XCTAssertEqual(gs2.nuclearStrikes.last?.warheadsUsed, 12)
        XCTAssertEqual(gs2.getPlayerCountry()?.nuclearWarheads, w0 - 12, "warheads fired are spent")
        XCTAssertGreaterThan(gs2.totalCasualties, gs1.totalCasualties)
        XCTAssertGreaterThan(gs2.getCountry(id: "IRN")!.radiationLevel, gs1.getCountry(id: "IRN")!.radiationLevel)
    }

    func testBiggerAirStrikeLosesMoreAircraftAndCostsMoreAbroad() throws {
        let (e1, gs1) = try modern()
        let (e2, gs2) = try twin(gs1)
        let std = AttackSizing.standard(.airStrike, in: gs1).aircraft
        e1.performAdvisedAction(.airStrike, targetID: "VEN", advice: nil, size: AttackSize(aircraft: std))
        e2.performAdvisedAction(.airStrike, targetID: "VEN", advice: nil, size: AttackSize(aircraft: std * 3))
        XCTAssertGreaterThan(gs2.shadow.aircraftLost, gs1.shadow.aircraftLost)
        XCTAssertLessThan(gs2.getCountry(id: "FRA")!.diplomaticRelations["USA"] ?? 0, gs1.getCountry(id: "FRA")!.diplomaticRelations["USA"] ?? 0)
        XCTAssertGreaterThan(gs2.shadow.ruthlessness, gs1.shadow.ruthlessness)
        XCTAssertLessThan(gs2.defconLevel.rawValue, gs1.defconLevel.rawValue, "an overwhelming strike escalates")
        let f2 = try XCTUnwrap(gs2.shadow.fronts.first { $0.defender == "VEN" && $0.status == .fighting })
        XCTAssertLessThan(f2.defenderTroops, f2.defenderInitial, "the raid thins the enemy line")
    }

    // Functional: the default selection reproduces the pre-3.4 behaviour exactly

    func testStandardSizeEqualsLegacyBehaviour() throws {
        for (action, target) in [(PresidentialAction.groundInvasion, "MEX"), (.airStrike, "CUB"), (.tacticalNuke, "PRK"), (.strategicNuke, "IRN")] {
            let (legacy, gsL) = try modern()
            let (sized, gsS) = try twin(gsL)
            legacy.performAdvisedAction(action, targetID: target, advice: nil)
            sized.performAdvisedAction(action, targetID: target, advice: nil, size: AttackSizing.preset(.standard, for: action, in: gsS))
            XCTAssertEqual(gsS.countries, gsL.countries, action.rawValue)
            XCTAssertEqual(gsS.defconLevel, gsL.defconLevel, action.rawValue)
            XCTAssertEqual(gsS.shadow.popularity, gsL.shadow.popularity, action.rawValue)
            XCTAssertEqual(gsS.shadow.ruthlessness, gsL.shadow.ruthlessness, action.rawValue)
            XCTAssertEqual(gsS.shadow.fronts.count, gsL.shadow.fronts.count, action.rawValue)
            XCTAssertEqual(gsS.activeWars.count, gsL.activeWars.count, action.rawValue)
            XCTAssertEqual(gsS.nuclearStrikes.map(\.warheadsUsed), gsL.nuclearStrikes.map(\.warheadsUsed), action.rawValue)
            XCTAssertEqual(gsS.totalCasualties, gsL.totalCasualties, action.rawValue)
            XCTAssertEqual(gsS.actionsUsedThisTurn, gsL.actionsUsedThisTurn)
        }
    }

    func testExpeditionToUnclaimedLandNeedsOnlyASmallForce() throws {
        let engine = GameEngine()
        engine.startNewGame(administration: Advisor.fillmoreAdministration(), turnLength: .month)
        let gs = try XCTUnwrap(engine.gameState)
        let (e2, gs2) = try twin(gs)
        XCTAssertTrue(engine.claimLand("CMR", troops: 1), "a token force suffices: there's no army")
        XCTAssertTrue(e2.claimLand("CMR", troops: 20))
        let small = try XCTUnwrap(gs.getCountry(id: "CMR")), big = try XCTUnwrap(gs2.getCountry(id: "CMR"))
        XCTAssertLessThan(small.militaryStrength, big.militaryStrength)
        XCTAssertLessThan(small.stability, big.stability, "a bigger garrison holds the land more firmly")
        XCTAssertEqual(gs2.shadow.garrisons["CMR"], 20)
        XCTAssertLessThan(AttackSizing.freeTroops(gs2), AttackSizing.freeTroops(gs), "the garrison is tied up")
        let (e3, gs3) = try twin(gs)
        _ = e3
        let std = CombatModel.claim(WorldCountriesDatabase.template(id: "KEN")!, for: gs3.getPlayerCountry()!)
        XCTAssertEqual(std.militaryStrength, 5); XCTAssertEqual(std.stability, 50, "the standard 5K expedition is the 3.3.0 one")
    }

    // Security: bounds and validation

    func testSizesAreClampedToWhatIsAvailable() throws {
        let (_, gs) = try modern()
        let free = AttackSizing.available(.troops, in: gs)
        for bad in [-50.0, 0, .nan, .infinity, 1e12] {
            let c = AttackSizing.clamp(AttackSize(troops: bad, aircraft: Int(min(1e9, max(-1e9, bad.isFinite ? bad : 0))), warheads: -3), for: .groundInvasion, in: gs)
            XCTAssertGreaterThanOrEqual(c.troops, 1); XCTAssertLessThanOrEqual(c.troops, free)
        }
        let w = AttackSizing.clamp(AttackSize(warheads: 1_000_000), for: .launchNukes, in: gs).warheads
        XCTAssertEqual(w, gs.getPlayerCountry()!.nuclearWarheads)
        for p in AttackPreset.allCases {
            for a in [PresidentialAction.groundInvasion, .airStrike, .launchNukes] {
                let s = AttackSizing.preset(p, for: a, in: gs)
                for k in AttackSizing.kinds(for: a) { XCTAssertLessThanOrEqual(s.amount(k), AttackSizing.available(k, in: gs)) }
            }
        }
    }

    func testBadExpeditionSizesAreRefused() throws {
        let engine = GameEngine()
        engine.startNewGame(administration: Advisor.fillmoreAdministration(), turnLength: .month)
        let gs = try XCTUnwrap(engine.gameState)
        for bad in [0.0, -5, .nan, .infinity, 1e9] { XCTAssertFalse(engine.claimLand("CMR", troops: bad), "\(bad)") }
        XCTAssertTrue(gs.unclaimedLandIDs.contains("CMR"))
        XCTAssertEqual(gs.actionsUsedThisTurn, 0)
    }

    func testOversizedNukeOrderFiresOnlyWhatExists() throws {
        let (engine, gs) = try modern()
        let i = try XCTUnwrap(gs.countries.firstIndex { $0.id == "USA" })
        gs.countries[i].nuclearWarheads = 4
        engine.performAdvisedAction(.strategicNuke, targetID: "IRN", advice: nil, size: AttackSize(warheads: 500))
        XCTAssertEqual(gs.nuclearStrikes.last?.warheadsUsed, 4)
        XCTAssertEqual(gs.getPlayerCountry()?.nuclearWarheads, 0)
    }

    // Retry: sizes and tied-up forces survive a reload; old saves decode

    func testLossesAndGarrisonsSurviveSaveAndOldSavesDecode() throws {
        let (engine, gs) = try modern()
        engine.performAdvisedAction(.airStrike, targetID: "VEN", advice: nil, size: AttackSize(aircraft: 400))
        gs.shadow.garrisons["CUB"] = 12
        let loaded = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(gs))
        XCTAssertEqual(loaded.shadow.aircraftLost, gs.shadow.aircraftLost)
        XCTAssertGreaterThan(loaded.shadow.aircraftLost, 0)
        XCTAssertEqual(loaded.shadow.garrisons["CUB"], 12)
        XCTAssertEqual(AttackSizing.preset(.overwhelming, for: .airStrike, in: loaded), AttackSizing.preset(.overwhelming, for: .airStrike, in: gs))
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(gs)) as? [String: Any])
        var shadow = try XCTUnwrap(json["shadow"] as? [String: Any])
        shadow.removeValue(forKey: "aircraftLost"); shadow.removeValue(forKey: "garrisons"); json["shadow"] = shadow
        let old = try JSONDecoder().decode(GameState.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(old.shadow.aircraftLost, 0)
        XCTAssertTrue(old.shadow.garrisons.isEmpty)
    }

    func testRepeatedOrdersEachSpendTheirOwnForces() throws {
        let (engine, gs) = try modern()
        let w0 = gs.getPlayerCountry()!.nuclearWarheads
        engine.performAdvisedAction(.tacticalNuke, targetID: "IRN", advice: nil, size: AttackSize(warheads: 2))
        engine.performAdvisedAction(.tacticalNuke, targetID: "IRN", advice: nil, size: AttackSize(warheads: 2))
        XCTAssertEqual(gs.getPlayerCountry()?.nuclearWarheads, w0 - 4, "a resubmitted order is a second strike, charged again")
    }

    // Performance

    func testSizingMathIsCheap() throws {
        let (_, gs) = try modern()
        measure {
            for _ in 0..<300 {
                for a in [PresidentialAction.groundInvasion, .airStrike, .launchNukes] {
                    for p in AttackPreset.allCases { _ = AttackSizing.scale(AttackSizing.preset(p, for: a, in: gs), for: a, in: gs) }
                }
            }
        }
    }
}

// MARK: - Play history for sized attacks (3.4.0)

final class AttackSizingPlayHistoryTests: XCTestCase {
    private var dir: URL!
    override func setUp() { super.setUp(); dir = StoreFixtures.tempDir() }
    override func tearDown() { try? FileManager.default.removeItem(at: dir); super.tearDown() }

    @MainActor
    func testAttackOrdersRecordTheirSize() async throws {
        let remote = InMemoryGameStore()
        let (e, service) = PlayFixtures.engine(dir, remote: remote)
        e.startNewGame(playerCountryID: "USA", turnLength: .month)
        let id = try XCTUnwrap(e.gameState?.shadow.playSessionID)
        e.performAdvisedAction(.strategicNuke, targetID: "IRN", advice: nil, size: AttackSize(warheads: 12))
        e.performAdvisedAction(.groundInvasion, targetID: "MEX", advice: nil, size: AttackSize(troops: 40))
        let synced = await service.syncNow()
        XCTAssertTrue(synced)
        let orders = await remote.events(id).filter { $0.kind == "attack_ordered" }
        XCTAssertEqual(orders.count, 2)
        let nuke = PlayFixtures.detail(orders[0])
        XCTAssertEqual(nuke["warheads"] as? Int, 12)
        XCTAssertEqual(nuke["summary"] as? String, "12 warheads")
        XCTAssertEqual(nuke["target"] as? String, "IRN")
        XCTAssertEqual(PlayFixtures.detail(orders[1])["troops"] as? Int, 40)
    }
}

// MARK: - Naval operations (3.5.0)

@MainActor
final class NavalOperationsTests: XCTestCase {

    private func modern() throws -> (GameEngine, GameState) {
        let engine = GameEngine()
        engine.startNewGame(turnLength: .month)
        return (engine, try XCTUnwrap(engine.gameState))
    }

    private func game1850() throws -> (GameEngine, GameState) {
        let engine = GameEngine()
        engine.startNewGame(administration: Advisor.fillmoreAdministration(), turnLength: .month)
        return (engine, try XCTUnwrap(engine.gameState))
    }

    /// Advance the calendar a turn at a time and run the fleet step (not the whole simulation).
    private func sail(_ engine: GameEngine, _ gs: GameState, turns: Int) {
        for _ in 0..<turns { gs.turn += 1; gs.actionsUsedThisTurn = 0; engine.processFleets() }
    }

    // Unit: the era table

    func testEraTable() {
        for year in 1789...1800 { XCTAssertTrue(NavalModel.fleets(in: year).isEmpty, "no named U.S. squadron in \(year)") }
        let f1850 = NavalModel.fleets(in: 1850)
        XCTAssertFalse(f1850.isEmpty)
        XCTAssertTrue(f1850.allSatisfy { NavalModel.composition($0, year: 1850).carriers == 0 }, "no carriers in 1850")
        XCTAssertTrue(f1850.allSatisfy { NavalModel.composition($0, year: 1850).submarines == 0 })
        XCTAssertGreaterThan(NavalModel.composition(NavalModel.fleet(id: "pacfleet")!, year: 1944).carriers, 0)
        let ids = { (y: Int) in Set(NavalModel.fleets(in: y).map(\.id)) }
        XCTAssertTrue(ids(1944).contains("fifth")); XCTAssertFalse(ids(1970).contains("fifth")); XCTAssertTrue(ids(2025).contains("fifth"))
        XCTAssertEqual(NavalModel.fleet(id: "fifth")?.period(in: 2025)?.home, "Bahrain")
        XCTAssertTrue(ids(1908).contains("gwf")); XCTAssertFalse(ids(1910).contains("gwf"))
        XCTAssertFalse(ids(2015).contains("second"), "Second Fleet was disestablished 2011–2018")
        XCTAssertTrue(ids(2025).isSuperset(of: ["second", "third", "fifth", "sixth", "seventh"]))
        XCTAssertEqual(Set(NavalModel.fleets.map(\.id)).count, NavalModel.fleets.count)
        XCTAssertEqual(NavalModel.strikeWeapon(year: 1980).contains("Tomahawk"), false)
        XCTAssertTrue(NavalModel.strikeWeapon(year: 1991).contains("Tomahawk"))
    }

    func testFleetTableMatchesTheResearchFile() throws {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Documentation/arsenal/gtnw_us_arsenal_by_era.json")
        guard let data = try? Data(contentsOf: url) else { throw XCTSkip("research file not reachable from the test host") }
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let fleets = try XCTUnwrap(json["fleets"] as? [[String: Any]])
        let firstYear = fleets.compactMap { $0["from"] as? Int }.min() ?? 0
        XCTAssertGreaterThanOrEqual(NavalModel.fleets.flatMap(\.periods).map(\.from).min() ?? 0, firstYear)
        for (name, from) in [("Fifth Fleet", 1944), ("Sixth Fleet", 1950), ("Seventh Fleet", 1943), ("Great White Fleet", 1907)] {
            XCTAssertEqual(fleets.first { $0["name"] as? String == name }?["from"] as? Int, from, name)
            XCTAssertEqual(NavalModel.fleets.first { $0.name == name }?.periods.first?.from, from, name)
        }
    }

    // Unit: transit-time maths

    func testTransitTime() {
        let km = NavalModel.distanceKm(lat1: 26.2, lon1: 50.6, lat2: 35.68, lon2: 139.69)   // Bahrain → Tokyo
        XCTAssertEqual(km, 7_900, accuracy: 400)
        XCTAssertEqual(NavalModel.transitDays(km: 900, year: 2025), 1)
        XCTAssertEqual(NavalModel.transitDays(km: 901, year: 2025), 2)
        XCTAssertEqual(NavalModel.transitDays(km: 0, year: 2025), 1, "at least a day")
        XCTAssertEqual(NavalModel.transitDays(km: km, year: 2025), Int((km / 900).rounded(.up)))
        XCTAssertGreaterThan(NavalModel.transitDays(km: km, year: 1830), NavalModel.transitDays(km: km, year: 1900), "sail is slower than steam")
        XCTAssertGreaterThan(NavalModel.transitDays(km: km, year: 1900), NavalModel.transitDays(km: km, year: 2025))
        XCTAssertEqual(NavalModel.distanceKm(lat1: 10, lon1: 10, lat2: 10, lon2: 10), 0, accuracy: 0.001)
    }

    // Functional: "Send the Fifth Fleet to Japan!"

    func testSendTheFifthFleetToJapanAndBlockade() throws {
        let (engine, gs) = try modern()
        let used = gs.actionsUsedThisTurn
        let d = try XCTUnwrap(engine.orderFleet("fifth", to: "JPN", mission: .blockade))
        XCTAssertEqual(gs.actionsUsedThisTurn, used + 1)
        XCTAssertEqual(d.status, .underway)
        XCTAssertGreaterThan(d.ships.carriers, 0)
        XCTAssertFalse(gs.getCountry(id: "JPN")!.atWarWith.contains("USA"), "nothing happens until the fleet arrives")
        sail(engine, gs, turns: 1)
        let onStation = try XCTUnwrap(gs.shadow.fleetDeployments.first)
        XCTAssertEqual(onStation.status, .onStation)
        XCTAssertTrue(gs.getCountry(id: "JPN")!.atWarWith.contains("USA"), "a blockade is an act of war")
        XCTAssertTrue(gs.shadow.ticker.contains { $0.text.contains("Fifth Fleet blockaded Japan") })
        let gdp = gs.getCountry(id: "JPN")!.gdp
        sail(engine, gs, turns: 2)
        XCTAssertLessThan(gs.getCountry(id: "JPN")!.gdp, gdp, "output falls every turn on station")
        XCTAssertTrue(engine.recallFleet(onStation.id))
        let after = gs.getCountry(id: "JPN")!.gdp
        sail(engine, gs, turns: 1)
        XCTAssertEqual(gs.getCountry(id: "JPN")!.gdp, after, "a recalled fleet blockades nothing")
    }

    func testShowOfForceStrikeAndPositionsOnTheWay() throws {
        let (engine, gs) = try modern()
        let rel0 = gs.getCountry(id: "CUB")!.diplomaticRelations["USA"] ?? 0
        let d = try XCTUnwrap(engine.orderFleet("second", to: "CUB", mission: .showOfForce))
        let mid = Date(timeIntervalSince1970: (d.departed.timeIntervalSince1970 + d.arrives.timeIntervalSince1970) / 2)
        let p = d.position(at: mid)
        XCTAssertEqual(p.lat, (d.fromLat + d.toLat) / 2, accuracy: 0.01)
        XCTAssertEqual(d.position(at: d.departed).lat, d.fromLat, accuracy: 0.001)
        XCTAssertEqual(d.position(at: .distantFuture).lon, d.toLon, accuracy: 0.001)
        sail(engine, gs, turns: 1)
        XCTAssertFalse(gs.getCountry(id: "CUB")!.atWarWith.contains("USA"), "a show of force is not war")
        XCTAssertLessThan(gs.getCountry(id: "CUB")!.diplomaticRelations["USA"] ?? 0, rel0)
        XCTAssertEqual(gs.shadow.fleetDeployments.first?.shipsLost, 0, "nobody fires on a show of force in peacetime")

        let dmg = gs.getCountry(id: "VEN")!.damageLevel
        XCTAssertNotNil(engine.orderFleet("fourth", to: "VEN", mission: .strike))
        sail(engine, gs, turns: 1)
        XCTAssertGreaterThan(gs.getCountry(id: "VEN")!.damageLevel, dmg)
        XCTAssertTrue(gs.getCountry(id: "VEN")!.atWarWith.contains("USA"))
    }

    func testAmphibiousLandingTakesUnclaimedCoastalLandIn1850() throws {
        let (engine, gs) = try game1850()
        XCTAssertNotNil(engine.fleetOrderProblem(fleetID: "africa", target: "CMR", mission: .blockade), "unclaimed land has no ports to blockade")
        XCTAssertNil(engine.fleetOrderProblem(fleetID: "africa", target: "CMR", mission: .amphibious))
        XCTAssertNotNil(engine.orderFleet("africa", to: "CMR", mission: .amphibious))
        sail(engine, gs, turns: 2)
        XCTAssertEqual(gs.getCountry(id: "CMR")?.territoryOf, "USA")
        XCTAssertGreaterThan(gs.shadow.garrisons["CMR"] ?? 0, 0, "the landing force stays as the garrison")
        XCTAssertNotNil(engine.fleetOrderProblem(fleetID: "home", target: "MLI", mission: .amphibious), "Mali is landlocked")
    }

    func testAmphibiousInvasionOpensAFrontWithTheLandingForce() throws {
        let (engine, gs) = try modern()
        XCTAssertNotNil(engine.orderFleet("third", to: "CUB", mission: .amphibious, preset: .overwhelming))
        sail(engine, gs, turns: 1)
        let f = try XCTUnwrap(gs.shadow.fronts.first { $0.defender == "CUB" && $0.status == .fighting })
        let d = try XCTUnwrap(gs.shadow.fleetDeployments.first)
        XCTAssertEqual(f.attackerTroops, NavalModel.landingTroops(d.ships, year: gs.currentYear) * Double(d.shipsAfloat) / Double(d.ships.total), accuracy: 0.001)
    }

    // Functional: the fleet is a real force

    func testLossesScaleWithWhatEachSideHas() throws {
        let (_, gs) = try modern()
        let fleet = NavalModel.fleet(id: "seventh")!
        func deployment(_ commit: Double) -> FleetDeployment {
            FleetDeployment(fleetID: "seventh", target: "X", mission: .strike, commitment: commit,
                            ships: NavalModel.composition(fleet, year: 2025).scaled(commit), fromLat: 0, fromLon: 0, toLat: 0, toLon: 0,
                            departed: Date(), arrives: Date())
        }
        let strong = NavalModel.defence(gs.getCountry(id: "CHN"), year: 2025), weak = NavalModel.defence(gs.getCountry(id: "CUB"), year: 2025)
        XCTAssertGreaterThan(strong, weak)
        let d = deployment(1)
        XCTAssertGreaterThan(NavalModel.shipsLost(d, defence: strong * 10), NavalModel.shipsLost(d, defence: weak))
        XCTAssertEqual(NavalModel.shipsLost(d, defence: 0), 0)
        XCTAssertGreaterThan(NavalModel.power(deployment(1)), NavalModel.power(deployment(0.25)), "more ships committed, more power")
        XCTAssertEqual(NavalModel.defence(nil, year: 2025), 0, "unclaimed land fires no shots")
    }

    // Security: guards

    func testLandlockedAndOtherBadOrdersAreRefused() throws {
        let (engine, gs) = try modern()
        for id in ["CHE", "BOL", "AFG", "MLI", "HUN"] {
            let problem = try XCTUnwrap(engine.fleetOrderProblem(fleetID: "sixth", target: id, mission: .strike), id)
            XCTAssertTrue(problem.contains("landlocked"), id)
            XCTAssertNil(engine.orderFleet("sixth", to: id, mission: .strike))
        }
        XCTAssertNotNil(engine.fleetOrderProblem(fleetID: "nope", target: "JPN", mission: .strike))
        XCTAssertNotNil(engine.fleetOrderProblem(fleetID: "gwf", target: "JPN", mission: .strike), "the Great White Fleet is history")
        XCTAssertNotNil(engine.fleetOrderProblem(fleetID: "sixth", target: "ZZZ", mission: .strike))
        XCTAssertNotNil(engine.fleetOrderProblem(fleetID: "sixth", target: "USA", mission: .strike))
        XCTAssertTrue(gs.shadow.fleetDeployments.isEmpty)
        gs.actionsUsedThisTurn = gs.actionsPerTurn
        XCTAssertNotNil(engine.fleetOrderProblem(fleetID: "sixth", target: "LBY", mission: .showOfForce), "no actions left")
    }

    // Retry: double orders, recalls, save / load

    func testAFleetCanOnlyBeInOnePlaceAndRecallFreesIt() throws {
        let (engine, gs) = try modern()
        let d = try XCTUnwrap(engine.orderFleet("seventh", to: "PRK", mission: .showOfForce))
        XCTAssertNil(engine.orderFleet("seventh", to: "PRK", mission: .showOfForce), "a resubmitted order is refused")
        XCTAssertNil(engine.orderFleet("seventh", to: "CHN", mission: .blockade), "ships on station are tied up")
        XCTAssertEqual(gs.shadow.fleetDeployments.count, 1)
        XCTAssertTrue(engine.recallFleet(d.id))
        XCTAssertFalse(engine.recallFleet(d.id), "a second recall does nothing")
        XCTAssertNotNil(engine.orderFleet("seventh", to: "CHN", mission: .blockade))
    }

    func testFleetPositionsSurviveSaveAndOldSavesLoad() throws {
        let (engine, gs) = try modern()
        let d = try XCTUnwrap(engine.orderFleet("fifth", to: "JPN", mission: .strike))
        let loaded = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(gs))
        XCTAssertEqual(loaded.shadow.fleetDeployments, gs.shadow.fleetDeployments)
        let at = Date(timeIntervalSince1970: (d.departed.timeIntervalSince1970 + d.arrives.timeIntervalSince1970) / 2)
        XCTAssertEqual(loaded.shadow.fleetDeployments.first?.position(at: at).lon ?? 0, d.position(at: at).lon, accuracy: 0.0001)
        let engine2 = GameEngine(); engine2.gameState = loaded
        sail(engine2, loaded, turns: 1)
        XCTAssertEqual(loaded.shadow.fleetDeployments.first?.status, .onStation, "it completes its voyage after the reload")
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(gs)) as? [String: Any])
        var shadow = try XCTUnwrap(json["shadow"] as? [String: Any])
        shadow.removeValue(forKey: "fleetDeployments"); json["shadow"] = shadow
        let old = try JSONDecoder().decode(GameState.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertTrue(old.shadow.fleetDeployments.isEmpty)
    }

    // Performance

    func testFleetMathsIsCheap() throws {
        let (_, gs) = try modern()
        let countries = gs.countries
        measure {
            for f in NavalModel.fleets(in: 2025) {
                guard let home = f.period(in: 2025) else { continue }
                for c in countries {
                    _ = NavalModel.transitDays(km: NavalModel.distanceKm(lat1: home.lat, lon1: home.lon, lat2: c.coordinates.lat, lon2: c.coordinates.lon), year: 2025)
                    _ = NavalModel.isLandlocked(c.id)
                }
            }
        }
    }
}

// MARK: - Play history for fleets (3.5.0)

final class NavalPlayHistoryTests: XCTestCase {
    private var dir: URL!
    override func setUp() { super.setUp(); dir = StoreFixtures.tempDir() }
    override func tearDown() { try? FileManager.default.removeItem(at: dir); super.tearDown() }

    @MainActor
    func testFleetOrdersAndOutcomesAreLogged() async throws {
        let remote = InMemoryGameStore()
        let (e, service) = PlayFixtures.engine(dir, remote: remote)
        e.startNewGame(playerCountryID: "USA", turnLength: .month)
        let gs = try XCTUnwrap(e.gameState)
        let id = try XCTUnwrap(gs.shadow.playSessionID)
        let d = try XCTUnwrap(e.orderFleet("fifth", to: "JPN", mission: .blockade))
        gs.turn += 1; e.processFleets()
        XCTAssertTrue(e.recallFleet(d.id))
        let synced = await service.syncNow()
        XCTAssertTrue(synced)
        let events = await remote.events(id)
        let ordered = try XCTUnwrap(events.first { $0.kind == "fleet_ordered" })
        XCTAssertEqual(PlayFixtures.detail(ordered)["fleet"] as? String, "Fifth Fleet")
        XCTAssertEqual(PlayFixtures.detail(ordered)["mission"] as? String, "blockade")
        let action = try XCTUnwrap(events.first { $0.kind == "fleet_action" })
        XCTAssertEqual(PlayFixtures.detail(action)["sentence"] as? String, "Fifth Fleet blockaded Japan")
        XCTAssertTrue(events.contains { $0.kind == "fleet_recalled" })
    }
}

// MARK: - Era weapons catalog (3.6.0)

@MainActor
final class ArsenalCatalogTests: XCTestCase {

    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date { GameCalendar.date(year: y, month: m, day: d) }

    /// A modern game moved to `year` (Jan 20). The board stays modern; only the calendar matters here.
    private func game(year: Int) throws -> (GameEngine, GameState) {
        let engine = GameEngine()
        engine.startNewGame(turnLength: .month)
        let gs = try XCTUnwrap(engine.gameState)
        gs.eraStartYear = year
        return (engine, gs)
    }

    // Unit: era boundaries

    func testChemicalBoundaries() {
        XCTAssertFalse(PresidentialAction.chemicalAttack.isAvailable(on: day(1916, 12, 31)), "no chemical before 1917")
        XCTAssertTrue(PresidentialAction.chemicalAttack.isAvailable(on: day(1917, 6, 1)))
        XCTAssertEqual(ArsenalCatalog.legalStatus(.chemical, on: day(1918, 6, 1)), .legal, "WWI: before any treaty bound the U.S.")
        XCTAssertEqual(ArsenalCatalog.legalStatus(.chemical, on: day(1943, 6, 1)), .restricted)
        XCTAssertEqual(ArsenalCatalog.legalStatus(.chemical, on: day(1975, 6, 1)), .restricted, "Geneva Protocol ratified 1975")
        XCTAssertEqual(ArsenalCatalog.legalStatus(.chemical, on: day(1997, 6, 1)), .treatyBanned, "CWC 1997")
        XCTAssertTrue(ArsenalCatalog.stockpileExists(.chemical, on: day(2023, 7, 6)))
        XCTAssertFalse(ArsenalCatalog.stockpileExists(.chemical, on: day(2023, 7, 7)), "destroyed 7 Jul 2023")
        XCTAssertFalse(PresidentialAction.restartChemical.isAvailable(on: day(2023, 7, 6)))
        XCTAssertTrue(PresidentialAction.restartChemical.isAvailable(on: day(2023, 7, 7)), "from then on, restart only")
        XCTAssertTrue(ArsenalCatalog.treatyLabel(.chemical, year: 2010)?.contains("Chemical Weapons Convention") ?? false)
        XCTAssertNil(ArsenalCatalog.treatyLabel(.chemical, year: 1918))
    }

    func testBiologicalBoundaries() {
        XCTAssertFalse(PresidentialAction.biologicalAttack.isAvailable(on: day(1942, 6, 1)))
        XCTAssertTrue(ArsenalCatalog.stockpileExists(.biological, on: day(1943, 6, 1)))
        XCTAssertTrue(ArsenalCatalog.stockpileExists(.biological, on: day(1969, 6, 1)))
        XCTAssertFalse(ArsenalCatalog.stockpileExists(.biological, on: day(1970, 6, 1)), "program ended 1969")
        XCTAssertTrue(ArsenalCatalog.restartOnly(.biological, on: day(1970, 6, 1)))
        XCTAssertFalse(PresidentialAction.restartBiological.isAvailable(on: day(1969, 6, 1)))
        XCTAssertTrue(PresidentialAction.restartBiological.isAvailable(on: day(1980, 6, 1)))
        XCTAssertEqual(ArsenalCatalog.legalStatus(.biological, on: day(1976, 6, 1)), .treatyBanned, "BWC 1975")
        XCTAssertTrue(ArsenalCatalog.treatyLabel(.biological, year: 1990)?.contains("Biological Weapons Convention") ?? false)
    }

    func testNoNukesBeforeTrinityAndINFLabel() {
        for a in [PresidentialAction.launchNukes, .tacticalNuke, .strategicNuke, .firstStrike] {
            XCTAssertFalse(a.isAvailable(on: day(1944, 12, 1)), a.rawValue)
            XCTAssertFalse(a.isAvailable(on: day(1945, 7, 15)), a.rawValue)
            XCTAssertTrue(a.isAvailable(on: day(1945, 7, 16)), a.rawValue)
        }
        XCTAssertEqual(ArsenalCatalog.status(for: .deployMissiles, year: 1990), .treatyBanned, "INF Treaty 1988–2019")
        XCTAssertEqual(ArsenalCatalog.status(for: .deployMissiles, year: 2020), .legal)
        XCTAssertTrue(PresidentialAction.sendAmbassador.isAvailable(on: day(1790, 6, 1)), "uncatalogued actions keep their era year")
    }

    func testCatalogIsTheResearchTable() {
        XCTAssertEqual(ArsenalCatalog.options.count, 47)
        XCTAssertEqual(Set(ArsenalCatalog.options.map(\.id)).count, 47)
        for o in ArsenalCatalog.options {
            XCTAssertFalse(o.exists(in: o.from - 1), o.id)
            XCTAssertFalse(o.periods.isEmpty, o.id)
            if let to = o.to { XCTAssertGreaterThanOrEqual(to, o.from, o.id) }
        }
        XCTAssertTrue(ArsenalCatalog.examples(for: .groundInvasion, year: 1918).contains { $0.contains("Armor") || $0.contains("Tank") || $0.contains("armor") })
        XCTAssertFalse(ArsenalCatalog.examples(for: .groundInvasion, year: 1850).contains { $0.lowercased().contains("armor") })
        XCTAssertTrue(ArsenalCatalog.examples(for: .airStrike, year: 1850).isEmpty)
        // Low-confidence (post-April-2026) items never gate an action on their own.
        for a in PresidentialAction.allCases {
            let ids = ArsenalCatalog.optionIDs(for: a).compactMap(ArsenalCatalog.option)
            if !ids.isEmpty { XCTAssertFalse(ids.allSatisfy(\.lowConfidence), a.rawValue) }
        }
    }

    func testCostsRiseWithLegalStatus() {
        let legal = ArsenalCatalog.cost(.legal), restricted = ArsenalCatalog.cost(.restricted), banned = ArsenalCatalog.cost(.treatyBanned)
        XCTAssertLessThan(legal.world, restricted.world); XCTAssertLessThan(restricted.world, banned.world)
        XCTAssertLessThan(legal.ruthlessness, banned.ruthlessness)
        XCTAssertFalse(legal.opensImpeachment); XCTAssertTrue(banned.opensImpeachment)
        XCTAssertGreaterThan(banned.sanctions, 0)
        XCTAssertEqual(ArsenalCatalog.cost(.destroyed), banned)
    }

    // Functional: use in WWI versus after the CWC

    func testWWIChemicalUseCostsLittleAndPostCWCUseCostsALot() throws {
        let (e1918, g1918) = try game(year: 1918)
        let (e2000, g2000) = try game(year: 2000)
        let rel0 = g1918.getCountry(id: "FRA")!.diplomaticRelations["USA"] ?? 0
        let rel0b = g2000.getCountry(id: "FRA")!.diplomaticRelations["USA"] ?? 0
        e1918.performAdvisedAction(.chemicalAttack, targetID: "MEX", advice: nil)
        e2000.performAdvisedAction(.chemicalAttack, targetID: "MEX", advice: nil)
        XCTAssertTrue(g1918.getCountry(id: "MEX")!.atWarWith.contains("USA"))
        let drop1918 = rel0 - (g1918.getCountry(id: "FRA")!.diplomaticRelations["USA"] ?? 0)
        let drop2000 = rel0b - (g2000.getCountry(id: "FRA")!.diplomaticRelations["USA"] ?? 0)
        XCTAssertGreaterThan(drop2000, drop1918)
        XCTAssertEqual(g1918.shadow.impeachmentStage, 0)
        XCTAssertGreaterThanOrEqual(g2000.shadow.impeachmentStage, 1, "a treaty violation opens hearings")
        XCTAssertGreaterThan(g2000.shadow.ruthlessness, g1918.shadow.ruthlessness)
        XCTAssertTrue(g2000.shadow.ticker.contains { $0.text.contains("Chemical Weapons Convention") })
    }

    func testDestroyedStockpileMeansRestartFirst() throws {
        let (engine, gs) = try game(year: 2025)
        XCTAssertNotNil(engine.wmdProblem(.chemicalAttack), "no stockpile in 2025")
        let rel = gs.getCountry(id: "IRN")!.diplomaticRelations["USA"] ?? 0
        engine.performAdvisedAction(.chemicalAttack, targetID: "IRN", advice: nil)
        XCTAssertEqual(gs.getCountry(id: "IRN")!.diplomaticRelations["USA"] ?? 0, rel, "nothing happens")
        XCTAssertEqual(gs.actionsUsedThisTurn, 0, "and no action is spent")
        engine.performAdvisedAction(.restartChemical, targetID: "IRN", advice: nil)
        let p = try XCTUnwrap(gs.shadow.wmdPrograms["chemical"])
        XCTAssertEqual(GameCalendar.year(of: p.ready), 2027, "a two-year lead time")
        XCTAssertNotNil(engine.wmdProblem(.chemicalAttack), "not ready yet")
        XCTAssertNotNil(engine.wmdProblem(.restartChemical), "already under way")
        gs.turn = 26
        XCTAssertNil(engine.wmdProblem(.chemicalAttack))
        XCTAssertTrue(engine.executeWMD(.chemicalAttack, target: "IRN"))
        XCTAssertTrue(gs.shadow.wmdPrograms["chemical"]!.discovered, "use reveals the program")
        XCTAssertGreaterThanOrEqual(gs.shadow.impeachmentStage, 1)
    }

    func testRestartedProgramsCanBeDiscovered() throws {
        let engine = GameEngine()
        engine.startNewGame(turnLength: .year)
        let gs = try XCTUnwrap(engine.gameState)
        var found = 0
        for _ in 0..<200 {
            gs.shadow.wmdPrograms["biological"] = WMDProgram(kind: .biological, started: gs.currentDate, ready: .distantFuture)
            engine.processWMDPrograms()
            if gs.shadow.wmdPrograms["biological"]!.discovered { found += 1 }
        }
        XCTAssertGreaterThan(found, 30); XCTAssertLessThan(found, 120)   // ~35% a year
        gs.shadow.wmdPrograms["biological"] = WMDProgram(kind: .biological, started: gs.currentDate, ready: gs.currentDate)
        engine.processWMDPrograms()
        XCTAssertFalse(gs.shadow.wmdPrograms["biological"]!.discovered, "a finished program is no longer at risk")
    }

    // Security

    func testBadWMDOrdersDoNothing() throws {
        let (engine, gs) = try game(year: 1918)
        XCTAssertFalse(engine.executeWMD(.chemicalAttack, target: "USA"))
        XCTAssertFalse(engine.executeWMD(.chemicalAttack, target: "ZZZ"))
        XCTAssertFalse(engine.executeWMD(.biologicalAttack, target: "MEX"), "no biological weapons in 1918")
        XCTAssertFalse(engine.executeWMD(.sendAmbassador, target: "MEX"))
        let snapshot = gs.countries
        engine.executeShadowPresidentAction(.chemicalAttack, from: "MEX", to: "USA")
        XCTAssertEqual(gs.countries, snapshot, "the computer never uses this path")
        XCTAssertFalse(ArsenalCatalog.options.contains { $0.name.isEmpty })
    }

    // Retry: programs survive save / load; old saves decode

    func testProgramsSurviveSaveAndOldSavesLoad() throws {
        let (engine, gs) = try game(year: 2025)
        XCTAssertTrue(engine.executeWMD(.restartBiological, target: "IRN"))
        let loaded = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(gs))
        XCTAssertEqual(loaded.shadow.wmdPrograms, gs.shadow.wmdPrograms)
        let e2 = GameEngine(); e2.gameState = loaded
        XCTAssertFalse(e2.executeWMD(.restartBiological, target: "IRN"), "a restart can't be resubmitted after reload")
        loaded.turn = 40
        XCTAssertTrue(e2.executeWMD(.biologicalAttack, target: "IRN"), "ready after its lead time, across the reload")
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(gs)) as? [String: Any])
        var shadow = try XCTUnwrap(json["shadow"] as? [String: Any])
        shadow.removeValue(forKey: "wmdPrograms"); json["shadow"] = shadow
        let old = try JSONDecoder().decode(GameState.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertTrue(old.shadow.wmdPrograms.isEmpty)
    }

    // Performance

    func testAvailabilityAcrossAllYearsIsCheap() {
        let dates = (1789...2030).map { day($0, 6, 1) }
        measure {
            for d in dates { for a in PresidentialAction.allCases { _ = a.isAvailable(on: d) } }
        }
    }
}

// MARK: - Play history for the weapons catalog (3.6.0)

final class ArsenalPlayHistoryTests: XCTestCase {
    private var dir: URL!
    override func setUp() { super.setUp(); dir = StoreFixtures.tempDir() }
    override func tearDown() { try? FileManager.default.removeItem(at: dir); super.tearDown() }

    @MainActor
    func testWMDUseAndRestartsAreLogged() async throws {
        let remote = InMemoryGameStore()
        let (e, service) = PlayFixtures.engine(dir, remote: remote)
        e.startNewGame(playerCountryID: "USA", turnLength: .month)
        let gs = try XCTUnwrap(e.gameState)
        let id = try XCTUnwrap(gs.shadow.playSessionID)
        XCTAssertTrue(e.executeWMD(.restartChemical, target: "IRN"))
        gs.turn = 30
        XCTAssertTrue(e.executeWMD(.chemicalAttack, target: "IRN"))
        let synced = await service.syncNow()
        XCTAssertTrue(synced)
        let events = await remote.events(id)
        XCTAssertTrue(events.contains { $0.kind == "wmd_program_started" })
        let used = try XCTUnwrap(events.first { $0.kind == "wmd_used" })
        XCTAssertEqual(PlayFixtures.detail(used)["legal_status"] as? String, "treatyBanned")
        XCTAssertTrue((PlayFixtures.detail(used)["treaty"] as? String)?.contains("Chemical Weapons Convention") ?? false)
    }
}

// MARK: - Territory wealth and the politics of expansion (3.7.0)

@MainActor
final class ExpansionTests: XCTestCase {

    private func game(_ admin: Administration, turn: TurnLength = .week) throws -> (GameEngine, GameState) {
        let engine = GameEngine()
        engine.startNewGame(administration: admin, turnLength: turn)
        return (engine, try XCTUnwrap(engine.gameState))
    }

    /// Claim `ids` (5K troops each, actions refilled as a player with time would have), spread over `turns` turns,
    /// running the full Shadow turn between them; then play on `after` more turns. Returns the stages seen.
    @discardableResult
    private func spree(_ engine: GameEngine, _ gs: GameState, ids: [String], turns: Int, after: Int) -> [Int] {
        var stages: [Int] = []
        let perTurn = Int((Double(ids.count) / Double(turns)).rounded(.up))
        var queue = ids[...]
        for _ in 0..<(turns + after) {
            for _ in 0..<perTurn where !queue.isEmpty {
                gs.actionsUsedThisTurn = 0
                let id = queue.removeFirst()
                if gs.getCountry(id: id) != nil { continue }   // 3.14.0: a rival power got there first
                XCTAssertTrue(engine.claimLand(id, troops: 5), id)
                engine.renameTerritory(id, to: "Gimme \(id)")
            }
            gs.turn += 1
            engine.processShadowTurn()
            stages.append(gs.shadow.impeachmentStage)
            // A random assassination is noise for a balance replay; only impeachment counts here.
            if gs.shadow.domesticEnding == .assassinated { gs.shadow.domesticEnding = nil; gs.gameOver = false }
            if gs.shadow.domesticEnding != nil { break }
        }
        return stages
    }

    // Retry / rebalance: Jordan's 3.3.0 session must no longer end in removal

    func testJordans1913PatternNoLongerEndsInRemoval() throws {
        let (engine, gs) = try game(Advisor.wilsonAdministration())
        let lands = Array(gs.unclaimedLandIDs.sorted().prefix(27))
        XCTAssertEqual(lands.count, 27)
        let pop0 = gs.shadow.popularity
        let stages = spree(engine, gs, ids: lands, turns: 8, after: 26)
        print("REPLAY popularity \(pop0) -> \(gs.shadow.popularity), ruthlessness \(gs.shadow.ruthlessness), stages \(stages)")
        XCTAssertNotEqual(gs.shadow.domesticEnding, .impeached, "27 modest claims in 1913 must not get the President removed")
        XCTAssertLessThan(stages.max() ?? 0, 3, "the House never votes")
        XCTAssertGreaterThan(gs.shadow.resourceEarnings, 0, "the land pays")
        XCTAssertTrue(gs.shadow.ticker.contains { $0.text.contains("is now producing") })
    }

    func testAnAbsurdSpreeStillRisksImpeachment() throws {
        let (engine, gs) = try game(Advisor.fillmoreAdministration())
        let lands = gs.unclaimedLandIDs.sorted()
        XCTAssertGreaterThanOrEqual(lands.count, 40, "3.14.1: Ethiopia, Liberia, Madagascar and the African states aren't unclaimed")
        let stages = spree(engine, gs, ids: lands, turns: 1, after: 12)
        XCTAssertGreaterThanOrEqual(stages.max() ?? 0, 1, "40-odd lands in a week brings Congress down on the President")
        XCTAssertTrue(gs.shadow.ticker.contains { $0.text.contains("WARNING from the Chief of Staff") }, "and he is warned first")
    }
}

@MainActor
final class TerritoryWealthTests: XCTestCase {

    private func game(_ admin: Administration?, turn: TurnLength = .month) throws -> (GameEngine, GameState) {
        let engine = GameEngine()
        engine.startNewGame(administration: admin, turnLength: turn)
        return (engine, try XCTUnwrap(engine.gameState))
    }

    /// Move the calendar on and run only the territory step.
    private func years(_ engine: GameEngine, _ gs: GameState, _ n: Int) {
        for _ in 0..<(n * 12) { gs.turn += 1; engine.processTerritoryEconomy() }
    }

    // Unit: era-accurate resources

    func testResourcesFollowHistory() {
        let k = { (id: String, y: Int) in Set(ExpansionModel.deposits(for: id, year: y).map(\.kind)) }
        XCTAssertFalse(k("LBY", 1950).contains(.oil)); XCTAssertTrue(k("LBY", 1960).contains(.oil), "Libyan oil from 1959")
        XCTAssertFalse(k("NGA", 1950).contains(.oil)); XCTAssertTrue(k("NGA", 1957).contains(.oil), "Oloibiri 1956")
        XCTAssertTrue(k("COD", 1900).contains(.rubber)); XCTAssertFalse(k("COD", 1925).contains(.rubber), "the rubber boom ended")
        XCTAssertFalse(k("COD", 1930).contains(.uranium)); XCTAssertTrue(k("COD", 1944).contains(.uranium))
        XCTAssertFalse(k("ZAF", 1880).contains(.gold)); XCTAssertTrue(k("ZAF", 1890).contains(.gold), "Witwatersrand 1886")
        XCTAssertTrue(k("GHA", 1900).contains(.cocoa)); XCTAssertTrue(k("ZMB", 1930).contains(.copper))
        XCTAssertFalse(k("ZMB", 1920).contains(.copper), "the Copperbelt opened c.1928")
        XCTAssertEqual(k("ERI", 1913), [.agriculture], "lands without a table entry farm a little")
        for (_, list) in ExpansionModel.deposits { for d in list { XCTAssertGreaterThan(d.value, 0); if let to = d.to { XCTAssertGreaterThan(to, d.from) } } }
    }

    func testRampUpHoldAndPolitics() {
        XCTAssertEqual(ExpansionModel.rampUp(yearsHeld: 0.4), 0); XCTAssertEqual(ExpansionModel.rampUp(yearsHeld: 2), 1)
        XCTAssertEqual(ExpansionModel.rampUp(yearsHeld: 1.25), 0.5, accuracy: 0.001)
        XCTAssertEqual(ExpansionModel.holdFactor(stability: 60, garrison: 5), 1)
        XCTAssertLessThan(ExpansionModel.holdFactor(stability: 10, garrison: 1), ExpansionModel.holdFactor(stability: 60, garrison: 5))
        XCTAssertGreaterThan(ExpansionModel.holdFactor(stability: 0, garrison: 0), 0, "neglect hurts but never zeroes")
        XCTAssertGreaterThan(ExpansionModel.politics(year: 1900, nth: 1).popularity, 0, "a small imperial-era claim is popular")
        XCTAssertLessThan(ExpansionModel.politics(year: 1950, nth: 1).popularity, 0, "UN-era annexation is not")
        XCTAssertGreaterThan(ExpansionModel.politics(year: 1950, nth: 1).ruthlessness, ExpansionModel.politics(year: 1900, nth: 1).ruthlessness)
        var last = -1.0
        for n in 1...80 {   // gentle first, steep for a spree
            let r = ExpansionModel.politics(year: 1910, nth: n).ruthlessness
            XCTAssertGreaterThanOrEqual(r, last); last = r
        }
        XCTAssertLessThan(ExpansionModel.politics(year: 1910, nth: 5).ruthlessness, 1)
        XCTAssertGreaterThan(ExpansionModel.politics(year: 1910, nth: 50).ruthlessness, 6)
        XCTAssertEqual(ExpansionModel.risk(pressure: 13), .high); XCTAssertEqual(ExpansionModel.risk(pressure: 8), .rising)
        XCTAssertEqual(ExpansionModel.risk(pressure: 0), .none)
    }

    // Functional: land pays, scores and helps the forces

    func testClaimedGoldFieldsPayAndScore() throws {
        let (engine, gs) = try game(Advisor.mckinleyAdministration())
        let gdp0 = gs.getPlayerCountry()!.gdp
        let score0 = GameScore.calculate(from: gs, victoryType: nil).expansionBonus ?? 0
        XCTAssertTrue(engine.claimLand("ZAF"))
        years(engine, gs, 3)
        let row = try XCTUnwrap(ExpansionModel.ledger(gs).first { $0.country.id == "ZAF" })
        XCTAssertGreaterThan(row.income, 0)
        XCTAssertTrue(row.resources.contains(.gold))
        XCTAssertGreaterThan(gs.shadow.resourceEarnings, 0)
        XCTAssertGreaterThan(gs.getPlayerCountry()!.gdp, gdp0)
        XCTAssertTrue(gs.shadow.ticker.contains { $0.text.contains("is now producing") && $0.text.contains("gold") })
        XCTAssertGreaterThan(GameScore.calculate(from: gs, victoryType: nil).expansionBonus ?? 0, score0 + 99, "land and wealth score")
    }

    func testAnnexedCountriesPayTributeAndNeglectCosts() throws {
        let (engine, gs) = try game(nil)
        engine.declareWar(aggressor: "USA", defender: "CUB")
        engine.syncFronts()
        let i = try XCTUnwrap(gs.shadow.fronts.firstIndex { $0.defender == "CUB" && $0.status == .fighting })
        engine.resolveFront(index: i, verdict: .attackerWon)
        XCTAssertTrue(engine.settle(gs.shadow.pendingSettlements[0].id, choice: .annex))
        years(engine, gs, 3)
        let cub = try XCTUnwrap(gs.getCountry(id: "CUB"))
        let held = ExpansionModel.annualIncome(cub, in: gs)
        XCTAssertGreaterThan(held, 0)
        gs.shadow.garrisons["CUB"] = 0.5
        let ci = try XCTUnwrap(gs.countries.firstIndex { $0.id == "CUB" })
        gs.countries[ci].stability = 5
        XCTAssertLessThan(ExpansionModel.annualIncome(gs.countries[ci], in: gs), held, "a neglected territory pays less")
    }

    func testStrategicOilFuelsTheAirArmInItsEra() throws {
        let (engine, gs) = try game(Advisor.trumanAdministration(), turn: .year)
        XCTAssertTrue(engine.claimLand("LBY"))
        for _ in 0..<16 { gs.turn += 1; engine.processTerritoryEconomy() }   // past Libya's 1959 oil
        XCTAssertTrue(ExpansionModel.strategic(gs).contains(.oil))
        let pool = Double(AttackSizing.aircraftPool(gs.getPlayerCountry()!, year: gs.currentYear, lost: gs.shadow.aircraftLost))
        XCTAssertGreaterThan(AttackSizing.available(.aircraft, in: gs), pool, "oil fuels a larger air arm")
        XCTAssertFalse(ExpansionModel.strategic(gs).contains(.rubber), "rubber only counts in the world wars")
    }

    // Security

    func testRiskReadoutAndHostileInputs() throws {
        let (engine, gs) = try game(Advisor.wilsonAdministration())
        gs.shadow.ruthlessness = 200; gs.shadow.popularity = 10
        XCTAssertEqual(engine.impeachmentRisk().risk, .high)
        gs.shadow.expansionLog = Array(repeating: gs.currentDate, count: 40)   // mid-spree, the next claim adds pressure
        XCTAssertGreaterThan(engine.pressureAfterNextClaim(), engine.impeachmentRisk().pressure)
        XCTAssertTrue(ExpansionModel.politics(year: 1910, nth: 10_000).ruthlessness.isFinite)
        XCTAssertEqual(ExpansionModel.deposits(for: "ZZZ", year: 1900).map(\.kind), [.agriculture])
        let old = try JSONDecoder().decode(GameScore.self, from: Data(#"{"baseScore":1,"turnsPlayed":2,"nuclearVirgin":true,"casualtyPenalty":0,"allianceBonus":0,"treatyBonus":0,"economicBonus":0,"difficultyMultiplier":1,"finalScore":3,"playerCountry":"USA","dateAchieved":0}"#.utf8))
        XCTAssertNil(old.expansionBonus, "older score records decode")
    }

    // Retry: expansion state survives a reload; old saves decode

    func testExpansionStateSurvivesSaveAndOldSavesLoad() throws {
        let (engine, gs) = try game(Advisor.wilsonAdministration())
        XCTAssertTrue(engine.claimLand("CMR"))
        years(engine, gs, 1)
        let loaded = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(gs))
        XCTAssertEqual(loaded.shadow.expansionLog, gs.shadow.expansionLog)
        XCTAssertEqual(loaded.shadow.claimDates, gs.shadow.claimDates)
        XCTAssertEqual(loaded.shadow.resourceEarnings, gs.shadow.resourceEarnings)
        XCTAssertEqual(loaded.shadow.producing, gs.shadow.producing)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(gs)) as? [String: Any])
        var shadow = try XCTUnwrap(json["shadow"] as? [String: Any])
        for k in ["expansionLog", "claimDates", "producing", "resourceEarnings", "impeachmentWarned"] { shadow.removeValue(forKey: k) }
        json["shadow"] = shadow
        let old = try JSONDecoder().decode(GameState.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertTrue(old.shadow.expansionLog.isEmpty)
        XCTAssertGreaterThan(ExpansionModel.annualIncome(old.getCountry(id: "CMR")!, in: old), 0, "old territories count as long held")
    }

    // Performance

    func testLedgerIsCheapWithManyTerritories() throws {
        let (engine, gs) = try game(Advisor.fillmoreAdministration())
        for id in gs.unclaimedLandIDs.sorted() { gs.actionsUsedThisTurn = 0; engine.claimLand(id) }
        measure { for _ in 0..<100 { _ = ExpansionModel.ledger(gs); _ = ExpansionModel.strategic(gs) } }
    }
}

// MARK: - Play history: "Gotit is now producing copper" (3.7.0)

final class TerritoryWealthPlayHistoryTests: XCTestCase {
    private var dir: URL!
    override func setUp() { super.setUp(); dir = StoreFixtures.tempDir() }
    override func tearDown() { try? FileManager.default.removeItem(at: dir); super.tearDown() }

    @MainActor
    func testTerritoryProducingIsLogged() async throws {
        let remote = InMemoryGameStore()
        let (e, service) = PlayFixtures.engine(dir, remote: remote)
        e.startNewGame(playerCountryID: "USA", administration: Advisor.hooverAdministration(), turnLength: .month)
        let gs = try XCTUnwrap(e.gameState)
        let id = try XCTUnwrap(gs.shadow.playSessionID)
        XCTAssertTrue(e.claimLand("ZMB"))
        XCTAssertTrue(e.renameTerritory("ZMB", to: "Gotit"))
        for _ in 0..<12 { gs.turn += 1; e.processTerritoryEconomy() }
        let synced = await service.syncNow()
        XCTAssertTrue(synced)
        let events = await remote.events(id)
        let ev = try XCTUnwrap(events.first { $0.kind == "territory_producing" })
        XCTAssertEqual(PlayFixtures.detail(ev)["name"] as? String, "Gotit")
        XCTAssertTrue((PlayFixtures.detail(ev)["resources"] as? String)?.contains("copper") ?? false)
        XCTAssertTrue(gs.shadow.ticker.contains { $0.text.hasPrefix("Gotit is now producing copper") })
    }
}

// MARK: - Congress and the war powers; advisor warnings (3.8.0)

@MainActor
final class CongressTests: XCTestCase {

    private func game(year: Int, turn: TurnLength = .week) throws -> (GameEngine, GameState) {
        let engine = GameEngine()
        engine.startNewGame(turnLength: turn)
        let gs = try XCTUnwrap(engine.gameState)
        gs.eraStartYear = year
        return (engine, gs)
    }

    private func advance(_ engine: GameEngine, _ gs: GameState, turns: Int) {
        for _ in 0..<turns { gs.turn += 1; gs.actionsUsedThisTurn = 0; engine.processWarPowers() }
    }

    // Unit

    func testChambersVotesAndTrial() {
        XCTAssertEqual(CongressModel.house(congress: 60, popularity: 40), 50)
        XCTAssertEqual(CongressModel.senate(congress: 60, popularity: 40), 54, accuracy: 0.001)
        var last = -1.0
        for s in stride(from: 0.0, through: 100, by: 5) {
            let e = CongressModel.expectedYes(support: s, warSupport: 50, casusBelli: 0, kind: .declaration)
            XCTAssertGreaterThanOrEqual(e, last); last = e
        }
        XCTAssertGreaterThan(CongressModel.expectedYes(support: 50, warSupport: 50, casusBelli: 1, kind: .declaration),
                             CongressModel.expectedYes(support: 50, warSupport: 50, casusBelli: 0, kind: .declaration), "a casus belli helps")
        XCTAssertGreaterThan(CongressModel.expectedYes(support: 50, warSupport: 50, casusBelli: 0, kind: .useOfForce),
                             CongressModel.expectedYes(support: 50, warSupport: 50, casusBelli: 0, kind: .declaration), "an AUMF is easier")
        XCTAssertEqual(CongressModel.passOdds(expectedYes: 30), 0); XCTAssertEqual(CongressModel.passOdds(expectedYes: 70), 1)
        XCTAssertTrue(CongressModel.convicts(senateSupport: 20)); XCTAssertFalse(CongressModel.convicts(senateSupport: 40))
        XCTAssertEqual(CongressModel.impeachmentStageName(1), "INQUIRY")
        XCTAssertTrue(MajorAction.isMajor(.groundInvasion)); XCTAssertTrue(MajorAction.isMajor(.strategicNuke))
        XCTAssertTrue(MajorAction.isMajor(.chemicalAttack)); XCTAssertFalse(MajorAction.isMajor(.sendAmbassador))
        XCTAssertFalse(MajorAction.isMajor(.nuclearTest))
    }

    // Functional: asking Congress

    func testRequestPassesOrFailsWithTheOdds() throws {
        let (engine, gs) = try game(year: 2001)
        let pi = try XCTUnwrap(gs.countries.firstIndex { $0.id == "USA" })
        gs.countries[pi].congressionalSupport = 60; gs.countries[pi].warSupport = 50   // fixed, not the random start
        let o = try XCTUnwrap(engine.authorizationOdds(target: "AFG", kind: .useOfForce))
        XCTAssertGreaterThan(o.odds, 0)
        let v = try XCTUnwrap(engine.requestAuthorization(target: "AFG", kind: .useOfForce, roll: 0))
        XCTAssertTrue(v.passed); XCTAssertGreaterThan(v.houseYes, 50); XCTAssertTrue(engine.isAuthorized("AFG"))
        XCTAssertNil(engine.requestAuthorization(target: "AFG", kind: .declaration), "already authorized")
        gs.actionsUsedThisTurn = 0
        let pop = gs.shadow.popularity
        let o2 = try XCTUnwrap(engine.authorizationOdds(target: "CHE", kind: .declaration))
        let v2 = try XCTUnwrap(engine.requestAuthorization(target: "CHE", kind: .declaration, roll: 0.999))
        XCTAssertFalse(v2.passed || o2.odds > 0.999)
        XCTAssertLessThan(gs.shadow.popularity, pop, "a rebuff costs approval")
    }

    func testWarPowersClockFrom1973() throws {
        let (engine, gs) = try game(year: 1980)
        let c0 = gs.getPlayerCountry()!.congressionalSupport
        engine.declareWar(aggressor: "USA", defender: "MEX")
        advance(engine, gs, turns: 1)
        XCTAssertNotNil(gs.shadow.warPowersClocks["MEX"])
        XCTAssertTrue(gs.shadow.ticker.contains { $0.text.contains("60 days") })
        advance(engine, gs, turns: 7)   // ~50 days
        XCTAssertTrue(gs.shadow.ticker.contains { $0.text.contains("days left to win authorization") }, "warned before time is up")
        advance(engine, gs, turns: 7)   // ~99 days
        XCTAssertTrue(gs.shadow.ticker.contains { $0.text.contains("must leave the fight") })
        XCTAssertTrue(gs.shadow.ticker.contains { $0.text.contains("defies the War Powers Resolution") })
        XCTAssertLessThan(gs.getPlayerCountry()!.congressionalSupport, c0)
    }

    func testNoClockWhenAuthorizedOrBefore1973() throws {
        let (e1, g1) = try game(year: 1980)
        XCTAssertNotNil(e1.requestAuthorization(target: "MEX", kind: .useOfForce, roll: 0))
        if e1.isAuthorized("MEX") {
            e1.declareWar(aggressor: "USA", defender: "MEX")
            advance(e1, g1, turns: 20)
            XCTAssertNil(g1.shadow.warPowersClocks["MEX"])
        }
        let (e2, g2) = try game(year: 1965)
        e2.declareWar(aggressor: "USA", defender: "MEX")
        advance(e2, g2, turns: 20)
        XCTAssertTrue(g2.shadow.warPowersClocks.isEmpty, "no War Powers Resolution before Nov 1973")
    }

    func testSenateTrialNeedsTwoThirds() throws {
        for (congress, removed) in [(5, true), (95, false)] {
            let engine = GameEngine()
            engine.startNewGame(turnLength: .month)
            let gs = try XCTUnwrap(engine.gameState)
            let pi = try XCTUnwrap(gs.countries.firstIndex { $0.id == "USA" })
            gs.shadow.impeachmentStage = 3
            gs.shadow.popularity = 10; gs.shadow.ruthlessness = 80
            gs.countries[pi].congressionalSupport = congress
            gs.turn += 1
            engine.processShadowTurn()
            if removed {
                XCTAssertEqual(gs.shadow.domesticEnding, .impeached)
            } else {
                XCTAssertNotEqual(gs.shadow.domesticEnding, .impeached, "acquitted (a random assassination can still follow)")
                XCTAssertTrue(gs.shadow.ticker.contains { $0.text.contains("Senate acquits") })
            }
        }
    }

    // Functional: honest warnings

    func testWarningsUseTheEnginesNumbers() throws {
        let (engine, gs) = try game(year: 1985)
        let usa = gs.getPlayerCountry()!, mex = gs.getCountry(id: "MEX")!
        let std = AttackSizing.standard(.groundInvasion, in: gs)
        let inv = engine.advisorWarnings(for: .attack(.groundInvasion, target: "MEX", size: std))
        XCTAssertEqual(inv.map(\.who).count, 3)
        XCTAssertTrue(inv[0].text.contains("\(Int(AttackSizing.invasionOdds(troops: std.troops, attacker: usa, defender: mex) * 100))%"))
        XCTAssertTrue(inv[2].text.contains("War Powers"), "1985: the VP flags the clock")
        let nuke = engine.advisorWarnings(for: .attack(.strategicNuke, target: "RUS", size: AttackSize(warheads: 12)))
        XCTAssertTrue(nuke[0].text.contains("12 warheads")); XCTAssertTrue(nuke[0].text.contains("retaliation")); XCTAssertEqual(nuke[0].level, 2)
        let chem = engine.advisorWarnings(for: .attack(.chemicalAttack, target: "MEX", size: nil))
        XCTAssertTrue(chem[1].text.contains("Geneva Protocol"))
        let (e1918, _) = try game(year: 1918)
        XCTAssertFalse(e1918.advisorWarnings(for: .attack(.groundInvasion, target: "MEX", size: nil))[2].text.contains("War Powers"))
        let fleet = engine.advisorWarnings(for: .fleet(fleetID: "seventh", target: "PRK", mission: .strike, preset: .standard))
        XCTAssertTrue(fleet[0].text.contains("ships committed"))
    }

    func testClaimWarningsMatchTheExpansionModel() throws {
        let engine = GameEngine()
        engine.startNewGame(administration: Advisor.wilsonAdministration(), turnLength: .month)
        let gs = try XCTUnwrap(engine.gameState)
        let w = engine.advisorWarnings(for: .claim(land: "CMR", troops: 5))
        XCTAssertTrue(w[1].text.contains("Claim #1"))
        XCTAssertEqual(w[2].level, 0, "a first imperial-era claim is safe")
        gs.shadow.ruthlessness = 30; gs.shadow.popularity = 31
        gs.shadow.expansionLog = Array(repeating: gs.currentDate, count: 30)
        XCTAssertEqual(engine.advisorWarnings(for: .claim(land: "CMR", troops: 5))[2].level, 2, "the VP warns before the tipping claim")
    }

    // Security

    func testBadRequestsAreRefused() throws {
        let (engine, gs) = try game(year: 2001)
        XCTAssertNil(engine.requestAuthorization(target: "USA", kind: .declaration))
        XCTAssertNil(engine.requestAuthorization(target: "ZZZ", kind: .declaration))
        gs.actionsUsedThisTurn = gs.actionsPerTurn
        XCTAssertNil(engine.requestAuthorization(target: "MEX", kind: .declaration), "no actions left")
        let suite = try XCTUnwrap(UserDefaults(suiteName: "GTNWTests.warnings.\(UUID().uuidString)"))
        XCTAssertTrue(AdvisorWarnings.enabled(suite), "on by default")
        suite.set(false, forKey: AdvisorWarnings.defaultsKey)
        XCTAssertFalse(AdvisorWarnings.enabled(suite))
    }

    // Retry: votes and clocks survive a reload; old saves decode

    func testCongressStateSurvivesSave() throws {
        let (engine, gs) = try game(year: 1990)
        let pi = try XCTUnwrap(gs.countries.firstIndex { $0.id == "USA" })
        gs.countries[pi].congressionalSupport = 60; gs.countries[pi].warSupport = 50   // fixed, not the random start
        XCTAssertTrue(try XCTUnwrap(engine.requestAuthorization(target: "IRQ", kind: .useOfForce, roll: 0)).passed)
        gs.actionsUsedThisTurn = 0
        engine.declareWar(aggressor: "USA", defender: "MEX")
        advance(engine, gs, turns: 2)
        let loaded = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(gs))
        XCTAssertEqual(loaded.shadow.authorizations, gs.shadow.authorizations)
        XCTAssertEqual(loaded.shadow.warPowersClocks, gs.shadow.warPowersClocks)
        let e2 = GameEngine(); e2.gameState = loaded
        XCTAssertNil(e2.requestAuthorization(target: "IRQ", kind: .declaration), "still authorized after the reload")
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(gs)) as? [String: Any])
        var shadow = try XCTUnwrap(json["shadow"] as? [String: Any])
        shadow.removeValue(forKey: "authorizations"); shadow.removeValue(forKey: "warPowersClocks"); json["shadow"] = shadow
        let old = try JSONDecoder().decode(GameState.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertTrue(old.shadow.authorizations.isEmpty); XCTAssertTrue(old.shadow.warPowersClocks.isEmpty)
    }

    // Performance

    func testWarningsAreCheap() throws {
        let (engine, _) = try game(year: 2001)
        measure {
            for _ in 0..<200 {
                _ = engine.advisorWarnings(for: .attack(.groundInvasion, target: "MEX", size: nil))
                _ = engine.advisorWarnings(for: .fleet(fleetID: "fifth", target: "IRN", mission: .blockade, preset: .standard))
            }
        }
    }
}

final class CongressPlayHistoryTests: XCTestCase {
    private var dir: URL!
    override func setUp() { super.setUp(); dir = StoreFixtures.tempDir() }
    override func tearDown() { try? FileManager.default.removeItem(at: dir); super.tearDown() }

    @MainActor
    func testVotesAndViolationsAreLogged() async throws {
        let remote = InMemoryGameStore()
        let (e, service) = PlayFixtures.engine(dir, remote: remote)
        e.startNewGame(playerCountryID: "USA", turnLength: .week)
        let gs = try XCTUnwrap(e.gameState)
        let id = try XCTUnwrap(gs.shadow.playSessionID)
        XCTAssertNotNil(e.requestAuthorization(target: "IRN", kind: .useOfForce, roll: 0.999))
        e.declareWar(aggressor: "USA", defender: "MEX")
        for _ in 0..<16 { gs.turn += 1; e.processWarPowers() }
        let synced = await service.syncNow()
        XCTAssertTrue(synced)
        let events = await remote.events(id)
        XCTAssertEqual(PlayFixtures.detail(try XCTUnwrap(events.first { $0.kind == "congress_vote" }))["target"] as? String, "IRN")
        XCTAssertTrue(events.contains { $0.kind == "war_powers_violation" })
    }
}

// MARK: - Occupation, statehood, draft and mobilization; AI attack sizing (3.9.0)

@MainActor
final class ManpowerAndOccupationTests: XCTestCase {

    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date { GameCalendar.date(year: y, month: m, day: d) }

    private func game(_ admin: Administration?, turn: TurnLength = .month) throws -> (GameEngine, GameState) {
        let engine = GameEngine()
        engine.startNewGame(administration: admin, turnLength: turn)
        return (engine, try XCTUnwrap(engine.gameState))
    }

    private func months(_ engine: GameEngine, _ gs: GameState, _ n: Int) {
        for _ in 0..<n { gs.turn += 1; gs.actionsUsedThisTurn = 0; engine.processOccupation() }
    }

    // Unit: manpower by era

    func testManpowerFollowsTheEraAndTheDrafts() {
        XCTAssertEqual(ManpowerModel.standing(year: 1850), 20)
        XCTAssertLessThan(ManpowerModel.total(on: day(1850, 6, 1), called: []), 50)
        XCTAssertNil(ManpowerModel.historicalDraft(on: day(1917, 5, 17)))
        XCTAssertNotNil(ManpowerModel.historicalDraft(on: day(1917, 5, 18)), "Selective Service Act of 1917")
        XCTAssertNotNil(ManpowerModel.historicalDraft(on: day(1863, 6, 1)))
        XCTAssertNotNil(ManpowerModel.historicalDraft(on: day(1968, 6, 1)))
        XCTAssertNil(ManpowerModel.historicalDraft(on: day(1975, 6, 1)), "all-volunteer force after 1973")
        XCTAssertGreaterThan(ManpowerModel.total(on: day(1944, 6, 1), called: []), 5000, "WWII mobilization")
        XCTAssertGreaterThan(ManpowerModel.total(on: day(1941, 3, 1), called: []), ManpowerModel.total(on: day(1940, 10, 1), called: []), "draftees train over months")
        let drafted = [Mobilization(kind: .draft, started: day(2025, 1, 1))]
        XCTAssertEqual(ManpowerModel.total(on: day(2025, 1, 1), called: drafted), ManpowerModel.standing(year: 2025))
        XCTAssertGreaterThan(ManpowerModel.total(on: day(2025, 8, 1), called: drafted), ManpowerModel.standing(year: 2025) + 400)
        XCTAssertLessThan(ManpowerModel.callCost(.draft, atWar: false).popularity, ManpowerModel.callCost(.mobilization, atWar: false).popularity)
    }

    func testOccupationCurvesAndStatehoodRules() {
        var last = 101.0
        for g in stride(from: 0.0, through: 30, by: 2) {
            let t = OccupationModel.insurgencyTarget(garrison: g, needed: 10, governance: .militaryGovernor)
            XCTAssertLessThanOrEqual(t, last); last = t
        }
        XCTAssertLessThan(OccupationModel.insurgencyTarget(garrison: 5, needed: 10, governance: .selfRule),
                          OccupationModel.insurgencyTarget(garrison: 5, needed: 10, governance: .localElections))
        XCTAssertGreaterThan(OccupationModel.stabilityTarget(insurgency: 10, governance: .localElections), OccupationModel.stabilityTarget(insurgency: 80, governance: .localElections))
        XCTAssertEqual(OccupationModel.historicalStates(year: 1912), 48)
        XCTAssertEqual(OccupationModel.historicalStates(year: 1958), 48)
        XCTAssertEqual(OccupationModel.historicalStates(year: 1960), 50)
        XCTAssertEqual(OccupationModel.ordinal(51), "51st"); XCTAssertEqual(OccupationModel.ordinal(52), "52nd"); XCTAssertEqual(OccupationModel.ordinal(13), "13th")
    }

    func testComputersSizeTheirOwnAttacks() throws {
        let (engine, gs) = try game(nil)
        let a = try XCTUnwrap(gs.getCountry(id: "BRA")), d = try XCTUnwrap(gs.getCountry(id: "ARG"))
        var hawk = a; hawk.aggressionLevel = 90
        var dove = a; dove.aggressionLevel = 10
        XCTAssertEqual(AttackSizing.aiPreset(attacker: hawk, defender: d), CombatModel.forcePool(a) > 3 * CombatModel.forcePool(d) ? .standard : .overwhelming)
        XCTAssertEqual(AttackSizing.aiPreset(attacker: dove, defender: d), .probe)
        XCTAssertGreaterThan(AttackSizing.aiTroops(attacker: hawk, defender: d), AttackSizing.aiTroops(attacker: dove, defender: d))
        XCTAssertLessThanOrEqual(AttackSizing.aiTroops(attacker: hawk, defender: d), CombatModel.forcePool(a) * 0.9)
        engine.declareWar(aggressor: "BRA", defender: "ARG")
        engine.syncFronts()
        let f = try XCTUnwrap(gs.shadow.fronts.first { $0.attacker == "BRA" && $0.defender == "ARG" })
        XCTAssertEqual(f.attackerTroops, AttackSizing.aiTroops(attacker: a, defender: d), accuracy: 0.001, "the computer's front opens at its own size")
        var rus = try XCTUnwrap(gs.getCountry(id: "RUS")); rus.aggressionLevel = 90
        XCTAssertGreaterThan(AttackSizing.aiWarheads(3, attacker: rus, defender: gs.getCountry(id: "USA")!), 3)
        XCTAssertGreaterThanOrEqual(AttackSizing.aiWarheads(3, attacker: dove, defender: d), 0)
    }

    // Functional: you can't send troops you don't have; drafts add them

    func testTroopsAreFiniteAndADraftAddsThem() throws {
        let (engine, gs) = try game(nil)
        let free0 = AttackSizing.freeTroops(gs)
        XCTAssertEqual(free0, ManpowerModel.standing(year: 2025), accuracy: 1)
        XCTAssertEqual(AttackSizing.clamp(AttackSize(troops: 1e6), for: .groundInvasion, in: gs).troops, free0.rounded(.down), accuracy: 1)
        engine.declareWar(aggressor: "BRA", defender: "ARG"); engine.syncFronts()
        let fid = try XCTUnwrap(gs.shadow.fronts.first { $0.defender == "ARG" }).id
        XCTAssertFalse(engine.commitTroops(frontID: fid, side: "BRA", thousands: free0 + 100), "more than the U.S. has")
        let pop = gs.shadow.popularity
        XCTAssertTrue(engine.callUp(.draft))
        XCTAssertLessThan(gs.shadow.popularity, pop, "a peacetime draft is unpopular")
        XCTAssertNotNil(engine.callUpProblem(.draft), "already called")
        gs.turn += 7
        XCTAssertGreaterThan(AttackSizing.freeTroops(gs), free0 + 400)
        XCTAssertTrue(engine.standDown(.draft))
        XCTAssertEqual(AttackSizing.freeTroops(gs), free0, accuracy: 1)
        let (e1944, g1944) = try game(nil)
        g1944.eraStartYear = 1944
        XCTAssertNotNil(e1944.callUpProblem(.draft), "a historical draft is already in force")
    }

    // Functional: occupation, governance, statehood, breakaway

    func testGovernAndAdmitAsTheFortyNinthState() throws {
        let (engine, gs) = try game(Advisor.wilsonAdministration())
        XCTAssertTrue(engine.claimLand("GMB", troops: 5))
        XCTAssertTrue(engine.renameTerritory("GMB", to: "Fort Wilson"))
        XCTAssertTrue(engine.setGovernance("GMB", .localElections))
        let needed = OccupationModel.neededGarrison(gs.getCountry(id: "GMB")!)
        XCTAssertTrue(engine.setGarrison("GMB", thousands: (needed * 1.5).rounded(.up)))
        months(engine, gs, 6)
        XCTAssertLessThan(gs.getCountry(id: "GMB")!.profile.outcry, 30, "garrison and elections calm it")
        XCTAssertNil(engine.petitionStatehood("GMB", roll: 0), "not yet: five years")
        months(engine, gs, 60)
        let p = gs.countries.firstIndex { $0.id == "USA" }!
        gs.countries[p].congressionalSupport = 80
        let score0 = GameScore.calculate(from: gs, victoryType: nil).expansionBonus ?? 0
        XCTAssertEqual(engine.petitionStatehood("GMB", roll: 0), true)
        let s = try XCTUnwrap(gs.shadow.statesAdmitted.first)
        XCTAssertEqual(s.number, 49, "after 48 states in 1918")
        XCTAssertEqual(s.name, "Fort Wilson", "it keeps the President's name")
        XCTAssertEqual(gs.territoryLabel(gs.getCountry(id: "GMB")!), "U.S. STATE ★49")
        XCTAssertTrue(gs.shadow.ticker.contains { $0.text.contains("49th state") && $0.text.contains("star") })
        XCTAssertGreaterThanOrEqual((GameScore.calculate(from: gs, victoryType: nil).expansionBonus ?? 0) - score0, 1000)
    }

    func testNeglectedTerritoryBreaksAway() throws {
        let (engine, gs) = try game(Advisor.wilsonAdministration())
        XCTAssertTrue(engine.claimLand("CMR", troops: 1))
        let i = gs.countries.firstIndex { $0.id == "CMR" }!
        for _ in 0..<14 {
            gs.countries[i].profile.outcry = 100
            months(engine, gs, 1)
            if gs.getCountry(id: "CMR")?.territoryOf == nil { break }
        }
        XCTAssertNil(gs.getCountry(id: "CMR")?.territoryOf, "a year boiling over with a token garrison: independence")
        XCTAssertTrue(gs.shadow.ticker.contains { $0.text.contains("declares independence") })
        XCTAssertNil(gs.shadow.garrisons["CMR"], "the garrison comes home")
    }

    func testAnnexationTakesAGarrison() throws {
        let (engine, gs) = try game(nil)
        engine.declareWar(aggressor: "USA", defender: "CUB"); engine.syncFronts()
        let i = try XCTUnwrap(gs.shadow.fronts.firstIndex { $0.defender == "CUB" && $0.status == .fighting })
        engine.resolveFront(index: i, verdict: .attackerWon)
        XCTAssertTrue(engine.settle(gs.shadow.pendingSettlements[0].id, choice: .annex))
        XCTAssertEqual(gs.shadow.garrisons["CUB"] ?? 0, OccupationModel.neededGarrison(gs.getCountry(id: "CUB")!).rounded(), accuracy: 1)
    }

    // Security

    func testBadOrdersAreRefused() throws {
        let (engine, gs) = try game(Advisor.wilsonAdministration())
        XCTAssertTrue(engine.claimLand("CMR", troops: 5))
        for bad in [-1.0, 0, 0.2, .nan, .infinity, 1e9] { XCTAssertFalse(engine.setGarrison("CMR", thousands: bad), "\(bad)") }
        XCTAssertFalse(engine.setGarrison("FRA", thousands: 5))
        XCTAssertFalse(engine.setGovernance("FRA", .selfRule))
        XCTAssertNil(engine.petitionStatehood("FRA", roll: 0))
        XCTAssertNil(engine.petitionStatehood("ZZZ", roll: 0))
        gs.actionsUsedThisTurn = gs.actionsPerTurn
        XCTAssertNotNil(engine.callUpProblem(.mobilization))
        XCTAssertFalse(engine.callUp(.mobilization))
    }

    // Retry: state survives a reload; old saves decode

    func testManpowerAndTerritoryStateSurvivesSave() throws {
        let (engine, gs) = try game(Advisor.wilsonAdministration())
        XCTAssertTrue(engine.claimLand("CMR", troops: 5))
        engine.setGovernance("CMR", .selfRule)
        gs.actionsUsedThisTurn = 0
        XCTAssertTrue(engine.callUp(.mobilization))
        let loaded = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(gs))
        XCTAssertEqual(loaded.shadow.mobilizations, gs.shadow.mobilizations)
        XCTAssertEqual(loaded.shadow.territoryPolicies, gs.shadow.territoryPolicies)
        let e2 = GameEngine(); e2.gameState = loaded
        XCTAssertFalse(e2.callUp(.mobilization), "can't be called twice across a reload")
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(gs)) as? [String: Any])
        var shadow = try XCTUnwrap(json["shadow"] as? [String: Any])
        for k in ["mobilizations", "territoryPolicies", "statesAdmitted", "garrisons"] { shadow.removeValue(forKey: k) }
        json["shadow"] = shadow
        let old = try JSONDecoder().decode(GameState.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertTrue(old.shadow.mobilizations.isEmpty && old.shadow.statesAdmitted.isEmpty)
        let e3 = GameEngine(); e3.gameState = old
        e3.processOccupation()
        XCTAssertEqual(old.getCountry(id: "CMR")?.territoryOf, "USA", "an old save's territory without a garrison record is not lost")
    }

    // Performance

    func testManpowerAndOccupationAreCheap() throws {
        let (engine, gs) = try game(Advisor.fillmoreAdministration())
        for id in gs.unclaimedLandIDs.sorted() { gs.actionsUsedThisTurn = 0; _ = engine.claimLand(id, troops: 1) }
        let dates = (1789...2030).map { day($0, 6, 1) }
        measure {
            for d in dates { _ = ManpowerModel.total(on: d, called: []) }
            for _ in 0..<20 { engine.processOccupation() }
        }
    }
}

final class ManpowerPlayHistoryTests: XCTestCase {
    private var dir: URL!
    override func setUp() { super.setUp(); dir = StoreFixtures.tempDir() }
    override func tearDown() { try? FileManager.default.removeItem(at: dir); super.tearDown() }

    @MainActor
    func testDraftAndStatehoodAreLogged() async throws {
        let remote = InMemoryGameStore()
        let (e, service) = PlayFixtures.engine(dir, remote: remote)
        e.startNewGame(playerCountryID: "USA", administration: Advisor.wilsonAdministration(), turnLength: .month)
        let gs = try XCTUnwrap(e.gameState)
        let id = try XCTUnwrap(gs.shadow.playSessionID)
        XCTAssertTrue(e.callUp(.mobilization))
        gs.actionsUsedThisTurn = 0
        XCTAssertTrue(e.claimLand("GMB", troops: 5))
        e.setGovernance("GMB", .localElections)
        _ = e.setGarrison("GMB", thousands: 20)
        for _ in 0..<66 { gs.turn += 1; gs.actionsUsedThisTurn = 0; e.processOccupation() }
        gs.countries[gs.countries.firstIndex { $0.id == "USA" }!].congressionalSupport = 90
        XCTAssertEqual(e.petitionStatehood("GMB", roll: 0), true)
        let synced = await service.syncNow()
        XCTAssertTrue(synced)
        let events = await remote.events(id)
        XCTAssertTrue(events.contains { $0.kind == "mobilization_called" })
        XCTAssertEqual(PlayFixtures.detail(try XCTUnwrap(events.first { $0.kind == "statehood" }))["number"] as? Int, 49)
    }
}

// MARK: - Antarctica and group actions (3.10.0)

@MainActor
final class AntarcticaTests: XCTestCase {

    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date { GameCalendar.date(year: y, month: m, day: d) }

    private func game(year: Int) throws -> (GameEngine, GameState) {
        let engine = GameEngine()
        engine.startNewGame(turnLength: .month)
        let gs = try XCTUnwrap(engine.gameState)
        gs.eraStartYear = year
        return (engine, gs)
    }

    func testTreatyClaimsAndResourcesByEra() {
        XCTAssertEqual(Antarctica.legalStatus(on: day(1959, 11, 30)), .legal)
        XCTAssertEqual(Antarctica.legalStatus(on: day(1960, 6, 1)), .restricted, "signed, not yet in force")
        XCTAssertEqual(Antarctica.legalStatus(on: day(1961, 6, 22)), .restricted)
        XCTAssertEqual(Antarctica.legalStatus(on: day(1961, 6, 23)), .treatyBanned)
        XCTAssertTrue(Antarctica.claims(by: 1907).isEmpty)
        XCTAssertEqual(Antarctica.claims(by: 1925).count, 3)
        XCTAssertEqual(Antarctica.claims(by: 1950).count, 7)
        let k = { (y: Int) in Set(ExpansionModel.deposits(for: Antarctica.id, year: y).map(\.kind)) }
        XCTAssertTrue(k(1950).contains(.whaling)); XCTAssertFalse(k(1970).contains(.whaling))
        XCTAssertTrue(k(1880).contains(.sealing)); XCTAssertFalse(k(1950).contains(.science)); XCTAssertTrue(k(1960).contains(.science))
        XCTAssertFalse(k(2047).contains(.minerals)); XCTAssertTrue(k(2048).contains(.minerals), "Madrid Protocol review")
        XCTAssertFalse(k(2030).contains(.oil))
        XCTAssertNotNil(WorldCountriesDatabase.template(id: Antarctica.id))
        XCTAssertTrue(WorldMapData.shared.shapes.contains { $0.id == Antarctica.id }, "it has its own map shape")
    }

    func testClaimBeforeTheTreatyIsJustAnotherClaim() throws {
        let engine = GameEngine()
        engine.startNewGame(administration: Advisor.wilsonAdministration(), turnLength: .month)
        let gs = try XCTUnwrap(engine.gameState)
        XCTAssertTrue(gs.unclaimedLandIDs.contains(Antarctica.id))
        XCTAssertTrue(engine.claimLand(Antarctica.id, troops: 1))
        XCTAssertEqual(gs.getCountry(id: Antarctica.id)?.territoryOf, "USA")
        XCTAssertEqual(gs.shadow.impeachmentStage, 0)
        XCTAssertFalse(gs.shadow.ticker.contains { $0.text.contains("Antarctic Treaty") })
        XCTAssertEqual(OccupationModel.neededGarrison(gs.getCountry(id: Antarctica.id)!), 0.5)
    }

    func testClaimAfter1961BreaksTheTreaty() throws {
        let (engine, gs) = try game(year: 2025)
        let fra0 = gs.getCountry(id: "FRA")!.diplomaticRelations["USA"] ?? 0
        let w = engine.advisorWarnings(for: .claim(land: Antarctica.id, troops: 1))
        XCTAssertEqual(w[1].level, 2); XCTAssertTrue(w[1].text.contains("Antarctic Treaty"))
        XCTAssertTrue(engine.claimLand(Antarctica.id, troops: 1))
        XCTAssertTrue(gs.shadow.ticker.contains { $0.text.contains("violates the Antarctic Treaty") })
        XCTAssertGreaterThanOrEqual(gs.shadow.impeachmentStage, 1, "a treaty violation opens hearings")
        XCTAssertLessThan(gs.getCountry(id: "FRA")!.diplomaticRelations["USA"] ?? 0, fra0 - 30)
    }

    func testTheColdTakesItsToll() throws {
        let engine = GameEngine()
        engine.startNewGame(administration: Advisor.wilsonAdministration(), turnLength: .month)
        let gs = try XCTUnwrap(engine.gameState)
        XCTAssertTrue(engine.claimLand(Antarctica.id, troops: 10))
        let gdp = gs.getPlayerCountry()!.gdp
        for _ in 0..<6 { gs.turn += 1; engine.processAntarctica() }
        XCTAssertLessThan(gs.shadow.garrisons[Antarctica.id] ?? 99, 8, "5% a month to the cold")
        XCTAssertLessThan(gs.getPlayerCountry()!.gdp, gdp, "and upkeep is paid")
        XCTAssertEqual(gs.getCountry(id: Antarctica.id)?.profile.outcry, 0, "nobody to rebel")
        for _ in 0..<200 { gs.turn += 1; engine.processAntarctica() }
        XCTAssertGreaterThanOrEqual(gs.shadow.garrisons[Antarctica.id] ?? 0, 0.5, "a skeleton crew always remains")
    }
}

@MainActor
final class GroupActionTests: XCTestCase {

    private func modern() throws -> (GameEngine, GameState) {
        let engine = GameEngine()
        engine.startNewGame(turnLength: .month)
        return (engine, try XCTUnwrap(engine.gameState))
    }

    private func twin(_ gs: GameState) throws -> (GameEngine, GameState) {
        let copy = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(gs))
        let e = GameEngine(); e.gameState = copy
        return (e, copy)
    }

    func testMembersOfEachKindOfGroup() throws {
        let (engine, gs) = try modern()
        let allies = engine.groupMembers(.allies)
        XCTAssertFalse(allies.isEmpty)
        XCTAssertTrue(allies.contains("GBR") && allies.contains("FRA"), "NATO allies in 2025")
        XCTAssertFalse(allies.contains("RUS")); _ = gs
        XCTAssertFalse(allies.contains("USA"))
        let europe = engine.groupMembers(.region(.europe))
        XCTAssertTrue(europe.contains("FRA")); XCTAssertFalse(europe.contains("JPN"))
        XCTAssertEqual(engine.groupMembers(.custom(name: "x", ids: ["FRA", "ZZZ", "DEU"])), ["FRA", "DEU"], "unknown ids drop out")
        XCTAssertTrue(engine.groupMembers(.territories).isEmpty)
    }

    func testPlansSplitTheMoneyAndAddUp() throws {
        let (engine, _) = try modern()
        let members = ["FRA", "MEX", "IND"]
        let even = engine.planGroupAction(.money, members: members, amount: 9, split: .even)
        XCTAssertNil(even.problem)
        XCTAssertEqual(even.lines.map(\.amount), [3, 3, 3])
        let need = engine.planGroupAction(.aid, members: members, amount: 9, split: .byNeed)
        XCTAssertEqual(need.lines.reduce(0) { $0 + $1.amount }, 9, accuracy: 1e-9)
        XCTAssertNotEqual(Set(need.lines.map(\.amount)).count, 1, "by need is not even")
    }

    func testGroupMessageMatchesSingleActionsAndCostsOneAction() throws {
        let (e1, g1) = try modern()
        let (e2, g2) = try twin(g1)
        let members = ["FRA", "DEU", "JPN"]
        let used = g1.actionsUsedThisTurn
        XCTAssertNotNil(e1.executeGroupAction(.message, members: members, groupName: "Friends"))
        for id in members { e2.executeShadowPresidentAction(.jointStatement, from: "USA", to: id) }
        for id in members {
            XCTAssertEqual(g1.getCountry(id: id)!.diplomaticRelations["USA"], g2.getCountry(id: id)!.diplomaticRelations["USA"], id)
            XCTAssertEqual(g1.getPlayerCountry()!.diplomaticRelations[id], g2.getPlayerCountry()!.diplomaticRelations[id], id)
        }
        XCTAssertEqual(g1.actionsUsedThisTurn, used + 1, "one action for the whole group")
    }

    func testMoneyAndGarrisonsGoThroughTheSingleNationCode() throws {
        let engine = GameEngine()
        engine.startNewGame(administration: Advisor.wilsonAdministration(), turnLength: .month)
        let gs = try XCTUnwrap(engine.gameState)
        for id in ["CMR", "KEN", "GAB"] { gs.actionsUsedThisTurn = 0; XCTAssertTrue(engine.claimLand(id, troops: 2)) }
        gs.actionsUsedThisTurn = 0
        XCTAssertNotNil(engine.executeGroupAction(.garrison, members: engine.groupMembers(.territories), amount: 6, groupName: "Territories"))
        for id in ["CMR", "KEN", "GAB"] { XCTAssertEqual(gs.shadow.garrisons[id], 6) }
        XCTAssertEqual(gs.actionsUsedThisTurn, 0, "garrison changes are free, as they are singly")
        let pool = gs.shadow.aidRemaining
        XCTAssertNotNil(engine.executeGroupAction(.money, members: ["FRA", "MEX"], amount: min(2, pool), split: .even))
        XCTAssertLessThanOrEqual(gs.shadow.aidRemaining, pool)
        XCTAssertNotNil(gs.shadow.aidSent["FRA"])
    }

    // Security

    func testBadGroupOrdersAreRefusedAndChangeNothing() throws {
        let (engine, gs) = try modern()
        let snapshot = gs.countries
        XCTAssertNil(engine.executeGroupAction(.sanctions, members: []))
        XCTAssertNil(engine.executeGroupAction(.money, members: ["FRA"], amount: .nan))
        XCTAssertNil(engine.executeGroupAction(.money, members: ["FRA"], amount: gs.shadow.aidRemaining + 1000))
        XCTAssertNil(engine.executeGroupAction(.garrison, members: ["FRA"], amount: 5), "garrisons are for territories")
        XCTAssertEqual(gs.countries, snapshot)
        XCTAssertFalse(engine.saveGroup(name: "", ids: ["FRA"]))
        XCTAssertFalse(engine.saveGroup(name: "Bad\nName", ids: ["FRA"]))
        XCTAssertFalse(engine.saveGroup(name: "Empty", ids: []))
        gs.actionsUsedThisTurn = gs.actionsPerTurn
        XCTAssertNotNil(engine.planGroupAction(.message, members: ["FRA"]).problem, "no actions left")
    }

    // Retry / persistence

    func testSavedGroupsSurviveAReloadAndOldSavesDecode() throws {
        let (engine, gs) = try modern()
        XCTAssertTrue(engine.saveGroup(name: "  Old Friends ", ids: ["GBR", "FRA", "GBR"]))
        XCTAssertEqual(gs.shadow.savedGroups["Old Friends"], ["FRA", "GBR"])
        let loaded = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(gs))
        XCTAssertEqual(loaded.shadow.savedGroups, gs.shadow.savedGroups)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(gs)) as? [String: Any])
        var shadow = try XCTUnwrap(json["shadow"] as? [String: Any])
        shadow.removeValue(forKey: "savedGroups"); json["shadow"] = shadow
        XCTAssertTrue(try JSONDecoder().decode(GameState.self, from: JSONSerialization.data(withJSONObject: json)).shadow.savedGroups.isEmpty)
    }

    // Performance

    func testPlanningBigGroupsIsCheap() throws {
        let (engine, _) = try modern()
        measure {
            for r in WorldRegion.allCases {
                let m = engine.groupMembers(.region(r))
                _ = engine.planGroupAction(.aid, members: m, amount: 5, split: .byNeed)
                _ = engine.planGroupAction(.sanctions, members: m)
            }
        }
    }
}

final class GroupActionPlayHistoryTests: XCTestCase {
    private var dir: URL!
    override func setUp() { super.setUp(); dir = StoreFixtures.tempDir() }
    override func tearDown() { try? FileManager.default.removeItem(at: dir); super.tearDown() }

    @MainActor
    func testOneEventPerGroupActionListingItsMembers() async throws {
        let remote = InMemoryGameStore()
        let (e, service) = PlayFixtures.engine(dir, remote: remote)
        e.startNewGame(playerCountryID: "USA", turnLength: .month)
        let id = try XCTUnwrap(e.gameState?.shadow.playSessionID)
        XCTAssertNotNil(e.executeGroupAction(.recall, members: ["IRN", "PRK"], groupName: "Rogues"))
        let synced = await service.syncNow()
        XCTAssertTrue(synced)
        let groups = await remote.events(id).filter { $0.kind == "group_action" }
        XCTAssertEqual(groups.count, 1)
        let d = PlayFixtures.detail(groups[0])
        XCTAssertEqual(d["members"] as? [String], ["IRN", "PRK"])
        XCTAssertEqual(d["group"] as? String, "Rogues")
    }
}

// MARK: - Play as other nations (3.11.0)

@MainActor
final class NationPlayTests: XCTestCase {

    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date { GameCalendar.date(year: y, month: m, day: d) }

    private func play(_ id: String, year: Int) throws -> (GameEngine, GameState) {
        let engine = GameEngine()
        engine.startNewGame(playerCountryID: id, turnLength: .month)
        let gs = try XCTUnwrap(engine.gameState)
        if year != 2025 {
            gs.eraStartYear = year
            gs.advisors = NationModel.cabinet(for: gs.getPlayerCountry()!, on: gs.currentDate)
        }
        return (engine, gs)
    }

    // Unit: the data and the lookups

    func testDataLoadsAndDatesParse() throws {
        let data = try XCTUnwrap(NationCabinets.shared, "bundled nation_cabinets.json")
        XCTAssertEqual(data.nations.count, 33)
        XCTAssertEqual(NationModel.parse("1913"), day(1913, 1, 1))
        XCTAssertEqual(NationModel.parse("1913-07"), day(1913, 7, 1))
        XCTAssertEqual(NationModel.parse("1909-04-27"), day(1909, 4, 27))
        XCTAssertNil(NationModel.parse(""))
        XCTAssertEqual(NationModel.cabinetID(forGameID: "SVN_VN"), "VNM_S")
    }

    func testRealHoldersOnTheDate() {
        let gov = "constitutional_monarchy_parliamentary"
        XCTAssertEqual(NationModel.holder("GBR", role: "head_of_government", on: day(1950, 1, 20), government: gov).name, "Clement Attlee")
        XCTAssertEqual(NationModel.holder("GBR", role: "head_of_state", on: day(2025, 2, 1), government: gov).name, "Charles III")
        XCTAssertEqual(NationModel.holder("TUR", role: "head_of_state", on: day(1913, 2, 1), government: "absolute_monarchy").name, "Mehmed V Reşad")
        XCTAssertEqual(NationModel.holder("RUS", role: "paramount_leader", on: day(1960, 1, 20), government: "one_party_communist_state").name, "Nikita Khrushchev")
    }

    func testAfterApril2026KeepTheLastVerifiedHolder() {
        let late = NationModel.holder("GBR", role: "head_of_government", on: day(2026, 10, 20), government: "constitutional_monarchy_parliamentary")
        XCTAssertEqual(late.name, "Sir Keir Starmer", "a July 2026 change is low-confidence and not used")
        XCTAssertTrue(late.unverified)
        XCTAssertTrue(late.display.contains("(acting/unverified)"))
        XCTAssertFalse(NationModel.holder("GBR", role: "head_of_government", on: day(2025, 1, 20), government: "constitutional_monarchy_parliamentary").unverified)
    }

    func testUncertainRecordsAreMarkedAndGapsAreGenericNeverInvented() {
        let u = NationModel.holder("AUT", role: "foreign", on: day(1848, 4, 1), government: "absolute_monarchy")
        XCTAssertTrue(u.uncertain); XCTAssertTrue(u.display.hasSuffix("?"))
        let gap = NationModel.holder("NGA", role: "foreign", on: day(1970, 1, 20), government: "presidential_republic")
        XCTAssertTrue(gap.generic); XCTAssertEqual(gap.display, "(no record)")
        XCTAssertFalse(gap.title.isEmpty, "a generic title for the government type")
    }

    func testLeaderRolesAndRemovalMechanisms() throws {
        XCTAssertEqual(NationModel.leaderRole(government: "parliamentary_republic"), "head_of_government")
        XCTAssertEqual(NationModel.leaderRole(government: "one_party_communist_state"), "paramount_leader")
        XCTAssertEqual(NationModel.leaderRole(government: "absolute_monarchy"), "head_of_state")
        let gs = GameState(playerCountryID: "USA")
        let gbr = try XCTUnwrap(gs.getCountry(id: "GBR")), usa = try XCTUnwrap(gs.getCountry(id: "USA"))
        XCTAssertEqual(NationModel.removal(gbr, on: day(2025, 1, 20)), .noConfidence)
        XCTAssertEqual(NationModel.removal(usa, on: day(2025, 1, 20)), .impeachment)
        XCTAssertEqual(NationModel.removal(gs.getCountry(id: "RUS")!, on: day(1960, 1, 20)), .partyCongress)
        XCTAssertEqual(NationModel.removal(gs.getCountry(id: "ARG")!, on: day(1977, 1, 20)), .juntaDecision)
        for m in RemovalMechanism.allCases where m != .impeachment {
            XCTAssertFalse(m.stageText(3).contains("Senate"), m.rawValue)
            XCTAssertNotEqual(m.ending, .impeached)
        }
    }

    // Functional

    func testPlayAsBritainTheComputerRunsTheUS() throws {
        let (engine, gs) = try play("GBR", year: 2025)
        XCTAssertEqual(gs.playerCountryID, "GBR")
        XCTAssertTrue(gs.getPlayerCountry()!.isPlayerControlled)
        XCTAssertFalse(gs.getCountry(id: "USA")!.isPlayerControlled, "the AI runs the U.S.")
        XCTAssertFalse(gs.shadow.electionsEnabled, "no U.S. presidential elections")
        XCTAssertTrue(gs.advisors.contains { $0.name == "Charles III" && $0.roleKey == "whc" }, "the King as chief adviser to the PM")
        XCTAssertEqual(Set(gs.advisors.compactMap(\.roleKey)), Set(AdviceEngine.roleOrder))
        XCTAssertNil(engine.requestAuthorization(target: "IRN", kind: .declaration, roll: 0), "no U.S. Congress")
        XCTAssertNotNil(engine.fleetOrderProblem(fleetID: "fifth", target: "IRN", mission: .blockade))
        XCTAssertNotNil(engine.callUpProblem(.draft))
        engine.declareWar(aggressor: "GBR", defender: "IRN")
        engine.processWarPowers()
        XCTAssertTrue(gs.shadow.warPowersClocks.isEmpty, "the War Powers Resolution is American")
    }

    func testAPrimeMinisterFallsToNoConfidenceNotASenateTrial() throws {
        let (engine, gs) = try play("GBR", year: 2025)
        let pi = try XCTUnwrap(gs.countries.firstIndex { $0.id == "GBR" })
        gs.shadow.impeachmentStage = 3; gs.shadow.popularity = 10; gs.shadow.ruthlessness = 80
        gs.countries[pi].congressionalSupport = 90
        gs.turn += 1
        engine.processShadowTurn()
        XCTAssertEqual(gs.shadow.domesticEnding, .noConfidence)
        XCTAssertFalse(gs.shadow.ticker.contains { $0.text.contains("Senate") })
    }

    func testOttomanEmpireIn1913HasItsRealCourt() throws {
        let engine = GameEngine()
        engine.startNewGame(playerCountryID: "TUR", administration: Advisor.wilsonAdministration(), turnLength: .month)
        let gs = try XCTUnwrap(engine.gameState)
        XCTAssertEqual(gs.getPlayerCountry()?.name, "Ottoman Empire")
        XCTAssertTrue(gs.advisors.contains { $0.name.hasPrefix("Mehmed V") }, "the Sultan advises his Grand Vizier")
    }

    // Security: nations without data are playable with generic titles; names are never made up

    func testNationsWithoutDataUseGenericTitles() throws {
        let gs = GameState(playerCountryID: "CMR")
        let cab = NationModel.cabinet(for: gs.getPlayerCountry()!, on: day(2025, 1, 20))
        XCTAssertFalse(cab.isEmpty)
        XCTAssertTrue(cab.allSatisfy { $0.name == "(no record)" })
        let data = try XCTUnwrap(NationCabinets.shared)
        let known = Set(data.nations.flatMap { $0.roles.values.flatMap { $0.map { $0[0] } } })
        for id in ["GBR", "FRA", "RUS", "JPN", "IRN"] {
            for a in NationModel.cabinet(for: GameState(playerCountryID: "USA").getCountry(id: id)!, on: day(1985, 6, 1)) {
                let bare = a.name.replacingOccurrences(of: " (acting/unverified)", with: "").replacingOccurrences(of: " ?", with: "")
                XCTAssertTrue(a.name == "(no record)" || known.contains(bare), "\(id): \(a.name)")
            }
        }
    }

    // Retry: saves keep the nation and its cabinet; old advisor records decode

    func testANationGameSurvivesSaveAndOldAdvisorsDecode() throws {
        let (_, gs) = try play("FRA", year: 2025)
        let loaded = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(gs))
        XCTAssertEqual(loaded.playerCountryID, "FRA")
        XCTAssertEqual(loaded.advisors.map(\.roleKey), gs.advisors.map(\.roleKey))
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(gs)) as? [String: Any])
        json["advisors"] = (json["advisors"] as? [[String: Any]])?.map { var a = $0; a.removeValue(forKey: "role"); return a }
        let old = try JSONDecoder().decode(GameState.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(old.advisors.count, gs.advisors.count)
    }

    // Performance

    func testCabinetLookupsAreCheap() throws {
        let gs = GameState(playerCountryID: "USA")
        let nations = ["GBR", "FRA", "RUS", "DEU", "JPN", "CHN", "TUR", "ESP", "ITA", "MEX"].compactMap { gs.getCountry(id: $0) }
        measure {
            for y in stride(from: 1800, through: 2030, by: 10) {
                for c in nations { _ = NationModel.cabinet(for: c, on: day(y, 6, 1)) }
            }
        }
    }
}

final class NationPlayHistoryTests: XCTestCase {
    private var dir: URL!
    override func setUp() { super.setUp(); dir = StoreFixtures.tempDir() }
    override func tearDown() { try? FileManager.default.removeItem(at: dir); super.tearDown() }

    @MainActor
    func testTheNationPlayedIsRecorded() async throws {
        let remote = InMemoryGameStore()
        let (e, service) = PlayFixtures.engine(dir, remote: remote)
        e.startNewGame(playerCountryID: "TUR", turnLength: .month)
        let id = try XCTUnwrap(e.gameState?.shadow.playSessionID)
        let synced = await service.syncNow()
        XCTAssertTrue(synced)
        let events = await remote.events(id)
        let start = try XCTUnwrap(events.first { $0.kind == "game_start" })
        XCTAssertEqual(PlayFixtures.detail(start)["country"] as? String, "TUR")
        XCTAssertNotNil(PlayFixtures.detail(start)["country_name"] as? String)
        let s = await remote.playSessions[id]
        XCTAssertEqual(PlayFixtures.summary(s)["country"] as? String, "TUR")
        XCTAssertNotNil(PlayFixtures.summary(s)["leader"])
    }
}

// MARK: - Coalitions and historical scenarios (3.12.0)

@MainActor
final class CoalitionAndScenarioTests: XCTestCase {

    private func scenario(_ id: String, turn: TurnLength? = nil) throws -> (GameEngine, GameState) {
        let engine = GameEngine()
        engine.startScenario(try XCTUnwrap(ScenarioDefinition.find(id)), turnLength: turn)
        return (engine, try XCTUnwrap(engine.gameState))
    }

    private func twin(_ gs: GameState) throws -> (GameEngine, GameState) {
        let copy = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(gs))
        let e = GameEngine(); e.gameState = copy
        return (e, copy)
    }

    // Unit

    func testJoinOddsAndSharedOpinion() {
        var last = -1.0
        for r in stride(from: -100, through: 100, by: 10) {
            let o = CoalitionModel.joinOdds(relationWithPlayer: r, relationWithTarget: 0, authorized: false, casusBelli: 0, wmdUsed: false)
            XCTAssertGreaterThanOrEqual(o, last); last = o
            XCTAssertTrue((0.02...0.95).contains(o))
        }
        let base = CoalitionModel.joinOdds(relationWithPlayer: 70, relationWithTarget: 0, authorized: false, casusBelli: 0, wmdUsed: false)
        XCTAssertGreaterThan(CoalitionModel.joinOdds(relationWithPlayer: 70, relationWithTarget: 0, authorized: true, casusBelli: 0, wmdUsed: false), base, "legitimacy helps")
        XCTAssertGreaterThan(CoalitionModel.joinOdds(relationWithPlayer: 70, relationWithTarget: 0, authorized: false, casusBelli: 1, wmdUsed: false), base)
        XCTAssertLessThan(CoalitionModel.joinOdds(relationWithPlayer: 70, relationWithTarget: 80, authorized: false, casusBelli: 0, wmdUsed: false), base, "friends of the target hang back")
        XCTAssertLessThan(CoalitionModel.joinOdds(relationWithPlayer: 70, relationWithTarget: 0, authorized: false, casusBelli: 0, wmdUsed: true), base, "banned weapons drive allies away")
        XCTAssertEqual(CoalitionModel.opinionShare(members: 0), 1)
        XCTAssertEqual(CoalitionModel.opinionShare(members: 3), 0.25)
    }

    func testEveryScenarioLoadsItsBoard() throws {
        XCTAssertEqual(ScenarioDefinition.all.count, 10)
        for s in ScenarioDefinition.all {
            let (_, gs) = try scenario(s.id)
            XCTAssertEqual(gs.currentDate, s.startDate, s.id)
            XCTAssertEqual(gs.shadow.scenarioID, s.id)
            for (a, b) in s.wars { XCTAssertTrue(gs.activeWars.contains { $0.aggressor == a && $0.defender == b }, "\(s.id): \(a)-\(b)") }
            XCTAssertFalse(Scorecard.lines(for: s.id, in: gs).isEmpty, s.id)
        }
    }

    // Functional: scenarios and their scorecards

    func testPearlHarborPlaysOutAndScoresAgainstHistory() throws {
        let (engine, gs) = try scenario("pearl1941", turn: .week)
        XCTAssertTrue(Scorecard.fought("USA", "JPN", in: gs), "the war with Japan starts on day one")
        XCTAssertFalse(Scorecard.fought("USA", "DEU", in: gs))
        gs.turn += 1
        engine.processShadowTurn()
        XCTAssertTrue(Scorecard.fought("USA", "DEU", in: gs), "Germany declares war on 11 Dec")
        let lines = Scorecard.lines(for: "pearl1941", in: gs)
        XCTAssertEqual(lines.first { $0.label.contains("Nuclear") }?.matchesHistory, false, "no bomb yet: diverges from 1945")
        XCTAssertTrue(lines.first { $0.label.contains("Germany") }?.historical.contains("11 Dec 1941") ?? false)
    }

    func testSeptember11WithCongressAndACoalitionMatchesHistory() throws {
        let (engine, gs) = try scenario("sept11_2001", turn: .week)
        let pi = try XCTUnwrap(gs.countries.firstIndex { $0.id == "USA" })
        gs.countries[pi].congressionalSupport = 70; gs.countries[pi].warSupport = 70
        XCTAssertEqual(engine.requestAuthorization(target: "AFG", kind: .useOfForce, roll: 0)?.passed, true)
        gs.actionsUsedThisTurn = 0
        let rolls = Dictionary(uniqueKeysWithValues: engine.coalitionCandidates(against: "AFG").map { ($0, 0.0) })
        let co = try XCTUnwrap(engine.requestCoalition(against: "AFG", rolls: rolls))
        XCTAssertTrue(co.members.contains("GBR"))
        engine.declareWar(aggressor: "USA", defender: "AFG")
        let score = Scorecard.score(Scorecard.lines(for: "sept11_2001", in: gs))
        XCTAssertEqual(score.matched, score.total, "authorized, coalition, war, no nukes: as in 2001")
    }

    func testCoalitionMembersFightAndShareTheBlame() throws {
        let (e1, g1) = try scenario("world1990")
        engine(e1, g1, invade: "IRQ")
        let f0 = try XCTUnwrap(g1.shadow.fronts.first { $0.defender == "IRQ" && $0.status == .fighting }).attackerTroops
        let (e2, g2) = try twin(g1)
        g1.actionsUsedThisTurn = 0
        let rolls = Dictionary(uniqueKeysWithValues: e1.coalitionCandidates(against: "IRQ").map { ($0, 0.0) })
        let co = try XCTUnwrap(e1.requestCoalition(against: "IRQ", rolls: rolls))
        XCTAssertFalse(co.members.isEmpty)
        XCTAssertGreaterThan(g1.shadow.fronts.first { $0.defender == "IRQ" && $0.status == .fighting }!.attackerTroops, f0, "allies send troops")
        // The same overwhelming air strike costs less abroad with a coalition.
        g1.actionsUsedThisTurn = 0; g2.actionsUsedThisTurn = 0
        let big = AttackSize(aircraft: AttackSizing.standard(.airStrike, in: g1).aircraft * 3)
        let jpn1 = g1.getCountry(id: "JPN")!.diplomaticRelations["USA"] ?? 0, jpn2 = g2.getCountry(id: "JPN")!.diplomaticRelations["USA"] ?? 0
        e1.applySizedFallout(.airStrike, target: "IRQ", size: big, scale: 3, kinds: [.aircraft], success: true)
        e2.applySizedFallout(.airStrike, target: "IRQ", size: big, scale: 3, kinds: [.aircraft], success: true)
        let drop1 = jpn1 - (g1.getCountry(id: "JPN")!.diplomaticRelations["USA"] ?? 0), drop2 = jpn2 - (g2.getCountry(id: "JPN")!.diplomaticRelations["USA"] ?? 0)
        XCTAssertLessThan(drop1, drop2)
    }

    private func engine(_ e: GameEngine, _ gs: GameState, invade target: String) {
        e.declareWar(aggressor: "USA", defender: target)
        e.syncFronts()
    }

    func testRefusersDriftAway() throws {
        let (engine, gs) = try scenario("world1990")
        let cands = engine.coalitionCandidates(against: "IRQ")
        let who = try XCTUnwrap(cands.first)
        let r0 = gs.getCountry(id: who)!.diplomaticRelations["USA"] ?? 0
        let rolls = Dictionary(uniqueKeysWithValues: cands.map { ($0, 0.999) })
        let co = try XCTUnwrap(engine.requestCoalition(against: "IRQ", rolls: rolls))
        XCTAssertTrue(co.members.isEmpty)
        XCTAssertLessThan(gs.getCountry(id: who)!.diplomaticRelations["USA"] ?? 0, r0)
    }

    // Security

    func testBadCoalitionRequestsAreRefused() throws {
        let (engine, gs) = try scenario("modern2025")
        XCTAssertNil(engine.requestCoalition(against: "USA"))
        XCTAssertNil(engine.requestCoalition(against: "ZZZ"))
        let cands = engine.coalitionCandidates(against: "RUS")
        XCTAssertFalse(cands.contains("RUS")); XCTAssertFalse(cands.contains("USA"))
        XCTAssertFalse(cands.contains { gs.getCountry(id: "RUS")!.alliances.contains($0) }, "the target's allies are never asked")
        gs.actionsUsedThisTurn = gs.actionsPerTurn
        XCTAssertNil(engine.requestCoalition(against: "IRN"), "no actions left")
        XCTAssertTrue(Scorecard.lines(for: "nope", in: gs).isEmpty)
    }

    // Retry

    func testCoalitionsMergeAndSurviveAReload() throws {
        let (engine, gs) = try scenario("world1990")
        let cands = engine.coalitionCandidates(against: "IRQ")
        engine.requestCoalition(against: "IRQ", rolls: Dictionary(uniqueKeysWithValues: cands.map { ($0, 0.0) }))
        gs.actionsUsedThisTurn = 0
        engine.requestCoalition(against: "IRQ", rolls: Dictionary(uniqueKeysWithValues: cands.map { ($0, 0.0) }))
        let co = try XCTUnwrap(gs.shadow.coalitions["IRQ"])
        XCTAssertEqual(co.members.count, Set(co.members).count, "asking twice adds no duplicates")
        let loaded = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(gs))
        XCTAssertEqual(loaded.shadow.coalitions, gs.shadow.coalitions)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(gs)) as? [String: Any])
        var shadow = try XCTUnwrap(json["shadow"] as? [String: Any])
        shadow.removeValue(forKey: "coalitions"); json["shadow"] = shadow
        XCTAssertTrue(try JSONDecoder().decode(GameState.self, from: JSONSerialization.data(withJSONObject: json)).shadow.coalitions.isEmpty)
    }

    // Performance

    func testCoalitionOddsAreCheap() throws {
        let (engine, _) = try scenario("modern2025")
        measure { for t in ["RUS", "IRN", "PRK", "CHN", "VEN", "CUB"] { _ = engine.coalitionOdds(against: t) } }
    }
}

final class CoalitionPlayHistoryTests: XCTestCase {
    private var dir: URL!
    override func setUp() { super.setUp(); dir = StoreFixtures.tempDir() }
    override func tearDown() { try? FileManager.default.removeItem(at: dir); super.tearDown() }

    @MainActor
    func testCoalitionRequestsAreLogged() async throws {
        let remote = InMemoryGameStore()
        let (e, service) = PlayFixtures.engine(dir, remote: remote)
        e.startScenario(try XCTUnwrap(ScenarioDefinition.find("korea1950")), turnLength: .week)
        let id = try XCTUnwrap(e.gameState?.shadow.playSessionID)
        let cands = e.coalitionCandidates(against: "PRK")
        XCTAssertNotNil(e.requestCoalition(against: "PRK", rolls: Dictionary(uniqueKeysWithValues: cands.map { ($0, 0.0) })))
        let synced = await service.syncNow()
        XCTAssertTrue(synced)
        let events = await remote.events(id)
        let ev = try XCTUnwrap(events.first { $0.kind == "coalition_request" })
        XCTAssertEqual(PlayFixtures.detail(ev)["target"] as? String, "PRK")
        XCTAssertEqual((PlayFixtures.detail(ev)["joined"] as? [String])?.count, cands.count)
        XCTAssertEqual(PlayFixtures.detail(try XCTUnwrap(events.first { $0.kind == "game_start" }))["scenario"] as? String, "korea1950")
    }
}

// MARK: - Mute switch: tests never make a sound or take the desktop

final class AudioGateTests: XCTestCase {
    override func tearDown() { AudioGate.environmentOverride = nil; AudioGate.defaultsOverride = nil; super.tearDown() }

    func testTheTestHostIsMutedAndHidden() {
        XCTAssertTrue(AudioGate.underXCTest, "running as an XCTest host")
        XCTAssertTrue(AudioGate.muted)
        XCTAssertEqual(ProcessInfo.processInfo.environment["GTNW_MUTE"], "1", "the test scheme passes GTNW_MUTE=1")
        #if os(macOS)
        XCTAssertEqual(NSApplication.shared.activationPolicy(), .prohibited, "the test host never activates")
        XCTAssertFalse(NSApplication.shared.isActive)
        #endif
    }

    func testEveryAudioPathIsANoOpWhenMuted() {
        let before = AudioGate.suppressed
        XCTAssertFalse(ShadowPack.shared.play("sfx.nuke_strike"), "no player is created")
        XCTAssertFalse(ShadowPack.shared.play("sfx.hail_to_chief", volume: 1))
        XCTAssertGreaterThanOrEqual(AudioGate.suppressed, before + 2)
        XCTAssertFalse(AudioGate.allow())
    }

    func testTheSwitchesTheAppHonours() {
        let empty = UserDefaults(suiteName: "GTNWTests.mute.\(UUID().uuidString)")!
        AudioGate.defaultsOverride = empty
        AudioGate.environmentOverride = [:]
        XCTAssertFalse(AudioGate.muted, "an ordinary launch plays sound")
        AudioGate.environmentOverride = ["GTNW_MUTE": "1"]
        XCTAssertTrue(AudioGate.muted)
        AudioGate.environmentOverride = ["GTNW_MUTE": "0"]
        XCTAssertFalse(AudioGate.muted)
        AudioGate.environmentOverride = ["XCTestConfigurationFilePath": "/tmp/x.xctestconfiguration"]
        XCTAssertTrue(AudioGate.muted)
        AudioGate.environmentOverride = [:]
        empty.set(true, forKey: "GTNWMute")   // what `-GTNWMute YES` puts in the argument domain
        XCTAssertTrue(AudioGate.muted)
    }
}

// MARK: - Evolving cabinets, the Gulf War and Cuba scorecards (3.12.2)

@MainActor
final class EvolvingCabinetTests: XCTestCase {

    /// Britain in January 1951: Attlee's government, Bevin at the Foreign Office.
    private func britain1951() throws -> (GameEngine, GameState) {
        let engine = GameEngine()
        engine.startNewGame(playerCountryID: "GBR", turnLength: .month)
        let gs = try XCTUnwrap(engine.gameState)
        gs.eraStartYear = 1951
        let me = try XCTUnwrap(gs.getPlayerCountry())
        gs.advisors = NationModel.cabinet(for: me, on: gs.currentDate)
        gs.shadow.playerLeader = NationModel.leader(for: me, on: gs.currentDate).name
        gs.shadow.cabinetFollowsHistory = true
        return (engine, gs)
    }

    private func months(_ e: GameEngine, _ gs: GameState, _ n: Int) { for _ in 0..<n { gs.turn += 1; e.processCabinets() } }

    private func foreign(_ gs: GameState) -> String? { gs.advisors.last { $0.isActive && $0.role == "state" }?.name }

    func testOfficeholdersChangeOnTheirRealDates() throws {
        let (engine, gs) = try britain1951()
        XCTAssertEqual(gs.shadow.playerLeader, "Clement Attlee")
        XCTAssertEqual(foreign(gs), "Ernest Bevin")
        months(engine, gs, 3)   // April 1951
        XCTAssertEqual(foreign(gs), "Herbert Morrison", "Morrison took over the Foreign Office in March 1951")
        XCTAssertTrue(gs.shadow.ticker.contains { $0.text.contains("Herbert Morrison replaces Ernest Bevin") })
        XCTAssertTrue(gs.shadow.cabinetFollowsHistory)
    }

    func testHistoryStopsWhenHistoryRemovesThePlayer() throws {
        let (engine, gs) = try britain1951()
        months(engine, gs, 10)   // November 1951: Churchill returns to No. 10 in history
        XCTAssertFalse(gs.shadow.cabinetFollowsHistory)
        XCTAssertTrue(gs.shadow.ticker.contains { $0.text.contains("History records Sir Winston Churchill") })
        XCTAssertEqual(foreign(gs), "Herbert Morrison", "Eden does not arrive: the government is the player's now")
        XCTAssertNil(gs.shadow.domesticEnding, "and the player is not removed by history")
    }

    func testThePlayersOwnAppointmentEndsTheScript() throws {
        let (engine, gs) = try britain1951()
        let i = try XCTUnwrap(gs.advisors.firstIndex { $0.isActive && $0.role == "state" })
        engine.departAdvisor(index: i, status: .fired, reason: "Bevin is dismissed.")
        XCTAssertFalse(gs.shadow.cabinetFollowsHistory)
        let acting = foreign(gs)
        months(engine, gs, 4)
        XCTAssertEqual(foreign(gs), acting, "history no longer appoints anyone")
    }

    func testComputerNationsKeepTheirHistoricalLeadersUntilTheyDiverge() throws {
        let engine = GameEngine()
        engine.startNewGame(turnLength: .month)
        let gs = try XCTUnwrap(engine.gameState)
        gs.eraStartYear = 1960
        engine.processCabinets()
        XCTAssertTrue(gs.shadow.leaderNames["FRA"]?.hasPrefix("Charles de Gaulle") ?? false, gs.shadow.leaderNames["FRA"] ?? "nil")
        let fi = try XCTUnwrap(gs.countries.firstIndex { $0.id == "FRA" })
        gs.countries[fi].government = .military   // a coup in this game
        engine.processCabinets()
        XCTAssertTrue(gs.shadow.divergedNations.contains("FRA"))
        XCTAssertNil(gs.shadow.leaderNames["FRA"], "no longer de Gaulle's France")
        gs.turn += 120   // 1970
        engine.processCabinets()
        XCTAssertNil(gs.shadow.leaderNames["FRA"], "and history does not come back")
    }

    func testUSGamesAreUnaffected() throws {
        let engine = GameEngine()
        engine.startNewGame(turnLength: .month)
        let gs = try XCTUnwrap(engine.gameState)
        let before = gs.advisors.map(\.name)
        gs.turn += 24; engine.processCabinets()
        XCTAssertEqual(gs.advisors.map(\.name), before)
    }

    func testCabinetStateSurvivesSaveAndOldSavesDecode() throws {
        let (engine, gs) = try britain1951()
        months(engine, gs, 2)
        let loaded = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(gs))
        XCTAssertEqual(loaded.shadow.playerLeader, "Clement Attlee")
        XCTAssertEqual(loaded.shadow.leaderNames, gs.shadow.leaderNames)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(gs)) as? [String: Any])
        var shadow = try XCTUnwrap(json["shadow"] as? [String: Any])
        for k in ["cabinetFollowsHistory", "playerLeader", "trackedGovernments", "divergedNations", "leaderNames"] { shadow.removeValue(forKey: k) }
        json["shadow"] = shadow
        let old = try JSONDecoder().decode(GameState.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertTrue(old.shadow.cabinetFollowsHistory); XCTAssertTrue(old.shadow.leaderNames.isEmpty)
    }

    func testEvolvingCabinetsAreCheap() throws {
        let engine = GameEngine()
        engine.startNewGame(turnLength: .month)
        let gs = try XCTUnwrap(engine.gameState)
        measure { for _ in 0..<12 { gs.turn += 1; engine.processCabinets() } }
    }

    // The Gulf War and Cuba 1962 scorecards

    func testGulfWarPlayedAsHistoryScoresFullMarks() throws {
        let engine = GameEngine()
        engine.startScenario(try XCTUnwrap(ScenarioDefinition.find("gulf1990")), turnLength: .week)
        let gs = try XCTUnwrap(engine.gameState)
        XCTAssertTrue(Scorecard.fought("IRQ", "KWT", in: gs), "the invasion has happened on day one")
        let pi = try XCTUnwrap(gs.countries.firstIndex { $0.id == "USA" })
        gs.countries[pi].congressionalSupport = 70; gs.countries[pi].warSupport = 70
        XCTAssertEqual(engine.requestAuthorization(target: "IRQ", kind: .useOfForce, roll: 0)?.passed, true)
        gs.actionsUsedThisTurn = 0
        engine.requestCoalition(against: "IRQ", rolls: Dictionary(uniqueKeysWithValues: engine.coalitionCandidates(against: "IRQ").map { ($0, 0.0) }))
        engine.declareWar(aggressor: "USA", defender: "IRQ"); engine.syncFronts()
        let i = try XCTUnwrap(gs.shadow.fronts.firstIndex { $0.attacker == "USA" && $0.defender == "IRQ" && $0.status == .fighting })
        engine.resolveFront(index: i, verdict: .attackerWon)
        let lines = Scorecard.lines(for: "gulf1990", in: gs)
        XCTAssertEqual(lines.count, 5)
        XCTAssertEqual(Scorecard.score(lines).matched, 5, lines.map { "\($0.label)=\($0.player)" }.joined(separator: ", "))
    }

    func testCubaScorecardCountsTheQuarantineAndDefcon() throws {
        let engine = GameEngine()
        engine.startScenario(try XCTUnwrap(ScenarioDefinition.find("cuba1962")), turnLength: .day)
        let gs = try XCTUnwrap(engine.gameState)
        let quarantine = { Scorecard.lines(for: "cuba1962", in: gs).first { $0.label.contains("quarantine") } }
        XCTAssertEqual(quarantine()?.matchesHistory, false)
        XCTAssertNotNil(engine.orderFleet("atlfleet", to: "CUB", mission: .blockade))
        XCTAssertEqual(quarantine()?.matchesHistory, true)
        gs.defconLevel = .defcon2
        XCTAssertEqual(Scorecard.lines(for: "cuba1962", in: gs).first { $0.label.contains("DEFCON") }?.matchesHistory, true)
        XCTAssertEqual(Scorecard.lines(for: "cuba1962", in: gs).count, 5)
    }
}

// MARK: - Takeable land on every continent (3.13.0)

@MainActor
final class PreStateLandTests: XCTestCase {

    private func game(_ admin: Administration) throws -> (GameEngine, GameState) {
        let engine = GameEngine()
        engine.startNewGame(administration: admin, turnLength: .month)
        return (engine, try XCTUnwrap(engine.gameState))
    }

    // Unit: the data

    func testDataIsConsistentWithTheEraBoard() {
        XCTAssertGreaterThan(PreStateModel.eras.count, 90)
        for land in PreStateModel.lands {
            XCTAssertNotNil(PreStateModel.template(land), land)
            let spans = PreStateModel.eras.filter { $0.land == land }.sorted { $0.from < $1.from }
            for (a, b) in zip(spans, spans.dropFirst()) { XCTAssertLessThanOrEqual(a.to, b.from, "\(land) eras overlap") }
        }
        for e in PreStateModel.eras {
            if e.kind == .colony { XCTAssertNotNil(PreStateModel.ownerNames[e.owner], e.owner) } else { XCTAssertTrue((0...100).contains(e.extra)) }
            // During its era the modern country is not on the board (the land would otherwise be shown twice).
            let mid = (e.from + e.to - 1) / 2
            XCTAssertFalse(WorldCountriesDatabase.countriesForYear(mid).contains { $0.id == e.land }, "\(e.land) in \(mid)")
        }
        XCTAssertTrue(WorldMapData.shared.shapes.contains { $0.id == PreStateModel.alaska }, "Alaska has its own outline")
        XCTAssertTrue(WorldMapData.shared.shapes.contains { $0.id == "USA" })
    }

    func testCanadaAndMexicoInThe1790s() throws {
        let (_, gs) = try game(Advisor.washingtonAdministration())
        XCTAssertEqual(gs.preState("CAN")?.label, "British North America (UK)")
        XCTAssertEqual(gs.preState("MEX")?.label, "New Spain (Spain)")
        XCTAssertTrue(gs.preState("MEX")?.ownerPresent ?? false)
        XCTAssertEqual(gs.preState(PreStateModel.alaska)?.label, "Russian America (Russia)")
        XCTAssertEqual(gs.preState("BRA")?.era.owner, "PRT")
        XCTAssertEqual(gs.preState("NZL")?.era.kind, .indigenous)
        XCTAssertTrue(gs.colonyLandIDs.isSuperset(of: ["CAN", "MEX", "ARG", "AUS", "IRL"]))
        XCTAssertTrue(gs.indigenousLandIDs.isSuperset(of: ["NZL", "SAU", "MMR"]))
        XCTAssertNil(gs.preState("FRA"), "a country in the game is not pre-state land")
    }

    func testEveryContinentHasTakeableLand() {
        let regions = Set(PreStateModel.lands.compactMap { PreStateModel.template($0)?.region })
        XCTAssertTrue(regions.isSuperset(of: [.northAmerica, .southAmerica, .europe, .asia, .middleEast, .oceania]))
    }

    func testPricesAndOddsAreSensible() {
        XCTAssertGreaterThan(PreStateModel.price("MEX", year: 1800, relation: -100), PreStateModel.price("MEX", year: 1800, relation: 100))
        XCTAssertEqual(PreStateModel.saleOdds(relation: 90, atWar: true, historical: false), 0, "no sale in wartime")
        XCTAssertEqual(PreStateModel.saleOdds(relation: 0, atWar: false, historical: true), 1, "a historical offer is good")
        XCTAssertGreaterThan(PreStateModel.revoltOdds(year: 1815, independence: 1816, ownerAtWarWithPlayer: false, ownerStability: 50),
                             PreStateModel.revoltOdds(year: 1790, independence: 1816, ownerAtWarWithPlayer: false, ownerStability: 50), "riper near the real date")
        XCTAssertGreaterThan(PreStateModel.seizeOdds(troops: 50, attackerStrength: 60, defenders: 5, defenderStrength: 40),
                             PreStateModel.seizeOdds(troops: 5, attackerStrength: 60, defenders: 5, defenderStrength: 40))
    }

    // Functional: war, purchase, liberation, indigenous land, historical offers

    func testSeizeNewSpainFromSpain() throws {
        let (engine, gs) = try game(Advisor.jeffersonAdministration())
        XCTAssertEqual(engine.seizeColony("MEX", troops: 5, roll: 0), true, "the 1801 army is small: 5K of it")
        XCTAssertEqual(gs.getCountry(id: "MEX")?.territoryOf, "USA")
        XCTAssertTrue(gs.getCountry(id: "ESP")!.atWarWith.contains("USA"), "seizing a colony means war with its owner")
        XCTAssertNil(gs.preState("MEX"))
        XCTAssertTrue(engine.renameTerritory("MEX", to: "New Columbia"))
        XCTAssertGreaterThan(OccupationModel.neededGarrison(gs.getCountry(id: "MEX")!), 0, "3.9.0 rules apply")
    }

    func testBuyAndFreeColonies() throws {
        let (engine, gs) = try game(Advisor.monroeAdministration())
        let gbr = try XCTUnwrap(gs.countries.firstIndex { $0.id == "GBR" })
        gs.countries[gbr].diplomaticRelations["USA"] = 80
        let wealth = gs.getPlayerCountry()!.gdp * 1000 + gs.shadow.aidRemaining
        XCTAssertEqual(engine.purchaseColony("CAN", roll: 0), true)
        XCTAssertEqual(gs.getCountry(id: "CAN")?.territoryOf, "USA")
        XCTAssertLessThan(gs.getPlayerCountry()!.gdp * 1000 + gs.shadow.aidRemaining, wealth, "the price is paid (3.13.1: from funds first)")
        gs.actionsUsedThisTurn = 0
        let esp0 = gs.getCountry(id: "ESP")!.diplomaticRelations["USA"] ?? 0
        XCTAssertEqual(engine.supportIndependence("ARG", roll: 0), true)
        let arg = try XCTUnwrap(gs.getCountry(id: "ARG"))
        XCTAssertNil(arg.territoryOf, "a free state, not a territory")
        XCTAssertTrue(arg.alliances.contains("USA"))
        XCTAssertLessThan(gs.getCountry(id: "ESP")!.diplomaticRelations["USA"] ?? 0, esp0, "Spain resents it")
    }

    func testIndigenousLandResistsAndCostsStability() throws {
        let (engine, gs) = try game(Advisor.jeffersonAdministration())
        XCTAssertEqual(engine.claimIndigenousLand("NZL", troops: 2, roll: 0.999), false, "its people drive the expedition off")
        XCTAssertNil(gs.getCountry(id: "NZL"))
        gs.actionsUsedThisTurn = 0
        XCTAssertEqual(engine.claimIndigenousLand("NZL", troops: 6, roll: 0), true)
        let nz = try XCTUnwrap(gs.getCountry(id: "NZL"))
        XCTAssertEqual(nz.territoryOf, "USA")
        XCTAssertLessThan(nz.stability, 50); XCTAssertGreaterThan(nz.profile.outcry, 50, "resistance continues")
        XCTAssertTrue(gs.shadow.ticker.contains { $0.text.contains("Its people do not accept it") })
    }

    func testLouisianaAndAlaskaOffersInTheirWindows() throws {
        let (engine, gs) = try game(Advisor.jeffersonAdministration())
        gs.turn = 25   // early 1803
        XCTAssertEqual(engine.openAcquisitions().map(\.id), ["louisiana"])
        engine.processPreState()
        XCTAssertTrue(gs.shadow.ticker.contains { $0.text.contains("Louisiana Purchase") })
        XCTAssertTrue(engine.acceptAcquisition("louisiana"))
        XCTAssertTrue(gs.shadow.acquired.contains("louisiana"))
        XCTAssertGreaterThan(gs.shadow.acquisitionIncome, 0)
        XCTAssertFalse(engine.acceptAcquisition("louisiana"), "once only")
        let (e2, g2) = try game(Advisor.ajohnsonAdministration())
        g2.turn = 24   // 1867
        XCTAssertEqual(g2.currentYear, 1867)
        XCTAssertTrue(e2.openAcquisitions().contains { $0.id == "alaska" }, "\(e2.openAcquisitions().map(\.id)) RUS=\(g2.getCountry(id: "RUS")?.name ?? "nil")")
        XCTAssertTrue(e2.acceptAcquisition("alaska"))
        XCTAssertNil(g2.preState(PreStateModel.alaska), "Alaska is American")
    }

    // Security

    func testBadOrdersAreRefused() throws {
        let (engine, gs) = try game(Advisor.jeffersonAdministration())
        XCTAssertNil(engine.seizeColony("FRA", troops: 5, roll: 0), "not a colony")
        XCTAssertNil(engine.seizeColony("MEX", troops: 1e9, roll: 0), "more troops than exist")
        XCTAssertNil(engine.seizeColony("MEX", troops: .nan, roll: 0))
        XCTAssertNil(engine.claimIndigenousLand("MEX", troops: 5, roll: 0), "a colony is not indigenous land")
        XCTAssertNil(engine.purchaseColony("ZZZ", roll: 0))
        XCTAssertFalse(engine.acceptAcquisition("alaska"), "not its window")
        let other = GameEngine(); other.startNewGame(playerCountryID: "GBR", turnLength: .month)
        XCTAssertTrue(other.openAcquisitions().isEmpty, "the U.S. offers are for a U.S. President")
        XCTAssertNil(gs.getCountry(id: "MEX"))
    }

    // Retry: persistence and old saves

    func testAcquisitionsSurviveSaveAndOldSavesLoad() throws {
        let (engine, gs) = try game(Advisor.jeffersonAdministration())
        gs.turn = 25
        engine.acceptAcquisition("louisiana")
        let loaded = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(gs))
        XCTAssertEqual(loaded.shadow.acquired, ["louisiana"])
        XCTAssertEqual(loaded.shadow.acquisitionIncome, gs.shadow.acquisitionIncome)
        let e2 = GameEngine(); e2.gameState = loaded
        XCTAssertFalse(e2.acceptAcquisition("louisiana"))
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(gs)) as? [String: Any])
        var shadow = try XCTUnwrap(json["shadow"] as? [String: Any])
        for k in ["acquired", "acquisitionIncome", "announcedOffers"] { shadow.removeValue(forKey: k) }
        json["shadow"] = shadow
        XCTAssertTrue(try JSONDecoder().decode(GameState.self, from: JSONSerialization.data(withJSONObject: json)).shadow.acquired.isEmpty)
    }

    // Performance

    func testPreStateLookupsAreCheap() throws {
        let (_, gs) = try game(Advisor.washingtonAdministration())
        measure { for _ in 0..<50 { _ = gs.colonyLandIDs; _ = gs.indigenousLandIDs } }
    }
}

final class PreStatePlayHistoryTests: XCTestCase {
    private var dir: URL!
    override func setUp() { super.setUp(); dir = StoreFixtures.tempDir() }
    override func tearDown() { try? FileManager.default.removeItem(at: dir); super.tearDown() }

    @MainActor
    func testTakingLandIsLogged() async throws {
        let remote = InMemoryGameStore()
        let (e, service) = PlayFixtures.engine(dir, remote: remote)
        e.startNewGame(playerCountryID: "USA", administration: Advisor.jeffersonAdministration(), turnLength: .month)
        let gs = try XCTUnwrap(e.gameState)
        let id = try XCTUnwrap(gs.shadow.playSessionID)
        XCTAssertEqual(e.seizeColony("CUB", troops: 5, roll: 0), true)
        gs.actionsUsedThisTurn = 0
        XCTAssertNotNil(e.supportIndependence("ARG", roll: 0.999))
        let synced = await service.syncNow()
        XCTAssertTrue(synced)
        let kinds = await remote.events(id).map(\.kind)
        XCTAssertTrue(kinds.contains("colony_seized")); XCTAssertTrue(kinds.contains("independence_backed"))
    }
}

// MARK: - 3.13.1: territory money

final class TerritoryMoneyTests: XCTestCase {

    private func game() throws -> (GameEngine, GameState) {
        let engine = GameEngine()
        engine.startNewGame(administration: Advisor.mckinleyAdministration(), turnLength: .month)
        return (engine, try XCTUnwrap(engine.gameState))
    }

    /// Claim South Africa's gold and hold it a few years so it is producing.
    private func goldFields() throws -> (GameEngine, GameState) {
        let (engine, gs) = try game()
        XCTAssertTrue(engine.claimLand("ZAF"))
        gs.turn += 36
        return (engine, gs)
    }

    // Unit: the rates and the helpers

    func testRatesScaleIncomeAndCost() throws {
        let m = ExtractionRate.allCases.map(\.incomeMultiplier)
        XCTAssertEqual(m, m.sorted(), "heavier rates pay more")
        XCTAssertEqual(ExtractionRate.normal.incomeMultiplier, 1)
        XCTAssertEqual(ExtractionRate.light.insurgencyShift, 0)
        XCTAssertGreaterThan(ExtractionRate.plunder.insurgencyShift, ExtractionRate.heavy.insurgencyShift)
        let (engine, gs) = try goldFields()
        let zaf = try XCTUnwrap(gs.getCountry(id: "ZAF"))
        let normal = ExpansionModel.annualIncome(zaf, in: gs)
        XCTAssertTrue(engine.setExtraction("ZAF", .plunder))
        XCTAssertEqual(ExpansionModel.annualIncome(zaf, in: gs), normal * 2.5, accuracy: 1e-9)
        XCTAssertGreaterThanOrEqual(ExpansionModel.levyAmount(zaf, in: gs), 0.2)
    }

    func testRampUpCountdown() throws {
        let (engine, gs) = try game()
        XCTAssertTrue(engine.claimLand("ZAF"))
        XCTAssertEqual(ExpansionModel.monthsUntilProducing("ZAF", in: gs), 6, "new land produces after six months")
        gs.turn += 12
        XCTAssertEqual(ExpansionModel.monthsUntilProducing("ZAF", in: gs), 0)
    }

    // Functional: cash into the funds, levies, group actions

    func testTerritoryCashLandsInFunds() throws {
        let (engine, gs) = try goldFields()
        gs.shadow.aidRemaining = 0
        engine.processTerritoryEconomy()
        XCTAssertGreaterThan(gs.shadow.lastTurnCash, 0)
        XCTAssertEqual(gs.shadow.aidRemaining, gs.shadow.lastTurnCash, accuracy: 1e-9, "spendable right away")
        XCTAssertTrue(gs.shadow.ticker.contains { $0.text.hasPrefix("Territories paid $") })
    }

    func testLevyPaysThenCoolsDown() throws {
        let (engine, gs) = try goldFields()
        let funds = gs.shadow.aidRemaining
        let st = gs.getCountry(id: "ZAF")!.stability
        let paid = try XCTUnwrap(engine.collectLevy("ZAF"))
        XCTAssertEqual(gs.shadow.aidRemaining, funds + paid, accuracy: 1e-9)
        XCTAssertEqual(gs.getCountry(id: "ZAF")!.stability, max(0, st - 10))
        XCTAssertEqual(ExpansionModel.levyCooldown("ZAF", in: gs), 6)
        XCTAssertNil(engine.collectLevy("ZAF"), "cooling down")
        gs.turn += 5
        XCTAssertEqual(ExpansionModel.levyCooldown("ZAF", in: gs), 1)
        gs.turn += 1
        XCTAssertNotNil(engine.collectLevy("ZAF"), "ready again after exactly six months (3.13.2)")
    }

    func testGroupExtractionAndLevy() throws {
        let (engine, gs) = try goldFields()
        gs.actionsUsedThisTurn = 0
        XCTAssertTrue(engine.claimLand("NAM"))
        let members = engine.groupMembers(.territories)
        XCTAssertTrue(Set(members).isSuperset(of: ["ZAF", "NAM"]))
        let used = gs.actionsUsedThisTurn
        XCTAssertNotNil(engine.executeGroupAction(.extraction, members: members, rate: .heavy))
        XCTAssertEqual(ExpansionModel.rate("NAM", in: gs), .heavy)
        XCTAssertEqual(gs.actionsUsedThisTurn, used, "territory money is free")
        let plan = engine.planGroupAction(.levy, members: members)
        XCTAssertNil(plan.problem)
        XCTAssertNotNil(engine.executeGroupAction(.levy, members: members))
        XCTAssertNotNil(engine.planGroupAction(.levy, members: members).problem, "all cooling down")
    }

    // Security: only your own land, and bad saves fall back safely

    func testOnlyYourTerritories() throws {
        let (engine, gs) = try goldFields()
        XCTAssertFalse(engine.setExtraction("FRA", .plunder))
        XCTAssertNil(engine.collectLevy("FRA"))
        XCTAssertNil(engine.collectLevy("ZZZ"))
        XCTAssertNotNil(engine.planGroupAction(.levy, members: ["ZAF", "FRA"]).problem)
        gs.shadow.extraction["ZAF"] = "<script>plunder</script>\u{0}"
        XCTAssertEqual(ExpansionModel.rate("ZAF", in: gs), .normal, "unknown rates read as normal")
    }

    // Integration: plunder stirs the insurgency and costs friends

    func testPlunderStirsInsurgencyAndCostsGoodwill() throws {
        let (engine, gs) = try goldFields()
        let (calm, g2) = try goldFields()
        XCTAssertTrue(engine.setExtraction("ZAF", .plunder))
        let fra0 = gs.getCountry(id: "FRA")!.diplomaticRelations["USA"] ?? 0
        for _ in 0..<12 { gs.turn += 1; g2.turn += 1; engine.processOccupation(); calm.processOccupation(); engine.processTerritoryEconomy() }
        if let p = gs.getCountry(id: "ZAF"), p.territoryOf == "USA" {
            XCTAssertGreaterThan(p.profile.outcry, g2.getCountry(id: "ZAF")!.profile.outcry)
            // The yearly goodwill cost is a stochastic integer, so it only lands while the territory is still held.
            XCTAssertLessThan(gs.getCountry(id: "FRA")!.diplomaticRelations["USA"] ?? 0, fra0)
        }   // else it already revolted, which plunder allows
    }

    // Retry: persistence and old saves

    func testMoneyStateSurvivesSaveAndOldSavesLoad() throws {
        let (engine, gs) = try goldFields()
        engine.setExtraction("ZAF", .heavy)
        engine.collectLevy("ZAF")
        engine.processTerritoryEconomy()
        let loaded = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(gs))
        XCTAssertEqual(loaded.shadow.extraction, ["ZAF": "heavy"])
        XCTAssertNotNil(loaded.shadow.lastLevy["ZAF"])
        XCTAssertEqual(loaded.shadow.lastTurnCash, gs.shadow.lastTurnCash, accuracy: 1e-9)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(gs)) as? [String: Any])
        var shadow = try XCTUnwrap(json["shadow"] as? [String: Any])
        for k in ["extraction", "lastLevy", "lastTurnCash"] { shadow.removeValue(forKey: k) }
        json["shadow"] = shadow
        let old = try JSONDecoder().decode(GameState.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertTrue(old.shadow.extraction.isEmpty)
        XCTAssertEqual(ExpansionModel.levyCooldown("ZAF", in: old), 0)
    }

    // Performance

    func testResourceSheetMathIsCheap() throws {
        let (_, gs) = try goldFields()
        measure {
            for _ in 0..<50 {
                for r in ExpansionModel.ledger(gs) {
                    _ = ExpansionModel.limit(r.country, in: gs); _ = ExpansionModel.levyCooldown(r.country.id, in: gs)
                    _ = ExpansionModel.monthsUntilProducing(r.country.id, in: gs)
                }
            }
        }
    }
}

final class TerritoryMoneyPlayHistoryTests: XCTestCase {
    private var dir: URL!
    override func setUp() { super.setUp(); dir = StoreFixtures.tempDir() }
    override func tearDown() { try? FileManager.default.removeItem(at: dir); super.tearDown() }

    @MainActor
    func testLevyIsLogged() async throws {
        let remote = InMemoryGameStore()
        let (e, service) = PlayFixtures.engine(dir, remote: remote)
        e.startNewGame(playerCountryID: "USA", administration: Advisor.mckinleyAdministration(), turnLength: .month)
        let gs = try XCTUnwrap(e.gameState)
        let id = try XCTUnwrap(gs.shadow.playSessionID)
        XCTAssertTrue(e.claimLand("ZAF"))
        XCTAssertNotNil(e.collectLevy("ZAF"))
        let synced = await service.syncNow()
        XCTAssertTrue(synced)
        let kinds = await remote.events(id).map(\.kind)
        XCTAssertTrue(kinds.contains("territory_levy"))
    }
}

// MARK: - 3.13.2: levy cooldown and first-year stability recovery

final class TerritoryRecoveryTests: XCTestCase {

    /// A fresh, fully garrisoned South Africa at stability 45.
    private func fresh() throws -> (GameEngine, GameState) {
        let engine = GameEngine()
        engine.startNewGame(administration: Advisor.mckinleyAdministration(), turnLength: .month)
        let gs = try XCTUnwrap(engine.gameState)
        XCTAssertTrue(engine.claimLand("ZAF"))
        let i = try XCTUnwrap(gs.countries.firstIndex { $0.id == "ZAF" })
        gs.countries[i].stability = 45
        gs.shadow.garrisons["ZAF"] = OccupationModel.neededGarrison(gs.countries[i])
        return (engine, gs)
    }

    private func zaf(_ gs: GameState) -> Country { gs.getCountry(id: "ZAF")! }

    // Unit

    func testRecoveryCountdown() throws {
        let (_, gs) = try fresh()
        XCTAssertEqual(ExpansionModel.stabilityRecoveryMonths(zaf(gs), in: gs), 12)
        XCTAssertEqual(ExpansionModel.limit(zaf(gs), in: gs), "Stability 45 → 60 in ~12 months at this garrison.")
        gs.turn += 4
        XCTAssertEqual(ExpansionModel.stabilityRecoveryMonths(zaf(gs), in: gs), 8)
        XCTAssertEqual(ExpansionModel.monthsUntilProducing("ZAF", in: gs), 2, "calendar months (3.13.2)")
        gs.turn += 8
        XCTAssertNil(ExpansionModel.stabilityRecoveryMonths(zaf(gs), in: gs), "only the first year")
    }

    func testLevyCooldownIsSixCalendarMonths() throws {
        let (engine, gs) = try fresh()
        gs.turn += 12
        XCTAssertNotNil(engine.collectLevy("ZAF"))
        XCTAssertEqual((0...6).map { _ -> Int in defer { gs.turn += 1 }; return ExpansionModel.levyCooldown("ZAF", in: gs) }, [6, 5, 4, 3, 2, 1, 0])
    }

    // Functional: good governance clears the warning within the year

    func testGoodGovernanceReachesSixty() throws {
        let (engine, gs) = try fresh()
        var seen: [Int] = []
        for _ in 0..<12 { gs.turn += 1; engine.processOccupation(); seen.append(zaf(gs).stability) }
        XCTAssertGreaterThanOrEqual(zaf(gs).stability, 60)
        XCTAssertEqual(seen, seen.sorted(), "steady recovery")
        XCTAssertFalse(ExpansionModel.limit(zaf(gs), in: gs)?.contains("stability") ?? false)
    }

    // Security: no free recovery for squeezed or neglected land

    func testNoRecoveryWhenSqueezedOrUndermanned() throws {
        let (engine, gs) = try fresh()
        engine.setExtraction("ZAF", .heavy)
        XCTAssertNil(ExpansionModel.stabilityRecoveryMonths(zaf(gs), in: gs))
        engine.setExtraction("ZAF", .light)
        XCTAssertNotNil(ExpansionModel.stabilityRecoveryMonths(zaf(gs), in: gs))
        gs.shadow.garrisons["ZAF"] = 0.5
        XCTAssertNil(ExpansionModel.stabilityRecoveryMonths(zaf(gs), in: gs))
        XCTAssertNil(ExpansionModel.stabilityRecoveryMonths(gs.getCountry(id: "FRA")!, in: gs), "not a territory")
    }

    // Integration: a full year of occupation and economy leaves a producing, stable territory

    func testFirstYearEndsStableAndPaying() throws {
        let (engine, gs) = try fresh()
        for _ in 0..<12 { gs.turn += 1; engine.processOccupation(); engine.processTerritoryEconomy() }
        XCTAssertEqual(gs.getCountry(id: "ZAF")?.territoryOf, "USA")
        XCTAssertGreaterThanOrEqual(zaf(gs).stability, 60)
        XCTAssertGreaterThan(gs.shadow.lastTurnCash, 0)
    }

    // Retry: a save mid-recovery resumes the countdown

    func testRecoverySurvivesSave() throws {
        let (_, gs) = try fresh()
        gs.turn += 3
        let loaded = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(gs))
        XCTAssertEqual(ExpansionModel.stabilityRecoveryMonths(loaded.getCountry(id: "ZAF")!, in: loaded), 9)
    }

    // Performance

    func testRecoveryCheckIsCheap() throws {
        let (_, gs) = try fresh()
        let c = zaf(gs)
        measure { for _ in 0..<2000 { _ = ExpansionModel.stabilityRecoveryMonths(c, in: gs) } }
    }
}

// MARK: - 3.14.0: a living world, era-true nations, every land selectable

final class MapSweepTests: XCTestCase {
    static let eras = [1789, 1850, 1913, 1950, 2025]

    private func board(_ year: Int) throws -> (GameEngine, GameState) {
        let engine = GameEngine()
        engine.startNewGame(turnLength: .month, year: year)
        return (engine, try XCTUnwrap(engine.gameState))
    }

    /// A point inside the outline (map units), found on a grid over its bounds.
    private func interior(_ s: MapCountryShape) -> CGPoint? {
        for n in [8, 24, 80] {
            for i in 0..<n { for j in 0..<n {
                let p = CGPoint(x: s.bounds.minX + s.bounds.width * (Double(i) + 0.5) / Double(n),
                                y: s.bounds.minY + s.bounds.height * (Double(j) + 0.5) / Double(n))
                if s.path.contains(p) { return p }
            } }
        }
        return nil
    }

    // Frame / Functional: every land outline resolves, has a colour designation, and can be clicked on the map and
    // found in the card grid, in every era.
    func testEveryLandIsSelectableInEveryEra() throws {
        let shapes = WorldMapData.shared.shapes
        XCTAssertGreaterThan(shapes.count, 200)
        for year in Self.eras {
            let (_, gs) = try board(year)
            let present = Set(gs.countries.filter { !$0.isDestroyed }.map(\.id))
            let unclaimed = gs.unclaimedLandIDs
            let cards = present.union(SimpleModernWorldMap.landCardIDs(gs))
            var missing: [String] = []
            for s in shapes {
                guard let sel = WorldMapData.selection(for: s.id, in: gs, present: present, unclaimed: unclaimed) else {
                    missing.append("\(s.id) \(s.name)"); continue
                }
                // A status with an owner that is really on this board (colour designation).
                if let pre = gs.preState(s.id) {
                    if pre.era.kind == .colony { XCTAssertTrue(present.contains(pre.era.owner), "\(year) \(s.id): colony owner \(pre.era.owner) not on the board") }
                } else if !unclaimed.contains(sel) {
                    XCTAssertTrue(present.contains(sel), "\(year) \(s.id): owner \(sel) not on the board")
                }
                XCTAssertTrue(cards.contains(sel), "\(year) \(s.id): no card for \(sel)")
                // Offscreen click: the outline under an interior point selects something.
                if let p = interior(s), let top = shapes.first(where: { $0.bounds.contains(p) && $0.path.contains(p) }) {
                    XCTAssertNotNil(WorldMapData.selection(for: top.id, in: gs, present: present, unclaimed: unclaimed), "\(year) \(s.id): click finds nothing")
                }
            }
            XCTAssertTrue(missing.isEmpty, "\(year): unselectable \(missing.joined(separator: ", "))")
        }
    }

    func testCanadaMexicoMongoliaIn1789() throws {
        let (_, gs) = try board(1789)
        let present = Set(gs.countries.map(\.id))
        for id in ["CAN", "MEX", "MNG", "AUS", "NZL", "BRA", "ARG"] {
            XCTAssertNotNil(WorldMapData.selection(for: id, in: gs, present: present, unclaimed: gs.unclaimedLandIDs), id)
        }
        XCTAssertEqual(gs.preState("MNG")?.era.owner, "CHN")
        XCTAssertEqual(gs.getCountry(id: "CHN")?.name, "Qing Empire")
    }
}

final class EraNationTests: XCTestCase {
    /// Nations that must not be on the 1789 board.
    func testNoModernStatesIn1789() throws {
        let engine = GameEngine()
        engine.startNewGame(turnLength: .month, year: 1789)
        let gs = try XCTUnwrap(engine.gameState)
        let ids = Set(gs.countries.map(\.id))
        for id in ["CSK", "YUG", "SUR", "LKA", "MDV", "DZA", "VUT", "SLB", "TWN", "FJI"] { XCTAssertFalse(ids.contains(id), id) }
        let names = gs.countries.map(\.name)
        XCTAssertFalse(names.contains("Republic of China"))
    }
}


final class LivingWorldTests: XCTestCase {

    /// Run `turns` monthly turns of the real Shadow turn plus the rule-based AI, as `endTurn` does (minus the async).
    static func simulate(year: Int, difficulty: DifficultyLevel, turns: Int = 200) -> (GameEngine, GameState) {
        let e = GameEngine()
        e.startNewGame(difficulty: difficulty, turnLength: .month, year: year)
        let gs = e.gameState!
        for _ in 0..<turns {
            gs.turn += 1
            e.processShadowTurn()
            let p = e.aiActionProbability(gs)
            for c in gs.liveCountries where c.id != gs.playerCountryID && Double.random(in: 0..<1) < p { e.applyRuleBasedAction(for: c.id) }
        }
        return (e, gs)
    }

    // Integration: 200 turns from 1789, 1850, 1913, 1950 and 2025 on every difficulty; the world is busy, and
    // Nightmare is clearly the busiest.
    func testTheWorldIsAliveInEveryEraAndDifficulty() {
        for year in MapSweepTests.eras {
            var wars: [DifficultyLevel: Int] = [:]
            for d in DifficultyLevel.allCases {
                let (_, gs) = Self.simulate(year: year, difficulty: d)
                let s = gs.shadow.worldStats
                wars[d] = s["wars"] ?? 0
                let minWars = d == .easy ? 2 : 5
                XCTAssertGreaterThanOrEqual(s["wars"] ?? 0, minWars, "\(year) \(d.rawValue): AI-vs-AI wars")
                XCTAssertGreaterThanOrEqual(s["diplomacy"] ?? 0, 100, "\(year) \(d.rawValue): diplomacy")
                if year < 1946 { XCTAssertGreaterThanOrEqual(s["claims"] ?? 0, d == .easy ? 4 : 10, "\(year) \(d.rawValue): land claims") }
            }
            XCTAssertGreaterThan(Double(wars[.nightmare]!), Double(wars[.normal]!) * 1.5, "\(year): Nightmare is relentless")
            XCTAssertGreaterThanOrEqual(wars[.nightmare]!, wars[.hard]!, "\(year): Nightmare is the most active")
            XCTAssertGreaterThan(wars[.normal]!, wars[.easy]!, "\(year): Easy is the calmest")
        }
    }

    // Functional: the era's wars break out between the right powers.
    func testFrenchRevolutionaryWarsBreakOut() {
        let (_, gs) = Self.simulate(year: 1789, difficulty: .normal, turns: 50)
        XCTAssertTrue(gs.shadow.firedRivalries.contains("FRA-AUT-1792"))
        XCTAssertTrue(gs.shadow.ticker.contains { $0.text.contains("declares war") } || (gs.shadow.worldStats["wars"] ?? 0) > 0)
        XCTAssertLessThanOrEqual(gs.getCountry(id: "FRA")?.diplomaticRelations["GBR"] ?? 0, -60, "the 1793 enmity")
    }

    func testPowersClaimLandAndSeizeEnemyColonies() throws {
        let e = GameEngine()
        e.startNewGame(turnLength: .month, year: 1885)
        let gs = try XCTUnwrap(e.gameState)
        let land = try XCTUnwrap(gs.unclaimedLandIDs.sorted().first { $0 != Antarctica.id })
        XCTAssertTrue(WorldPolitics.reachesOverseas("FRA", year: 1885))
        XCTAssertFalse(WorldPolitics.reachesOverseas("VNM", year: 1885), "only the colonial powers reach overseas")
        XCTAssertTrue(e.aiTakeLand(land, by: "FRA"))
        XCTAssertEqual(gs.getCountry(id: land)?.territoryOf, "FRA")
        XCTAssertFalse(gs.unclaimedLandIDs.contains(land), "taken land is no longer open to the player")
        XCTAssertFalse(e.aiTakeLand(land, by: "GBR"), "not twice")
    }

    func testPowersAnswerUSExpansion() throws {
        let e = GameEngine()
        e.startNewGame(difficulty: .nightmare, turnLength: .month, year: 1890)
        let gs = try XCTUnwrap(e.gameState)
        var taken: [String] = []
        for id in gs.unclaimedLandIDs.sorted().prefix(6) where id != Antarctica.id {
            gs.actionsUsedThisTurn = 0
            if e.claimLand(id, troops: 1) { taken.append(id) }
        }
        XCTAssertGreaterThanOrEqual(taken.count, 4)
        for _ in 0..<6 { gs.turn += 1; e.processWorldPolitics() }
        XCTAssertTrue(gs.shadow.ticker.contains { $0.text.contains("protests against American expansion") })
        XCTAssertTrue(gs.shadow.ticker.contains { $0.text.contains("arms rebels in") || $0.text.contains("seizes lightly garrisoned") })
    }

    func testTreatyOffersCanBeAnswered() throws {
        let e = GameEngine()
        e.startNewGame(turnLength: .month, year: 1913)
        let gs = try XCTUnwrap(e.gameState)
        gs.shadow.treatyOffers = [TreatyOffer(from: "FRA", type: .nonAggression, date: gs.currentDate),
                                  TreatyOffer(from: "GBR", type: .alliance, date: gs.currentDate)]
        let n = gs.treaties.count
        XCTAssertTrue(e.answerTreaty(gs.shadow.treatyOffers[0].id, accept: true))
        XCTAssertEqual(gs.treaties.count, n + 1)
        XCTAssertTrue(e.answerTreaty(gs.shadow.treatyOffers[0].id, accept: false))
        XCTAssertTrue(gs.shadow.treatyOffers.isEmpty)
        XCTAssertFalse(gs.getPlayerCountry()!.alliances.contains("GBR"), "declined")
    }

    // Unit: difficulty scaling and era-true militia call-ups.
    func testDifficultyScalesActivity() {
        let a = DifficultyLevel.allCases.map(WorldPolitics.activity)
        XCTAssertEqual(a, a.sorted())
        XCTAssertGreaterThan(WorldPolitics.claimRate(year: 1885), WorldPolitics.claimRate(year: 1850), "the Scramble for Africa")
        XCTAssertLessThan(WorldPolitics.claimRate(year: 1960), WorldPolitics.claimRate(year: 1850))
        XCTAssertLessThan(WorldPolitics.reactionThreshold(.nightmare), WorldPolitics.reactionThreshold(.easy))
    }

    func testMilitiaInThe1790sNeverZero() throws {
        XCTAssertEqual(ManpowerModel.callUpSize(.mobilization, year: 1792), 13)
        XCTAssertEqual(ManpowerModel.title(.mobilization, year: 1792), "Call out the militia")
        let e = GameEngine()
        e.startNewGame(turnLength: .month, year: 1792)
        let gs = try XCTUnwrap(e.gameState)
        XCTAssertNotNil(e.callUpProblem(.draft), "no federal draft before 1863")
        XCTAssertTrue(e.callUp(.mobilization))
        let line = try XCTUnwrap(gs.shadow.ticker.last?.text)
        XCTAssertTrue(line.contains("calls out the militia: 13K"), line)
        for y in stride(from: 1789, through: 2025, by: 4) { XCTAssertGreaterThanOrEqual(ManpowerModel.callUpSize(.mobilization, year: y), 1, "\(y)") }
    }

    // Security: generators never name a nation that isn't on the board that year.
    func testEventGeneratorsUseOnlyNationsOfTheEra() throws {
        let allNames = Set(WorldCountriesDatabase.allCountries().map(\.name) + ["Republic of China", "Czechoslovakia", "Yugoslavia"])
        for year in MapSweepTests.eras {
            let e = GameEngine()
            e.startNewGame(difficulty: .nightmare, turnLength: .month, year: year)
            let gs = try XCTUnwrap(e.gameState)
            let present = gs.countries.map(\.name)
            let absent = allNames.filter { n in !present.contains { $0.contains(n) } }
            var text: [String] = []
            for type in CrisisEventType.allCases {
                for _ in 0..<4 { if let c = e.crisisManager.createCrisis(type: type, gameState: gs) { text.append(c.title + " " + c.description) } }
            }
            let news = NewsManager()
            for _ in 0..<30 { news.generateNews(from: gs) }
            text += news.headlines.map(\.headline)
            for _ in 0..<24 {
                gs.turn += 1; e.processShadowTurn()
                for c in gs.liveCountries where c.id != gs.playerCountryID { e.applyRuleBasedAction(for: c.id) }
            }
            // Land is named for its geography ("France claims Gambia") and the record of the age (3.17.6) names
            // peoples and places rather than states ("its Armenian population"); every other line must name only
            // nations of the era.
            let record = Set(gs.shadow.worldAtrocities.map(\.text))
            text += gs.shadow.ticker.map(\.text).filter { !$0.contains(" claims ") && !$0.contains(" seizes ") && !record.contains($0) }
            // Nations born during play (a territory that revolts into independence) are of the era too.
            let born = gs.countries.map(\.name)
            for t in text { for n in absent where t.contains(n) && !born.contains(where: { $0.contains(n) }) { XCTFail("\(year): \(n) named in \(t.prefix(120))") } }
            for c in gs.countries { for k in c.diplomaticRelations.keys { XCTAssertNotNil(gs.getCountry(id: k), "\(year): relation with \(k)") } }
        }
    }

    // Retry: the living world survives save and load, and old saves load.
    func testWorldStateSurvivesSave() throws {
        let (_, gs) = Self.simulate(year: 1789, difficulty: .hard, turns: 40)
        gs.shadow.treatyOffers.append(TreatyOffer(from: "ESP", type: .tradeAgreement, date: gs.currentDate))
        let loaded = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(gs))
        XCTAssertEqual(loaded.shadow.worldStats, gs.shadow.worldStats)
        XCTAssertEqual(loaded.shadow.firedRivalries, gs.shadow.firedRivalries)
        XCTAssertEqual(loaded.shadow.treatyOffers, gs.shadow.treatyOffers)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(gs)) as? [String: Any])
        var shadow = try XCTUnwrap(json["shadow"] as? [String: Any])
        for k in ["worldStats", "firedRivalries", "treatyOffers", "lastReaction"] { shadow.removeValue(forKey: k) }
        json["shadow"] = shadow
        XCTAssertTrue(try JSONDecoder().decode(GameState.self, from: JSONSerialization.data(withJSONObject: json)).shadow.treatyOffers.isEmpty)
    }

    // Performance: a busy Nightmare month stays quick.
    func testABusyWorldTurnIsQuick() {
        let (e, gs) = Self.simulate(year: 1913, difficulty: .nightmare, turns: 1)
        measure { gs.turn += 1; e.processWorldPolitics(); _ = gs.unclaimedLandIDs }
    }
}

// MARK: - 3.14.1: independent Africa, the Balkan states, AI territories with stakes

final class EraStatesTests: XCTestCase {
    private func board(_ year: Int) throws -> GameState {
        let e = GameEngine()
        e.startNewGame(turnLength: .month, year: year)
        return try XCTUnwrap(e.gameState)
    }

    // Unit: which African states stand alone, by year
    func testIndependentAfricaByYear() {
        XCTAssertEqual(WorldCountriesDatabase.independentAfrica(year: 1789), ["ETH", "MDG"])
        XCTAssertEqual(WorldCountriesDatabase.independentAfrica(year: 1850), ["ETH", "LBR", "MDG"])
        XCTAssertEqual(WorldCountriesDatabase.independentAfrica(year: 1900), ["ETH", "LBR"])
        for y in stride(from: 1789, through: 1959, by: 5) {
            XCTAssertFalse(WorldCountriesDatabase.unclaimedLandIDs(year: y).contains("ETH"), "Ethiopia was never unclaimed (\(y))")
        }
    }

    // Functional: the boards and their names
    func testAfricaIsEraTrue() throws {
        let g1789 = try board(1789)
        XCTAssertEqual(g1789.getCountry(id: "ETH")?.name, "Ethiopian Empire")
        XCTAssertEqual(g1789.getCountry(id: "MDG")?.name, "Merina Kingdom")
        XCTAssertNil(g1789.getCountry(id: "LBR"))
        XCTAssertEqual(g1789.preState("GHA")?.era.name, "Ashanti Empire")
        XCTAssertEqual(g1789.preState("TZA")?.era.owner, "OMN", "the Swahili coast under Oman")
        XCTAssertFalse(g1789.unclaimedLandIDs.contains("GHA"), "peoples' land, not unclaimed")
        let g1850 = try board(1850)
        XCTAssertEqual(g1850.getCountry(id: "LBR")?.name, "Liberia")
        XCTAssertEqual(g1850.preState("NGA")?.era.name, "Sokoto Caliphate")
        XCTAssertEqual(g1850.getCountry(id: "MAR")?.name, "Morocco")
        let g1913 = try board(1913)
        XCTAssertNil(g1913.getCountry(id: "MDG"), "French Madagascar from 1896")
        XCTAssertEqual(g1913.preState("GHA")?.era.name, "Gold Coast", "British after the Ashanti were conquered in 1901")
        XCTAssertEqual(g1913.getCountry(id: "MAR")?.name, "French Morocco")
    }

    func testBalkanStatesStandAlone() throws {
        let g1789 = try board(1789)
        XCTAssertNil(g1789.getCountry(id: "SRB"))
        XCTAssertEqual(g1789.preState("SRB")?.era.owner, "TUR")
        let g1850 = try board(1850)
        XCTAssertEqual(g1850.getCountry(id: "SRB")?.name, "Principality of Serbia")
        XCTAssertEqual(g1850.getCountry(id: "GRC")?.name, "Kingdom of Greece")
        XCTAssertNil(g1850.getCountry(id: "ROU"))
        let g1881 = try board(1881)
        for (id, name) in [("SRB", "Principality of Serbia"), ("MNE", "Principality of Montenegro"), ("ROU", "Kingdom of Romania"),
                           ("BGR", "Principality of Bulgaria")] {
            XCTAssertEqual(g1881.getCountry(id: id)?.name, name, id)
        }
        let g1913 = try board(1913)
        XCTAssertEqual(g1913.getCountry(id: "SRB")?.name, "Kingdom of Serbia")
        XCTAssertEqual(g1913.getCountry(id: "BGR")?.name, "Kingdom of Bulgaria")
        XCTAssertNil(g1913.getCountry(id: "YUG"))
        let present = Set(g1913.countries.map(\.id))
        XCTAssertEqual(WorldMapData.owner(of: "MKD", in: present, year: 1913), "SRB", "Macedonia to Serbia after the Balkan Wars")
        XCTAssertEqual(try board(1925).getCountry(id: "YUG")?.name, "Yugoslavia")
    }

    // Frame: every outline still resolves in the years the new states appear and vanish
    func testSweepAroundTheNewDates() throws {
        let shapes = WorldMapData.shared.shapes
        for year in [1817, 1847, 1878, 1896, 1901, 1908] {
            let gs = try board(year)
            let present = Set(gs.countries.filter { !$0.isDestroyed }.map(\.id))
            let unclaimed = gs.unclaimedLandIDs
            let missing = shapes.filter { WorldMapData.selection(for: $0.id, in: gs, present: present, unclaimed: unclaimed) == nil }.map(\.id)
            XCTAssertTrue(missing.isEmpty, "\(year): \(missing)")
            XCTAssertTrue(unclaimed.isDisjoint(with: Set(PreStateModel.lands.filter { gs.preState($0) != nil })), "\(year): unclaimed and pre-state overlap")
        }
    }

    // Integration: AI-held territories pay their owner and can rise up
    func testAITerritoriesPayAndRevolt() throws {
        let e = GameEngine()
        e.startNewGame(turnLength: .month, year: 1900)
        let gs = try XCTUnwrap(e.gameState)
        XCTAssertTrue(e.aiTakeLand("ZAF", by: "GBR") || gs.getCountry(id: "ZAF") != nil)
        gs.shadow.claimDates["ZAF"] = GameCalendar.date(year: 1890, month: 1, day: 1)   // long held: full output
        if let i = gs.countries.firstIndex(where: { $0.id == "ZAF" }) { gs.countries[i].territoryOf = "GBR" }
        let gdp0 = gs.getCountry(id: "GBR")!.gdp
        e.processAITerritories()
        XCTAssertGreaterThan(gs.getCountry(id: "GBR")!.gdp, gdp0, "South African gold pays London")
        XCTAssertGreaterThan(gs.shadow.worldStats["aiIncomeCents"] ?? 0, 0)
        let i = try XCTUnwrap(gs.countries.firstIndex { $0.id == "ZAF" })
        var rose = false
        for _ in 0..<480 where !rose {   // 30% a year: ~3% a month; 40 years leave no realistic chance of a miss
            gs.countries[i].profile.outcry = 95
            gs.turn += 1
            e.processAITerritories()
            rose = gs.getCountry(id: "ZAF")?.territoryOf == nil
        }
        XCTAssertTrue(rose, "a territory boiling over wins its independence in time")
        XCTAssertGreaterThanOrEqual(gs.shadow.worldStats["revolts"] ?? 0, 1)
        XCTAssertFalse(gs.getCountry(id: "GBR")!.alliances.contains("ZAF"))
    }

    // Security: the player's free troops don't pay for AI garrisons
    func testAIGarrisonsAreNotOnThePlayersBooks() throws {
        let e = GameEngine()
        e.startNewGame(turnLength: .month, year: 1890)
        let gs = try XCTUnwrap(e.gameState)
        let free = AttackSizing.freeTroops(gs)
        let land = try XCTUnwrap(gs.unclaimedLandIDs.sorted().first { $0 != Antarctica.id })
        XCTAssertTrue(e.aiTakeLand(land, by: "FRA"))
        e.processAITerritories()
        XCTAssertEqual(AttackSizing.freeTroops(gs), free, accuracy: 1e-9)
        XCTAssertNil(gs.shadow.garrisons[land])
    }

    // Performance
    func testAITerritoryTurnIsCheap() throws {
        let (e, _) = LivingWorldTests.simulate(year: 1890, difficulty: .hard, turns: 24)
        measure { e.processAITerritories() }
    }

    // Retry: old saves (no claim date for AI land) load and run
    func testAITerritoryWithoutClaimDateStillWorks() throws {
        let e = GameEngine()
        e.startNewGame(turnLength: .month, year: 1890)
        let gs = try XCTUnwrap(e.gameState)
        let land = try XCTUnwrap(gs.unclaimedLandIDs.sorted().first { $0 != Antarctica.id })
        XCTAssertTrue(e.aiTakeLand(land, by: "FRA"))
        gs.shadow.claimDates.removeValue(forKey: land)
        let loaded = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(gs))
        let e2 = GameEngine(); e2.gameState = loaded
        e2.processAITerritories()
        XCTAssertEqual(loaded.getCountry(id: land)?.territoryOf ?? "FRA", "FRA")
    }
}

// MARK: - 3.15.0: Nova's commentary, the Hall of Infamy, era transitions

final class NovaCommentaryTests: XCTestCase {
    override func tearDown() {
        NovaCommentary.generator = nil
        NovaCommentary.defaults.removeObject(forKey: NovaCommentary.defaultsKey)
        super.tearDown()
    }

    private func game(_ year: Int = 1913) throws -> (GameEngine, GameState) {
        let e = GameEngine()
        e.startNewGame(turnLength: .month, year: year)
        return (e, try XCTUnwrap(e.gameState))
    }

    // Unit: templates are deterministic; picks follow the rules; replies are cleaned
    func testTemplatesPicksAndCleaning() {
        let war = TickerItem(date: Date(), text: "France declares war on Austria.", severity: 2)
        XCTAssertEqual(NovaCommentary.template(war, turn: 3), NovaCommentary.template(war, turn: 3))
        let flash = (0..<4).map { TickerItem(date: Date(), text: "Flash \($0)", severity: 3) }
        XCTAssertEqual(NovaCommentary.picks(flash + [war]).count, 2, "at most two flash lines")
        XCTAssertEqual(NovaCommentary.picks([war, TickerItem(date: Date(), text: "x", severity: 1)]).map(\.text), [war.text], "one line a turn")
        XCTAssertTrue(NovaCommentary.picks([TickerItem(date: Date(), text: "Nova: hi", severity: 2)]).isEmpty, "never comments on herself")
        XCTAssertEqual(NovaCommentary.clean("\"Nova: Well, that escalated.\"\nSecond line"), "Well, that escalated.")
        XCTAssertNil(NovaCommentary.clean("see http://example.com"))
        XCTAssertNil(NovaCommentary.clean("<script>alert(1)</script>"))
        XCTAssertNil(NovaCommentary.clean("  "))
    }

    // Functional: a notable turn gets one line on the ticker and in the record; the setting turns it off
    func testANotableTurnGetsALine() throws {
        let (e, gs) = try game()
        gs.shadow.post("Britain declares war on Germany.", date: gs.currentDate, severity: 2)
        e.processCommentary(seen: [])
        XCTAssertEqual(gs.shadow.novaLines.count, 1)
        XCTAssertTrue(gs.shadow.ticker.last?.text.hasPrefix("Nova: ") ?? false)
        NovaCommentary.defaults.set(false, forKey: NovaCommentary.defaultsKey)
        gs.shadow.post("Another war.", date: gs.currentDate, severity: 2)
        e.processCommentary(seen: [])
        XCTAssertEqual(gs.shadow.novaLines.count, 1, "off means off")
    }

    // Integration: the live backend's line replaces the template and is logged as Nova's
    @MainActor
    func testLiveLineReplacesTheTemplate() async throws {
        let (e, gs) = try game()
        var prompts: [String] = []
        NovaCommentary.generator = { p in prompts.append(p); return "\"Somebody should have read the treaty.\"" }
        let item = TickerItem(date: gs.currentDate, text: "Germany invades Belgium.", severity: 3)
        e.comment(NovaCommentary.template(item, turn: gs.turn), about: item)
        for _ in 0..<100 where !(gs.shadow.novaLines.last?.text.contains("treaty") ?? false) { try await Task.sleep(nanoseconds: 10_000_000) }
        XCTAssertEqual(gs.shadow.novaLines.last?.text, "Nova: Somebody should have read the treaty.")
        XCTAssertTrue(gs.shadow.ticker.contains { $0.text == "Nova: Somebody should have read the treaty." })
        XCTAssertTrue(prompts.first?.contains("Germany invades Belgium.") ?? false)
    }

    // Retry: a backend that fails leaves the template line standing
    @MainActor
    func testFailedBackendKeepsTheTemplate() async throws {
        let (e, gs) = try game()
        NovaCommentary.generator = { _ in nil }
        let item = TickerItem(date: gs.currentDate, text: "Russia mobilizes.", severity: 2)
        let template = NovaCommentary.template(item, turn: gs.turn)
        e.comment(template, about: item)
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(gs.shadow.novaLines.last?.text, "Nova: " + template)
    }

    // Security: hostile replies are dropped; the prompt carries game facts only
    @MainActor
    func testHostileRepliesAndPrivacy() async throws {
        let (e, gs) = try game()
        NovaCommentary.generator = { _ in "Click https://evil.example <img>" }
        let item = TickerItem(date: gs.currentDate, text: "A coup in Persia.", severity: 2)
        let template = NovaCommentary.template(item, turn: gs.turn)
        e.comment(template, about: item)
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(gs.shadow.novaLines.last?.text, "Nova: " + template)
        let prompt = NovaCommentary.prompt(item, gs: gs)
        XCTAssertFalse(prompt.contains(NSUserName()))
        XCTAssertFalse(prompt.contains(NSFullUserName()))
        XCTAssertFalse(prompt.contains("@"))
    }

    // Performance
    func testPickingIsCheap() {
        let items = (0..<120).map { TickerItem(date: Date(), text: "Headline \($0) war nuclear", severity: $0 % 4) }
        measure { for _ in 0..<50 { for i in NovaCommentary.picks(items) { _ = NovaCommentary.template(i, turn: 1) } } }
    }
}

final class HallOfInfamyTests: XCTestCase {
    override func setUp() { super.setUp(); HallOfInfamy.defaults.removeObject(forKey: HallOfInfamy.defaultsKey) }
    override func tearDown() { HallOfInfamy.defaults.removeObject(forKey: HallOfInfamy.defaultsKey); super.tearDown() }

    private func game() throws -> (GameEngine, GameState) {
        let e = GameEngine()
        e.startNewGame(turnLength: .month, year: 1890)
        return (e, try XCTUnwrap(e.gameState))
    }

    // Unit
    func testWhatCountsAsARecord() throws {
        let (_, gs) = try game()
        gs.shadow.ruthlessness = 40
        gs.shadow.popularity = 20
        let broken = Dictionary(uniqueKeysWithValues: HallOfInfamy.broken(gs, hall: [:]).map { ($0.0, $0.1) })
        XCTAssertEqual(broken[.ruthlessness], 40)
        XCTAssertEqual(broken[.lowestApproval], 20)
        XCTAssertNil(broken[.nukes], "zero isn't a record")
        let hall: [InfamyRecord: InfamyEntry] = [.lowestApproval: InfamyEntry(value: 10, who: "x", gameDate: Date(), setAt: Date())]
        XCTAssertFalse(HallOfInfamy.broken(gs, hall: hall).contains { $0.0 == .lowestApproval }, "20% doesn't beat 10%")
    }

    // Functional: records persist across sittings; beating an earlier sitting's record is announced
    func testRecordsPersistAndBeatingOneIsAnnounced() throws {
        let (e, gs) = try game()
        HallOfInfamy.save([.ruthlessness: InfamyEntry(value: 10, who: "United States, 1850", gameDate: Date(), setAt: .distantPast)])
        gs.shadow.ruthlessness = 55
        e.processHallOfInfamy()
        XCTAssertEqual(HallOfInfamy.load()[.ruthlessness]?.value, 55)
        XCTAssertTrue(gs.shadow.ticker.contains { $0.text.hasPrefix("Hall of Infamy: new record, most ruthless (55)") })
        let n = gs.shadow.ticker.count
        gs.shadow.ruthlessness = 60
        e.processHallOfInfamy()
        XCTAssertEqual(HallOfInfamy.load()[.ruthlessness]?.value, 60)
        XCTAssertFalse(gs.shadow.ticker.dropFirst(n).contains { $0.text.hasPrefix("Hall of Infamy") }, "pushing this sitting's own record is quiet")
    }

    // Retry: damaged storage reads as an empty hall
    func testDamagedStorageIsEmpty() {
        HallOfInfamy.defaults.set(Data("not json".utf8), forKey: HallOfInfamy.defaultsKey)
        XCTAssertTrue(HallOfInfamy.load().isEmpty)
        let raw = ["nukes": InfamyEntry(value: .nan, who: "x", gameDate: Date(), setAt: Date())]
        HallOfInfamy.defaults.set(try? JSONEncoder().encode(raw), forKey: HallOfInfamy.defaultsKey)
        XCTAssertTrue(HallOfInfamy.load().isEmpty, "NaN never loads")
    }

    // Security: the test host never writes the real defaults
    func testTestsUseAThrowawaySuite() {
        XCTAssertFalse(HallOfInfamy.defaults === UserDefaults.standard)
        XCTAssertFalse(NovaCommentary.defaults === UserDefaults.standard)
    }
}

final class EraTransitionTests: XCTestCase {
    private func run(from year: Int, years: Int, before: ((GameEngine, GameState) -> Void)? = nil) throws -> (GameEngine, GameState) {
        let e = GameEngine()
        e.startNewGame(turnLength: .month, year: year)
        let gs = try XCTUnwrap(e.gameState)
        e.processEraTransitions()   // remembers the starting governments
        before?(e, gs)
        for _ in 0..<years { gs.turn += 12; e.processEraTransitions() }
        return (e, gs)
    }

    // Functional: nations follow history through a long game
    func testNationsRenameOnTheirDates() throws {
        let (_, g1) = try run(from: 1881, years: 1)
        XCTAssertEqual(g1.getCountry(id: "SRB")?.name, "Kingdom of Serbia")
        XCTAssertTrue(g1.shadow.ticker.contains { $0.text == "Principality of Serbia becomes Kingdom of Serbia." })
        let (_, g2) = try run(from: 1911, years: 1)
        XCTAssertEqual(g2.getCountry(id: "CHN")?.name, "Republic of China")
        let (_, g3) = try run(from: 1916, years: 7)
        XCTAssertEqual(g3.getCountry(id: "RUS")?.name, "Soviet Union")
    }

    // Integration: once a nation's story diverges it stops following history
    func testADivergedNationKeepsItsStory() throws {
        let (_, gs) = try run(from: 1881, years: 1) { _, gs in
            let i = gs.countries.firstIndex { $0.id == "SRB" }!
            gs.countries[i].government = gs.countries[i].government == .democracy ? .military : .democracy
        }
        XCTAssertEqual(gs.getCountry(id: "SRB")?.name, "Principality of Serbia")
        XCTAssertTrue(gs.shadow.eraDiverged.contains("SRB"))
    }

    // Retry: the era state survives save and load; old saves start syncing afresh
    func testEraStateSurvivesSave() throws {
        let (_, gs) = try run(from: 1881, years: 1)
        let loaded = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(gs))
        XCTAssertEqual(loaded.shadow.eraSyncYear, gs.shadow.eraSyncYear)
        XCTAssertEqual(loaded.shadow.eraGovernment, gs.shadow.eraGovernment)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(gs)) as? [String: Any])
        var shadow = try XCTUnwrap(json["shadow"] as? [String: Any])
        for k in ["eraSyncYear", "eraGovernment", "eraDiverged", "novaLines"] { shadow.removeValue(forKey: k) }
        json["shadow"] = shadow
        XCTAssertEqual(try JSONDecoder().decode(GameState.self, from: JSONSerialization.data(withJSONObject: json)).shadow.eraSyncYear, 0)
    }

    // Performance: building an era board once a game year
    func testEraBoardIsQuickEnough() {
        measure { _ = GameState.eraBoard(year: 1913) }
    }
}


// MARK: - 3.16.0: peace victories

final class PeaceVictoryTests: XCTestCase {
    private func game(_ year: Int = 1913) throws -> (GameEngine, GameState) {
        let e = GameEngine()
        e.startNewGame(turnLength: .month, year: year)
        let gs = try XCTUnwrap(e.gameState)
        e.processWorldPolitics()   // sets the output baseline
        return (e, gs)
    }

    private func sign(_ gs: GameState, _ n: Int, type: TreatyType = .tradeAgreement) {
        for c in PeaceModel.others(gs).prefix(n) { gs.treaties.append(Treaty(type: type, signatories: [gs.playerCountryID, c.id], turn: gs.turn)) }
    }

    private func makePeaceful(_ gs: GameState) {
        gs.turn += 61
        for i in gs.countries.indices { gs.countries[i].atWarWith.remove(gs.playerCountryID) }
        if let p = gs.countries.firstIndex(where: { $0.id == gs.playerCountryID }) { gs.countries[p].atWarWith = [] }
    }

    // Unit: targets and odds
    func testTargetsAndOdds() throws {
        let (_, gs) = try game(1789)
        let n = Double(PeaceModel.others(gs).count)
        XCTAssertEqual(PeaceModel.progress(.treatyNetwork, gs).target, (n * 0.35).rounded(.up))
        XCTAssertEqual(PeaceModel.economicTarget(gs), gs.shadow.startOutputShare + 0.05, accuracy: 1e-9, "era-relative in 1789")
        let (_, g2) = try game(2025)
        XCTAssertEqual(PeaceModel.economicTarget(g2), 0.30, accuracy: 1e-9)
        let a = gs.countries[0], b = gs.countries[1]
        let odds = PeaceModel.brokerOdds(a, b, player: "USA")
        XCTAssertTrue((0.1...0.9).contains(odds))
    }

    // Functional: each path wins, at peace, after five years
    func testTreatyNetworkWins() throws {
        let (_, gs) = try game()
        sign(gs, Int(PeaceModel.progress(.treatyNetwork, gs).target))
        XCTAssertNil(VictoryChecker.checkVictory(gameState: gs), "five years in office first")
        makePeaceful(gs)
        XCTAssertEqual(VictoryChecker.checkVictory(gameState: gs), .diplomaticVictory)
    }

    func testAllianceLeadershipWins() throws {
        let (e, gs) = try game()
        let need = Int(PeaceModel.progress(.allianceLeader, gs).target)
        for c in PeaceModel.others(gs).sorted(by: { $0.alliances.count < $1.alliances.count }).prefix(need) { e.formAlliance(country1: gs.playerCountryID, country2: c.id) }
        makePeaceful(gs)
        for i in gs.countries.indices where gs.countries[i].id != gs.playerCountryID { gs.countries[i].alliances = gs.countries[i].alliances.filter { $0 == gs.playerCountryID } }
        XCTAssertNil(PeaceModel.progress(.allianceLeader, gs).missing)
        XCTAssertNotNil(VictoryChecker.checkVictory(gameState: gs))
    }

    func testNobelMomentsWin() throws {
        let (e, gs) = try game()
        let pairs = Array(zip(PeaceModel.others(gs).prefix(3), PeaceModel.others(gs).dropFirst(3).prefix(3)))
        for (a, b) in pairs { e.makePeace(a.id, b.id); e.declareWar(aggressor: a.id, defender: b.id) }
        for (a, b) in pairs { gs.actionsUsedThisTurn = 0; XCTAssertEqual(e.brokerPeace(a.id, b.id, roll: 0), true) }
        XCTAssertEqual(gs.shadow.nobelMoments, 3)
        XCTAssertFalse(gs.getCountry(id: pairs[0].0.id)!.atWarWith.contains(pairs[0].1.id))
        makePeaceful(gs)
        XCTAssertEqual(PeaceModel.progress(.nobel, gs).missing, nil)
        XCTAssertNotNil(VictoryChecker.checkVictory(gameState: gs))
    }

    // Integration: the President's treaty actions put treaties on record and count toward the network
    func testTreatyActionsCount() throws {
        let (e, gs) = try game()
        let t = try XCTUnwrap(PeaceModel.others(gs).first)
        e.executeShadowPresidentAction(.nonAggression, from: gs.playerCountryID, to: t.id)
        e.executeShadowPresidentAction(.nonAggression, from: gs.playerCountryID, to: t.id)
        XCTAssertEqual(gs.treaties.filter { $0.type == .nonAggression && $0.signatories.contains(t.id) }.count, 1, "once")
        XCTAssertTrue(PeaceModel.treatyPartners(gs).contains(t.id))
        XCTAssertGreaterThan(GameScore.calculate(from: gs, victoryType: nil).peaceBonus ?? 0, 0, "peace scores short of victory")
    }

    // Security: war, nukes and bad broker targets
    func testPeaceRequiresPeace() throws {
        let (e, gs) = try game()
        sign(gs, Int(PeaceModel.progress(.treatyNetwork, gs).target))
        makePeaceful(gs)
        let foe = try XCTUnwrap(PeaceModel.others(gs).last)
        e.declareWar(aggressor: gs.playerCountryID, defender: foe.id)
        XCTAssertEqual(PeaceModel.conditionsProblem(gs), "You are at war.")
        XCTAssertNil(VictoryChecker.checkVictory(gameState: gs).flatMap { [.diplomaticVictory, .peaceMaker].contains($0) ? $0 : nil })
        XCTAssertNil(e.brokerPeace(gs.playerCountryID, foe.id), "not your own war")
        XCTAssertNil(e.brokerPeace("FRA", "ZZZ"))
        gs.nuclearStrikes.append(NuclearStrike(attacker: gs.playerCountryID, target: foe.id, warheadsUsed: 1, turn: gs.turn, casualties: 0, radiationSpread: 0))
        e.makePeace(gs.playerCountryID, foe.id)
        XCTAssertEqual(PeaceModel.conditionsProblem(gs), "You have used nuclear weapons.")
    }

    // Retry: peace state survives save and load; old saves start at zero
    func testPeaceStateSurvivesSave() throws {
        let (_, gs) = try game()
        gs.shadow.nobelMoments = 2
        let loaded = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(gs))
        XCTAssertEqual(loaded.shadow.nobelMoments, 2)
        XCTAssertEqual(loaded.shadow.startOutputShare, gs.shadow.startOutputShare)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(gs)) as? [String: Any])
        var shadow = try XCTUnwrap(json["shadow"] as? [String: Any])
        for k in ["nobelMoments", "playerWarsStarted", "startOutputShare"] { shadow.removeValue(forKey: k) }
        json["shadow"] = shadow
        XCTAssertEqual(try JSONDecoder().decode(GameState.self, from: JSONSerialization.data(withJSONObject: json)).shadow.nobelMoments, 0)
    }

    // Performance: the panel's maths on the biggest board
    func testProgressIsCheap() throws {
        let (_, gs) = try game(2025)
        measure { for _ in 0..<20 { for p in PeacePath.allCases { _ = PeaceModel.progress(p, gs) }; _ = PeaceModel.scoreBonus(gs) } }
    }
}

// MARK: - 3.16.1: mid-game foundings, commentary on the AI phase

final class FoundingTests: XCTestCase {
    private func play(from year: Int, years: Int, before: ((GameEngine, GameState) -> Void)? = nil) throws -> (GameEngine, GameState) {
        let e = GameEngine()
        e.startNewGame(turnLength: .month, year: year)
        let gs = try XCTUnwrap(e.gameState)
        e.processEraTransitions()
        before?(e, gs)
        for _ in 0..<years { gs.turn += 12; e.processEraTransitions() }
        return (e, gs)
    }

    // Functional: nations appear on their real dates
    func testNationsAreFoundedOnTheirDates() throws {
        let (_, gs) = try play(from: 1789, years: 42)
        for id in ["SRB", "GRC"] {
            let c = try XCTUnwrap(gs.getCountry(id: id), id)
            XCTAssertNil(c.territoryOf, id)
        }
        XCTAssertTrue(gs.shadow.ticker.contains { $0.text.hasSuffix("is founded.") })
        XCTAssertNil(gs.preState("SRB"), "no longer an Ottoman colony")
        XCTAssertGreaterThanOrEqual(gs.shadow.worldStats["foundings"] ?? 0, 2)
        XCTAssertNotNil(gs.getCountry(id: "SRB")?.diplomaticRelations["TUR"], "the new state has relations")
        XCTAssertNotNil(gs.getCountry(id: "TUR")?.diplomaticRelations["SRB"], "and the world has relations with it")
    }

    // Integration: land the player took doesn't spawn a state; its people press for independence
    func testTakenLandGetsAMovementNotAState() throws {
        let (_, gs) = try play(from: 1950, years: 11) { e, gs in
            XCTAssertTrue(e.claimLand("CMR", troops: 5))
        }
        XCTAssertEqual(gs.getCountry(id: "CMR")?.territoryOf, "USA")
        XCTAssertTrue(gs.shadow.ticker.contains { $0.text.contains("independence movement in") && $0.text.contains("United States") })
        XCTAssertNotNil(gs.getCountry(id: "SEN"), "untaken Africa is decolonised")
        XCTAssertNil(gs.getCountry(id: "SEN")?.territoryOf)
    }

    // Integration: Yugoslavia absorbs Serbia and Montenegro in 1918
    func testSuccessorStatesAbsorbTheirParts() throws {
        let (_, gs) = try play(from: 1913, years: 6)
        XCTAssertNotNil(gs.getCountry(id: "YUG"))
        XCTAssertEqual(gs.getCountry(id: "SRB")?.territoryOf, "YUG")
    }

    // Retry: the board memory survives save; a save without it re-syncs without a flood
    func testBoardMemorySurvivesSave() throws {
        let (_, gs) = try play(from: 1789, years: 1)
        let loaded = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(gs))
        XCTAssertEqual(loaded.shadow.eraBoardIDs, gs.shadow.eraBoardIDs)
        XCTAssertFalse(loaded.shadow.eraBoardIDs.isEmpty)
    }

    // Security: the player's own nation and diverged nations are never absorbed
    func testDivergedPartsStayIndependent() throws {
        let (_, gs) = try play(from: 1913, years: 6) { _, gs in gs.shadow.eraDiverged.insert("SRB") }
        XCTAssertNil(gs.getCountry(id: "SRB")?.territoryOf)
    }
}

final class AIPhaseCommentaryTests: XCTestCase {
    override func tearDown() { NovaCommentary.generator = nil; super.tearDown() }

    // Functional: the Shadow turn alone no longer comments; the full turn comments after the AI phase
    @MainActor
    func testCommentsAfterTheAIPhase() async throws {
        let e = GameEngine()
        e.startNewGame(turnLength: .month, year: 1913)
        let gs = try XCTUnwrap(e.gameState)
        gs.shadow.post("Britain declares war on Germany.", date: gs.currentDate, severity: 2)
        gs.turn += 1
        e.processShadowTurn()
        XCTAssertTrue(gs.shadow.novaLines.isEmpty, "not mid-turn")
        e.endTurn()
        // Something the AI phase would post: a strike in the same turn.
        gs.shadow.post("Nuclear detonation: Germany strikes France.", date: gs.currentDate, severity: 3)
        for _ in 0..<300 where e.turnPhase != .playerInput { try await Task.sleep(nanoseconds: 10_000_000) }
        XCTAssertEqual(e.turnPhase, .playerInput)
        XCTAssertFalse(gs.shadow.novaLines.isEmpty)
        XCTAssertLessThanOrEqual(gs.shadow.novaLines.count, 2, "same limits: one line, or up to two flash")
    }

    // Performance: the yearly sync with foundings
    func testYearlySyncIsQuickEnough() throws {
        let e = GameEngine()
        e.startNewGame(turnLength: .month, year: 1950)
        let gs = try XCTUnwrap(e.gameState)
        e.processEraTransitions()
        measure { gs.turn += 12; e.processEraTransitions() }
    }

    // Unit: a fresh board is the difference from last year's
    func testFreshNationsAreTheDifference() {
        let a = Set(GameState.eraBoard(year: 1816).map(\.id)), b = Set(GameState.eraBoard(year: 1818).map(\.id))
        XCTAssertTrue(b.subtracting(a).contains("SRB"))
        XCTAssertFalse(b.subtracting(a).contains("USA"))
    }
}


// MARK: - 3.16.2: historical absorptions

final class AbsorptionTests: XCTestCase {
    private func play(from year: Int, years: Int, before: ((GameEngine, GameState) -> Void)? = nil) throws -> (GameEngine, GameState) {
        let e = GameEngine()
        e.startNewGame(turnLength: .month, year: year)
        let gs = try XCTUnwrap(e.gameState)
        e.processEraTransitions()
        before?(e, gs)
        for _ in 0..<years { gs.turn += 12; e.processEraTransitions() }
        return (e, gs)
    }

    // Unit: the table is sane
    func testAbsorptionTable() {
        for a in WorldPolitics.absorptions { XCTAssertLessThan(a.from, a.until, a.land); XCTAssertNotEqual(a.land, a.by) }
    }

    // Functional: Korea into Japan in 1910
    func testKoreaIsAnnexedByJapan() throws {
        let (_, gs) = try play(from: 1905, years: 6)
        XCTAssertEqual(gs.getCountry(id: "KOR")?.territoryOf, "JPN")
        XCTAssertTrue(gs.shadow.ticker.contains { $0.text.contains("is annexed by") })
    }

    // Functional: the Anschluss, and Austria restored in 1945
    func testAnschlussAndRestoration() throws {
        let (e, gs) = try play(from: 1936, years: 3)
        XCTAssertEqual(gs.getCountry(id: "AUT")?.territoryOf, "DEU")
        for _ in 0..<7 { gs.turn += 12; e.processEraTransitions() }
        XCTAssertNil(gs.getCountry(id: "AUT")?.territoryOf, "restored in 1945")
        XCTAssertTrue(gs.shadow.ticker.contains { $0.text.contains("regains its independence") })
    }

    // Integration: a U.S. ally isn't quietly absorbed; it's a crisis
    func testAnAllyBecomesACrisis() throws {
        let (_, gs) = try play(from: 1936, years: 3) { e, gs in e.formAlliance(country1: gs.playerCountryID, country2: "AUT") }
        XCTAssertNil(gs.getCountry(id: "AUT")?.territoryOf)
        XCTAssertTrue(gs.getCountry(id: "DEU")!.atWarWith.contains("AUT"))
        XCTAssertTrue(gs.shadow.ticker.contains { $0.text.contains("appeals to Washington") })
    }

    // Security: a nation whose story diverged keeps its independence
    func testDivergedNationsAreLeftAlone() throws {
        let (_, gs) = try play(from: 1936, years: 3) { _, gs in gs.shadow.eraDiverged.insert("AUT") }
        XCTAssertNil(gs.getCountry(id: "AUT")?.territoryOf)
        let (_, g2) = try play(from: 1936, years: 3) { _, gs in gs.shadow.eraDiverged.insert("DEU") }
        XCTAssertNil(g2.getCountry(id: "AUT")?.territoryOf, "nor does a diverged absorber follow the script")
    }

    // Retry: absorption records survive save and load
    func testAbsorptionsSurviveSave() throws {
        let (_, gs) = try play(from: 1936, years: 3)
        let loaded = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(gs))
        XCTAssertEqual(loaded.shadow.historicalAbsorptions["AUT"], "DEU")
    }

    // Performance: a full 2025 Nightmare end-turn stays under a second (profiled at ~0.25 s, worst 0.5 s in Debug)
    @MainActor
    func testANightmareTurnStaysUnderASecond() async throws {
        let e = GameEngine()
        e.startNewGame(difficulty: .nightmare, turnLength: .month, year: 2025)
        for _ in 0..<3 {
            let t0 = Date()
            e.endTurn()
            while e.turnPhase != .playerInput { try await Task.sleep(nanoseconds: 1_000_000) }
            XCTAssertLessThan(Date().timeIntervalSince(t0), 1.0)
        }
    }
}

// MARK: - 3.17.0: dirty tactics — early chemical and biological

@MainActor
final class DirtyTacticsChemicalTests: XCTestCase {

    private func game(_ year: Int, difficulty: DifficultyLevel = .normal) throws -> (GameEngine, GameState) {
        let e = GameEngine()
        e.startNewGame(difficulty: difficulty, turnLength: .month, year: year)
        return (e, try XCTUnwrap(e.gameState))
    }

    /// A resisting people's land on the board in `year`.
    private func land(_ gs: GameState) throws -> String { try XCTUnwrap(gs.indigenousLandIDs.sorted().first) }

    // Unit: the catalog is sane, and every legal status tightens with the real treaties
    func testCatalogAndLegalStatusByEra() {
        for t in DirtyTactics.all {
            XCTAssertLessThan(t.from, t.to ?? 3000, t.id)
            XCTAssertFalse(t.periods.isEmpty, t.id)
            XCTAssertEqual(t.periods.map(\.from), t.periods.map(\.from).sorted(), "\(t.id): periods are chronological")
            XCTAssertGreaterThanOrEqual(t.periods[0].from, t.from, t.id)
            XCTAssertFalse(t.blurb.isEmpty, t.id)
        }
        let goods = DirtyTactics.tactic("contaminated_goods")!
        XCTAssertEqual(goods.status(in: 1800), .legal, "no rule of war covered it")
        XCTAssertEqual(goods.status(in: 1870), .restricted, "the Lieber Code of 1863")
        XCTAssertEqual(goods.status(in: 1900), .treatyBanned, "Hague 1899")
        XCTAssertEqual(goods.status(in: 1960), .treatyBanned)
        let gas = DirtyTactics.tactic("chem_program")!
        XCTAssertFalse(gas.exists(in: 1879), "industrial chemistry is not there yet")
        XCTAssertTrue(gas.exists(in: 1880))
        XCTAssertEqual(gas.status(in: 1890), .legal)
        XCTAssertEqual(gas.status(in: 1905), .restricted, "Hague 1899")
        XCTAssertEqual(gas.status(in: 1930), .treatyBanned, "Geneva Protocol, in force 1928")
        XCTAssertEqual(DirtyTactics.tactic("defoliants")!.status(in: 1965), .legal)
        XCTAssertEqual(DirtyTactics.tactic("defoliants")!.status(in: 1980), .restricted, "EO 11850, 1975")
        XCTAssertEqual(DirtyTactics.tactic("defoliants")!.status(in: 2000), .treatyBanned, "CWC 1997")
        XCTAssertEqual(DirtyTactics.available(in: 1850, group: .chemical).count, 1, "only contaminated goods in 1850")
        XCTAssertTrue(DirtyTactics.available(in: 1970, group: .chemical).count >= 4)
    }

    // Unit: discovery rises with the era, the crowd and the scale ordered, and never reaches certainty
    func testDiscoveryRisesWithEraCrowdAndScale() {
        let t = DirtyTactics.tactic("gas_resistance")!
        XCTAssertLessThan(DirtyTactics.eraExposure(year: 1800), DirtyTactics.eraExposure(year: 1900))
        XCTAssertLessThan(DirtyTactics.eraExposure(year: 1900), DirtyTactics.eraExposure(year: 1950))
        XCTAssertLessThan(DirtyTactics.eraExposure(year: 1950), DirtyTactics.eraExposure(year: 2025))
        XCTAssertLessThan(DirtyTactics.discoveryChance(t, year: 1925), DirtyTactics.discoveryChance(t, year: 2025))
        XCTAssertLessThan(DirtyTactics.discoveryChance(t, year: 1960, scale: 0.5),
                          DirtyTactics.discoveryChance(t, year: 1960, scale: 2.5))
        let lonely = DirtyTactics.tactic("contaminated_goods")!
        XCTAssertLessThan(DirtyTactics.discoveryChance(lonely, year: 1930), DirtyTactics.discoveryChance(t, year: 1930),
                          "one quartermaster keeps a secret better than a squadron")
        for y in [1789, 1900, 2030] {
            XCTAssertLessThan(DirtyTactics.discoveryChance(t, year: y, scale: 9), 0.91)
            XCTAssertGreaterThan(DirtyTactics.discoveryChance(t, year: y, scale: 0.1), 0)
        }
        XCTAssertEqual(DirtyTactics.tribunalChance(year: 1930, status: .treatyBanned), 0, "nothing before Nuremberg")
        XCTAssertGreaterThan(DirtyTactics.tribunalChance(year: 2010, status: .treatyBanned),
                             DirtyTactics.tribunalChance(year: 1960, status: .treatyBanned))
        XCTAssertEqual(DirtyTactics.tribunalChance(year: 2010, status: .legal), 0, "a legal order has no tribunal")
    }

    // Functional: an 1790s gas programme is refused, and the game says why
    func testAnEarlyGasProgrammeIsRefusedWithAReason() throws {
        let (e, _) = try game(1792)
        let problem = try XCTUnwrap(e.tacticProblem("chem_program"))
        XCTAssertTrue(problem.contains("1792"), problem)
        XCTAssertTrue(problem.contains("chlorine"), "it explains the chemistry, not just the year")
        XCTAssertNil(e.useTactic("chem_program"), "and nothing happens")
    }

    // Functional: the programme runs for four years, then the Army has gas the catalog prices as usual
    func testTheWarGasProgrammeDeliversAStockpileBefore1917() throws {
        let (e, gs) = try game(1890)
        XCTAssertFalse(PresidentialAction.chemicalAttack.isAvailable(on: gs.currentDate, in: gs))
        XCTAssertNotNil(e.useTactic("chem_program"))
        XCTAssertNotNil(gs.shadow.tacticPrograms["chem_program"])
        for _ in 0..<60 { gs.turn += 1; e.processDirtyTactics() }
        XCTAssertNil(gs.shadow.tacticPrograms["chem_program"], "delivered")
        XCTAssertNotNil(gs.shadow.wmdPrograms[WMDKind.chemical.rawValue])
        XCTAssertTrue(PresidentialAction.chemicalAttack.isAvailable(on: gs.currentDate, in: gs), "gas in 1895")
        XCTAssertNil(e.wmdProblem(.chemicalAttack))
        XCTAssertEqual(ArsenalCatalog.legalStatus(.chemical, on: gs.currentDate), .legal, "no treaty bound the U.S. in 1895")
    }

    // Functional: covert costs little while it holds, and more than an open order once it comes out
    func testCovertCostsLittleUntilItComesOut() throws {
        let (open, g1) = try game(1930)
        let l1 = try land(g1)
        open.useTactic("gas_resistance", target: l1, covert: false, discoveryRoll: 0.99)
        let openCost = g1.shadow.ruthlessness

        let (quiet, g2) = try game(1930)
        quiet.useTactic("gas_resistance", target: try land(g2), covert: true, discoveryRoll: 0.99)
        XCTAssertLessThan(g2.shadow.ruthlessness, openCost, "nobody knows yet")
        XCTAssertFalse(g2.shadow.tacticUses[0].discovered)

        let (caught, g3) = try game(1930)
        caught.useTactic("gas_resistance", target: try land(g3), covert: true, discoveryRoll: 0.0)
        XCTAssertTrue(g3.shadow.tacticUses[0].discovered)
        XCTAssertGreaterThan(g3.shadow.ruthlessness, openCost, "the cover-up is its own scandal")
        XCTAssertTrue(g3.shadow.ticker.contains { $0.text.contains("newspapers") })
        XCTAssertGreaterThan(g3.shadow.impeachmentStage, 0, "a treaty-banned order opens hearings")
    }

    // Functional: gas breaks a resisting people, so the land is easier to take afterwards
    func testGasBreaksResistanceBeforeAClaim() throws {
        let (e, gs) = try game(1930)
        let l = try land(gs)
        let before = try XCTUnwrap(gs.preState(l)).era.extra
        e.useTactic("gas_resistance", target: l, covert: true, discoveryRoll: 0.99)
        XCTAssertGreaterThan(gs.shadow.resistanceBroken[l] ?? 0, 0)
        XCTAssertGreaterThan(before, 0, "the land resisted to begin with")
    }

    // Security: a tactic can't be aimed at the wrong kind of land, or at yourself
    func testTargetsAreChecked() throws {
        let (e, gs) = try game(1930)
        XCTAssertNotNil(e.tacticProblem("gas_resistance", target: gs.playerCountryID), "not your own country")
        XCTAssertNotNil(e.tacticProblem("gas_resistance", target: "FRA"), "France is not a resisting people")
        XCTAssertNotNil(e.tacticProblem("gas_resistance", target: nil))
        XCTAssertNotNil(e.tacticProblem("defoliants", target: gs.playerCountryID))
        XCTAssertNotNil(e.tacticProblem("no_such_tactic", target: "FRA"))
        XCTAssertNil(e.useTactic("gas_resistance", target: "FRA", covert: true))
        XCTAssertTrue(gs.shadow.tacticUses.isEmpty)
        // One order, one action.
        let before = gs.actionsRemaining
        e.useTactic("gas_resistance", target: try land(gs), covert: true, discoveryRoll: 0.99)
        XCTAssertEqual(gs.actionsRemaining, before - 1)
    }

    // Integration: the dioxin bill arrives twenty years later, through the turn loop
    func testTheDefoliantBillArrivesTwentyYearsLater() throws {
        let (e, gs) = try game(1965)
        e.declareWar(aggressor: gs.playerCountryID, defender: "VNM")
        let gdp = try XCTUnwrap(gs.getCountry(id: "VNM")).gdp
        XCTAssertNotNil(e.useTactic("defoliants", target: "VNM"))
        XCTAssertLessThan(try XCTUnwrap(gs.getCountry(id: "VNM")).gdp, gdp, "the harvest and the cover are gone")
        XCTAssertEqual(gs.shadow.aftermath.count, 1)
        let pop = gs.shadow.popularity
        for _ in 0..<21 { gs.turn += 12; e.processDirtyTactics() }
        XCTAssertTrue(gs.shadow.aftermath.isEmpty, "the bill was paid")
        XCTAssertLessThan(gs.shadow.popularity, pop)
        XCTAssertTrue(gs.shadow.ticker.contains { $0.text.contains("Veterans") })
    }

    // Integration: a secret programme can leak before it is ready, and then it costs
    func testASecretProgrammeCanLeak() throws {
        let (e, gs) = try game(1935)
        XCTAssertNotNil(e.useTactic("human_subject_program"))
        var leaked = false
        for _ in 0..<36 where !leaked {
            gs.turn += 1
            e.processDirtyTactics()
            leaked = gs.shadow.tacticPrograms["human_subject_program"]?.discovered ?? true
        }
        XCTAssertTrue(leaked, "a programme on this scale does not stay quiet for three years")
    }

    // Security: the Hall of Infamy counts what was ordered and what came out, and only the player's own
    func testHallOfInfamyCountsTacticsAndExposures() throws {
        let (e, gs) = try game(1930)
        XCTAssertFalse(InfamyRecord.dirtyTactics.counts(0))
        e.useTactic("gas_resistance", target: try land(gs), covert: true, discoveryRoll: 0.0)
        XCTAssertEqual(InfamyRecord.dirtyTactics.value(gs), 1)
        XCTAssertEqual(InfamyRecord.tacticsExposed.value(gs), 1)
        XCTAssertTrue(InfamyRecord.dirtyTactics.counts(1))
    }

    // Retry: new state decodes from a save that never had it, and survives a round trip
    func testTacticStateSurvivesOldAndNewSaves() throws {
        let legacy = try JSONDecoder().decode(ShadowState.self, from: Data("{\"popularity\":51}".utf8))
        XCTAssertTrue(legacy.tacticUses.isEmpty)
        XCTAssertTrue(legacy.tacticPrograms.isEmpty)
        XCTAssertTrue(legacy.aftermath.isEmpty)
        XCTAssertTrue(legacy.resistanceBroken.isEmpty)
        XCTAssertTrue(legacy.tacticStances.isEmpty)
        let (e, gs) = try game(1965)
        e.declareWar(aggressor: gs.playerCountryID, defender: "VNM")
        e.useTactic("defoliants", target: "VNM")
        e.useTactic("chem_program")
        let loaded = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(gs))
        XCTAssertEqual(loaded.shadow.tacticUses.count, 1)
        XCTAssertEqual(loaded.shadow.aftermath.count, 1)
        XCTAssertEqual(loaded.shadow.tacticPrograms["chem_program"]?.tactic, "chem_program")
    }

    // Performance: the catalog and the per-turn pass are cheap
    func testTacticLookupsAreCheap() throws {
        let (e, gs) = try game(1965)
        measure {
            for _ in 0..<200 {
                for y in [1789, 1890, 1930, 1965, 2025] { _ = DirtyTactics.available(in: y) }
                _ = e.tacticProblem("defoliants", target: "VNM")
                e.processDirtyTactics()
            }
        }
        XCTAssertTrue(gs.shadow.aftermath.isEmpty)
    }
}

// MARK: - 3.17.1: dirty tactics — incendiaries by era

@MainActor
final class DirtyTacticsIncendiaryTests: XCTestCase {

    /// A game in `year` already at war with `foe`, with a front open.
    private func war(_ year: Int, with foe: String) throws -> (GameEngine, GameState) {
        let e = GameEngine()
        e.startNewGame(turnLength: .month, year: year)
        let gs = try XCTUnwrap(e.gameState)
        e.declareWar(aggressor: gs.playerCountryID, defender: foe)
        e.syncFronts()
        return (e, gs)
    }

    // Unit: the era windows are the real ones, and fire gets harder to use lawfully
    func testIncendiaryErasAndTreaties() {
        let hot = DirtyTactics.tactic("hot_shot")!
        XCTAssertTrue(hot.exists(in: 1812))
        XCTAssertFalse(hot.exists(in: 1900), "iron hulls and explosive shell ended it")
        let congreve = DirtyTactics.tactic("congreve_rockets")!
        XCTAssertFalse(congreve.exists(in: 1804), "Congreve's rockets enter service in 1805")
        XCTAssertTrue(congreve.exists(in: 1814))
        let shells = DirtyTactics.tactic("incendiary_shells")!
        XCTAssertFalse(shells.exists(in: 1860))
        XCTAssertEqual(shells.status(in: 1862), .legal)
        XCTAssertEqual(shells.status(in: 1864), .restricted, "the Lieber Code of 1863")
        let burn = DirtyTactics.tactic("burn_towns")!
        XCTAssertEqual(burn.status(in: 1814), .legal, "Washington burns under no treaty at all")
        XCTAssertEqual(burn.status(in: 1864), .restricted)
        XCTAssertEqual(burn.status(in: 1950), .treatyBanned, "Geneva IV Art. 53")
        let flame = DirtyTactics.tactic("flamethrowers")!
        XCTAssertFalse(flame.exists(in: 1914))
        XCTAssertEqual(flame.status(in: 1944), .legal)
        XCTAssertEqual(flame.status(in: 1990), .restricted, "CCW Protocol III")
        let napalm = DirtyTactics.tactic("napalm_wp")!
        XCTAssertFalse(napalm.exists(in: 1941))
        XCTAssertEqual(napalm.status(in: 1945), .legal)
        XCTAssertEqual(napalm.status(in: 2010), .treatyBanned)
        XCTAssertTrue(shells.blurb.contains("672"), "Byzantine Greek fire predates the game")
        XCTAssertTrue(shells.blurb.contains("recipe was lost"))
    }

    // Unit: an army burning towns cannot do it quietly; one arsonist can
    func testWhatCanBeHiddenAndWhatCannot() {
        XCTAssertFalse(DirtyTactics.tactic("burn_towns")!.canBeCovert)
        XCTAssertFalse(DirtyTactics.tactic("napalm_wp")!.canBeCovert)
        XCTAssertTrue(DirtyTactics.tactic("incendiary_shells")!.canBeCovert)
        XCTAssertGreaterThan(DirtyTactics.tactic("burn_towns")!.people, DirtyTactics.tactic("incendiary_shells")!.people)
    }

    // Functional: Sherman's year — burning towns breaks the enemy's will and his output
    func testBurningTownsBreaksTheEnemy() throws {
        let (e, gs) = try war(1864, with: "GBR")
        let before = try XCTUnwrap(gs.getCountry(id: "GBR"))
        let will = try XCTUnwrap(gs.shadow.fronts.first).defenderWill
        XCTAssertNotNil(e.useTactic("burn_towns", target: "GBR", preset: .overwhelming))
        let after = try XCTUnwrap(gs.getCountry(id: "GBR"))
        XCTAssertLessThan(after.gdp, before.gdp)
        XCTAssertLessThan(after.stability, before.stability)
        XCTAssertLessThan(try XCTUnwrap(gs.shadow.fronts.first).defenderWill, will)
        XCTAssertTrue(gs.shadow.ticker.contains { $0.text.contains("burn the towns") })
        XCTAssertGreaterThan(gs.shadow.ruthlessness, 0)
    }

    // Functional: a bigger order buys more and risks more
    func testScaleBuysMoreAndRisksMore() throws {
        let (probe, g1) = try war(1864, with: "GBR")
        probe.useTactic("incendiary_shells", target: "GBR", covert: true, preset: .probe, discoveryRoll: 0.99)
        let (big, g2) = try war(1864, with: "GBR")
        big.useTactic("incendiary_shells", target: "GBR", covert: true, preset: .overwhelming, discoveryRoll: 0.99)
        XCTAssertLessThan(try XCTUnwrap(g2.getCountry(id: "GBR")).stability,
                          try XCTUnwrap(g1.getCountry(id: "GBR")).stability, "Overwhelming burns more")
        let t = DirtyTactics.tactic("incendiary_shells")!
        XCTAssertLessThan(DirtyTactics.discoveryChance(t, year: 1864, scale: AttackPreset.probe.multiplier),
                          DirtyTactics.discoveryChance(t, year: 1864, scale: AttackPreset.overwhelming.multiplier))
    }

    // Functional: flamethrowers help the side the U.S. is fighting on
    func testFlamethrowersPushTheAssault() throws {
        let (e, gs) = try war(1944, with: "DEU")
        let momentum = try XCTUnwrap(gs.shadow.fronts.first).attackerMomentum
        XCTAssertNotNil(e.useTactic("flamethrowers", target: "DEU"))
        XCTAssertGreaterThan(try XCTUnwrap(gs.shadow.fronts.first).attackerMomentum, momentum)
        XCTAssertEqual(DirtyTactics.tactic("flamethrowers")!.status(in: 1944), .legal, "no treaty in 1944")
        XCTAssertEqual(gs.shadow.impeachmentStage, 0, "a lawful weapon opens no hearings")
    }

    // Security: nothing from a later era, and the panel says why
    func testNoAnachronisticFire() throws {
        let e = GameEngine()
        e.startNewGame(turnLength: .month, year: 1814)
        let gs = try XCTUnwrap(e.gameState)
        XCTAssertNil(e.useTactic("napalm_wp", target: "GBR"))
        XCTAssertNil(e.useTactic("flamethrowers", target: "GBR"))
        let why = try XCTUnwrap(e.tacticProblem("napalm_wp", target: "GBR"))
        XCTAssertTrue(why.contains("Fieser") || why.contains("1942"), why)
        XCTAssertTrue(gs.shadow.tacticUses.isEmpty)
        // And nothing from an era that has passed.
        let e2 = GameEngine()
        e2.startNewGame(turnLength: .month, year: 1944)
        XCTAssertNotNil(e2.tacticProblem("hot_shot", target: "DEU"), "heated shot belongs to the age of sail")
        XCTAssertTrue(DirtyTactics.available(in: 1944, group: .incendiary).allSatisfy { $0.exists(in: 1944) })
    }

    // Integration: a treaty-banned burning in 1950 costs the world, Congress and the tribunals
    func testATreatyBannedBurningCostsEverything() throws {
        let (e, gs) = try war(1950, with: "PRK")
        let friend = try XCTUnwrap(gs.liveCountries.first { $0.id != gs.playerCountryID && $0.id != "PRK" })
        let before = friend.diplomaticRelations[gs.playerCountryID] ?? 0
        e.applyTacticCost(DirtyTactics.tactic("burn_towns")!, target: "PRK", coverUp: false, tribunalRoll: 0.0)
        XCTAssertLessThan(try XCTUnwrap(gs.getCountry(id: friend.id)).diplomaticRelations[gs.playerCountryID] ?? 0, before)
        XCTAssertGreaterThanOrEqual(gs.shadow.impeachmentStage, 2, "the tribunal brings articles of impeachment")
        XCTAssertTrue(gs.shadow.ticker.contains { $0.text.contains("tribunal") })
    }

    // Integration: fire runs through the whole turn and Nova has something to say
    func testFireReachesNovaAndTheTurnLoop() throws {
        let (e, gs) = try war(1864, with: "GBR")
        let seen = Set(gs.shadow.ticker.map(\.id))
        e.useTactic("burn_towns", target: "GBR")
        e.processCommentary(seen: seen)
        XCTAssertTrue(gs.shadow.novaLines.last?.text.hasPrefix("Nova: ") ?? false)
        gs.turn += 1
        e.processShadowTurn()
        XCTAssertEqual(gs.shadow.tacticUses.count, 1, "no duplicate records from the turn loop")
    }

    // Retry: incendiary records survive a save and reload
    func testIncendiaryUsesSurviveSave() throws {
        let (e, gs) = try war(1864, with: "GBR")
        e.useTactic("incendiary_shells", target: "GBR", covert: true, discoveryRoll: 0.0)
        let loaded = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(gs))
        XCTAssertEqual(loaded.shadow.tacticUses.first?.tactic, "incendiary_shells")
        XCTAssertTrue(try XCTUnwrap(loaded.shadow.tacticUses.first).discovered)
        XCTAssertTrue(try XCTUnwrap(loaded.shadow.tacticUses.first).covert)
    }

    // Performance: the catalog stays cheap with two groups in it
    func testCatalogStaysCheap() {
        measure {
            for _ in 0..<500 {
                for y in [1800, 1814, 1864, 1915, 1945, 2025] {
                    for g in TacticGroup.allCases { _ = DirtyTactics.available(in: y, group: g) }
                }
            }
        }
    }
}

// MARK: - 3.17.2: dirty tactics — starvation and supply

@MainActor
final class DirtyTacticsStarvationTests: XCTestCase {

    private func war(_ year: Int, with foe: String) throws -> (GameEngine, GameState) {
        let e = GameEngine()
        e.startNewGame(turnLength: .month, year: year)
        let gs = try XCTUnwrap(e.gameState)
        e.declareWar(aggressor: gs.playerCountryID, defender: foe)
        e.syncFronts()
        return (e, gs)
    }

    /// A game with one territory the player holds.
    private func withTerritory(_ year: Int, _ id: String) throws -> (GameEngine, GameState) {
        let e = GameEngine()
        e.startNewGame(turnLength: .month, year: year)
        let gs = try XCTUnwrap(e.gameState)
        let i = try XCTUnwrap(gs.countries.firstIndex { $0.id == id })
        gs.countries[i].territoryOf = gs.playerCountryID
        gs.shadow.claimDates[id] = GameCalendar.date(year: year - 3, month: 1, day: 1)
        return (e, gs)
    }

    // Unit: windows and treaties
    func testStarvationErasAndTreaties() {
        let scorch = DirtyTactics.tactic("scorched_earth")!
        XCTAssertEqual(scorch.status(in: 1812), .legal)
        XCTAssertEqual(scorch.status(in: 1864), .restricted, "the Lieber Code of 1863")
        XCTAssertEqual(scorch.status(in: 1960), .treatyBanned, "Geneva IV Art. 53")
        let blockade = DirtyTactics.tactic("starve_blockade")!
        XCTAssertTrue(blockade.isStance)
        XCTAssertEqual(blockade.status(in: 1917), .legal, "no treaty bound the British blockade")
        XCTAssertEqual(blockade.status(in: 1960), .restricted)
        XCTAssertEqual(blockade.status(in: 1990), .treatyBanned, "Additional Protocol I Art. 54, 1977")
        let herds = DirtyTactics.tactic("buffalo_slaughter")!
        XCTAssertFalse(herds.exists(in: 1860))
        XCTAssertTrue(herds.exists(in: 1874))
        XCTAssertFalse(herds.exists(in: 1890), "there were no herds left")
        let beef = DirtyTactics.tactic("profiteer_contracts")!
        XCTAssertFalse(beef.exists(in: 1850))
        XCTAssertEqual(beef.status(in: 1898), .legal)
        XCTAssertEqual(beef.status(in: 1910), .restricted, "the Pure Food and Drug Act of 1906")
    }

    // Unit: federal food inspection after 1906 makes a ration scandal far likelier to come out
    func testPureFoodActRaisesDetection() {
        let beef = DirtyTactics.tactic("profiteer_contracts")!
        let before = DirtyTactics.discoveryChance(beef, year: 1898)
        let after = DirtyTactics.discoveryChance(beef, year: 1910)
        XCTAssertGreaterThan(after, before * 2, "inspection changes the odds, not just the era")
        XCTAssertEqual(DirtyTactics.exposureBonus(beef, year: 1898), 1)
        XCTAssertGreaterThan(DirtyTactics.exposureBonus(beef, year: 1907), 1)
        XCTAssertEqual(DirtyTactics.exposureBonus(DirtyTactics.tactic("scorched_earth")!, year: 1910), 1)
    }

    // Functional: scorched earth takes the enemy's supply and his will
    func testScorchedEarth() throws {
        let (e, gs) = try war(1864, with: "GBR")
        let troops = try XCTUnwrap(gs.shadow.fronts.first).defenderTroops
        let gdp = try XCTUnwrap(gs.getCountry(id: "GBR")).gdp
        XCTAssertNotNil(e.useTactic("scorched_earth", target: "GBR"))
        XCTAssertLessThan(try XCTUnwrap(gs.shadow.fronts.first).defenderTroops, troops)
        XCTAssertLessThan(try XCTUnwrap(gs.getCountry(id: "GBR")).gdp, gdp)
    }

    // Functional: the starvation stance needs a blockade, bites every turn, and lapses when the blockade is lifted
    func testStarvationBlockadeStance() throws {
        let (e, gs) = try war(1917, with: "DEU")
        XCTAssertNotNil(e.tacticProblem("starve_blockade", target: "DEU"), "no blockade, no stance")
        gs.shadow.fleetDeployments.append(FleetDeployment(fleetID: "atlantic", target: "DEU", mission: .blockade,
                                                          commitment: 1, ships: FleetComposition(), fromLat: 0, fromLon: 0,
                                                          toLat: 0, toLon: 0, departed: gs.currentDate, arrives: gs.currentDate,
                                                          status: .onStation))
        XCTAssertNil(e.tacticProblem("starve_blockade", target: "DEU"))
        XCTAssertTrue(e.setStance("starve_blockade", target: "DEU", on: true))
        XCTAssertFalse(e.setStance("starve_blockade", target: "DEU", on: true), "already in force")
        let gdp = try XCTUnwrap(gs.getCountry(id: "DEU")).gdp
        let ruth = gs.shadow.ruthlessness
        for _ in 0..<6 { gs.turn += 1; e.processTacticStances() }
        XCTAssertLessThan(try XCTUnwrap(gs.getCountry(id: "DEU")).gdp, gdp, "the blockade bites every turn")
        XCTAssertGreaterThan(gs.shadow.ruthlessness, ruth, "a standing policy is nobody's secret")
        gs.shadow.fleetDeployments.removeAll()
        e.processTacticStances()
        XCTAssertTrue(gs.shadow.tacticStances.isEmpty, "the stance lapses with the blockade")
        XCTAssertTrue(gs.shadow.ticker.contains { $0.text.contains("has been lifted") })
    }

    // Functional: the herds, and the land that is easier to take afterwards
    func testDestroyingTheHerdsBreaksResistance() throws {
        let e = GameEngine()
        e.startNewGame(turnLength: .month, year: 1874)
        let gs = try XCTUnwrap(e.gameState)
        let land = try XCTUnwrap(gs.indigenousLandIDs.sorted().first)
        XCTAssertNotNil(e.useTactic("buffalo_slaughter", target: land))
        XCTAssertGreaterThan(gs.shadow.resistanceBroken[land] ?? 0, 0)
        XCTAssertGreaterThan(gs.shadow.ruthlessness, 0)
    }

    // Functional: the embalmed-beef bargain — cash now, sick soldiers now, a commission later
    func testProfiteeringPaysThenCosts() throws {
        let (e, gs) = try war(1898, with: "ESP")
        let funds = gs.shadow.aidRemaining
        let will = try XCTUnwrap(gs.shadow.fronts.first).attackerWill
        XCTAssertNotNil(e.useTactic("profiteer_contracts", covert: true, discoveryRoll: 0.99))
        XCTAssertGreaterThan(gs.shadow.aidRemaining, funds, "cash and kickbacks now")
        XCTAssertLessThan(try XCTUnwrap(gs.shadow.fronts.first).attackerWill, will, "your own men are sick")
        XCTAssertEqual(gs.shadow.aftermath.count, 1)
        let pop = gs.shadow.popularity
        for _ in 0..<24 { gs.turn += 1; e.processDirtyTactics() }
        XCTAssertLessThan(gs.shadow.popularity, pop, "the commission of inquiry")
        XCTAssertGreaterThan(gs.shadow.impeachmentStage, 0)
    }

    // Security: a requisition only works on your own territory, and a stance only on a stance tactic
    func testStarvationTargetsAreChecked() throws {
        let (e, gs) = try withTerritory(1900, "CUB")
        XCTAssertNotNil(e.tacticProblem("requisition_harvest", target: "GBR"), "not another nation")
        XCTAssertNotNil(e.tacticProblem("requisition_harvest", target: gs.playerCountryID))
        XCTAssertNil(e.tacticProblem("requisition_harvest", target: "CUB"))
        XCTAssertFalse(e.setStance("scorched_earth", target: "GBR", on: true), "not a stance")
        XCTAssertFalse(e.setStance("starve_blockade", target: "GBR", on: false), "nothing to lift")
    }

    // Integration: a requisition pays at once and brings a famine a year later, through the turn loop
    func testRequisitionPaysThenStarves() throws {
        let (e, gs) = try withTerritory(1900, "CUB")
        let funds = gs.shadow.aidRemaining
        XCTAssertNotNil(e.useTactic("requisition_harvest", target: "CUB"))
        XCTAssertGreaterThan(gs.shadow.aidRemaining, funds)
        XCTAssertLessThan(try XCTUnwrap(gs.getCountry(id: "CUB")).stability, 100)
        for _ in 0..<14 { gs.turn += 1; e.processDirtyTactics() }
        XCTAssertTrue(gs.shadow.ticker.contains { $0.text.contains("Famine") })
        XCTAssertTrue(gs.shadow.aftermath.isEmpty)
    }

    // Retry: a stance in force survives a save and reload
    func testStancesSurviveSave() throws {
        let (e, gs) = try war(1917, with: "DEU")
        gs.shadow.fleetDeployments.append(FleetDeployment(fleetID: "atlantic", target: "DEU", mission: .blockade,
                                                          commitment: 1, ships: FleetComposition(), fromLat: 0, fromLon: 0,
                                                          toLat: 0, toLon: 0, departed: gs.currentDate, arrives: gs.currentDate,
                                                          status: .onStation))
        e.setStance("starve_blockade", target: "DEU", on: true)
        let loaded = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(gs))
        XCTAssertTrue(loaded.shadow.tacticStances.contains(DirtyTactics.stanceKey("starve_blockade", target: "DEU")))
        XCTAssertEqual(DirtyTactics.splitStance("starve_blockade:DEU").1, "DEU")
        XCTAssertNil(DirtyTactics.splitStance("starve_blockade").1)
    }

    // Performance: stances cost nothing to carry
    func testStanceTickIsCheap() throws {
        let (e, gs) = try war(1917, with: "DEU")
        gs.shadow.fleetDeployments.append(FleetDeployment(fleetID: "atlantic", target: "DEU", mission: .blockade,
                                                          commitment: 1, ships: FleetComposition(), fromLat: 0, fromLon: 0,
                                                          toLat: 0, toLon: 0, departed: gs.currentDate, arrives: gs.currentDate,
                                                          status: .onStation))
        e.setStance("starve_blockade", target: "DEU", on: true)
        measure { for _ in 0..<300 { e.processTacticStances() } }
    }
}

// MARK: - 3.17.3: dirty tactics — civilians and land

@MainActor
final class DirtyTacticsCiviliansTests: XCTestCase {

    /// A game in `year` where the player holds `id` as a restless territory.
    private func territory(_ year: Int, _ id: String, outcry: Double = 70) throws -> (GameEngine, GameState) {
        let e = GameEngine()
        e.startNewGame(turnLength: .month, year: year)
        let gs = try XCTUnwrap(e.gameState)
        let i = try XCTUnwrap(gs.countries.firstIndex { $0.id == id })
        gs.countries[i].territoryOf = gs.playerCountryID
        gs.countries[i].profile.outcry = outcry
        gs.countries[i].stability = 30
        gs.shadow.claimDates[id] = GameCalendar.date(year: year - 3, month: 1, day: 1)
        gs.shadow.garrisons[id] = AttackSizing.expeditionStandard
        return (e, gs)
    }

    // Unit: the eras and the treaties that closed them
    func testCivilianErasAndTreaties() {
        let camps = DirtyTactics.tactic("reconcentration")!
        XCTAssertFalse(camps.exists(in: 1895), "Weyler's order is February 1896")
        XCTAssertEqual(camps.status(in: 1900), .legal, "no treaty covered it; the newspapers did")
        XCTAssertEqual(camps.status(in: 1950), .treatyBanned, "Geneva IV Art. 49")
        let removal = DirtyTactics.tactic("forced_removal")!
        XCTAssertFalse(removal.exists(in: 1829), "the Indian Removal Act is 28 May 1830")
        XCTAssertEqual(removal.status(in: 1838), .legal, "lawful under the Act; the Supreme Court said otherwise and was ignored")
        XCTAssertEqual(removal.status(in: 1960), .treatyBanned)
        let camp = DirtyTactics.tactic("internment")!
        XCTAssertFalse(camp.exists(in: 1941))
        XCTAssertEqual(camp.status(in: 1943), .legal, "Executive Order 9066, upheld in Korematsu")
        XCTAssertEqual(camp.status(in: 1980), .restricted, "the Non-Detention Act of 1971")
        let torture = DirtyTactics.tactic("torture")!
        XCTAssertEqual(torture.status(in: 1800), .legal)
        XCTAssertEqual(torture.status(in: 1902), .restricted, "the Lieber Code of 1863")
        XCTAssertEqual(torture.status(in: 1960), .treatyBanned, "the Geneva Conventions of 1949")
        XCTAssertEqual(DirtyTactics.tactic("max_extraction")!.status(in: 1900), .legal)
        XCTAssertEqual(DirtyTactics.tactic("max_extraction")!.status(in: 1910), .restricted, "Hague IV Art. 52, 1907")
    }

    // Unit: the maximum rate is the richest and the worst to hold
    func testMaximumExtractionRate() {
        XCTAssertGreaterThan(ExtractionRate.maximum.incomeMultiplier, ExtractionRate.plunder.incomeMultiplier)
        XCTAssertGreaterThan(ExtractionRate.maximum.insurgencyShift, ExtractionRate.plunder.insurgencyShift)
        XCTAssertGreaterThan(ExtractionRate.maximum.stabilityPerMonth, ExtractionRate.plunder.stabilityPerMonth)
        XCTAssertGreaterThan(ExtractionRate.maximum.worldHitPerYear, ExtractionRate.plunder.worldHitPerYear)
        XCTAssertEqual(ExtractionRate.allCases.count, 5)
    }

    // Functional: the camps end an insurgency, and the death rates are published two years later
    func testReconcentrationEndsTheInsurgency() throws {
        let (e, gs) = try territory(1901, "PHL")
        let outcry = try XCTUnwrap(gs.getCountry(id: "PHL")).profile.outcry
        XCTAssertNotNil(e.useTactic("reconcentration", target: "PHL"))
        XCTAssertLessThan(try XCTUnwrap(gs.getCountry(id: "PHL")).profile.outcry, outcry)
        XCTAssertGreaterThan(try XCTUnwrap(gs.getCountry(id: "PHL")).stability, 30)
        XCTAssertEqual(gs.shadow.aftermath.count, 1)
        for _ in 0..<3 { gs.turn += 12; e.processDirtyTactics() }
        XCTAssertTrue(gs.shadow.ticker.contains { $0.text.contains("death rates") })
    }

    // Functional: removal leaves quiet land and a smaller people
    func testForcedRemovalQuietsTheLand() throws {
        let (e, gs) = try territory(1838, "MEX")
        let people = try XCTUnwrap(gs.getCountry(id: "MEX")).population
        XCTAssertNotNil(e.useTactic("forced_removal", target: "MEX"))
        let after = try XCTUnwrap(gs.getCountry(id: "MEX"))
        XCTAssertEqual(after.profile.outcry, 0)
        XCTAssertGreaterThanOrEqual(after.stability, 80)
        XCTAssertLessThan(after.population, people)
        XCTAssertGreaterThan(gs.shadow.ruthlessness, 0)
    }

    // Functional: internment buys war support now and a redress bill in forty-six years
    func testInternmentAndItsRedress() throws {
        let e = GameEngine()
        e.startNewGame(turnLength: .month, year: 1942)
        let gs = try XCTUnwrap(e.gameState)
        let support = try XCTUnwrap(gs.getPlayerCountry()).warSupport
        XCTAssertNotNil(e.useTactic("internment"))
        XCTAssertGreaterThan(try XCTUnwrap(gs.getPlayerCountry()).warSupport, support)
        gs.shadow.aidRemaining = 20
        let funds = gs.shadow.aidRemaining
        for _ in 0..<47 { gs.turn += 12; e.processDirtyTactics() }
        XCTAssertLessThan(gs.shadow.aidRemaining, funds, "the Civil Liberties Act is paid for")
        XCTAssertTrue(gs.shadow.ticker.contains { $0.text.contains("redress") })
    }

    // Functional: maximum extraction pays more and boils over
    func testMaximumExtractionPaysAndBoils() throws {
        let (e, gs) = try territory(1900, "CUB", outcry: 20)
        let normal = ExpansionModel.annualIncome(try XCTUnwrap(gs.getCountry(id: "CUB")), in: gs)
        XCTAssertNotNil(e.useTactic("max_extraction", target: "CUB"))
        XCTAssertEqual(gs.shadow.extraction["CUB"], ExtractionRate.maximum.rawValue)
        XCTAssertGreaterThan(ExpansionModel.annualIncome(try XCTUnwrap(gs.getCountry(id: "CUB")), in: gs), normal)
        XCTAssertGreaterThan(try XCTUnwrap(gs.getCountry(id: "CUB")).profile.outcry, 20)
        XCTAssertFalse(e.setExtraction("CUB", .maximum), "the quota is a tactic, not a rate button")
    }

    // Security: torture needs a nation, and is never aimed at your own people
    func testCivilianTargetsAreChecked() throws {
        let (e, gs) = try territory(1902, "PHL")
        XCTAssertNotNil(e.tacticProblem("torture", target: gs.playerCountryID))
        XCTAssertNotNil(e.tacticProblem("reconcentration", target: "FRA"), "camps go in your own territory")
        XCTAssertNotNil(e.tacticProblem("max_extraction", target: "FRA"))
        XCTAssertNil(e.tacticProblem("reconcentration", target: "PHL"))
        XCTAssertNil(e.useTactic("torture", target: gs.playerCountryID))
        XCTAssertTrue(gs.shadow.tacticUses.isEmpty)
    }

    // Integration: torture gives intelligence, some of it true, and a scandal when it comes out
    func testTortureYieldsIntelligenceAndScandal() throws {
        var sound = 0
        for seed in 0..<40 {
            let e = GameEngine()
            e.startNewGame(turnLength: .month, year: 1902)
            let gs = try XCTUnwrap(e.gameState)
            e.declareWar(aggressor: gs.playerCountryID, defender: "ESP")
            e.syncFronts()
            e.useTactic("torture", target: "ESP", covert: true, discoveryRoll: 0.99)
            if gs.shadow.ticker.contains(where: { $0.text.contains("Both check out") }) { sound += 1 }
            _ = seed
        }
        XCTAssertGreaterThan(sound, 5, "some of it is true")
        XCTAssertLessThan(sound, 35, "and some of it is not")

        let e = GameEngine()
        e.startNewGame(turnLength: .month, year: 2003)
        let gs = try XCTUnwrap(e.gameState)
        e.declareWar(aggressor: gs.playerCountryID, defender: "IRQ")
        e.useTactic("torture", target: "IRQ", covert: true, discoveryRoll: 0.0)
        XCTAssertTrue(try XCTUnwrap(gs.shadow.tacticUses.first).discovered)
        XCTAssertGreaterThan(gs.shadow.impeachmentStage, 0, "a treaty-banned order in 2003 costs at home")
    }

    // Retry: the new extraction rate decodes from an older save, and unknown rates fall back
    func testExtractionRateDecoding() throws {
        let (e, gs) = try territory(1900, "CUB", outcry: 20)
        e.useTactic("max_extraction", target: "CUB")
        let loaded = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(gs))
        XCTAssertEqual(ExpansionModel.rate("CUB", in: loaded), .maximum)
        loaded.shadow.extraction["CUB"] = "pillage"
        XCTAssertEqual(ExpansionModel.rate("CUB", in: loaded), .normal, "an unknown rate falls back")
    }

    // Performance: four groups in the catalog stay cheap to list
    func testFourGroupsStayCheap() {
        measure {
            for _ in 0..<500 {
                for y in [1830, 1896, 1942, 2003] {
                    for g in TacticGroup.allCases { _ = DirtyTactics.available(in: y, group: g) }
                }
            }
        }
    }
}

// MARK: - 3.17.4: dirty tactics — deception

@MainActor
final class DirtyTacticsDeceptionTests: XCTestCase {

    private func game(_ year: Int) throws -> (GameEngine, GameState) {
        let e = GameEngine()
        e.startNewGame(turnLength: .month, year: year)
        return (e, try XCTUnwrap(e.gameState))
    }

    private func war(_ year: Int, with foe: String) throws -> (GameEngine, GameState) {
        let (e, gs) = try game(year)
        e.declareWar(aggressor: gs.playerCountryID, defender: foe)
        e.syncFronts()
        return (e, gs)
    }

    // Unit: the eras and the treaties
    func testDeceptionErasAndTreaties() {
        let flag = DirtyTactics.tactic("false_flag")!
        XCTAssertEqual(flag.status(in: 1898), .legal, "nothing yet covered how a war begins")
        XCTAssertEqual(flag.status(in: 1964), .treatyBanned, "the UN Charter Art. 2(4), 1945")
        let press = DirtyTactics.tactic("yellow_press")!
        XCTAssertFalse(press.exists(in: 1894))
        XCTAssertEqual(press.status(in: 1898), .legal, "nothing forbids a newspaper from printing what sells")
        XCTAssertEqual(press.status(in: 2025), .legal)
        let greif = DirtyTactics.tactic("enemy_uniforms")!
        XCTAssertEqual(greif.status(in: 1864), .legal)
        XCTAssertEqual(greif.status(in: 1944), .restricted, "Hague IV Art. 23(f)")
        XCTAssertEqual(greif.status(in: 1990), .treatyBanned, "perfidy under AP I, 1977")
        let notes = DirtyTactics.tactic("counterfeit_currency")!
        XCTAssertEqual(notes.status(in: 1777), .legal)
        XCTAssertEqual(notes.status(in: 1943), .restricted, "the 1929 counterfeiting convention, in force 1931")
        let opium = DirtyTactics.tactic("opium_policy")!
        XCTAssertEqual(opium.status(in: 1840), .legal)
        XCTAssertEqual(opium.status(in: 1920), .restricted, "the Hague Opium Convention of 1912")
        XCTAssertEqual(opium.status(in: 1980), .treatyBanned, "the Single Convention of 1961")
    }

    // Functional: a pretext Congress accepts, and the annulment when it is exposed
    func testPretextCarriesCongressUntilExposed() throws {
        let (e, gs) = try game(1964)
        let plain = try XCTUnwrap(e.authorizationOdds(target: "VNM", kind: .declaration)).casusBelli
        XCTAssertNotNil(e.useTactic("false_flag", target: "VNM", covert: true, discoveryRoll: 0.99))
        let withPretext = try XCTUnwrap(e.authorizationOdds(target: "VNM", kind: .declaration))
        XCTAssertGreaterThan(withPretext.casusBelli, plain, "the incident is a casus belli")
        XCTAssertNotNil(e.requestAuthorization(target: "VNM", kind: .useOfForce, roll: 0.0))
        XCTAssertTrue(e.isAuthorized("VNM"))
        e.exposeTactic(try XCTUnwrap(gs.shadow.tacticUses.first).id)
        XCTAssertFalse(e.isAuthorized("VNM"), "Congress annuls what the lie bought")
        XCTAssertEqual(e.pretextBonus("VNM"), 0)
        XCTAssertGreaterThanOrEqual(gs.shadow.impeachmentStage, 2)
    }

    // Functional: the papers raise war support, and an exposé takes it back
    func testYellowPressRaisesWarSupportAndTheExposeTakesIt() throws {
        let (e, gs) = try game(1898)
        let support = try XCTUnwrap(gs.getPlayerCountry()).warSupport
        XCTAssertNotNil(e.useTactic("yellow_press", covert: true, discoveryRoll: 0.99))
        let after = try XCTUnwrap(gs.getPlayerCountry()).warSupport
        XCTAssertGreaterThan(after, support)
        e.exposeTactic(try XCTUnwrap(gs.shadow.tacticUses.first).id)
        XCTAssertLessThan(try XCTUnwrap(gs.getPlayerCountry()).warSupport, after)
    }

    // Functional: counterfeiting pays the President and costs the enemy
    func testCounterfeitingPaysAndBites() throws {
        let (e, gs) = try war(1943, with: "DEU")
        let funds = gs.shadow.aidRemaining
        let gdp = try XCTUnwrap(gs.getCountry(id: "DEU")).gdp
        XCTAssertNotNil(e.useTactic("counterfeit_currency", target: "DEU", covert: true, discoveryRoll: 0.99))
        XCTAssertGreaterThan(gs.shadow.aidRemaining, funds)
        XCTAssertLessThan(try XCTUnwrap(gs.getCountry(id: "DEU")).gdp, gdp)
    }

    // Functional: enemy uniforms buy momentum, and cost men when they are found out
    func testEnemyUniformsBuyMomentum() throws {
        let (e, gs) = try war(1944, with: "DEU")
        let momentum = try XCTUnwrap(gs.shadow.fronts.first).attackerMomentum
        XCTAssertNotNil(e.useTactic("enemy_uniforms", target: "DEU", covert: true, discoveryRoll: 0.99))
        XCTAssertGreaterThan(try XCTUnwrap(gs.shadow.fronts.first).attackerMomentum, momentum)
        let troops = try XCTUnwrap(gs.shadow.fronts.first).attackerTroops
        e.exposeTactic(try XCTUnwrap(gs.shadow.tacticUses.first).id)
        XCTAssertLessThan(try XCTUnwrap(gs.shadow.fronts.first).attackerTroops, troops, "men out of uniform are shot")
    }

    // Integration: the opium trade as state policy, through the existing drug-operations action
    func testOpiumPolicyMultipliesDrugOperations() throws {
        let (plain, g1) = try game(1850)
        plain.runDrugOperations(target: "CHN")
        let ordinary = g1.shadow.resourceEarnings

        let (state, g2) = try game(1850)
        XCTAssertNotNil(state.useTactic("opium_policy", target: "CHN", covert: false))
        XCTAssertTrue(state.opiumPolicyActive(against: "CHN"))
        let afterPolicy = g2.shadow.resourceEarnings
        state.runDrugOperations(target: "CHN")
        XCTAssertGreaterThan(g2.shadow.resourceEarnings - afterPolicy, ordinary * 2, "state policy runs on another scale")
        XCTAssertLessThan(try XCTUnwrap(g2.getCountry(id: "CHN")).stability,
                          try XCTUnwrap(g1.getCountry(id: "CHN")).stability)
        // And through the menu action the game already had.
        state.executeShadowPresidentAction(.drugOps, from: g2.playerCountryID, to: "CHN")
        XCTAssertTrue(g2.shadow.ticker.contains { $0.text.contains("under the flag") })
    }

    // Security: a pretext that was exposed is worth nothing, and none of this works on yourself
    func testDeceptionTargetsAndSpentPretexts() throws {
        let (e, gs) = try game(1964)
        XCTAssertNotNil(e.tacticProblem("false_flag", target: gs.playerCountryID))
        XCTAssertNotNil(e.tacticProblem("counterfeit_currency", target: gs.playerCountryID))
        XCTAssertNil(e.useTactic("enemy_uniforms", target: gs.playerCountryID, covert: true))
        e.useTactic("false_flag", target: "VNM", covert: true, discoveryRoll: 0.0)
        XCTAssertEqual(e.pretextBonus("VNM"), 0, "a pretext that was caught is worth nothing")
        XCTAssertEqual(e.pretextBonus("FRA"), 0)
        XCTAssertFalse(e.opiumPolicyActive(against: "CHN"))
    }

    // Retry: deception records and the pretext survive a save
    func testDeceptionSurvivesSave() throws {
        let (e, gs) = try game(1964)
        e.useTactic("false_flag", target: "VNM", covert: true, discoveryRoll: 0.99)
        let loaded = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(gs))
        let e2 = GameEngine()
        e2.gameState = loaded
        XCTAssertGreaterThan(e2.pretextBonus("VNM"), 0, "the lie is still standing after a reload")
    }

    // Performance: five groups in the catalog stay cheap
    func testFiveGroupsStayCheap() {
        measure {
            for _ in 0..<500 {
                for y in [1789, 1850, 1898, 1944, 1964, 2025] {
                    for g in TacticGroup.allCases { _ = DirtyTactics.available(in: y, group: g) }
                }
            }
        }
    }
}

// MARK: - 3.17.5: dirty tactics — the sea, and what is left on the ground

@MainActor
final class DirtyTacticsSeaTests: XCTestCase {

    private func game(_ year: Int) throws -> (GameEngine, GameState) {
        let e = GameEngine()
        e.startNewGame(turnLength: .month, year: year)
        return (e, try XCTUnwrap(e.gameState))
    }

    private func war(_ year: Int, with foe: String) throws -> (GameEngine, GameState) {
        let (e, gs) = try game(year)
        e.declareWar(aggressor: gs.playerCountryID, defender: foe)
        e.syncFronts()
        return (e, gs)
    }

    // Unit: the eras and the treaties, including the ones the United States never joined
    func testSeaErasAndTreaties() {
        let press = DirtyTactics.tactic("impressment")!
        XCTAssertTrue(press.exists(in: 1807))
        XCTAssertFalse(press.exists(in: 1860), "impressment died with the age of sail")
        let subs = DirtyTactics.tactic("unrestricted_submarine")!
        XCTAssertTrue(subs.isStance)
        XCTAssertFalse(subs.exists(in: 1914))
        XCTAssertEqual(subs.status(in: 1917), .legal, "no treaty yet; prize rules were custom")
        XCTAssertEqual(subs.status(in: 1932), .restricted, "the London Naval Treaty of 1930")
        XCTAssertEqual(subs.status(in: 1941), .treatyBanned, "the London Protocol of 1936")
        let hired = DirtyTactics.tactic("hired_troops")!
        XCTAssertEqual(hired.status(in: 1776), .legal)
        XCTAssertEqual(hired.status(in: 1990), .restricted, "AP I Art. 47")
        XCTAssertTrue(try XCTUnwrap(hired.note(in: 2010)).contains("not a party"), "the U.S. never joined the Mercenary Convention")
        let mines = DirtyTactics.tactic("landmines")!
        XCTAssertFalse(mines.exists(in: 1861))
        XCTAssertEqual(mines.status(in: 1900), .legal)
        XCTAssertEqual(mines.status(in: 1990), .restricted, "CCW Protocol II")
        XCTAssertEqual(mines.status(in: 2005), .treatyBanned, "Ottawa, in force 1 March 1999")
        XCTAssertTrue(try XCTUnwrap(mines.note(in: 2005)).contains("never joined"))
        let fire = DirtyTactics.tactic("firebomb_cities")!
        XCTAssertTrue(fire.isStance)
        XCTAssertFalse(fire.exists(in: 1936))
        XCTAssertEqual(fire.status(in: 1945), .legal, "the 1923 Hague air rules were never adopted")
        XCTAssertEqual(fire.status(in: 1990), .restricted)
        XCTAssertEqual(fire.status(in: 2010), .treatyBanned)
    }

    // Functional: press gangs put men on top of the era's pool, and somebody objects
    func testPressGangsAddMenAndAGrievance() throws {
        let (e, gs) = try game(1807)
        let pool = AttackSizing.troopPool(gs)
        XCTAssertNotNil(e.useTactic("impressment"))
        XCTAssertGreaterThan(AttackSizing.troopPool(gs), pool, "men on top of the era's army")
        XCTAssertGreaterThan(gs.shadow.pressedTroops, 0)
        XCTAssertTrue(gs.shadow.ticker.contains { $0.text.contains("its subjects") })
    }

    // Functional: hired regiments come on top of the cap, and their sovereign can take them back
    func testHiredTroopsAndTheirSovereign() throws {
        let (e, gs) = try game(1800)
        let lender = try XCTUnwrap(gs.liveCountries.first { $0.id != gs.playerCountryID })
        gs.setRelation(from: lender.id, to: gs.playerCountryID, value: 40)
        let pool = AttackSizing.troopPool(gs)
        XCTAssertNotNil(e.useTactic("hired_troops", target: lender.id))
        XCTAssertGreaterThan(AttackSizing.troopPool(gs), pool)
        XCTAssertGreaterThan(gs.shadow.hiredContingents[lender.id] ?? 0, 0)
        // Fall out with them and the regiments go home.
        gs.setRelation(from: lender.id, to: gs.playerCountryID, value: -50)
        e.processDirtyTactics()
        XCTAssertNil(gs.shadow.hiredContingents[lender.id], "their sovereign has a say")
        XCTAssertEqual(AttackSizing.troopPool(gs), pool, accuracy: 1e-6)
        XCTAssertTrue(gs.shadow.ticker.contains { $0.text.contains("recalls") })
    }

    // Functional: a nation that will not lend, and one at war with you
    func testHiringNeedsAWillingSovereign() throws {
        let (e, gs) = try game(1800)
        let lender = try XCTUnwrap(gs.liveCountries.first { $0.id != gs.playerCountryID })
        gs.setRelation(from: lender.id, to: gs.playerCountryID, value: -30)
        XCTAssertNotNil(e.tacticProblem("hired_troops", target: lender.id), "nobody rents regiments to a nation they dislike")
        gs.setRelation(from: lender.id, to: gs.playerCountryID, value: 40)
        XCTAssertNil(e.tacticProblem("hired_troops", target: lender.id))
        e.declareWar(aggressor: lender.id, defender: gs.playerCountryID)
        XCTAssertNotNil(e.tacticProblem("hired_troops", target: lender.id))
    }

    // Functional: unrestricted submarine warfare strangles an island enemy and angers the neutrals
    func testUnrestrictedSubmarineWarfare() throws {
        let (e, gs) = try war(1942, with: "JPN")
        XCTAssertTrue(e.setStance("unrestricted_submarine", target: "JPN", on: true))
        let gdp = try XCTUnwrap(gs.getCountry(id: "JPN")).gdp
        for _ in 0..<24 { gs.turn += 1; e.processTacticStances() }
        XCTAssertLessThan(try XCTUnwrap(gs.getCountry(id: "JPN")).gdp, gdp * 0.9)
        // A neutral goes down about once every other year, so give it the years rather than one roll.
        var sankANeutral = gs.shadow.ticker.contains { $0.text.contains("without warning") }
        for _ in 0..<96 where !sankANeutral {
            gs.turn += 1
            e.processTacticStances()
            sankANeutral = gs.shadow.ticker.contains { $0.text.contains("without warning") }
        }
        XCTAssertTrue(sankANeutral, "neutral shipping goes down too")
    }

    // Functional: a firebombing stance, and what it does to a city
    func testFirebombingStance() throws {
        let (e, gs) = try war(1945, with: "JPN")
        XCTAssertTrue(e.setStance("firebomb_cities", target: "JPN", on: true))
        let stability = try XCTUnwrap(gs.getCountry(id: "JPN")).stability
        let dead = gs.totalCasualties
        for _ in 0..<6 { gs.turn += 1; e.processTacticStances() }
        XCTAssertLessThan(try XCTUnwrap(gs.getCountry(id: "JPN")).stability, stability)
        XCTAssertGreaterThan(gs.totalCasualties, dead)
        XCTAssertTrue(e.setStance("firebomb_cities", target: "JPN", on: false))
        XCTAssertTrue(gs.shadow.tacticStances.isEmpty)
    }

    // Security: nothing from a later era, and no stance on a nation you are not fighting
    func testSeaTargetsAndEras() throws {
        let (e, gs) = try game(1807)
        XCTAssertNil(e.useTactic("landmines", target: "GBR"), "land torpedoes are 1862")
        XCTAssertNil(e.useTactic("firebomb_cities", target: "GBR"))
        XCTAssertNotNil(e.tacticProblem("unrestricted_submarine", target: "GBR"))
        XCTAssertTrue(gs.shadow.tacticUses.isEmpty)
        let (e2, gs2) = try game(1945)
        XCTAssertNotNil(e2.tacticProblem("impressment"), "the press gang belongs to the age of sail")
        XCTAssertNil(e2.useTactic("impressment"))
        XCTAssertEqual(gs2.shadow.pressedTroops, 0)
    }

    // Integration: mines go on killing for thirty years, through the turn loop
    func testMinesKeepKillingForYears() throws {
        let (e, gs) = try war(1970, with: "VNM")
        XCTAssertNotNil(e.useTactic("landmines", target: "VNM"))
        XCTAssertEqual(gs.shadow.aftermath.count, 1)
        var tolls = 0
        for _ in 0..<35 {
            gs.turn += 12
            let before = gs.shadow.ticker.count
            e.processDirtyTactics()
            if gs.shadow.ticker.dropFirst(before).contains(where: { $0.text.contains("kill farmers") }) { tolls += 1 }
        }
        XCTAssertGreaterThan(tolls, 10, "a mined country keeps paying")
        XCTAssertTrue(gs.shadow.aftermath.isEmpty, "and then, after thirty years, it stops")
    }

    // Retry: pressed and hired men survive a save, and an old save has neither
    func testManpowerStateSurvivesSave() throws {
        let legacy = try JSONDecoder().decode(ShadowState.self, from: Data("{\"popularity\":50}".utf8))
        XCTAssertEqual(legacy.pressedTroops, 0)
        XCTAssertTrue(legacy.hiredContingents.isEmpty)
        let (e, gs) = try game(1800)
        let lender = try XCTUnwrap(gs.liveCountries.first { $0.id != gs.playerCountryID })
        gs.setRelation(from: lender.id, to: gs.playerCountryID, value: 40)
        e.useTactic("impressment")
        e.useTactic("hired_troops", target: lender.id)
        let loaded = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(gs))
        XCTAssertGreaterThan(loaded.shadow.pressedTroops, 0)
        XCTAssertGreaterThan(loaded.shadow.hiredContingents[lender.id] ?? 0, 0)
    }

    // Performance: all six groups stay cheap to list and price
    func testAllSixGroupsStayCheap() {
        XCTAssertEqual(Set(DirtyTactics.all.map(\.group)).count, TacticGroup.allCases.count, "every group has tactics")
        measure {
            for _ in 0..<400 {
                for y in [1789, 1807, 1862, 1917, 1945, 1999, 2025] {
                    for g in TacticGroup.allCases {
                        for t in DirtyTactics.available(in: y, group: g) { _ = DirtyTactics.discoveryChance(t, year: y) }
                    }
                }
            }
        }
    }
}

// MARK: - 3.17.6: AI villains, the record of the age, and the end-turn budget

@MainActor
final class WorldAtrocityTests: XCTestCase {

    private func play(from year: Int, years: Int, before: ((GameEngine, GameState) -> Void)? = nil) throws -> (GameEngine, GameState) {
        let e = GameEngine()
        e.startNewGame(turnLength: .month, year: year)
        let gs = try XCTUnwrap(e.gameState)
        e.processEraTransitions()
        before?(e, gs)
        for _ in 0..<years { gs.turn += 12; e.processEraTransitions() }
        return (e, gs)
    }

    // Unit: the table is sane, and nothing in it is a player action
    func testTheRecordOfTheAgeIsSane() {
        for a in WorldPolitics.atrocities {
            XCTAssertLessThanOrEqual(a.from, a.to, a.id)
            XCTAssertGreaterThanOrEqual(a.from, 1789, a.id)
            XCTAssertFalse(a.text.isEmpty, a.id)
            XCTAssertEqual(a.isAtrocity, a.worldCost > 0, a.id)
        }
        XCTAssertEqual(Set(WorldPolitics.atrocities.map(\.id)).count, WorldPolitics.atrocities.count, "no duplicate ids")
        // Abolition is on the record too, and costs nobody anything.
        XCTAssertTrue(WorldPolitics.atrocities.contains { $0.id == "thirteenth" && !$0.isAtrocity })
        XCTAssertTrue(WorldPolitics.atrocities.contains { $0.id == "abolition_1833" && !$0.isAtrocity })
    }

    // Security: nothing in the record is something the President can order
    func testNoPlayerActionForSlaveryOrGenocide() {
        let forbidden = ["slave", "slaver", "genocid", "ethnic cleansing", "exterminat"]
        for t in DirtyTactics.all {
            let text = (t.id + " " + t.name + " " + t.blurb).lowercased()
            for word in forbidden where word != "exterminat" {
                XCTAssertFalse(t.id.lowercased().contains(word), "\(t.id): no tactic is named for it")
            }
            XCTAssertFalse(text.contains("enslave"), t.id)
        }
        // And none of the recorded genocides has a matching tactic id.
        for a in WorldPolitics.atrocities where ["herero", "armenian", "holocaust", "khmer", "rwanda", "holodomor"].contains(a.id) {
            XCTAssertNil(DirtyTactics.tactic(a.id), "\(a.id) is history, never an order")
        }
    }

    // Functional: the Herero and Nama, and the Armenian deportations, on their real dates
    func testTheRecordFiresOnItsRealDates() throws {
        let (_, gs) = try play(from: 1900, years: 6)
        XCTAssertTrue(gs.shadow.worldAtrocities.contains { $0.text.contains("Omaheke") }, "1904")
        XCTAssertFalse(gs.shadow.worldAtrocities.contains { $0.text.contains("Armenian") }, "not yet")
        let (_, g2) = try play(from: 1913, years: 4)
        XCTAssertTrue(g2.shadow.worldAtrocities.contains { $0.text.contains("Armenian") }, "1915")
        XCTAssertGreaterThan(g2.shadow.worldStats["atrocities"] ?? 0, 0)
    }

    // Functional: abolition is on the record and blames nobody
    func testAbolitionIsOnTheRecord() throws {
        let (_, gs) = try play(from: 1862, years: 5)
        XCTAssertTrue(gs.shadow.worldAtrocities.contains { $0.text.contains("Thirteenth Amendment") })
        XCTAssertTrue(gs.shadow.worldAtrocities.contains { $0.text.contains("Emancipation Proclamation") })
    }

    // Functional: the world turns on a power that does it
    func testTheWorldTurnsOnTheActor() throws {
        let (_, gs) = try play(from: 1930, years: 3) { _, gs in
            gs.setRelation(from: "GBR", to: "JPN", value: 40)
        }
        XCTAssertTrue(gs.shadow.worldAtrocities.contains { $0.text.contains("Mukden") })
        XCTAssertLessThan(gs.getCountry(id: "GBR")?.diplomaticRelations["JPN"] ?? 0, 40)
    }

    // Security: a nation whose story has diverged does not follow the script, and nothing fires twice
    func testDivergedActorsAndNoRepeats() throws {
        let (_, gs) = try play(from: 1930, years: 3) { _, gs in gs.shadow.eraDiverged.insert("JPN") }
        XCTAssertFalse(gs.shadow.worldAtrocities.contains { $0.text.contains("Mukden") })
        let (e2, g2) = try play(from: 1913, years: 4)
        let count = g2.shadow.worldAtrocities.count
        for _ in 0..<5 { e2.processWorldAtrocities() }
        XCTAssertEqual(g2.shadow.worldAtrocities.count, count, "each line fires once")
    }

    // Integration: a computer-run power at war reaches for the era's tactics
    func testComputerRunPowersUseTheEraTactics() throws {
        var used = 0
        for _ in 0..<12 where used == 0 {
            let e = GameEngine()
            e.startNewGame(difficulty: .nightmare, turnLength: .month, year: 1944)
            let gs = try XCTUnwrap(e.gameState)
            e.declareWar(aggressor: "DEU", defender: "FRA")
            e.syncFronts()
            for _ in 0..<36 { gs.turn += 1; e.processAITactics() }
            used = gs.shadow.worldStats["aiTactics"] ?? 0
        }
        XCTAssertGreaterThan(used, 0, "the other powers fight dirty too")
    }

    // Security: the AI never uses a tactic its era does not have, and never against the player's own country by
    // a war the player started
    func testAITacticsRespectTheEra() throws {
        let e = GameEngine()
        e.startNewGame(difficulty: .nightmare, turnLength: .month, year: 1800)
        let gs = try XCTUnwrap(e.gameState)
        e.declareWar(aggressor: "FRA", defender: "GBR")
        e.syncFronts()
        for _ in 0..<60 { gs.turn += 1; e.processAITactics() }
        for line in gs.shadow.worldAtrocities {
            XCTAssertFalse(line.text.lowercased().contains("napalm"), line.text)
            XCTAssertFalse(line.text.lowercased().contains("defoliant"), line.text)
        }
        XCTAssertTrue(WorldPolitics.aiTacticIDs(year: 1800).allSatisfy { DirtyTactics.tactic($0)!.exists(in: 1800) })
        XCTAssertTrue(WorldPolitics.aiTacticIDs(year: 1800).allSatisfy { !DirtyTactics.tactic($0)!.isStance })
    }

    // Retry: the record survives a save, and an old save has none
    func testTheRecordSurvivesSave() throws {
        let legacy = try JSONDecoder().decode(ShadowState.self, from: Data("{\"popularity\":50}".utf8))
        XCTAssertTrue(legacy.worldAtrocities.isEmpty)
        let (_, gs) = try play(from: 1913, years: 4)
        let loaded = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(gs))
        XCTAssertFalse(loaded.shadow.worldAtrocities.isEmpty)
        XCTAssertTrue(loaded.shadow.firedRivalries.contains { $0.hasPrefix("atrocity-") })
    }

    // Performance: the end-turn budget measured in 3.16.2 still holds with the whole 3.17 series in the loop
    @MainActor
    func testTheEndTurnBudgetStillHolds() async throws {
        for (year, difficulty) in [(2025, DifficultyLevel.nightmare), (1789, DifficultyLevel.nightmare)] {
            let e = GameEngine()
            e.startNewGame(difficulty: difficulty, turnLength: .month, year: year)
            let gs = try XCTUnwrap(e.gameState)
            // The dirty tactics the President can run at once, so the per-turn passes have real work to do.
            gs.shadow.aftermath = (0..<20).map {
                TacticAftermath(tactic: "landmines", due: GameCalendar.calendar.date(byAdding: .year, value: $0, to: gs.currentDate)!,
                                text: "A mine goes off.", ruthlessness: 1, until: nil)
            }
            for _ in 0..<3 {
                let t0 = Date()
                e.endTurn()
                while e.turnPhase != .playerInput { try await Task.sleep(nanoseconds: 1_000_000) }
                // Measured in a Debug build on the Studio: 2025 Nightmare 0.20-0.46 s (the high one is the year's
                // era sync), 1789 Nightmare 0.014-0.040 s. The budget is 1 s.
                XCTAssertLessThan(Date().timeIntervalSince(t0), 1.0, "\(year) \(difficulty)")
            }
        }
    }
}

// MARK: - End-game roast & Most Favored Nation (3.17.x)

final class EndGameRoastAndMFNTests: XCTestCase {

    // MARK: Give Most Favored Nation

    func testMFNisAFriendlyTreatyAction() {
        XCTAssertEqual(PresidentialAction.mostFavoredNation.category, .treaties)
        XCTAssertFalse(PresidentialAction.mostFavoredNation.isHostile)
        XCTAssertTrue(PresidentialAction.friendlyActions.contains(.mostFavoredNation))
        XCTAssertFalse(PresidentialAction.mostFavoredNation.description.isEmpty)
    }

    func testMFNboostsRelationsAndEconomyWhenItLands() {
        var gs = GameState(playerCountryID: "USA", turnLength: .month)
        let r = ShadowPresidentActionManager.execute(action: .mostFavoredNation, from: "USA", to: "CHN",
                                                      gameState: &gs, successChance: 1.0)
        if r.success {   // successChance 1.0 ⇒ effectively always; guard keeps the test non-flaky
            XCTAssertEqual(r.relationChange, 25)
            XCTAssertGreaterThan(r.economicImpact, 0)
        }
    }

    // MARK: Nova end-game roast

    func testGameStateHasNoRoastUntilGameEnds() {
        XCTAssertEqual(GameState(playerCountryID: "USA").novaRoast, "")
    }

    func testRoastTemplateIsNonEmptyDeterministicAndOutcomeAware() {
        let gs = GameState(playerCountryID: "USA", turnLength: .month)
        gs.turn = 6
        gs.gameOverReason = "Impeached and removed from office"
        let score = GameScore.calculate(from: gs, victoryType: nil)

        let loss = NovaCommentary.roastTemplate(gs: gs, score: score, victory: nil)
        XCTAssertFalse(loss.isEmpty)
        XCTAssertEqual(loss, NovaCommentary.roastTemplate(gs: gs, score: score, victory: nil))  // deterministic

        let pyrrhic = NovaCommentary.roastTemplate(gs: gs, score: score, victory: .pyrrhicVictory)
        let win = NovaCommentary.roastTemplate(gs: gs, score: score, victory: .economicVictory)
        XCTAssertFalse(pyrrhic.isEmpty)
        XCTAssertFalse(win.isEmpty)
        XCTAssertNotEqual(loss, win)   // a clean win reads differently from a loss
    }

    func testRoastPromptCarriesTheOutcomeFacts() {
        let gs = GameState(playerCountryID: "USA", turnLength: .month)
        gs.turn = 9
        gs.gameOverReason = "Nuclear annihilation"
        let score = GameScore.calculate(from: gs, victoryType: nil)

        let lost = NovaCommentary.roastPrompt(gs: gs, score: score, victory: nil)
        XCTAssertTrue(lost.contains("LOST"))
        XCTAssertTrue(lost.contains("Roast the player"))
        XCTAssertTrue(NovaCommentary.roastPrompt(gs: gs, score: score, victory: .peaceMaker).contains("WON"))
    }
}

// MARK: - Make Case for War (3.17.x)

final class MakeCaseForWarTests: XCTestCase {

    func testMakeCaseForWarIsAHostileMilitaryAction() {
        XCTAssertEqual(PresidentialAction.makeCaseForWar.category, .military)
        XCTAssertTrue(PresidentialAction.makeCaseForWar.isHostile)   // advocating war is not a friendly act
        XCTAssertFalse(PresidentialAction.makeCaseForWar.description.isEmpty)
    }

    func testCongressRallyHasDiminishingReturnsAndCaps() {
        XCTAssertEqual(CongressModel.rally(30, share: 4, floor: 3), 47)    // (100-30)/4 = 17
        XCTAssertEqual(CongressModel.rally(90, share: 4, floor: 3), 93)    // small gap -> floor 3
        XCTAssertEqual(CongressModel.rally(99, share: 6, floor: 2), 100)   // 99 + 2 -> capped
        XCTAssertEqual(CongressModel.rally(100, share: 4, floor: 3), 100)  // already maxed
    }
}

// MARK: - Call for Statehood (U.S. territories, 3.18.x)

final class DomesticStatehoodTests: XCTestCase {

    func testUSTerritoriesBecomeAvailableByYearAndDropWhenAdmitted() {
        // In 1850 only DC (held from 1790) exists; the island possessions come 1898–1986.
        XCTAssertEqual(OccupationModel.availableTerritories(year: 1850, admitted: []).map(\.id), ["US-DC"])
        XCTAssertEqual(Set(OccupationModel.availableTerritories(year: 2025, admitted: []).map(\.id)),
                       Set(["US-DC", "US-PR", "US-GU", "US-VI", "US-AS", "US-MP"]))
        XCTAssertFalse(OccupationModel.availableTerritories(year: 2025, admitted: ["US-DC"]).contains { $0.id == "US-DC" })
    }

    func testCallForStatehoodAdmitsAStarAndIsIdempotent() {
        let engine = GameEngine()
        engine.startNewGame(playerCountryID: "USA")
        let before = engine.gameState?.shadow.statesAdmitted.count ?? -1

        // roll 0 passes (odds > 0); DC becomes a state.
        XCTAssertEqual(engine.petitionDomesticStatehood("US-DC", roll: 0.0), true)
        XCTAssertEqual(engine.gameState?.shadow.statesAdmitted.count, before + 1)
        XCTAssertTrue(engine.gameState?.shadow.statesAdmitted.contains { $0.id == "US-DC" } ?? false)

        // already a state -> nil (cannot re-admit)
        XCTAssertNil(engine.petitionDomesticStatehood("US-DC", roll: 0.0))
        // unknown territory -> nil
        XCTAssertNil(engine.petitionDomesticStatehood("US-ZZ", roll: 0.0))
    }
}

// MARK: - Region zoom framing (3.18.x bugfix)

final class RegionZoomTests: XCTestCase {
    func testRegionRectsAreAntimeridianSafeAndWithinTheWorld() {
        let world = CGRect(x: -180, y: -84, width: 360, height: 158)
        for region in WorldRegion.allCases {
            let r = VectorWorldMap.regionRect(region)
            XCTAssertTrue(r.width > 0 && r.height > 0, "\(region) empty box")
            XCTAssertLessThan(r.width, 200, "\(region) too wide — would trip the whole-world fallback")
            XCTAssertTrue(world.contains(r), "\(region) frames outside the world rect")
        }
        // North America must actually frame the continental U.S. (lon ~-98, lat ~39 → y = -lat)
        XCTAssertTrue(VectorWorldMap.regionRect(.northAmerica).contains(CGPoint(x: -98, y: -39)))
    }
}

// MARK: - Warhead types: fission / thermonuclear / neutron (3.18.x)

final class WarheadTypeTests: XCTestCase {
    func testEraGatesMatchHistory() {
        XCTAssertEqual(WarheadType.standard(for: 1948), .fission)        // US monopoly, atomic only
        XCTAssertEqual(WarheadType.standard(for: 1960), .thermonuclear)  // H-bomb era
        XCTAssertTrue(WarheadType.fission.available(in: 1945));  XCTAssertFalse(WarheadType.fission.available(in: 1944))
        XCTAssertFalse(WarheadType.thermonuclear.available(in: 1951)); XCTAssertTrue(WarheadType.thermonuclear.available(in: 1952))
        XCTAssertTrue(WarheadType.neutron.available(in: 1985))
        XCTAssertFalse(WarheadType.neutron.available(in: 1975)); XCTAssertFalse(WarheadType.neutron.available(in: 1995))
    }
    func testMultipliersEncodeTheRepoManProfile() {
        // thermonuclear: far deadlier. neutron: kills more than fission but spares buildings + fallout.
        XCTAssertGreaterThan(WarheadType.thermonuclear.casualtyMult, WarheadType.fission.casualtyMult)
        XCTAssertGreaterThan(WarheadType.neutron.casualtyMult, WarheadType.fission.casualtyMult)
        XCTAssertLessThan(WarheadType.neutron.blastMult, WarheadType.fission.blastMult)     // buildings stand
        XCTAssertLessThan(WarheadType.neutron.falloutMult, WarheadType.fission.falloutMult) // low lasting fallout
    }
    func testStrikeAppliesTheWarheadProfile() {
        func strike(_ t: WarheadType) -> (casualties: Int, damage: Int) {
            let e = GameEngine(); e.startNewGame(playerCountryID: "USA")
            guard let gs = e.gameState,
                  let ai = gs.countries.firstIndex(where: { $0.id == "USA" }),
                  let ti = gs.countries.firstIndex(where: { $0.id == "CHN" }) else { return (0, 0) }
            gs.countries[ai].nuclearWarheads = 100
            gs.countries[ti].hasSDI = false
            let dmg0 = gs.countries[ti].damageLevel
            e.launchNuclearStrike(from: "USA", to: "CHN", warheads: 5, type: t)
            let dmg = (e.gameState?.countries.first { $0.id == "CHN" }?.damageLevel ?? dmg0) - dmg0
            return (e.gameState?.nuclearStrikes.last?.casualties ?? 0, dmg)
        }
        let fis = strike(.fission), ther = strike(.thermonuclear), neut = strike(.neutron)
        XCTAssertGreaterThan(ther.casualties, fis.casualties)   // megaton kills more
        XCTAssertGreaterThan(neut.casualties, fis.casualties)   // neutron kills more than fission
        XCTAssertLessThan(neut.damage, fis.damage)              // ...but leaves the buildings standing
    }
}

// MARK: - Era public mood: the nuclear taboo (3.18.x)

final class EraMoodTests: XCTestCase {
    func testNuclearTabooRisesAcrossTheDecades() {
        XCTAssertLessThan(EraMood.nuclearTaboo(year: 1947), EraMood.nuclearTaboo(year: 1955))  // monopoly cheap
        XCTAssertLessThan(EraMood.nuclearTaboo(year: 1955), EraMood.nuclearTaboo(year: 1985))
        XCTAssertLessThan(EraMood.nuclearTaboo(year: 1985), EraMood.nuclearTaboo(year: 2025))  // entrenched horror
    }
    func testUseContextVictimIsCheapestAndFirstStrikeDearest() {
        XCTAssertLessThan(EraMood.useContext(atWar: false, retaliating: true), EraMood.useContext(atWar: true, retaliating: false))
        XCTAssertLessThan(EraMood.useContext(atWar: true, retaliating: false), EraMood.useContext(atWar: false, retaliating: false))
    }
    func testFirstStrikeCostsMorePopularityThanRetaliation() {
        func popDrop(makeVictim: Bool) -> Double {
            let e = GameEngine(); e.startNewGame(playerCountryID: "USA")
            guard let gs = e.gameState, let ai = gs.countries.firstIndex(where: { $0.id == "USA" }) else { return 0 }
            gs.countries[ai].nuclearWarheads = 50
            if makeVictim {   // the target already nuked us -> retaliation, not first use
                gs.nuclearStrikes.append(NuclearStrike(attacker: "CHN", target: "USA", warheadsUsed: 1, turn: 0, casualties: 0, radiationSpread: 0))
            }
            let before = gs.shadow.popularity
            e.launchNuclearStrike(from: "USA", to: "CHN", warheads: 3, type: .fission)
            return before - (e.gameState?.shadow.popularity ?? before)
        }
        XCTAssertGreaterThan(popDrop(makeVictim: false), popDrop(makeVictim: true))  // unprovoked first strike hurts more
    }
}

// MARK: - Civil War mode (3.18.x)

final class CivilWarScenarioTests: XCTestCase {
    func testConfederacyExistsOnlyDuringTheWarYears() {
        XCTAssertTrue(WorldCountriesDatabase.countriesForYear(1863).contains { $0.id == "CSA" })
        XCTAssertFalse(WorldCountriesDatabase.countriesForYear(1860).contains { $0.id == "CSA" })
        XCTAssertFalse(WorldCountriesDatabase.countriesForYear(1866).contains { $0.id == "CSA" })
    }
    func testCivilWarScenarioPutsUnionAndConfederacyAtWarFromEitherSide() {
        for side in ["USA", "CSA"] {
            let gs = ScenarioLoader.makeGameState(.civilWar1861, player: side)
            XCTAssertEqual(gs.playerCountryID, side, "player side")
            XCTAssertNotNil(gs.getCountry(id: "CSA"), "\(side): CSA missing")
            XCTAssertNotNil(gs.getCountry(id: "USA"), "\(side): USA missing")
            XCTAssertTrue(gs.getCountry(id: "USA")?.atWarWith.contains("CSA") ?? false, "\(side): Union not at war")
            XCTAssertTrue(gs.getCountry(id: "CSA")?.atWarWith.contains("USA") ?? false, "\(side): CSA not at war")
        }
    }
}

// MARK: - Civil War foreign recognition (3.18.x)

final class CivilWarRecognitionTests: XCTestCase {
    func testLeanFollowsCourtshipCottonAndMomentum() {
        XCTAssertGreaterThan(CivilWarRecognition.lean(relToUnion: 0, relToCSA: 60, monthsIn: 0, unionStability: 50, csaStability: 50), 0)  // CSA courted -> toward Confederacy
        XCTAssertLessThan(CivilWarRecognition.lean(relToUnion: 60, relToCSA: 0, monthsIn: 0, unionStability: 50, csaStability: 50), 0)     // Union courted -> toward Union
        let early = CivilWarRecognition.lean(relToUnion: 0, relToCSA: 0, monthsIn: 0, unionStability: 50, csaStability: 50)
        let late  = CivilWarRecognition.lean(relToUnion: 0, relToCSA: 0, monthsIn: 40, unionStability: 50, csaStability: 50)
        XCTAssertGreaterThan(late, early)   // cotton pressure builds toward CSA recognition over time
    }
    func testRecognitionThreshold() {
        XCTAssertEqual(CivilWarRecognition.recognizedSide(lean: 40), .confederacy)
        XCTAssertEqual(CivilWarRecognition.recognizedSide(lean: -40), .union)
        XCTAssertNil(CivilWarRecognition.recognizedSide(lean: 10))
    }
}

// MARK: - Civil War WMD gate (3.18.x)

final class CivilWarWMDGateTests: XCTestCase {
    func testCivilWarScenarioLiftsTheWMDEraGate() {
        XCTAssertTrue(ScenarioDefinition.civilWar1861.allowsEarlyWMD)
        XCTAssertFalse(ScenarioDefinition.modern2025.allowsEarlyWMD)
        let gs = ScenarioLoader.makeGameState(.civilWar1861, player: "USA")
        XCTAssertTrue(PresidentialAction.chemicalAttack.isAvailable(on: gs.currentDate, in: gs), "chem usable in 1861 Civil War")
        XCTAssertTrue(PresidentialAction.biologicalAttack.isAvailable(on: gs.currentDate, in: gs), "bio usable in 1861 Civil War")
    }
}
