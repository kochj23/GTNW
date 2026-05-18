//
//  AIWarRoom.swift
//  GTNW
//
//  AI-powered strategic war room analysis and threat assessment
//  Created by Jordan Koch on 2026-01-22
//

import Foundation
import SwiftUI

/// AI War Room for strategic intelligence and recommendations
@MainActor
class AIWarRoom: ObservableObject {
    @Published var threatAnalysis: ThreatAnalysis?
    @Published var isAnalyzing = false

    private let aiBackend = AIBackendManager.shared

    /// Analyze current strategic situation
    func analyzeSituation(gameState: GameState) async -> ThreatAnalysis {
        guard aiBackend.activeBackend != nil else {
            return generateBasicAnalysis(gameState: gameState)
        }

        isAnalyzing = true
        defer { isAnalyzing = false }

        let playerCountry = gameState.getPlayerCountry()!
        let threats = gameState.countries.filter { $0.id != gameState.playerCountry }

        let prompt = """
        Analyze this nuclear war strategic situation:

        YOUR STATUS (USA):
        - Warheads: \(playerCountry.nuclearWarheads)
        - Military: \(playerCountry.militaryStrength)/100
        - GDP: $\(playerCountry.gdp)B
        - At war: \(gameState.activeWars.filter { $0.involves(gameState.playerCountry) }.count) wars
        - Allies: \(threats.filter { ($0.diplomaticRelations[gameState.playerCountry] ?? 0) > 50 }.count)

        THREATS (top 5 by military):
        \(threats.sorted { ($0.militaryStrength + $0.nuclearWarheads) > ($1.militaryStrength + $1.nuclearWarheads) }.prefix(5).map { country in
            "- \(country.name): Military=\(country.militaryStrength), Nukes=\(country.nuclearWarheads), Relations=\(country.diplomaticRelations[gameState.playerCountry] ?? 0)"
        }.joined(separator: "\n"))

        CURRENT STATE:
        - DEFCON: \(gameState.defconLevel.rawValue)
        - Turn: \(gameState.turn)
        - Casualties: \(gameState.totalCasualties.formatted())

        Provide strategic analysis:
        1. Rank top 3 immediate threats
        2. Identify opportunities to exploit
        3. Recommend 2-3 actions
        4. Assess path to victory

        Return JSON:
        {
          "immediateThreats": [{"country": "Russia", "threatLevel": 85, "reasoning": "...", "timeWindow": "Act within 3 turns"}],
          "opportunities": [{"country": "China", "opportunity": "..."}],
          "recommendations": ["Recommend 1", "Recommend 2"],
          "victoryPath": "Assessment of victory path..."
        }
        """

        do {
            let response = try await aiBackend.generate(
                prompt: prompt,
                systemPrompt: "You are a military strategist analyzing nuclear war scenarios.",
                temperature: 0.3,
                maxTokens: 600
            )

            if let analysis = parseThreatAnalysis(from: response) {
                await MainActor.run {
                    self.threatAnalysis = analysis
                }
                return analysis
            }
        } catch {
            print("War Room analysis failed: \(error)")
        }

        return generateBasicAnalysis(gameState: gameState)
    }

    private func parseThreatAnalysis(from response: String) -> ThreatAnalysis? {
        guard let data = response.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let threats = (json["immediateThreats"] as? [[String: Any]])?.compactMap { dict -> ThreatReport in
            ThreatReport(
                country: dict["country"] as? String ?? "",
                threatLevel: dict["threatLevel"] as? Int ?? 0,
                reasoning: dict["reasoning"] as? String ?? "",
                recommendedResponse: dict["recommendedResponse"] as? String ?? "",
                timeWindow: dict["timeWindow"] as? String ?? ""
            )
        } ?? []

        let opportunities = (json["opportunities"] as? [[String: Any]])?.compactMap { dict -> Opportunity in
            Opportunity(
                country: dict["country"] as? String ?? "",
                opportunity: dict["opportunity"] as? String ?? ""
            )
        } ?? []

        return ThreatAnalysis(
            immediateThreats: threats,
            emergingThreats: [],
            opportunities: opportunities,
            victoryPathAnalysis: json["victoryPath"] as? String ?? "",
            recommendations: json["recommendations"] as? [String] ?? []
        )
    }

    private func generateBasicAnalysis(gameState: GameState) -> ThreatAnalysis {
        let playerCountry = gameState.getPlayerCountry()!
        let threats = gameState.countries
            .filter { $0.id != gameState.playerCountry }
            .sorted { ($0.militaryStrength + $0.nuclearWarheads) > ($1.militaryStrength + $1.nuclearWarheads) }
            .prefix(3)

        let threatReports = threats.map { country in
            ThreatReport(
                country: country.name,
                threatLevel: country.militaryStrength + country.nuclearWarheads / 10,
                reasoning: "High military capability",
                recommendedResponse: "Monitor closely",
                timeWindow: "Ongoing"
            )
        }

        return ThreatAnalysis(
            immediateThreats: Array(threatReports),
            emergingThreats: [],
            opportunities: [],
            victoryPathAnalysis: "Build alliances and maintain military superiority",
            recommendations: ["Monitor top threats", "Build nuclear arsenal", "Form strategic alliances"]
        )
    }
}

// MARK: - Data Models

struct ThreatAnalysis: Identifiable {
    let id = UUID()
    let immediateThreats: [ThreatReport]
    let emergingThreats: [ThreatReport]
    let opportunities: [Opportunity]
    let victoryPathAnalysis: String
    let recommendations: [String]
}

struct ThreatReport: Identifiable {
    let id = UUID()
    let country: String
    let threatLevel: Int  // 0-100
    let reasoning: String
    let recommendedResponse: String
    let timeWindow: String

    init(country: String, threatLevel: Int, reasoning: String, recommendedResponse: String, timeWindow: String) {
        self.country = country
        self.threatLevel = threatLevel
        self.reasoning = reasoning
        self.recommendedResponse = recommendedResponse
        self.timeWindow = timeWindow
    }
}

struct Opportunity: Identifiable {
    let id = UUID()
    let country: String
    let opportunity: String
}
