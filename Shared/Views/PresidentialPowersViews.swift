//
//  PresidentialPowersViews.swift
//  GTNW
//
//  UI menus for executive orders, pardons, and presidential addresses.
//  Created by Jordan Koch on 2026-03-05
//

import SwiftUI

// MARK: - Shared power menu style

private struct PowerMenuHeader: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
            }
            .foregroundColor(AppSettings.terminalGreen)
            Text(subtitle)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(AppSettings.terminalAmber)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(AppSettings.terminalGreen.opacity(0.1))
        .border(AppSettings.terminalGreen, width: 1)
    }
}

private struct PowerOptionRow: View {
    let icon: String
    let title: String
    let description: String
    let accentColor: Color
    let requiresTarget: Bool
    let hasTarget: Bool
    let onSelect: () -> Void

    private var isEnabled: Bool { !requiresTarget || hasTarget }

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(isEnabled ? accentColor : .gray)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title)
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(isEnabled ? .white : .gray)
                        if requiresTarget && !hasTarget {
                            Text("(select target first)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.orange)
                        }
                    }
                    Text(description)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(isEnabled ? AppSettings.terminalGreen.opacity(0.8) : .gray)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                if isEnabled {
                    Image(systemName: "chevron.right")
                        .foregroundColor(accentColor)
                }
            }
            .padding(12)
            .background(Color.black.opacity(0.4))
            .border(isEnabled ? accentColor.opacity(0.5) : Color.gray.opacity(0.2), width: 1)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

// MARK: - Executive Order Menu

struct ExecutiveOrderMenuView: View {
    let gameEngine: GameEngine
    let selectedTarget: String?
    let gameState: GameState
    @Environment(\.dismiss) var dismiss
    @State private var confirming: ExecutiveOrderType?

    var body: some View {
        VStack(spacing: 0) {
            PowerMenuHeader(
                icon: "scroll.fill",
                title: "ISSUE EXECUTIVE ORDER",
                subtitle: "Bypass Congress — act unilaterally by presidential authority"
            )

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(ExecutiveOrderType.allCases) { type in
                        PowerOptionRow(
                            icon: type.icon,
                            title: type.rawValue,
                            description: type.description,
                            accentColor: .purple,
                            requiresTarget: type.requiresTarget,
                            hasTarget: selectedTarget != nil
                        ) {
                            confirming = type
                        }
                    }
                }
                .padding()
            }
        }
        .background(AppSettings.terminalBackground)
        .alert(item: $confirming) { order in
            let targetName = selectedTarget.flatMap { gameState.getCountry(id: $0)?.name } ?? ""
            return Alert(
                title: Text("Sign: \(order.rawValue)?"),
                message: Text(order.requiresTarget && !targetName.isEmpty
                    ? "Target: \(targetName)\n\(order.description)"
                    : order.description),
                primaryButton: .destructive(Text("SIGN ORDER")) {
                    gameEngine.issueExecutiveOrder(type: order, targetCountryID: selectedTarget)
                    dismiss()
                },
                secondaryButton: .cancel()
            )
        }
    }
}

// MARK: - Pardon Menu

struct PardonMenuView: View {
    let gameEngine: GameEngine
    let selectedTarget: String?
    let gameState: GameState
    @Environment(\.dismiss) var dismiss
    @State private var confirming: PardonType?

    var body: some View {
        VStack(spacing: 0) {
            PowerMenuHeader(
                icon: "checkmark.seal.fill",
                title: "PRESIDENTIAL PARDON",
                subtitle: "Article II, Section 2 — 'Power to grant reprieves and pardons'"
            )

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(PardonType.allCases) { type in
                        let needsTarget = (type == .diplomaticGesture || type == .warCriminal)
                        PowerOptionRow(
                            icon: type.icon,
                            title: type.rawValue,
                            description: type.description,
                            accentColor: .teal,
                            requiresTarget: needsTarget,
                            hasTarget: selectedTarget != nil
                        ) {
                            confirming = type
                        }
                    }
                }
                .padding()
            }
        }
        .background(AppSettings.terminalBackground)
        .alert(item: $confirming) { pardonType in
            let targetName = selectedTarget.flatMap { gameState.getCountry(id: $0)?.name } ?? ""
            let needsTarget = (pardonType == .diplomaticGesture || pardonType == .warCriminal)
            return Alert(
                title: Text("Grant Pardon: \(pardonType.rawValue)?"),
                message: Text(needsTarget && !targetName.isEmpty
                    ? "Regarding \(targetName):\n\(pardonType.description)"
                    : pardonType.description),
                primaryButton: .default(Text("GRANT PARDON")) {
                    let targetID = (pardonType == .diplomaticGesture || pardonType == .warCriminal)
                        ? selectedTarget : nil
                    gameEngine.grantPardon(type: pardonType, targetCountryID: targetID)
                    dismiss()
                },
                secondaryButton: .cancel()
            )
        }
    }
}

// MARK: - Presidential Address Menu

struct PresidentialAddressMenuView: View {
    let gameEngine: GameEngine
    let selectedTarget: String?
    let gameState: GameState
    @Environment(\.dismiss) var dismiss
    @State private var confirming: AddressType?

    var body: some View {
        VStack(spacing: 0) {
            PowerMenuHeader(
                icon: "mic.fill",
                title: "PRESIDENTIAL ADDRESS",
                subtitle: "Use the Bully Pulpit — shape opinion, rally allies, warn adversaries"
            )

            if let player = gameState.getPlayerCountry() {
                HStack(spacing: 20) {
                    Label("Public Approval: \(player.publicApproval)%",
                          systemImage: "chart.bar.fill")
                    Label("Congressional Support: \(player.congressionalSupport)%",
                          systemImage: "person.3.fill")
                }
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(AppSettings.terminalAmber)
                .padding(.horizontal)
                .padding(.vertical, 8)
            }

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(AddressType.allCases) { type in
                        let needsTarget = (type == .foreignPolicy || type == .warningAddress)
                        PowerOptionRow(
                            icon: type.icon,
                            title: type.rawValue,
                            description: "\(type.description)\nCooldown: \(type.cooldownTurns) turn(s)",
                            accentColor: AppSettings.terminalAmber,
                            requiresTarget: needsTarget,
                            hasTarget: selectedTarget != nil
                        ) {
                            confirming = type
                        }
                    }
                }
                .padding()
            }
        }
        .background(AppSettings.terminalBackground)
        .alert(item: $confirming) { addressType in
            let targetName = selectedTarget.flatMap { gameState.getCountry(id: $0)?.name } ?? ""
            let needsTarget = (addressType == .foreignPolicy || addressType == .warningAddress)
            return Alert(
                title: Text("Deliver: \(addressType.rawValue)?"),
                message: Text(needsTarget && !targetName.isEmpty
                    ? "Directed at \(targetName)\n+\(addressType.approvalImpact) approval"
                    : "+\(addressType.approvalImpact) approval"),
                primaryButton: .default(Text("DELIVER ADDRESS")) {
                    let targetID = needsTarget ? selectedTarget : nil
                    gameEngine.deliverPresidentialAddress(type: addressType, targetCountryID: targetID)
                    dismiss()
                },
                secondaryButton: .cancel()
            )
        }
    }
}
