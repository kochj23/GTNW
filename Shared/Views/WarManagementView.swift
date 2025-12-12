//
//  WarManagementView.swift
//  Global Thermal Nuclear War
//
//  Detailed war management with granular controls
//  Created by Jordan Koch on 2025-12-11.
//

import SwiftUI

// MARK: - War Management Dashboard

struct WarManagementView: View {
    @EnvironmentObject var gameEngine: GameEngine
    @State private var selectedWar: EnhancedWar?
    @State private var showingDeploymentPanel = false

    var body: some View {
        ZStack {
            GTNWColors.spaceBackground
                .overlay(ScanlineOverlay().opacity(0.2))

            VStack(spacing: 0) {
                // Header
                SectionHeader("⚔️ WAR MANAGEMENT CENTER", icon: "exclamationmark.triangle.fill", color: GTNWColors.terminalRed)
                    .padding()

                if let gameState = gameEngine.gameState, !gameState.activeWars.isEmpty {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Active Wars List
                            ForEach(gameEngine.enhancedWars) { war in
                                WarCard(war: war, gameState: gameState) {
                                    selectedWar = war
                                }
                            }
                        }
                        .padding()
                    }
                } else {
                    Spacer()
                    Text("NO ACTIVE WARS")
                        .font(GTNWFonts.heading())
                        .foregroundColor(GTNWColors.terminalGreen)
                    Text("World at peace")
                        .font(GTNWFonts.body())
                        .foregroundColor(GTNWColors.terminalAmber.opacity(0.7))
                    Spacer()
                }
            }
        }
        .sheet(item: $selectedWar) { war in
            DetailedWarView(war: war, gameState: gameEngine.gameState!)
                .environmentObject(gameEngine)
        }
    }
}

// MARK: - War Card

struct WarCard: View {
    let war: EnhancedWar
    let gameState: GameState
    let onTap: () -> Void

    private func getCountry(_ id: String) -> Country? {
        gameState.getCountry(id: id)
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 16) {
                // War header
                HStack {
                    if let aggressor = getCountry(war.aggressor),
                       let defender = getCountry(war.defender) {
                        VStack(alignment: .leading) {
                            Text(aggressor.flag + " " + aggressor.name)
                                .font(GTNWFonts.terminal(size: 18, weight: .bold))
                                .foregroundColor(GTNWColors.terminalRed)

                            Text("vs")
                                .font(GTNWFonts.caption())
                                .foregroundColor(GTNWColors.terminalAmber)

                            Text(defender.flag + " " + defender.name)
                                .font(GTNWFonts.terminal(size: 18, weight: .bold))
                                .foregroundColor(GTNWColors.terminalRed)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing) {
                        Text(war.warPhase.rawValue)
                            .font(GTNWFonts.caption())
                            .foregroundColor(warPhaseColor(war.warPhase))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(warPhaseColor(war.warPhase).opacity(0.2))
                                    .overlay(Capsule().stroke(warPhaseColor(war.warPhase).opacity(0.5), lineWidth: 1))
                            )

                        Text("Turn \(war.startTurn) - \(war.currentTurn)")
                            .font(GTNWFonts.caption())
                            .foregroundColor(GTNWColors.terminalAmber.opacity(0.7))
                    }
                }

                // Quick stats
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    WarStatBadge(
                        icon: "cross.case.fill",
                        label: "Casualties",
                        value: "\(war.totalCasualties.total.formatted(.number.notation(.compactName)))",
                        color: GTNWColors.terminalRed
                    )

                    WarStatBadge(
                        icon: "person.fill.xmark",
                        label: "KIA",
                        value: "\(war.totalCasualties.dead.formatted(.number.notation(.compactName)))",
                        color: GTNWColors.terminalRed
                    )

                    WarStatBadge(
                        icon: "bandage.fill",
                        label: "Wounded",
                        value: "\(war.totalCasualties.wounded.formatted(.number.notation(.compactName)))",
                        color: GTNWColors.terminalAmber
                    )

                    WarStatBadge(
                        icon: "flame.fill",
                        label: "Equipment",
                        value: "\(war.totalEquipmentLosses.totalLosses)",
                        color: .orange
                    )
                }

                // Tap to view details
                HStack {
                    Spacer()
                    Text("TAP FOR DETAILED STATS")
                        .font(GTNWFonts.terminal(size: 10, weight: .bold))
                        .foregroundColor(GTNWColors.neonCyan)
                    Image(systemName: "chevron.right")
                        .foregroundColor(GTNWColors.neonCyan)
                    Spacer()
                }
            }
            .padding(20)
            .modernCard(glowColor: GTNWColors.terminalRed)
        }
        .buttonStyle(.plain)
        .hoverScale()
    }

    private func warPhaseColor(_ phase: WarPhase) -> Color {
        switch phase {
        case .initial: return GTNWColors.terminalAmber
        case .active: return .orange
        case .prolonged: return .orange
        case .escalated: return GTNWColors.terminalRed
        case .totalWar: return GTNWColors.terminalRed
        case .apocalyptic: return .black
        }
    }
}

// MARK: - Detailed War View

struct DetailedWarView: View {
    @EnvironmentObject var gameEngine: GameEngine
    @Environment(\.dismiss) var dismiss
    let war: EnhancedWar
    let gameState: GameState

    @State private var showingMilitaryDeployment = false
    @State private var showingNuclearStrikePanel = false

    var body: some View {
        ZStack {
            GTNWColors.commandCenterBackground

            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading) {
                        if let aggressor = gameState.getCountry(id: war.aggressor),
                           let defender = gameState.getCountry(id: war.defender) {
                            HStack {
                                Text(aggressor.flag)
                                    .font(.system(size: 48))
                                Text("vs")
                                    .font(GTNWFonts.subheading())
                                    .foregroundColor(GTNWColors.terminalAmber)
                                Text(defender.flag)
                                    .font(.system(size: 48))
                            }

                            Text(aggressor.name + " vs " + defender.name)
                                .font(GTNWFonts.heading())
                                .foregroundColor(GTNWColors.neonCyan)
                        }
                    }

                    Spacer()

                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(GTNWColors.terminalRed)
                    }
                }
                .padding()

                ScrollView {
                    VStack(spacing: 24) {
                        // Action buttons
                        actionButtons

                        // Overall statistics
                        overallStatisticsSection

                        // Side-by-side deployments
                        deploymentsSection

                        // Per-turn combat history
                        combatHistorySection

                        // Economic impact
                        economicImpactSection
                    }
                    .padding()
                }
            }
        }
        .frame(minWidth: 1200, minHeight: 800)
        .sheet(isPresented: $showingMilitaryDeployment) {
            MilitaryDeploymentPanel(war: war, gameState: gameState)
                .environmentObject(gameEngine)
        }
        .sheet(isPresented: $showingNuclearStrikePanel) {
            NuclearStrikePanelView(war: war, gameState: gameState)
                .environmentObject(gameEngine)
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 16) {
            ModernButton(
                title: "DEPLOY\nFORCES",
                icon: "person.3.fill",
                color: GTNWColors.neonBlue,
                enabled: true
            ) {
                showingMilitaryDeployment = true
            }

            ModernButton(
                title: "NUCLEAR\nSTRIKE",
                icon: "flame.fill",
                color: GTNWColors.terminalRed,
                enabled: (gameState.getPlayerCountry()?.nuclearWarheads ?? 0) > 0
            ) {
                showingNuclearStrikePanel = true
            }

            ModernButton(
                title: "PROPOSE\nCEASEFIRE",
                icon: "flag.fill",
                color: GTNWColors.terminalAmber,
                enabled: true
            ) {
                // TODO: Implement ceasefire
            }

            ModernButton(
                title: "SURRENDER",
                icon: "xmark.circle.fill",
                color: GTNWColors.terminalRed,
                enabled: true
            ) {
                // TODO: Implement surrender
            }
        }
        .padding(.horizontal)
    }

    private var overallStatisticsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("OVERALL WAR STATISTICS")
                .font(GTNWFonts.subheading())
                .foregroundColor(GTNWColors.terminalAmber)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                StatCard(
                    title: "Duration",
                    value: "\(war.durationInTurns) turns",
                    icon: "clock.fill",
                    color: GTNWColors.neonCyan
                )

                StatCard(
                    title: "Total Casualties",
                    value: war.totalCasualties.total.formatted(.number.notation(.compactName)),
                    icon: "cross.case.fill",
                    color: GTNWColors.terminalRed
                )

                StatCard(
                    title: "KIA",
                    value: war.totalCasualties.dead.formatted(.number.notation(.compactName)),
                    icon: "person.fill.xmark",
                    color: GTNWColors.terminalRed
                )

                StatCard(
                    title: "Wounded",
                    value: war.totalCasualties.wounded.formatted(.number.notation(.compactName)),
                    icon: "bandage.fill",
                    color: GTNWColors.terminalAmber
                )

                StatCard(
                    title: "Equipment Lost",
                    value: "\(war.totalEquipmentLosses.totalLosses)",
                    icon: "flame.fill",
                    color: .orange
                )

                StatCard(
                    title: "War Crimes",
                    value: "\(war.warCrimesReported)",
                    icon: "exclamationmark.triangle.fill",
                    color: war.warCrimesReported > 0 ? GTNWColors.terminalRed : GTNWColors.terminalGreen
                )

                StatCard(
                    title: "Intensity",
                    value: "\(war.intensity)/10",
                    icon: "bolt.fill",
                    color: .orange
                )

                StatCard(
                    title: "Phase",
                    value: war.warPhase.rawValue,
                    icon: "chart.line.uptrend.xyaxis.fill",
                    color: GTNWColors.neonCyan
                )
            }
        }
        .padding(20)
        .glassPanel(borderColor: GTNWColors.neonCyan.opacity(0.3))
    }

    private var deploymentsSection: some View {
        HStack(alignment: .top, spacing: 16) {
            // Aggressor deployment
            if let aggressor = gameState.getCountry(id: war.aggressor) {
                DeploymentCard(
                    country: aggressor,
                    stats: war.aggressorStats,
                    title: "AGGRESSOR FORCES"
                )
            }

            // Defender deployment
            if let defender = gameState.getCountry(id: war.defender) {
                DeploymentCard(
                    country: defender,
                    stats: war.defenderStats,
                    title: "DEFENDER FORCES"
                )
            }
        }
    }

    private var combatHistorySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("COMBAT HISTORY (LAST 10 TURNS)")
                .font(GTNWFonts.subheading())
                .foregroundColor(GTNWColors.terminalAmber)

            if war.combatHistory.isEmpty {
                Text("No combat statistics recorded yet")
                    .font(GTNWFonts.body())
                    .foregroundColor(GTNWColors.terminalAmber.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(war.combatHistory.suffix(10).reversed()) { stats in
                    CombatStatisticsRow(stats: stats, war: war)
                }
            }
        }
        .padding(20)
        .glassPanel(borderColor: GTNWColors.terminalRed.opacity(0.3))
    }

    private var economicImpactSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("ECONOMIC IMPACT")
                .font(GTNWFonts.subheading())
                .foregroundColor(GTNWColors.terminalAmber)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                StatCard(
                    title: "Aggressor Cost",
                    value: "$\(Int(war.economicCostAggressor))B",
                    icon: "dollarsign.circle.fill",
                    color: GTNWColors.neonPurple
                )

                StatCard(
                    title: "Defender Cost",
                    value: "$\(Int(war.economicCostDefender))B",
                    icon: "dollarsign.circle.fill",
                    color: GTNWColors.neonPurple
                )

                StatCard(
                    title: "Humanitarian Aid",
                    value: "$\(Int(war.humanitarianAid))B",
                    icon: "heart.fill",
                    color: GTNWColors.terminalGreen
                )

                StatCard(
                    title: "Sanctions",
                    value: "\(war.sanctionsImposed)",
                    icon: "hand.raised.slash.fill",
                    color: GTNWColors.terminalAmber
                )
            }
        }
        .padding(20)
        .glassPanel(borderColor: GTNWColors.neonPurple.opacity(0.3))
    }
}

// MARK: - Deployment Card

struct DeploymentCard: View {
    let country: Country
    let stats: WarSideStatistics
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(country.flag)
                    .font(.system(size: 32))
                Text(title)
                    .font(GTNWFonts.subheading())
                    .foregroundColor(GTNWColors.terminalAmber)
            }

            VStack(spacing: 12) {
                MetricRow(
                    label: "Infantry",
                    value: stats.deployment.infantry.formatted(),
                    icon: "person.3.fill",
                    color: GTNWColors.neonBlue
                )

                MetricRow(
                    label: "Tanks",
                    value: "\(stats.deployment.tanks)",
                    icon: "car.fill",
                    color: GTNWColors.neonBlue
                )

                MetricRow(
                    label: "Artillery",
                    value: "\(stats.deployment.artillery)",
                    icon: "scope",
                    color: GTNWColors.neonBlue
                )

                MetricRow(
                    label: "Aircraft",
                    value: "\(stats.deployment.aircraft)",
                    icon: "airplane",
                    color: GTNWColors.neonBlue
                )

                MetricRow(
                    label: "Ships",
                    value: "\(stats.deployment.ships)",
                    icon: "ferry.fill",
                    color: GTNWColors.neonBlue
                )

                MetricRow(
                    label: "Nuclear Warheads",
                    value: "\(stats.deployment.nuclearWarheads)",
                    icon: "flame.fill",
                    color: GTNWColors.terminalRed
                )

                Divider()
                    .background(GTNWColors.terminalAmber.opacity(0.3))

                MetricRow(
                    label: "Morale",
                    value: "\(stats.morale)%",
                    icon: "heart.fill",
                    color: stats.morale > 50 ? GTNWColors.terminalGreen : GTNWColors.terminalRed
                )

                MetricRow(
                    label: "Total Casualties",
                    value: stats.totalCasualties.total.formatted(.number.notation(.compactName)),
                    icon: "cross.case.fill",
                    color: GTNWColors.terminalRed
                )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .glassPanel(borderColor: GTNWColors.neonBlue.opacity(0.3))
    }
}

// MARK: - Combat Statistics Row

struct CombatStatisticsRow: View {
    let stats: CombatStatistics
    let war: EnhancedWar

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Turn header
            HStack {
                Text("TURN \(stats.turn)")
                    .font(GTNWFonts.terminal(size: 14, weight: .bold))
                    .foregroundColor(GTNWColors.terminalAmber)

                Spacer()

                Text("Intensity: \(stats.intensity)/10")
                    .font(GTNWFonts.caption())
                    .foregroundColor(.orange)

                if stats.nuclearStrikesThisTurn > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .foregroundColor(GTNWColors.terminalRed)
                        Text("\(stats.nuclearStrikesThisTurn) nuclear strikes")
                            .font(GTNWFonts.caption())
                            .foregroundColor(GTNWColors.terminalRed)
                    }
                }
            }

            // Casualties comparison
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Aggressor Losses")
                        .font(GTNWFonts.caption())
                        .foregroundColor(GTNWColors.terminalAmber.opacity(0.7))

                    Text("Dead: \(stats.aggressorCasualties.dead)")
                        .font(GTNWFonts.terminal(size: 11, weight: .regular))
                        .foregroundColor(GTNWColors.terminalRed)

                    Text("Wounded: \(stats.aggressorCasualties.wounded)")
                        .font(GTNWFonts.terminal(size: 11, weight: .regular))
                        .foregroundColor(GTNWColors.terminalAmber)

                    Text("Equipment: \(stats.aggressorEquipmentLosses.totalLosses)")
                        .font(GTNWFonts.terminal(size: 11, weight: .regular))
                        .foregroundColor(.orange)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Defender Losses")
                        .font(GTNWFonts.caption())
                        .foregroundColor(GTNWColors.terminalAmber.opacity(0.7))

                    Text("Dead: \(stats.defenderCasualties.dead)")
                        .font(GTNWFonts.terminal(size: 11, weight: .regular))
                        .foregroundColor(GTNWColors.terminalRed)

                    Text("Wounded: \(stats.defenderCasualties.wounded)")
                        .font(GTNWFonts.terminal(size: 11, weight: .regular))
                        .foregroundColor(GTNWColors.terminalAmber)

                    Text("Equipment: \(stats.defenderEquipmentLosses.totalLosses)")
                        .font(GTNWFonts.terminal(size: 11, weight: .regular))
                        .foregroundColor(.orange)
                }
            }

            // Territory changes
            if stats.territoryGained != 0 || stats.citiesCaptured != 0 {
                HStack {
                    if stats.territoryGained != 0 {
                        Text("Territory: \(stats.territoryGained > 0 ? "+" : "")\(stats.territoryGained) km²")
                            .font(GTNWFonts.caption())
                            .foregroundColor(GTNWColors.neonCyan)
                    }

                    if stats.citiesCaptured != 0 {
                        Text("Cities: \(stats.citiesCaptured)")
                            .font(GTNWFonts.caption())
                            .foregroundColor(GTNWColors.neonCyan)
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(GTNWColors.terminalAmber.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - War Stat Badge

struct WarStatBadge: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)

            Text(value)
                .font(GTNWFonts.terminal(size: 14, weight: .bold))
                .foregroundColor(color)

            Text(label)
                .font(GTNWFonts.terminal(size: 9, weight: .regular))
                .foregroundColor(GTNWColors.terminalAmber.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Preview

#Preview {
    WarManagementView()
        .environmentObject(GameEngine())
}
