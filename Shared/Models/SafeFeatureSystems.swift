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
        // 10% chance per AI country to send message
        for country in countries where !country.isPlayerControlled && !country.isDestroyed {
            if Double.random(in: 0...1) < 0.1 {
                let messages = [
                    "We demand you cease military buildup immediately.",
                    "Your actions are provocative. We propose non-aggression pact.",
                    "We request $5B economic aid to stabilize our economy."
                ]
                generateMessage(from: country.id, content: messages.randomElement()!, turn: turn)
            }
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
