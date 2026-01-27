//
//  NaturalLanguageIntel.swift
//  GTNW
//
//  Natural Language Intelligence Query System
//  Ask questions in plain English, get actionable intel
//  Created by Jordan Koch on 2026-01-26
//

import Foundation
import SwiftUI

@MainActor
class NaturalLanguageIntel: ObservableObject {
    static let shared = NaturalLanguageIntel()

    @Published var isProcessing = false
    @Published var queryHistory: [IntelQuery] = []
    @Published var lastError: String?

    private let llm = AIBackendManager.shared

    private init() {}

    // MARK: - Query Intelligence

    func query(_ question: String, gameState: GameState) async throws -> IntelligenceReport {
        isProcessing = true
        defer { isProcessing = false }

        // Build context for LLM
        let context = buildGameStateContext(gameState)

        let prompt = """
        You are the CIA Director briefing the President.

        CURRENT GAME STATE:
        \(context)

        PRESIDENT ASKS:
        "\(question)"

        Provide a clear, actionable intelligence report:
        1. Direct answer to the question
        2. Supporting evidence from game state
        3. Strategic implications
        4. Recommended actions

        Be concise but thorough. Focus on actionable intelligence.
        Format as intelligence briefing.
        """

        let response = try await llm.generate(prompt: prompt)

        // Extract countries mentioned
        let mentionedCountries = extractCountries(from: response, gameState: gameState)

        // Generate threat assessment
        let threats = assessThreats(mentionedCountries, gameState: gameState)

        let report = IntelligenceReport(
            id: UUID(),
            query: question,
            response: response,
            mentionedCountries: mentionedCountries,
            threatAssessment: threats,
            confidence: 0.85,
            sources: ["AI Analysis", "Game State", "Historical Patterns"],
            timestamp: Date()
        )

        // Save to history
        let query = IntelQuery(
            question: question,
            report: report,
            timestamp: Date()
        )
        queryHistory.append(query)

        return report
    }

    // MARK: - Common Queries

    func suggestQueries(gameState: GameState) -> [String] {
        var suggestions = [
            "Which countries are most likely to attack us?",
            "Show all Russian military movements",
            "Which countries have grievances against China?",
            "Find secret alliances forming",
            "What triggered North Korea's aggression?",
            "Identify weakest nuclear powers",
            "Which countries are our most reliable allies?",
            "Show countries with growing militaries"
        ]

        // Context-specific suggestions
        if gameState.defconLevel <= 2 {
            suggestions.insert("What are the chances of nuclear war?", at: 0)
        }

        if !gameState.activeWars.isEmpty {
            suggestions.insert("Analyze current war situation", at: 0)
        }

        return Array(suggestions.prefix(8))
    }

    // MARK: - Context Building

    private func buildGameStateContext(_ gameState: GameState) -> String {
        var context = """
        Turn: \(gameState.turnNumber)
        DEFCON: \(gameState.defconLevel)
        Active Wars: \(gameState.activeWars.count)
        """

        // Add country data
        context += "\n\nCOUNTRIES:\n"
        for country in gameState.countries.prefix(20) {
            let relations = country.relations[gameState.playerCountryID] ?? 0
            context += "- \(country.name): Relations=\(relations), Military=\(country.militaryStrength), Nuclear=\(country.hasNuclearWeapons)\n"
        }

        // Add recent events
        context += "\n\nRECENT EVENTS:\n"
        for event in gameState.recentEvents.suffix(10) {
            context += "- \(event)\n"
        }

        return context
    }

    private func extractCountries(from text: String, gameState: GameState) -> [Country] {
        var mentioned: [Country] = []

        for country in gameState.countries {
            if text.contains(country.name) {
                mentioned.append(country)
            }
        }

        return mentioned
    }

    private func assessThreats(_ countries: [Country], gameState: GameState) -> [ThreatAssessment] {
        return countries.map { country in
            let relations = country.relations[gameState.playerCountryID] ?? 0
            let threatLevel = calculateThreatLevel(country, relations: relations)

            return ThreatAssessment(
                country: country,
                threatLevel: threatLevel,
                reasons: generateThreatReasons(country, relations: relations)
            )
        }
    }

    private func calculateThreatLevel(_ country: Country, relations: Int) -> Double {
        var threat = 0.0

        if relations < -50 {
            threat += 0.4
        }

        if country.hasNuclearWeapons {
            threat += 0.3
        }

        if country.militaryStrength > 70 {
            threat += 0.2
        }

        if let personality = country.personality, personality.aggressionMultiplier > 1.2 {
            threat += 0.1
        }

        return min(threat, 1.0)
    }

    private func generateThreatReasons(_ country: Country, relations: Int) -> [String] {
        var reasons: [String] = []

        if relations < -50 {
            reasons.append("Hostile diplomatic relations")
        }

        if country.hasNuclearWeapons {
            reasons.append("Nuclear-armed nation")
        }

        if country.militaryStrength > 70 {
            reasons.append("Strong military capability")
        }

        return reasons
    }
}

// MARK: - Models

struct IntelQuery {
    let question: String
    let report: IntelligenceReport
    let timestamp: Date
}

struct IntelligenceReport: Identifiable {
    let id: UUID
    let query: String
    let response: String
    let mentionedCountries: [Country]
    let threatAssessment: [ThreatAssessment]
    let confidence: Double
    let sources: [String]
    let timestamp: Date
}

struct ThreatAssessment {
    let country: Country
    let threatLevel: Double
    let reasons: [String]

    var threatPercentage: Int {
        Int(threatLevel * 100)
    }

    var threatColor: Color {
        if threatLevel > 0.7 { return .red }
        if threatLevel > 0.4 { return .orange }
        return .yellow
    }
}

// MARK: - Natural Language Intel View

struct NaturalLanguageIntelView: View {
    @StateObject private var intel = NaturalLanguageIntel.shared
    @State private var query = ""
    @State private var currentReport: IntelligenceReport?
    @ObservedObject var gameState: GameState

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Query input
            queryInput

            Divider()

            // Results or suggestions
            if let report = currentReport {
                reportView(report)
            } else {
                suggestionsView
            }
        }
        .background(Color.black.opacity(0.9))
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text("🔍 Natural Language Intelligence")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text("Ask questions in plain English")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
        .padding()
        .background(Color.blue.opacity(0.2))
    }

    private var queryInput: some View {
        HStack {
            TextField("Ask intelligence question...", text: $query)
                .textFieldStyle(.roundedBorder)
                .font(.body)

            Button(action: {
                Task {
                    guard !query.isEmpty else { return }
                    currentReport = try await intel.query(query, gameState: gameState)
                    query = ""
                }
            }) {
                HStack {
                    Image(systemName: "magnifyingglass")
                    Text("Query")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(query.isEmpty || intel.isProcessing)
        }
        .padding()
    }

    private var suggestionsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Suggested Queries:")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal)

                ForEach(intel.suggestQueries(gameState: gameState), id: \.self) { suggestion in
                    Button(action: {
                        query = suggestion
                    }) {
                        HStack {
                            Image(systemName: "lightbulb")
                                .foregroundColor(.yellow)
                            Text(suggestion)
                                .font(.body)
                                .foregroundColor(.white)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
    }

    private func reportView(_ report: IntelligenceReport) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Query
                VStack(alignment: .leading, spacing: 4) {
                    Text("YOUR QUERY:")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white.opacity(0.7))

                    Text(report.query)
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .padding()
                .background(Color.blue.opacity(0.2))
                .cornerRadius(10)

                // Response
                VStack(alignment: .leading, spacing: 8) {
                    Text("INTELLIGENCE ASSESSMENT:")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white.opacity(0.7))

                    Text(report.response)
                        .font(.body)
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding()
                .background(Color.black.opacity(0.3))
                .cornerRadius(10)

                // Threat assessment
                if !report.threatAssessment.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("THREAT ASSESSMENT:")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white.opacity(0.7))

                        ForEach(report.threatAssessment, id: \.country.id) { threat in
                            ThreatCard(threat: threat)
                        }
                    }
                    .padding()
                    .background(Color.red.opacity(0.2))
                    .cornerRadius(10)
                }

                // Metadata
                HStack {
                    Text("Confidence: \(Int(report.confidence * 100))%")
                    Text("•")
                    Text(report.sources.joined(separator: ", "))
                }
                .font(.caption2)
                .foregroundColor(.white.opacity(0.5))
                .padding()

                // New query button
                Button("New Query") {
                    currentReport = nil
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }
}

struct ThreatCard: View {
    let threat: ThreatAssessment

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(threat.country.name)
                    .font(.headline)
                    .foregroundColor(.white)

                ForEach(threat.reasons, id: \.self) { reason in
                    Text("• \(reason)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }

            Spacer()

            VStack {
                Text("\(threat.threatPercentage)%")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(threat.threatColor)

                Text("THREAT")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding()
        .background(Color.black.opacity(0.3))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(threat.threatColor, lineWidth: 2)
        )
    }
}
