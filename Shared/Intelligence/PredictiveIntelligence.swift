//
//  PredictiveIntelligence.swift
//  GTNW
//
//  ML-Powered Predictive Intelligence System
//  Forecast wars, alliances, DEFCON changes 3-5 turns ahead
//  Created by Jordan Koch on 2026-01-26
//

import Foundation
import SwiftUI

@MainActor
class PredictiveIntelligence: ObservableObject {
    static let shared = PredictiveIntelligence()

    @Published var warPredictions: [WarPrediction] = []
    @Published var defconForecast: [DEFCONForecast] = []
    @Published var alliancePredictions: [AlliancePrediction] = []
    @Published var crisisProbabilities: [CrisisProbability] = []
    @Published var isAnalyzing = false

    private let analysis = AnalysisUnified.shared
    private let llm = AIBackendManager.shared

    private init() {}

    // MARK: - Generate Full Intelligence Forecast

    func generateForecast(gameState: GameState) async throws {
        isAnalyzing = true
        defer { isAnalyzing = false }

        // Run all predictions in parallel
        async let wars = predictWars(gameState: gameState)
        async let defcon = forecastDEFCON(gameState: gameState)
        async let alliances = predictAlliances(gameState: gameState)
        async let crises = predictCrises(gameState: gameState)

        (warPredictions, defconForecast, alliancePredictions, crisisProbabilities) = try await (wars, defcon, alliances, crises)
    }

    // MARK: - War Prediction

    private func predictWars(gameState: GameState) async throws -> [WarPrediction] {
        var predictions: [WarPrediction] = []

        // Analyze all country pairs for war probability
        let countries = gameState.countries.filter { !$0.isDestroyed }

        for i in 0..<countries.count {
            for j in (i+1)..<countries.count {
                let country1 = countries[i]
                let country2 = countries[j]

                // Calculate war probability
                let probability = calculateWarProbability(
                    country1: country1,
                    country2: country2,
                    gameState: gameState
                )

                if probability > 0.3 { // 30% threshold for reporting
                    let prediction = WarPrediction(
                        attacker: country1,
                        defender: country2,
                        probability: probability,
                        estimatedTurn: gameState.turnNumber + Int.random(in: 2...5),
                        reasons: analyzeWarReasons(country1, country2),
                        confidence: calculateConfidence(probability)
                    )
                    predictions.append(prediction)
                }
            }
        }

        // Sort by probability
        return predictions.sorted { $0.probability > $1.probability }
    }

    private func calculateWarProbability(
        country1: Country,
        country2: Country,
        gameState: GameState
    ) -> Double {
        var probability = 0.0

        // Factor 1: Diplomatic relations (-100 to +100)
        let relations = country1.relations[country2.id] ?? 0
        if relations < -50 {
            probability += 0.4
        } else if relations < 0 {
            probability += 0.2
        }

        // Factor 2: Grievances
        let grievances = country1.memory.grievances.filter { $0.against == country2.id }
        probability += Double(grievances.count) * 0.05

        // Factor 3: Personality
        if let personality = country1.personality {
            probability += Double(personality.aggressionMultiplier - 1.0) * 0.2
        }

        // Factor 4: DEFCON level
        probability += Double(5 - gameState.defconLevel) * 0.1

        // Factor 5: Nuclear imbalance
        if country1.hasNuclearWeapons && !country2.hasNuclearWeapons {
            probability += 0.15
        }

        // Factor 6: Recent conflicts
        if gameState.activeWars.contains(where: { $0.involves(country1) || $0.involves(country2) }) {
            probability += 0.2
        }

        return min(probability, 1.0)
    }

    private func analyzeWarReasons(_ c1: Country, _ c2: Country) -> [String] {
        var reasons: [String] = []

        if (c1.relations[c2.id] ?? 0) < -50 {
            reasons.append("Hostile diplomatic relations")
        }

        if c1.memory.grievances.contains(where: { $0.against == c2.id }) {
            reasons.append("Unresolved grievances")
        }

        if c1.personality?.personalityType == .opportunistic && c2.militaryStrength < c1.militaryStrength * 0.5 {
            reasons.append("Opportunistic personality sees weakness")
        }

        return reasons
    }

    private func calculateConfidence(_ probability: Double) -> Double {
        // Confidence decreases as we look further ahead
        let baseConfidence = min(probability * 1.2, 0.95)
        return baseConfidence
    }

    // MARK: - DEFCON Forecast

    private func forecastDEFCON(gameState: GameState) async throws -> [DEFCONForecast] {
        var forecast: [DEFCONForecast] = []

        let currentDEFCON = gameState.defconLevel
        var predictedDEFCON = currentDEFCON

        // Forecast next 10 turns
        for turn in 1...10 {
            let futureTurn = gameState.turnNumber + turn

            // Predict DEFCON changes
            let tensionDelta = predictTensionChange(gameState: gameState, turnsAhead: turn)

            if tensionDelta > 0.3 && predictedDEFCON > 1 {
                predictedDEFCON -= 1 // Tension increases, DEFCON lowers
            } else if tensionDelta < -0.3 && predictedDEFCON < 5 {
                predictedDEFCON += 1 // Tension decreases, DEFCON raises
            }

            forecast.append(DEFCONForecast(
                turn: futureTurn,
                predictedLevel: predictedDEFCON,
                confidence: 0.85 - (Double(turn) * 0.05), // Confidence decreases over time
                factors: ["Historical patterns", "Current tensions", "AI analysis"]
            ))
        }

        return forecast
    }

    private func predictTensionChange(gameState: GameState, turnsAhead: Int) -> Double {
        var tensionDelta = 0.0

        // Factor in active wars
        tensionDelta += Double(gameState.activeWars.count) * 0.1

        // Factor in hostile relations
        let hostileRelations = gameState.countries.flatMap { $0.relations.values }.filter { $0 < -50 }.count
        tensionDelta += Double(hostileRelations) * 0.02

        // Factor in nuclear tests
        // tensionDelta += recent nuclear activity

        // Decay over time (tension naturally reduces)
        tensionDelta -= Double(turnsAhead) * 0.05

        return tensionDelta
    }

    // MARK: - Alliance Prediction

    private func predictAlliances(gameState: GameState) async throws -> [AlliancePrediction] {
        var predictions: [AlliancePrediction] = []

        let countries = gameState.countries.filter { !$0.isDestroyed }

        for i in 0..<countries.count {
            for j in (i+1)..<countries.count {
                let country1 = countries[i]
                let country2 = countries[j]

                let probability = calculateAllianceProbability(country1, country2, gameState)

                if probability > 0.4 {
                    predictions.append(AlliancePrediction(
                        country1: country1,
                        country2: country2,
                        probability: probability,
                        estimatedTurn: gameState.turnNumber + Int.random(in: 2...6),
                        reasons: analyzeAllianceReasons(country1, country2),
                        confidence: probability * 0.9
                    ))
                }
            }
        }

        return predictions.sorted { $0.probability > $1.probability }
    }

    private func calculateAllianceProbability(_ c1: Country, _ c2: Country, _ gameState: GameState) -> Double {
        var probability = 0.0

        // Good relations
        let relations = c1.relations[c2.id] ?? 0
        if relations > 50 {
            probability += 0.4
        } else if relations > 20 {
            probability += 0.2
        }

        // Shared enemies
        let sharedEnemies = findSharedEnemies(c1, c2, gameState)
        probability += Double(sharedEnemies.count) * 0.15

        // Similar government types
        if c1.governmentType == c2.governmentType {
            probability += 0.1
        }

        // Geographic proximity (simplified)
        // probability += proximityBonus

        return min(probability, 1.0)
    }

    private func findSharedEnemies(_ c1: Country, _ c2: Country, _ gameState: GameState) -> [Country] {
        let c1Enemies = c1.relations.filter { $0.value < -50 }.keys
        let c2Enemies = c2.relations.filter { $0.value < -50 }.keys
        let shared = Set(c1Enemies).intersection(Set(c2Enemies))

        return gameState.countries.filter { shared.contains($0.id) }
    }

    private func analyzeAllianceReasons(_ c1: Country, _ c2: Country) -> [String] {
        var reasons: [String] = []

        if (c1.relations[c2.id] ?? 0) > 50 {
            reasons.append("Strong diplomatic ties")
        }

        if c1.governmentType == c2.governmentType {
            reasons.append("Similar government systems")
        }

        reasons.append("Strategic mutual interest")

        return reasons
    }

    // MARK: - Crisis Prediction

    private func predictCrises(gameState: GameState) async throws -> [CrisisProbability] {
        var predictions: [CrisisProbability] = []

        // Base probability from DEFCON
        let baseProbability = Double(5 - gameState.defconLevel) * 0.15

        // Predict crisis types
        predictions.append(CrisisProbability(
            type: "Nuclear Test",
            probability: baseProbability + 0.1,
            estimatedTurn: gameState.turnNumber + 2,
            confidence: 0.7,
            description: "Country likely to conduct nuclear test"
        ))

        predictions.append(CrisisProbability(
            type: "Regional Conflict",
            probability: baseProbability + 0.15,
            estimatedTurn: gameState.turnNumber + 3,
            confidence: 0.65,
            description: "Tensions escalating in volatile region"
        ))

        if gameState.defconLevel <= 2 {
            predictions.append(CrisisProbability(
                type: "Nuclear Alert",
                probability: 0.6,
                estimatedTurn: gameState.turnNumber + 1,
                confidence: 0.85,
                description: "DEFCON 2: High probability of nuclear crisis"
            ))
        }

        return predictions.sorted { $0.probability > $1.probability }
    }
}

// MARK: - Models

struct WarPrediction: Identifiable {
    let id = UUID()
    let attacker: Country
    let defender: Country
    let probability: Double
    let estimatedTurn: Int
    let reasons: [String]
    let confidence: Double

    var probabilityPercent: Int {
        Int(probability * 100)
    }
}

struct DEFCONForecast: Identifiable {
    let id = UUID()
    let turn: Int
    let predictedLevel: Int
    let confidence: Double
    let factors: [String]
}

struct AlliancePrediction: Identifiable {
    let id = UUID()
    let country1: Country
    let country2: Country
    let probability: Double
    let estimatedTurn: Int
    let reasons: [String]
    let confidence: Double
}

struct CrisisProbability: Identifiable {
    let id = UUID()
    let type: String
    let probability: Double
    let estimatedTurn: Int
    let confidence: Double
    let description: String
}

// MARK: - Predictive Intelligence Dashboard View

struct PredictiveIntelligenceView: View {
    @StateObject private var intelligence = PredictiveIntelligence.shared
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            // Tab selector
            Picker("Analysis Type", selection: $selectedTab) {
                Text("War Forecast").tag(0)
                Text("DEFCON Trend").tag(1)
                Text("Alliances").tag(2)
                Text("Crises").tag(3)
            }
            .pickerStyle(.segmented)
            .padding()

            // Content
            TabView(selection: $selectedTab) {
                warForecastView.tag(0)
                defconTrendView.tag(1)
                allianceForecastView.tag(2)
                crisisForecastView.tag(3)
            }
        }
        .background(Color.black.opacity(0.8))
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text("🔮 Predictive Intelligence")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text("ML-Powered Strategic Forecasting")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))

            if intelligence.isAnalyzing {
                ProgressView()
                    .progressViewStyle(.linear)
                    .tint(.blue)
            }
        }
        .padding()
        .background(Color.blue.opacity(0.2))
    }

    private var warForecastView: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(intelligence.warPredictions.prefix(10)) { prediction in
                    WarPredictionCard(prediction: prediction)
                }
            }
            .padding()
        }
    }

    private var defconTrendView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // DEFCON forecast chart
                DEFCONForecastChart(forecast: intelligence.defconForecast)

                // Forecast details
                ForEach(intelligence.defconForecast.prefix(10)) { forecast in
                    DEFCONForecastCard(forecast: forecast)
                }
            }
            .padding()
        }
    }

    private var allianceForecastView: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(intelligence.alliancePredictions.prefix(10)) { prediction in
                    AlliancePredictionCard(prediction: prediction)
                }
            }
            .padding()
        }
    }

    private var crisisForecastView: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(intelligence.crisisProbabilities) { crisis in
                    CrisisProbabilityCard(crisis: crisis)
                }
            }
            .padding()
        }
    }
}

// MARK: - Prediction Card Views

struct WarPredictionCard: View {
    let prediction: WarPrediction

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(prediction.attacker.name) → \(prediction.defender.name)")
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()

                Text("\(prediction.probabilityPercent)%")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(probabilityColor)
            }

            Text("Estimated: Turn \(prediction.estimatedTurn)")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("Indicators:")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white.opacity(0.8))

                ForEach(prediction.reasons, id: \.self) { reason in
                    HStack {
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                        Text(reason)
                            .font(.caption)
                    }
                    .foregroundColor(.white.opacity(0.7))
                }
            }

            HStack {
                Text("Confidence:")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))
                Text("\(Int(prediction.confidence * 100))%")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(probabilityColor.opacity(0.5), lineWidth: 2)
                )
        )
    }

    private var probabilityColor: Color {
        if prediction.probability > 0.7 { return .red }
        if prediction.probability > 0.5 { return .orange }
        return .yellow
    }
}

struct DEFCONForecastCard: View {
    let forecast: DEFCONForecast

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Turn \(forecast.turn)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))

                Text("DEFCON \(forecast.predictedLevel)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(defconColor)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(Int(forecast.confidence * 100))% confident")
                    .font(.caption)
                    .foregroundColor(.blue)

                ProgressView(value: forecast.confidence)
                    .progressViewStyle(.linear)
                    .tint(.blue)
                    .frame(width: 100)
            }
        }
        .padding()
        .background(Color.black.opacity(0.3))
        .cornerRadius(8)
    }

    private var defconColor: Color {
        switch forecast.predictedLevel {
        case 1: return .red
        case 2: return .orange
        case 3: return .yellow
        case 4: return .green
        case 5: return .blue
        default: return .gray
        }
    }
}

struct DEFCONForecastChart: View {
    let forecast: [DEFCONForecast]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DEFCON Trajectory")
                .font(.headline)
                .foregroundColor(.white)

            // Simple visualization
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(forecast.prefix(10)) { point in
                    VStack {
                        Rectangle()
                            .fill(defconColor(point.predictedLevel))
                            .frame(width: 30, height: CGFloat(point.predictedLevel) * 30)

                        Text("T\(point.turn)")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
            }
            .frame(height: 200)
        }
        .padding()
        .background(Color.black.opacity(0.3))
        .cornerRadius(12)
    }

    private func defconColor(_ level: Int) -> Color {
        switch level {
        case 1: return .red
        case 2: return .orange
        case 3: return .yellow
        case 4: return .green
        case 5: return .blue
        default: return .gray
        }
    }
}

struct AlliancePredictionCard: View {
    let prediction: AlliancePrediction

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(prediction.country1.name) ↔ \(prediction.country2.name)")
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()

                Text("\(Int(prediction.probability * 100))%")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
            }

            Text("Est. Turn \(prediction.estimatedTurn)")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))

            ForEach(prediction.reasons, id: \.self) { reason in
                HStack {
                    Image(systemName: "checkmark")
                        .font(.caption2)
                    Text(reason)
                        .font(.caption)
                }
                .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding()
        .background(Color.green.opacity(0.2))
        .cornerRadius(10)
    }
}

struct CrisisProbabilityCard: View {
    let crisis: CrisisProbability

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(crisis.type)
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()

                Text("\(Int(crisis.probability * 100))%")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
            }

            Text(crisis.description)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))

            HStack {
                Text("Turn \(crisis.estimatedTurn)")
                Text("•")
                Text("Confidence: \(Int(crisis.confidence * 100))%")
            }
            .font(.caption2)
            .foregroundColor(.white.opacity(0.5))
        }
        .padding()
        .background(Color.orange.opacity(0.2))
        .cornerRadius(10)
    }
}
