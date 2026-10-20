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
        XCTAssertEqual(gs.shadow.ruthlessness, ruth0 + 5)
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
        e1.performAdvisedAction(.groundInvasion, targetID: "MEX", advice: nil, size: AttackSize(troops: std * 0.5))
        e2.performAdvisedAction(.groundInvasion, targetID: "MEX", advice: nil, size: AttackSize(troops: std * 2))
        let f1 = try XCTUnwrap(gs1.shadow.fronts.first { $0.defender == "MEX" && $0.status == .fighting })
        let f2 = try XCTUnwrap(gs2.shadow.fronts.first { $0.defender == "MEX" && $0.status == .fighting })
        XCTAssertEqual(f1.attackerTroops, (std * 0.5).rounded()); XCTAssertEqual(f2.attackerTroops, std * 2)
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
