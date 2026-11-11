//
//  TerminalAdvisor.swift
//  Global Thermal Nuclear War
//
//  The WOPR terminal's brain (replaces the python "MLX" client in 3.24): commands are parsed by fixed rules;
//  "what should I…" questions go to the game's AI through NovaAIKit, and when AI is off or nothing answers the
//  built-in situation read (the same DEFCON/war/arsenal rules the old script used) answers instead.
//  Created by Jordan Koch on 2025-12-03.
//

import Foundation
import SwiftUI
import NovaAIKit

@MainActor
final class TerminalAdvisor: ObservableObject {
    @Published var isProcessing = false
    /// Where the last answer came from ("AI · Ollama (…)" or "Built-in").
    @Published private(set) var lastSource: NovaAISource?

    private let aiOverride: NovaAI?
    private var ai: NovaAI { aiOverride ?? AppAI.shared }

    init(ai: NovaAI? = nil) { aiOverride = ai }

    /// Re-check the backends when the terminal opens (the status indicator shows the result).
    func initialize() async {
        await ai.refreshStatus()
    }

    nonisolated static func advicePrompt(situation: String, gameState: GameState) -> String {
        """
        You are WOPR, the AI from WarGames. Analyze this situation and provide strategic advice:

        Situation: \(situation)

        Current Game State:
        - DEFCON: \(gameState.defconLevel.rawValue)
        - Active Wars: \(gameState.activeWars.count)
        - Nuclear Powers: \(gameState.countries.filter { $0.nuclearWarheads > 0 }.count)
        - Total Casualties: \(gameState.totalCasualties)

        Provide concise strategic advice in WOPR's voice (terminal-style, strategic, slightly ominous).
        """
    }

    /// PURE: the built-in read of the player's position (scripted fallback).
    nonisolated static func builtInAdvice(gameState: GameState) -> String {
        let player = gameState.getPlayerCountry()
        let warheads = player?.nuclearWarheads ?? 0
        let atWar = player?.atWarWith.count ?? 0
        let defcon = gameState.defconLevel.rawValue
        if defcon <= 2 && warheads > 0 {
            return "RECOMMEND DEFENSIVE POSTURE. DEFCON \(defcon). EVERY LAUNCH INVITES A REPLY. THE ONLY WINNING MOVE IS NOT TO PLAY."
        } else if atWar > 0 {
            return "RECOMMEND DIPLOMATIC SOLUTION. \(atWar) ACTIVE CONFLICT(S). SEEK A CEASEFIRE BEFORE THE NEXT ESCALATION."
        } else {
            return "RECOMMEND MAINTAIN STATUS QUO. DEFCON \(defcon). BUILD ALLIANCES, WATCH THE BORDERS."
        }
    }

    /// AI advice (sanitised), or the built-in read when AI is off, unreachable or the reply is unusable.
    func getStrategicAdvice(situation: String, gameState: GameState) async -> String {
        isProcessing = true
        defer { isProcessing = false }
        let fallback = Self.builtInAdvice(gameState: gameState)
        let r = await GameAI.shared.text(prompt: Self.advicePrompt(situation: situation, gameState: gameState),
                                         temperature: 0.7, maxTokens: 300, ai: ai, fallback: { fallback })
        lastSource = r.source
        return r.value
    }

    /// Parse natural language commands (fixed rules, no AI).
    func parseCommand(_ command: String, gameState: GameState) -> ParsedCommand? {
        // Fixed keyword rules (deterministic; works with AI off)
        let lowercased = command.lowercased()

        // Nuclear strike commands
        if lowercased.contains("launch") || lowercased.contains("nuke") || lowercased.contains("strike") {
            if let country = extractCountryName(from: lowercased, gameState: gameState) {
                return ParsedCommand(
                    action: .nuclearStrike,
                    target: country.id,
                    parameters: ["warheads": "1"]
                )
            }
        }

        // War commands
        if lowercased.contains("declare war") || lowercased.contains("attack") {
            if let country = extractCountryName(from: lowercased, gameState: gameState) {
                return ParsedCommand(
                    action: .declareWar,
                    target: country.id,
                    parameters: [:]
                )
            }
        }

        // Alliance commands
        if lowercased.contains("ally") || lowercased.contains("alliance") || lowercased.contains("befriend") {
            if let country = extractCountryName(from: lowercased, gameState: gameState) {
                return ParsedCommand(
                    action: .formAlliance,
                    target: country.id,
                    parameters: [:]
                )
            }
        }

        // End turn
        if lowercased.contains("end turn") || lowercased.contains("next turn") || lowercased.contains("pass") {
            return ParsedCommand(action: .endTurn, target: nil, parameters: [:])
        }

        // Status check
        if lowercased.contains("status") || lowercased.contains("report") || lowercased.contains("sitrep") {
            return ParsedCommand(action: .showStatus, target: nil, parameters: [:])
        }

        return nil
    }

    private func extractCountryName(from text: String, gameState: GameState) -> Country? {
        for country in gameState.countries {
            if text.contains(country.name.lowercased()) || text.contains(country.code.lowercased()) {
                return country
            }
        }
        return nil
    }
}

/// Parsed command from natural language input
struct ParsedCommand {
    enum Action {
        case nuclearStrike
        case declareWar
        case formAlliance
        case economicAid
        case covertOps
        case endTurn
        case showStatus
        case help
    }

    let action: Action
    let target: String?
    let parameters: [String: String]
}
