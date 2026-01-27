//
//  EconomicWarfareSimulator.swift
//  GTNW
//
//  Economic Warfare Simulation with Supply Chain Modeling
//  Predict GDP impact, cascading effects, trade routes
//  Created by Jordan Koch on 2026-01-26
//

import Foundation
import SwiftUI

@MainActor
class EconomicWarfareSimulator: ObservableObject {
    static let shared = EconomicWarfareSimulator()

    @Published var isSimulating = false
    @Published var lastSimulation: EconomicImpactSimulation?

    private let analysis = AnalysisUnified.shared

    private init() {}

    // MARK: - Predict Sanction Impact

    func predictSanctionImpact(
        sanctioner: Country,
        target: Country,
        sanctionType: EconomicSanctionType,
        gameState: GameState
    ) async throws -> EconomicImpactSimulation {
        isSimulating = true
        defer { isSimulating = false }

        // Build trade network
        let tradeNetwork = buildTradeNetwork(gameState)

        // Calculate direct impact
        let directImpact = calculateDirectImpact(
            sanctioner: sanctioner,
            target: target,
            sanctionType: sanctionType
        )

        // Calculate cascading effects
        let cascadingEffects = calculateCascadingEffects(
            target: target,
            tradeNetwork: tradeNetwork,
            directImpact: directImpact
        )

        // Identify alternative routes
        let alternativeRoutes = identifyAlternativeRoutes(
            target: target,
            sanctioner: sanctioner,
            tradeNetwork: tradeNetwork
        )

        // Recovery timeline
        let recoveryYears = estimateRecoveryTime(
            target: target,
            impact: directImpact,
            alternatives: alternativeRoutes
        )

        let simulation = EconomicImpactSimulation(
            sanctioner: sanctioner,
            target: target,
            sanctionType: sanctionType,
            targetGDPLoss: directImpact.targetLoss,
            sanctionerGDPCost: directImpact.sanctionerCost,
            affectedCountries: cascadingEffects,
            alternativeRoutes: alternativeRoutes,
            recoveryTimeYears: recoveryYears,
            confidence: 0.75,
            timestamp: Date()
        )

        lastSimulation = simulation
        return simulation
    }

    // MARK: - Trade Network

    private func buildTradeNetwork(_ gameState: GameState) -> TradeNetwork {
        var connections: [TradeConnection] = []

        // Simplified trade network
        for country in gameState.countries {
            let partners = gameState.countries.filter { other in
                let relations = country.relations[other.id] ?? 0
                return relations > 20 && other.id != country.id
            }

            for partner in partners {
                let volume = estimateTradeVolume(country, partner)
                connections.append(TradeConnection(
                    from: country,
                    to: partner,
                    volume: volume,
                    dependency: volume / country.gdp
                ))
            }
        }

        return TradeNetwork(connections: connections)
    }

    private func estimateTradeVolume(_ c1: Country, _ c2: Country) -> Double {
        // Simplified: Based on GDP and relations
        let relations = c1.relations[c2.id] ?? 0
        let baseVolume = min(c1.gdp, c2.gdp) * 0.05
        let relationsFactor = Double(relations + 100) / 200.0
        return baseVolume * relationsFactor
    }

    // MARK: - Impact Calculations

    private func calculateDirectImpact(
        sanctioner: Country,
        target: Country,
        sanctionType: EconomicSanctionType
    ) -> DirectEconomicImpact {
        // Trade dependency
        let tradeDependency = estimateTradeVolume(target, sanctioner) / target.gdp

        // Sanction severity multiplier
        let severityMultiplier: Double
        switch sanctionType {
        case .tradeBan:
            severityMultiplier = 1.0
        case .techBan:
            severityMultiplier = 0.6
        case .armsBan:
            severityMultiplier = 0.3
        case .financialFreeze:
            severityMultiplier = 0.8
        case .fullEmbargo:
            severityMultiplier = 1.5
        }

        let targetLoss = tradeDependency * severityMultiplier * 100.0
        let sanctionerCost = (estimateTradeVolume(sanctioner, target) / sanctioner.gdp) * 0.5 * 100.0

        return DirectEconomicImpact(
            targetLoss: targetLoss,
            sanctionerCost: sanctionerCost
        )
    }

    private func calculateCascadingEffects(
        target: Country,
        tradeNetwork: TradeNetwork,
        directImpact: DirectEconomicImpact
    ) -> [CountryEconomicEffect] {
        var effects: [CountryEconomicEffect] = []

        // Find trade partners of target
        let targetConnections = tradeNetwork.connections.filter {
            $0.from.id == target.id || $0.to.id == target.id
        }

        for connection in targetConnections {
            let affectedCountry = connection.from.id == target.id ? connection.to : connection.from
            let impact = connection.dependency * directImpact.targetLoss * 0.3

            if impact > 1.0 {
                effects.append(CountryEconomicEffect(
                    country: affectedCountry,
                    gdpImpact: impact,
                    reason: "Trade disruption with \(target.name)"
                ))
            }
        }

        return effects.sorted { $0.gdpImpact > $1.gdpImpact }
    }

    private func identifyAlternativeRoutes(
        target: Country,
        sanctioner: Country,
        tradeNetwork: TradeNetwork
    ) -> [AlternativeRoute] {
        // Find alternative trade partners
        var alternatives: [AlternativeRoute] = []

        let potentialPartners = tradeNetwork.connections
            .filter { $0.to.id != sanctioner.id && $0.from.id != sanctioner.id }
            .map { $0.to }

        for partner in potentialPartners.prefix(5) {
            alternatives.append(AlternativeRoute(
                partner: partner,
                replacementCapacity: estimateReplacementCapacity(target, partner),
                timeToEstablish: Int.random(in: 2...8)
            ))
        }

        return alternatives
    }

    private func estimateReplacementCapacity(_ target: Country, _ alternative: Country) -> Double {
        return min(alternative.gdp / target.gdp, 1.0) * 0.7
    }

    private func estimateRecoveryTime(
        target: Country,
        impact: DirectEconomicImpact,
        alternatives: [AlternativeRoute]
    ) -> Int {
        let baseRecovery = Int(impact.targetLoss / 10.0)
        let alternativesFactor = alternatives.reduce(0.0) { $0 + $1.replacementCapacity } / Double(alternatives.count)
        return max(Int(Double(baseRecovery) * (1.0 - alternativesFactor)), 1)
    }
}

// MARK: - Models

struct EconomicImpactSimulation {
    let sanctioner: Country
    let target: Country
    let sanctionType: EconomicSanctionType
    let targetGDPLoss: Double // Percentage
    let sanctionerGDPCost: Double // Percentage
    let affectedCountries: [CountryEconomicEffect]
    let alternativeRoutes: [AlternativeRoute]
    let recoveryTimeYears: Int
    let confidence: Double
    let timestamp: Date
}

struct DirectEconomicImpact {
    let targetLoss: Double
    let sanctionerCost: Double
}

struct TradeNetwork {
    let connections: [TradeConnection]
}

struct TradeConnection {
    let from: Country
    let to: Country
    let volume: Double
    let dependency: Double // How dependent 'from' is on 'to'
}

struct CountryEconomicEffect {
    let country: Country
    let gdpImpact: Double
    let reason: String
}

struct AlternativeRoute {
    let partner: Country
    let replacementCapacity: Double // 0.0 to 1.0
    let timeToEstablish: Int // turns
}

enum EconomicSanctionType: String {
    case tradeBan = "Trade Ban"
    case techBan = "Technology Ban"
    case armsBan = "Arms Embargo"
    case financialFreeze = "Financial Freeze"
    case fullEmbargo = "Full Embargo"
}

// MARK: - Economic Impact View

struct EconomicImpactView: View {
    let simulation: EconomicImpactSimulation

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Text("💰 Economic Warfare Simulation")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Text("\(simulation.sanctioner.name) vs \(simulation.target.name)")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.7))
                }

                // Direct impact
                HStack(spacing: 32) {
                    impactCard("Target Loss", simulation.targetGDPLoss, .red)
                    impactCard("Your Cost", simulation.sanctionerGDPCost, .orange)
                }

                // Cascading effects
                if !simulation.affectedCountries.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("⚠️ Collateral Damage:")
                            .font(.headline)
                            .foregroundColor(.white)

                        ForEach(simulation.affectedCountries.prefix(5), id: \.country.id) { effect in
                            HStack {
                                Text(effect.country.name)
                                    .foregroundColor(.white)
                                Spacer()
                                Text("-\(String(format: "%.1f", effect.gdpImpact))%")
                                    .foregroundColor(.orange)
                            }
                            .font(.caption)
                        }
                    }
                    .padding()
                    .background(Color.orange.opacity(0.2))
                    .cornerRadius(12)
                }

                // Alternative routes
                if !simulation.alternativeRoutes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("🔄 Alternative Trade Routes:")
                            .font(.headline)
                            .foregroundColor(.white)

                        ForEach(simulation.alternativeRoutes.prefix(5), id: \.partner.id) { route in
                            HStack {
                                Text(route.partner.name)
                                    .foregroundColor(.white)
                                Spacer()
                                Text("\(Int(route.replacementCapacity * 100))% capacity")
                                    .foregroundColor(.green)
                                Text("• \(route.timeToEstablish) turns")
                                    .foregroundColor(.gray)
                            }
                            .font(.caption)
                        }
                    }
                    .padding()
                    .background(Color.green.opacity(0.2))
                    .cornerRadius(12)
                }

                // Recovery time
                VStack(spacing: 8) {
                    Text("Recovery Estimate")
                        .font(.headline)
                        .foregroundColor(.white)

                    Text("\(simulation.recoveryTimeYears) years")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)

                    Text("Confidence: \(Int(simulation.confidence * 100))%")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding()
                .background(Color.blue.opacity(0.2))
                .cornerRadius(12)
            }
            .padding()
        }
    }

    private func impactCard(_ label: String, _ value: Double, _ color: Color) -> some View {
        VStack(spacing: 8) {
            Text("-\(String(format: "%.1f", value))%")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(color)

            Text(label)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
        .padding()
        .frame(minWidth: 120)
        .background(color.opacity(0.2))
        .cornerRadius(12)
    }
}
