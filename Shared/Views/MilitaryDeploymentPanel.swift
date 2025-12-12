//
//  MilitaryDeploymentPanel.swift
//  Global Thermal Nuclear War
//
//  Granular control over military deployments
//  Created by Jordan Koch on 2025-12-11.
//

import SwiftUI

struct MilitaryDeploymentPanel: View {
    @EnvironmentObject var gameEngine: GameEngine
    @Environment(\.dismiss) var dismiss

    let war: EnhancedWar
    let gameState: GameState

    @State private var infantryToDeploy: Int = 0
    @State private var tanksToDeploy: Int = 0
    @State private var artilleryToDeploy: Int = 0
    @State private var aircraftToDeploy: Int = 0
    @State private var shipsToDeploy: Int = 0

    private var playerCountry: Country? {
        gameState.getPlayerCountry()
    }

    private var totalUnitsSelected: Int {
        infantryToDeploy + tanksToDeploy + artilleryToDeploy + aircraftToDeploy + shipsToDeploy
    }

    private var estimatedCost: Double {
        // Cost in billions
        let infantryCost = Double(infantryToDeploy) * 0.0001  // $100k per soldier
        let tankCost = Double(tanksToDeploy) * 0.005          // $5M per tank
        let artilleryCost = Double(artilleryToDeploy) * 0.002 // $2M per artillery piece
        let aircraftCost = Double(aircraftToDeploy) * 0.1     // $100M per aircraft
        let shipCost = Double(shipsToDeploy) * 1.0            // $1B per ship

        return infantryCost + tankCost + artilleryCost + aircraftCost + shipCost
    }

    var body: some View {
        ZStack {
            GTNWColors.commandCenterBackground

            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading) {
                        Text("🪖 MILITARY DEPLOYMENT")
                            .font(GTNWFonts.heading())
                            .foregroundColor(GTNWColors.neonBlue)

                        if let player = playerCountry,
                           let target = war.aggressor == player.id ?
                            gameState.getCountry(id: war.defender) :
                            gameState.getCountry(id: war.aggressor) {
                            Text("Deploy forces against " + target.name)
                                .font(GTNWFonts.body())
                                .foregroundColor(GTNWColors.terminalAmber.opacity(0.7))
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
                        // Player's available forces
                        availableForcesSection

                        // Unit selection sliders
                        infantrySelector
                        tankSelector
                        artillerySelector
                        aircraftSelector
                        shipsSelector

                        // Summary
                        deploymentSummary

                        // Deploy button
                        deployButton
                    }
                    .padding()
                }
            }
        }
        .frame(minWidth: 800, minHeight: 700)
    }

    private var availableForcesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("AVAILABLE FORCES")
                .font(GTNWFonts.subheading())
                .foregroundColor(GTNWColors.terminalAmber)

            if let player = playerCountry {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    QuickStatBadge(
                        label: "Military Strength",
                        value: "\(player.militaryStrength)/100",
                        color: GTNWColors.neonBlue
                    )

                    QuickStatBadge(
                        label: "GDP Available",
                        value: "$\(Int(player.gdp / 1_000_000_000))B",
                        color: GTNWColors.neonPurple
                    )

                    QuickStatBadge(
                        label: "Public Support",
                        value: "\(player.warSupport)%",
                        color: player.warSupport > 50 ? GTNWColors.terminalGreen : GTNWColors.terminalRed
                    )
                }
            }
        }
        .padding(20)
        .glassPanel(borderColor: GTNWColors.neonCyan.opacity(0.3))
    }

    private var infantrySelector: some View {
        UnitDeploymentSelector(
            unitType: "Infantry",
            icon: "person.3.fill",
            currentValue: $infantryToDeploy,
            maxValue: 1_000_000,
            increment: 10_000,
            color: GTNWColors.neonBlue,
            unitCost: 0.0001
        )
    }

    private var tankSelector: some View {
        UnitDeploymentSelector(
            unitType: "Tanks",
            icon: "car.fill",
            currentValue: $tanksToDeploy,
            maxValue: 5_000,
            increment: 100,
            color: GTNWColors.neonBlue,
            unitCost: 0.005
        )
    }

    private var artillerySelector: some View {
        UnitDeploymentSelector(
            unitType: "Artillery",
            icon: "scope",
            currentValue: $artilleryToDeploy,
            maxValue: 3_000,
            increment: 50,
            color: GTNWColors.neonBlue,
            unitCost: 0.002
        )
    }

    private var aircraftSelector: some View {
        UnitDeploymentSelector(
            unitType: "Aircraft",
            icon: "airplane",
            currentValue: $aircraftToDeploy,
            maxValue: 1_000,
            increment: 10,
            color: GTNWColors.neonBlue,
            unitCost: 0.1
        )
    }

    private var shipsSelector: some View {
        UnitDeploymentSelector(
            unitType: "Naval Vessels",
            icon: "ferry.fill",
            currentValue: $shipsToDeploy,
            maxValue: 100,
            increment: 1,
            color: GTNWColors.neonBlue,
            unitCost: 1.0
        )
    }

    private var deploymentSummary: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("DEPLOYMENT SUMMARY")
                .font(GTNWFonts.subheading())
                .foregroundColor(GTNWColors.terminalAmber)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                StatCard(
                    title: "Total Units",
                    value: "\(totalUnitsSelected)",
                    icon: "person.3.fill",
                    color: GTNWColors.neonBlue
                )

                StatCard(
                    title: "Est. Cost",
                    value: "$\(String(format: "%.1f", estimatedCost))B",
                    icon: "dollarsign.circle.fill",
                    color: GTNWColors.neonPurple
                )
            }
        }
        .padding(20)
        .glassPanel(borderColor: GTNWColors.neonPurple.opacity(0.3))
    }

    private var deployButton: some View {
        Button(action: deployForces) {
            HStack {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 24))
                Text("DEPLOY FORCES")
                    .font(GTNWFonts.terminal(size: 18, weight: .bold))
            }
            .foregroundColor(totalUnitsSelected > 0 ? GTNWColors.terminalGreen : Color.gray)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(totalUnitsSelected > 0 ? GTNWColors.terminalGreen.opacity(0.2) : Color.gray.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(totalUnitsSelected > 0 ? GTNWColors.terminalGreen : Color.gray, lineWidth: 2)
                    )
            )
        }
        .disabled(totalUnitsSelected == 0)
        .hoverScale()
    }

    private func deployForces() {
        let deployment = MilitaryDeployment(
            infantry: infantryToDeploy,
            tanks: tanksToDeploy,
            artillery: artilleryToDeploy,
            aircraft: aircraftToDeploy,
            ships: shipsToDeploy,
            nuclearWarheads: 0
        )

        gameEngine.deployMilitaryForces(warID: war.id, deployment: deployment)
        dismiss()
    }
}

// MARK: - Unit Deployment Selector

struct UnitDeploymentSelector: View {
    let unitType: String
    let icon: String
    @Binding var currentValue: Int
    let maxValue: Int
    let increment: Int
    let color: Color
    let unitCost: Double

    var totalCost: Double {
        Double(currentValue) * unitCost
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)

                Text(unitType)
                    .font(GTNWFonts.terminal(size: 16, weight: .bold))
                    .foregroundColor(GTNWColors.terminalAmber)

                Spacer()

                Text("\(currentValue.formatted())")
                    .font(GTNWFonts.terminal(size: 18, weight: .bold))
                    .foregroundColor(color)

                Text("($\(String(format: "%.2f", totalCost))B)")
                    .font(GTNWFonts.caption())
                    .foregroundColor(GTNWColors.neonPurple)
            }

            HStack(spacing: 12) {
                // Decrement button
                Button(action: {
                    currentValue = max(0, currentValue - increment)
                }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(currentValue > 0 ? color : Color.gray)
                }
                .disabled(currentValue == 0)

                // Slider
                Slider(value: Binding(
                    get: { Double(currentValue) },
                    set: { currentValue = Int($0) }
                ), in: 0...Double(maxValue), step: Double(increment))
                    .accentColor(color)

                // Increment button
                Button(action: {
                    currentValue = min(maxValue, currentValue + increment)
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(currentValue < maxValue ? color : Color.gray)
                }
                .disabled(currentValue >= maxValue)
            }

            // Quick select buttons
            HStack(spacing: 8) {
                ForEach([0.25, 0.5, 0.75, 1.0], id: \.self) { fraction in
                    Button(action: {
                        currentValue = Int(Double(maxValue) * fraction)
                    }) {
                        Text("\(Int(fraction * 100))%")
                            .font(GTNWFonts.terminal(size: 10, weight: .semibold))
                            .foregroundColor(color)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(color.opacity(0.2))
                                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(color.opacity(0.5), lineWidth: 1))
                            )
                    }
                }

                Spacer()

                Button(action: {
                    currentValue = 0
                }) {
                    Text("CLEAR")
                        .font(GTNWFonts.terminal(size: 10, weight: .semibold))
                        .foregroundColor(GTNWColors.terminalRed)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(GTNWColors.terminalRed.opacity(0.2))
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(GTNWColors.terminalRed.opacity(0.5), lineWidth: 1))
                        )
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Nuclear Strike Panel

struct NuclearStrikePanelView: View {
    @EnvironmentObject var gameEngine: GameEngine
    @Environment(\.dismiss) var dismiss

    let war: EnhancedWar
    let gameState: GameState

    @State private var warheadsToUse: Int = 1
    @State private var strikeType: StrikeType = .tactical
    @State private var showingConfirmation = false

    private var playerCountry: Country? {
        gameState.getPlayerCountry()
    }

    private var maxWarheads: Int {
        playerCountry?.nuclearWarheads ?? 0
    }

    private var estimatedCasualties: Int {
        let basePerWarhead = 500_000
        let multiplier = strikeType == .strategic ? 3.0 : 1.0
        return Int(Double(warheadsToUse * basePerWarhead) * multiplier)
    }

    var body: some View {
        ZStack {
            GTNWColors.commandCenterBackground

            VStack(spacing: 0) {
                // Header with warning
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(GTNWColors.terminalRed)

                        VStack(alignment: .leading) {
                            Text("☢️ NUCLEAR STRIKE")
                                .font(GTNWFonts.heading())
                                .foregroundColor(GTNWColors.terminalRed)

                            Text("POINT OF NO RETURN")
                                .font(GTNWFonts.subheading())
                                .foregroundColor(GTNWColors.terminalAmber)
                        }

                        Spacer()

                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(GTNWColors.terminalRed)
                        }
                    }

                    // Critical warning
                    Text("⚠️ This action CANNOT be undone. Nuclear war will likely result in global catastrophe.")
                        .font(GTNWFonts.body())
                        .foregroundColor(GTNWColors.terminalRed)
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(GTNWColors.terminalRed.opacity(0.2))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(GTNWColors.terminalRed, lineWidth: 2))
                        )
                }
                .padding()

                ScrollView {
                    VStack(spacing: 24) {
                        // Available arsenal
                        availableArsenalSection

                        // Warhead selector
                        warheadSelector

                        // Strike type
                        strikeTypeSelector

                        // Estimated consequences
                        consequencesSection

                        // Launch button
                        launchButton
                    }
                    .padding()
                }
            }
        }
        .frame(minWidth: 800, minHeight: 700)
    }

    private var availableArsenalSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("AVAILABLE ARSENAL")
                .font(GTNWFonts.subheading())
                .foregroundColor(GTNWColors.terminalAmber)

            if let player = playerCountry {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    QuickStatBadge(
                        label: "Total Warheads",
                        value: "\(player.nuclearWarheads)",
                        color: GTNWColors.terminalRed
                    )

                    QuickStatBadge(
                        label: "ICBMs",
                        value: "\(player.icbmCount)",
                        color: GTNWColors.terminalRed
                    )

                    QuickStatBadge(
                        label: "SLBMs",
                        value: "\(player.submarineLaunchedMissiles)",
                        color: GTNWColors.terminalRed
                    )
                }
            }
        }
        .padding(20)
        .glassPanel(borderColor: GTNWColors.terminalRed.opacity(0.5))
    }

    private var warheadSelector: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("WARHEADS TO DEPLOY")
                .font(GTNWFonts.subheading())
                .foregroundColor(GTNWColors.terminalAmber)

            HStack(spacing: 12) {
                Button(action: {
                    warheadsToUse = max(1, warheadsToUse - 1)
                }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(warheadsToUse > 1 ? GTNWColors.terminalRed : Color.gray)
                }
                .disabled(warheadsToUse <= 1)

                Text("\(warheadsToUse)")
                    .font(GTNWFonts.terminal(size: 48, weight: .bold))
                    .foregroundColor(GTNWColors.terminalRed)
                    .frame(maxWidth: .infinity)

                Button(action: {
                    warheadsToUse = min(maxWarheads, warheadsToUse + 1)
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(warheadsToUse < maxWarheads ? GTNWColors.terminalRed : Color.gray)
                }
                .disabled(warheadsToUse >= maxWarheads)
            }

            Slider(value: Binding(
                get: { Double(warheadsToUse) },
                set: { warheadsToUse = Int($0) }
            ), in: 1...Double(maxWarheads), step: 1)
                .accentColor(GTNWColors.terminalRed)
        }
        .padding(20)
        .glassPanel(borderColor: GTNWColors.terminalRed.opacity(0.5))
    }

    private var strikeTypeSelector: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("STRIKE TYPE")
                .font(GTNWFonts.subheading())
                .foregroundColor(GTNWColors.terminalAmber)

            HStack(spacing: 16) {
                ForEach(StrikeType.allCases, id: \.self) { type in
                    Button(action: {
                        strikeType = type
                    }) {
                        VStack(spacing: 8) {
                            Text(type.rawValue)
                                .font(GTNWFonts.terminal(size: 14, weight: .bold))
                                .foregroundColor(strikeType == type ? GTNWColors.terminalRed : GTNWColors.terminalAmber.opacity(0.7))

                            Text(type.description)
                                .font(GTNWFonts.caption())
                                .foregroundColor(strikeType == type ? GTNWColors.terminalAmber : GTNWColors.terminalAmber.opacity(0.5))
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(strikeType == type ? GTNWColors.terminalRed.opacity(0.2) : Color.black.opacity(0.3))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(strikeType == type ? GTNWColors.terminalRed : GTNWColors.terminalAmber.opacity(0.3), lineWidth: strikeType == type ? 2 : 1)
                                )
                        )
                    }
                }
            }
        }
        .padding(20)
        .glassPanel(borderColor: GTNWColors.terminalAmber.opacity(0.3))
    }

    private var consequencesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("⚠️ ESTIMATED CONSEQUENCES")
                .font(GTNWFonts.subheading())
                .foregroundColor(GTNWColors.terminalRed)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                StatCard(
                    title: "Immediate Deaths",
                    value: estimatedCasualties.formatted(.number.notation(.compactName)),
                    icon: "person.fill.xmark",
                    color: GTNWColors.terminalRed
                )

                StatCard(
                    title: "Radiation Deaths",
                    value: (estimatedCasualties / 2).formatted(.number.notation(.compactName)),
                    icon: "radiation",
                    color: GTNWColors.terminalRed
                )

                StatCard(
                    title: "Retaliation Risk",
                    value: "95%",
                    icon: "exclamationmark.triangle.fill",
                    color: GTNWColors.terminalRed
                )

                StatCard(
                    title: "Global Impact",
                    value: "CATASTROPHIC",
                    icon: "globe",
                    color: GTNWColors.terminalRed
                )
            }

            Text("\"The only winning move is not to play.\" - WOPR")
                .font(GTNWFonts.terminal(size: 14, weight: .bold))
                .foregroundColor(GTNWColors.neonCyan)
                .frame(maxWidth: .infinity)
                .padding()
        }
        .padding(20)
        .glassPanel(borderColor: GTNWColors.terminalRed.opacity(0.5))
    }

    private var launchButton: some View {
        Button(action: { showingConfirmation = true }) {
            HStack {
                Image(systemName: "flame.fill")
                    .font(.system(size: 24))
                Text("AUTHORIZE NUCLEAR STRIKE")
                    .font(GTNWFonts.terminal(size: 18, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(GTNWColors.terminalRed)
                    .shadow(color: GTNWColors.terminalRed.opacity(0.5), radius: 20)
            )
        }
        .hoverScale()
        .alert("CONFIRM NUCLEAR STRIKE", isPresented: $showingConfirmation) {
            Button("CANCEL", role: .cancel) { }
            Button("LAUNCH", role: .destructive) {
                launchNuclearStrike()
            }
        } message: {
            Text("This will launch \(warheadsToUse) nuclear warhead(s). Approximately \(estimatedCasualties.formatted()) people will die. This action CANNOT be undone.")
        }
    }

    private func launchNuclearStrike() {
        guard let player = playerCountry else { return }

        let targetID = war.aggressor == player.id ? war.defender : war.aggressor

        gameEngine.launchNuclearStrike(
            from: player.id,
            to: targetID,
            warheads: warheadsToUse
        )

        dismiss()
    }

    enum StrikeType: String, CaseIterable {
        case tactical = "Tactical"
        case strategic = "Strategic"

        var description: String {
            switch self {
            case .tactical: return "Military targets"
            case .strategic: return "Cities & infrastructure"
            }
        }
    }
}

#Preview {
    MilitaryDeploymentPanel(
        war: EnhancedWar(aggressor: "USA", defender: "RUS", startTurn: 1),
        gameState: GameState(playerCountryID: "USA")
    )
    .environmentObject(GameEngine())
}
