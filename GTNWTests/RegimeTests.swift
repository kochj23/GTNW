//
//  RegimeTests.swift
//  GTNWTests
//
//  3.37.0: the player's own government (Regime.swift, RegimeCapability.swift). The mapping from a nation to its
//  form of government and words; each way out of office; a short Vatican City game (no Congress, Senate or
//  President anywhere it can be read; chemical and biological programs "started", not restarted; military options
//  turned into a request to Italy); the United States unchanged; saves.
//

import XCTest
@testable import GTNW

enum R337D {
    @MainActor
    static func game(_ player: String, year: Int = 2025, seed: UInt64 = 337, difficulty: DifficultyLevel = .normal) throws -> (GameEngine, GameState) {
        let e = GameEngine()
        e.startNewGame(playerCountryID: player, difficulty: difficulty, year: year, seed: seed)
        return (e, try XCTUnwrap(e.gameState))
    }

    static func country(_ gs: GameState, _ id: String) throws -> Country { try XCTUnwrap(gs.getCountry(id: id)) }

    /// American words that must not appear in a non-U.S. game's player-facing text. "President" is matched as the
    /// leader's title ("the President", "President's"), not inside another office ("President of the Republic").
    static func americanisms(_ text: String) -> [String] {
        var out: [String] = []
        for w in ["Congress", "Senate", "Vice President", "Joint Chiefs", "White House", "Capitol Hill", "impeach", "Impeach",
                  "Rose Garden", "midterm", "the President", "The President", "presidency", "Presidency", "presidential", "Presidential",
                  "Mr. President", "THE PRESIDENT", "PRESIDENCY"] where text.contains(w) {
            out.append(w)
        }
        return out
    }

    /// Push approval down and outrage up, then run turns until the leader falls (or `turns` pass).
    @MainActor
    static func fall(_ e: GameEngine, _ gs: GameState, turns: Int = 10) {
        for _ in 0..<turns where !gs.gameOver {
            gs.shadow.popularity = 5
            gs.shadow.ruthlessness = 150
            if let pi = gs.countries.firstIndex(where: { $0.id == gs.playerCountryID }) {
                gs.countries[pi].congressionalSupport = 5
                gs.countries[pi].stability = max(gs.countries[pi].stability, 40)   // a removal, not a civil war
                gs.countries[pi].profile.outcry = 0
            }
            e.endTurn()
        }
    }
}

// MARK: - Unit: the mapping

final class RegimeMappingTests: XCTestCase {
    /// Unit: each nation gets the government it actually has, with its removal path.
    @MainActor
    func testRegimeMapping() throws {
        let (_, gs) = try R337D.game("USA")
        let date = gs.currentDate
        func regime(_ id: String) throws -> Regime { try XCTUnwrap(Regime.resolve(try R337D.country(gs, id), on: date), id) }
        XCTAssertNil(Regime.resolve(try R337D.country(gs, "USA"), on: date), "the United States keeps its own words")

        let vat = try regime("VAT")
        XCTAssertEqual(vat.kind, .papacy)
        XCTAssertEqual(vat.removal, .resignationPressure)
        XCTAssertEqual(vat.terms.title, "Pope")
        XCTAssertEqual(vat.terms.legislature, "the College of Cardinals")
        XCTAssertFalse(vat.terms.hasElections)

        XCTAssertEqual(try regime("GBR").kind, .parliamentary)
        XCTAssertEqual(try regime("GBR").removal, .noConfidence)
        XCTAssertEqual(try regime("GBR").terms.title, "Prime Minister")
        XCTAssertEqual(try regime("GBR").terms.legislature, "Parliament")
        XCTAssertEqual(try regime("IRL").kind, .parliamentary, "a parliamentary republic without research data (override)")
        XCTAssertEqual(try regime("IRL").removal, .noConfidence)
        XCTAssertEqual(try regime("DEU").terms.title, "Chancellor")
        XCTAssertEqual(try regime("CHN").kind, .communist)
        XCTAssertEqual(try regime("CHN").removal, .partyCongress)
        XCTAssertEqual(try regime("CHN").terms.legislature, "the Politburo")
        XCTAssertEqual(try regime("CUB").terms.title, "General Secretary")
        XCTAssertEqual(try regime("IRN").kind, .theocracy)
        XCTAssertEqual(try regime("IRN").removal, .council)
        XCTAssertEqual(try regime("IRN").terms.title, "Supreme Leader")
        XCTAssertEqual(try regime("MCO").kind, .monarchy)
        XCTAssertEqual(try regime("MCO").removal, .abdication)
        XCTAssertEqual(try regime("MCO").terms.title, "Prince")
        XCTAssertEqual(try regime("QAT").terms.title, "Emir")
        XCTAssertEqual(try regime("MLI").kind, .military)
        XCTAssertEqual(try regime("MLI").removal, .coup)
        XCTAssertEqual(try regime("MLI").terms.title, "Chairman of the Junta")
        XCTAssertEqual(try regime("BLR").kind, .authoritarian)
        XCTAssertEqual(try regime("BLR").removal, .coup)
        let bra = try regime("BRA")
        XCTAssertEqual(bra.kind, .presidential)
        XCTAssertEqual(bra.removal, .impeachment, "a presidential republic impeaches")
        XCTAssertEqual(bra.terms.legislature, "Congress")

        // Every nation on the board resolves, and its words never leave an American term behind.
        for c in gs.liveCountries where c.id != "USA" {
            let r = try XCTUnwrap(Regime.resolve(c, on: date), c.id)
            let line = r.localize("Congress drafts articles of impeachment. The Vice President and the Joint Chiefs warn the President.")
            XCTAssertFalse(line.contains("Joint Chiefs"), "\(c.id): \(line)")
            if r.terms.title != "President" { XCTAssertFalse(line.contains("the President"), "\(c.id): \(line)") }
            XCTAssertFalse(line.contains("Congress") && r.terms.legislature != "Congress", "\(c.id): \(line)")
            XCTAssertEqual(r.localize(line), line, "\(c.id): localizing twice changes nothing")
        }
    }

    /// Unit: the words, sentence by sentence.
    func testLocalize() {
        let pope = Regime(kind: .papacy, country: "VAT", countryName: "Vatican City", capital: "Vatican City", removal: .resignationPressure)
        XCTAssertEqual(pope.localize("Congress will move to impeach at the next poll."),
                       "Calls for your resignation will come to a head at the next poll.")
        XCTAssertEqual(pope.localize("The Joint Chiefs refuse to support the President."), "The Swiss Guard refuse to support the Pope.")
        XCTAssertEqual(pope.localize("THE PRESIDENT IS DEAD"), "THE POPE IS DEAD")
        XCTAssertEqual(pope.localize("AFTER THE PRESIDENCY"), "AFTER THE PONTIFICATE")
        XCTAssertEqual(pope.localize("Mr. President, I advise against it."), "Holy Father, I advise against it.")
        XCTAssertEqual(pope.localize("Congress votes."), "The College of Cardinals votes.", "a sentence opens with a capital")
        XCTAssertEqual(pope.localize("President Lincoln and the President of France met."), "President Lincoln and the President of France met.",
                       "other people's presidents are left alone")
        XCTAssertEqual(pope.localize("Presidents' Day, Congressman, Housing"), "Presidents' Day, Congressman, Housing", "whole words only")

        let uk = Regime(kind: .parliamentary, country: "GBR", countryName: "United Kingdom", capital: "London", removal: .noConfidence)
        XCTAssertEqual(uk.localize("The House has voted to impeach. The Senate trial begins: two-thirds must vote to convict at the next poll."),
                       RemovalMechanism.noConfidence.stageText(3))
        XCTAssertEqual(uk.localize("Congress votes to stop the President."), "Parliament votes to stop the Prime Minister.")
        XCTAssertEqual(uk.localize("The Vice President speaks from the White House."), "The Deputy Prime Minister speaks from Downing Street.")

        let iran = Regime(kind: .theocracy, country: "IRN", countryName: "Iran", capital: "Tehran", removal: .council)
        XCTAssertEqual(iran.localize("The Vice President briefs the President."), "The President of the Republic briefs the Supreme Leader.",
                       "one pass: the deputy is not rewritten again")
    }

    /// Unit: each way out of office has its stages, its ending and its own headline, with no American words.
    func testEveryRemovalPath() {
        let cases: [(RemovalMechanism, DomesticEnding)] = [
            (.impeachment, .impeached), (.noConfidence, .noConfidence), (.coup, .coup), (.partyCongress, .partyCongress),
            (.juntaDecision, .juntaDecision), (.council, .removedByCouncil), (.resignationPressure, .resigned), (.abdication, .abdicated),
        ]
        for (m, ending) in cases {
            XCTAssertEqual(m.ending, ending)
            XCTAssertFalse(ending.headline.isEmpty)
            XCTAssertTrue(PresidencyAwards.removals.contains(ending), "\(ending) counts as a removal")
            for s in 1...3 {
                let t = m.stageText(s)
                XCTAssertFalse(t.isEmpty)
                if m != .impeachment { XCTAssertTrue(R337D.americanisms(t).isEmpty, "\(m) \(s): \(t)") }
            }
            if m != .impeachment {
                XCTAssertTrue(R337D.americanisms(ending.headline).isEmpty, ending.headline)
                XCTAssertTrue(R337D.americanisms(m.imminentText + m.risingText + m.dropText).isEmpty, "\(m)")
            }
        }
        XCTAssertTrue(DomesticEnding.resigned.headline.contains("2013"), "the historical precedent")
        XCTAssertFalse(DomesticEnding.resigned.servedOut)
    }

    /// Unit: microstates have no forces; the WMD program is restarted only where there was one.
    @MainActor
    func testCapabilities() throws {
        let (_, gs) = try R337D.game("USA")
        for id in ["VAT", "MCO", "SMR", "LIE", "AND", "NRU"] {
            XCTAssertFalse(RegimeCapability.hasMeaningfulMilitary(try R337D.country(gs, id)), id)
        }
        for id in ["USA", "ITA", "GBR", "IRN", "FRA"] {
            XCTAssertTrue(RegimeCapability.hasMeaningfulMilitary(try R337D.country(gs, id)), id)
        }
        XCTAssertTrue(RegimeCapability.hadProgram(.chemical, "RUS"))
        XCTAssertTrue(RegimeCapability.hadProgram(.biological, "GBR"))
        XCTAssertFalse(RegimeCapability.hadProgram(.chemical, "VAT"))
        XCTAssertFalse(RegimeCapability.hadProgram(.biological, "BRA"))
        XCTAssertGreaterThan(RegimeCapability.startLeadYears(.chemical), ArsenalCatalog.restartLeadYears(.chemical))
        XCTAssertEqual(PresidentialAction.restartChemical.title(in: gs), "Restart Chemical Program", "the U.S. title is unchanged")
        XCTAssertEqual(PresidentialAction.airStrike.title(in: gs), "Air Strike")
    }
}

// MARK: - Functional: a short Vatican City game

final class RegimeVaticanGameTests: XCTestCase {
    /// Functional: the Holy See's offices, a crisis card with nothing it cannot do, orders that read "Start" and go
    /// to Italy, then the pressure to resign: no Congress, Senate or President in the ticker, the log, the game-over
    /// reason or the epilogue.
    @MainActor
    func testVaticanGame() throws {
        let (e, gs) = try R337D.game("VAT")
        let r = try XCTUnwrap(gs.shadow.regime)
        XCTAssertEqual(r.kind, .papacy)
        let titles = gs.advisors.filter(\.isActive).map(\.title)
        XCTAssertTrue(titles.contains("Secretary of State"), "\(titles)")
        XCTAssertTrue(titles.contains("Commander of the Swiss Guard"), "\(titles)")
        XCTAssertFalse(titles.contains { $0.contains("President") }, "\(titles)")
        XCTAssertTrue(gs.shadow.ticker.contains { $0.text.contains("Your pontificate begins.") })

        // The ally: Italy, the nearest friendly power that can act.
        let ally = try XCTUnwrap(RegimeCapability.nearestCapableAlly(gs, target: nil))
        XCTAssertEqual(ally.id, "ITA", "Italy's view of us: \(gs.getCountry(id: "ITA")?.diplomaticRelations["VAT"] ?? -999)")

        // Orders: "Start", not "Restart"; military orders are a request to Italy.
        XCTAssertEqual(PresidentialAction.restartChemical.title(in: gs), "Start a Secret Chemical Program")
        XCTAssertEqual(PresidentialAction.restartBiological.title(in: gs), "Start a Secret Biological Program")
        XCTAssertEqual(PresidentialAction.airStrike.title(in: gs), "Ask Italy: Air Strike")
        XCTAssertEqual(PresidentialAction.sendAmbassador.title(in: gs), "Send Ambassador", "diplomacy needs no army")
        e.performAdvisedAction(.restartChemical, targetID: "ITA", advice: nil)
        let program = try XCTUnwrap(gs.shadow.wmdPrograms[WMDKind.chemical.rawValue])
        XCTAssertEqual(GameCalendar.year(of: program.ready) - GameCalendar.year(of: program.started), RegimeCapability.startLeadYears(.chemical))
        XCTAssertTrue(e.logMessages.contains { $0.message.contains("program is started") })
        XCTAssertFalse(e.logMessages.contains { $0.message.contains("restarted") })

        let wasAtWar = gs.getPlayerCountry()?.atWarWith ?? []
        e.performAdvisedAction(.airStrike, targetID: "RUS", advice: nil)
        XCTAssertEqual(gs.getPlayerCountry()?.atWarWith ?? [], wasAtWar, "the Vatican sends no bombers of its own")
        XCTAssertTrue(e.logMessages.suffix(6).contains { $0.message.contains("Italy") }, "Italy answers the request")
        e.performAdvisedAction(.launchNukes, targetID: "RUS", advice: nil)
        XCTAssertTrue(gs.nuclearStrikes.filter { $0.attacker == "VAT" || $0.attacker == "ITA" }.isEmpty, "no ally uses WMD for another")
        XCTAssertTrue(e.logMessages.contains { $0.message.contains("will not use weapons of mass destruction") })

        // The Rogue Nuclear Commander: no "EMP Strike on Silo" of our own, no launch option; a request to Italy instead.
        let card = try XCTUnwrap(e.crisisManager.createCrisis(type: .rogueCommander, gameState: gs))
        e.crisisManager.activeCrisis = nil
        e.crisisManager.presentCrisis(card)
        let shown = try XCTUnwrap(e.crisisManager.activeCrisis)
        let options = shown.options.map(\.title)
        XCTAssertFalse(options.contains("EMP Strike on Silo"), "\(options)")
        XCTAssertFalse(options.contains("Prepare for Launch"), "\(options)")
        XCTAssertFalse(options.contains("Neutralize with Military Strike"), "\(options)")
        XCTAssertTrue(options.contains("Ask Italy: EMP Strike on Silo"), "\(options)")
        XCTAssertTrue(options.contains("Negotiate with Commander"), "\(options)")
        let ask = try XCTUnwrap(shown.options.first { $0.title == "Ask Italy: EMP Strike on Silo" })
        XCTAssertTrue(ask.consequences.message.hasPrefix("Italy"), "the outcome is Italy's decision: \(ask.consequences.message)")
        for o in shown.options {
            XCTAssertTrue(R337D.americanisms(o.title + o.description + o.consequences.message + (o.advisorRecommendation ?? "")).isEmpty,
                          "\(o.title): \(o.advisorRecommendation ?? "")")
        }
        e.crisisManager.activeCrisis = nil
        e.crisisManager.pendingCrises = []

        // The pressure to resign.
        R337D.fall(e, gs)
        XCTAssertTrue(gs.gameOver)
        XCTAssertEqual(gs.shadow.domesticEnding, .resigned)
        XCTAssertTrue(gs.gameOverReason.contains("resign the papacy"), gs.gameOverReason)

        // Nothing American where the player reads it.
        var texts = gs.shadow.ticker.map(\.text) + e.logMessages.map(\.message)
        texts += [gs.gameOverReason, PresidencyEpilogue.verdict(gs, victory: nil), PresidencyEpilogue.library(gs),
                  gs.say("AFTER THE PRESIDENCY"), gs.endingHeadline(.resigned)]
        for t in texts {
            XCTAssertTrue(R337D.americanisms(t).isEmpty, "\(R337D.americanisms(t)): \(t)")
        }
        let verdict = PresidencyEpilogue.verdict(gs, victory: nil)
        XCTAssertTrue(verdict.hasPrefix("The Pope led Vatican City"), verdict)
        XCTAssertTrue(verdict.contains("resigned the papacy"), verdict)
        XCTAssertTrue(PresidencyEpilogue.library(gs).contains("Vatican Apostolic Archive"))
        XCTAssertEqual(gs.say("AFTER THE PRESIDENCY"), "AFTER THE PONTIFICATE")
        XCTAssertFalse(PresidencyAwards.earned(gs, career: PresidencyCareer(), realSeconds: nil).contains("impeached_on_easy"))
    }

    /// Functional: every removal path ends a game in its own words.
    @MainActor
    func testEachRegimeFallsItsOwnWay() throws {
        let cases: [(String, DomesticEnding)] = [("GBR", .noConfidence), ("CHN", .partyCongress), ("IRN", .removedByCouncil),
                                                 ("MCO", .abdicated), ("MLI", .coup), ("BRA", .impeached), ("VAT", .resigned)]
        for (id, ending) in cases {
            let (e, gs) = try R337D.game(id, seed: 7)
            R337D.fall(e, gs)
            XCTAssertTrue(gs.gameOver, id)
            // A presidential republic's upper house may acquit; then it falls again until it is convicted.
            if gs.shadow.domesticEnding != ending, ending == .impeached { R337D.fall(e, gs, turns: 20) }
            XCTAssertEqual(gs.shadow.domesticEnding, ending, id)
            XCTAssertEqual(gs.gameOverReason, gs.endingHeadline(ending), id)
            if id != "BRA" {
                for t in gs.shadow.ticker.map(\.text) + [gs.gameOverReason, PresidencyEpilogue.verdict(gs, victory: nil)] {
                    XCTAssertFalse(t.contains("Congress") || t.contains("Senate") || t.contains("impeach") || t.contains("Vice President"),
                                   "\(id): \(t)")
                }
            }
        }
    }
}

// MARK: - Regression: the United States reads exactly as before

final class RegimeUSRegressionTests: XCTestCase {
    /// Regression: a U.S. game has no regime, every American line is untouched, and impeachment still ends it.
    @MainActor
    func testUnitedStatesUnchanged() throws {
        let (e, gs) = try R337D.game("USA", difficulty: .easy)
        XCTAssertNil(gs.shadow.regime)
        for line in ["Congress has removed you from office.", PopularityModel.impeachmentText(stage: 2),
                     "State of the Union: the President addresses a joint session of Congress.", "THE PRESIDENT IS DEAD",
                     "The Vice President and the Joint Chiefs advise the President from the White House."] {
            XCTAssertEqual(gs.say(line), line)
        }
        XCTAssertEqual(e.advisorWarnings(for: .attack(.airStrike, target: "RUS", size: nil)).map(\.who),
                       e.rawAdvisorWarnings(for: .attack(.airStrike, target: "RUS", size: nil)).map(\.who))
        XCTAssertTrue(e.advisorWarnings(for: .attack(.airStrike, target: "RUS", size: nil)).contains { $0.who == "Vice President" })
        XCTAssertEqual(PresidentialAction.restartBiological.title(in: gs), "Restart Biological Program")
        XCTAssertEqual(PresidencyEpilogue.library(gs).contains("Presidential Library"), true)
        let card = try XCTUnwrap(e.crisisManager.createCrisis(type: .rogueCommander, gameState: gs))
        e.crisisManager.activeCrisis = nil
        e.crisisManager.presentCrisis(card)
        XCTAssertEqual(e.crisisManager.activeCrisis?.options.map(\.title), card.options.map(\.title), "a U.S. card is untouched")
        e.crisisManager.activeCrisis = nil
        e.crisisManager.pendingCrises = []

        R337D.fall(e, gs, turns: 12)
        XCTAssertEqual(gs.shadow.domesticEnding, .impeached)
        XCTAssertEqual(gs.gameOverReason, "Congress has removed you from office.")
        XCTAssertTrue(gs.shadow.ticker.contains { $0.text == "Congress has removed you from office." })
        XCTAssertTrue(gs.shadow.ticker.contains { $0.text == PopularityModel.impeachmentText(stage: 1) })
        XCTAssertTrue(PresidencyEpilogue.verdict(gs, victory: nil).contains("removed from office by Congress"))
    }
}

// MARK: - Saves

final class RegimePersistenceTests: XCTestCase {
    /// Save round-trip: the regime survives a save; an older save (no regime) gets it back on load; a U.S. save
    /// carries none.
    @MainActor
    func testSaveRoundTrip() throws {
        let (_, gs) = try R337D.game("VAT")
        let data = try SaveCodec.encode(gs)
        let back = try SaveCodec.decode(data)
        XCTAssertEqual(back.shadow.regime, gs.shadow.regime)
        XCTAssertEqual(back.shadow.regime?.kind, .papacy)

        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        var obj = try XCTUnwrap(JSONSerialization.jsonObject(with: enc.encode(gs.shadow)) as? [String: Any])
        XCTAssertNotNil(obj["regime"])
        obj["regime"] = nil
        let old = try JSONDecoder().decode(ShadowState.self, from: JSONSerialization.data(withJSONObject: obj))
        XCTAssertNil(old.regime)
        back.shadow = old
        let e2 = GameEngine()
        e2.gameState = back
        e2.refreshRegime()
        XCTAssertEqual(back.shadow.regime?.kind, .papacy, "an older save gets its government back on load")

        let (_, us) = try R337D.game("USA")
        let usObj = try XCTUnwrap(JSONSerialization.jsonObject(with: enc.encode(us.shadow)) as? [String: Any])
        XCTAssertNil(usObj["regime"], "a U.S. save is unchanged")
    }

    /// Determinism: the same seed plays the same Vatican game.
    @MainActor
    func testSameSeedSameGame() throws {
        func play() throws -> [String] {
            let (e, gs) = try R337D.game("VAT", seed: 99)
            e.performAdvisedAction(.airStrike, targetID: "RUS", advice: nil)
            R337D.fall(e, gs, turns: 6)
            return gs.shadow.ticker.map(\.text)
        }
        XCTAssertEqual(try play(), try play())
    }
}
