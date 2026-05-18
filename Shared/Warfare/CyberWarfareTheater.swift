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

        let successProbability = calculateSuccessProbability(attacker: attacker, target: target, attackType: attackType)
        let success = Double.random(in: 0...1) < successProbability
        let damage = success ? calculateDamage(attackType, target: target) : CyberDamage.none
        let discovered = shouldBeAttributed(attribution, target: target)

        let result = CyberAttackResult(
            attackerID: attacker.id,
            targetID: target.id,
            attackType: attackType,
            success: success,
            damage: damage,
            discovered: discovered,
            retaliationProbability: calculateRetaliationProbability(discovered, damage, target),
            timestamp: Date()
        )

        let operation = CyberOperation(
            attackerID: attacker.id,
            targetID: target.id,
            type: attackType,
            startTurn: 0
        )
        activeOperations.append(operation)

        return result
    }

    // MARK: - Attack Types

    private func calculateSuccessProbability(attacker: Country, target: Country, attackType: CyberAttackType) -> Double {
        var probability = 0.5
        probability += (Double(attacker.cyberOffenseLevel) / 100.0) * 0.3
        probability -= (Double(target.cyberDefenseLevel.rawValue) / 4.0) * 0.3

        switch attackType {
        case .reconnaissance, .dataTheft:
            probability += 0.2
        case .infrastructureDisruption, .communicationsBlackout:
            probability += 0.0
        case .nuclearSystemsPenetration, .bankingSystemCollapse:
            probability -= 0.3
        case .propagandaCampaign, .electionInterference:
            probability -= 0.2
        default:
            break
        }

        return max(0.1, min(probability, 0.95))
    }

    private func calculateDamage(_ attackType: CyberAttackType, target: Country) -> CyberDamage {
        switch attackType {
        case .reconnaissance, .dataTheft:
            return CyberDamage(infrastructureDamage: 5, economicLoss: 5, militaryDegradation: 0, publicPanic: 10, duration: 2)
        case .powerGridAttack:
            return CyberDamage(infrastructureDamage: 40, economicLoss: 25, militaryDegradation: 10, publicPanic: 50, duration: 5)
        case .communicationsBlackout, .militarySystemsHack:
            return CyberDamage(infrastructureDamage: 20, economicLoss: 10, militaryDegradation: 35, publicPanic: 20, duration: 3)
        case .nuclearSystemsPenetration:
            return CyberDamage(infrastructureDamage: 60, economicLoss: 30, militaryDegradation: 70, publicPanic: 90, duration: 8)
        case .bankingSystemCollapse, .financialSabotage:
            return CyberDamage(infrastructureDamage: 30, economicLoss: 80, militaryDegradation: 5, publicPanic: 70, duration: 10)
        case .infrastructureDisruption, .supplyChainsDisruption:
            return CyberDamage(infrastructureDamage: 50, economicLoss: 40, militaryDegradation: 15, publicPanic: 60, duration: 6)
        case .propagandaCampaign, .electionInterference:
            return CyberDamage(infrastructureDamage: 0, economicLoss: 0, militaryDegradation: 0, publicPanic: 30, duration: 4)
        }
    }

    private func shouldBeAttributed(_ level: AttributionLevel, target: Country) -> Bool {
        let baseChance: Double
        switch level {
        case .anonymous: baseChance = 0.1
        case .deniable: baseChance = 0.3
        case .traceable: baseChance = 0.7
        case .overt: baseChance = 1.0
        }

        let counterIntelBonus = (Double(target.cyberDefenseLevel.rawValue) / 4.0) * 0.3
        return Double.random(in: 0...1) < (baseChance + counterIntelBonus)
    }

    private func calculateRetaliationProbability(_ discovered: Bool, _ damage: CyberDamage, _ target: Country) -> Double {
        guard discovered else { return 0.0 }
        var probability = 0.3 + Double(damage.totalImpact) / 200.0
        probability += Double(target.aggressionLevel) / 100.0 * 0.2
        return min(probability, 0.95)
    }
}

// MARK: - Models

struct CyberAttackResult {
    let attackerID: String
    let targetID: String
    let attackType: CyberAttackType
    let success: Bool
    let damage: CyberDamage
    let discovered: Bool
    let retaliationProbability: Double
    let timestamp: Date
}

struct CyberTheaterResult {
    let operation: CyberOperation
    let success: Bool
    let discovered: Bool
    let retaliationProbability: Double
    let timestamp: Date
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
    @State private var selectedAttack: CyberAttackType = .reconnaissance
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

                    Text(riskLabel)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(riskColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(riskColor.opacity(0.2))
                        .cornerRadius(6)
                }

                Text(type.rawValue)
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

    private var riskLabel: String {
        switch type.detectability {
        case 0..<20: return "Low"
        case 20..<40: return "Medium"
        case 40..<60: return "High"
        default: return "Extreme"
        }
    }

    private var riskColor: Color {
        switch type.detectability {
        case 0..<20: return .green
        case 20..<40: return .yellow
        case 40..<60: return .orange
        default: return .red
        }
    }
}

struct CyberOperationCard: View {
    let operation: CyberOperation

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: (operation.success ?? false) ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor((operation.success ?? false) ? .green : .red)

                Text(operation.type.rawValue)
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()

                if operation.wasDetected {
                    Text("🔍 ATTRIBUTED")
                        .font(.caption2)
                        .foregroundColor(.red)
                }
            }

            Text("\(operation.attackerID) → \(operation.targetID)")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))

            if operation.success == true {
                Text("Operation succeeded")
                    .font(.caption)
                    .foregroundColor(.green)
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

// cyberOffenseLevel and cyberDefenseLevel are already on Country
