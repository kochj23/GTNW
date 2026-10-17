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
