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
    @State private var selectedTab = MainTabView.launchTab

    /// `--tab N` (QA / screenshots) opens a game tab directly: 0 Situation Room, 5 Command, 1 Map, 2 Systems, 3 Advisors, 4 Intel.
    static var launchTab: Int {
        let args = CommandLine.arguments
        return args.firstIndex(of: "--tab").flatMap { args.indices.contains($0 + 1) ? Int(args[$0 + 1]) : nil } ?? 0
    }
    @State private var electionShown: Date?

    var body: some View {
        if gameEngine.gameState == nil {
            // Start screen
            ContentView()
                .environmentObject(gameEngine)
        } else {
            // Game tabs
            gameTabs
            // (The minimum window size is set once, at the app root, scaled with the text.)
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
                            gameEngine.showingVictoryScreen = false
                            gameEngine.showingLeaderboard = true
                        }
                    )
                    .interactiveDismissDisabled()  // Prevent accidental dismissal - must click button
                }
            }
            .sheet(isPresented: $gameEngine.showingLeaderboard) {
                LeaderboardView()
                    .environmentObject(gameEngine)
            }
            .sheet(item: Binding(
                get: { gameEngine.gameState?.shadow.lastElection.flatMap { $0.date == electionShown ? nil : $0 } },
                set: { if $0 == nil { electionShown = gameEngine.gameState?.shadow.lastElection?.date } })) { result in
                ElectionNightView(result: result)
            }
        }
    }

    /// The game tabs in display order: (tag, title, SF Symbol).
    static let tabs: [(tag: Int, title: String, icon: String)] = [
        (0, "Situation Room", "map.fill"), (5, "Command", "command.circle.fill"), (1, "World Map", "globe"),
        (2, "Systems", "cpu"), (3, "Advisors", "person.3.fill"), (4, "Intelligence", "eye.fill"),
    ]

    @ViewBuilder
    private func tabContent(_ tag: Int, _ gameState: GameState) -> some View {
        switch tag {
        // The Situation Room: map, advisors, dossier, escalation ladder, news (home screen)
        case 0: SituationRoomView(gameState: gameState).environmentObject(gameEngine)
        // Unified Command Center (Commands + Terminal + Event Log)
        case 5: UnifiedCommandCenter().environmentObject(gameEngine)
        case 1: SimpleModernWorldMap(gameState: gameState)
        case 2: SystemsView(gameEngine: gameEngine)
        case 3: AdvisorGridView(advisors: gameState.advisors).environmentObject(gameEngine)
        default: IntelligenceView().environmentObject(gameEngine)
        }
    }

    @ViewBuilder
    private var gameTabs: some View {
        if let gameState = gameEngine.gameState {
            #if os(macOS)
            // macOS draws TabView's strip natively at a fixed size; this bar uses the scaled fonts instead.
            VStack(spacing: 0) {
                GameTabBar(selection: $selectedTab)
                tabContent(selectedTab, gameState)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            #else
            TabView(selection: $selectedTab) {
                ForEach(Self.tabs, id: \.tag) { tab in
                    tabContent(tab.tag, gameState)
                        .tabItem { Label(tab.title, systemImage: tab.icon) }
                        .tag(tab.tag)
                }
            }
            #endif
        }
    }
}

#if os(macOS)
/// The macOS game tab bar: one themed button per tab, text scaled with `FontScale`.
struct GameTabBar: View {
    @Binding var selection: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(MainTabView.tabs, id: \.tag) { tab in
                let on = tab.tag == selection
                Button { selection = tab.tag } label: {
                    Label(tab.title, systemImage: tab.icon)
                        .font(ThemeFont.mono(11, on ? .bold : .regular))
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .foregroundColor(on ? (Theme.isRetro ? .black : .white) : (Theme.isRetro ? EGA.lightGray : .secondary))
                        .background(
                            RoundedRectangle(cornerRadius: Theme.isRetro ? 0 : 6)
                                .fill(on ? (Theme.isRetro ? EGA.lightGray : Color.accentColor.opacity(0.8)) : Color.clear)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(4)
        .frame(maxWidth: .infinity)
        .background(Theme.isRetro ? EGA.blue : Color.black.opacity(0.35))
    }
}
#endif

// MARK: - Intelligence View (New)

struct IntelligenceView: View {
    @EnvironmentObject var gameEngine: GameEngine

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let gameState = gameEngine.gameState {
                    // Header
                    Text("🔍 INTELLIGENCE BRIEFING")
                        .font(.scaled(size: 32, weight: .bold, design: .monospaced))
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
                                        .font(.scaled(size: 24))
                                    Text(country.name)
                                        .font(.scaled(size: 14, weight: .semibold, design: .monospaced))
                                        .foregroundColor(AppSettings.terminalGreen)
                                    Spacer()
                                    Text("☢️ \(country.nuclearWarheads)")
                                        .font(.scaled(size: 14, design: .monospaced))
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
                                            .font(.scaled(size: 20))
                                        Text(country.name)
                                            .font(.scaled(size: 12, weight: .semibold, design: .monospaced))
                                            .foregroundColor(AppSettings.terminalGreen)
                                        Spacer()
                                        Text(relationshipText(relation))
                                            .font(.scaled(size: 12, design: .monospaced))
                                            .foregroundColor(relationshipColor(relation))
                                        Text("\(relation > 0 ? "+" : "")\(relation)")
                                            .font(.scaled(size: 12, weight: .bold, design: .monospaced))
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
                .font(.scaled(size: 18, weight: .bold, design: .monospaced))
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
                .font(.scaled(size: 14, design: .monospaced))
                .foregroundColor(AppSettings.terminalAmber)
            Spacer()
            Text(value)
                .font(.scaled(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(AppSettings.terminalGreen)
        }
    }

    private func warRow(war: War, gameState: GameState) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                if let aggressor = gameState.getCountry(id: war.aggressor),
                   let defender = gameState.getCountry(id: war.defender) {
                    Text("\(aggressor.flag) \(aggressor.name)")
                        .font(.scaled(size: 14, design: .monospaced))
                        .foregroundColor(AppSettings.terminalRed)
                    Text("⚔️")
                    Text("\(defender.flag) \(defender.name)")
                        .font(.scaled(size: 14, design: .monospaced))
                        .foregroundColor(AppSettings.terminalRed)
                }
            }
            Text("Intensity: \(String(repeating: "▮", count: war.intensity)) (\(war.intensity)/10)")
                .font(.scaled(size: 12, design: .monospaced))
                .foregroundColor(AppSettings.terminalAmber)
            Text("Since \(gameState.dateLabel(forTurn: war.startTurn))")
                .font(.scaled(size: 10, design: .monospaced))
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
