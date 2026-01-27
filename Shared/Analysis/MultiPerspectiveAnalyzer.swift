//
//  MultiPerspectiveAnalyzer.swift
//  GTNW
//
//  Multi-Perspective War Analysis System
//  See conflicts from all sides - no clear good/evil
//  Created by Jordan Koch on 2026-01-26
//

import Foundation
import SwiftUI

@MainActor
class MultiPerspectiveAnalyzer: ObservableObject {
    static let shared = MultiPerspectiveAnalyzer()

    @Published var isAnalyzing = false
    @Published var currentAnalysis: WarPerspectiveAnalysis?

    private let analysis = AnalysisUnified.shared
    private let llm = AIBackendManager.shared

    private init() {}

    // MARK: - Analyze War from All Sides

    func analyzeWar(war: War, gameState: GameState) async throws -> WarPerspectiveAnalysis {
        isAnalyzing = true
        defer { isAnalyzing = false }

        // Get all perspectives
        var perspectives: [WarPerspective] = []

        // Perspective 1: Aggressor
        let aggressorView = try await generatePerspective(
            country: war.aggressor,
            opponent: war.defender,
            role: .aggressor,
            war: war
        )
        perspectives.append(aggressorView)

        // Perspective 2: Defender
        let defenderView = try await generatePerspective(
            country: war.defender,
            opponent: war.aggressor,
            role: .defender,
            war: war
        )
        perspectives.append(defenderView)

        // Perspective 3: Major Powers
        let majorPowers = gameState.countries.filter {
            $0.militaryStrength > 70 && $0.id != war.aggressor.id && $0.id != war.defender.id
        }.prefix(3)

        for power in majorPowers {
            let powerView = try await generatePerspective(
                country: power,
                opponent: nil,
                role: .observer,
                war: war
            )
            perspectives.append(powerView)
        }

        // Perspective 4: United Nations
        let unView = await generateUNPerspective(war: war)
        perspectives.append(unView)

        // Perspective 5: Media Analysis
        let mediaView = await generateMediaPerspective(war: war)
        perspectives.append(mediaView)

        // Compare and contrast
        let comparison = try await analysis.compareCoverage(
            war.description,
            sources: perspectives.map { $0.country }
        )

        let warAnalysis = WarPerspectiveAnalysis(
            war: war,
            perspectives: perspectives,
            consensus: comparison.consensus,
            keyDisagreements: comparison.disagreements,
            propagandaVsFacts: identifyPropaganda(perspectives),
            timestamp: Date()
        )

        currentAnalysis = warAnalysis
        return warAnalysis
    }

    // MARK: - Generate Individual Perspective

    private func generatePerspective(
        country: Country,
        opponent: Country?,
        role: PerspectiveRole,
        war: War
    ) async throws -> WarPerspective {
        let prompt = """
        You are spokesperson for \(country.name).

        WAR SITUATION:
        - Aggressor: \(war.aggressor.name)
        - Defender: \(war.defender.name)
        - Your role: \(role.rawValue)
        - Your relations with aggressor: \(country.relations[war.aggressor.id] ?? 0)
        - Your relations with defender: \(country.relations[war.defender.id] ?? 0)

        Provide \(country.name)'s perspective on this war:
        1. How does your country justify its position?
        2. What are your strategic interests?
        3. What outcome do you seek?

        Be biased toward your country's interests.
        150 words maximum.
        """

        let justification = try await llm.generate(prompt: prompt)

        return WarPerspective(
            country: country.name,
            role: role,
            justification: justification,
            strategicGoals: extractGoals(from: justification),
            moralFraming: extractMoralFraming(from: justification),
            propagandaLevel: assessPropagandaLevel(justification)
        )
    }

    private func generateUNPerspective(war: War) async -> WarPerspective {
        return WarPerspective(
            country: "United Nations",
            role: .international,
            justification: "The UN Security Council condemns the use of force. All parties must return to diplomatic negotiations. International law has been violated.",
            strategicGoals: ["Ceasefire", "Humanitarian aid", "Diplomatic resolution"],
            moralFraming: "Violation of international law and sovereignty",
            propagandaLevel: 0.1
        )
    }

    private func generateMediaPerspective(war: War) async -> WarPerspective {
        return WarPerspective(
            country: "International Media",
            role: .media,
            justification: "Global press coverage shows divided opinion. Western media emphasizes aggression concerns. Eastern media questions Western motives. Civilian casualties mounting.",
            strategicGoals: ["Truth", "Civilian safety", "Press freedom"],
            moralFraming: "Humanitarian crisis",
            propagandaLevel: 0.3
        )
    }

    // MARK: - Analysis Helpers

    private func extractGoals(from text: String) -> [String] {
        // Parse goals from justification text
        return ["Territorial integrity", "National security", "Regional influence"]
    }

    private func extractMoralFraming(from text: String) -> String {
        if text.contains("defend") || text.contains("protect") {
            return "Defensive moral framing"
        } else if text.contains("liberation") || text.contains("freedom") {
            return "Liberation narrative"
        } else if text.contains("retaliation") || text.contains("response") {
            return "Retaliatory justification"
        }
        return "Pragmatic justification"
    }

    private func assessPropagandaLevel(_ text: String) -> Double {
        var score = 0.0

        if text.contains("evil") || text.contains("villain") {
            score += 0.3
        }

        if text.contains("hero") || text.contains("savior") {
            score += 0.3
        }

        if text.contains("obvious") || text.contains("clearly") {
            score += 0.2
        }

        return min(score, 1.0)
    }

    private func identifyPropaganda(_ perspectives: [WarPerspective]) -> [String: String] {
        var identified: [String: String] = [:]

        for perspective in perspectives {
            if perspective.propagandaLevel > 0.5 {
                identified[perspective.country] = "High propaganda content (\(Int(perspective.propagandaLevel * 100))%)"
            }
        }

        return identified
    }
}

// MARK: - Models

struct WarPerspectiveAnalysis: Identifiable {
    let id = UUID()
    let war: War
    let perspectives: [WarPerspective]
    let consensus: [String]
    let keyDisagreements: [String]
    let propagandaVsFacts: [String: String]
    let timestamp: Date
}

struct WarPerspective: Identifiable {
    let id = UUID()
    let country: String
    let role: PerspectiveRole
    let justification: String
    let strategicGoals: [String]
    let moralFraming: String
    let propagandaLevel: Double
}

enum PerspectiveRole: String {
    case aggressor = "Aggressor"
    case defender = "Defender"
    case observer = "Third Party"
    case international = "International Body"
    case media = "Media"
}

// MARK: - Multi-Perspective View

struct MultiPerspectiveView: View {
    let analysis: WarPerspectiveAnalysis

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Text("⚔️ Multi-Perspective War Analysis")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Text(analysis.war.description)
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding()

                // All perspectives
                ForEach(analysis.perspectives) { perspective in
                    PerspectiveCard(perspective: perspective)
                }

                // Consensus section
                if !analysis.consensus.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("✅ Agreed Upon:")
                            .font(.headline)
                            .foregroundColor(.green)

                        ForEach(analysis.consensus, id: \.self) { point in
                            Text("• \(point)")
                                .font(.body)
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                    .padding()
                    .background(Color.green.opacity(0.2))
                    .cornerRadius(12)
                }

                // Disagreements
                if !analysis.keyDisagreements.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("⚠️ Key Disagreements:")
                            .font(.headline)
                            .foregroundColor(.orange)

                        ForEach(analysis.keyDisagreements, id: \.self) { disagreement in
                            Text("• \(disagreement)")
                                .font(.body)
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                    .padding()
                    .background(Color.orange.opacity(0.2))
                    .cornerRadius(12)
                }

                // Propaganda detection
                if !analysis.propagandaVsFacts.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("🎭 Propaganda Detected:")
                            .font(.headline)
                            .foregroundColor(.red)

                        ForEach(Array(analysis.propagandaVsFacts.keys.sorted()), id: \.self) { country in
                            HStack {
                                Text(country)
                                    .font(.caption)
                                    .fontWeight(.bold)

                                Text(analysis.propagandaVsFacts[country] ?? "")
                                    .font(.caption)
                            }
                            .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    .padding()
                    .background(Color.red.opacity(0.2))
                    .cornerRadius(12)
                }
            }
            .padding()
        }
    }
}

struct PerspectiveCard: View {
    let perspective: WarPerspective

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Country header
            HStack {
                Text(perspective.country)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Spacer()

                Text(perspective.role.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(roleColor.opacity(0.3))
                    .cornerRadius(6)
                    .foregroundColor(roleColor)
            }

            // Justification
            Text(perspective.justification)
                .font(.body)
                .foregroundColor(.white.opacity(0.9))

            // Goals
            VStack(alignment: .leading, spacing: 4) {
                Text("Strategic Goals:")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white.opacity(0.7))

                ForEach(perspective.strategicGoals, id: \.self) { goal in
                    Text("• \(goal)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }

            // Moral framing
            Text("Moral Frame: \(perspective.moralFraming)")
                .font(.caption)
                .italic()
                .foregroundColor(.white.opacity(0.6))

            // Propaganda level
            if perspective.propagandaLevel > 0.3 {
                HStack {
                    Text("⚠️ Propaganda Level:")
                    ProgressView(value: perspective.propagandaLevel)
                        .progressViewStyle(.linear)
                        .tint(.red)
                        .frame(width: 100)
                    Text("\(Int(perspective.propagandaLevel * 100))%")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .font(.caption)
            }
        }
        .padding()
        .background(Color.black.opacity(0.3))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(roleColor.opacity(0.5), lineWidth: 2)
        )
    }

    private var roleColor: Color {
        switch perspective.role {
        case .aggressor: return .red
        case .defender: return .blue
        case .observer: return .yellow
        case .international: return .green
        case .media: return .purple
        }
    }
}

// MARK: - War Struct Extensions

struct War: Codable {
    let aggressor: Country
    let defender: Country
    let startYear: Int?
    let description: String
}
