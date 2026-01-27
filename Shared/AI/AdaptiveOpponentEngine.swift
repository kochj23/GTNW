//
//  AdaptiveOpponentEngine.swift
//  GTNW
//
//  Adaptive AI That Learns Player's Playstyle
//  Cross-game learning and counter-strategy development
//  Created by Jordan Koch on 2026-01-26
//

import Foundation
import SwiftUI

@MainActor
class AdaptiveOpponentEngine: ObservableObject {
    static let shared = AdaptiveOpponentEngine()

    @Published var playerProfile: PlayerProfile?
    @Published var adaptationLevel: Double = 0.0
    @Published var isLearning = false

    private let analysis = AnalysisUnified.shared
    private let storage = UserDefaults.standard

    private init() {
        loadPlayerProfile()
    }

    // MARK: - Track Player Actions

    func recordAction(_ action: PlayerAction, gameState: GameState) {
        var history = loadActionHistory()
        history.append(action)

        // Keep last 500 actions
        if history.count > 500 {
            history = Array(history.suffix(500))
        }

        saveActionHistory(history)

        // Update profile periodically
        if history.count % 10 == 0 {
            Task {
                await updatePlayerProfile(history: history)
            }
        }
    }

    // MARK: - Analyze Player Behavior

    private func updatePlayerProfile(history: [PlayerAction]) async {
        isLearning = true
        defer { isLearning = false }

        // Analyze patterns
        let diplomaticCount = history.filter { $0.category == .diplomatic }.count
        let militaryCount = history.filter { $0.category == .military }.count
        let covertCount = history.filter { $0.category == .covert }.count
        let economicCount = history.filter { $0.category == .economic }.count
        let nuclearCount = history.filter { $0.category == .nuclear }.count

        let total = Double(history.count)

        let profile = PlayerProfile(
            gamesPlayed: loadGamesPlayedCount(),
            totalActions: history.count,
            preferredCategory: determinePreferredCategory(history),
            aggressionLevel: calculateAggressionLevel(history),
            diplomaticTendency: Double(diplomaticCount) / total,
            militaryTendency: Double(militaryCount) / total,
            covertTendency: Double(covertCount) / total,
            economicTendency: Double(economicCount) / total,
            nuclearThreshold: calculateNuclearThreshold(history),
            riskTolerance: calculateRiskTolerance(history),
            patterns: identifyPatterns(history),
            weaknesses: identifyWeaknesses(history),
            predictableResponses: predictResponses(history),
            timestamp: Date()
        )

        playerProfile = profile
        savePlayerProfile(profile)

        // Update adaptation level
        adaptationLevel = min(Double(history.count) / 100.0, 1.0)
    }

    // MARK: - AI Counter-Strategies

    func adaptOpponentBehavior(opponent: Country, playerProfile: PlayerProfile) {
        guard let profile = playerProfile else { return }

        // Counter diplomatic players
        if profile.diplomaticTendency > 0.6 {
            opponent.aggressionLevel = min(opponent.aggressionLevel * 1.3, 1.0)
            print("AI: Player is diplomatic, increasing aggression to exploit pacifism")
        }

        // Counter covert-heavy players
        if profile.covertTendency > 0.4 {
            opponent.counterIntelligenceBudget *= 2.0
            print("AI: Player favors covert ops, doubling counter-intelligence")
        }

        // Counter economic warfare
        if profile.economicTendency > 0.5 {
            opponent.economicDiversification = true
            print("AI: Player uses economic pressure, diversifying economy")
        }

        // Counter nuclear threats
        if profile.nuclearThreshold < 0.3 {
            opponent.nuclearReadiness = .high
            print("AI: Player quick to use nukes, maintaining high alert")
        }

        // Exploit patterns
        if let pattern = profile.patterns.first {
            exploitPattern(opponent: opponent, pattern: pattern)
        }
    }

    private func exploitPattern(opponent: Country, pattern: String) {
        if pattern.contains("always attacks after sanctions") {
            // AI will prepare defenses after imposing sanctions
            opponent.defensivePosture = true
        }

        if pattern.contains("rarely uses nuclear weapons") {
            // AI can be more aggressive
            opponent.nuclearFearFactor = 0.5
        }
    }

    // MARK: - Analysis Methods

    private func determinePreferredCategory(_ history: [PlayerAction]) -> ActionCategory {
        let counts: [ActionCategory: Int] = [
            .diplomatic: history.filter { $0.category == .diplomatic }.count,
            .military: history.filter { $0.category == .military }.count,
            .covert: history.filter { $0.category == .covert }.count,
            .economic: history.filter { $0.category == .economic }.count,
            .nuclear: history.filter { $0.category == .nuclear }.count
        ]

        return counts.max(by: { $0.value < $1.value })?.key ?? .diplomatic
    }

    private func calculateAggressionLevel(_ history: [PlayerAction]) -> Double {
        let aggressiveActions = history.filter { $0.isAggressive }.count
        return Double(aggressiveActions) / Double(history.count)
    }

    private func calculateNuclearThreshold(_ history: [PlayerAction]) -> Double {
        let nuclearActions = history.filter { $0.category == .nuclear }.count
        let warActions = history.filter { $0.category == .military }.count

        guard warActions > 0 else { return 1.0 }
        return Double(nuclearActions) / Double(warActions)
    }

    private func calculateRiskTolerance(_ history: [PlayerAction]) -> Double {
        let riskyActions = history.filter { $0.riskLevel > 0.6 }.count
        return Double(riskyActions) / Double(history.count)
    }

    private func identifyPatterns(_ history: [PlayerAction]) -> [String] {
        var patterns: [String] = []

        // Sequential patterns
        for i in 0..<(history.count - 2) {
            let sequence = [history[i], history[i+1], history[i+2]]
            if sequence.allSatisfy({ $0.category == .economic }) {
                patterns.append("Prefers economic pressure sequences")
                break
            }
        }

        // Response patterns
        let responsesToAggression = history.filter { $0.context.contains("aggressive") }
        if responsesToAggression.filter({ $0.category == .military }).count > responsesToAggression.count / 2 {
            patterns.append("Responds to aggression with military force")
        }

        return Array(Set(patterns)).prefix(5).map { $0 }
    }

    private func identifyWeaknesses(_ history: [PlayerAction]) -> [String] {
        var weaknesses: [String] = []

        // Never uses certain action types
        if history.filter({ $0.category == .covert }).isEmpty {
            weaknesses.append("Never uses covert operations")
        }

        if history.filter({ $0.category == .nuclear }).isEmpty {
            weaknesses.append("Unwilling to use nuclear weapons")
        }

        // Predictable patterns
        if history.suffix(5).allSatisfy({ $0.category == .diplomatic }) {
            weaknesses.append("Extremely predictable (only uses diplomacy)")
        }

        return weaknesses
    }

    private func predictResponses(_ history: [PlayerAction]) -> [String] {
        var predictions: [String] = []

        // If attacked, likely response
        let attackResponses = history.filter { $0.context.contains("attacked") }
        if !attackResponses.isEmpty {
            let mostCommon = attackResponses.map { $0.category }.mostCommon()
            predictions.append("If attacked: likely \(mostCommon?.rawValue ?? "retaliate")")
        }

        return predictions
    }

    // MARK: - Persistence

    private func loadActionHistory() -> [PlayerAction] {
        guard let data = storage.data(forKey: "gtnw_player_actions"),
              let history = try? JSONDecoder().decode([PlayerAction].self, from: data) else {
            return []
        }
        return history
    }

    private func saveActionHistory(_ history: [PlayerAction]) {
        if let data = try? JSONEncoder().encode(history) {
            storage.set(data, forKey: "gtnw_player_actions")
        }
    }

    private func loadPlayerProfile() {
        guard let data = storage.data(forKey: "gtnw_player_profile"),
              let profile = try? JSONDecoder().decode(PlayerProfile.self, from: data) else {
            return
        }
        playerProfile = profile
    }

    private func savePlayerProfile(_ profile: PlayerProfile) {
        if let data = try? JSONEncoder().encode(profile) {
            storage.set(data, forKey: "gtnw_player_profile")
        }
    }

    private func loadGamesPlayedCount() -> Int {
        return storage.integer(forKey: "gtnw_games_played")
    }
}

// MARK: - Models

struct PlayerProfile: Codable {
    let gamesPlayed: Int
    let totalActions: Int
    let preferredCategory: ActionCategory
    let aggressionLevel: Double
    let diplomaticTendency: Double
    let militaryTendency: Double
    let covertTendency: Double
    let economicTendency: Double
    let nuclearThreshold: Double
    let riskTolerance: Double
    let patterns: [String]
    let weaknesses: [String]
    let predictableResponses: [String]
    let timestamp: Date
}

struct PlayerAction: Codable {
    let id = UUID()
    let category: ActionCategory
    let actionName: String
    let target: String
    let turn: Int
    let gameID: UUID
    let isAggressive: Bool
    let riskLevel: Double
    let context: String
    let timestamp: Date
}

enum ActionCategory: String, Codable {
    case diplomatic = "Diplomatic"
    case military = "Military"
    case covert = "Covert"
    case economic = "Economic"
    case nuclear = "Nuclear"
    case intelligence = "Intelligence"
}

// MARK: - Player Profile View

struct PlayerProfileView: View {
    let profile: PlayerProfile

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                VStack(spacing: 8) {
                    Text("🎯 Your Playstyle")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Text("\(profile.gamesPlayed) games • \(profile.totalActions) actions")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding()

                // Preferred category
                VStack(alignment: .leading, spacing: 8) {
                    Text("Preferred Strategy")
                        .font(.headline)
                        .foregroundColor(.white)

                    Text(profile.preferredCategory.rawValue)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.blue.opacity(0.2))
                .cornerRadius(12)

                // Tendencies
                VStack(alignment: .leading, spacing: 12) {
                    Text("Action Breakdown")
                        .font(.headline)
                        .foregroundColor(.white)

                    tendencyBar("Diplomatic", profile.diplomaticTendency, .blue)
                    tendencyBar("Military", profile.militaryTendency, .red)
                    tendencyBar("Covert", profile.covertTendency, .purple)
                    tendencyBar("Economic", profile.economicTendency, .green)
                }
                .padding()
                .background(Color.black.opacity(0.3))
                .cornerRadius(12)

                // Patterns
                if !profile.patterns.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Identified Patterns")
                            .font(.headline)
                            .foregroundColor(.white)

                        ForEach(profile.patterns, id: \.self) { pattern in
                            HStack {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .foregroundColor(.orange)
                                Text(pattern)
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                    }
                    .padding()
                    .background(Color.orange.opacity(0.2))
                    .cornerRadius(12)
                }

                // Weaknesses
                if !profile.weaknesses.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("⚠️ Exploitable Weaknesses")
                            .font(.headline)
                            .foregroundColor(.white)

                        ForEach(profile.weaknesses, id: \.self) { weakness in
                            HStack {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.red)
                                Text(weakness)
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }

                        Text("AI opponents will exploit these weaknesses")
                            .font(.caption2)
                            .foregroundColor(.red.opacity(0.7))
                            .italic()
                    }
                    .padding()
                    .background(Color.red.opacity(0.2))
                    .cornerRadius(12)
                }

                // Stats
                HStack(spacing: 16) {
                    statBox("Aggression", Int(profile.aggressionLevel * 100), "%", .red)
                    statBox("Risk Tolerance", Int(profile.riskTolerance * 100), "%", .orange)
                    statBox("Nuclear Threshold", Int(profile.nuclearThreshold * 100), "%", .purple)
                }
            }
            .padding()
        }
    }

    private func tendencyBar(_ label: String, _ value: Double, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                Spacer()
                Text("\(Int(value * 100))%")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(color)
            }

            ProgressView(value: value)
                .progressViewStyle(.linear)
                .tint(color)
        }
    }

    private func statBox(_ label: String, _ value: Int, _ suffix: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(value)\(suffix)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)

            Text(label)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.2))
        .cornerRadius(8)
    }
}

// MARK: - Helpers

extension Array where Element: Hashable {
    func mostCommon() -> Element? {
        let counts = self.reduce(into: [:]) { $0[$1, default: 0] += 1 }
        return counts.max(by: { $0.value < $1.value })?.key
    }
}

extension Country {
    var economicDiversification: Bool {
        get { return true } // Placeholder
        set { }
    }

    var defensivePosture: Bool {
        get { return false }
        set { }
    }

    var nuclearFearFactor: Double {
        get { return 1.0 }
        set { }
    }

    var counterIntelligenceBudget: Double {
        get { return 100.0 }
        set { }
    }

    var nuclearReadiness: NuclearReadiness {
        get { return .normal }
        set { }
    }
}

enum NuclearReadiness {
    case low
    case normal
    case high
    case maximum
}
