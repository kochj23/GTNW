//
//  SystemsView.swift
//  Global Thermal Nuclear War
//
//  Unified UI for all 10 game systems
//

import SwiftUI

struct SystemsView: View {
    @ObservedObject var gameEngine: GameEngine
    @State private var selectedTab = 0

    var body: some View {
        guard let gs = gameEngine.gameState else {
            return AnyView(Text("No active game").foregroundColor(AppSettings.terminalGreen))
        }

        return AnyView(
            VStack(spacing: 0) {
                // Tab selector
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        systemTab("Intel", icon: "🕵️", index: 0)
                        systemTab("Crisis", icon: "⚠️", index: 1)
                        systemTab("Winter", icon: "❄️", index: 2)
                        systemTab("Diplomacy", icon: "📜", index: 3)
                        systemTab("Proxy", icon: "🎖️", index: 4)
                        systemTab("Economy", icon: "💰", index: 5)
                        systemTab("AI", icon: "🤖", index: 6)
                        systemTab("Subs", icon: "🛥️", index: 7)
                        systemTab("Space", icon: "🛰️", index: 8)
                        systemTab("Scenario", icon: "📚", index: 9)
                    }
                    .padding(.horizontal)
                }
                .frame(height: FontScale.h(50))
                .background(Color.black.opacity(0.3))

                Divider()

                // Content area
                ScrollView {
                    Group {
                        switch selectedTab {
                        case 0: IntelView(systems: gs.systems)
                        case 1: CrisisView(systems: gs.systems)
                        case 2: WinterView(systems: gs.systems)
                        case 3: DiplomacyView(systems: gs.systems)
                        case 4: ProxyView(systems: gs.systems)
                        case 5: EconomyView(systems: gs.systems)
                        case 6: AIView(systems: gs.systems)
                        case 7: SubView(systems: gs.systems)
                        case 8: SpaceView(systems: gs.systems)
                        case 9: ScenarioView(gameEngine: gameEngine)
                        default: EmptyView()
                        }
                    }
                    .padding()
                }
            }
            .background(Color.black)
        )
    }

    private func systemTab(_ title: String, icon: String, index: Int) -> some View {
        Button(action: { selectedTab = index }) {
            HStack(spacing: 4) {
                Text(icon)
                Text(title)
                    .font(.scaled(size: 12, design: .monospaced))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(selectedTab == index ? AppSettings.terminalGreen.opacity(0.3) : Color.clear)
            .foregroundColor(selectedTab == index ? AppSettings.terminalGreen : .gray)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(selectedTab == index ? AppSettings.terminalGreen : Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

// MARK: - Intelligence View
struct IntelView: View {
    let systems: SystemsManager

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("🕵️ INTELLIGENCE & ESPIONAGE")
                .font(.scaled(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(AppSettings.terminalGreen)

            // Spy Networks
            VStack(alignment: .leading, spacing: 8) {
                Text("Spy Networks: \(systems.spyNets.count)")
                    .foregroundColor(.white)
                ForEach(systems.spyNets) { net in
                    HStack {
                        Text("• \(net.location)")
                        Spacer()
                        Text("Strength: \(net.strength)%")
                        Text(net.compromised ? "🚨 COMPROMISED" : "✓ Active")
                            .foregroundColor(net.compromised ? .red : .green)
                    }
                    .font(.scaled(size: 12, design: .monospaced))
                    .foregroundColor(.gray)
                }
            }

            Divider().background(AppSettings.terminalGreen)

            // Active Operations
            VStack(alignment: .leading, spacing: 8) {
                Text("Active Operations: \(systems.intelOps.count)")
                    .foregroundColor(.white)
                ForEach(systems.intelOps.prefix(10)) { op in
                    HStack {
                        Text("• \(op.type.rawValue)")
                        Spacer()
                        Text("Turn \(op.turn)")
                        Text(op.success ? "✓" : "...")
                    }
                    .font(.scaled(size: 12, design: .monospaced))
                    .foregroundColor(.gray)
                }
            }
        }
    }
}

// MARK: - Crisis View
struct CrisisView: View {
    let systems: SystemsManager

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("⚠️ CRISIS EVENTS")
                .font(.scaled(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(AppSettings.terminalRed)

            if systems.crises.isEmpty {
                Text("No active crises")
                    .foregroundColor(.green)
            } else {
                ForEach(systems.crises) { crisis in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(crisis.type.rawValue.uppercased())
                            .font(.scaled(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(AppSettings.terminalRed)

                        Text("⏰ Deadline: \(crisis.deadline) turns")
                            .foregroundColor(crisis.deadline <= 2 ? .red : .orange)

                        if !crisis.options.isEmpty {
                            Text("Options:")
                            ForEach(crisis.options, id: \.self) { option in
                                Text("• \(option)")
                                    .font(.scaled(size: 11, design: .monospaced))
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding()
                    .background(AppSettings.terminalRed.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(AppSettings.terminalRed, lineWidth: 2)
                    )
                }
            }

            Divider().background(.gray)

            Text("Resolved: \(systems.resolved.count)")
                .foregroundColor(.gray)
        }
    }
}

// MARK: - Nuclear Winter View
struct WinterView: View {
    let systems: SystemsManager

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("❄️ NUCLEAR WINTER & ENVIRONMENT")
                .font(.scaled(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(.cyan)

            // Environmental State
            Group {
                statusRow("Stage", "\(systems.environ.stage.rawValue)/5")
                statusRow("Temperature Drop", "-\(systems.environ.temp)°C")
                statusRow("Food Production", "\(systems.environ.food)%")
                statusRow("Habitable Land", "\(systems.environ.land)%")
                statusRow("Atmospheric Soot", "\(systems.environ.soot)%")
            }

            Divider().background(.cyan)

            // Famine
            Text("🌾 FAMINE STATUS")
                .font(.scaled(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(.orange)

            Group {
                statusRow("Severity", "\(systems.famine.severity)%")
                statusRow("Deaths", "\(systems.famine.deaths)")
                statusRow("Food Reserves", "\(systems.famine.reserves) months")
                statusRow("Civil Unrest", "\(systems.famine.unrest)%")
            }

            Divider().background(.cyan)

            // Disease
            Text("🦠 DISEASE OUTBREAKS")
                .font(.scaled(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(.red)

            statusRow("Total Cases", "\(systems.disease.total)")

            Divider().background(.cyan)

            // Refugees
            Text("👥 REFUGEE CRISIS")
                .font(.scaled(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(.yellow)

            statusRow("Total Refugees", "\(systems.refugees.total) million")
        }
    }

    private func statusRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text("\(label):")
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .foregroundColor(.white)
        }
        .font(.scaled(size: 12, design: .monospaced))
    }
}

// MARK: - Diplomacy View
struct DiplomacyView: View {
    let systems: SystemsManager

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("📜 DIPLOMACY & TREATIES")
                .font(.scaled(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(AppSettings.terminalGreen)

            // Treaties
            VStack(alignment: .leading, spacing: 8) {
                Text("Treaty Proposals: \(systems.treaties.count)")
                    .foregroundColor(.white)
                ForEach(systems.treaties) { treaty in
                    HStack {
                        Text("• \(treaty.type.rawValue)")
                        Spacer()
                        Text(treaty.accepted ? "✓ Signed" : "⏳ Pending")
                            .foregroundColor(treaty.accepted ? .green : .yellow)
                    }
                    .font(.scaled(size: 12, design: .monospaced))
                    .foregroundColor(.gray)
                }
            }

            Divider().background(AppSettings.terminalGreen)

            // Verifications
            VStack(alignment: .leading, spacing: 8) {
                Text("Verification Missions: \(systems.verifications.count)")
                    .foregroundColor(.white)
                ForEach(systems.verifications.prefix(10)) { verify in
                    HStack {
                        Text("• Inspector: \(verify.initiatorID)")
                        Spacer()
                        if verify.cheating {
                            Text("🚨 CHEATING DETECTED")
                                .foregroundColor(.red)
                        } else {
                            Text("✓ Compliant")
                                .foregroundColor(.green)
                        }
                    }
                    .font(.scaled(size: 12, design: .monospaced))
                    .foregroundColor(.gray)
                }
            }
        }
    }
}

// MARK: - Proxy Wars View
struct ProxyView: View {
    let systems: SystemsManager

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("🎖️ PROXY WARS & CONVENTIONAL WARFARE")
                .font(.scaled(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(.orange)

            // Proxy Wars
            VStack(alignment: .leading, spacing: 8) {
                Text("Active Proxy Wars: \(systems.proxies.count)")
                    .foregroundColor(.white)
                ForEach(systems.proxies) { proxy in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("• \(proxy.type.rawValue)")
                            Spacer()
                            Text("Strength: \(proxy.strength)%")
                        }
                        Text("Casualties: \(proxy.casualties)")
                            .font(.scaled(size: 10, design: .monospaced))
                            .foregroundColor(.gray)
                    }
                    .font(.scaled(size: 12, design: .monospaced))
                    .foregroundColor(.gray)
                }
            }

            Divider().background(.orange)

            // Arms Sales
            Text("Arms Deals: \(systems.arms.count)")
                .foregroundColor(.white)
        }
    }
}

// MARK: - Economy View
struct EconomyView: View {
    let systems: SystemsManager

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("💰 ECONOMIC WARFARE")
                .font(.scaled(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(.yellow)

            // Sanctions
            VStack(alignment: .leading, spacing: 8) {
                Text("Active Sanctions: \(systems.sanctions.count)")
                    .foregroundColor(.white)
                ForEach(systems.sanctions) { sanction in
                    HStack {
                        Text("• \(sanction.type.rawValue)")
                        Spacer()
                        Text("\(sanction.imposer) → \(sanction.target)")
                    }
                    .font(.scaled(size: 12, design: .monospaced))
                    .foregroundColor(.gray)
                }
            }

            Divider().background(.yellow)

            // Currency Attacks
            VStack(alignment: .leading, spacing: 8) {
                Text("Currency Attacks: \(systems.currency.count)")
                    .foregroundColor(.white)
                ForEach(systems.currency.prefix(10)) { attack in
                    HStack {
                        Text("• \(attack.initiatorID) → \(attack.targetID)")
                        Spacer()
                        Text("Inflation: \(attack.inflation)%")
                    }
                    .font(.scaled(size: 12, design: .monospaced))
                    .foregroundColor(.gray)
                }
            }
        }
    }
}

// MARK: - AI View
struct AIView: View {
    let systems: SystemsManager

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("🤖 AI PERSONALITIES")
                .font(.scaled(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(.purple)

            ForEach(Leader.presets, id: \.name) { leader in
                VStack(alignment: .leading, spacing: 8) {
                    Text(leader.name.uppercased())
                        .font(.scaled(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)

                    HStack {
                        Text("Personality:")
                        Text(leader.personality.rawValue)
                            .foregroundColor(AppSettings.terminalGreen)
                    }
                    HStack {
                        Text("Ideology:")
                        Text(leader.ideology.rawValue)
                            .foregroundColor(.cyan)
                    }
                    HStack {
                        Text("Goal:")
                        Text(leader.goal.rawValue)
                            .foregroundColor(.orange)
                    }
                }
                .font(.scaled(size: 12, design: .monospaced))
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(4)
            }
        }
    }
}

// MARK: - Submarine View
struct SubView: View {
    let systems: SystemsManager

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("🛥️ SUBMARINE WARFARE")
                .font(.scaled(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(.blue)

            // Submarines
            VStack(alignment: .leading, spacing: 8) {
                Text("Deployed Submarines: \(systems.subs.count)")
                    .foregroundColor(.white)
                ForEach(systems.subs) { sub in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("• \(sub.subClass.rawValue)")
                            Spacer()
                            Text(sub.detected ? "🚨 DETECTED" : "🔇 Hidden")
                                .foregroundColor(sub.detected ? .red : .green)
                        }
                        HStack {
                            Text("Location: \(sub.loc.rawValue)")
                            Spacer()
                            Text("Warheads: \(sub.warheads)")
                        }
                        .font(.scaled(size: 10, design: .monospaced))
                        .foregroundColor(.gray)
                    }
                    .font(.scaled(size: 12, design: .monospaced))
                    .foregroundColor(.gray)
                }
            }

            Divider().background(.blue)

            // ASW Operations
            Text("ASW Operations: \(systems.asw.count)")
                .foregroundColor(.white)
        }
    }
}

// MARK: - Space View
struct SpaceView: View {
    let systems: SystemsManager

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("🛰️ SPACE WARFARE")
                .font(.scaled(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(.cyan)

            // Satellites
            VStack(alignment: .leading, spacing: 8) {
                Text("Satellites: \(systems.sats.count)")
                    .foregroundColor(.white)
                ForEach(systems.sats) { sat in
                    HStack {
                        Text("• \(sat.type.rawValue)")
                        Spacer()
                        Text(sat.operational ? "✓ Operational" : "❌ Offline")
                            .foregroundColor(sat.operational ? .green : .red)
                    }
                    .font(.scaled(size: 12, design: .monospaced))
                    .foregroundColor(.gray)
                }
            }

            Divider().background(.cyan)

            // Debris
            VStack(alignment: .leading, spacing: 8) {
                Text("ORBITAL DEBRIS STATUS")
                    .font(.scaled(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(systems.debris.kessler > 50 ? .red : .orange)

                HStack {
                    Text("Total Debris:")
                    Spacer()
                    Text("\(systems.debris.total)")
                }
                HStack {
                    Text("Kessler Syndrome Risk:")
                    Spacer()
                    Text("\(systems.debris.kessler)%")
                        .foregroundColor(systems.debris.kessler > 75 ? .red : systems.debris.kessler > 50 ? .orange : .yellow)
                }
                HStack {
                    Text("Compromised Zones:")
                    Spacer()
                    Text(systems.debris.zones.joined(separator: ", "))
                }
            }
            .font(.scaled(size: 12, design: .monospaced))
            .foregroundColor(.gray)
        }
    }
}

// MARK: - Scenario View
struct ScenarioView: View {
    @ObservedObject var gameEngine: GameEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("📚 HISTORICAL SCENARIOS")
                .font(.scaled(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(AppSettings.terminalGreen)

            ForEach(Scenario.all) { scenario in
                Button(action: {
                    gameEngine.startNewGame(playerCountryID: "USA", difficulty: scenario.difficulty)
                    gameEngine.gameState?.systems.scenario = scenario
                    gameEngine.gameState?.defconLevel = scenario.defcon
                }) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("\(scenario.name) (\(scenario.year))")
                                .font(.scaled(size: 14, weight: .bold, design: .monospaced))
                            Spacer()
                            Text(scenario.difficulty.rawValue)
                                .font(.scaled(size: 10, design: .monospaced))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(difficultyColor(scenario.difficulty).opacity(0.3))
                                .foregroundColor(difficultyColor(scenario.difficulty))
                        }

                        Text(scenario.desc)
                            .font(.scaled(size: 11, design: .monospaced))
                            .foregroundColor(.gray)

                        Text("🎯 \(scenario.objective)")
                            .font(.scaled(size: 11, design: .monospaced))
                            .foregroundColor(.cyan)
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(AppSettings.terminalGreen, lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    private func difficultyColor(_ difficulty: DifficultyLevel) -> Color {
        switch difficulty {
        case .easy: return .green
        case .normal: return .yellow
        case .hard: return .orange
        case .nightmare: return .red
        }
    }
}
