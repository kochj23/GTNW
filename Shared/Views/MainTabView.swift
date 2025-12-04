//
//  MainTabView.swift
//  Global Thermal Nuclear War
//
//  Modern tabbed interface inspired by NMAPScanner
//  Created by Jordan Koch on 2025-12-03.
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var gameEngine: GameEngine
    @State private var selectedTab = 0

    var body: some View {
        if gameEngine.gameState == nil {
            // Start screen
            ContentView()
                .environmentObject(gameEngine)
        } else {
            // Game tabs
            TabView(selection: $selectedTab) {
                // Unified Command Center (Commands + Terminal + Event Log)
                UnifiedCommandCenter()
                    .environmentObject(gameEngine)
                    .tabItem {
                        Label("Command", systemImage: "command.circle.fill")
                    }
                    .tag(0)

                // World Map
                SimpleModernWorldMap(gameState: gameEngine.gameState!)
                    .tabItem {
                        Label("World Map", systemImage: "globe")
                    }
                    .tag(1)

                // Systems
                SystemsView(gameEngine: gameEngine)
                    .tabItem {
                        Label("Systems", systemImage: "cpu")
                    }
                    .tag(2)

                // Advisors
                if let gameState = gameEngine.gameState {
                    AdvisorGridView(advisors: gameState.advisors)
                        .environmentObject(gameEngine)
                        .tabItem {
                            Label("Advisors", systemImage: "person.3.fill")
                        }
                        .tag(3)
                }

                // Intelligence
                IntelligenceView()
                    .environmentObject(gameEngine)
                    .tabItem {
                        Label("Intelligence", systemImage: "eye.fill")
                    }
                    .tag(4)
            }
            .frame(minWidth: 1400, minHeight: 900)
            .overlay(
                // Crisis Event Overlay
                Group {
                    if let crisis = gameEngine.crisisManager.activeCrisis,
                       let gameState = gameEngine.gameState {
                        DetailedCrisisView(
                            crisis: crisis,
                            gameState: gameState,
                            onResolve: { optionIndex in
                                var mutableState = gameState
                                gameEngine.crisisManager.resolveCrisis(optionIndex: optionIndex, gameState: &mutableState)
                                gameEngine.gameState = mutableState
                            },
                            crisisManager: gameEngine.crisisManager
                        )
                        .transition(.opacity)
                    }
                }
            )
            .sheet(isPresented: $gameEngine.showingVictoryScreen) {
                if let gameState = gameEngine.gameState,
                   let score = gameEngine.finalScore {
                    VictoryScreen(
                        gameState: gameState,
                        victoryType: gameEngine.victoryType,
                        score: score,
                        onNewGame: {
                            gameEngine.showingVictoryScreen = false
                            gameEngine.startNewGame()
                        },
                        onViewLeaderboard: {
                            // TODO: Show leaderboard
                        }
                    )
                }
            }
        }
    }
}

// MARK: - Intelligence View (New)

struct IntelligenceView: View {
    @EnvironmentObject var gameEngine: GameEngine

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let gameState = gameEngine.gameState {
                    // Header
                    Text("🔍 INTELLIGENCE BRIEFING")
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .foregroundColor(AppSettings.terminalGreen)
                        .padding()

                    // World Status
                    intelligenceCard(title: "GLOBAL STATUS") {
                        VStack(alignment: .leading, spacing: 10) {
                            statRow("Active Wars", value: "\(gameState.activeWars.count)")
                            statRow("Nuclear Powers", value: "\(gameState.countries.filter { $0.nuclearStatus != .none }.count)")
                            statRow("Total Warheads", value: "\(gameState.countries.reduce(0) { $0 + $1.nuclearWarheads })")
                            statRow("Global Radiation", value: "\(gameState.globalRadiation)")
                            statRow("Total Casualties", value: gameState.totalCasualties.formatted())
                            statRow("Treaties Active", value: "\(gameState.treaties.count)")
                        }
                    }

                    // Active Wars
                    if !gameState.activeWars.isEmpty {
                        intelligenceCard(title: "ACTIVE CONFLICTS") {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(gameState.activeWars) { war in
                                    warRow(war: war, gameState: gameState)
                                }
                            }
                        }
                    }

                    // Nuclear Powers
                    intelligenceCard(title: "NUCLEAR CAPABILITIES") {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(gameState.countries.filter { $0.nuclearWarheads > 0 }.sorted { $0.nuclearWarheads > $1.nuclearWarheads }) { country in
                                HStack {
                                    Text(country.flag)
                                        .font(.system(size: 24))
                                    Text(country.name)
                                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                        .foregroundColor(AppSettings.terminalGreen)
                                    Spacer()
                                    Text("☢️ \(country.nuclearWarheads)")
                                        .font(.system(size: 14, design: .monospaced))
                                        .foregroundColor(AppSettings.terminalRed)
                                }
                                .padding(.vertical, 5)
                            }
                        }
                    }

                    // Diplomatic Relations
                    if let player = gameState.getPlayerCountry() {
                        intelligenceCard(title: "DIPLOMATIC RELATIONS") {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(gameState.countries.filter { !$0.isPlayerControlled && !$0.isDestroyed }.sorted {
                                    (player.diplomaticRelations[$0.id] ?? 0) > (player.diplomaticRelations[$1.id] ?? 0)
                                }) { country in
                                    let relation = player.diplomaticRelations[country.id] ?? 0
                                    HStack {
                                        Text(country.flag)
                                            .font(.system(size: 20))
                                        Text(country.name)
                                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                            .foregroundColor(AppSettings.terminalGreen)
                                        Spacer()
                                        Text(relationshipText(relation))
                                            .font(.system(size: 12, design: .monospaced))
                                            .foregroundColor(relationshipColor(relation))
                                        Text("\(relation > 0 ? "+" : "")\(relation)")
                                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                                            .foregroundColor(relationshipColor(relation))
                                    }
                                    .padding(.vertical, 3)
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .background(AppSettings.terminalBackground)
    }

    private func intelligenceCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            Text(title)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(AppSettings.terminalAmber)

            content()
        }
        .padding()
        .background(Color.black.opacity(0.5))
        .border(AppSettings.terminalGreen, width: 2)
        .padding(.horizontal)
    }

    private func statRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label + ":")
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(AppSettings.terminalAmber)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(AppSettings.terminalGreen)
        }
    }

    private func warRow(war: War, gameState: GameState) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                if let aggressor = gameState.getCountry(id: war.aggressor),
                   let defender = gameState.getCountry(id: war.defender) {
                    Text("\(aggressor.flag) \(aggressor.name)")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(AppSettings.terminalRed)
                    Text("⚔️")
                    Text("\(defender.flag) \(defender.name)")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(AppSettings.terminalRed)
                }
            }
            Text("Intensity: \(String(repeating: "▮", count: war.intensity)) (\(war.intensity)/10)")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(AppSettings.terminalAmber)
            Text("Turn \(war.startTurn)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(AppSettings.terminalGreen)
        }
        .padding(.vertical, 5)
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
        case 50...: return AppSettings.terminalGreen
        case 0..<50: return .cyan
        case -50..<0: return AppSettings.terminalAmber
        default: return AppSettings.terminalRed
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(GameEngine())
}
