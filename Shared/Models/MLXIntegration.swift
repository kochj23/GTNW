//
//  MLXIntegration.swift
//  Global Thermal Nuclear War
//
//  Python MLX integration for AI-driven national decision making
//  Created by Jordan Koch on 2025-12-03.
//

import Foundation
import Combine
import SwiftUI

/// MLX Integration Manager for AI-driven responses
class MLXManager: ObservableObject {
    @Published var isConnected = false
    @Published var lastResponse: String = ""
    @Published var isProcessing = false
    @Published var interactionHistory: [MLXInteraction] = []

    private var detectedPythonPath: String?
    private let mlxScriptPath = "/Users/kochj/.mlx/gtnw_advisor.py"
    private var process: Process?
    private let maxHistory = 20

    /// Initialize MLX connection (using NMAPScanner's detection logic)
    func initialize() async {
        print("[MLX] Starting MLX detection...")

        // Check if MLX is available (check multiple locations like NMAPScanner)
        let mlxAvailable = await checkMLXAvailability()
        if mlxAvailable {
            await MainActor.run {
                isConnected = true
            }
            print("[MLX] ✅ MLX toolkit connected successfully at: \(detectedPythonPath ?? "unknown")")
            logInteraction(type: "System", output: "✅ MLX Toolkit ONLINE")
        } else {
            await MainActor.run {
                isConnected = false
            }
            print("[MLX] ⚠️ MLX not available, falling back to rule-based AI")
            logInteraction(type: "System", output: "⚠️ MLX not detected - using rule-based parsing")
        }
    }

    /// Check if MLX Python toolkit is available (NMAPScanner's multi-location approach)
    private func checkMLXAvailability() async -> Bool {
        // Python locations to check (priority order)
        let pythonPaths = [
            "/Volumes/Data/xcode/NMAPScanner/.venv/bin/python3",  // NMAPScanner venv (if shared)
            "/opt/homebrew/bin/python3",                          // Homebrew M1/M2/M3
            "/usr/local/bin/python3",                             // Homebrew Intel / MacPorts
            "/usr/bin/python3"                                    // System Python
        ]

        for path in pythonPaths {
            guard FileManager.default.fileExists(atPath: path) else {
                print("[MLX] Skipping \(path) - doesn't exist")
                continue
            }

            print("[MLX] Testing \(path)...")
            if await testMLXImport(pythonPath: path) {
                detectedPythonPath = path
                print("[MLX] ✅ Found MLX at: \(path)")
                return true
            }
        }

        print("[MLX] ❌ MLX not found in any Python location")
        return false
    }

    /// Test if MLX can be imported (same test as NMAPScanner)
    private func testMLXImport(pythonPath: String) async -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: pythonPath)
        // Test both mlx.core and mlx_lm like NMAPScanner
        task.arguments = ["-c", "import mlx.core; import mlx_lm; print('OK')"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let success = output.contains("OK")
                print("[MLX] \(pythonPath) result: \(success ? "SUCCESS" : "FAILED")")
                return success
            }
        } catch {
            print("[MLX] \(pythonPath) error: \(error)")
            return false
        }

        return false
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

    /// Parse natural language commands with enhanced AI understanding
    ///
    /// **Enhanced Features**:
    /// - Multiple command variations supported
    /// - Fuzzy country name matching
    /// - Number extraction (warhead counts, money amounts)
    /// - Compound commands
    /// - Intent recognition
    ///
    /// **Author**: Jordan Koch
    func parseCommand(_ command: String, gameState: GameState) -> ParsedCommand? {
        let lowercased = command.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Log command parsing
        logInteraction(type: "Command", input: command, output: "Parsing...")

        // Help commands
        if lowercased.contains("help") || lowercased == "?" {
            logInteraction(type: "Command", input: command, output: "✅ Parsed: HELP")
            return ParsedCommand(action: .help, target: nil, parameters: [:])
        }

        // Nuclear strike commands (many variations)
        let nuclearPatterns = [
            "launch", "nuke", "strike", "fire", "send nuke",
            "nuclear attack", "bomb", "icbm", "missile at"
        ]
        if nuclearPatterns.contains(where: { lowercased.contains($0) }) {
            if let country = extractCountryName(from: lowercased, gameState: gameState) {
                // Extract warhead count if specified
                let warheadCount = extractNumber(from: lowercased) ?? 1
                logInteraction(type: "Command", input: command, output: "✅ Nuclear Strike: \(country.name) (\(warheadCount) warheads)")
                return ParsedCommand(
                    action: .nuclearStrike,
                    target: country.id,
                    parameters: ["warheads": String(warheadCount)]
                )
            }
        }

        // War declaration commands (many variations)
        let warPatterns = [
            "declare war", "attack", "invade", "go to war",
            "fight", "assault", "engage", "start war with"
        ]
        if warPatterns.contains(where: { lowercased.contains($0) }) {
            if let country = extractCountryName(from: lowercased, gameState: gameState) {
                return ParsedCommand(
                    action: .declareWar,
                    target: country.id,
                    parameters: [:]
                )
            }
        }

        // Alliance commands (many variations)
        let alliancePatterns = [
            "ally", "alliance", "befriend", "team up",
            "join forces", "partner with", "make friends",
            "military pact", "defensive pact"
        ]
        if alliancePatterns.contains(where: { lowercased.contains($0) }) {
            if let country = extractCountryName(from: lowercased, gameState: gameState) {
                return ParsedCommand(
                    action: .formAlliance,
                    target: country.id,
                    parameters: [:]
                )
            }
        }

        // Economic aid commands (many variations)
        let economicPatterns = [
            "give", "send money", "aid", "donate",
            "economic", "financial aid", "pay", "bribe"
        ]
        if economicPatterns.contains(where: { lowercased.contains($0) }) {
            if let country = extractCountryName(from: lowercased, gameState: gameState) {
                // Extract dollar amount if specified (supports $5B, $1000000000, etc)
                let amount = extractMoneyAmount(from: lowercased) ?? 5_000_000_000
                return ParsedCommand(
                    action: .economicAid,
                    target: country.id,
                    parameters: ["amount": String(amount)]
                )
            }
        }

        // End turn commands (many variations)
        let endTurnPatterns = [
            "end turn", "next turn", "pass", "done", "finish turn",
            "skip", "wait", "continue", "proceed"
        ]
        if endTurnPatterns.contains(where: { lowercased.contains($0) }) {
            return ParsedCommand(action: .endTurn, target: nil, parameters: [:])
        }

        // Status check commands (many variations)
        let statusPatterns = [
            "status", "report", "sitrep", "situation",
            "what's happening", "info", "stats"
        ]
        if statusPatterns.contains(where: { lowercased.contains($0) }) {
            return ParsedCommand(action: .showStatus, target: nil, parameters: [:])
        }

        return nil
    }

    /// Extract number from text (for warhead counts)
    private func extractNumber(from text: String) -> Int? {
        let pattern = #"\d+"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range, in: text) {
            return Int(text[range])
        }
        return nil
    }

    /// Extract money amount from text (supports $5B, $1000000000, 5 billion, etc)
    private func extractMoneyAmount(from text: String) -> Int? {
        let lowercased = text.lowercased()

        // Check for billions (e.g., "$5B", "5 billion", "$5,000,000,000")
        if let billions = extractNumber(from: lowercased), lowercased.contains("b") {
            return billions * 1_000_000_000
        }

        // Check for millions (e.g., "$500M", "500 million")
        if let millions = extractNumber(from: lowercased), lowercased.contains("m") {
            return millions * 1_000_000
        }

        // Check for raw numbers
        if let amount = extractNumber(from: lowercased), amount > 1_000_000 {
            return amount
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
        task.executableURL = URL(fileURLWithPath: detectedPythonPath ?? "/usr/bin/python3")
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

    /// Extract country name from text with fuzzy matching
    ///
    /// **Enhanced Matching**:
    /// - Exact name match (e.g., "Russia")
    /// - Country code match (e.g., "RUS", "US", "CHN")
    /// - Partial name match (e.g., "united states" → USA)
    /// - Common aliases (e.g., "america" → USA, "britain" → UK)
    /// - Case-insensitive
    ///
    /// **Author**: Jordan Koch
    private func extractCountryName(from text: String, gameState: GameState) -> Country? {
        let lowercased = text.lowercased()

        // Common aliases
        let aliases: [String: String] = [
            "america": "USA",
            "united states": "USA",
            "us": "USA",
            "russia": "RUS",
            "soviet": "RUS",
            "ussr": "RUS",
            "china": "CHN",
            "prc": "CHN",
            "britain": "UK",
            "england": "UK",
            "great britain": "UK",
            "france": "FRA",
            "frenchman": "FRA",
            "germany": "GER",
            "japan": "JPN",
            "india": "IND",
            "pakistan": "PAK",
            "north korea": "PRK",
            "nk": "PRK",
            "south korea": "KOR",
            "sk": "KOR",
            "iran": "IRN",
            "israel": "ISR",
            "saudi arabia": "SAU",
            "turkey": "TUR",
            "ukraine": "UKR",
            "canada": "CAN"
        ]

        // Try exact country name match
        for country in gameState.countries {
            if lowercased.contains(country.name.lowercased()) {
                return country
            }
        }

        // Try country code match
        for country in gameState.countries {
            if lowercased.contains(country.code.lowercased()) {
                return country
            }
        }

        // Try alias match
        for (alias, code) in aliases {
            if lowercased.contains(alias) {
                return gameState.countries.first { $0.code == code || $0.id == code }
            }
        }

        // Fuzzy match - find closest country name (Levenshtein distance)
        var closestMatch: Country?
        var smallestDistance = Int.max

        for country in gameState.countries {
            let distance = levenshteinDistance(lowercased, country.name.lowercased())
            if distance < smallestDistance && distance <= 3 {  // Max 3 char difference
                smallestDistance = distance
                closestMatch = country
            }
        }

        return closestMatch
    }

    /// Calculate Levenshtein distance for fuzzy string matching
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let s1 = Array(s1)
        let s2 = Array(s2)
        var dist = [[Int]](repeating: [Int](repeating: 0, count: s2.count + 1), count: s1.count + 1)

        for i in 1...s1.count {
            dist[i][0] = i
        }

        for j in 1...s2.count {
            dist[0][j] = j
        }

        for i in 1...s1.count {
            for j in 1...s2.count {
                if s1[i-1] == s2[j-1] {
                    dist[i][j] = dist[i-1][j-1]
                } else {
                    dist[i][j] = min(dist[i-1][j], dist[i][j-1], dist[i-1][j-1]) + 1
                }
            }
        }

        return dist[s1.count][s2.count]
    }

    // MARK: - Interaction Logging

    /// Log an MLX interaction for the interaction panel
    func logInteraction(type: String, input: String? = nil, output: String) {
        let interaction = MLXInteraction(
            timestamp: Date(),
            type: type,
            input: input,
            output: output
        )

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.interactionHistory.insert(interaction, at: 0)

            // Keep only recent interactions
            if self.interactionHistory.count > self.maxHistory {
                self.interactionHistory = Array(self.interactionHistory.prefix(self.maxHistory))
            }
        }
    }
}

// MARK: - MLX Interaction Model

/// Represents an MLX AI interaction
struct MLXInteraction: Identifiable {
    let id = UUID()
    let timestamp: Date
    let type: String
    let input: String?
    let output: String

    var icon: String {
        switch type.lowercased() {
        case "command": return "terminal.fill"
        case "analysis": return "chart.bar.fill"
        case "strategic": return "brain.head.profile"
        case "prediction": return "crystal.ball.fill"
        case "recommendation": return "lightbulb.fill"
        default: return "cpu"
        }
    }

    var color: Color {
        switch type.lowercased() {
        case "command": return GTNWColors.neonCyan
        case "analysis": return GTNWColors.neonPurple
        case "strategic": return GTNWColors.neonBlue
        case "prediction": return GTNWColors.terminalAmber
        case "recommendation": return GTNWColors.terminalGreen
        default: return GTNWColors.terminalGreen
        }
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
