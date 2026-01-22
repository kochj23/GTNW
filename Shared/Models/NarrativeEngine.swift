//
//  NarrativeEngine.swift
//  GTNW
//
//  AI-powered narrative generation for news, advisors, and story arcs
//  Created by Jordan Koch on 2026-01-22
//

import Foundation

/// Dynamic narrative generation engine
@MainActor
class NarrativeEngine: ObservableObject {
    @Published var currentStoryArcs: [StoryArc] = []
    @Published var advisorDrama: [AdvisorEvent] = []

    private let aiBackend = AIBackendManager.shared

    /// Generate AI-powered news headlines
    func generateNews(
        gameState: GameState,
        recentEvents: [TurnEvent],
        previousHeadlines: [NewsEvent]
    ) async -> [NewsEvent] {
        guard aiBackend.activeBackend != nil else {
            return generateBasicNews(gameState: gameState)
        }

        let prompt = """
        Generate 2-3 dramatic news headlines for World War 3 situation:

        RECENT EVENTS:
        \(recentEvents.suffix(5).map { "Turn \($0.turn): \($0.event)" }.joined(separator: "\n"))

        PREVIOUS HEADLINES (for continuity):
        \(previousHeadlines.suffix(3).map { $0.headline }.joined(separator: "\n"))

        CURRENT STATE:
        - DEFCON: \(gameState.defconLevel.rawValue)
        - Active Wars: \(gameState.activeWars.count)
        - Total Casualties: \(gameState.totalCasualties.formatted())

        Generate headlines that:
        1. Reference previous events
        2. Build dramatic tension
        3. Vary by news source perspective

        Return JSON array: [{"headline": "...", "source": "CNN|BBC|FOX|RT", "severity": "breaking|developing|routine"}]
        """

        do {
            let response = try await aiBackend.generate(
                prompt: prompt,
                systemPrompt: "You are a news editor covering nuclear war. Write dramatic, tense headlines.",
                temperature: 0.6,
                maxTokens: 400
            )

            if let headlines = parseNewsJSON(from: response) {
                return headlines
            }
        } catch {
            print("AI news generation failed: \(error)")
        }

        return generateBasicNews(gameState: gameState)
    }

    /// Generate advisor dialogue in-character
    func generateAdvisorDialogue(
        advisor: Advisor,
        situation: GameSituation,
        recentPlayerActions: [String]
    ) async -> String {
        guard aiBackend.activeBackend != nil else {
            return generateBasicAdvice(advisor: advisor, situation: situation)
        }

        let prompt = """
        You are \(advisor.name), \(advisor.title).
        Personality: Hawkish=\(advisor.hawkishness), Loyal=\(advisor.loyalty), Interventionist=\(advisor.interventionism)

        Situation: \(situation.rawValue)

        Player recently: \(recentPlayerActions.suffix(3).joined(separator: ", "))

        Give advice in YOUR voice (2-3 sentences):
        - If hawkish (>70): Aggressive military language
        - If dovish (<40): Cautious diplomatic language
        - If low loyalty (<50): Subtle undermining
        """

        do {
            let response = try await aiBackend.generate(
                prompt: prompt,
                systemPrompt: "You are a presidential advisor. Stay in character.",
                temperature: 0.7,
                maxTokens: 150
            )

            return response.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return generateBasicAdvice(advisor: advisor, situation: situation)
        }
    }

    /// Generate consequence narrative after major action
    func generateConsequenceNarrative(
        action: String,
        target: String,
        result: ActionResult
    ) async -> String {
        guard aiBackend.activeBackend != nil else {
            return result.message
        }

        let prompt = """
        Generate a dramatic consequence description for this action:
        Action: \(action)
        Target: \(target)
        Success: \(result.success)
        Relation Change: \(result.relationChange)

        Write 1-2 sentences that:
        - Show consequences beyond numbers
        - Reference real leaders/institutions
        - Build narrative tension

        Example: "The British Prime Minister called your decision 'reckless' and withdrew from NATO talks."
        """

        do {
            let response = try await aiBackend.generate(
                prompt: prompt,
                systemPrompt: "You are a narrative writer for a strategy game.",
                temperature: 0.5,
                maxTokens: 100
            )

            return response.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return result.message
        }
    }

    /// Generate victory/defeat epilogue
    func generateEpilogue(
        victory: Bool,
        gameState: GameState,
        keyDecisions: [String]
    ) async -> String {
        guard aiBackend.activeBackend != nil else {
            return victory ? "Victory achieved." : "Defeat."
        }

        let prompt = """
        Write a 3-4 sentence epilogue for this game:
        Result: \(victory ? "VICTORY" : "DEFEAT")
        Final Turn: \(gameState.turn)
        Casualties: \(gameState.totalCasualties)
        Score: \(gameState.score)

        Key Decisions:
        \(keyDecisions.joined(separator: "\n"))

        Write a historical assessment of this presidency.
        """

        do {
            let response = try await aiBackend.generate(
                prompt: prompt,
                systemPrompt: "You are a historian assessing a president's legacy.",
                temperature: 0.6,
                maxTokens: 300
            )

            return response
        } catch {
            return victory ? "You achieved victory through strategic gameplay." : "Your presidency ended in defeat."
        }
    }

    private func parseNewsJSON(from response: String) -> [NewsEvent]? {
        // Basic JSON parsing
        guard let data = response.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return nil
        }

        return json.compactMap { dict in
            guard let headline = dict["headline"] as? String,
                  let sourceStr = dict["source"] as? String else {
                return nil
            }

            let source = NewsSource.from(sourceStr)
            let severity = NewsSeverity.from(dict["severity"] as? String ?? "routine")

            return NewsEvent(
                headline: headline,
                source: source,
                severity: severity,
                turn: 0
            )
        }
    }

    private func generateBasicNews(gameState: GameState) -> [NewsEvent] {
        var headlines: [NewsEvent] = []

        if !gameState.activeWars.isEmpty {
            let war = gameState.activeWars.first!
            headlines.append(NewsEvent(
                headline: "War continues between \(war.aggressor) and \(war.defender)",
                source: .ap,
                severity: .developing,
                turn: gameState.turn
            ))
        }

        return headlines
    }

    private func generateBasicAdvice(advisor: Advisor, situation: GameSituation) -> String {
        if advisor.hawkishness > 70 {
            return "Recommend strong military response, Mr. President."
        } else if advisor.hawkishness < 40 {
            return "Caution advised. Diplomatic solutions preferred."
        }
        return "Recommend careful consideration of all options."
    }
}

// MARK: - Data Models

struct StoryArc: Identifiable {
    let id = UUID()
    let title: String
    let startTurn: Int
    var events: [String]
    var isResolved: Bool
}

struct AdvisorEvent: Identifiable {
    let id = UUID()
    let advisor: String
    let eventType: EventType
    let description: String
    let turn: Int

    enum EventType {
        case resignation, conflict, scandal, achievement
    }
}

enum GameSituation: String {
    case nuclearThreat, diplomaticCrisis, economicSanctions, covertOperation, domesticCrisis, warDeclaration
}

struct ActionResult {
    var success: Bool
    var message: String
    var relationChange: Int
    var approvalChange: Int = 0
    var economicImpact: Int = 0
}

extension NewsSource {
    static func from(_ string: String) -> NewsSource {
        switch string.uppercased() {
        case "CNN": return .cnn
        case "BBC": return .bbc
        case "FOX": return .fox
        case "RT": return .rt
        case "REUTERS": return .reuters
        case "AP": return .ap
        default: return .ap
        }
    }
}

extension NewsSeverity {
    static func from(_ string: String) -> NewsSeverity {
        switch string.lowercased() {
        case "breaking": return .breaking
        case "developing": return .developing
        default: return .routine
        }
    }
}
