//
//  SafeFeatureSystems.swift
//  Global Thermal Nuclear War
//
//  Thread-safe implementations of advanced features
//  Created by Jordan Koch on 2025-12-12.
//

import Foundation
import SwiftUI

// MARK: - Intelligence System (Thread-Safe)

class SafeIntelligenceService: ObservableObject {
    static let shared = SafeIntelligenceService()

    @Published var activeOperations: [SafeSpyOperation] = []
    @Published var spyPoints: Int = 100

    private init() {}

    nonisolated func launchOperation(type: String, target: String, turn: Int) {
        Task { @MainActor in
            let op = SafeSpyOperation(type: type, target: target, startTurn: turn)
            activeOperations.append(op)
            spyPoints -= 20
        }
    }

    func processTurn() {
        for i in activeOperations.indices.reversed() {
            activeOperations[i].turnsRemaining -= 1
            if activeOperations[i].turnsRemaining <= 0 {
                activeOperations.remove(at: i)
            }
        }
        spyPoints = min(100, spyPoints + 10)
    }
}

struct SafeSpyOperation: Identifiable {
    let id = UUID()
    let type: String
    let target: String
    let startTurn: Int
    var turnsRemaining: Int = 3
}

// MARK: - Diplomacy System (Thread-Safe)

class SafeDiplomacyService: ObservableObject {
    static let shared = SafeDiplomacyService()

    @Published var messages: [SafeDiplomaticMessage] = []

    private init() {}

    nonisolated func generateMessage(from: String, content: String, turn: Int) {
        Task { @MainActor in
            let msg = SafeDiplomaticMessage(from: from, content: content, turn: turn)
            messages.insert(msg, at: 0)
        }
    }

    func processTurn(countries: [Country], turn: Int) {
        // Identify the player country
        guard let playerCountry = countries.first(where: { $0.isPlayerControlled }) else { return }
        let playerID = playerCountry.id

        // Pre-compute player's actual behaviour to make messages relevant
        let playerAtWar = !playerCountry.atWarWith.isEmpty
        let playerLaunchedNukes = playerCountry.nuclearWarheads < 50 && turn > 3  // rough proxy
        let playerHasSanctions = !playerCountry.economicSanctions.isEmpty

        for country in countries where !country.isPlayerControlled && !country.isDestroyed {
            // 10% base chance — higher if country has reason to care
            let relationToPlayer = country.diplomaticRelations[playerID] ?? 0
            let isHostile = relationToPlayer < -40 || country.atWarWith.contains(playerID)
            let isAlly    = relationToPlayer > 60
            let messageChance = isHostile ? 0.20 : isAlly ? 0.05 : 0.08

            guard Double.random(in: 0...1) < messageChance else { continue }

            // Modern vs pre-modern tone
            let isModernEra = turn > 0   // use actual era, not turn count

            // Select message BASED ON ACTUAL GAME SITUATION
            let message: String

            if country.atWarWith.contains(playerID) {
                // We are at war with the player
                let warMessages = isModernEra ? [
                    "This aggression will not stand. We will defend ourselves.",
                    "Your forces have crossed the line. Prepare for full retaliation.",
                    "We call on the international community to condemn this attack.",
                    "Our military is at full readiness. Do not escalate further."
                ] : [
                    "Your armies have violated our sovereign territory. We shall resist.",
                    "This unprovoked aggression will be met with righteous force.",
                    "We appeal to all nations to condemn this act of war.",
                    "Our forces stand ready. The blood of innocents is on your hands."
                ]
                message = warMessages.randomElement()!

            } else if isHostile {
                // Hostile but not at war — warn about ACTUAL player behavior
                if playerAtWar {
                    let messages = isModernEra ? [
                        "Your warmongering threatens regional stability. We are watching.",
                        "The wars you wage have consequences beyond your borders.",
                        "We urge an immediate ceasefire before this conflict spreads."
                    ] : [
                        "Your military campaigns disturb the peace of our region.",
                        "We counsel restraint before this conflict claims more lives.",
                        "The nations of this region observe your actions with alarm."
                    ]
                    message = messages.randomElement()!
                } else if playerHasSanctions {
                    let messages = isModernEra ? [
                        "Your economic pressure on our allies is noted and condemned.",
                        "Sanctions are an act of economic warfare. We stand in solidarity.",
                        "These trade restrictions violate the norms of civilized relations."
                    ] : [
                        "Your trade embargoes harm innocent citizens and will be opposed.",
                        "We protest your interference in the commerce of sovereign nations.",
                        "Economic coercion is beneath the dignity of a great nation."
                    ]
                    message = messages.randomElement()!
                } else {
                    // Hostile relations but player hasn't done anything specific
                    let messages = isModernEra ? [
                        "Our nations have differences that require urgent diplomatic attention.",
                        "We propose direct talks to reduce tensions between our peoples.",
                        "The current state of our relations serves neither nation's interests."
                    ] : [
                        "The disputes between our nations demand the attention of wise counsel.",
                        "We propose a congress of representatives to address our differences.",
                        "No good shall come from continued estrangement between our peoples."
                    ]
                    message = messages.randomElement()!
                }

            } else if isAlly {
                // Friendly — supportive messages
                let messages = isModernEra ? [
                    "Our alliance remains strong. You have our full support.",
                    "We stand ready to assist should you require our cooperation.",
                    "The bond between our nations is a cornerstone of stability.",
                    "We look forward to expanding our partnership in the coming year."
                ] : [
                    "Our friendship is a lamp that shall not be extinguished.",
                    "The ties of commerce and goodwill between our nations endure.",
                    "We stand as true friends — in peace and in hardship alike.",
                    "Your prosperity is our prosperity. Our cooperation continues."
                ]
                message = messages.randomElement()!

            } else {
                // Neutral — informational or general diplomatic contact
                let messages = isModernEra ? [
                    "We are open to formal diplomatic relations with your government.",
                    "We propose an exchange of ambassadors to improve communication.",
                    "Mutual recognition of our interests would benefit both nations.",
                    "Our borders remain open to diplomatic contact at your discretion."
                ] : [
                    "We seek formal recognition and exchange of envoys.",
                    "Our nation wishes to establish bonds of mutual commerce.",
                    "We propose a treaty of amity and navigation between our peoples.",
                    "Peaceful intercourse between neighboring nations is a virtue."
                ]
                message = messages.randomElement()!
            }

            generateMessage(from: country.id, content: message, turn: turn)
        }
    }
}

struct SafeDiplomaticMessage: Identifiable {
    let id = UUID()
    let from: String
    let content: String
    let turn: Int
    var read: Bool = false
}

// MARK: - Natural Language (Thread-Safe)

class SafeNLPProcessor: ObservableObject {
    static let shared = SafeNLPProcessor()

    @Published var lastCommand: String = ""
    @Published var lastResponse: String = ""

    private init() {}

    nonisolated func parseCommand(_ input: String, gameState: GameState) -> SafeParsedCommand? {
        let lower = input.lowercased().trimmingCharacters(in: .whitespaces)

        print("[SafeNLP] Parsing: '\(input)'")

        // Check for attack commands
        if lower.contains("attack") || lower.contains("war") || lower.contains("invade") {
            for country in gameState.countries where !country.isPlayerControlled && !country.isDestroyed {
                if lower.contains(country.name.lowercased()) || lower.contains(country.code.lowercased()) {
                    print("[SafeNLP] Matched ATTACK on \(country.name)")
                    return SafeParsedCommand(action: "ATTACK", target: country.id, reason: "War declared on \(country.name)")
                }
            }
        }

        // Check for nuke commands
        if lower.contains("nuke") || lower.contains("nuclear") || lower.contains("launch") {
            for country in gameState.countries where !country.isPlayerControlled && !country.isDestroyed {
                if lower.contains(country.name.lowercased()) || lower.contains(country.code.lowercased()) {
                    print("[SafeNLP] Matched NUKE on \(country.name)")
                    return SafeParsedCommand(action: "NUKE", target: country.id, reason: "Nuclear strike on \(country.name)")
                }
            }
        }

        // Check for build military
        if (lower.contains("build") && lower.contains("military")) || lower.contains("army") || lower.contains("troops") {
            print("[SafeNLP] Matched BUILD_MILITARY")
            return SafeParsedCommand(action: "BUILD_MILITARY", target: nil, reason: "Military buildup ordered")
        }

        // Check for build nukes
        if (lower.contains("build") && (lower.contains("nuke") || lower.contains("nuclear") || lower.contains("warhead"))) {
            print("[SafeNLP] Matched BUILD_NUKES")
            return SafeParsedCommand(action: "BUILD_NUKES", target: nil, reason: "Nuclear weapons production")
        }

        // Check for alliance
        if lower.contains("ally") || lower.contains("alliance") || lower.contains("befriend") {
            for country in gameState.countries where !country.isPlayerControlled && !country.isDestroyed {
                if lower.contains(country.name.lowercased()) || lower.contains(country.code.lowercased()) {
                    print("[SafeNLP] Matched ALLY with \(country.name)")
                    return SafeParsedCommand(action: "ALLY", target: country.id, reason: "Alliance with \(country.name)")
                }
            }
        }

        print("[SafeNLP] No match found for: '\(input)'")
        return nil
    }
}

struct SafeParsedCommand {
    let action: String
    let target: String?
    let reason: String
}
