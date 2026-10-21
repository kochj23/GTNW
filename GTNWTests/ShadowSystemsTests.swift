//
//  ShadowSystemsTests.swift
//  GTNWTests
//
//  Calendar & rate scaling, save migration, advice, anxieties, elections, aid, budget, War Room combat,
//  scenarios, save slots and theme persistence. No real UserDefaults (suites are injected) and no files
//  outside a temporary directory.
//

import XCTest
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
        XCTAssertEqual(attacks(ambition: 1), 0)
        XCTAssertGreaterThan(attacks(ambition: 6), attacks(ambition: 3))
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
        XCTAssertTrue(WorldCountriesDatabase.unclaimedLandIDs(year: 1850).contains("NGA"))
        XCTAssertFalse(WorldCountriesDatabase.countriesForYear(1850).contains { $0.id == "NGA" })
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
        XCTAssertTrue(gs.unclaimedLandIDs.contains("NGA"))
        XCTAssertNil(gs.getCountry(id: "NGA"), "unclaimed land is not a country, so it never takes a computer turn")
        XCTAssertTrue(GameState(playerCountryID: "USA").unclaimedLandIDs.isEmpty)
    }

    // Functional: the whole flow

    func testClaimNigeriaIn1850NameItAndItShowsAsAUSTerritory() throws {
        let (engine, gs) = try game1850()
        let used0 = gs.actionsUsedThisTurn, ruth0 = gs.shadow.ruthlessness
        XCTAssertTrue(engine.claimLand("NGA"))
        let land = try XCTUnwrap(gs.getCountry(id: "NGA"))
        XCTAssertEqual(land.territoryOf, "USA")
        XCTAssertEqual(land.alignment, gs.getCountry(id: "USA")?.alignment)
        XCTAssertEqual(land.name, "Nigeria", "starts with the land's modern name until the President names it")
        XCTAssertEqual(land.nuclearWarheads, 0)
        XCTAssertLessThanOrEqual(land.profile.outcry, 20, "no occupation insurgency: nobody governed it")
        XCTAssertFalse(gs.unclaimedLandIDs.contains("NGA"))
        XCTAssertEqual(gs.actionsUsedThisTurn, used0 + 1)
        XCTAssertEqual(gs.shadow.ruthlessness, ruth0 + ExpansionModel.politics(year: 1850, nth: 1).ruthlessness, accuracy: 1e-9)   // 3.7.0 era politics
        XCTAssertTrue(gs.getCountry(id: "USA")!.alliances.contains("NGA"))
        XCTAssertTrue(gs.shadow.ticker.last?.text.contains("U.S. territory") ?? false)

        XCTAssertTrue(engine.renameTerritory("NGA", to: "  New Albion  "))
        XCTAssertEqual(gs.getCountry(id: "NGA")?.name, "New Albion")
        XCTAssertEqual(CombatModel.territoryTitle(ownerID: "USA", ownerName: "United States"), "U.S. TERRITORY")
        XCTAssertTrue(gs.shadow.warLog.last?.contains("New Albion") ?? false)
    }

    func testClaimingCostsLittleGoodwill() throws {
        let (engine, gs) = try game1850()
        let before = Dictionary(gs.countries.map { ($0.id, $0.diplomaticRelations["USA"] ?? 0) }, uniquingKeysWith: { a, _ in a })
        engine.claimLand("NGA")
        for c in gs.countries where c.id != "USA" && c.id != "NGA" {
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
        XCTAssertTrue(engine.claimLand("NGA"))
        let odd = "<b>Robert'); --</b> %@"
        XCTAssertTrue(engine.renameTerritory("NGA", to: odd))
        XCTAssertEqual(gs.getCountry(id: "NGA")?.name, odd)
        XCTAssertFalse(engine.renameTerritory("NGA", to: "Two\nLines"))
        XCTAssertFalse(engine.renameTerritory("NGA", to: ""))
        XCTAssertEqual(gs.getCountry(id: "NGA")?.name, odd, "a rejected name changes nothing")
        let fra = gs.getCountry(id: "FRA")?.name
        XCTAssertFalse(engine.renameTerritory("FRA", to: "Gaul"), "only the President's territories can be renamed")
        XCTAssertFalse(engine.renameTerritory("KEN", to: "Somewhere"), "nor unclaimed land")
        XCTAssertEqual(gs.getCountry(id: "FRA")?.name, fra)
    }

    // Retry: double-submits never apply twice

    func testDoubleClaimAppliesOnce() throws {
        let (engine, gs) = try game1850()
        let n0 = gs.countries.count
        XCTAssertTrue(engine.claimLand("NGA"))
        let used = gs.actionsUsedThisTurn, ruth = gs.shadow.ruthlessness, ticker = gs.shadow.ticker.count
        XCTAssertFalse(engine.claimLand("NGA"), "the retry is refused")
        XCTAssertEqual(gs.countries.count, n0 + 1)
        XCTAssertEqual(gs.countries.filter { $0.id == "NGA" }.count, 1)
        XCTAssertEqual(gs.actionsUsedThisTurn, used)
        XCTAssertEqual(gs.shadow.ruthlessness, ruth)
        XCTAssertEqual(gs.shadow.ticker.count, ticker)
    }

    func testDoubleRenameIsHarmless() throws {
        let (engine, gs) = try game1850()
        engine.claimLand("NGA")
        XCTAssertTrue(engine.renameTerritory("NGA", to: "New Albion"))
        let ticker = gs.shadow.ticker.count, log = gs.shadow.warLog.count
        XCTAssertTrue(engine.renameTerritory("NGA", to: "New Albion "), "resubmitting the same name succeeds")
        XCTAssertEqual(gs.shadow.ticker.count, ticker, "and changes nothing")
        XCTAssertEqual(gs.shadow.warLog.count, log)
    }

    func testRenameAfterSaveAndReload() throws {
        let (engine, gs) = try game1850()
        engine.claimLand("NGA")
        engine.renameTerritory("NGA", to: "New Albion")
        let loaded = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(gs))
        let engine2 = GameEngine(); engine2.gameState = loaded
        XCTAssertTrue(engine2.renameTerritory("NGA", to: "Albion Major"))
        XCTAssertEqual(loaded.getCountry(id: "NGA")?.name, "Albion Major")
        XCTAssertFalse(engine2.claimLand("NGA"), "still claimed after the reload")
        XCTAssertTrue(engine2.claimLand("KEN"), "other land is still unclaimed after the reload")
    }

    // Integration: save / load, old saves

    func testClaimedTerritorySurvivesSaveSlotAndLoad() throws {
        let dir = StoreFixtures.tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let manager = SaveManager(folder: dir)
        let (engine, gs) = try game1850()
        engine.claimLand("NGA")
        engine.renameTerritory("NGA", to: "New Albion")
        try engine.saveGame(slot: 3, manager: manager)
        let engine2 = GameEngine()
        try engine2.loadGame(slot: 3, manager: manager)
        let loaded = try XCTUnwrap(engine2.gameState)
        XCTAssertEqual(loaded.getCountry(id: "NGA")?.name, "New Albion")
        XCTAssertEqual(loaded.getCountry(id: "NGA")?.territoryOf, "USA")
        XCTAssertFalse(loaded.unclaimedLandIDs.contains("NGA"))
        XCTAssertEqual(loaded.unclaimedLandIDs, gs.unclaimedLandIDs)
    }

    func testPre330SaveOfAn1850GameDecodesWithLandsUnclaimed() throws {
        let (_, gs) = try game1850()
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(gs)) as? [String: Any])
        json["countries"] = (json["countries"] as? [[String: Any]])?.map { var c = $0; c.removeValue(forKey: "territoryOf"); return c }
        var shadow = try XCTUnwrap(json["shadow"] as? [String: Any])
        shadow.removeValue(forKey: "pendingSettlements"); json["shadow"] = shadow
        let loaded = try JSONDecoder().decode(GameState.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertTrue(loaded.unclaimedLandIDs.contains("NGA"))
        let engine = GameEngine(); engine.gameState = loaded
        XCTAssertTrue(engine.claimLand("NGA"))
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
        XCTAssertTrue(e.claimLand("NGA"))
        XCTAssertTrue(e.renameTerritory("NGA", to: "New \"Albion\" <x>"))
        XCTAssertTrue(e.renameTerritory("NGA", to: "New \"Albion\" <x>"))   // a resubmit logs nothing

        let synced = await service.syncNow()

        XCTAssertTrue(synced)
        let events = await remote.events(id)
        let claimed = try XCTUnwrap(events.first { $0.kind == "claimed_land" })
        XCTAssertEqual(PlayFixtures.detail(claimed)["land"] as? String, "NGA")
        XCTAssertEqual(PlayFixtures.detail(claimed)["name"] as? String, "Nigeria")
        let renamed = events.filter { $0.kind == "renamed_territory" }
        XCTAssertEqual(renamed.count, 1)
        XCTAssertEqual(PlayFixtures.detail(renamed[0])["name"] as? String, "New \"Albion\" <x>")
        XCTAssertEqual(PlayFixtures.detail(renamed[0])["old_name"] as? String, "Nigeria")
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
        e2.performAdvisedAction(.groundInvasion, targetID: "MEX", advice: nil, size: AttackSize(troops: std * 2))
        let f1 = try XCTUnwrap(gs1.shadow.fronts.first { $0.defender == "MEX" && $0.status == .fighting })
        let f2 = try XCTUnwrap(gs2.shadow.fronts.first { $0.defender == "MEX" && $0.status == .fighting })
        XCTAssertEqual(f1.attackerTroops, (std * 1.2).rounded()); XCTAssertEqual(f2.attackerTroops, std * 2)
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
        XCTAssertTrue(engine.claimLand("NGA", troops: 1), "a token force suffices: there's no army")
        XCTAssertTrue(e2.claimLand("NGA", troops: 20))
        let small = try XCTUnwrap(gs.getCountry(id: "NGA")), big = try XCTUnwrap(gs2.getCountry(id: "NGA"))
        XCTAssertLessThan(small.militaryStrength, big.militaryStrength)
        XCTAssertLessThan(small.stability, big.stability, "a bigger garrison holds the land more firmly")
        XCTAssertEqual(gs2.shadow.garrisons["NGA"], 20)
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
        for bad in [0.0, -5, .nan, .infinity, 1e9] { XCTAssertFalse(engine.claimLand("NGA", troops: bad), "\(bad)") }
        XCTAssertTrue(gs.unclaimedLandIDs.contains("NGA"))
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
        XCTAssertNotNil(engine.fleetOrderProblem(fleetID: "africa", target: "NGA", mission: .blockade), "unclaimed land has no ports to blockade")
        XCTAssertNil(engine.fleetOrderProblem(fleetID: "africa", target: "NGA", mission: .amphibious))
        XCTAssertNotNil(engine.orderFleet("africa", to: "NGA", mission: .amphibious))
        sail(engine, gs, turns: 2)
        XCTAssertEqual(gs.getCountry(id: "NGA")?.territoryOf, "USA")
        XCTAssertGreaterThan(gs.shadow.garrisons["NGA"] ?? 0, 0, "the landing force stays as the garrison")
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
                XCTAssertTrue(engine.claimLand(id, troops: 5), id)
                engine.renameTerritory(id, to: "Gimme \(id)")
            }
            gs.turn += 1
            engine.processShadowTurn()
            stages.append(gs.shadow.impeachmentStage)
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
        XCTAssertGreaterThanOrEqual(lands.count, 47)
        let stages = spree(engine, gs, ids: lands, turns: 1, after: 12)
        XCTAssertGreaterThanOrEqual(stages.max() ?? 0, 1, "47 lands in a week brings Congress down on the President")
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
        XCTAssertTrue(engine.claimLand("NGA"))
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
        XCTAssertGreaterThan(ExpansionModel.annualIncome(old.getCountry(id: "NGA")!, in: old), 0, "old territories count as long held")
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
                XCTAssertNil(gs.shadow.domesticEnding)
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
        let w = engine.advisorWarnings(for: .claim(land: "NGA", troops: 5))
        XCTAssertTrue(w[1].text.contains("Claim #1"))
        XCTAssertEqual(w[2].level, 0, "a first imperial-era claim is safe")
        gs.shadow.ruthlessness = 30; gs.shadow.popularity = 31
        gs.shadow.expansionLog = Array(repeating: gs.currentDate, count: 30)
        XCTAssertEqual(engine.advisorWarnings(for: .claim(land: "NGA", troops: 5))[2].level, 2, "the VP warns before the tipping claim")
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
        engine.requestAuthorization(target: "IRQ", kind: .useOfForce, roll: 0)
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
