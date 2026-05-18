//
//  AIProfiler.swift
//  GTNW
//
//  AI-powered enemy country profiling and strategy analysis
//  Created by Jordan Koch on 2026-01-22
//

import Foundation

/// AI profiler for analyzing enemy strategies
@MainActor
class AIProfiler: ObservableObject {
    @Published var profiles: [String: CountryProfile] = [:]
    @Published var isProfiling = false

    private let aiBackend = AIBackendManager.shared

    /// Profile a country's strategy and predict next move
    func profileCountry(
        country: Country,
        gameState: GameState
    ) async -> CountryProfile {
        guard aiBackend.activeBackend != nil else {
            return generateBasicProfile(country: country, gameState: gameState)
        }

        isProfiling = true
        defer { isProfiling = false }

        let recentActions = country.memoryOfPlayer.rememberedEvents.suffix(5).map { $0.description }.joined(separator: ", ")

        let prompt = """
        Profile \(country.name)'s strategy:

        COUNTRY STATUS:
        - Military: \(country.militaryStrength)/100
        - Nukes: \(country.nuclearWarheads)
        - GDP: $\(country.gdp)B
        - Allies: \(gameState.countries.filter { ($0.diplomaticRelations[country.id] ?? 0) > 50 }.count)
        - At war: \(country.isAtWarWith(gameState.playerCountry) ? "YES with USA" : "NO")
        - Relations with USA: \(country.diplomaticRelations[gameState.playerCountry] ?? 0)

        RECENT ACTIONS:
        \(recentActions.isEmpty ? "No recent actions" : recentActions)

        PERSONALITY:
        - Aggression: \(country.aggressionLevel)/100
        - Government: \(country.government.rawValue)
        - Personality: \(country.personality.rawValue)

        Analyze:
        1. What is their strategic goal?
        2. Key weaknesses (military, economic, diplomatic)
        3. Predict their next move (with probability)
        4. Personality-based behavior patterns
        5. Best approach for dealing with them

        Return JSON:
        {
          "strategyAssessment": "...",
          "weaknesses": ["weak1", "weak2"],
          "nextMovePrediction": "...",
          "nextMoveProbability": 70,
          "personalityAnalysis": "...",
          "recommendedApproach": "..."
        }
        """

        do {
            let response = try await aiBackend.generate(
                prompt: prompt,
                systemPrompt: "You are an intelligence analyst profiling enemy nations.",
                temperature: 0.3,
                maxTokens: 500
            )

            if let profile = parseProfile(from: response, countryID: country.id) {
                await MainActor.run {
                    self.profiles[country.id] = profile
                }
                return profile
            }
        } catch {
            print("Profiling failed for \(country.name): \(error)")
        }

        return generateBasicProfile(country: country, gameState: gameState)
    }

    private func parseProfile(from response: String, countryID: String) -> CountryProfile? {
        guard let data = response.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        return CountryProfile(
            countryID: countryID,
            strategyAssessment: json["strategyAssessment"] as? String ?? "",
            weaknesses: json["weaknesses"] as? [String] ?? [],
            nextMovePrediction: json["nextMovePrediction"] as? String ?? "",
            nextMoveProbability: json["nextMoveProbability"] as? Double ?? 0,
            personalityAnalysis: json["personalityAnalysis"] as? String ?? "",
            recommendedApproach: json["recommendedApproach"] as? String ?? ""
        )
    }

    private func generateBasicProfile(country: Country, gameState: GameState) -> CountryProfile {
        let weaknesses: [String] = [
            country.militaryStrength < 50 ? "Weak military" : nil,
            country.nuclearWarheads < 50 ? "Limited nuclear capability" : nil,
            country.gdp < 1000 ? "Weak economy" : nil
        ].compactMap { $0 }

        return CountryProfile(
            countryID: country.id,
            strategyAssessment: "Building military capability",
            weaknesses: weaknesses.isEmpty ? ["No obvious weaknesses"] : weaknesses,
            nextMovePrediction: country.aggressionLevel > 70 ? "Likely to attack if opportunity arises" : "Likely to wait and build strength",
            nextMoveProbability: Double(country.aggressionLevel) / 100.0,
            personalityAnalysis: "\(country.personality.rawValue) personality with aggression level \(country.aggressionLevel)/100",
            recommendedApproach: currentRelation < 0 ? "Diplomatic engagement recommended" : "Monitor closely"
        )
    }
}

// MARK: - Data Models

struct CountryProfile: Identifiable {
    let id = UUID()
    let countryID: String
    let strategyAssessment: String
    let weaknesses: [String]
    let nextMovePrediction: String
    let nextMoveProbability: Double
    let personalityAnalysis: String
    let recommendedApproach: String
}
