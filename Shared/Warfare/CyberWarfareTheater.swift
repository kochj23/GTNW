//
//  CyberWarfareTheater.swift
//  GTNW
//
//  Expanded Cyber Warfare System
//  Target specific infrastructure, attribution challenges
//  Created by Jordan Koch on 2026-01-26
//

import Foundation
import SwiftUI

@MainActor
class CyberWarfareTheater: ObservableObject {
    static let shared = CyberWarfareTheater()

    @Published var activeOperations: [CyberOperation] = []
    @Published var isExecuting = false

    private let security = SecurityUnified.shared

    private init() {}

    // MARK: - Execute Cyber Attack

    func executeCyberAttack(
        attacker: Country,
        target: Country,
        attackType: CyberAttackType,
        attribution: AttributionLevel
    ) async throws -> CyberAttackResult {
        isExecuting = true
        defer { isExecuting = false }

        // Calculate success probability
        let successProbability = calculateSuccessProbability(
            attacker: attacker,
            target: target,
            attackType: attackType
        )

        let success = Double.random(in: 0...1) < successProbability

        // Calculate damage
        let damage = success ? calculateDamage(attackType, target: target) : CyberDamage.none

        // Attribution chance
        let discovered = shouldBeAttributed(attribution, target: target)

        let result = CyberAttackResult(
            attacker: attacker,
            target: target,
            attackType: attackType,
            success: success,
            damage: damage,
            discovered: discovered,
            retaliationProbability: calculateRetaliationProbability(discovered, damage, target),
            timestamp: Date()
        )

        // Record operation
        let operation = CyberOperation(
            id: UUID(),
            attacker: attacker.id,
            target: target.id,
            type: attackType,
            result: result,
            timestamp: Date()
        )
        activeOperations.append(operation)

        return result
    }

    // MARK: - Attack Types

    private func calculateSuccessProbability(
        attacker: Country,
        target: Country,
        attackType: CyberAttackType
    ) -> Double {
        var probability = 0.5

        // Attacker capability
        probability += (attacker.cyberOffenseCapability / 100.0) * 0.3

        // Target defenses
        probability -= (target.cyberDefenseCapability / 100.0) * 0.3

        // Attack complexity
        switch attackType {
        case .ddos:
            probability += 0.2 // Easier
        case .infrastructureDisruption, .militaryComms:
            probability += 0.0 // Moderate
        case .nuclearSystems, .financialCollapse:
            probability -= 0.3 // Harder
        case .falseFlagOperation:
            probability -= 0.2 // Complex
        }

        return max(0.1, min(probability, 0.95))
    }

    private func calculateDamage(_ attackType: CyberAttackType, target: Country) -> CyberDamage {
        switch attackType {
        case .ddos:
            return CyberDamage(
                infrastructureDamage: 10,
                economicLoss: 5,
                militaryDegradation: 0,
                publicPanic: 15,
                duration: 2 // turns
            )

        case .powerGrid:
            return CyberDamage(
                infrastructureDamage: 40,
                economicLoss: 25,
                militaryDegradation: 10,
                publicPanic: 50,
                duration: 5
            )

        case .militaryComms:
            return CyberDamage(
                infrastructureDamage: 20,
                economicLoss: 10,
                militaryDegradation: 35,
                publicPanic: 20,
                duration: 3
            )

        case .nuclearSystems:
            return CyberDamage(
                infrastructureDamage: 60,
                economicLoss: 30,
                militaryDegradation: 70,
                publicPanic: 90,
                duration: 8
            )

        case .financialCollapse:
            return CyberDamage(
                infrastructureDamage: 30,
                economicLoss: 80,
                militaryDegradation: 5,
                publicPanic: 70,
                duration: 10
            )

        case .infrastructureDisruption:
            return CyberDamage(
                infrastructureDamage: 50,
                economicLoss: 40,
                militaryDegradation: 15,
                publicPanic: 60,
                duration: 6
            )

        case .falseFlagOperation:
            return CyberDamage(
                infrastructureDamage: 0,
                economicLoss: 0,
                militaryDegradation: 0,
                publicPanic: 30,
                duration: 4
            )
        }
    }

    private func shouldBeAttributed(_ level: AttributionLevel, target: Country) -> Bool {
        let baseChance: Double
        switch level {
        case .anonymous:
            baseChance = 0.1
        case .deniable:
            baseChance = 0.3
        case .traceable:
            baseChance = 0.7
        case .overt:
            baseChance = 1.0
        }

        // Target's counter-intel affects attribution
        let counterIntelBonus = (target.cyberDefenseCapability / 100.0) * 0.3
        let finalChance = baseChance + counterIntelBonus

        return Double.random(in: 0...1) < finalChance
    }

    private func calculateRetaliationProbability(
        _ discovered: Bool,
        _ damage: CyberDamage,
        _ target: Country
    ) -> Double {
        guard discovered else { return 0.0 }

        var probability = 0.3

        // Damage severity
        probability += Double(damage.totalImpact) / 200.0

        // Target personality
        if let personality = target.personality {
            probability += (personality.aggressionMultiplier - 1.0)
        }

        return min(probability, 0.95)
    }
}

// MARK: - Models

struct CyberOperation: Identifiable {
    let id: UUID
    let attacker: String
    let target: String
    let type: CyberAttackType
    let result: CyberAttackResult
    let timestamp: Date
}

struct CyberAttackResult {
    let attacker: Country
    let target: Country
    let attackType: CyberAttackType
    let success: Bool
    let damage: CyberDamage
    let discovered: Bool
    let retaliationProbability: Double
    let timestamp: Date
}

enum CyberAttackType: String, CaseIterable {
    case ddos = "DDoS Attack"
    case powerGrid = "Power Grid Disruption"
    case militaryComms = "Military Communications"
    case nuclearSystems = "Nuclear Command & Control"
    case financialCollapse = "Financial System Attack"
    case infrastructureDisruption = "Infrastructure Sabotage"
    case falseFlagOperation = "False Flag Cyber Attack"

    var description: String {
        switch self {
        case .ddos: return "Overwhelm networks, temporary disruption"
        case .powerGrid: return "Disable power infrastructure, massive impact"
        case .militaryComms: return "Disrupt military command systems"
        case .nuclearSystems: return "HIGH RISK: Target nuclear control systems"
        case .financialCollapse: return "Crash banking and financial systems"
        case .infrastructureDisruption: return "Sabotage critical infrastructure"
        case .falseFlagOperation: return "Attack from spoofed source, blame others"
        }
    }

    var risk: String {
        switch self {
        case .ddos: return "Low"
        case .powerGrid, .infrastructureDisruption: return "Medium"
        case .militaryComms, .financialCollapse: return "High"
        case .nuclearSystems, .falseFlagOperation: return "Extreme"
        }
    }
}

struct CyberDamage {
    let infrastructureDamage: Int // 0-100
    let economicLoss: Int // 0-100
    let militaryDegradation: Int // 0-100
    let publicPanic: Int // 0-100
    let duration: Int // turns

    var totalImpact: Int {
        (infrastructureDamage + economicLoss + militaryDegradation + publicPanic) / 4
    }

    static let none = CyberDamage(
        infrastructureDamage: 0,
        economicLoss: 0,
        militaryDegradation: 0,
        publicPanic: 0,
        duration: 0
    )
}

enum AttributionLevel: String {
    case anonymous = "Anonymous (VPN/Tor)"
    case deniable = "Plausible Deniability"
    case traceable = "Traceable but Deniable"
    case overt = "Overt (Accept Responsibility)"
}

// MARK: - Cyber Warfare View

struct CyberWarfareView: View {
    @StateObject private var cyber = CyberWarfareTheater.shared
    @State private var selectedAttack: CyberAttackType = .ddos
    @State private var selectedAttribution: AttributionLevel = .deniable
    @State private var selectedTarget: Country?

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            HStack(spacing: 0) {
                // Attack selector
                attackSelector
                    .frame(width: 300)

                Divider()

                // Operations log
                operationsLog
            }
        }
        .background(Color.black.opacity(0.9))
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text("💻 Cyber Warfare Theater")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text("\(cyber.activeOperations.count) operations conducted")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
        .padding()
        .background(Color.purple.opacity(0.2))
    }

    private var attackSelector: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Select Attack Type:")
                    .font(.headline)
                    .foregroundColor(.white)

                ForEach(CyberAttackType.allCases, id: \.self) { type in
                    AttackTypeCard(
                        type: type,
                        isSelected: selectedAttack == type,
                        onSelect: { selectedAttack = type }
                    )
                }

                Divider()

                Text("Attribution:")
                    .font(.headline)
                    .foregroundColor(.white)

                Picker("Attribution", selection: $selectedAttribution) {
                    ForEach([AttributionLevel.anonymous, .deniable, .traceable, .overt], id: \.self) { level in
                        Text(level.rawValue).tag(level)
                    }
                }
                .pickerStyle(.segmented)

                Button("Execute Attack") {
                    executeAttack()
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(selectedTarget == nil || cyber.isExecuting)
            }
            .padding()
        }
    }

    private var operationsLog: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(cyber.activeOperations.reversed()) { operation in
                    CyberOperationCard(operation: operation)
                }
            }
            .padding()
        }
    }

    private func executeAttack() {
        guard let target = selectedTarget else { return }

        Task {
            // Would execute actual attack
            print("Cyber attack: \(selectedAttack.rawValue) on \(target.name)")
        }
    }
}

struct AttackTypeCard: View {
    let type: CyberAttackType
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(type.rawValue)
                        .font(.headline)
                        .foregroundColor(.white)

                    Spacer()

                    Text(type.risk)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(riskColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(riskColor.opacity(0.2))
                        .cornerRadius(6)
                }

                Text(type.description)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding()
            .background(isSelected ? Color.purple.opacity(0.3) : Color.black.opacity(0.3))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.purple : Color.gray.opacity(0.3), lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private var riskColor: Color {
        switch type.risk {
        case "Low": return .green
        case "Medium": return .yellow
        case "High": return .orange
        case "Extreme": return .red
        default: return .gray
        }
    }
}

struct CyberOperationCard: View {
    let operation: CyberOperation

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: operation.result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(operation.result.success ? .green : .red)

                Text(operation.type.rawValue)
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()

                if operation.result.discovered {
                    Text("🔍 ATTRIBUTED")
                        .font(.caption2)
                        .foregroundColor(.red)
                }
            }

            Text("\(operation.attacker) → \(operation.target)")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))

            if operation.result.success {
                HStack(spacing: 16) {
                    damageIndicator("Infrastructure", operation.result.damage.infrastructureDamage)
                    damageIndicator("Economic", operation.result.damage.economicLoss)
                    damageIndicator("Military", operation.result.damage.militaryDegradation)
                }
            }
        }
        .padding()
        .background(Color.black.opacity(0.3))
        .cornerRadius(8)
    }

    private func damageIndicator(_ label: String, _ value: Int) -> some View {
        VStack(spacing: 2) {
            Text("\(value)%")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(damageColor(value))

            Text(label)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.5))
        }
    }

    private func damageColor(_ value: Int) -> Color {
        if value > 70 { return .red }
        if value > 40 { return .orange }
        if value > 10 { return .yellow }
        return .green
    }
}

// MARK: - Country Extensions

extension Country {
    var cyberOffenseCapability: Double {
        return Double(militaryStrength) * 0.8 + (hasNuclearWeapons ? 20 : 0)
    }

    var cyberDefenseCapability: Double {
        return Double(militaryStrength) * 0.6 + Double(economicStrength) * 0.4
    }
}
