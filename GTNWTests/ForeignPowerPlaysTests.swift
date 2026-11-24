//
//  ForeignPowerPlaysTests.swift
//  GTNWTests
//
//  3.36.0: presidential power plays (Shared/Engine/Shadow/ForeignPowerPlays.swift and its feature files, PowerPlayPlanner.swift,
//  PowerPlaysSheet.swift): acquisition campaigns, emergency powers and the courts, leader-capture raids, limited
//  strikes. Unit (pure formulas, the parser), functional (each feature through the engine), the command box and the
//  chief of staff, save compatibility and determinism. Turns are advanced by hand (turn += 1, then the turn step's
//  pieces) so nothing waits on the computer's moves.
//

import XCTest
@testable import GTNW

enum PPFixtures {
    @MainActor
    static func engine(year: Int = 2025, player: String = "USA", seed: UInt64 = 36) -> GameEngine {
        CmdFixtures.engine(year: year, player: player, seed: seed)
    }

    /// Free the turn's actions again (so nothing schedules an end of turn).
    @MainActor
    static func refill(_ e: GameEngine) { e.gameState?.actionsUsedThisTurn = 0 }

    /// Advance `months` monthly turns, running the power plays' and War Powers' turn steps only.
    @MainActor
    static func advance(_ e: GameEngine, months: Int) {
        for _ in 0..<months {
            e.gameState?.turn += 1
            e.processPowerPlays()
            e.processWarPowers()
            refill(e)
        }
    }

    @MainActor
    static func plan(_ e: GameEngine, _ text: String) -> CommandPlan? {
        guard let i = CommandParser.parse(text) else { return nil }
        var outcome = e.planCommand(i, source: .parser)
        for _ in 0..<3 { if case .clarify(let c) = outcome, let f = c.options.first { outcome = e.planCommand(f.intent, source: .parser) } }
        if case .plan(let p) = outcome { return p }
        return nil
    }
}

// MARK: - Unit

final class PowerPlaysUnitTests: XCTestCase {

    func testParserReadsEveryPowerPlay() throws {
        func v(_ s: String) -> CommandIntent? { CommandParser.parse(s) }
        XCTAssertEqual(v("offer to buy Greenland")?.verb, .acquire)
        XCTAssertEqual(v("offer to buy Greenland")?.targets, ["greenland"])
        XCTAssertEqual(v("tariff the objectors over Greenland")?.verb, .pressure)
        XCTAssertEqual(v("threaten Denmark")?.verb, .posture)
        XCTAssertEqual(v("take the framework deal on Greenland")?.verb, .frameworkDeal)
        XCTAssertEqual(v("declare a national emergency over trade")?.verb, .emergency)
        XCTAssertEqual(v("declare a national emergency over trade")?.detail, EmergencyReason.trade.rawValue)
        XCTAssertEqual(v("declare a national emergency at the border")?.detail, EmergencyReason.border.rawValue)
        XCTAssertEqual(v("end the national emergency")?.verb, .endEmergency)
        let t = try XCTUnwrap(v("emergency tariffs on Canada under section 232"))
        XCTAssertEqual(t.verb, .emergencyTariffs)
        XCTAssertEqual(t.targets, ["canada"])
        XCTAssertEqual(t.detail, LegalBasis.nationalSecurity232.rawValue)
        XCTAssertEqual(v("tariffs on Mexico under emergency powers")?.verb, .emergencyTariffs)
        XCTAssertEqual(v("tariffs on Mexico under emergency powers")?.detail, LegalBasis.emergencyEconomic.rawValue)
        XCTAssertEqual(v("tariffs on Mexico")?.verb, .tariffs, "plain tariffs stay the Situation Room action")
        XCTAssertEqual(v("reissue the tariffs on Canada under national security")?.detail, LegalBasis.nationalSecurity232.rawValue)
        XCTAssertEqual(v("capture the leader of Panama")?.verb, .captureLeader)
        XCTAssertEqual(v("capture Panama's leader")?.targets, ["panama"])
        XCTAssertNil(v("capture Paris").flatMap { $0.verb == .captureLeader ? $0 : nil }, "capture without a leader is not a raid")
        XCTAssertEqual(v("precision strike on Libya")?.detail, StrikeKind.precision.rawValue)
        XCTAssertEqual(v("strike Iran's nuclear facilities")?.verb, .limitedStrike)
        XCTAssertEqual(v("strike Iran's nuclear facilities")?.detail, StrikeKind.nuclearFacility.rawValue)
        XCTAssertEqual(v("strike Iran's nuclear facilities")?.targets, ["iran"])
        XCTAssertEqual(v("strike boats off Venezuela")?.detail, StrikeKind.boats.rawValue)
        XCTAssertEqual(v("strike boats off Venezuela")?.targets, ["venezuela"])
        XCTAssertEqual(v("strike France")?.verb, .attack, "a plain strike is still an attack")
    }

    func testBasesFollowTheCalendar() {
        XCTAssertEqual(LegalBasis.emergencyEconomic.since, 1977)
        XCTAssertEqual(LegalBasis.nationalSecurity232.since, 1962)
        XCTAssertTrue(LegalBasis.emergencyEconomic.needsEmergency)
        XCTAssertFalse(LegalBasis.insurrectionAct.covers(.tariff))
        XCTAssertTrue(LegalBasis.insurrectionAct.covers(.deployment))
        XCTAssertLessThan(LegalBasis.impoundment.strength(for: .spendingFreeze, year: 1980), LegalBasis.impoundment.strength(for: .spendingFreeze, year: 1960))
        XCTAssertLessThan(EmergencyPowers.eraAdjustment(year: 2025), EmergencyPowers.eraAdjustment(year: 1960))
    }

    func testCaptureOddsAreBoundedAndSensible() {
        let base = LeaderCapture.odds(year: 2025, intel: 0.9, spies: 0, playerMilitary: 90, targetMilitary: 20, distanceKm: 3000, targetStability: 40)
        XCTAssertGreaterThan(base, LeaderCapture.odds(year: 1930, intel: 0.9, spies: 0, playerMilitary: 90, targetMilitary: 20, distanceKm: 3000, targetStability: 40))
        XCTAssertGreaterThan(base, LeaderCapture.odds(year: 2025, intel: 0.9, spies: 0, playerMilitary: 90, targetMilitary: 20, distanceKm: 15000, targetStability: 40))
        XCTAssertGreaterThan(LeaderCapture.odds(year: 2025, intel: 0.9, spies: 80, playerMilitary: 90, targetMilitary: 20, distanceKm: 3000, targetStability: 40), base)
        for y in [1800, 1950, 2025] {
            let p = LeaderCapture.odds(year: y, intel: 0, spies: 0, playerMilitary: 1, targetMilitary: 100, distanceKm: 20_000, targetStability: 100)
            XCTAssertGreaterThanOrEqual(p, 0.03)
            XCTAssertLessThanOrEqual(LeaderCapture.odds(year: y, intel: 1, spies: 100, playerMilitary: 100, targetMilitary: 1, distanceKm: 0, targetStability: 0), 0.8)
        }
    }

    func testCampaignFormulas() {
        let calm = AcquisitionModel.resistance(kind: .colony, protests: 0, solidarity: 0, ownerMilitary: 20, objectors: 0, relation: 50, ownerNuclear: false, year: 1900)
        let hot = AcquisitionModel.resistance(kind: .colony, protests: 60, solidarity: 12, ownerMilitary: 20, objectors: 4, relation: -20, ownerNuclear: false, year: 1900)
        XCTAssertGreaterThan(hot, calm)
        XCTAssertGreaterThan(AcquisitionModel.resistance(kind: .nation, protests: 0, solidarity: 0, ownerMilitary: 20, objectors: 0, relation: 0, ownerNuclear: false, year: 2000),
                             AcquisitionModel.resistance(kind: .land, protests: 0, solidarity: 0, ownerMilitary: 20, objectors: 0, relation: 0, ownerNuclear: false, year: 2000))
        XCTAssertGreaterThan(AcquisitionModel.leverage(.posture, econShare: 0.5, milShare: 0.9, tariffed: 0, nuclearEdge: true),
                             AcquisitionModel.leverage(.posture, econShare: 0.5, milShare: 0.2, tariffed: 0, nuclearEdge: false))
        XCTAssertEqual(AcquisitionModel.leverage(.deal, econShare: 1, milShare: 1, tariffed: 4, nuclearEdge: true), 0)
        XCTAssertEqual(LimitedStrikes.restraintYes(authorizationYes: 30), 70)
    }

    func testOldSavesDecodeWithEmptyPowerPlays() throws {
        let state = try JSONDecoder().decode(PowerPlayState.self, from: Data("{}".utf8))
        XCTAssertTrue(state.isIdle)
        XCTAssertEqual(state.nextOrderID, 1)
        let shadow = try JSONDecoder().decode(ShadowState.self, from: Data(#"{"popularity": 61}"#.utf8))
        XCTAssertEqual(shadow.powerPlays, PowerPlayState())
        // A partial record (a later field missing) still loads.
        let partial = try JSONDecoder().decode(PowerPlayState.self, from: Data(#"{"strikeBans":["IRN"],"featureNames":{"GEO_X":"Y"}}"#.utf8))
        XCTAssertEqual(partial.strikeBans, ["IRN"])
        XCTAssertEqual(partial.featureNames["GEO_X"], "Y")
    }
}

// MARK: - Emergency powers and the courts

final class EmergencyPowersTests: XCTestCase {

    @MainActor
    func testEmergencyUnlocksEmergencyPowersAndTheCourtsStrikeAWeakTariff() throws {
        let e = PPFixtures.engine()
        let gs = try XCTUnwrap(e.gameState)
        XCTAssertNotNil(e.basisBlocked(.emergencyEconomic, kind: .tariff, target: "CAN"), "no emergency yet")
        XCTAssertTrue(e.declareNationalEmergency(.trade))
        PPFixtures.refill(e)
        XCTAssertNil(e.basisBlocked(.emergencyEconomic, kind: .tariff, target: "CAN"))
        let relBefore = gs.getCountry(id: "CAN")?.diplomaticRelations["USA"] ?? 0
        let o = try XCTUnwrap(e.emergencyTariffs(on: "CAN", basis: .emergencyEconomic))
        PPFixtures.refill(e)
        XCTAssertEqual(o.status, .inForce)
        XCTAssertLessThan(gs.getCountry(id: "CAN")?.diplomaticRelations["USA"] ?? 0, relBefore)
        XCTAssertFalse(e.courtUpholds(o), "emergency economic powers are weak for tariffs in the 2020s courts")
        PPFixtures.advance(e, months: 7)
        let ruled = try XCTUnwrap(gs.shadow.powerPlays.orders.first { $0.id == o.id })
        XCTAssertEqual(ruled.status, .struckDown)
        XCTAssertTrue(gs.shadow.ticker.contains { $0.text.contains("strikes down the tariffs on") })
        // Reissue under another authority; the struck one is refused.
        XCTAssertNotNil(e.reissueProblem(o.id, basis: .emergencyEconomic))
        let again = try XCTUnwrap(e.reissueEmergencyOrder(o.id, basis: .nationalSecurity232))
        PPFixtures.refill(e)
        XCTAssertEqual(again.root, o.root)
        XCTAssertEqual(again.status, .pending, "section 232 needs an investigation first")
        XCTAssertTrue(again.struckBases.contains(.emergencyEconomic))
        PPFixtures.advance(e, months: 5)
        XCTAssertEqual(gs.shadow.powerPlays.orders.first { $0.id == again.id }?.status, .inForce)
    }

    @MainActor
    func testStrongAuthorityIsUpheldAndATimeLimitLapses() throws {
        let e = PPFixtures.engine()
        let gs = try XCTUnwrap(e.gameState)
        let target = try XCTUnwrap(gs.countries.first { !$0.isTerritory && !$0.alliances.contains("USA") && $0.id != "USA" && !$0.isDestroyed && $0.gdp > 0.5 }?.id)
        let strong = try XCTUnwrap(e.emergencyTariffs(on: target, basis: .nationalSecurity232))
        PPFixtures.refill(e)
        XCTAssertTrue(e.courtUpholds(strong))
        PPFixtures.advance(e, months: 11)
        XCTAssertEqual(gs.shadow.powerPlays.orders.first { $0.id == strong.id }?.status, .upheld)
        let other = try XCTUnwrap(gs.countries.first { !$0.isTerritory && $0.id != "USA" && $0.id != target && !$0.isDestroyed && $0.gdp > 0.3 }?.id)
        let limited = try XCTUnwrap(e.emergencyTariffs(on: other, basis: .balanceOfPayments122))
        PPFixtures.advance(e, months: 6)
        XCTAssertEqual(gs.shadow.powerPlays.orders.first { $0.id == limited.id }?.status, .lapsed)
    }

    @MainActor
    func testGenericHookForOtherOrders() throws {
        let e = PPFixtures.engine()
        let o = try XCTUnwrap(e.issueEmergencyOrder(kind: .deployment, target: "HOME", subject: "Guard deployment", basis: .insurrectionAct))
        XCTAssertTrue(e.emergencyOrderInForce(o.id))
        XCTAssertNil(e.issueEmergencyOrder(kind: .deployment, target: "HOME", subject: "x", basis: .nationalSecurity232), "232 does not cover troops")
        XCTAssertTrue(e.rescindEmergencyOrder(o.id))
        XCTAssertFalse(e.emergencyOrderInForce(o.id))
    }

    @MainActor
    func testEndingTheEmergencyLapsesItsOrders() throws {
        let e = PPFixtures.engine()
        XCTAssertTrue(e.declareNationalEmergency(.security))
        PPFixtures.refill(e)
        let o = try XCTUnwrap(e.emergencyTariffs(on: "MEX", basis: .emergencyEconomic))
        XCTAssertTrue(e.endNationalEmergency())
        XCTAssertEqual(e.gameState?.shadow.powerPlays.orders.first { $0.id == o.id }?.status, .lapsed)
        XCTAssertNil(e.gameState?.shadow.powerPlays.emergency)
    }

    @MainActor
    func testOrdinaryTariffActionGoesOnTheRecord() throws {
        let e = PPFixtures.engine()
        e.performAdvisedAction(.imposeTariffs, targetID: "BRA", advice: nil)
        PPFixtures.refill(e)
        XCTAssertNotNil(e.liveEmergencyOrder(.tariff, target: "BRA"))
        e.performAdvisedAction(.removeTariffs, targetID: "BRA", advice: nil)
        XCTAssertNil(e.liveEmergencyOrder(.tariff, target: "BRA"))
    }

    @MainActor
    func testAuthoritarianCourtsDoNotBite() throws {
        let e = PPFixtures.engine(player: "RUS")
        let gs = try XCTUnwrap(e.gameState)
        if let i = gs.countries.firstIndex(where: { $0.id == "RUS" }) { gs.countries[i].government = .authoritarian }
        XCTAssertTrue(e.declareNationalEmergency(.trade))
        PPFixtures.refill(e)
        XCTAssertTrue(e.legalBases(for: .tariff).contains(.emergencyDecree))
        XCTAssertFalse(e.legalBases(for: .tariff).contains(.nationalSecurity232), "American statutes are not Russia's law")
        let o = try XCTUnwrap(e.emergencyTariffs(on: "UKR", basis: .emergencyDecree))
        XCTAssertTrue(e.courtUpholds(o))
    }
}

// MARK: - Limited strikes

final class LimitedStrikesTests: XCTestCase {

    @MainActor
    static func quietTarget(_ gs: GameState) -> String {
        gs.countries.first { $0.id == "VEN" && !$0.isDestroyed }?.id ?? "CUB"
    }

    @MainActor
    func testStrikesStartTheWarPowersClockAndForceAVote() throws {
        let e = PPFixtures.engine()
        let gs = try XCTUnwrap(e.gameState)
        let t = Self.quietTarget(gs)
        XCTAssertNil(e.strikeProblem(t, kind: .boats))
        XCTAssertNotNil(e.limitedStrike(t, kind: .boats, roll: 0))
        PPFixtures.refill(e)
        XCTAssertFalse(gs.getPlayerCountry()?.atWarWith.contains(t) ?? true, "no declaration of war")
        XCTAssertTrue(e.hostilitiesTargets().contains(t))
        e.processWarPowers()
        XCTAssertNotNil(gs.shadow.warPowersClocks[t], "the existing War Powers clock runs")
        XCTAssertNotNil(e.limitedStrike(t, kind: .precision, roll: 0))
        PPFixtures.refill(e)
        PPFixtures.advance(e, months: 1)
        XCTAssertEqual(gs.shadow.powerPlays.strikeVotes.filter { $0.target == t }.count, 1, "a second strike forces a vote")
        PPFixtures.advance(e, months: 1)
        XCTAssertEqual(gs.shadow.powerPlays.strikeVotes.filter { $0.target == t }.count, 1, "one vote per window")
        // The clock goes when the strikes stop.
        PPFixtures.advance(e, months: 4)
        XCTAssertFalse(e.hostilitiesTargets().contains(t))
    }

    @MainActor
    func testOverriddenVetoMakesTheNextStrikeDefiance() throws {
        let e = PPFixtures.engine()
        let gs = try XCTUnwrap(e.gameState)
        let t = Self.quietTarget(gs)
        if let pi = gs.countries.firstIndex(where: { $0.id == "USA" }) { gs.countries[pi].congressionalSupport = 0; gs.countries[pi].warSupport = 0 }
        gs.shadow.popularity = 5
        let v = try XCTUnwrap(e.forceStrikeVote(t))
        XCTAssertTrue(v.passed && v.overridden)
        XCTAssertTrue(gs.shadow.powerPlays.strikeBans.contains(t))
        let before = gs.getPlayerCountry()?.congressionalSupport ?? 0
        XCTAssertTrue(e.strikeWarnings(t, kind: .precision).contains { $0.level == 2 && $0.text.contains("defies Congress") })
        XCTAssertNotNil(e.limitedStrike(t, kind: .precision, roll: 0))
        XCTAssertEqual(gs.shadow.powerPlays.strikes.last?.defied, true)
        XCTAssertLessThanOrEqual(gs.getPlayerCountry()?.congressionalSupport ?? 0, before)
    }

    @MainActor
    func testNuclearFacilityStrikeDelaysTheProgram() throws {
        let e = PPFixtures.engine()
        let gs = try XCTUnwrap(e.gameState)
        let ti = try XCTUnwrap(gs.countries.firstIndex { $0.id == "IRN" })
        gs.countries[ti].nuclearStatus = .developing
        gs.countries[ti].aggressionLevel = 1
        gs.countries[ti].nuclearWarheads = 0
        XCTAssertNil(e.strikeProblem("IRN", kind: .nuclearFacility))
        XCTAssertEqual(e.limitedStrike("IRN", kind: .nuclearFacility, roll: 0), true)
        PPFixtures.refill(e)
        XCTAssertTrue(e.nuclearProgramDelayed("IRN"))
        PPFixtures.advance(e, months: 25)
        XCTAssertFalse(e.nuclearProgramDelayed("IRN"))
    }

    @MainActor
    func testStrikesAddUpToWar() throws {
        let e = PPFixtures.engine()
        let gs = try XCTUnwrap(e.gameState)
        let ti = try XCTUnwrap(gs.countries.firstIndex { $0.id == "VEN" })
        gs.countries[ti].militaryStrength = 40
        gs.countries[ti].aggressionLevel = 60
        for _ in 0..<6 where !(gs.getPlayerCountry()?.atWarWith.contains("VEN") ?? true) {
            _ = e.limitedStrike("VEN", kind: .facility, roll: 0)
            PPFixtures.refill(e)
        }
        XCTAssertTrue(gs.getPlayerCountry()?.atWarWith.contains("VEN") ?? false, "repeated strikes push the target into war")
        XCTAssertNotNil(e.strikeProblem("VEN", kind: .precision), "at war: limited strikes give way to the war orders")
    }
}

// MARK: - Leader capture

final class LeaderCaptureTests: XCTestCase {

    @MainActor
    func testCaptureOpensTheRegimeChangePath() throws {
        let e = PPFixtures.engine()
        let gs = try XCTUnwrap(e.gameState)
        let ws = e.captureWarnings("PAN")
        XCTAssertTrue(ws.contains { $0.who == PowerPlay.counsel && $0.text.contains("UN Charter") }, "legality first")
        XCTAssertEqual(e.captureLeader("PAN", roll: 0), .captured)
        PPFixtures.refill(e)
        XCTAssertTrue(gs.shadow.pendingSettlements.contains { $0.loser == "PAN" && $0.victor == "USA" })
        XCTAssertNotNil(e.captureProblem("PAN"), "a year's guard after a raid")
        XCTAssertFalse(gs.shadow.ticker.suffix(5).contains { $0.text.contains(gs.shadow.leaderNames["PAN"] ?? "§§") })
    }

    @MainActor
    func testFailuresBringHostagesOrWar() throws {
        let e = PPFixtures.engine()
        let gs = try XCTUnwrap(e.gameState)
        XCTAssertEqual(e.captureLeader("CUB", roll: 0.999), .firefight)
        PPFixtures.refill(e)
        XCTAssertTrue(gs.getPlayerCountry()?.atWarWith.contains("CUB") ?? false)
        let odds = e.captureOdds("NIC")
        XCTAssertEqual(e.captureLeader("NIC", roll: odds + 0.01), .hostages)
        PPFixtures.refill(e)
        XCTAssertEqual(gs.shadow.powerPlays.hostages.last?.released, false)
        PPFixtures.advance(e, months: 7)
        XCTAssertEqual(gs.shadow.powerPlays.hostages.last?.released, true)
    }
}

// MARK: - Acquisition campaign

final class AcquisitionCampaignTests: XCTestCase {

    @MainActor
    func testGreenlandIsALandUnderDenmark() throws {
        let e = PPFixtures.engine()
        let t = try XCTUnwrap(e.acquisitionTarget("GRL"))
        XCTAssertEqual(t.kind, .land)
        XCTAssertEqual(t.owner.id, "DNK")
        let p = try XCTUnwrap(PPFixtures.plan(e, "offer to buy Greenland"))
        XCTAssertEqual(p.orders.first?.kind, .acquire)
        XCTAssertEqual(p.orders.first?.target, "GRL")
        let viaBuy = try XCTUnwrap(PPFixtures.plan(e, "buy Greenland"), "buy on a land under a nation starts a campaign")
        XCTAssertEqual(viaBuy.orders.first?.mission, CampaignStep.offer.rawValue)
    }

    @MainActor
    func testCampaignStepsTariffsPushbackAndFramework() throws {
        let e = PPFixtures.engine()
        let gs = try XCTUnwrap(e.gameState)
        XCTAssertTrue(e.campaignStep("GRL", step: .offer))
        PPFixtures.refill(e)
        let c0 = try XCTUnwrap(e.openCampaign("GRL"))
        XCTAssertFalse(c0.objectors.isEmpty, "Denmark's allies object")
        XCTAssertNotNil(e.campaignProblem("GRL", step: .offer), "one campaign at a time")
        XCTAssertTrue(e.campaignStep("GRL", step: .pressure))
        PPFixtures.refill(e)
        let c1 = try XCTUnwrap(e.openCampaign("GRL"))
        XCTAssertEqual(c1.stage, .tariffs)
        XCTAssertFalse(c1.tariffOrders.isEmpty, "the tariffs go through emergency powers")
        XCTAssertTrue(c1.tariffOrders.allSatisfy { id in gs.shadow.powerPlays.orders.first { $0.id == id }?.status.isLive == true })
        XCTAssertGreaterThan(c1.protests, c0.protests)
        XCTAssertTrue(e.campaignStep("GRL", step: .posture))
        PPFixtures.refill(e)
        let c2 = gs.shadow.powerPlays.campaigns.last!
        if c2.stage == .posturing {
            XCTAssertTrue(e.campaignStep("GRL", step: .deal))
            let c3 = gs.shadow.powerPlays.campaigns.last!
            XCTAssertEqual(c3.stage, .deal)
            XCTAssertTrue(c3.tariffOrders.allSatisfy { !e.emergencyOrderInForce($0) }, "the deal lifts the tariffs")
        } else {
            XCTAssertEqual(c2.stage, .acquired)
        }
    }

    @MainActor
    func testLeverageWinsAWeakOwnersColony() throws {
        let e = PPFixtures.engine(year: 1850, player: "USA")
        let gs = try XCTUnwrap(e.gameState)
        let land = try XCTUnwrap(gs.colonyLandIDs.sorted().first { e.colonyTarget($0) != nil && e.colonyTarget($0)?.owner.nuclearWarheads == 0 })
        let owner = try XCTUnwrap(e.colonyTarget(land)?.owner.id)
        if let oi = gs.countries.firstIndex(where: { $0.id == owner }) {
            gs.countries[oi].militaryStrength = 1
            gs.countries[oi].alliances = []
            gs.countries[oi].diplomaticRelations["USA"] = 100
        }
        for step in [CampaignStep.offer, .pressure, .posture] where e.openCampaign(land) != nil || step == .offer {
            XCTAssertTrue(e.campaignStep(land, step: step))
            PPFixtures.refill(e)
        }
        XCTAssertEqual(gs.shadow.powerPlays.campaigns.last?.stage, .acquired)
        XCTAssertEqual(gs.getCountry(id: land)?.territoryOf, "USA")
    }

    @MainActor
    func testEscalationIsWarOnTheOwner() throws {
        let e = PPFixtures.engine()
        let gs = try XCTUnwrap(e.gameState)
        XCTAssertTrue(e.campaignStep("GRL", step: .offer))
        PPFixtures.refill(e)
        XCTAssertTrue(e.campaignWarnings("GRL", step: .escalate).contains { $0.level == 2 })
        XCTAssertTrue(e.campaignStep("GRL", step: .escalate))
        PPFixtures.refill(e)
        XCTAssertTrue(gs.getPlayerCountry()?.atWarWith.contains("DNK") ?? false)
        XCTAssertEqual(gs.shadow.powerPlays.campaigns.last?.stage, .escalated)
    }
}

// MARK: - Command box, chief of staff, saves, determinism

final class PowerPlaysIntegrationTests: XCTestCase {

    @MainActor
    func testCardsCarryTheCabinetAndExecute() throws {
        let e = PPFixtures.engine()
        let raid = try XCTUnwrap(PPFixtures.plan(e, "capture the leader of Panama"))
        XCTAssertEqual(raid.title, "LEADER CAPTURE RAID")
        XCTAssertTrue(raid.warnings.contains { $0.text.hasPrefix(PowerPlay.counsel) })
        XCTAssertTrue(raid.committed.joined().contains("Odds"))
        let strike = try XCTUnwrap(PPFixtures.plan(e, "strike boats off Venezuela"))
        XCTAssertEqual(strike.orders.first?.mission, StrikeKind.boats.rawValue)
        let out = e.executeCommand(strike.orders, source: .parser)
        XCTAssertEqual(out.carried.count, 1)
        PPFixtures.refill(e)
        XCTAssertEqual(e.gameState?.shadow.commandLog.last?.orders.first?.kind, .limitedStrike)
        let declare = try XCTUnwrap(PPFixtures.plan(e, "declare a national emergency over trade"))
        XCTAssertEqual(declare.orders.first?.detail, EmergencyReason.trade.rawValue)
        XCTAssertEqual(e.executeCommand(declare.orders, source: .parser).carried.count, 1)
        PPFixtures.refill(e)
        let tariff = try XCTUnwrap(PPFixtures.plan(e, "emergency tariffs on Canada"))
        XCTAssertEqual(tariff.orders.first?.detail, LegalBasis.emergencyEconomic.rawValue, "with an emergency in force the chief picks emergency powers")
        XCTAssertTrue(tariff.committed.contains { $0.contains("likely struck down") })
        guard case .rejected = e.planCommand(CommandIntent(verb: .emergencyTariffs, targets: ["Canada"], detail: LegalBasis.tradingWithEnemy.rawValue), source: .parser) else {
            return XCTFail("the Trading with the Enemy Act needs a war after 1977")
        }
    }

    @MainActor
    func testTamperedOrdersAreRefused() throws {
        let e = PPFixtures.engine()
        XCTAssertFalse(e.executeOrder(GameOrder(kind: .limitedStrike, target: "VEN", mission: "orbital")))
        XCTAssertFalse(e.executeOrder(GameOrder(kind: .emergency, target: "CAN", mission: "tariff", detail: "notALaw")))
        XCTAssertFalse(e.executeOrder(GameOrder(kind: .emergency, target: "CAN", mission: "tariff", detail: LegalBasis.emergencyEconomic.rawValue)), "no emergency in force")
        XCTAssertFalse(e.executeOrder(GameOrder(kind: .acquire, target: "USA", mission: "offer")))
        XCTAssertFalse(e.executeOrder(GameOrder(kind: .captureLeader, target: "USA")))
    }

    @MainActor
    func testChiefOfStaffProposesPowerPlaysAndReadsThem() throws {
        let e = PPFixtures.engine()
        let before = try JSONEncoder().encode(e.gameState!.shadow)
        let out = ChatTools.run("propose_orders", arguments: ["steps": [["verb": "limitedStrike", "targets": ["Iran"], "detail": "nuclearFacility"],
                                                                         ["verb": "acquire", "targets": ["Greenland"]],
                                                                         ["verb": "emergency", "detail": "border"]]], engine: e, planID: 1)
        XCTAssertFalse(out.isError, out.text)
        let plan = try XCTUnwrap(out.plan)
        XCTAssertEqual(plan.steps.count, 3)
        XCTAssertEqual(plan.steps[1].plan?.orders.first?.target, "GRL")
        XCTAssertEqual(plan.steps[2].plan?.orders.first?.detail, EmergencyReason.border.rawValue)
        let read = ChatTools.run("power_plays", arguments: [:], engine: e)
        XCTAssertFalse(read.isError)
        XCTAssertEqual(try JSONEncoder().encode(e.gameState!.shadow), before, "tools never write the game")
        let bad = ChatTools.run("propose_orders", arguments: ["steps": [["verb": "emergencyTariffs", "targets": ["Canada"], "detail": "the vibes"]]], engine: e)
        XCTAssertTrue(bad.isError)
    }

    @MainActor
    func testSaveRoundTripKeepsEverything() throws {
        let e = PPFixtures.engine()
        XCTAssertTrue(e.declareNationalEmergency(.trade)); PPFixtures.refill(e)
        _ = e.emergencyTariffs(on: "CAN", basis: .emergencyEconomic); PPFixtures.refill(e)
        _ = e.limitedStrike("VEN", kind: .boats, roll: 0); PPFixtures.refill(e)
        _ = e.captureLeader("NIC", roll: 0.5); PPFixtures.refill(e)
        _ = e.campaignStep("GRL", step: .offer); PPFixtures.refill(e)
        let gs = try XCTUnwrap(e.gameState)
        let back = try JSONDecoder().decode(ShadowState.self, from: JSONEncoder().encode(gs.shadow))
        XCTAssertEqual(back.powerPlays, gs.shadow.powerPlays)
        XCTAssertFalse(back.powerPlays.isIdle)
        // Without the key (a 3.35 save) it loads empty.
        var obj = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(gs.shadow)) as? [String: Any])
        obj.removeValue(forKey: "powerPlays")
        let old = try JSONDecoder().decode(ShadowState.self, from: JSONSerialization.data(withJSONObject: obj))
        XCTAssertTrue(old.powerPlays.isIdle)
    }

    @MainActor
    func testSameSeedSameOrdersSameOutcome() throws {
        func play() throws -> (Data, UInt64) {
            let e = PPFixtures.engine(seed: 909)
            _ = e.declareNationalEmergency(.trade); PPFixtures.refill(e)
            _ = e.emergencyTariffs(on: "CAN", basis: .emergencyEconomic); PPFixtures.refill(e)
            _ = e.limitedStrike("VEN", kind: .precision); PPFixtures.refill(e)
            _ = e.limitedStrike("VEN", kind: .boats); PPFixtures.refill(e)
            _ = e.captureLeader("NIC"); PPFixtures.refill(e)
            _ = e.campaignStep("GRL", step: .offer); PPFixtures.refill(e)
            _ = e.campaignStep("GRL", step: .pressure); PPFixtures.refill(e)
            PPFixtures.advance(e, months: 8)
            let gs = try XCTUnwrap(e.gameState)
            return (try JSONEncoder().encode(gs.shadow.powerPlays), gs.rng.state)
        }
        let a = try play(), b = try play()
        XCTAssertEqual(a.0, b.0)
        XCTAssertEqual(a.1, b.1)
    }

    @MainActor
    func testAnUntouchedGameDrawsNothing() throws {
        let e = PPFixtures.engine()
        let gs = try XCTUnwrap(e.gameState)
        let rng = gs.rng.state
        e.processPowerPlays()
        XCTAssertEqual(gs.rng.state, rng)
        XCTAssertTrue(gs.shadow.powerPlays.isIdle)
        XCTAssertEqual(e.limitedStrikeHostilities(), [])
    }
}

// MARK: - Renaming the map and the government

final class PlaceNamesTests: XCTestCase {

    func testFeaturesByEraAndIdsFitOrders() {
        XCTAssertEqual(MapFeatures.feature("GEO_EVEREST")?.name(in: 1850), "Peak XV")
        XCTAssertEqual(MapFeatures.feature("GEO_EVEREST")?.name(in: 1900), "Mount Everest")
        XCTAssertEqual(MapFeatures.feature("GEO_TAIWAN_STR")?.name(in: 1930), "Formosa Strait")
        XCTAssertFalse(MapFeatures.feature("GEO_SUEZ")!.exists(in: 1850))
        for id in MapFeatures.all.map(\.id) + (Departments.american + Departments.ministries).map(\.id) {
            XCTAssertLessThanOrEqual(id.count, 16, id)
            XCTAssertTrue(id.unicodeScalars.allSatisfy { CharacterSet.alphanumerics.contains($0) || $0 == "_" }, id)
        }
        XCTAssertEqual(Set(MapFeatures.all.map(\.id)).count, MapFeatures.all.count)
    }

    func testParserKeepsTheNewNamesCapitals() {
        let i = CommandParser.parse("Rename the Gulf of Mexico to Gulf of Plenty")
        XCTAssertEqual(i?.verb, .renamePlace)
        XCTAssertEqual(i?.detail, "Gulf of Plenty")
        XCTAssertEqual(CommandParser.parse("rename the Department of Defense to Department of War")?.verb, .renamePlace)
        XCTAssertNotEqual(CommandParser.parse("rename France to Gaul")?.verb, .renamePlace, "a nation is not a map feature")
    }

    @MainActor
    func testRenameFeatureRecognitionNewsAndUndo() throws {
        let e = PPFixtures.engine()
        let gs = try XCTUnwrap(e.gameState)
        let mx = gs.getCountry(id: "MEX")?.diplomaticRelations["USA"] ?? 0
        let p = try XCTUnwrap(PPFixtures.plan(e, "rename the Gulf of Mexico to Gulf of Plenty"))
        XCTAssertEqual(p.actionsNeeded, 0)
        XCTAssertEqual(e.executeCommand(p.orders, source: .parser).carried.count, 1)
        XCTAssertEqual(gs.shadow.powerPlays.featureNames["GEO_GULF_MEXICO"], "Gulf of Plenty")
        XCTAssertTrue(gs.shadow.ticker.contains { $0.text.contains("Gulf of Plenty (Gulf of Mexico)") }, "the news gives both names")
        let f = try XCTUnwrap(MapFeatures.feature("GEO_GULF_MEXICO"))
        XCTAssertEqual(MapFeatures.shownName(f, in: gs), "Gulf of Plenty")
        XCTAssertEqual(MapFeatures.newsName(f, in: gs), "Gulf of Plenty (Gulf of Mexico)")
        let usesIt = gs.shadow.powerPlays.featureRecognition["GEO_GULF_MEXICO"]?.contains("MEX") ?? false
        XCTAssertEqual(gs.getCountry(id: "MEX")?.diplomaticRelations["USA"] ?? 0, mx + (usesIt ? 1 : -3))
        XCTAssertEqual(MapFeatures.match("Gulf of Plenty", in: gs)?.id, "GEO_GULF_MEXICO")
        XCTAssertTrue(e.renamePlace("GEO_GULF_MEXICO", to: "Gulf of Mexico"))
        XCTAssertNil(gs.shadow.powerPlays.featureNames["GEO_GULF_MEXICO"])
    }

    @MainActor
    func testRenameDepartmentAndContentCheck() throws {
        let e = PPFixtures.engine()
        let gs = try XCTUnwrap(e.gameState)
        gs.actionsUsedThisTurn = gs.actionsPerTurn
        XCTAssertTrue(e.executeOrder(GameOrder(kind: .renamePlace, target: "DEPT_DEFENSE", detail: "Department of War")) )
        XCTAssertEqual(Departments.title(forRole: "defense", in: gs), "Secretary of War")
        XCTAssertNotNil(e.renamePlaceProblem("DEPT_WAR", to: "X"), "no Department of War in 2025 by law")
        XCTAssertNotNil(e.renamePlaceProblem("GEO_ALPS", to: "Alps\nNew"))
        XCTAssertNotNil(e.renamePlaceProblem("GEO_ALPS", to: "see https://example.com"))
        XCTAssertNotNil(e.renamePlaceProblem("GEO_ALPS", to: String(repeating: "A", count: 200)))
        let none = PPFixtures.plan(e, "rename the Pentagon to Department of Peace")
        XCTAssertEqual(none?.orders.first?.target, "DEPT_DEFENSE", "free with no actions left")
    }
}
