//
//  ModernCountryPicker.swift
//  Global Thermal Nuclear War
//
//  Beautiful country selection with glassmorphism
//  Created by Jordan Koch on 2025-12-03.
//

import SwiftUI

struct ModernCountryPicker: View {
    let gameState: GameState
    @Binding var selectedCountry: String?
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    @State private var filterAlignment: PoliticalAlignment?

    private var filteredCountries: [Country] {
        let countries = gameState.countries.filter { !$0.isDestroyed && !$0.isPlayerControlled }

        var filtered = countries

        // Apply alignment filter
        if let alignment = filterAlignment {
            filtered = filtered.filter { $0.alignment == alignment }
        }

        // Apply search
        if !searchText.isEmpty {
            filtered = filtered.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.code.localizedCaseInsensitiveContains(searchText)
            }
        }

        return filtered.sorted { $0.name < $1.name }
    }

    var body: some View {
        ZStack {
            // Space background
            GTNWColors.spaceBackground
                .overlay(ScanlineOverlay().opacity(0.2))

            VStack(spacing: 0) {
                // Header
                header

                // Filters
                filterBar

                // Country count
                Text("\(filteredCountries.count) nations available")
                    .font(GTNWFonts.caption())
                    .foregroundColor(GTNWColors.terminalAmber)
                    .padding(.vertical, 8)

                // Countries grid
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ForEach(filteredCountries) { country in
                            countryCard(country)
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(minWidth: 900, minHeight: 800)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("🎯 SELECT TARGET NATION")
                    .font(GTNWFonts.heading())
                    .foregroundColor(GTNWColors.terminalGreen)

                Text("Choose your target wisely...")
                    .font(GTNWFonts.caption())
                    .foregroundColor(GTNWColors.terminalAmber)
            }

            Spacer()

            Button(action: { dismiss() }) {
                HStack(spacing: 8) {
                    Image(systemName: "xmark.circle.fill")
                    Text("CANCEL")
                }
                .font(GTNWFonts.terminal(size: 16, weight: .bold))
                .foregroundColor(GTNWColors.terminalRed)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(GTNWColors.terminalRed.opacity(0.2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(GTNWColors.terminalRed, lineWidth: 2)
                        )
                )
            }
            .hoverScale()
        }
        .padding(24)
        .background(.ultraThinMaterial)
        .overlay(
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [GTNWColors.neonCyan.opacity(0.3), GTNWColors.neonPurple.opacity(0.3)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 3),
            alignment: .bottom
        )
    }

    private var filterBar: some View {
        VStack(spacing: 12) {
            // Search bar
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(GTNWColors.neonCyan)
                    .font(.system(size: 20))

                TextField("Search nations...", text: $searchText)
                    .textFieldStyle(.plain)
                    .foregroundColor(GTNWColors.terminalGreen)
                    .font(GTNWFonts.terminal(size: 16))

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(GTNWColors.terminalAmber)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(GTNWColors.glassPanelMedium)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(GTNWColors.neonCyan.opacity(0.5), lineWidth: 2)
                    )
            )

            // Alignment filters
            HStack(spacing: 12) {
                Text("Filter:")
                    .font(GTNWFonts.caption())
                    .foregroundColor(GTNWColors.terminalAmber)

                alignmentFilterButton(.western, label: "Western", icon: "🇺🇸")
                alignmentFilterButton(.eastern, label: "Eastern", icon: "🇷🇺")
                alignmentFilterButton(.nonAligned, label: "Non-Aligned", icon: "🌍")

                Button(action: { filterAlignment = nil }) {
                    Text("All Nations")
                        .font(GTNWFonts.caption())
                        .foregroundColor(filterAlignment == nil ? .black : GTNWColors.terminalGreen)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(filterAlignment == nil ? GTNWColors.terminalGreen : Color.clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(GTNWColors.terminalGreen, lineWidth: 1)
                                )
                        )
                }
                .hoverScale(scale: 1.1)
            }
        }
        .padding()
        .background(GTNWColors.glassPanelDark)
    }

    private func alignmentFilterButton(_ alignment: PoliticalAlignment, label: String, icon: String) -> some View {
        Button(action: {
            filterAlignment = filterAlignment == alignment ? nil : alignment
        }) {
            HStack(spacing: 4) {
                Text(icon)
                Text(label)
            }
            .font(GTNWFonts.caption())
            .foregroundColor(filterAlignment == alignment ? .black : GTNWColors.terminalGreen)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(filterAlignment == alignment ? GTNWColors.terminalGreen : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(GTNWColors.terminalGreen, lineWidth: 1)
                    )
            )
        }
        .hoverScale(scale: 1.1)
    }

    private func countryCard(_ country: Country) -> some View {
        Button(action: {
            selectedCountry = country.id
            dismiss()
        }) {
            HStack(spacing: 16) {
                // Flag
                Text(country.flag)
                    .font(.system(size: 48))

                VStack(alignment: .leading, spacing: 8) {
                    // Name
                    Text(country.name)
                        .font(GTNWFonts.terminal(size: 18, weight: .bold))
                        .foregroundColor(GTNWColors.terminalGreen)

                    // Stats
                    HStack(spacing: 12) {
                        quickStat("☢️", value: "\(country.nuclearWarheads)", color: country.nuclearWarheads > 0 ? GTNWColors.terminalRed : GTNWColors.terminalAmber)
                        quickStat("👥", value: country.population.formatted(.number.notation(.compactName)), color: GTNWColors.neonCyan)
                        quickStat("💰", value: "$\(Int(country.gdp / 1_000_000_000))B", color: GTNWColors.neonPurple)
                    }

                    // Badges
                    HStack(spacing: 8) {
                        badge(country.alignment.rawValue)
                        badge(country.nuclearStatus.rawValue)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(GTNWColors.terminalGreen)
            }
            .padding(16)
            .modernCard(glowColor: GTNWColors.terminalGreen)
        }
        .buttonStyle(.plain)
        .hoverScale()
    }

    private func quickStat(_ icon: String, value: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(icon)
            Text(value)
                .font(GTNWFonts.terminal(size: 12, weight: .bold))
                .foregroundColor(color)
        }
    }

    private func badge(_ text: String) -> some View {
        Text(text.uppercased())
            .font(GTNWFonts.terminal(size: 9, weight: .semibold))
            .foregroundColor(GTNWColors.terminalAmber)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(GTNWColors.terminalAmber.opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(GTNWColors.terminalAmber.opacity(0.5), lineWidth: 1)
                    )
            )
    }
}

#Preview {
    ModernCountryPicker(
        gameState: GameState(playerCountryID: "USA"),
        selectedCountry: .constant(nil)
    )
}
