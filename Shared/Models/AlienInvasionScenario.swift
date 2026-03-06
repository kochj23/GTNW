//
//  AlienInvasionScenario.swift
//  GTNW
//
//  Independence Day-style alien invasion scenario.
//  Available in any era — because the universe doesn't care about your calendar.
//  Created by Jordan Koch on 2026-03-05
//

import Foundation
import SwiftUI

// MARK: - Alien Invasion Scenario

/// The alien invasion scenario — available from any presidential era.
/// Inspired by "Independence Day" (1996). Earth vs. extraterrestrials.
struct AlienInvasionScenario {

    static let scenarioID = "alien_invasion_independence_day"

    /// Build the crisis event for the alien invasion.
    static func buildCrisis(gameState: GameState) -> CrisisEvent {
        let eraYear = gameState.currentYear

        return CrisisEvent(
            type: .falseAlarm,   // reusing type — it's the closest to "unclassified extraordinary event"
            severity: .catastrophic,
            title: "FIRST CONTACT — HOSTILE ALIEN INVASION",
            description: """
            CLASSIFIED: EYES ONLY — PRESIDENT OF THE UNITED STATES

            At \(eraYear), massive alien vessels have entered Earth's atmosphere. \
            15 motherships, each 25 kilometers in diameter, are now positioned over \
            every major capital city on Earth. Washington, London, Moscow, Beijing, \
            Paris, Delhi, and 9 others are currently under shadow.

            All global military forces are on maximum alert. NATO, the Warsaw Pact \
            (if active), and non-aligned nations have all suspended hostilities. \
            Every nuclear power is calculating deterrence options.

            The aliens have shown NO interest in communication. \
            Initial probe attacks have destroyed two fighter squadrons. \
            Conventional weapons appear entirely ineffective. \
            Their shields absorb everything short of a direct nuclear detonation.

            Dr. David Levinson (JPL) has identified a possible 36-hour window in the \
            alien command network. General Grey reports all global forces standing by.

            "Welcome to Earth." — Captain Steven Hiller, USMC

            This is not a drill, Mr. President. What are your orders?
            """,
            affectedCountries: Array(gameState.countries.map { $0.id }.prefix(10)),
            turn: gameState.turn,
            timeLimit: nil,
            options: [
                CrisisOption(
                    title: "Global Nuclear Strike — All nations fire simultaneously",
                    description: "Coordinate a synchronized worldwide nuclear launch at all 15 motherships.",
                    advisorRecommendation: "Secretary of Defense",
                    consequences: CrisisConsequences(
                        relationshipChanges: [:],
                        approvalChange: 0,
                        defconChange: 0,
                        economicImpact: 0,
                        militaryImpact: 0,
                        triggersWar: false,
                        warTarget: nil,
                        message: """
                        The nuclear strike is coordinated. Every nuclear power on Earth fires simultaneously. \
                        The explosions tear through alien hull plating. The shields are down. \
                        But the fallout is catastrophic — global radiation +200. Nuclear winter begins. \
                        The aliens are defeated but Earth pays a terrible price. \
                        Later, mankind rebuilds. The lesson: there had to be a better way.
                        """
                    ),
                    successChance: 0.6
                ),
                CrisisOption(
                    title: "Upload computer virus to alien network",
                    description: "Dr. Levinson has identified a 36-hour window to upload a disabling virus to the alien command network — then all shields drop simultaneously.",
                    advisorRecommendation: "CIA Director",
                    consequences: CrisisConsequences(
                        relationshipChanges: [:],
                        approvalChange: 30,
                        defconChange: 0,
                        economicImpact: 0,
                        militaryImpact: 20,
                        triggersWar: false,
                        warTarget: nil,
                        message: """
                        SHIELDS DOWN ACROSS ALL VESSELS. \
                        Every nation's air force scrambles simultaneously. \
                        F/A-18s, MiGs, Mirages, and Sukhois fill the sky. \
                        \"Good morning\" — and the motherships begin to fall. \
                        Earth is saved. All nations celebrate together. \
                        For one brief moment, humanity was truly united. \
                        +30 approval. All diplomatic relations improve dramatically. \
                        Global radiation: unchanged. This was the good ending.
                        """
                    ),
                    successChance: 0.75
                ),
                CrisisOption(
                    title: "Attempt alien communication — seek negotiated withdrawal",
                    description: "Use radio signals, mathematical patterns, and captured alien technology to attempt first contact. Reagan was always ready for this.",
                    advisorRecommendation: "Secretary of State",
                    consequences: CrisisConsequences(
                        relationshipChanges: [:],
                        approvalChange: -10,
                        defconChange: 0,
                        economicImpact: 0,
                        militaryImpact: 0,
                        triggersWar: false,
                        warTarget: nil,
                        message: """
                        Communication is established. \
                        The alien response is a single repeated message: \"EXTERMINATE.\" \
                        Negotiations have failed. The aliens resume their attack. \
                        You have wasted 12 precious hours. \
                        The window for the computer virus upload is now closing. \
                        Approval -10. Military situation deteriorating. Try another approach — fast.
                        """
                    ),
                    successChance: 0.05
                ),
                CrisisOption(
                    title: "Deploy experimental hydrogen bomb kamikaze strike",
                    description: "One pilot. One fighter. One hydrogen bomb. Fly it directly into the alien weapon port. Someone has to be the hero.",
                    advisorRecommendation: "National Security Advisor",
                    consequences: CrisisConsequences(
                        relationshipChanges: [:],
                        approvalChange: 50,
                        defconChange: 0,
                        economicImpact: 0,
                        militaryImpact: 30,
                        triggersWar: false,
                        warTarget: nil,
                        message: """
                        \"In the words of my generation: UP YOURS!\" \
                        One modified fighter breaks through. \
                        The bomb detonates inside the alien weapon port. \
                        The mothership above Area 51 is destroyed. \
                        Using that signal, all nations launch their attack. \
                        The sky clears. The aliens retreat. \
                        Russell Casse has saved the world. \
                        July 4th will never be the same. \
                        Approval +50. Global morale restored. \
                        All wars on Earth end. All nations allied.
                        """
                    ),
                    successChance: 0.85
                ),
                CrisisOption(
                    title: "Evacuate population underground — concede the surface",
                    description: "Abandon the cities. Move civilization underground. Hope the aliens leave eventually.",
                    advisorRecommendation: "Secretary of Health",
                    consequences: CrisisConsequences(
                        relationshipChanges: [:],
                        approvalChange: -40,
                        defconChange: 0,
                        economicImpact: -500_000_000_000,
                        militaryImpact: -30,
                        triggersWar: false,
                        warTarget: nil,
                        message: """
                        The surface of Earth is abandoned. \
                        Major cities are destroyed. Billions displaced. \
                        The aliens establish surface colonies. \
                        Mankind survives in bunkers and mines. \
                        Civilization is set back 200 years. \
                        The resistance begins. The fight continues underground. \
                        Approval -40. GDP catastrophically damaged. \
                        But humanity survives — to fight another day.
                        """
                    ),
                    successChance: 1.0
                )
            ]
        )
    }

    /// Trigger alien invasion collective defense — all wars stop, all countries become temporary allies.
    static func triggerGlobalUnity(gameState: GameState, gameEngine: GameEngine) {
        // End all active wars
        gameState.activeWars.removeAll()
        for i in gameState.countries.indices {
            gameState.countries[i].atWarWith.removeAll()
        }

        // Dramatically improve all relations (united against common enemy)
        for i in gameState.countries.indices {
            let playerID = gameState.playerCountryID
            gameState.countries[i].diplomaticRelations[playerID] = max(
                gameState.countries[i].diplomaticRelations[playerID] ?? 0, 50
            )
        }

        gameEngine.addLog("", type: .system)
        gameEngine.addLog("!! ALIEN INVASION — GLOBAL UNITY PROTOCOL ACTIVATED !!", type: .critical)
        gameEngine.addLog("All active wars suspended. All nations aligned against the common threat.", type: .warning)
        gameEngine.addLog("The world has never been so united — or so close to annihilation.", type: .info)
    }
}

// MARK: - GameEngine extension

extension GameEngine {

    /// Check if the alien invasion should be triggered (random event, very rare).
    /// Can be triggered from any presidential era.
    func checkForAlienInvasion() {
        guard let gameState = gameState else { return }
        guard crisisManager.activeCrisis == nil else { return }

        // 0.1% chance per turn — very rare but possible in any era
        // Also triggerable via the What If system
        if Double.random(in: 0...1) < 0.001 {
            triggerAlienInvasion()
        }
    }

    func triggerAlienInvasion() {
        guard let gameState = gameState else { return }

        let crisis = AlienInvasionScenario.buildCrisis(gameState: gameState)
        crisisManager.presentCrisis(crisis)

        // Trigger global unity
        AlienInvasionScenario.triggerGlobalUnity(gameState: gameState, gameEngine: self)

        self.gameState = gameState
    }
}

// MARK: - What If Scenario Entry

extension Scenario {
    static let alienInvasion = Scenario(
        name: "Independence Day",
        year: 0,  // Any era
        desc: "Massive alien vessels appear over every major capital. Earth has 36 hours.",
        objective: "Defeat the alien invasion and save Earth. By any means necessary.",
        defcon: .defcon1,
        wars: [],
        warheads: 0,
        relations: [:],
        events: ["ALIEN INVASION", "GLOBAL UNITY", "SHIELDS UP"],
        difficulty: .nightmare
    )
}
