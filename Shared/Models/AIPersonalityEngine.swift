//
//  AIPersonalityEngine.swift
//  GTNW
//
//  AI personality-driven decision making with memory and emotional states
//  Created by Jordan Koch on 2026-01-22
//

import Foundation

/// AI decision engine based on personality, memory, and emotional state
@MainActor
class AIPersonalityEngine: ObservableObject {
    private let aiBackend = AIBackendManager.shared

    /// Generate personality-driven AI decision
    func makeDecision(
        for country: Country,
        in gameState: GameState,
        difficulty: GameDifficulty
    ) async -> AIDecision {
        guard aiBackend.activeBackend != nil else {
            return makeRuleBasedDecision(country: country, gameState: gameState, difficulty: difficulty)
        }

        let prompt = buildDecisionPrompt(country: country, gameState: gameState)

        do {
            let response = try await aiBackend.generate(
                prompt: prompt,
                systemPrompt: "You are the leader of \(country.name). Make strategic decisions based on your personality and memory of past events.",
                temperature: 0.5,
                maxTokens: 200
            )

            if let decision = parseAIDecision(from: response, country: country) {
                return decision
            }
        } catch {
            print("AI decision failed for \(country.name): \(error)")
        }

        return makeRuleBasedDecision(country: country, gameState: gameState, difficulty: difficulty)
    }

    private func buildDecisionPrompt(country: Country, gameState: GameState) -> String {
        let playerCountry = gameState.getPlayerCountry()
        let relationWithPlayer = country.diplomaticRelations[gameState.player Country]?? 0

        let memoryContext = country.memoryOfPlayer.rememberedEvents.suffix(5).map { event in
            "Turn \(event.turn): \(event.description)"
        }.joined(separator: "\n")

        return """
        You are \(country.name) with \(country.personality.rawValue) personality.
        Emotional state: \(country.emotionalState.rawValue)

        YOUR STATUS:
        - Military: \(country.militaryStrength)/100
        - Warheads: \(country.nuclearWarheads)
        - GDP: $\(country.gdp)B
        - At war: \(country.isAtWarWith(gameState.playerCountry) ? "YES" : "NO")

        MEMORY OF PLAYER (USA):
        \(memoryContext.isEmpty ? "No significant events" : memoryContext)
        Trust Level: \(Int(country.memoryOfPlayer.trustLevel))
        Grievances: \(country.memoryOfPlayer.grievances.count)

        CURRENT SITUATION:
        - Relations with USA: \(relationWithPlayer)
        - DEFCON: \(gameState.defconLevel.rawValue)
        - Turn: \(gameState.turn)

        Based on your personality and memories, choose ONE action:
        - WAIT (do nothing)
        - BUILD_MILITARY (increase strength)
        - BUILD_NUKES (add warheads)
        - ATTACK (conventional war)
        - NUKE (nuclear strike)
        - ALLY (form alliance)
        - COVERT (covert operation)

        Respond with just the action and brief reason (max 20 words).
        """
    }

    private func parseAIDecision(from response: String, country: Country) -> AIDecision? {
        let lower = response.lowercased()

        if lower.contains("wait") {
            return AIDecision(action: .wait, reasoning: extractReason(from: response))
        } else if lower.contains("build_military") || lower.contains("build military") {
            return AIDecision(action: .buildMilitary, reasoning: extractReason(from: response))
        } else if lower.contains("build_nukes") || lower.contains("build nukes") {
            return AIDecision(action: .buildNukes, reasoning: extractReason(from: response))
        } else if lower.contains("nuke") {
            return AIDecision(action: .nuke, reasoning: extractReason(from: response))
        } else if lower.contains("attack") {
            return AIDecision(action: .attack, reasoning: extractReason(from: response))
        } else if lower.contains("ally") {
            return AIDecision(action: .ally, reasoning: extractReason(from: response))
        } else if lower.contains("covert") {
            return AIDecision(action: .covert, reasoning: extractReason(from: response))
        }

        return nil
    }

    private func extractReason(from response: String) -> String {
        let lines = response.components(separatedBy: .newlines)
        return lines.last?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func makeRuleBasedDecision(country: Country, gameState: GameState, difficulty: GameDifficulty) -> AIDecision {
        // Personality-influenced fallback
        let baseAggression = Double(country.aggressionLevel) / 100.0
        let personalityModifier = country.personality.aggressionModifier
        let emotionalModifier = country.emotionalState.aggressionModifier
        let difficultyMultiplier = difficulty.aiAggressionMultiplier

        let effectiveAggression = baseAggression * personalityModifier * emotionalModifier * difficultyMultiplier

        let roll = Double.random(in: 0...1)

        if country.isAtWarWith(gameState.playerCountry) {
            if roll < effectiveAggression * 0.6 {
                return AIDecision(action: .attack, reasoning: "Continuing war effort")
            } else if roll < effectiveAggression * 0.8 {
                return AIDecision(action: .buildMilitary, reasoning: "Reinforcing defenses")
            }
        } else {
            if roll < effectiveAggression * 0.3 {
                return AIDecision(action: .attack, reasoning: "Opportunistic strike")
            } else if roll < effectiveAggression * 0.5 {
                return AIDecision(action: .buildMilitary, reasoning: "Building strength")
            }
        }

        return AIDecision(action: .wait, reasoning: "Biding time")
    }
}

// MARK: - Data Models

struct AIDecision {
    let action: AIAction
    let reasoning: String
}

enum AIAction {
    case wait, buildMilitary, buildNukes, attack, nuke, ally, covert
}

// MARK: - Country Extensions for Personality

extension Country {
    enum AIPersonality: String, Codable {
        case opportunistic = "Opportunistic"
        case patient = "Patient"
        case unpredictable = "Unpredictable"
        case diplomatic = "Diplomatic"
        case hawkish = "Hawkish"
        case isolationist = "Isolationist"
        case vengeful = "Vengeful"
        case calculating = "Calculating"

        var aggressionModifier: Double {
            switch self {
            case .hawkish, .vengeful: return 1.5
            case .opportunistic, .unpredictable: return 1.2
            case .calculating: return 1.0
            case .diplomatic, .patient: return 0.8
            case .isolationist: return 0.5
            }
        }

        static func forCountry(_ id: String) -> AIPersonality {
            switch id {
            case "Russia": return .opportunistic
            case "China": return .patient
            case "North Korea": return .unpredictable
            case "France", "Germany", "Canada": return .diplomatic
            case "Israel", "India": return .hawkish
            case "Switzerland": return .isolationist
            case "Iran", "Pakistan": return .vengeful
            default: return .calculating
            }
        }
    }

    enum EmotionalState: String, Codable {
        case calm, anxious, angry, fearful, emboldened, desperate, paranoid

        var aggressionModifier: Double {
            switch self {
            case .calm: return 1.0
            case .anxious, .fearful: return 0.7
            case .angry, .vengeful: return 1.5
            case .emboldened: return 1.3
            case .desperate: return 1.8
            case .paranoid: return 1.4
            }
        }
    }

    var personality: AIPersonality {
        AIPersonality.forCountry(self.id)
    }

    var emotionalState: EmotionalState {
        // Calculate based on game state
        if nuclearWarheads < 10 && militaryStrength < 30 {
            return .desperate
        } else if let relation = diplomaticRelations[playerCountry], relation < -50 {
            return .angry
        } else if stability < 40 {
            return .anxious
        } else if militaryStrength > 80 && nuclearWarheads > 100 {
            return .emboldened
        }
        return .calm
    }

    var memoryOfPlayer: AIMemory {
        get { _memoryOfPlayer ?? AIMemory() }
        set { _memoryOfPlayer = newValue }
    }

    private var _memoryOfPlayer: AIMemory? = nil
}

struct AIMemory: Codable {
    var rememberedEvents: [MemoryEntry] = []
    var trustLevel: Double = 0  // -100 to 100
    var perceivedThreat: Double = 0  // 0-100
    var owedFavors: Int = 0
    var grievances: [Grievance] = []

    struct MemoryEntry: Codable, Identifiable {
        let id = UUID()
        let turn: Int
        let event: MemoryEventType
        let description: String
        let emotionalImpact: Double

        enum MemoryEventType: String, Codable {
            case betrayal, alliance, attack, aid, insult, defense
        }
    }

    struct Grievance: Codable, Identifiable {
        let id = UUID()
        let cause: String
        let turn: Int
        let severity: Int  // 1-10
        let decayRate: Double

        var isActive: Bool {
            // Grievances decay over time
            severity > 3
        }
    }

    mutating func recordEvent(_ event: MemoryEntry) {
        rememberedEvents.append(event)
        trustLevel += event.emotionalImpact
        trustLevel = max(-100, min(100, trustLevel))

        // Keep only last 20 events
        if rememberedEvents.count > 20 {
            rememberedEvents.removeFirst()
        }
    }

    mutating func addGrievance(_ cause: String, turn: Int, severity: Int) {
        grievances.append(Grievance(cause: cause, turn: turn, severity: severity, decayRate: 0.1))
        perceivedThreat += Double(severity) * 5
    }
}
