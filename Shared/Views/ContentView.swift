//
//  ContentView.swift
//  Global Thermal Nuclear War
//
//  Main game interface inspired by WOPR terminal from WarGames
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var gameEngine: GameEngine
    @State private var showingCountrySelection = false
    @State private var showingDifficultySelection = false
    @State private var showingAdministrationSelection = false
    @State private var selectedDifficulty: DifficultyLevel = .normal
    @State private var selectedAdministration: Administration? = nil

    var body: some View {
        ZStack {
            // Glassmorphic background
            GlassmorphicBackground()

            Group {
                if gameEngine.gameState == nil {
                    startScreen
                } else {
                    gameScreen
                }
            }
        }
        .foregroundColor(ModernColors.textPrimary)
    }

    // MARK: - Start Screen

    private var startScreen: some View {
        VStack(spacing: 30) {
            Spacer()

            // Title (WOPR style)
            VStack(spacing: 10) {
                Text("W.O.P.R")
                    .font(.system(size: 60, weight: .bold, design: .monospaced))
                    .foregroundColor(ModernColors.cyan)
                    .shadow(color: ModernColors.cyan.opacity(0.5), radius: 20)

                Text("War Operation Plan Response")
                    .font(.system(size: 18, design: .monospaced))
                    .foregroundColor(ModernColors.yellow)

                Text("GLOBAL THERMAL NUCLEAR WAR")
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundColor(ModernColors.statusCritical)
                    .shadow(color: ModernColors.statusCritical.opacity(0.5), radius: 10)
                    .padding(.top, 10)
            }

            Spacer()

            // Quote from the movie
            VStack(spacing: 5) {
                Text("\"Shall we play a game?\"")
                    .font(.system(size: 20, design: .monospaced))
                    .italic()
                    .foregroundColor(ModernColors.cyan)

                Text("- WOPR, 1983")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(ModernColors.yellow)
            }
            .padding(.bottom, 30)

            // Difficulty selection
            VStack(spacing: 15) {
                Text("SELECT DIFFICULTY")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(ModernColors.yellow)

                ForEach(DifficultyLevel.allCases, id: \.self) { difficulty in
                    Button(action: {
                        selectedDifficulty = difficulty
                    }) {
                        HStack {
                            Image(systemName: selectedDifficulty == difficulty ? "checkmark.circle.fill" : "circle")
                            Text(difficulty.rawValue.uppercased())
                                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                        }
                        .foregroundColor(selectedDifficulty == difficulty ? ModernColors.yellow : ModernColors.cyan)
                        .padding()
                        .frame(maxWidth: 300)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedDifficulty == difficulty ? ModernColors.cyan.opacity(0.15) : Color.white.opacity(0.05))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(ModernColors.cyan, lineWidth: 1)
                        )
                    }
                }
            }
            .padding(.bottom, 20)

            // Administration selection
            VStack(spacing: 15) {
                Text("SELECT ADMINISTRATION")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(ModernColors.yellow)

                Button(action: {
                    showingAdministrationSelection = true
                }) {
                    HStack {
                        Image(systemName: "person.3.fill")
                        Text(selectedAdministration?.description ?? "Trump 2025 (Default)")
                            .font(.system(size: 14, design: .monospaced))
                    }
                    .foregroundColor(ModernColors.cyan)
                    .padding()
                    .frame(maxWidth: 300)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.05))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(ModernColors.cyan, lineWidth: 1)
                    )
                }
            }
            .padding(.bottom, 20)

            // Start button - Always start as USA
            Button(action: {
                gameEngine.startNewGame(
                    playerCountryID: "USA",
                    difficulty: selectedDifficulty,
                    administration: selectedAdministration
                )
            }) {
                Text("INITIALIZE GAME (AS USA)")
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundColor(.black)
                    .padding()
                    .frame(maxWidth: 300)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(ModernColors.cyan)
                    )
                    .shadow(color: ModernColors.cyan.opacity(0.5), radius: 10)
            }

            Spacer()

            // Warning
            Text("⚠️  WARNING: THE ONLY WINNING MOVE IS NOT TO PLAY  ⚠️")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(ModernColors.statusCritical)
                .padding()
        }
        .padding()
        .sheet(isPresented: $showingAdministrationSelection) {
            AdministrationSelectionView(selectedAdministration: $selectedAdministration)
        }
    }

    // MARK: - Game Screen

    private var gameScreen: some View {
        // Use simplified command view
        CommandView()
            .environmentObject(gameEngine)
    }

    // MARK: - macOS Layout

    #if os(macOS)
    private var macOSGameScreen: some View {
        HSplitView {
            // Left panel - World status
            leftPanel
                .frame(minWidth: 300, maxWidth: 400)

            // Center - World map
            centerPanel
                .frame(minWidth: 500)

            // Right panel - Game log
            rightPanel
                .frame(minWidth: 300, maxWidth: 400)
        }
        .frame(minWidth: 1200, minHeight: 800)
    }
    #endif

    // MARK: - iOS Layout

    #if os(iOS)
    private var iOSGameScreen: some View {
        TabView {
            // World Map tab
            NavigationView {
                centerPanel
                    .navigationTitle("World Map")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem {
                Label("Map", systemImage: "globe")
            }

            // Status tab
            NavigationView {
                leftPanel
                    .navigationTitle("Status")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem {
                Label("Status", systemImage: "info.circle")
            }

            // Advisors tab
            NavigationView {
                AdvisorGridView(advisors: gameEngine.advisors)
                    .navigationTitle("Advisors")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem {
                Label("Advisors", systemImage: "person.3.fill")
            }

            // Log tab
            NavigationView {
                rightPanel
                    .navigationTitle("Events")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem {
                Label("Events", systemImage: "text.bubble")
            }
        }
    }
    #endif

    // MARK: - tvOS Layout

    #if os(tvOS)
    private var tvOSGameScreen: some View {
        HStack(spacing: 0) {
            // Left panel
            leftPanel
                .frame(width: 500)

            // Center panel
            VStack {
                centerPanel
                rightPanel
                    .frame(height: 300)
            }
        }
    }
    #endif

    // MARK: - Panels

    private var leftPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let gameState = gameEngine.gameState {
                    // DEFCON Level
                    defconDisplay(gameState.defconLevel)

                    Divider().background(ModernColors.cyan)

                    // Player info
                    if let playerCountry = gameState.getPlayerCountry() {
                        playerInfoSection(playerCountry)
                    }

                    Divider().background(ModernColors.cyan)

                    // Nuclear powers
                    nuclearPowersSection(gameState.countries)

                    Divider().background(ModernColors.cyan)

                    // Global stats
                    globalStatsSection(gameState)

                    // Actions
                    Divider().background(ModernColors.cyan)
                    actionButtons
                }
            }
            .padding()
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .background(.ultraThinMaterial.opacity(0.8))
        )
        .padding(8)
    }

    private var centerPanel: some View {
        VStack {
            if let gameState = gameEngine.gameState {
                WorldMapView(gameState: gameState)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .background(.ultraThinMaterial.opacity(0.8))
        )
        .padding(8)
    }

    private var rightPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SYSTEM LOG")
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(ModernColors.yellow)
                .padding(.bottom, 5)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 5) {
                    ForEach(gameEngine.logMessages) { log in
                        logMessageView(log)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .background(.ultraThinMaterial.opacity(0.8))
        )
        .padding(8)
    }

    // MARK: - Components

    private func defconDisplay(_ defcon: DefconLevel) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("DEFCON LEVEL")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(ModernColors.yellow)

            Text("\(defcon.rawValue)")
                .font(.system(size: 60, weight: .bold, design: .monospaced))
                .foregroundColor(defconColor(defcon))
                .shadow(color: defconColor(defcon).opacity(0.5), radius: 15)

            Text(defcon.description)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(defconColor(defcon))
        }
    }

    private func defconColor(_ defcon: DefconLevel) -> Color {
        switch defcon.rawValue {
        case 5: return ModernColors.statusLow
        case 4: return ModernColors.statusMedium
        case 3: return ModernColors.statusHigh
        case 2: return ModernColors.orange
        case 1: return ModernColors.statusCritical
        default: return ModernColors.statusLow
        }
    }

    private func playerInfoSection(_ country: Country) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("YOUR NATION")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(ModernColors.yellow)

            HStack {
                Text(country.flag)
                    .font(.system(size: 40))
                Text(country.name)
                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
            }

            VStack(alignment: .leading, spacing: 5) {
                statRow("Nuclear Warheads:", "\(country.nuclearWarheads)")
                statRow("ICBMs:", "\(country.icbmCount)")
                statRow("SLBMs:", "\(country.submarineLaunchedMissiles)")
                statRow("Bombers:", "\(country.bombers)")
                statRow("Damage:", "\(country.damageLevel)%")
                statRow("Radiation:", "\(country.radiationLevel)")
            }
        }
    }

    private func nuclearPowersSection(_ countries: [Country]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("NUCLEAR POWERS")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(ModernColors.yellow)

            ForEach(countries.filter { $0.nuclearWarheads > 0 && !$0.isDestroyed }.sorted(by: { $0.nuclearWarheads > $1.nuclearWarheads })) { country in
                HStack {
                    Text(country.flag)
                    Text(country.code)
                        .font(.system(size: 12, design: .monospaced))
                    Spacer()
                    Text("\(country.nuclearWarheads)")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(country.isPlayerControlled ? ModernColors.yellow : ModernColors.cyan)
                }
            }
        }
    }

    private func globalStatsSection(_ gameState: GameState) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("GLOBAL STATUS")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(ModernColors.yellow)

            statRow("Turn:", "\(gameState.turn)")
            statRow("Active Wars:", "\(gameState.activeWars.count)")
            statRow("Nuclear Strikes:", "\(gameState.nuclearStrikes.count)")
            statRow("Total Casualties:", gameState.totalCasualties.formatted())
            statRow("Global Radiation:", "\(gameState.globalRadiation)")
            statRow("Destroyed Nations:", "\(gameState.countries.filter { $0.isDestroyed }.count)")
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            Button(action: {
                gameEngine.endTurn()
            }) {
                Text("END TURN")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(ModernColors.cyan)
                    )
                    .shadow(color: ModernColors.cyan.opacity(0.5), radius: 8)
            }

            Button(action: {
                gameEngine.startNewGame()
            }) {
                Text("NEW GAME")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(ModernColors.cyan)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.05))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(ModernColors.cyan, lineWidth: 1)
                    )
            }
        }
    }

    private func statRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(ModernColors.yellow)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(ModernColors.cyan)
        }
    }

    private func logMessageView(_ log: LogMessage) -> some View {
        HStack(alignment: .top, spacing: 5) {
            Text(logIcon(for: log.type))
                .font(.system(size: 10))

            Text(log.message)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(logColor(for: log.type))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func logIcon(for type: LogType) -> String {
        switch type {
        case .system: return ">"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        case .critical: return "☢️"
        }
    }

    private func logColor(for type: LogType) -> Color {
        switch type {
        case .system: return ModernColors.cyan
        case .info: return ModernColors.cyan
        case .warning: return ModernColors.yellow
        case .error: return ModernColors.statusCritical
        case .critical: return ModernColors.statusCritical
        }
    }
}

// MARK: - Country Selection View

struct CountrySelectionView: View {
    @EnvironmentObject var gameEngine: GameEngine
    @Environment(\.dismiss) var dismiss
    let selectedDifficulty: DifficultyLevel
    let selectedAdministration: Administration?

    @State private var selectedCountry: String = "USA"
    @State private var searchText = ""

    private let allCountries = CountryFactory.createAllCountries()

    private var filteredCountries: [Country] {
        if searchText.isEmpty {
            return allCountries
        } else {
            return allCountries.filter { $0.name.localizedCaseInsensitiveContains(searchText) || $0.code.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var body: some View {
        ZStack {
            // Glassmorphic background
            GlassmorphicBackground()

            VStack {
                Text("SELECT YOUR NATION")
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundColor(ModernColors.cyan)
                    .padding()

                #if !os(tvOS)
                TextField("Search countries...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                #endif

                List(filteredCountries) { country in
                    Button(action: {
                        selectedCountry = country.id
                    }) {
                        HStack {
                            Text(country.flag)
                                .font(.system(size: 30))

                            VStack(alignment: .leading) {
                                Text(country.name)
                                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                    .foregroundColor(ModernColors.textPrimary)
                                Text("\(country.nuclearStatus.rawValue) • \(country.government.rawValue)")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(ModernColors.textSecondary)
                            }

                            Spacer()

                            if country.id == selectedCountry {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(ModernColors.cyan)
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)

                Button(action: {
                    gameEngine.startNewGame(playerCountryID: selectedCountry, difficulty: selectedDifficulty, administration: selectedAdministration)
                    dismiss()
                }) {
                    Text("START GAME")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(.black)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(ModernColors.cyan)
                        )
                        .shadow(color: ModernColors.cyan.opacity(0.5), radius: 10)
                }
                .padding()
            }
        }
    }
}
