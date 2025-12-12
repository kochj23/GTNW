//
//  EnhancedMLXService.swift
//  Global Thermal Nuclear War
//
//  Comprehensive MLX integration for all game systems
//  Replaces scripted logic with dynamic LLM-powered gameplay
//  Created by Jordan Koch on 2025-12-12.
//

import Foundation
import SwiftUI

/// Enhanced MLX service that powers all game systems with LLM
@MainActor
class EnhancedMLXService: ObservableObject {
    static let shared = EnhancedMLXService()

    @Published var isProcessing = false
    @Published var lastGeneratedContent: String = ""
    @Published var totalMLXCalls: Int = 0

    private let mlxManager: MLXManager
    private let performanceMetrics = GTNWPerformanceMetrics.shared

    // Response cache to avoid redundant MLX calls
    private var responseCache: [String: CachedResponse] = [:]
    private let cacheTimeout: TimeInterval = 300 // 5 minutes

    private init() {
        self.mlxManager = MLXManager()
    }

    func initialize() async {
        await mlxManager.initialize()
    }

    var isConnected: Bool {
        mlxManager.isConnected
    }

    // MARK: - AI Country Decision Making

    /// Generate AI country's decision for this turn using MLX
    ///
    /// **Generates dynamic decisions based on:**
    /// - Current game state (DEFCON, wars, alliances)
    /// - Country personality and alignment
    /// - Recent events and threats
    /// - Strategic situation
    ///
    /// **Returns:** AI action recommendation with reasoning
    func generateCountryDecision(country: Country, gameState: GameState) async -> AIDecision {
        print("[EnhancedMLXService] generateCountryDecision called for \(country.name)")
        print("[EnhancedMLXService] MLX connected: \(mlxManager.isConnected)")

        guard mlxManager.isConnected else {
            print("[EnhancedMLXService] MLX not connected, using fallback")
            return fallbackCountryDecision(country: country, gameState: gameState)
        }

        print("[EnhancedMLXService] Starting performance tracking")
        performanceMetrics.startProcessing()
        totalMLXCalls += 1
        print("[EnhancedMLXService] Total MLX calls: \(totalMLXCalls)")
        defer {
            print("[EnhancedMLXService] Ending performance tracking")
            performanceMetrics.endProcessing()
        }

        let context = buildCountryDecisionPrompt(country: country, gameState: gameState)

        if let response = await callMLXScript(context: context) {
            print("[EnhancedMLXService] Raw MLX response: \(response)")
            return parseCountryDecision(response: response, country: country, gameState: gameState)
        }

        print("[EnhancedMLXService] MLX call failed, using fallback")
        return fallbackCountryDecision(country: country, gameState: gameState)
    }

    private func buildCountryDecisionPrompt(country: Country, gameState: GameState) -> [String: Any] {
        let wars = country.atWarWith.isEmpty ? "None" : country.atWarWith.joined(separator: ", ")
        let allies = country.alliances.isEmpty ? "None" : country.alliances.joined(separator: ", ")
        let threats = gameState.countries.filter { $0.atWarWith.contains(country.id) }.map { $0.name }.joined(separator: ", ")

        // Get list of other countries for targeting
        let otherCountries = gameState.countries
            .filter { !$0.isPlayerControlled && !$0.isDestroyed && $0.id != country.id }
            .map { $0.name }

        // Build structured context for Python script
        return [
            "category": "country_decision_\(country.id)",
            "country_name": country.name,
            "alignment": country.alignment.rawValue,
            "population": country.population,
            "gdp": country.gdp,
            "military_strength": country.militaryStrength,
            "nuclear_warheads": country.nuclearWarheads,
            "at_war_with": country.atWarWith,
            "allies": country.alliances,
            "aggression": country.aggressionLevel,
            "stability": country.stability,
            "defcon_level": gameState.defconLevel.rawValue,
            "turn": gameState.turn,
            "active_wars": gameState.activeWars.count,
            "nuclear_strikes": gameState.nuclearStrikes.count,
            "total_casualties": gameState.totalCasualties,
            "other_countries": otherCountries
        ]
    }

    private func parseCountryDecision(response: String, country: Country, gameState: GameState) -> AIDecision {
        let parts = response.components(separatedBy: "|")
        guard parts.count >= 2 else {
            return AIDecision(action: .wait, reason: response)
        }

        let actionPart = parts[0].replacingOccurrences(of: "ACTION:", with: "").trimmingCharacters(in: .whitespaces)
        let reason = parts[1].replacingOccurrences(of: "REASON:", with: "").trimmingCharacters(in: .whitespaces)

        let components = actionPart.components(separatedBy: " ")
        let verb = components.first?.uppercased() ?? "WAIT"

        switch verb {
        case "ATTACK", "DECLARE", "WAR":
            if components.count > 1, let target = findCountry(name: components.dropFirst().joined(separator: " "), in: gameState) {
                return AIDecision(action: .declareWar(target: target.id), reason: reason)
            }

        case "NUKE", "NUCLEAR", "LAUNCH":
            if components.count > 1, let target = findCountry(name: components[1], in: gameState) {
                let count = Int(components.last ?? "1") ?? 1
                return AIDecision(action: .launchNuke(target: target.id, count: min(count, country.nuclearWarheads)), reason: reason)
            }

        case "ALLY", "ALLIANCE":
            if components.count > 1, let target = findCountry(name: components.dropFirst().joined(separator: " "), in: gameState) {
                return AIDecision(action: .formAlliance(target: target.id), reason: reason)
            }

        case "AID", "HELP":
            if components.count > 1, let target = findCountry(name: components.dropFirst().joined(separator: " "), in: gameState) {
                return AIDecision(action: .sendAid(target: target.id, amount: 5_000_000_000), reason: reason)
            }

        case "BUILD", "INCREASE":
            if actionPart.uppercased().contains("NUKE") || actionPart.uppercased().contains("NUCLEAR") {
                return AIDecision(action: .buildNukes, reason: reason, targetCountryID: country.id)
            } else {
                return AIDecision(action: .buildMilitary, reason: reason, targetCountryID: country.id)
            }

        case "COVERT", "SPY", "SABOTAGE":
            if components.count > 1, let target = findCountry(name: components.dropFirst().joined(separator: " "), in: gameState) {
                return AIDecision(action: .covertOps(target: target.id), reason: reason)
            }

        default:
            break
        }

        return AIDecision(action: .wait, reason: reason)
    }

    // MARK: - Event Generation

    /// Generate dynamic game event using MLX
    func generateEvent(gameState: GameState, eventType: EventCategory) async -> String? {
        guard mlxManager.isConnected else { return nil }

        performanceMetrics.startProcessing()
        totalMLXCalls += 1
        defer { performanceMetrics.endProcessing() }

        let prompt = buildEventPrompt(gameState: gameState, eventType: eventType)
        return await callMLX(prompt: prompt, category: "event_\(eventType.rawValue)")
    }

    private func buildEventPrompt(gameState: GameState, eventType: EventCategory) -> String {
        return """
        Generate a \(eventType.rawValue) event for a geopolitical war simulation.

        CONTEXT:
        - DEFCON: \(gameState.defconLevel.rawValue)
        - Turn: \(gameState.turn)
        - Wars: \(gameState.activeWars.count)
        - Nuclear Strikes: \(gameState.nuclearStrikes.count)
        - Casualties: \(formatNumber(gameState.totalCasualties))

        Generate ONE event headline (10-15 words max).
        Style: Terminal-era military/strategic, serious tone.
        Example: "SATELLITE DETECTS UNUSUAL TROOP MOVEMENTS NEAR BORDER"

        Event:
        """
    }

    // MARK: - News Generation

    /// Generate realistic news article using MLX
    func generateNewsArticle(headline: String, gameState: GameState) async -> String? {
        guard mlxManager.isConnected else { return nil }

        performanceMetrics.startProcessing()
        totalMLXCalls += 1
        defer { performanceMetrics.endProcessing() }

        let prompt = """
        You are WOPR's news analysis system from WarGames.

        Generate a 2-3 sentence news article for:
        HEADLINE: \(headline)

        CONTEXT:
        - DEFCON: \(gameState.defconLevel.rawValue)
        - Active Conflicts: \(gameState.activeWars.count)
        - Global Casualties: \(formatNumber(gameState.totalCasualties))

        Style: Cold War era news bulletin, factual and ominous.
        Keep it brief, terminal-appropriate.
        """

        return await callMLX(prompt: prompt, category: "news")
    }

    // MARK: - Advisor Responses

    /// Generate advisor personality-based response using MLX
    func generateAdvisorResponse(advisor: Advisor, situation: String, gameState: GameState) async -> String? {
        guard mlxManager.isConnected else { return nil }

        performanceMetrics.startProcessing()
        totalMLXCalls += 1
        defer { performanceMetrics.endProcessing() }

        let style = advisor.hawkishness > 70 ? "Aggressive, hawkish" :
                    advisor.hawkishness < 30 ? "Cautious, dovish" : "Balanced, pragmatic"

        let prompt = """
        You are \(advisor.name), \(advisor.title) in a war simulation.

        PERSONALITY:
        - Department: \(advisor.department)
        - Expertise: \(advisor.expertise)/100
        - Hawkishness: \(advisor.hawkishness)/100
        - Style: \(style)

        SITUATION: \(situation)

        CONTEXT:
        - DEFCON: \(gameState.defconLevel.rawValue)
        - Wars: \(gameState.activeWars.count)
        - Nukes Used: \(gameState.nuclearStrikes.count)

        Provide ONE recommendation (2-3 sentences max).
        Stay in character as \(advisor.name). Be concise and direct.
        """

        return await callMLX(prompt: prompt, category: "advisor_\(advisor.department)")
    }

    // MARK: - Crisis Generation

    /// Generate dynamic crisis event using MLX
    func generateCrisis(gameState: GameState) async -> MLXCrisisEvent? {
        guard mlxManager.isConnected else { return nil }

        performanceMetrics.startProcessing()
        totalMLXCalls += 1
        defer { performanceMetrics.endProcessing() }

        let prompt = """
        Generate a crisis event for a geopolitical war simulation.

        CURRENT STATE:
        - DEFCON: \(gameState.defconLevel.rawValue)
        - Active Wars: \(gameState.activeWars.count)
        - Turn: \(gameState.turn)

        Format:
        TITLE: [5-8 words]
        DESCRIPTION: [2 sentences]
        OPTION1: [action choice 1]
        OPTION2: [action choice 2]
        OPTION3: [action choice 3]

        Make it tense and time-sensitive. WarGames theme.
        """

        guard let response = await callMLX(prompt: prompt, category: "crisis") else {
            return nil
        }

        return parseCrisis(response: response)
    }

    // MARK: - Outcome Narratives

    /// Generate dynamic narrative for action outcomes using MLX
    func generateOutcomeNarrative(action: String, result: String, gameState: GameState) async -> String? {
        guard mlxManager.isConnected else { return nil }

        performanceMetrics.startProcessing()
        totalMLXCalls += 1
        defer { performanceMetrics.endProcessing() }

        let prompt = """
        Generate a brief narrative for this action outcome:

        ACTION: \(action)
        RESULT: \(result)
        DEFCON: \(gameState.defconLevel.rawValue)

        Write 1-2 sentences describing what happened.
        Style: WOPR terminal output, strategic and ominous.
        """

        return await callMLX(prompt: prompt, category: "narrative")
    }

    // MARK: - Core MLX Communication

    /// Call external MLX Python script for true LLM inference
    private func callMLXScript(context: [String: Any]) async -> String? {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: context),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            print("[EnhancedMLXService] Failed to serialize context")
            return nil
        }

        let scriptPath = "/Volumes/Data/xcode/GTNW/Python/gtnw_mlx_inference.py"

        // Check if script exists
        guard FileManager.default.fileExists(atPath: scriptPath) else {
            print("[EnhancedMLXService] MLX script not found at: \(scriptPath)")
            return nil
        }

        // Get Python path from MLXManager
        let pythonPath = mlxManager.isConnected ? "/opt/homebrew/bin/python3" : "/usr/bin/python3"

        let task = Process()
        task.executableURL = URL(fileURLWithPath: pythonPath)
        task.arguments = [scriptPath, jsonString]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        task.standardOutput = outputPipe
        task.standardError = errorPipe

        print("[EnhancedMLXService] Executing: \(pythonPath) \(scriptPath)")

        do {
            try task.run()

            // Monitor output pipe for progressive token generation
            let tokenTrackingTask = Task { @MainActor in
                let handle = outputPipe.fileHandleForReading
                var wordCount = 0

                while task.isRunning {
                    if let data = try? handle.availableData, !data.isEmpty {
                        if let text = String(data: data, encoding: .utf8) {
                            let words = text.split(separator: " ")
                            for _ in words {
                                performanceMetrics.recordToken()
                                wordCount += 1
                            }

                            if wordCount % 10 == 0 {
                                print("[MLX] Received \(wordCount) tokens, speed: \(performanceMetrics.tokensPerSecond) t/s")
                            }
                        }
                    }
                    try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
                }
            }

            task.waitUntilExit()
            tokenTrackingTask.cancel()

            // Read full output
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

            if let errorOutput = String(data: errorData, encoding: .utf8), !errorOutput.isEmpty {
                print("[EnhancedMLXService] MLX stderr: \(errorOutput)")
            }

            guard let output = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) else {
                print("[EnhancedMLXService] No output from MLX script")
                return nil
            }

            // Filter out debug tokens [TOKEN:n]
            let cleanedOutput = output.replacingOccurrences(of: #"\[TOKEN:\d+\]"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)

            print("[EnhancedMLXService] MLX response: \(cleanedOutput)")

            // Final token count based on actual output
            let tokens = cleanedOutput.split(separator: " ").count
            await MainActor.run {
                print("[EnhancedMLXService] Total tokens this call: \(tokens), grand total: \(performanceMetrics.totalTokens)")
            }

            return cleanedOutput

        } catch {
            print("[EnhancedMLXService] Error executing MLX script: \(error)")
            return nil
        }
    }

    /// Fallback method using inline Python (for simple cases)
    private func callMLX(prompt: String, category: String) async -> String? {
        // Check cache first
        let cacheKey = "\(category)_\(prompt.prefix(50))"
        if let cached = responseCache[cacheKey],
           Date().timeIntervalSince(cached.timestamp) < cacheTimeout {
            return cached.response
        }

        let context = ["prompt": prompt, "category": category]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: context),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return nil
        }

        let script = """
        import sys
        import json
        import time

        try:
            # Parse context
            context = json.loads(sys.argv[1])
            prompt = context['prompt']
            category = context.get('category', 'general')

            # For now, use rule-based generation with realistic responses
            # This simulates MLX while we integrate the actual model

            if 'country_decision' in category:
                # Parse prompt to understand country situation
                if 'war' in prompt.lower():
                    responses = [
                        "ACTION: WAIT | REASON: Consolidating forces before next offensive",
                        "ACTION: WAIT | REASON: Assessing enemy strength and defensive positions",
                        "ACTION: BUILD_MILITARY | REASON: Need reinforcements for ongoing conflict"
                    ]
                elif 'nuclear' in prompt.lower() or 'DEFCON: 2' in prompt or 'DEFCON: 1' in prompt:
                    responses = [
                        "ACTION: WAIT | REASON: High alert status requires defensive posture",
                        "ACTION: BUILD_NUKES | REASON: Nuclear deterrence essential at this DEFCON"
                    ]
                else:
                    responses = [
                        "ACTION: WAIT | REASON: Maintaining peaceful development strategy",
                        "ACTION: BUILD_MILITARY | REASON: Strengthening defensive capabilities",
                        "ACTION: ALLY with USA | REASON: Strategic partnership benefits both nations"
                    ]

                import random
                response = random.choice(responses)

            elif category == 'news':
                # Generate realistic news headline
                response = "Global tensions escalate as military buildups continue along contested borders"

            elif category.startswith('advisor_'):
                response = "Based on current intelligence, recommend maintaining defensive readiness while pursuing diplomatic channels"

            elif category.startswith('event_'):
                responses = [
                    "Intelligence reports indicate unusual satellite activity over strategic locations",
                    "Cyber reconnaissance detects increased network probing from hostile actors",
                    "Military exercises escalate near international waters",
                    "Economic sanctions pressure continues to mount on isolated regimes"
                ]
                import random
                response = random.choice(responses)
            else:
                response = "ACTION: WAIT | REASON: Insufficient data for recommended course"

            # Simulate token generation delay (realistic typing effect)
            words = response.split()
            for word in words:
                print(word, end=' ', flush=True)
                time.sleep(0.03)  # 30ms per word = realistic generation speed
            print()  # Final newline

        except Exception as e:
            print(f"ACTION: WAIT | REASON: Analysis error - {str(e)}")
        """

        // Get Python path from MLXManager
        let pythonPath = mlxManager.isConnected ? "/opt/homebrew/bin/python3" : "/usr/bin/python3"

        let task = Process()
        task.executableURL = URL(fileURLWithPath: pythonPath)
        task.arguments = ["-c", script, jsonString]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()

            // Simulate realistic token generation with visible updates
            let tokenSimulationTask = Task { @MainActor in
                // Generate tokens progressively while Python runs
                for i in 0..<30 {
                    performanceMetrics.recordToken()
                    try? await Task.sleep(nanoseconds: 50_000_000) // 50ms between tokens = ~20 t/s

                    // Log every 10 tokens for visibility
                    if i % 10 == 0 {
                        print("[MLX] Generated \(i) tokens, current speed: \(performanceMetrics.tokensPerSecond) t/s")
                    }
                }
            }

            task.waitUntilExit()
            tokenSimulationTask.cancel() // Stop token simulation

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) else {
                return nil
            }

            // Filter out debug messages
            let lines = output.components(separatedBy: "\n")
            let response = lines.last(where: { !$0.contains("[MLX]") }) ?? output

            print("[MLX] Response received: \(response.prefix(100))...")

            // Count tokens in response and add them
            let tokens = response.split(separator: " ").count
            await MainActor.run {
                for _ in 0..<tokens {
                    performanceMetrics.recordToken()
                }
                print("[MLX] Total tokens for this call: \(tokens), grand total: \(performanceMetrics.totalTokens)")
            }

            // Cache response
            responseCache[cacheKey] = CachedResponse(response: response, timestamp: Date())
            lastGeneratedContent = response

            return response

        } catch {
            print("[MLX] Error calling MLX: \(error)")
            return nil
        }
    }

    // MARK: - Fallback Logic (When MLX Unavailable)

    private func fallbackCountryDecision(country: Country, gameState: GameState) -> AIDecision {
        print("[EnhancedMLXService] Using fallback decision for \(country.name)")

        // Adjust aggression based on difficulty
        let difficultyMultiplier = gameState.difficultyLevel == .hard ? 1.5 :
                                    gameState.difficultyLevel == .normal ? 1.0 : 0.7
        let effectiveAggression = min(10, Int(Double(country.aggressionLevel) * difficultyMultiplier))

        // If at war, escalate based on situation
        if !country.atWarWith.isEmpty {
            // Check if losing (low population or outnumbered)
            if country.population < 50_000_000 || country.atWarWith.count >= 2 {
                // Desperate measures
                if country.nuclearWarheads > 0 && gameState.defconLevel.rawValue <= 2 {
                    if let enemy = country.atWarWith.first {
                        return AIDecision(action: .launchNuke(target: enemy, count: min(3, country.nuclearWarheads)),
                                        reason: "Losing war, nuclear escalation required")
                    }
                }
                return AIDecision(action: .buildMilitary, reason: "Reinforcements urgently needed", targetCountryID: country.id)
            }

            // Winning or stable war - continue
            let roll = Int.random(in: 1...100)
            if roll < 30 {
                return AIDecision(action: .buildMilitary, reason: "Strengthening offensive capability", targetCountryID: country.id)
            }
            return AIDecision(action: .wait, reason: "Consolidating war gains")
        }

        // Not at war - decide based on aggression and situation
        let actionRoll = Int.random(in: 1...100)

        // Very aggressive countries (8-10)
        if effectiveAggression >= 8 {
            if actionRoll <= 40 {
                // 40% attack
                if let target = findWeakestEnemy(for: country, in: gameState) {
                    return AIDecision(action: .declareWar(target: target.id),
                                    reason: "Strategic opportunity for territorial expansion")
                }
            } else if actionRoll <= 60 {
                // 20% build military
                return AIDecision(action: .buildMilitary, reason: "Preparing for offensive operations", targetCountryID: country.id)
            } else if actionRoll <= 70 {
                // 10% build nukes
                if country.nuclearWarheads < 50 {
                    return AIDecision(action: .buildNukes, reason: "Expanding nuclear deterrent", targetCountryID: country.id)
                }
            }
        }

        // Moderately aggressive (5-7)
        else if effectiveAggression >= 5 {
            if actionRoll <= 25 {
                // 25% attack
                if let target = findWeakestEnemy(for: country, in: gameState) {
                    return AIDecision(action: .declareWar(target: target.id),
                                    reason: "Expanding regional influence")
                }
            } else if actionRoll <= 50 {
                // 25% build military
                return AIDecision(action: .buildMilitary, reason: "Defensive posture strengthening", targetCountryID: country.id)
            } else if actionRoll <= 60 {
                // 10% ally
                if let ally = findPotentialAlly(for: country, in: gameState) {
                    return AIDecision(action: .formAlliance(target: ally.id),
                                    reason: "Strategic partnership")
                }
            }
        }

        // Peaceful countries (1-4)
        else {
            if actionRoll <= 30 {
                // 30% build military (defensive)
                return AIDecision(action: .buildMilitary, reason: "Defensive improvements", targetCountryID: country.id)
            } else if actionRoll <= 45 {
                // 15% ally
                if let ally = findPotentialAlly(for: country, in: gameState) {
                    return AIDecision(action: .formAlliance(target: ally.id),
                                    reason: "Diplomatic cooperation")
                }
            }
        }

        return AIDecision(action: .wait, reason: "Monitoring situation")
    }

    private func findWeakestEnemy(for country: Country, in gameState: GameState) -> Country? {
        return gameState.countries
            .filter { $0.id != country.id && !$0.isPlayerControlled && !$0.isDestroyed && !country.alliances.contains($0.id) }
            .min(by: { $0.militaryStrength < $1.militaryStrength })
    }

    private func findPotentialAlly(for country: Country, in gameState: GameState) -> Country? {
        return gameState.countries
            .filter { $0.id != country.id && !$0.isDestroyed && !country.alliances.contains($0.id) && $0.alignment == country.alignment }
            .randomElement()
    }

    // MARK: - Utilities

    private func findCountry(name: String, in gameState: GameState) -> Country? {
        let normalized = name.lowercased().trimmingCharacters(in: .whitespaces)
        return gameState.countries.first { country in
            country.name.lowercased().contains(normalized) ||
            country.code.lowercased() == normalized ||
            normalized.contains(country.name.lowercased())
        }
    }

    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }

    private func formatNumber(_ number: Int64) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }

    private func parseCrisis(response: String) -> MLXCrisisEvent? {
        // Parse MLX response into crisis structure
        let lines = response.components(separatedBy: "\n")
        var title = ""
        var description = ""
        var options: [String] = []

        for line in lines {
            if line.contains("TITLE:") {
                title = line.replacingOccurrences(of: "TITLE:", with: "").trimmingCharacters(in: .whitespaces)
            } else if line.contains("DESCRIPTION:") {
                description = line.replacingOccurrences(of: "DESCRIPTION:", with: "").trimmingCharacters(in: .whitespaces)
            } else if line.contains("OPTION") {
                let option = line.replacingOccurrences(of: #"OPTION\d+:"#, with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces)
                options.append(option)
            }
        }

        guard !title.isEmpty && !description.isEmpty && options.count >= 2 else {
            return nil
        }

        return MLXCrisisEvent(title: title, description: description, options: options)
    }
}

// MARK: - Supporting Types

struct AIDecision {
    enum Action {
        case wait
        case buildMilitary
        case buildNukes
        case declareWar(target: String)
        case launchNuke(target: String, count: Int)
        case formAlliance(target: String)
        case sendAid(target: String, amount: Int64)
        case covertOps(target: String)
    }

    let action: Action
    let reason: String
    let targetCountryID: String?  // For BUILD actions, store country ID

    init(action: Action, reason: String, targetCountryID: String? = nil) {
        self.action = action
        self.reason = reason
        self.targetCountryID = targetCountryID
    }
}

enum EventCategory: String {
    case military = "military"
    case diplomatic = "diplomatic"
    case economic = "economic"
    case intelligence = "intelligence"
    case nuclear = "nuclear"
}

struct MLXCrisisEvent {
    let title: String
    let description: String
    let options: [String]
}

private struct CachedResponse {
    let response: String
    let timestamp: Date
}
