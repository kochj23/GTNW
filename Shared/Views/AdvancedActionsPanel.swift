//
//  AdvancedActionsPanel.swift
//  Global Thermal Nuclear War
//
//  Folds every implemented verb that used to live only in the orphaned
//  CommandView (SDI, cyber, weapons programs, economic diplomacy, the covert
//  quartet) plus the new reversible verbs (sue-for-peace, leave alliance, abort
//  launch) into ONE reachable action hub, grouped by category. Gates are
//  proactive: buttons stay visible but `.disabled` with an inline reason chip.
//
//  Created by Jordan Koch on 2026.
//

import SwiftUI

struct AdvancedActionsPanel: View {
    @EnvironmentObject var gameEngine: GameEngine
    @Environment(\.dismiss) var dismiss
    let selectedTarget: String?

    private var gameState: GameState? { gameEngine.gameState }
    private var player: Country? { gameState?.getPlayerCountry() }
    private var target: Country? { selectedTarget.flatMap { gameState?.getCountry(id: $0) } }

    var body: some View {
        VStack(spacing: 0) {
            header
            if let gameState = gameState, let player = player {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        targetLine
                        diplomacySection(gameState: gameState, player: player)
                        covertSection(player: player)
                        strategicSection(gameState: gameState, player: player)
                        reversibleSection(player: player)
                    }
                    .padding()
                }
            } else {
                Spacer(); Text("No active game.").foregroundColor(.secondary); Spacer()
            }
        }
        .frame(minWidth: 560, minHeight: 620)
    }

    private var header: some View {
        HStack {
            Text("🎯 ACTION HUB")
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(GTNWColors.terminalGreen)
            Spacer()
            Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
        }
        .padding()
        .background(Color.black.opacity(0.3))
    }

    private var targetLine: some View {
        HStack {
            Image(systemName: "scope").foregroundColor(GTNWColors.terminalRed)
            if let target = target {
                Text("Target: \(target.flag) \(target.name)")
            } else {
                Text("Target: none selected")
                    .foregroundColor(GTNWColors.terminalAmber)
            }
            Spacer()
            if let p = player {
                Text("Treasury: \(treasuryLabel(p.treasury))")
                    .foregroundColor(GTNWColors.neonCyan)
            }
        }
        .font(.system(size: 12, weight: .medium, design: .monospaced))
    }

    // MARK: - Sections

    private func diplomacySection(gameState: GameState, player: Country) -> some View {
        section("DIPLOMACY & ECONOMY", color: GTNWColors.neonCyan) {
            GatedActionButton(
                title: "Economic Diplomacy (\(gameState.eraDiplomacyAmountLabel))",
                systemImage: "dollarsign.circle.fill",
                color: GTNWColors.neonCyan,
                reason: target == nil ? "Select a target" : nil
            ) {
                if let t = selectedTarget {
                    gameEngine.economicDiplomacy(from: player.id, to: t, amount: gameState.eraDiplomacyAmount)
                }
            }
        }
    }

    private func covertSection(player: Country) -> some View {
        section("COVERT OPERATIONS", color: GTNWColors.neonPurple) {
            let reason = target == nil ? "Select a target" : nil
            GatedActionButton(title: "Sabotage Infrastructure", systemImage: "wrench.and.screwdriver.fill",
                              color: GTNWColors.neonPurple, reason: reason) {
                if let t = selectedTarget { gameEngine.covertSabotage(from: player.id, to: t) }
            }
            GatedActionButton(title: "Cyber Warfare (quick)", systemImage: "network",
                              color: GTNWColors.neonPurple, reason: reason) {
                if let t = selectedTarget { gameEngine.cyberWarfare(from: player.id, to: t) }
            }
            GatedActionButton(title: "Propaganda Campaign", systemImage: "megaphone.fill",
                              color: GTNWColors.neonPurple, reason: reason) {
                if let t = selectedTarget { gameEngine.propaganda(from: player.id, to: t) }
            }
            GatedActionButton(title: "Special Forces Strike", systemImage: "figure.run",
                              color: GTNWColors.neonPurple, reason: reason) {
                if let t = selectedTarget { gameEngine.specialForces(from: player.id, to: t) }
            }
        }
    }

    private func strategicSection(gameState: GameState, player: Country) -> some View {
        section("STRATEGIC PROGRAMS", color: GTNWColors.terminalAmber) {
            // SDI
            let sdiReason: String? = {
                if !gameState.sdiAvailable { return "Unlocks 1983 (SDI)" }
                if player.treasury < 100_000_000_000 { return "Need $100B (have \(treasuryLabel(player.treasury)))" }
                return nil
            }()
            GatedActionButton(title: "Deploy SDI ($100B)", systemImage: "shield.lefthalf.filled",
                              color: GTNWColors.terminalAmber, reason: sdiReason) {
                gameEngine.deploySDI(countryID: player.id, investmentAmount: 100_000_000_000)
            }

            // Cyber operation (advanced) — menu of attack types
            let cyberReason: String? = gameState.cyberWarfareAvailable ? (target == nil ? "Select a target" : nil) : "Unlocks 1990 (Cyber)"
            GatedMenuButton(title: "Launch Cyber Operation", systemImage: "bolt.horizontal.circle",
                            color: GTNWColors.terminalRed, reason: cyberReason) {
                ForEach(CyberAttackType.allCases, id: \.self) { type in
                    Button(type.rawValue) {
                        if let t = selectedTarget {
                            gameEngine.launchCyberAttack(from: player.id, to: t, attackType: type, useProxy: nil)
                        }
                    }
                }
            }

            // Weapons programs — menu of SALT-prohibited weapons
            let weaponReason: String? = gameState.currentYear >= 1945 ? nil : "Unlocks 1945 (Nuclear age)"
            GatedMenuButton(title: "Start Weapons Program", systemImage: "hammer.fill",
                            color: GTNWColors.terminalAmber, reason: weaponReason) {
                ForEach(SALTProhibitedWeapon.allCases, id: \.self) { weapon in
                    Button("\(weapon.rawValue) — \(treasuryLabel(weapon.developmentCost))") {
                        gameEngine.startWeaponProgram(countryID: player.id, weapon: weapon)
                    }
                }
            }
        }
    }

    private func reversibleSection(player: Country) -> some View {
        section("DE-ESCALATE / REVERSE", color: GTNWColors.terminalGreen) {
            let atWar = target.map { player.atWarWith.contains($0.id) } ?? false
            let allied = target.map { player.alliances.contains($0.id) } ?? false

            GatedActionButton(title: "Sue for Peace / Ceasefire", systemImage: "dove.fill",
                              color: GTNWColors.terminalGreen,
                              reason: target == nil ? "Select a target" : (atWar ? nil : "Not at war with target")) {
                if let t = selectedTarget { _ = gameEngine.sueForPeace(from: player.id, to: t) }
            }

            GatedActionButton(title: "Leave / Defect Alliance", systemImage: "person.fill.xmark",
                              color: GTNWColors.terminalAmber,
                              reason: target == nil ? "Select a target" : (allied ? nil : "Not allied with target")) {
                if let t = selectedTarget { _ = gameEngine.leaveAlliance(country: player.id, from: t) }
            }

            GatedActionButton(title: "Abort Armed Launch", systemImage: "xmark.octagon.fill",
                              color: GTNWColors.terminalRed,
                              reason: gameEngine.pendingLaunch == nil ? "No launch armed" : nil) {
                _ = gameEngine.abortLaunch()
            }
        }
    }

    // MARK: - Helpers

    private func section<Content: View>(_ title: String, color: Color, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(color)
            content()
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.03))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.3), lineWidth: 1)))
    }

    private func treasuryLabel(_ amount: Int) -> String {
        if amount >= 1_000_000_000_000 { return String(format: "$%.1fT", Double(amount) / 1_000_000_000_000) }
        if amount >= 1_000_000_000 { return String(format: "$%.0fB", Double(amount) / 1_000_000_000) }
        if amount >= 1_000_000 { return String(format: "$%.0fM", Double(amount) / 1_000_000) }
        return "$\(amount)"
    }
}

// MARK: - Reusable gated controls

/// A button that stays visible but disables with an inline reason chip when a
/// precondition isn't met (proactive + legible gating).
struct GatedActionButton: View {
    let title: String
    let systemImage: String
    let color: Color
    let reason: String?      // nil = enabled
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage).frame(width: 22)
                Text(title).font(.system(size: 13, weight: .semibold, design: .monospaced))
                Spacer()
                if let reason = reason {
                    Text(reason)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.black)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(GTNWColors.terminalAmber))
                }
            }
            .foregroundColor(reason == nil ? color : color.opacity(0.5))
            .padding(.horizontal, 12).padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.10))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.4), lineWidth: 1)))
        }
        .buttonStyle(.plain)
        .disabled(reason != nil)
    }
}

/// Same gating, but the label opens a Menu of choices when enabled.
struct GatedMenuButton<Content: View>: View {
    let title: String
    let systemImage: String
    let color: Color
    let reason: String?
    @ViewBuilder let menu: () -> Content

    var body: some View {
        Menu {
            menu()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: systemImage).frame(width: 22)
                Text(title).font(.system(size: 13, weight: .semibold, design: .monospaced))
                Spacer()
                if let reason = reason {
                    Text(reason)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.black)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(GTNWColors.terminalAmber))
                } else {
                    Image(systemName: "chevron.up.chevron.down").font(.system(size: 9))
                }
            }
            .foregroundColor(reason == nil ? color : color.opacity(0.5))
            .padding(.horizontal, 12).padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.10))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.4), lineWidth: 1)))
        }
        .menuStyle(.borderlessButton)
        .disabled(reason != nil)
    }
}
