//
//  WarRoomView.swift
//  GTNW
//
//  AI War Room interface for strategic analysis
//  Created by Jordan Koch on 2026-01-22
//

import SwiftUI

/// AI War Room strategic analysis view
struct WarRoomView: View {
    @ObservedObject var warRoom: AIWarRoom
    let gameState: GameState
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                    .font(.title)
                    .foregroundColor(GTNWColors.neonCyan)

                Text("AI WAR ROOM")
                    .font(GTNWFonts.title())
                    .foregroundColor(GTNWColors.terminalGreen)

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(GTNWColors.terminalRed)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color.black.opacity(0.9))

            Divider().background(GTNWColors.terminalGreen)

            if let analysis = warRoom.threatAnalysis {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Immediate Threats
                        if !analysis.immediateThreats.isEmpty {
                            ThreatSection(title: "🚨 IMMEDIATE THREATS", threats: analysis.immediateThreats)
                        }

                        // Opportunities
                        if !analysis.opportunities.isEmpty {
                            OpportunitySection(opportunities: analysis.opportunities)
                        }

                        // Recommendations
                        if !analysis.recommendations.isEmpty {
                            RecommendationSection(recommendations: analysis.recommendations)
                        }

                        // Victory Path
                        VictoryPathSection(analysis: analysis.victoryPathAnalysis)
                    }
                    .padding()
                }
            } else {
                VStack(spacing: 20) {
                    if warRoom.isAnalyzing {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Analyzing strategic situation...")
                            .font(GTNWFonts.body())
                            .foregroundColor(GTNWColors.terminalAmber)
                    } else {
                        Button(action: {
                            Task {
                                await warRoom.analyzeSituation(gameState: gameState)
                            }
                        }) {
                            HStack {
                                Image(systemName: "brain.head.profile")
                                Text("ANALYZE SITUATION")
                            }
                            .padding()
                            .background(GTNWColors.neonCyan.opacity(0.3))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
        .frame(width: 800, height: 600)
        .background(Color.black)
        .border(GTNWColors.neonCyan, width: 2)
    }
}

struct ThreatSection: View {
    let title: String
    let threats: [ThreatReport]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(GTNWFonts.sectionHeader())
                .foregroundColor(GTNWColors.terminalRed)

            ForEach(threats) { threat in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(threat.country)
                            .font(GTNWFonts.headline())
                            .foregroundColor(GTNWColors.terminalGreen)

                        Spacer()

                        ThreatLevelBadge(level: threat.threatLevel)
                    }

                    Text(threat.reasoning)
                        .font(GTNWFonts.body())
                        .foregroundColor(GTNWColors.terminalAmber.opacity(0.8))

                    HStack {
                        Image(systemName: "clock")
                        Text(threat.timeWindow)
                    }
                    .font(GTNWFonts.caption())
                    .foregroundColor(GTNWColors.neonPurple)

                    if !threat.recommendedResponse.isEmpty {
                        Text("→ \(threat.recommendedResponse)")
                            .font(GTNWFonts.caption())
                            .foregroundColor(GTNWColors.neonCyan)
                    }
                }
                .padding()
                .background(Color.black.opacity(0.5))
                .border(GTNWColors.terminalRed, width: 1)
            }
        }
    }
}

struct ThreatLevelBadge: View {
    let level: Int

    var body: some View {
        Text("\(level)")
            .font(.system(size: 14, weight: .bold, design: .monospaced))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(threatColor)
            .cornerRadius(4)
    }

    var threatColor: Color {
        if level >= 80 { return GTNWColors.terminalRed }
        if level >= 60 { return GTNWColors.terminalAmber }
        if level >= 40 { return GTNWColors.neonPurple }
        return GTNWColors.terminalGreen
    }
}

struct OpportunitySection: View {
    let opportunities: [Opportunity]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("💡 OPPORTUNITIES")
                .font(GTNWFonts.sectionHeader())
                .foregroundColor(GTNWColors.neonCyan)

            ForEach(opportunities) { opp in
                HStack(alignment: .top) {
                    Image(systemName: "star.fill")
                        .foregroundColor(GTNWColors.yellow)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(opp.country)
                            .font(GTNWFonts.headline())
                            .foregroundColor(GTNWColors.terminalGreen)
                        Text(opp.opportunity)
                            .font(GTNWFonts.body())
                            .foregroundColor(GTNWColors.terminalAmber.opacity(0.8))
                    }
                }
                .padding()
                .background(Color.black.opacity(0.5))
                .border(GTNWColors.neonCyan, width: 1)
            }
        }
    }
}

struct RecommendationSection: View {
    let recommendations: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("📋 STRATEGIC RECOMMENDATIONS")
                .font(GTNWFonts.sectionHeader())
                .foregroundColor(GTNWColors.terminalGreen)

            ForEach(Array(recommendations.enumerated()), id: \.offset) { index, rec in
                HStack(alignment: .top) {
                    Text("\(index + 1).")
                        .font(GTNWFonts.headline())
                        .foregroundColor(GTNWColors.neonCyan)
                    Text(rec)
                        .font(GTNWFonts.body())
                        .foregroundColor(GTNWColors.terminalAmber)
                }
                .padding()
                .background(Color.black.opacity(0.3))
                .border(GTNWColors.terminalGreen, width: 1)
            }
        }
    }
}

struct VictoryPathSection: View {
    let analysis: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("🏆 PATH TO VICTORY")
                .font(GTNWFonts.sectionHeader())
                .foregroundColor(GTNWColors.yellow)

            Text(analysis)
                .font(GTNWFonts.body())
                .foregroundColor(GTNWColors.terminalAmber)
                .padding()
                .background(Color.black.opacity(0.5))
                .border(GTNWColors.yellow, width: 1)
        }
    }
}
