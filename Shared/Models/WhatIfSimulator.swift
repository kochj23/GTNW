//
//  WhatIfSimulator.swift
//  GTNW
//
//  What-If simulator for predicting action consequences
//  Created by Jordan Koch on 2026-01-22
//

import Foundation

/// Simulates consequences of actions before execution
@MainActor
class WhatIfSimulator: ObservableObject {
    @Published var simulationResults: [ActionSimulation] = []
    @Published var isSimulating = false

    private let aiBackend = AIBackendManager.shared

    /// Simulate an action's consequences
    func simulate(
        action: PresidentialAction,
        target: Country,
        gameState: GameState
    ) async -> ActionSimulation {
        guard aiBackend.activeBackend != nil else {
            return generateBasicSimulation(action: action, target: target, gameState: gameState)
        }

        isSimulating = true
        defer { isSimulating = false }

        let playerCountry = gameState.getPlayerCountry()!
        let currentRelation = target.diplomaticRelations[gameState.playerCountry] ?? 0

        let prompt = """
        Predict consequences of this presidential action:

        ACTION: \(action.name)
        Description: \(action.description)
        Cost: \(action.cost > 0 ? "$\(action.cost)B" : "Free")
        Risk: \(action.riskLevel.rawValue)

        TARGET: \(target.name)
        - Military: \(target.militaryStrength)/100
        - Nukes: \(target.nuclearWarheads)
        - Current relations: \(currentRelation)
        - Personality: \(target.personality.rawValue)
        - At war with us: \(target.isAtWarWith(gameState.playerCountry) ? "YES" : "NO")

        CONTEXT:
        - DEFCON: \(gameState.defconLevel.rawValue)
        - Target has allies: \(gameState.countries.filter { ($0.diplomaticRelations[target.id] ?? 0) > 50 }.count)

        Predict:
        1. Best case outcome
        2. Worst case outcome
        3. Most likely outcome
        4. War probability (0-100)
        5. Retaliation likelihood (0-100)
        6. Confidence (High/Medium/Low)

        Return JSON:
        {
          "bestCase": {"relations": 20, "warProb": 0, "outcome": "..."},
          "worstCase": {"relations": -50, "warProb": 90, "outcome": "..."},
          "mostLikely": {"relations": -10, "warProb": 30, "outcome": "..."},
          "confidence": "High|Medium|Low",
          "explanation": "..."
        }
        """

        do {
            let response = try await aiBackend.generate(
                prompt: prompt,
                systemPrompt: "You are a strategic analyst predicting consequences of presidential actions.",
                temperature: 0.4,
                maxTokens: 400
            )

            if let simulation = parseSimulation(from: response, action: action) {
                await MainActor.run {
                    self.simulationResults.append(simulation)
                }
                return simulation
            }
        } catch {
            print("Simulation failed: \(error)")
        }

        return generateBasicSimulation(action: action, target: target, gameState: gameState)
    }

    private func parseSimulation(from response: String, action: PresidentialAction) -> ActionSimulation? {
        guard let data = response.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        func parseOutcome(_ dict: [String: Any]?) -> Outcome {
            Outcome(
                relationChange: dict?["relations"] as? Int ?? 0,
                warProbability: (dict?["warProb"] as? Int ?? 0) / 100.0,
                retaliationLikelihood: (dict?["retaliation"] as? Int ?? 0) / 100.0,
                economicImpact: dict?["economic"] as? Int ?? 0,
                defconChange: dict?["defcon"] as? Int ?? 0,
                outcome: dict?["outcome"] as? String ?? ""
            )
        }

        return ActionSimulation(
            action: action,
            bestCase: parseOutcome(json["bestCase"] as? [String: Any]),
            worstCase: parseOutcome(json["worstCase"] as? [String: Any]),
            mostLikely: parseOutcome(json["mostLikely"] as? [String: Any]),
            confidence: json["confidence"] as? String ?? "Low",
            explanation: json["explanation"] as? String ?? ""
        )
    }

    private func generateBasicSimulation(action: PresidentialAction, target: Country, gameState: GameState) -> ActionSimulation {
        let baseRelationChange = action.relationImpact

        return ActionSimulation(
            action: action,
            bestCase: Outcome(
                relationChange: baseRelationChange / 2,
                warProbability: 0.0,
                retaliationLikelihood: 0.0,
                economicImpact: -action.cost,
                defconChange: 0,
                outcome: "Smooth execution, minimal backlash"
            ),
            worstCase: Outcome(
                relationChange: baseRelationChange * 2,
                warProbability: action.riskLevel == .catastrophic ? 0.8 : 0.3,
                retaliationLikelihood: 0.6,
                economicImpact: -action.cost * 2,
                defconChange: -1,
                outcome: "Major escalation, possible war"
            ),
            mostLikely: Outcome(
                relationChange: baseRelationChange,
                warProbability: action.riskLevel == .high ? 0.3 : 0.1,
                retaliationLikelihood: 0.2,
                economicImpact: -action.cost,
                defconChange: 0,
                outcome: "Expected consequences"
            ),
            confidence: "Low",
            explanation: "Basic estimation. AI analysis unavailable."
        )
    }
}

// MARK: - Data Models

struct ActionSimulation: Identifiable {
    let id = UUID()
    let action: PresidentialAction
    let bestCase: Outcome
    let worstCase: Outcome
    let mostLikely: Outcome
    let confidence: String
    let explanation: String
}

struct Outcome {
    let relationChange: Int
    let warProbability: Double
    let retaliationLikelihood: Double
    let economicImpact: Int
    let defconChange: Int
    let outcome: String
}
