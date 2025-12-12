//
//  MetricsPanel.swift
//  Global Thermal Nuclear War
//
//  Simple text-based metrics display (no complex dials/gauges)
//  Created by Jordan Koch on 2025-12-11.
//

import SwiftUI

// MARK: - Main Metrics Panel

struct MetricsPanel: View {
    let gameState: GameState

    var body: some View {
        VStack(spacing: 20) {
            SectionHeader("📊 METRICS DASHBOARD", icon: "chart.bar.fill", color: GTNWColors.neonCyan)

            ScrollView {
                VStack(spacing: 24) {
                    // World Status Metrics
                    worldStatusSection

                    // Player Nation Metrics
                    if let player = gameState.getPlayerCountry() {
                        playerNationSection(player: player)
                    }

                    // Threat Assessment
                    threatAssessmentSection

                    // Military Readiness
                    militaryReadinessSection

                    // Diplomatic Overview
                    diplomaticOverviewSection
                }
                .padding()
            }
        }
    }

    // MARK: - World Status Section

    private var worldStatusSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("GLOBAL STATUS")
                .font(GTNWFonts.subheading())
                .foregroundColor(GTNWColors.terminalAmber)

            VStack(spacing: 12) {
                MetricRow(
                    label: "Turn Number",
                    value: "\(gameState.turn)",
                    icon: "clock.fill",
                    color: GTNWColors.neonCyan
                )

                MetricRow(
                    label: "DEFCON Level",
                    value: "DEFCON \(gameState.defconLevel.rawValue)",
                    icon: "exclamationmark.shield.fill",
                    color: gameState.defconLevel.color,
                    detail: gameState.defconLevel.description
                )

                MetricRow(
                    label: "Active Nations",
                    value: "\(gameState.countries.filter { !$0.isDestroyed }.count)/\(gameState.countries.count)",
                    icon: "flag.fill",
                    color: GTNWColors.terminalGreen
                )

                MetricRow(
                    label: "Nuclear Powers",
                    value: "\(gameState.countries.filter { $0.nuclearWarheads > 0 && !$0.isDestroyed }.count)",
                    icon: "flame.fill",
                    color: GTNWColors.terminalRed
                )

                MetricRow(
                    label: "Active Wars",
                    value: "\(gameState.activeWars.count)",
                    icon: "exclamationmark.triangle.fill",
                    color: gameState.activeWars.count > 0 ? GTNWColors.terminalRed : GTNWColors.terminalGreen,
                    detail: gameState.activeWars.count > 0 ? "Conflicts in progress" : "World at peace"
                )

                MetricRow(
                    label: "Treaties",
                    value: "\(gameState.treaties.count)",
                    icon: "doc.text.fill",
                    color: GTNWColors.terminalGreen
                )

                MetricRow(
                    label: "Total Casualties",
                    value: gameState.totalCasualties.formatted(.number.notation(.compactName)),
                    icon: "cross.case.fill",
                    color: gameState.totalCasualties > 0 ? GTNWColors.terminalRed : GTNWColors.terminalGreen
                )
            }
        }
        .padding(20)
        .glassPanel(borderColor: GTNWColors.neonCyan.opacity(0.3))
    }

    // MARK: - Player Nation Section

    private func playerNationSection(player: Country) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(player.flag)
                    .font(.system(size: 32))
                Text("YOUR NATION")
                    .font(GTNWFonts.subheading())
                    .foregroundColor(GTNWColors.terminalAmber)
            }

            VStack(spacing: 12) {
                MetricRow(
                    label: "Country",
                    value: player.name,
                    icon: "flag.fill",
                    color: GTNWColors.terminalAmber
                )

                MetricRow(
                    label: "Nuclear Warheads",
                    value: "\(player.nuclearWarheads)",
                    icon: "flame.fill",
                    color: GTNWColors.terminalRed,
                    detail: player.nuclearStatus.rawValue
                )

                MetricRow(
                    label: "Population",
                    value: player.population.formatted(.number.notation(.compactName)),
                    icon: "person.3.fill",
                    color: GTNWColors.neonCyan
                )

                MetricRow(
                    label: "GDP",
                    value: "$\(Int(player.gdp / 1_000_000_000))B",
                    icon: "dollarsign.circle.fill",
                    color: GTNWColors.neonPurple
                )

                MetricRow(
                    label: "Military Strength",
                    value: "\(player.militaryStrength)",
                    icon: "shield.fill",
                    color: GTNWColors.neonBlue
                )

                MetricRow(
                    label: "Radiation Level",
                    value: "\(player.radiationLevel)",
                    icon: "radiation",
                    color: player.radiationLevel > 0 ? GTNWColors.terminalRed : GTNWColors.terminalGreen
                )

                MetricRow(
                    label: "Wars",
                    value: "\(player.atWarWith.count)",
                    icon: "exclamationmark.triangle.fill",
                    color: player.atWarWith.count > 0 ? GTNWColors.terminalRed : GTNWColors.terminalGreen
                )

                MetricRow(
                    label: "Allies",
                    value: "\(player.alliances.count)",
                    icon: "hand.raised.fill",
                    color: GTNWColors.terminalGreen
                )
            }
        }
        .padding(20)
        .glassPanel(borderColor: GTNWColors.terminalAmber.opacity(0.5))
    }

    // MARK: - Threat Assessment Section

    private var threatAssessmentSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("THREAT ASSESSMENT")
                .font(GTNWFonts.subheading())
                .foregroundColor(GTNWColors.terminalAmber)

            VStack(spacing: 16) {
                // DEFCON Threat Level
                ThreatLevelIndicator(
                    level: threatLevelFromDEFCON(gameState.defconLevel),
                    label: "DEFCON Threat Level"
                )

                // Global Radiation
                ThreatLevelIndicator(
                    level: min(100, gameState.globalRadiation),
                    label: "Global Radiation"
                )

                // War Intensity
                let warIntensity = min(100, gameState.activeWars.count * 10)
                ThreatLevelIndicator(
                    level: warIntensity,
                    label: "War Intensity"
                )

                // Nuclear Risk
                let nuclearRisk = calculateNuclearRisk()
                ThreatLevelIndicator(
                    level: nuclearRisk,
                    label: "Nuclear Strike Risk"
                )
            }
        }
        .padding(20)
        .glassPanel(borderColor: GTNWColors.terminalRed.opacity(0.3))
    }

    // MARK: - Military Readiness Section

    private var militaryReadinessSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("MILITARY READINESS")
                .font(GTNWFonts.subheading())
                .foregroundColor(GTNWColors.terminalAmber)

            if let player = gameState.getPlayerCountry() {
                VStack(spacing: 12) {
                    // Nuclear Arsenal Strength
                    let nuclearStrength = min(100, player.nuclearWarheads * 2)
                    MetricProgressRow(
                        label: "Nuclear Arsenal",
                        value: "\(player.nuclearWarheads) warheads",
                        progress: Double(nuclearStrength) / 100.0,
                        color: GTNWColors.terminalRed
                    )

                    // Conventional Military
                    let militaryProgress = Double(player.militaryStrength) / 100.0
                    MetricProgressRow(
                        label: "Conventional Forces",
                        value: "\(player.militaryStrength)/100",
                        progress: militaryProgress,
                        color: GTNWColors.neonBlue
                    )

                    // Economic Capacity
                    let economicCapacity = min(100.0, player.gdp / 100_000_000_000.0)
                    MetricProgressRow(
                        label: "Economic Capacity",
                        value: "$\(Int(player.gdp / 1_000_000_000))B GDP",
                        progress: economicCapacity / 100.0,
                        color: GTNWColors.neonPurple
                    )
                }
            }
        }
        .padding(20)
        .glassPanel(borderColor: GTNWColors.neonBlue.opacity(0.3))
    }

    // MARK: - Diplomatic Overview Section

    private var diplomaticOverviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("DIPLOMATIC OVERVIEW")
                .font(GTNWFonts.subheading())
                .foregroundColor(GTNWColors.terminalAmber)

            if let player = gameState.getPlayerCountry() {
                VStack(spacing: 12) {
                    MetricRow(
                        label: "Allied Nations",
                        value: "\(player.alliances.count)",
                        icon: "hand.raised.fill",
                        color: GTNWColors.terminalGreen
                    )

                    MetricRow(
                        label: "Enemy Nations",
                        value: "\(player.atWarWith.count)",
                        icon: "exclamationmark.triangle.fill",
                        color: GTNWColors.terminalRed
                    )

                    let (friendly, neutral, hostile) = calculateDiplomaticBreakdown(player: player)
                    MetricRow(
                        label: "Friendly Relations",
                        value: "\(friendly)",
                        icon: "face.smiling.fill",
                        color: GTNWColors.terminalGreen
                    )

                    MetricRow(
                        label: "Neutral Relations",
                        value: "\(neutral)",
                        icon: "minus.circle.fill",
                        color: GTNWColors.terminalAmber
                    )

                    MetricRow(
                        label: "Hostile Relations",
                        value: "\(hostile)",
                        icon: "xmark.circle.fill",
                        color: GTNWColors.terminalRed
                    )

                    // Diplomatic standing score
                    let diplomaticScore = calculateDiplomaticScore(player: player)
                    ThreatLevelIndicator(
                        level: diplomaticScore,
                        label: "Diplomatic Standing"
                    )
                }
            }
        }
        .padding(20)
        .glassPanel(borderColor: GTNWColors.terminalGreen.opacity(0.3))
    }

    // MARK: - Helper Functions

    private func threatLevelFromDEFCON(_ defcon: DefconLevel) -> Int {
        switch defcon.rawValue {
        case 5: return 20  // Peacetime - low threat
        case 4: return 40  // Increased intelligence
        case 3: return 60  // Increased readiness
        case 2: return 85  // Armed forces ready
        case 1: return 100 // Nuclear war
        default: return 50
        }
    }

    private func calculateNuclearRisk() -> Int {
        var risk = 0

        // Base risk from DEFCON
        risk += threatLevelFromDEFCON(gameState.defconLevel) / 2

        // Risk from active wars
        risk += min(30, gameState.activeWars.count * 10)

        // Risk from nuclear strikes already happened
        risk += min(40, gameState.nuclearStrikes.count * 20)

        return min(100, risk)
    }

    private func calculateDiplomaticBreakdown(player: Country) -> (friendly: Int, neutral: Int, hostile: Int) {
        var friendly = 0
        var neutral = 0
        var hostile = 0

        for (_, relation) in player.diplomaticRelations {
            if relation >= 25 {
                friendly += 1
            } else if relation <= -25 {
                hostile += 1
            } else {
                neutral += 1
            }
        }

        return (friendly, neutral, hostile)
    }

    private func calculateDiplomaticScore(player: Country) -> Int {
        let (friendly, _, hostile) = calculateDiplomaticBreakdown(player: player)
        let totalRelations = player.diplomaticRelations.count

        guard totalRelations > 0 else { return 50 }

        // Score based on friendly vs hostile ratio
        let friendlyRatio = Double(friendly) / Double(totalRelations)
        let hostileRatio = Double(hostile) / Double(totalRelations)

        let score = Int((friendlyRatio * 100) - (hostileRatio * 50))
        return max(0, min(100, score + 50)) // Normalize to 0-100
    }
}

// MARK: - Metric Row Component

struct MetricRow: View {
    let label: String
    let value: String
    let icon: String
    let color: Color
    var detail: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(GTNWFonts.caption())
                    .foregroundColor(GTNWColors.terminalAmber.opacity(0.7))

                if let detail = detail {
                    Text(detail)
                        .font(GTNWFonts.terminal(size: 9, weight: .regular))
                        .foregroundColor(GTNWColors.terminalAmber.opacity(0.5))
                }
            }

            Spacer()

            Text(value)
                .font(GTNWFonts.terminal(size: 16, weight: .bold))
                .foregroundColor(color)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
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

// MARK: - Metric Progress Row Component

struct MetricProgressRow: View {
    let label: String
    let value: String
    let progress: Double  // 0.0 to 1.0
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(GTNWFonts.caption())
                    .foregroundColor(GTNWColors.terminalAmber.opacity(0.7))

                Spacer()

                Text(value)
                    .font(GTNWFonts.terminal(size: 12, weight: .bold))
                    .foregroundColor(color)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.black.opacity(0.5))

                    // Progress fill
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [color, color.opacity(0.6)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * CGFloat(progress))
                        .shadow(color: color.opacity(0.5), radius: 5)

                    // Percentage overlay
                    Text("\(Int(progress * 100))%")
                        .font(GTNWFonts.terminal(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 16)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
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

// MARK: - Compact Metrics Grid

struct CompactMetricsGrid: View {
    let gameState: GameState

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            QuickStatBadge(
                label: "Turn",
                value: "\(gameState.turn)",
                color: GTNWColors.neonCyan
            )

            QuickStatBadge(
                label: "DEFCON",
                value: "\(gameState.defconLevel.rawValue)",
                color: gameState.defconLevel.color
            )

            QuickStatBadge(
                label: "Wars",
                value: "\(gameState.activeWars.count)",
                color: gameState.activeWars.count > 0 ? GTNWColors.terminalRed : GTNWColors.terminalGreen
            )

            QuickStatBadge(
                label: "Treaties",
                value: "\(gameState.treaties.count)",
                color: GTNWColors.terminalGreen
            )

            QuickStatBadge(
                label: "Radiation",
                value: "\(gameState.globalRadiation)",
                color: gameState.globalRadiation > 100 ? GTNWColors.terminalRed : GTNWColors.terminalAmber
            )

            QuickStatBadge(
                label: "Nations",
                value: "\(gameState.countries.filter { !$0.isDestroyed }.count)",
                color: GTNWColors.neonCyan
            )
        }
    }
}

// MARK: - Quick Stat Badge

struct QuickStatBadge: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(GTNWFonts.terminal(size: 20, weight: .bold))
                .foregroundColor(color)

            Text(label)
                .font(GTNWFonts.terminal(size: 10, weight: .regular))
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
    ZStack {
        GTNWColors.spaceBackground
        MetricsPanel(gameState: GameState(playerCountryID: "USA"))
    }
}
