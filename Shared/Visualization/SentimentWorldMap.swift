//
//  SentimentWorldMap.swift
//  GTNW
//
//  Sentiment-Based World Map Visualization
//  Countries show emotional states, not just numbers
//  Created by Jordan Koch on 2026-01-26
//

import Foundation
import SwiftUI

@MainActor
class SentimentWorldMap: ObservableObject {
    static let shared = SentimentWorldMap()

    @Published var countrySentiments: [String: NationalSentiment] = [:]
    @Published var isAnalyzing = false

    private let sentiment = AnalysisUnified.shared

    private init() {}

    // MARK: - Analyze National Sentiments

    func analyzeAllSentiments(gameState: GameState) async throws {
        isAnalyzing = true
        defer { isAnalyzing = false }

        for country in gameState.countries {
            let sentiment = try await analyzeCountrySentiment(
                country: country,
                gameState: gameState
            )
            countrySentiments[country.id] = sentiment
        }
    }

    private func analyzeCountrySentiment(
        country: Country,
        gameState: GameState
    ) async throws -> NationalSentiment {
        // Gather recent events affecting this country
        let relevantEvents = gameState.recentEvents.filter { event in
            event.contains(country.name)
        }

        // Analyze sentiment
        let eventText = relevantEvents.joined(separator: ". ")
        let sentimentResult = try await sentiment.analyzeSentiment(eventText)

        // Determine primary emotion
        let primaryEmotion = determinePrimaryEmotion(
            country: country,
            gameState: gameState,
            sentimentResult: sentimentResult
        )

        return NationalSentiment(
            country: country.id,
            primaryEmotion: primaryEmotion,
            intensity: sentimentResult.score,
            towards: analyzeTargetSentiments(country, gameState),
            factors: identifyEmotionalFactors(country, gameState),
            timestamp: Date()
        )
    }

    private func determinePrimaryEmotion(
        country: Country,
        gameState: GameState,
        sentimentResult: SentimentResult
    ) -> NationalEmotion {
        // Check game state for specific triggers
        let inWar = gameState.activeWars.contains { $0.involves(country) }
        let recentAttack = country.memory.grievances.contains { $0.turn > gameState.turnNumber - 3 }
        let hasAllies = country.relations.values.filter { $0 > 60 }.count > 3
        let isStrong = country.militaryStrength > 70

        if recentAttack && country.hasNuclearWeapons {
            return .vengeful
        } else if recentAttack {
            return .fearful
        } else if inWar && isStrong {
            return .emboldened
        } else if inWar && !isStrong {
            return .desperate
        } else if hasAllies && isStrong {
            return .confident
        } else if country.personality?.personalityType == .unpredictable {
            return .paranoid
        } else {
            return .neutral
        }
    }

    private func analyzeTargetSentiments(
        _ country: Country,
        _ gameState: GameState
    ) -> [String: EmotionalStance] {
        var sentiments: [String: EmotionalStance] = [:]

        for (targetID, relations) in country.relations {
            let stance: EmotionalStance

            if relations > 60 {
                stance = .friendly
            } else if relations < -60 {
                stance = .hostile
            } else if country.memory.grievances.contains(where: { $0.against == targetID }) {
                stance = .resentful
            } else if relations > 20 {
                stance = .cautious
            } else {
                stance = .neutral
            }

            sentiments[targetID] = stance
        }

        return sentiments
    }

    private func identifyEmotionalFactors(
        _ country: Country,
        _ gameState: GameState
    ) -> [String] {
        var factors: [String] = []

        if gameState.activeWars.contains(where: { $0.involves(country) }) {
            factors.append("Currently at war")
        }

        if country.memory.grievances.count > 3 {
            factors.append("Multiple grievances")
        }

        if (country.relations.values.filter { $0 > 60 }.count) > 5 {
            factors.append("Strong alliance network")
        }

        if country.hasNuclearWeapons {
            factors.append("Nuclear deterrent provides confidence")
        }

        return factors
    }
}

// MARK: - Models

struct NationalSentiment: Codable {
    let country: String
    let primaryEmotion: NationalEmotion
    let intensity: Double // 0.0 to 1.0
    let towards: [String: EmotionalStance]
    let factors: [String]
    let timestamp: Date
}

enum NationalEmotion: String, Codable {
    case vengeful = "VENGEFUL"
    case fearful = "FEARFUL"
    case emboldened = "EMBOLDENED"
    case desperate = "DESPERATE"
    case confident = "CONFIDENT"
    case paranoid = "PARANOID"
    case neutral = "NEUTRAL"
    case anxious = "ANXIOUS"

    var color: Color {
        switch self {
        case .vengeful: return .red
        case .fearful: return .purple
        case .emboldened: return .orange
        case .desperate: return .red
        case .confident: return .green
        case .paranoid: return .yellow
        case .neutral: return .gray
        case .anxious: return .yellow
        }
    }

    var description: String {
        switch self {
        case .vengeful: return "Seeking revenge for past wrongs"
        case .fearful: return "Afraid of imminent threats"
        case .emboldened: return "Confident and aggressive"
        case .desperate: return "Back against the wall"
        case .confident: return "Secure and stable"
        case .paranoid: return "Suspicious of all neighbors"
        case .neutral: return "Balanced emotional state"
        case .anxious: return "Nervous about future"
        }
    }
}

enum EmotionalStance: String, Codable {
    case friendly = "Friendly"
    case hostile = "Hostile"
    case resentful = "Resentful"
    case cautious = "Cautious"
    case neutral = "Neutral"
}

struct DynamicCrisis: Identifiable, Codable {
    let id: UUID
    let title: String
    let description: String
    let year: Int
    let countries: [String]
    let options: [CrisisOption]
    let severity: CrisisSeverity
    let imageData: Data?
    let generatedBy: String // "AI" vs "Historical"
    let timestamp: Date
}

// MARK: - Sentiment World Map View

struct SentimentWorldMapView: View {
    @StateObject private var sentimentMap = SentimentWorldMap.shared
    @State private var selectedCountry: Country?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Map and legend
            HStack(spacing: 0) {
                // Interactive map (simplified)
                mapView
                    .frame(maxWidth: .infinity)

                Divider()

                // Legend and details
                legendView
                    .frame(width: 300)
            }
        }
        .background(Color.black.opacity(0.9))
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text("🗺️ Sentiment World Map")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text("Emotional state of nations")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
        .padding()
        .background(Color.blue.opacity(0.2))
    }

    private var mapView: some View {
        ZStack {
            Color.gray.opacity(0.2)

            // Would render actual world map with country colors
            Text("World Map\n(Countries colored by emotion)")
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.5))
        }
    }

    private var legendView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Emotional States:")
                    .font(.headline)
                    .foregroundColor(.white)

                ForEach([NationalEmotion.vengeful, .fearful, .emboldened, .desperate, .confident, .paranoid, .neutral], id: \.self) { emotion in
                    HStack {
                        Circle()
                            .fill(emotion.color)
                            .frame(width: 16, height: 16)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(emotion.rawValue)
                                .font(.caption)
                                .fontWeight(.bold)

                            Text(emotion.description)
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .foregroundColor(.white)
                    }
                }

                Divider()

                if let country = selectedCountry,
                   let sentiment = sentimentMap.countrySentiments[country.id] {
                    selectedCountryDetails(country, sentiment)
                }
            }
            .padding()
        }
    }

    private func selectedCountryDetails(_ country: Country, _ sentiment: NationalSentiment) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(country.name)
                .font(.headline)
                .foregroundColor(.white)

            HStack {
                Text("Feeling:")
                    .font(.caption)
                Text(sentiment.primaryEmotion.rawValue)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(sentiment.primaryEmotion.color)
            }

            Text("Intensity: \(Int(sentiment.intensity * 100))%")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))

            VStack(alignment: .leading, spacing: 4) {
                Text("Factors:")
                    .font(.caption)
                    .fontWeight(.bold)

                ForEach(sentiment.factors, id: \.self) { factor in
                    Text("• \(factor)")
                        .font(.caption2)
                }
            }
            .foregroundColor(.white.opacity(0.7))
        }
        .padding()
        .background(sentiment.primaryEmotion.color.opacity(0.2))
        .cornerRadius(12)
    }
}
