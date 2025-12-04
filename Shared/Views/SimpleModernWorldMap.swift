//
//  SimpleModernWorldMap.swift
//  Global Thermal Nuclear War
//
//  Beautiful but simple world visualization
//  Created by Jordan Koch on 2025-12-03.
//

import SwiftUI

struct SimpleModernWorldMap: View {
    let gameState: GameState
    @State private var selectedCountry: Country?

    var body: some View {
        ZStack {
            // Space background
            GTNWColors.spaceBackground
                .overlay(ScanlineOverlay().opacity(0.2))

            VStack(spacing: 0) {
                // Header
                SectionHeader("🌍 GLOBAL THREAT MAP", icon: "globe", color: GTNWColors.neonCyan)
                    .padding()

                // Countries Grid View (instead of broken canvas)
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ForEach(gameState.countries.filter { !$0.isDestroyed }) { country in
                            countryMapCard(country)
                        }
                    }
                    .padding()
                }

                // Legend
                legend
            }
        }
        .sheet(item: $selectedCountry) { country in
            CountryDetailSheet(country: country, gameState: gameState)
        }
    }

    private func countryMapCard(_ country: Country) -> some View {
        Button(action: { selectedCountry = country }) {
            VStack(spacing: 12) {
                // Flag and status
                ZStack {
                    // Glow for nuclear powers
                    if country.nuclearWarheads > 0 {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [GTNWColors.terminalRed.opacity(0.5), GTNWColors.terminalRed.opacity(0.0)],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 40
                                )
                            )
                            .frame(width: 80, height: 80)
                    }

                    Text(country.flag)
                        .font(.system(size: 56))
                }

                // Name
                Text(country.name)
                    .font(GTNWFonts.terminal(size: 14, weight: .bold))
                    .foregroundColor(country.isPlayerControlled ? GTNWColors.terminalAmber : GTNWColors.terminalGreen)
                    .multilineTextAlignment(.center)

                // Quick stats
                HStack(spacing: 8) {
                    if country.nuclearWarheads > 0 {
                        Text("☢️ \(country.nuclearWarheads)")
                            .font(GTNWFonts.caption())
                            .foregroundColor(GTNWColors.terminalRed)
                    }

                    if !country.atWarWith.isEmpty {
                        Text("⚔️ \(country.atWarWith.count)")
                            .font(GTNWFonts.caption())
                            .foregroundColor(.orange)
                    }

                    if country.radiationLevel > 0 {
                        Text("☢️ \(country.radiationLevel)")
                            .font(GTNWFonts.caption())
                            .foregroundColor(GTNWColors.terminalRed)
                    }
                }

                // Status badge
                Text(country.alignment.rawValue.uppercased())
                    .font(GTNWFonts.terminal(size: 9, weight: .semibold))
                    .foregroundColor(alignmentColor(country.alignment))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(alignmentColor(country.alignment).opacity(0.2))
                            .overlay(Capsule().stroke(alignmentColor(country.alignment).opacity(0.5), lineWidth: 1))
                    )
            }
            .frame(height: 180)
            .frame(maxWidth: .infinity)
            .padding()
            .modernCard(
                glowColor: country.isPlayerControlled ? GTNWColors.terminalAmber :
                    (country.nuclearWarheads > 0 ? GTNWColors.terminalRed : GTNWColors.neonCyan)
            )
        }
        .buttonStyle(.plain)
        .hoverScale()
    }

    private func alignmentColor(_ alignment: PoliticalAlignment) -> Color {
        switch alignment {
        case .western: return GTNWColors.neonBlue
        case .eastern: return GTNWColors.terminalRed
        case .nonAligned: return GTNWColors.terminalAmber
        case .independent: return GTNWColors.neonCyan
        }
    }

    private var legend: some View {
        HStack(spacing: 24) {
            legendItem(icon: "star.fill", color: GTNWColors.terminalAmber, label: "Your Nation")
            legendItem(icon: "flame.fill", color: GTNWColors.terminalRed, label: "Nuclear Power")
            legendItem(icon: "exclamationmark.triangle.fill", color: .orange, label: "At War")
            legendItem(icon: "checkmark.circle.fill", color: GTNWColors.terminalGreen, label: "Peaceful")
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    private func legendItem(icon: String, color: Color, label: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 14))
            Text(label)
                .font(GTNWFonts.caption())
                .foregroundColor(GTNWColors.terminalAmber)
        }
    }
}

struct CountryDetailSheet: View {
    let country: Country
    let gameState: GameState
    @Environment(\.dismiss) var dismiss

    private var relationWithPlayer: Int {
        guard let player = gameState.getPlayerCountry() else { return 0 }
        return player.diplomaticRelations[country.id] ?? 0
    }

    var body: some View {
        ZStack {
            GTNWColors.commandCenterBackground

            VStack(spacing: 24) {
                // Header
                HStack {
                    Text(country.flag)
                        .font(.system(size: 72))

                    VStack(alignment: .leading, spacing: 8) {
                        Text(country.name)
                            .font(GTNWFonts.heading())
                            .foregroundColor(GTNWColors.neonCyan)

                        HStack(spacing: 12) {
                            badge(country.alignment.rawValue, color: alignmentColor(country.alignment))
                            badge(country.government.rawValue, color: GTNWColors.lcarsSkyBlue)
                            badge(country.nuclearStatus.rawValue, color: GTNWColors.terminalRed)
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

                // Stats Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    StatCard(title: "Nuclear Warheads", value: "\(country.nuclearWarheads)", icon: "flame.fill", color: GTNWColors.terminalRed)
                    StatCard(title: "Population", value: country.population.formatted(.number.notation(.compactName)), icon: "person.3.fill", color: GTNWColors.neonCyan)
                    StatCard(title: "GDP", value: "$\(Int(country.gdp / 1_000_000_000))B", icon: "dollarsign.circle.fill", color: GTNWColors.neonPurple)
                    StatCard(title: "Active Wars", value: "\(country.atWarWith.count)", icon: "exclamationmark.triangle.fill", color: .orange)
                    StatCard(title: "Radiation", value: "\(country.radiationLevel)", icon: "radiation", color: country.radiationLevel > 0 ? GTNWColors.terminalRed : GTNWColors.terminalGreen)
                    StatCard(title: "Military", value: "\(country.militaryStrength)", icon: "shield.fill", color: GTNWColors.neonBlue)
                }
                .padding(.horizontal)

                // Relationship with player
                if !country.isPlayerControlled {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("DIPLOMATIC RELATIONS")
                            .font(GTNWFonts.subheading())
                            .foregroundColor(GTNWColors.terminalAmber)

                        HStack {
                            Text(relationshipText(relationWithPlayer))
                                .font(GTNWFonts.terminal(size: 18, weight: .bold))
                                .foregroundColor(relationshipColor(relationWithPlayer))

                            Spacer()

                            Text("\(relationWithPlayer > 0 ? "+" : "")\(relationWithPlayer)")
                                .font(GTNWFonts.terminal(size: 24, weight: .bold))
                                .foregroundColor(relationshipColor(relationWithPlayer))
                        }

                        ThreatLevelIndicator(
                            level: min(100, max(0, relationWithPlayer + 50)),
                            label: "Relationship Strength"
                        )
                    }
                    .padding()
                    .glassPanel(borderColor: relationshipColor(relationWithPlayer).opacity(0.5))
                    .padding(.horizontal)
                }

                Spacer()
            }
        }
        .frame(minWidth: 800, minHeight: 700)
    }

    private func alignmentColor(_ alignment: PoliticalAlignment) -> Color {
        switch alignment {
        case .western: return GTNWColors.neonBlue
        case .eastern: return GTNWColors.terminalRed
        case .nonAligned: return GTNWColors.terminalAmber
        case .independent: return GTNWColors.neonCyan
        }
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text.uppercased())
            .font(GTNWFonts.terminal(size: 10, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(color.opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(color.opacity(0.5), lineWidth: 1)
                    )
            )
    }

    private func relationshipText(_ value: Int) -> String {
        switch value {
        case 75...: return "Allied"
        case 50..<75: return "Friendly"
        case 25..<50: return "Cooperative"
        case -25..<25: return "Neutral"
        case -50..<(-25): return "Tense"
        case -75..<(-50): return "Hostile"
        default: return "Enemies"
        }
    }

    private func relationshipColor(_ value: Int) -> Color {
        switch value {
        case 50...: return GTNWColors.terminalGreen
        case 0..<50: return GTNWColors.neonCyan
        case -50..<0: return GTNWColors.terminalAmber
        default: return GTNWColors.terminalRed
        }
    }
}

#Preview {
    SimpleModernWorldMap(gameState: GameState(playerCountryID: "USA"))
}
