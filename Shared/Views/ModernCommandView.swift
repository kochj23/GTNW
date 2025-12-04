//
//  ModernCommandView.swift  
//  Global Thermal Nuclear War
//
//  Modern glassmorphic command interface
//  Created by Jordan Koch & Claude Code on 2025-12-03.
//

import SwiftUI

struct ModernCommandView: View {
    @EnvironmentObject var gameEngine: GameEngine
    @State private var selectedTarget: String?
    @State private var showingCountryPicker = false
    @State private var showingShadowMenu = false
    @State private var warheadCount: Int = 1

    var body: some View {
        if let gameState = gameEngine.gameState {
            ZStack {
                // Animated space background
                GTNWColors.spaceBackground
                    .overlay(ScanlineOverlay().opacity(0.3))

                ScrollView {
                    VStack(spacing: 24) {
                        // DEFCON Status
                        DefconIndicator(level: gameState.defconLevel)
                            .padding(.horizontal)

                        // Player Status
                        if let player = gameState.getPlayerCountry() {
                            playerStatusCard(player: player, gameState: gameState)
                        }

                        // Target Selection
                        targetSelectionCard(gameState: gameState)

                        // Command Actions
                        SectionHeader("⚡ AVAILABLE ACTIONS", icon: "bolt.fill", color: GTNWColors.terminalAmber)
                        actionsGrid(gameState: gameState)

                        // Quick Stats
                        SectionHeader("📊 SITUATION REPORT", icon: "chart.bar.fill", color: GTNWColors.neonCyan)
                        quickStatsGrid(gameState: gameState)
                    }
                    .padding()
                }
            }
            .sheet(isPresented: $showingCountryPicker) {
                ModernCountryPicker(gameState: gameState, selectedCountry: $selectedTarget)
            }
            .sheet(isPresented: $showingShadowMenu) {
                if let targetID = selectedTarget,
                   let target = gameState.getCountry(id: targetID),
                   let player = gameState.getPlayerCountry() {
                    ShadowPresidentMenu(
                        player: player,
                        target: target,
                        gameState: gameState,
                        onExecute: { action in
                            gameEngine.executeShadowPresidentAction(action, from: player.id, to: target.id)
                        }
                    )
                }
            }
        }
    }

    private func playerStatusCard(player: Country, gameState: GameState) -> some View {
        HStack(spacing: 20) {
            Text(player.flag)
                .font(.system(size: 72))

            VStack(alignment: .leading, spacing: 8) {
                Text(player.name)
                    .font(GTNWFonts.heading())
                    .foregroundColor(GTNWColors.terminalAmber)

                HStack(spacing: 16) {
                    statPill("☢️ \(player.nuclearWarheads)", color: GTNWColors.terminalRed)
                    statPill("Turn \(gameState.turn)", color: GTNWColors.neonCyan)
                    statPill("Wars: \(gameState.activeWars.count)", color: gameState.activeWars.count > 0 ? GTNWColors.terminalRed : GTNWColors.terminalGreen)
                }
            }

            Spacer()
        }
        .padding(24)
        .modernCard(glowColor: GTNWColors.terminalAmber)
        .padding(.horizontal)
    }

    private func targetSelectionCard(gameState: GameState) -> some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "scope")
                    .font(.system(size: 24))
                    .foregroundColor(GTNWColors.terminalRed)

                Text("TARGET SELECTION")
                    .font(GTNWFonts.subheading())
                    .foregroundColor(GTNWColors.terminalAmber)

                Spacer()
            }

            Button(action: { showingCountryPicker = true }) {
                HStack {
                    if let targetID = selectedTarget,
                       let target = gameState.getCountry(id: targetID) {
                        Text(target.flag)
                            .font(.system(size: 32))
                        VStack(alignment: .leading) {
                            Text(target.name)
                                .font(GTNWFonts.terminal(size: 18, weight: .bold))
                            Text("☢️ \(target.nuclearWarheads) warheads • Pop: \(target.population.formatted(.number.notation(.compactName)))")
                                .font(GTNWFonts.caption())
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                    } else {
                        Image(systemName: "target")
                            .font(.system(size: 24))
                        Text("SELECT TARGET NATION")
                            .font(GTNWFonts.terminal(size: 18, weight: .bold))
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                }
                .foregroundColor(GTNWColors.terminalGreen)
                .padding()
                .modernCard(glowColor: GTNWColors.terminalGreen)
            }
            .hoverScale()
        }
        .padding(20)
        .glassPanel(borderColor: GTNWColors.terminalRed.opacity(0.3))
        .padding(.horizontal)
    }

    private func actionsGrid(gameState: GameState) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            ModernButton(
                title: "NUCLEAR\nSTRIKE",
                icon: "flame.fill",
                color: GTNWColors.terminalRed,
                enabled: selectedTarget != nil && (gameState.getPlayerCountry()?.nuclearWarheads ?? 0) > 0
            ) {
                if let target = selectedTarget, let player = gameState.getPlayerCountry() {
                    gameEngine.launchNuclearStrike(from: player.id, to: target, warheads: min(warheadCount, player.nuclearWarheads))
                }
            }

            ModernButton(
                title: "DECLARE\nWAR",
                icon: "exclamationmark.triangle.fill",
                color: GTNWColors.terminalAmber,
                enabled: selectedTarget != nil
            ) {
                if let target = selectedTarget, let player = gameState.getPlayerCountry() {
                    gameEngine.declareWar(aggressor: player.id, defender: target)
                }
            }

            ModernButton(
                title: "FORM\nALLIANCE",
                icon: "hand.raised.fill",
                color: GTNWColors.terminalGreen,
                enabled: selectedTarget != nil
            ) {
                if let target = selectedTarget, let player = gameState.getPlayerCountry() {
                    gameEngine.formAlliance(country1: player.id, country2: target)
                }
            }

            ModernButton(
                title: "ECONOMIC\nDIPLOMACY",
                icon: "dollarsign.circle.fill",
                color: GTNWColors.neonCyan,
                enabled: selectedTarget != nil
            ) {
                if let target = selectedTarget, let player = gameState.getPlayerCountry() {
                    gameEngine.economicDiplomacy(from: player.id, to: target, amount: 5_000_000_000)
                }
            }

            ModernButton(
                title: "SHADOW PRESIDENT\nACTIONS (132)",
                icon: "list.bullet.rectangle.fill",
                color: GTNWColors.neonPurple,
                enabled: selectedTarget != nil
            ) {
                showingShadowMenu = true
            }

            ModernButton(
                title: "END\nTURN",
                icon: "arrow.right.circle.fill",
                color: GTNWColors.terminalGreen,
                enabled: true
            ) {
                gameEngine.endTurn()
            }
        }
        .padding(.horizontal)
    }

    private func quickStatsGrid(gameState: GameState) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            StatCard(
                title: "Nuclear Powers",
                value: "\(gameState.countries.filter { $0.nuclearWarheads > 0 && !$0.isDestroyed }.count)",
                icon: "flame.fill",
                color: GTNWColors.terminalRed
            )

            StatCard(
                title: "Active Wars",
                value: "\(gameState.activeWars.count)",
                icon: "exclamationmark.triangle.fill",
                color: .orange
            )

            StatCard(
                title: "Treaties",
                value: "\(gameState.treaties.count)",
                icon: "doc.text.fill",
                color: GTNWColors.terminalGreen
            )

            StatCard(
                title: "Global Radiation",
                value: "\(gameState.globalRadiation)",
                icon: "radiation",
                color: gameState.globalRadiation > 100 ? GTNWColors.terminalRed : GTNWColors.terminalGreen
            )
        }
        .padding(.horizontal)
    }

    private func statPill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(GTNWFonts.caption())
            .foregroundColor(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(color.opacity(0.2))
                    .overlay(Capsule().stroke(color.opacity(0.5), lineWidth: 1))
            )
    }
}

#Preview {
    ModernCommandView()
        .environmentObject(GameEngine())
}
