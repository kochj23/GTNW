//
//  MLXIntegration.swift
//  Global Thermal Nuclear War
//
//  Python MLX integration for AI-driven national decision making
//  Created by Jordan Koch & Claude Code on 2025-12-03.
//

import Foundation
import Combine
import SwiftUI

/// MLX Integration Manager for AI-driven responses
class MLXManager: ObservableObject {
    @Published var isConnected = false
    @Published var lastResponse: String = ""
    @Published var isProcessing = false

    private let pythonPath = "/opt/homebrew/bin/python3"
    private let mlxScriptPath = "/Users/kochj/.mlx/gtnw_advisor.py"
    private var process: Process?

    /// Initialize MLX connection
    func initialize() async {
        // Check if MLX is available
        let mlxAvailable = await checkMLXAvailability()
        if mlxAvailable {
            isConnected = true
            print("MLX toolkit connected successfully")
        } else {
            print("MLX not available, falling back to rule-based AI")
            isConnected = false
        }
    }

    /// Check if MLX Python toolkit is available
    private func checkMLXAvailability() async -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: pythonPath)
        task.arguments = ["-c", "import mlx.core as mx; print('OK')"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            return false
        }
    }

    /// Get AI recommendation for a country's action
    func getCountryAction(country: Country, gameState: GameState) async -> String? {
        guard isConnected else {
            return nil  // Fall back to rule-based
        }

        isProcessing = true
        defer { isProcessing = false }

        // Create context for MLX
        let context = createMLXContext(country: country, gameState: gameState)

        // Call Python MLX script
        let response = await callMLXPython(context: context)

        lastResponse = response ?? "No response"
        return response
    }

    /// Generate strategic advice using MLX
    func getStrategicAdvice(situation: String, gameState: GameState) async -> String {
        guard isConnected else {
            return "MLX not available - using rule-based analysis"
        }

        isProcessing = true
        defer { isProcessing = false }

        let prompt = """
        You are WOPR, the AI from WarGames. Analyze this situation and provide strategic advice:

        Situation: \(situation)

        Current Game State:
        - DEFCON: \(gameState.defconLevel.rawValue)
        - Active Wars: \(gameState.activeWars.count)
        - Nuclear Powers: \(gameState.countries.filter { $0.nuclearWarheads > 0 }.count)
        - Total Casualties: \(gameState.totalCasualties)

        Provide concise strategic advice in WOPR's voice (terminal-style, strategic, slightly ominous).
        """

        let response = await callMLXPython(context: ["prompt": prompt])
        return response ?? "INSUFFICIENT DATA FOR MEANINGFUL ANSWER"
    }

    /// Parse natural language commands
    func parseCommand(_ command: String, gameState: GameState) -> ParsedCommand? {
        // Simple command parsing (can be enhanced with MLX NLP)
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

    // MARK: - Private Methods

    private func createMLXContext(country: Country, gameState: GameState) -> [String: Any] {
        return [
            "country_name": country.name,
            "country_id": country.id,
            "nuclear_warheads": country.nuclearWarheads,
            "at_war_with": country.atWarWith.count,
            "defcon_level": gameState.defconLevel.rawValue,
            "player_country": gameState.playerCountryID,
            "turn": gameState.turn,
            "active_wars": gameState.activeWars.count,
            "alignment": country.alignment.rawValue
        ]
    }

    private func callMLXPython(context: [String: Any]) async -> String? {
        // Convert context to JSON
        guard let jsonData = try? JSONSerialization.data(withJSONObject: context),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return nil
        }

        // Create Python script invocation
        let script = """
        import sys
        import json
        try:
            import mlx.core as mx
            import mlx.nn as nn

            # Parse input
            context = json.loads(sys.argv[1])

            # Simple MLX-based decision (can be much more sophisticated)
            # For now, use context to generate strategic response
            defcon = context.get('defcon_level', 5)
            warheads = context.get('nuclear_warheads', 0)
            at_war = context.get('at_war_with', 0)

            # Simple strategic logic
            if defcon <= 2 and warheads > 0:
                print("RECOMMEND_DEFENSIVE_POSTURE")
            elif at_war > 0:
                print("RECOMMEND_DIPLOMATIC_SOLUTION")
            else:
                print("RECOMMEND_MAINTAIN_STATUS_QUO")

        except Exception as e:
            print(f"ERROR: {e}")
        """

        let task = Process()
        task.executableURL = URL(fileURLWithPath: pythonPath)
        task.arguments = ["-c", script, jsonString]

        let pipe = Pipe()
        task.standardOutput = pipe

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)

            return output
        } catch {
            print("MLX call failed: \(error)")
            return nil
        }
    }

    private func extractCountryName(from text: String, gameState: GameState) -> Country? {
        // Try to find country name in text
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

/// Event logger for tracking all country actions
class EventLogger: ObservableObject {
    @Published var events: [GameEvent] = []
    private let maxEvents = 500

    func log(_ event: GameEvent) {
        events.insert(event, at: 0)

        // Trim old events
        if events.count > maxEvents {
            events = Array(events.prefix(maxEvents))
        }
    }

    func log(_ message: String, type: GameEvent.EventType, country: String? = nil, turn: Int) {
        let event = GameEvent(
            message: message,
            type: type,
            country: country,
            turn: turn,
            timestamp: Date()
        )
        log(event)
    }

    func clear() {
        events.removeAll()
    }

    func getEventsForTurn(_ turn: Int) -> [GameEvent] {
        return events.filter { $0.turn == turn }
    }
}

struct GameEvent: Identifiable, Codable {
    let id = UUID()
    var message: String
    var type: EventType
    var country: String?
    var turn: Int
    var timestamp: Date

    enum EventType: String, Codable {
        case nuclear = "☢️"
        case war = "⚔️"
        case diplomacy = "🤝"
        case economic = "💰"
        case cyber = "💻"
        case intel = "🔍"
        case system = "⚙️"
    }

    var color: Color {
        switch type {
        case .nuclear: return GTNWColors.terminalRed
        case .war: return .orange
        case .diplomacy: return GTNWColors.terminalGreen
        case .economic: return GTNWColors.neonCyan
        case .cyber: return GTNWColors.neonPurple
        case .intel: return GTNWColors.neonBlue
        case .system: return GTNWColors.terminalAmber
        }
    }
}
