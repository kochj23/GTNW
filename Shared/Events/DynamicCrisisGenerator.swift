//
//  DynamicCrisisGenerator.swift
//  GTNW
//
//  Dynamic Crisis Generator - AI Creates New Scenarios
//  Infinite replayability beyond 290 historical crises
//  Created by Jordan Koch on 2026-01-26
//

import Foundation
import SwiftUI

@MainActor
class DynamicCrisisGenerator: ObservableObject {
    static let shared = DynamicCrisisGenerator()

    @Published var isGenerating = false
    @Published var generatedCrises: [DynamicCrisis] = []

    private let llm = AIBackendManager.shared

    private init() {}

    // MARK: - Generate Crisis

    func generateCrisis(gameState: GameState) async throws -> DynamicCrisis {
        isGenerating = true
        defer { isGenerating = false }

        let prompt = """
        Generate a realistic geopolitical crisis for a Cold War strategy game.

        CURRENT GAME STATE:
        - Turn: \(gameState.turn)
        - Year: \(gameState.currentYear)
        - DEFCON: \(gameState.defconLevel.description)
        - Active Wars: \(gameState.activeWars.map { "\($0.aggressor) vs \($0.defender)" }.joined(separator: "; "))
        - Player Country: \(gameState.playerCountryID)
        - Unstable Countries: \(findUnstableCountries(gameState).map { $0.name }.joined(separator: ", "))
        - Recent Events: \(gameState.recentEvents.suffix(5).joined(separator: "; "))

        GENERATE:
        1. **Crisis Title** (15-20 words, dramatic)
        2. **Description** (150-200 words, include context and stakes)
        3. **Four Decision Options** (each with consequences)
        4. **Crisis Severity** (Low/Medium/High/Critical)
        5. **Countries Involved** (2-4 countries)

        Requirements:
        - Historically plausible given the era and game state
        - Morally complex (no obvious right answer)
        - Consequences should be realistic
        - Reference current tensions and recent events
        - Make it feel urgent and important

        Format as JSON with keys: title, description, options (array of {title, outcome}), severity, countries
        """

        let response = try await llm.generate(prompt: prompt)

        // Parse JSON response
        let crisis = try parseCrisisJSON(response)

        // Image generation happens at the app level (not shared code)
        let dynamicCrisis = DynamicCrisis(
            id: UUID(),
            title: crisis.title,
            description: crisis.description,
            year: gameState.currentYear,
            countries: crisis.countries,
            options: crisis.options,
            severity: crisis.severity,
            imageData: nil,
            generatedAt: Date()
        )

        generatedCrises.append(dynamicCrisis)
        return dynamicCrisis
    }

    // MARK: - Context-Aware Generation

    private func findUnstableCountries(_ gameState: GameState) -> [Country] {
        return gameState.countries.filter { country in
            let hasWar = gameState.activeWars.contains { $0.aggressor == country.id || $0.defender == country.id }
            let lowStability = country.stability < 40
            let poorEconomy = country.economicStrength < 30
            return hasWar || lowStability || poorEconomy
        }.prefix(5).map { $0 }
    }

    // MARK: - Parse Crisis from LLM

    private func parseCrisisJSON(_ json: String) throws -> ParsedCrisis {
        guard let jsonData = json.data(using: .utf8) else {
            return parseFallback(json)
        }

        do {
            let decoded = try JSONDecoder().decode(ParsedCrisisJSON.self, from: jsonData)
            let options = decoded.options.map { opt in
                CrisisOption(
                    title: opt.title,
                    description: opt.outcome,
                    consequences: CrisisConsequences(message: opt.outcome)
                )
            }
            return ParsedCrisis(
                title: decoded.title,
                description: decoded.description,
                countries: decoded.countries,
                options: options,
                severity: DynamicSeverity(rawValue: decoded.severity) ?? .medium
            )
        } catch {
            return parseFallback(json)
        }
    }

    private func parseFallback(_ text: String) -> ParsedCrisis {
        let lines = text.components(separatedBy: "\n")
        let title = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Crisis Alert"
        let description = text.components(separatedBy: "\n\n").first ?? text

        let options = [
            CrisisOption(title: "Diplomatic approach",
                         description: "Attempt to resolve through negotiation",
                         consequences: CrisisConsequences(message: "Diplomatic solution pursued")),
            CrisisOption(title: "Military response",
                         description: "Show strength through military action",
                         consequences: CrisisConsequences(message: "Military action taken")),
            CrisisOption(title: "Economic pressure",
                         description: "Use sanctions and economic tools",
                         consequences: CrisisConsequences(message: "Economic pressure applied")),
            CrisisOption(title: "Covert operations",
                         description: "Handle situation through intelligence",
                         consequences: CrisisConsequences(message: "Covert action initiated"))
        ]

        return ParsedCrisis(
            title: title,
            description: description,
            countries: ["USA"],
            options: options,
            severity: .medium
        )
    }

    struct ParsedCrisisJSON: Codable {
        let title: String
        let description: String
        let countries: [String]
        let options: [OptionJSON]
        let severity: String

        struct OptionJSON: Codable {
            let title: String
            let outcome: String
        }
    }
}

// MARK: - Models

struct DynamicCrisis: Identifiable, Codable {
    let id: UUID
    let title: String
    let description: String
    let year: Int
    let countries: [String]
    let options: [CrisisOption]
    let severity: DynamicSeverity
    let imageData: Data?
    let generatedAt: Date
}

struct ParsedCrisis {
    let title: String
    let description: String
    let countries: [String]
    let options: [CrisisOption]
    let severity: DynamicSeverity
}

enum DynamicSeverity: String, Codable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case critical = "Critical"

    var color: Color {
        switch self {
        case .low: return .green
        case .medium: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
}

// MARK: - Dynamic Crisis View

struct DynamicCrisisView: View {
    let crisis: DynamicCrisis
    @State private var selectedOption: Int?

    var body: some View {
        VStack(spacing: 16) {
            severityHeader
            crisisContent
            optionsList
        }
        .padding(24)
        .frame(maxWidth: 600)
    }

    private var severityHeader: some View {
        HStack {
            Text(crisis.severity.rawValue.uppercased())
                .font(.caption).fontWeight(.bold)
                .foregroundColor(crisis.severity.color)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(crisis.severity.color.opacity(0.2))
                .cornerRadius(8)
            Spacer()
            Text("Turn \(crisis.year)").font(.caption).foregroundColor(.white.opacity(0.6))
        }
    }

    private var crisisContent: some View {
        VStack(spacing: 12) {
            Text(crisis.title).font(.title2).fontWeight(.bold).foregroundColor(.white).multilineTextAlignment(.center)
            if let imageData = crisis.imageData, let nsImage = NSImage(data: imageData) {
                Image(nsImage: nsImage).resizable().aspectRatio(contentMode: .fill).frame(height: 200).clipped().cornerRadius(12)
            }
            Text(crisis.description).font(.body).foregroundColor(.white.opacity(0.9)).padding().background(Color.black.opacity(0.3)).cornerRadius(10)
        }
    }

    private var optionsList: some View {
        VStack(spacing: 12) {
            ForEach(Array(crisis.options.enumerated()), id: \.offset) { index, option in
                Button(action: { selectedOption = index }) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(option.title).font(.headline).foregroundColor(.white)
                        Text("→ \(option.description)").font(.caption).foregroundColor(.white.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading).padding()
                    .background(selectedOption == index ? Color.blue.opacity(0.3) : Color.gray.opacity(0.2))
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(selectedOption == index ? Color.blue : Color.clear, lineWidth: 2))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
