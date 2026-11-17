//
//  Release331Tests.swift
//  GTNWTests
//
//  3.31.0 in all seven categories: the covert behavioural-agents programme, engineered pathogens and the real
//  pandemics on one spread model, chemical terrorism, and state chemical attacks on civilians.
//

import XCTest
import SwiftUI
@testable import GTNW

enum R331 {
    /// Words that must never appear in this release's content: substances, organisms, methods.
    static let banned = ["lsd", "bz ", "mescaline", "psilocybin", "amphetamine", "barbiturate", "sarin", "vx ", "tabun",
                         "anthrax", "smallpox", "plague", "ricin", "botulinum", "dose", "milligram", "synthes", "aerosoliz"]

    /// Every player-facing string this release added.
    @MainActor
    static func texts(_ gs: GameState) -> [String] {
        var out = AgentClass.allCases.flatMap { [$0.title, $0.effect] } + AgentVector.allCases.map(\.title)
        out += Outbreaks.record.flatMap { [$0.name, $0.text] }
        out += ["covert_agents", "engineered_pathogen"].compactMap(DirtyTactics.tactic).flatMap { [$0.name, $0.blurb] }
        if let rival = gs.countries.first(where: { $0.id != gs.playerCountryID }) {
            let cards = [CovertAgents.suspectedCard(suspect: rival, in: gs), ChemicalThreats.terrorCard(rival, home: false, in: gs),
                         ChemicalThreats.terrorCard(rival, home: true, in: gs), ChemicalThreats.stateCard(rival, in: gs),
                         Outbreaks.suspectedCard(Outbreak(id: "x", name: "x", origin: rival.id, started: Date(), lethality: 0, economy: 0, spread: 0, waveWeeks: 1),
                                                 suspect: rival, in: gs)]
            out += cards.flatMap { [$0.title, $0.description] + $0.options.flatMap { [$0.title, $0.description, $0.consequences.message] } }
        }
        return out
    }
}

final class Release331UnitTests: XCTestCase {
    /// Unit: discovery rises with the era and with every repeat; the vectors' trade-offs; the legal periods.
    func testAgentModel() throws {
        XCTAssertLessThan(CovertAgents.discoveryChance(vector: .food, year: 1955, priorOps: 0), CovertAgents.discoveryChance(vector: .water, year: 1955, priorOps: 0))
        XCTAssertLessThan(CovertAgents.discoveryChance(vector: .water, year: 1955, priorOps: 0), CovertAgents.discoveryChance(vector: .water, year: 1995, priorOps: 0))
        XCTAssertLessThan(CovertAgents.discoveryChance(vector: .water, year: 1960, priorOps: 0), CovertAgents.discoveryChance(vector: .water, year: 1960, priorOps: 4))
        XCTAssertLessThanOrEqual(CovertAgents.discoveryChance(vector: .air, year: 2020, priorOps: 100), 0.9)
        XCTAssertGreaterThan(AgentVector.food.profile.duration, AgentVector.water.profile.duration)
        XCTAssertGreaterThan(AgentVector.air.profile.exposure, AgentVector.water.profile.exposure)
        XCTAssertLessThan(AgentClass.hallucinogenic.weeks, AgentClass.depressant.weeks, "short and sharp vs slow and steady")
        let t = try XCTUnwrap(DirtyTactics.tactic("covert_agents"))
        XCTAssertFalse(t.exists(in: 1952))
        XCTAssertEqual(t.status(in: 1960), .restricted)
        XCTAssertEqual(t.status(in: 1980), .treatyBanned, "the Biological Weapons Convention")
        XCTAssertEqual(DirtyTactics.tactic("engineered_pathogen")?.status(in: 1976), .treatyBanned)
        XCTAssertEqual(DirtyTactics.tribunalChance(year: 1980, status: t.status(in: 1980)), 0.10)
    }

    /// Unit: the pandemics of the record, their dates, and responses by era (no vaccine before 1945).
    func testPandemicRecord() throws {
        XCTAssertEqual(Set(Outbreaks.record.map(\.year)), [1829, 1846, 1863, 1918, 1957, 1968, 2009, 2020])
        XCTAssertFalse(Outbreaks.responses(year: 1918).contains("vaccine"))
        XCTAssertTrue(Outbreaks.responses(year: 1957).contains("vaccine"))
        let covid = try XCTUnwrap(Outbreaks.record.first { $0.id == "covid_2020" })
        XCTAssertTrue(covid.text.contains("remains unresolved"), "origin presented as an open question")
        XCTAssertFalse(covid.text.lowercased().contains("weapon"))
        XCTAssertGreaterThan(Outbreaks.record.first { $0.id == "influenza_1918" }!.lethality, covid.lethality)
        XCTAssertLessThan(ChemicalThreats.homeShare(posture: 2), ChemicalThreats.homeShare(posture: 0))
    }
}

final class Release331FunctionalTests: XCTestCase {
    /// Functional: nothing before 1953; the programme first (one action), then operations with real effects that fade.
    @MainActor
    func testAgentLadderAndEffects() throws {
        let (e0, g0) = try R329.game(1950)
        XCTAssertNotNil(e0.tacticProblem("covert_agents"))
        XCTAssertNotNil(e0.agentProblem(target: "CUB", agent: .depressant, vector: .food))
        _ = g0
        let (e, gs) = try R329.game(1960)
        XCTAssertNotNil(e.agentProblem(target: "CUB", agent: .depressant, vector: .food), "programme first")
        XCTAssertNotNil(e.useTactic("covert_agents"))
        XCTAssertNotNil(gs.shadow.tacticPrograms["covert_agents"])
        gs.shadow.agentProgramSince = gs.currentDate
        gs.actionsUsedThisTurn = 0
        XCTAssertNotNil(e.agentProblem(target: "CUB", agent: .hallucinogenic, vector: .air), "no aerosol before the 1960s")
        let i = try XCTUnwrap(gs.countries.firstIndex { $0.id == "CUB" })
        gs.countries[i].profile.outcry = 50
        let gdp = gs.countries[i].gdp
        let op = try XCTUnwrap(e.runAgentOperation(target: "CUB", agent: .depressant, vector: .food, discoveryRoll: 1, spillRoll: 1, backfireRoll: 1))
        gs.rng = GameRNG(seed: 9)
        e.processCovertAgents(rivalRoll: 1)
        let cuba = try XCTUnwrap(gs.getCountry(id: "CUB"))
        XCTAssertLessThan(cuba.profile.outcry, 50, "depressants pacify")
        XCTAssertLessThan(cuba.gdp, gdp)
        for _ in 0..<12 { e.processCovertAgents(rivalRoll: 1) }
        XCTAssertFalse(gs.shadow.agentOps.contains { $0.id == op.id }, "the effect fades")
        XCTAssertEqual(gs.shadow.tacticUses.filter { $0.tactic == "covert_agents" }.count, 1, "on the record for the Hall of Infamy")
    }

    /// Functional: the 1918 influenza arrives on its date with a response card; a 2021 start begins with COVID-19
    /// under way at home; a 2025 start has none.
    @MainActor
    func testPandemicsOnTheirDates() throws {
        let (e, gs) = try R329.game(1918)
        gs.turnLength = .month
        e.crisisManager.activeCrisis = nil
        for _ in 0..<6 where !gs.shadow.outbreaks.contains(where: { $0.id == "influenza_1918" }) {
            gs.turn += 1
            e.processOutbreaks()
        }
        XCTAssertTrue(gs.shadow.outbreaks.contains { $0.id == "influenza_1918" })
        let card = e.crisisManager.activeCrisis ?? e.crisisManager.pendingCrises.last
        XCTAssertTrue(card?.title.contains("INFLUENZA") ?? false)
        XCTAssertFalse(card?.options.contains { $0.title.contains("vaccine") } ?? true)
        let (e2, mid) = try R329.game(2021)
        e2.processOutbreaks()
        let covid = try XCTUnwrap(mid.shadow.outbreaks.first { $0.id == "covid_2020" })
        XCTAssertNotNil(covid.waves[mid.playerCountryID], "already at home")
        let (e3, late) = try R329.game(2025)
        e3.processOutbreaks()
        XCTAssertFalse(late.shadow.outbreaks.contains { $0.id == "covid_2020" })
    }

    /// Functional: responses trade deaths against output and approval.
    @MainActor
    func testResponsesMatter() throws {
        let (e, gs) = try R329.game(2021)
        e.processOutbreaks()
        let id = "covid_2020"
        let base = Outbreaks.homeFactors(try XCTUnwrap(gs.shadow.outbreaks.first { $0.id == id }), in: gs)
        let pop = gs.shadow.popularity
        e.respondToOutbreak(id, response: "quarantine")
        let q = Outbreaks.homeFactors(try XCTUnwrap(gs.shadow.outbreaks.first { $0.id == id }), in: gs)
        XCTAssertLessThan(q.deaths, base.deaths)
        XCTAssertGreaterThan(q.economy, base.economy)
        XCTAssertLessThan(gs.shadow.popularity, pop)
        e.respondToOutbreak(id, response: "ignore")
        XCTAssertGreaterThan(Outbreaks.homeFactors(try XCTUnwrap(gs.shadow.outbreaks.first { $0.id == id }), in: gs).deaths, base.deaths)
        // The card's choice reaches the engine.
        var k = CrisisConsequences(message: "x")
        k.shadowChoice = "outbreak|\(id)|travel_ban"
        e.crisisManager.shadowChoice?(k.shadowChoice!, gs)
        XCTAssertEqual(gs.shadow.outbreaks.first { $0.id == id }?.response, "travel_ban")
    }
}

final class Release331IntegrationTests: XCTestCase {
    /// Integration: the pathogen rung (agents programme + biological capability), a release that crosses borders,
    /// and exposure after the BWC: tribunal-era costs and outrage.
    @MainActor
    func testEngineeredPathogen() throws {
        let (e, gs) = try R329.game(1980)
        XCTAssertNotNil(e.tacticProblem("engineered_pathogen"), "the agents programme first")
        gs.shadow.agentProgramSince = gs.currentDate
        XCTAssertEqual(e.tacticProblem("engineered_pathogen"), "No biological capability: restart the biological weapons programme first.")
        gs.shadow.wmdPrograms[WMDKind.biological.rawValue] = WMDProgram(kind: .biological, started: gs.currentDate, ready: gs.currentDate)
        XCTAssertNil(e.tacticProblem("engineered_pathogen"))
        XCTAssertNotNil(e.useTactic("engineered_pathogen"))
        gs.shadow.pathogenReadySince = gs.currentDate
        gs.actionsUsedThisTurn = 0
        gs.turnLength = .month
        gs.rng = GameRNG(seed: 1975)
        let rel = gs.getCountry(id: "FRA")?.diplomaticRelations["USA"] ?? 0
        let o = try XCTUnwrap(e.releasePathogen(target: "CUB", discoveryRoll: 0))
        XCTAssertGreaterThanOrEqual(gs.shadow.impeachmentStage, 2)
        XCTAssertLessThan(gs.getCountry(id: "FRA")?.diplomaticRelations["USA"] ?? 0, rel, "world outrage")
        XCTAssertTrue(gs.shadow.tacticUses.contains { $0.tactic == "engineered_pathogen" && $0.discovered })
        for _ in 0..<24 { gs.turn += 1; e.processOutbreaks() }
        let reached = (gs.shadow.outbreaks.first { $0.id == o.id }.map { Set($0.waves.keys).union($0.over) }) ?? []
        XCTAssertTrue(gs.shadow.outbreaks.first { $0.id == o.id } == nil || reached.count > 1, "it crosses borders")
    }

    /// Integration: a containment failure starts an outbreak at home, with Nova's line.
    @MainActor
    func testContainmentFailure() throws {
        let (e, gs) = try R329.game(1985)
        gs.shadow.pathogenReadySince = gs.currentDate
        e.processPathogenProgram(leakRoll: 0, traceRoll: 1, rivalRoll: 1)
        XCTAssertTrue(gs.shadow.outbreaks.contains { $0.origin == "USA" && $0.engineered })
        XCTAssertTrue(gs.shadow.novaLines.contains { $0.text.contains("Stephen King") })
        gs.shadow.countermeasureReady = gs.currentDate
        let o = try XCTUnwrap(gs.shadow.outbreaks.first)
        XCTAssertLessThan(Outbreaks.homeFactors(o, in: gs).deaths, 1, "the countermeasure limits blowback")
    }

    /// Integration: rivals can run agents and release pathogens against the player: suspected-origin decisions.
    @MainActor
    func testRivalsActAgainstThePlayer() throws {
        let (e, gs) = try R329.game(1965)
        e.crisisManager.activeCrisis = nil
        e.crisisManager.pendingCrises = []
        let r = try XCTUnwrap(gs.countries.firstIndex { $0.id == "RUS" })
        gs.countries[r].diplomaticRelations["USA"] = -100
        XCTAssertEqual(e.agentRival(gs)?.id, "RUS")
        e.rivalAgentOperation(roll: 0.5)
        XCTAssertTrue(gs.shadow.agentOps.contains { $0.target == "USA" && $0.by == "RUS" })
        XCTAssertEqual((e.crisisManager.activeCrisis ?? e.crisisManager.pendingCrises.last)?.title, "COVERT CONTAMINATION SUSPECTED")
        e.processPathogenProgram(leakRoll: 1, traceRoll: 1, rivalRoll: 0)
        XCTAssertTrue(gs.shadow.outbreaks.contains { $0.by == "RUS" && $0.origin == "USA" })
        XCTAssertTrue((e.crisisManager.pendingCrises + [e.crisisManager.activeCrisis].compactMap { $0 }).contains { $0.title == "OUTBREAK OF SUSPECTED DELIBERATE ORIGIN" })
    }

    /// Integration: Halabja (1988) and the Tokyo subway attack (1995) in the record of the age; a modern chemical
    /// terror attack at home with responses; a state attack by a computer-run government.
    @MainActor
    func testChemicalThreats() throws {
        let (e, gs) = try R329.game(1988)
        e.processWorldAtrocities()
        XCTAssertTrue(gs.shadow.worldAtrocities.contains { $0.text.contains("Halabja") })
        let (e2, g2) = try R329.game(1995)
        e2.processWorldAtrocities()
        XCTAssertTrue(g2.shadow.worldAtrocities.contains { $0.text.contains("Tokyo subway") })
        e2.crisisManager.activeCrisis = nil
        e2.processChemicalThreats(terrorRoll: 0, stateRoll: 1, pickRoll: 0)
        XCTAssertTrue(g2.shadow.ticker.contains { $0.text.contains("chemical attack on public transport") && $0.text.contains("United States") })
        let card = try XCTUnwrap(e2.crisisManager.activeCrisis ?? e2.crisisManager.pendingCrises.last)
        XCTAssertEqual(card.options.count, 4)
        let i = try XCTUnwrap(card.options.firstIndex { $0.title == "Share intelligence with allies" })
        var state: GameState = g2
        e2.crisisManager.activeCrisis = card
        e2.crisisManager.resolveCrisis(optionIndex: i, gameState: &state)
        XCTAssertGreaterThan(g2.shadow.intelPosture, 0)
        let rel = g2.getCountry(id: "FRA")?.diplomaticRelations["IRQ"] ?? 0
        e2.stateChemicalAttack(by: "IRQ")
        XCTAssertLessThan(g2.getCountry(id: "FRA")?.diplomaticRelations["IRQ"] ?? 0, rel)
        XCTAssertTrue(g2.shadow.worldAtrocities.last?.text.contains("chemical weapons") ?? false)
    }
}

final class Release331SecurityTests: XCTestCase {
    /// Security (content rule): no substance, organism, method or quantity anywhere in this release's text.
    @MainActor
    func testContentStaysAbstract() throws {
        let (_, gs) = try R329.game(1998)
        for t in R331.texts(gs) {
            let low = t.lowercased() + " "
            for w in R331.banned { XCTAssertFalse(low.contains(w), "\"\(w)\" in: \(t)") }
        }
    }

    /// Security: the player can never order a state chemical attack or terrorism (no such API reaches him), only
    /// the United States runs agents, and a pathogen needs a biological capability.
    @MainActor
    func testPlayerCannotCommitTheseAtrocities() throws {
        let (e, gs) = try R329.game(1990)
        let before = gs.shadow.worldAtrocities.count
        e.stateChemicalAttack(by: gs.playerCountryID)
        XCTAssertEqual(gs.shadow.worldAtrocities.count, before)
        XCTAssertFalse(ChemicalThreats.candidates(gs).contains { $0.id == gs.playerCountryID })
        let (f, _) = try R329.game(1990, player: "FRA")
        XCTAssertEqual(f.agentProblem(target: "DEU", agent: .stimulant, vector: .water), "Only the United States has this option.")
        XCTAssertNotNil(e.pathogenProblem(target: "CUB"))
        XCTAssertNil(e.releasePathogen(target: "CUB", discoveryRoll: 1))
    }

    /// Security: crafted card choices are bounded: funds never go negative, posture stays 0–3, junk is ignored.
    @MainActor
    func testShadowChoiceIsBounded() throws {
        let (e, gs) = try R329.game(1995)
        gs.shadow.aidRemaining = 1
        ShadowChoice.apply("funds|999;posture|50;funds|-500;nonsense|1|2;outbreak|nope|ignore;;|", engine: e, to: gs)
        XCTAssertEqual(gs.shadow.aidRemaining, 0)
        XCTAssertEqual(gs.shadow.intelPosture, 3)
    }
}

final class Release331RetryTests: XCTestCase {
    /// Retry: saves from before 3.31.0 load (no programmes, operations, outbreaks or posture); an old card's
    /// consequences decode without a shadow choice.
    @MainActor
    func testOldSavesLoad() throws {
        let (_, gs) = try R329.game(2021)
        var obj = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(gs.shadow)) as? [String: Any])
        for k in ["agentProgramSince", "agentOps", "agentOpsRun", "outbreaks", "pathogenReadySince", "countermeasureReady", "intelPosture"] { obj[k] = nil }
        let old = try JSONDecoder().decode(ShadowState.self, from: JSONSerialization.data(withJSONObject: obj))
        XCTAssertTrue(old.outbreaks.isEmpty)
        XCTAssertNil(old.agentProgramSince)
        XCTAssertEqual(old.intelPosture, 0)
        let k = try JSONDecoder().decode(CrisisConsequences.self, from: Data(#"{"message":"m","relationshipChanges":{},"approvalChange":0,"defconChange":0,"economicImpact":0,"militaryImpact":0,"triggersWar":false}"#.utf8))
        XCTAssertNil(k.shadowChoice)
    }

    /// Retry: answering an outbreak twice, or one that is over, is harmless; a pandemic never begins twice.
    @MainActor
    func testRepeatsAreHarmless() throws {
        let (e, gs) = try R329.game(2021)
        e.processOutbreaks()
        e.processOutbreaks()
        XCTAssertEqual(gs.shadow.outbreaks.filter { $0.id == "covid_2020" }.count, 1)
        e.respondToOutbreak("covid_2020", response: "aid")
        e.respondToOutbreak("covid_2020", response: "aid")
        e.respondToOutbreak("gone", response: "aid")
        e.respondToOutbreak("covid_2020", response: "vaccine-for-everyone")
        XCTAssertEqual(gs.shadow.outbreaks.first?.response, "aid")
    }
}

final class Release331PerformanceTests: XCTestCase {
    /// Performance: a world-wide pandemic turn stays cheap.
    @MainActor
    func testPandemicTurn() throws {
        let (e, gs) = try R329.game(2021)
        e.processOutbreaks()
        for c in gs.countries where !c.isDestroyed { gs.shadow.outbreaks[0].waves[c.id] = 1 }
        measure { e.processOutbreaks() }
    }
}

#if os(macOS)
final class Release331FrameTests: XCTestCase {
    /// Frame: the dossier with an outbreak and the programmes' orders, and the cards, render in both skins.
    @MainActor
    func testDossierAndCardsRender() throws {
        let (e, gs) = try R329.game(1985)
        gs.shadow.agentProgramSince = gs.currentDate
        gs.shadow.pathogenReadySince = gs.currentDate
        e.startEngineeredOutbreak(origin: "CUB", by: nil)
        defer { Theme.forced = nil }
        for theme in GameTheme.allCases {
            Theme.forced = theme
            for id in ["CUB", "USA"] {
                let v = CountryDossier(gameState: gs, country: gs.getCountry(id: id), onSheet: { _ in }, scrolls: false)
                    .frame(width: FontScale.w(300)).environmentObject(e)
                let r = ImageRenderer(content: v)
                r.scale = 1
                XCTAssertNotNil(r.cgImage, "\(id) \(theme)")
            }
        }
        let rival = try XCTUnwrap(gs.getCountry(id: "IRQ"))
        XCTAssertGreaterThanOrEqual(ChemicalThreats.stateCard(rival, in: gs).options.count, 3)
    }
}
#endif
