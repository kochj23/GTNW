//
//  CommandView.swift
//  Global Thermal Nuclear War
//
//  Simplified command interface - actions first, no scrolling
//

import SwiftUI

/// Simplified command-focused interface
struct CommandView: View {
    @EnvironmentObject var gameEngine: GameEngine
    @State private var selectedTarget: String?
    @State private var selectedAlly: String?
    @State private var warheadCount: Int = 1
    @State private var showingCountryPicker = false
    @State private var showingCovertOpsMenu = false
    @State private var showingSDIMenu = false
    @State private var showingCyberWarfareMenu = false
    @State private var showingWeaponsMenu = false
    @State private var showingSystemsView = false
    @State private var showingStatsPanel = true
    @State private var nlCommandText = ""
    @State private var nlCommandResponse = ""
    @State private var pickerMode: PickerMode = .target

    enum PickerMode {
        case target, ally
    }

    var body: some View {
        Text("CommandView (not used)")
            .foregroundColor(.white)
    }

    // MARK: - Status Bar

    private func statusBar(gameState: GameState) -> some View {
        HStack {
            // DEFCON
            HStack(spacing: 8) {
                Text("DEFCON")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(AppSettings.terminalAmber)

                Text("\(gameState.defconLevel.rawValue)")
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .foregroundColor(gameState.defconLevel.color)
            }
            .padding()
            .background(Color.black)
            .border(gameState.defconLevel.color, width: 2)

            Spacer()

            // Player info
            if let player = gameState.getPlayerCountry() {
                HStack(spacing: 15) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(player.flag + " " + player.name)
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(AppSettings.terminalGreen)
                        Text("☢️ \(player.nuclearWarheads) warheads")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(AppSettings.terminalAmber)
                    }

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Turn \(gameState.turn)")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(AppSettings.terminalAmber)
                        Text("Wars: \(gameState.activeWars.count)")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(gameState.activeWars.count > 0 ? AppSettings.terminalRed : AppSettings.terminalGreen)
                    }
                }
                .padding()
                .background(Color.black)
                .border(AppSettings.terminalGreen, width: 1)
            }
        }
        .padding()
        .background(Color.black)
        .border(AppSettings.terminalGreen, width: 2)
    }

    // MARK: - AI Stats Panel

    private var aiStatsPanel: some View {
        VStack(spacing: 0) {
            // Header with toggle
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.cyan)
                    .font(.system(size: 18))
                Text("📊 AI STATS")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan)

                Spacer()

                // AI Backend status
                HStack(spacing: 6) {
                    Circle()
                        .fill(gameEngine.aiBackend.activeBackend != nil ? Color.green : Color.gray)
                        .frame(width: 8, height: 8)
                    Text(gameEngine.aiBackend.activeBackend?.rawValue.uppercased() ?? "LOCAL")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(gameEngine.aiBackend.activeBackend != nil ? AppSettings.terminalGreen : AppSettings.terminalAmber)
                }

                Button(action: {
                    withAnimation {
                        showingStatsPanel.toggle()
                    }
                }) {
                    Image(systemName: showingStatsPanel ? "chevron.up" : "chevron.down")
                        .foregroundColor(AppSettings.terminalAmber)
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.cyan.opacity(0.3), Color.blue.opacity(0.2)]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .border(Color.cyan, width: 4)
            .shadow(color: Color.cyan.opacity(0.5), radius: 10)

            if showingStatsPanel {
                // Metrics content
                HStack(spacing: 20) {
                    // Current tokens/sec (large display)
                    VStack(spacing: 6) {
                        Text("CURRENT")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(AppSettings.terminalAmber)

                        Text(String(format: "%.1f", gameEngine.ollamaService.tokensPerSecond))
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(.cyan)

                        Text("tok/sec")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(AppSettings.terminalAmber.opacity(0.7))
                    }
                    .frame(minWidth: 100)
                    .padding()
                    .background(Color.cyan.opacity(0.1))
                    .border(Color.cyan, width: 2)

                    VStack(spacing: 12) {
                        // Average tokens/sec
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("AVERAGE")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(AppSettings.terminalAmber)
                                Text(String(format: "%.1f t/s", gameEngine.ollamaService.averageTokensPerSecond))
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundColor(AppSettings.terminalGreen)
                            }
                            .padding(8)
                            .background(AppSettings.terminalGreen.opacity(0.1))
                            .border(AppSettings.terminalGreen, width: 1)

                            Spacer()

                            // Peak tokens/sec
                            VStack(alignment: .leading, spacing: 4) {
                                Text("PEAK")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(AppSettings.terminalAmber)
                                Text(String(format: "%.1f t/s", gameEngine.ollamaService.peakTokensPerSecond))
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundColor(AppSettings.terminalRed)
                            }
                            .padding(8)
                            .background(AppSettings.terminalRed.opacity(0.1))
                            .border(AppSettings.terminalRed, width: 1)
                        }

                        // Total tokens and requests
                        HStack(spacing: 12) {
                            statBox(label: "TOTAL TOKENS", value: "\(gameEngine.ollamaService.totalTokens)", color: .purple)
                            statBox(label: "REQUESTS", value: "\(gameEngine.ollamaService.totalRequests)", color: .orange)

                            // Processing indicator
                            if gameEngine.ollamaService.isGenerating {
                                HStack(spacing: 6) {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .cyan))
                                        .scaleEffect(0.7)
                                    Text("PROCESSING")
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .foregroundColor(.cyan)
                                }
                                .padding(8)
                                .background(Color.cyan.opacity(0.1))
                                .border(Color.cyan, width: 1)
                            }
                        }
                    }

                    Spacer()
                }
                .padding(12)
                .background(Color.black.opacity(0.5))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private func statBox(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(AppSettings.terminalAmber.opacity(0.7))
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(color)
        }
        .padding(8)
        .background(color.opacity(0.1))
        .border(color, width: 1)
    }

    // MARK: - Command Panel

    private func commandPanel(gameState: GameState) -> some View {
        VStack(spacing: 15) {
            Text("COMMAND CONSOLE")
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundColor(AppSettings.terminalAmber)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Target selection
            HStack {
                Text("TARGET:")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(AppSettings.terminalAmber)
                    .frame(width: 100, alignment: .leading)

                Button(action: {
                    pickerMode = .target
                    showingCountryPicker = true
                }) {
                    HStack {
                        if let targetID = selectedTarget,
                           let target = gameState.getCountry(id: targetID) {
                            Text("\(target.flag) \(target.name)")
                        } else {
                            Text("SELECT TARGET")
                        }
                    }
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(AppSettings.terminalGreen)
                    .frame(maxWidth: .infinity)
                    .padding(10)
                    .background(Color.black)
                    .border(AppSettings.terminalGreen, width: 2)
                }
            }

            Divider().background(AppSettings.terminalGreen)

            // NEW FEATURES: Natural Language & Feature Access
            VStack(spacing: 10) {
                // Natural Language Command Input
                HStack(spacing: 8) {
                    TextField("Type command: 'attack Russia', 'build military'", text: $nlCommandText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(AppSettings.terminalGreen)
                        .padding(10)
                        .background(Color.black)
                        .border(Color.cyan, width: 2)
                        .onSubmit {
                            processNLCommand()
                        }

                    Button(action: processNLCommand) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.cyan)
                    }
                    .disabled(nlCommandText.isEmpty)
                    .buttonStyle(.plain)
                }

                if !nlCommandResponse.isEmpty {
                    Text(nlCommandResponse)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(AppSettings.terminalGreen)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.black.opacity(0.5))
                        .border(Color.cyan, width: 1)
                }

                // Feature status badges
                HStack(spacing: 8) {
                    featureBadge(
                        icon: "envelope.fill",
                        label: "MESSAGES",
                        count: gameEngine.diplomacyService.messages.count,
                        color: .purple
                    )

                    featureBadge(
                        icon: "binoculars.fill",
                        label: "INTEL OPS",
                        count: gameEngine.intelService.activeOperations.count,
                        color: .cyan
                    )

                    featureBadge(
                        icon: "key.fill",
                        label: "SPY POINTS",
                        count: gameEngine.intelService.spyPoints,
                        color: .orange
                    )
                }
            }
            .padding(.vertical, 8)

            Divider().background(AppSettings.terminalGreen)

            // Actions Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                // Nuclear Strike
                actionButton(
                    title: "☢️ NUCLEAR\nSTRIKE",
                    color: AppSettings.terminalRed,
                    enabled: selectedTarget != nil && (gameState.getPlayerCountry()?.nuclearWarheads ?? 0) > 0
                ) {
                    if let target = selectedTarget, let player = gameState.getPlayerCountry() {
                        gameEngine.launchNuclearStrike(from: player.id, to: target, warheads: min(warheadCount, player.nuclearWarheads))
                    }
                }

                // Declare War
                actionButton(
                    title: "⚔️ DECLARE\nWAR",
                    color: AppSettings.terminalAmber,
                    enabled: selectedTarget != nil
                ) {
                    if let target = selectedTarget, let player = gameState.getPlayerCountry() {
                        gameEngine.declareWar(aggressor: player.id, defender: target)
                    }
                }

                // Form Alliance
                actionButton(
                    title: "🤝 FORM\nALLIANCE",
                    color: AppSettings.terminalGreen,
                    enabled: selectedTarget != nil
                ) {
                    if let target = selectedTarget, let player = gameState.getPlayerCountry() {
                        gameEngine.formAlliance(country1: player.id, country2: target)
                    }
                }

                // Economic Diplomacy
                actionButton(
                    title: "💰 ECONOMIC\nDIPLOMACY",
                    color: AppSettings.terminalGreen,
                    enabled: selectedTarget != nil
                ) {
                    if let target = selectedTarget, let player = gameState.getPlayerCountry() {
                        // $5 billion = Turn enemy into ally
                        gameEngine.economicDiplomacy(from: player.id, to: target, amount: 5_000_000_000)
                    }
                }

                // Covert Operations
                actionButton(
                    title: "🕵️ COVERT\nOPS",
                    color: AppSettings.terminalAmber,
                    enabled: selectedTarget != nil
                ) {
                    showingCovertOpsMenu = true
                }

                // Cyber Warfare
                actionButton(
                    title: "🖥️ CYBER\nWARFARE",
                    color: AppSettings.terminalAmber,
                    enabled: selectedTarget != nil
                ) {
                    showingCyberWarfareMenu = true
                }

                // SDI Defense
                actionButton(
                    title: "🛰️ SDI\nDEFENSE",
                    color: AppSettings.terminalGreen,
                    enabled: true
                ) {
                    showingSDIMenu = true
                }

                // Prohibited Weapons
                actionButton(
                    title: "🚀 SALT\nVIOLATIONS",
                    color: AppSettings.terminalRed,
                    enabled: true
                ) {
                    showingWeaponsMenu = true
                }

                // All Systems
                actionButton(
                    title: "🎮 ALL\nSYSTEMS",
                    color: .cyan,
                    enabled: true
                ) {
                    showingSystemsView = true
                }

                // End Turn
                actionButton(
                    title: "⏭️ END\nTURN",
                    color: AppSettings.terminalGreen,
                    enabled: true
                ) {
                    gameEngine.endTurn()
                }
            }

            Divider().background(AppSettings.terminalGreen)

            // Quick stats
            HStack {
                Spacer()
                statPill("Nuclear Strikes: \(gameState.nuclearStrikes.count)", color: gameState.nuclearStrikes.count > 0 ? AppSettings.terminalRed : AppSettings.terminalGreen)
                Spacer()
                statPill("Casualties: \(gameState.totalCasualties.formatted())", color: gameState.totalCasualties > 0 ? AppSettings.terminalRed : AppSettings.terminalGreen)
                Spacer()
                statPill("Radiation: \(gameState.globalRadiation)", color: gameState.globalRadiation > 100 ? AppSettings.terminalRed : AppSettings.terminalGreen)
                Spacer()
            }
        }
        .padding()
        .background(Color.black.opacity(0.7))
        .border(AppSettings.terminalGreen, width: 2)
        .padding()
        .sheet(isPresented: $showingCountryPicker) {
            CountryPickerView(gameState: gameState, selectedCountry: $selectedTarget)
        }
        .sheet(isPresented: $showingCovertOpsMenu) {
            if let target = selectedTarget, let gameState = gameEngine.gameState {
                CovertOperationsMenu(gameEngine: gameEngine, playerID: gameState.playerCountryID, targetID: target)
            }
        }
        .sheet(isPresented: $showingSDIMenu) {
            if let gameState = gameEngine.gameState {
                SDIDeploymentMenu(gameEngine: gameEngine, playerID: gameState.playerCountryID)
            }
        }
        .sheet(isPresented: $showingCyberWarfareMenu) {
            if let target = selectedTarget, let gameState = gameEngine.gameState {
                CyberWarfareMenu(gameEngine: gameEngine, playerID: gameState.playerCountryID, targetID: target)
            }
        }
        .sheet(isPresented: $showingWeaponsMenu) {
            if let gameState = gameEngine.gameState {
                ProhibitedWeaponsMenu(gameEngine: gameEngine, playerID: gameState.playerCountryID)
            }
        }
        .sheet(isPresented: $showingSystemsView) {
            SystemsView(gameEngine: gameEngine)
                .frame(minWidth: 800, minHeight: 600)
        }
    }

    // MARK: - Log Section

    private var logSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("SYSTEM LOG")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(AppSettings.terminalAmber)
                .padding(.horizontal)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 3) {
                    ForEach(gameEngine.logMessages.suffix(50)) { log in
                        Text(log.message)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(logColor(for: log.type))
                            .padding(.horizontal)
                    }
                }
            }
            .frame(maxHeight: 200)
        }
        .padding(.vertical)
        .background(Color.black)
        .border(AppSettings.terminalGreen, width: 1)
    }

    // MARK: - Helper Components

    private func processNLCommand() {
        guard let gameState = gameEngine.gameState else { return }

        if let parsed = gameEngine.nlpProcessor.parseCommand(nlCommandText, gameState: gameState) {
            nlCommandResponse = "✓ Parsed: \(parsed.reason)"

            // Execute command
            if let player = gameState.getPlayerCountry() {
                switch parsed.action {
                case "ATTACK":
                    if let target = parsed.target {
                        print("[NL Command] Executing ATTACK on \(target)")
                        gameEngine.declareWar(aggressor: player.id, defender: target)
                        print("[NL Command] Calling endTurn()")
                        gameEngine.endTurn()
                        print("[NL Command] endTurn() completed")
                    }
                case "NUKE":
                    if let target = parsed.target {
                        print("[NL Command] Executing NUKE on \(target)")
                        gameEngine.launchNuclearStrike(from: player.id, to: target, warheads: 1)
                        print("[NL Command] Calling endTurn()")
                        gameEngine.endTurn()
                        print("[NL Command] endTurn() completed")
                    }
                case "ALLY":
                    if let target = parsed.target {
                        print("[NL Command] Executing ALLY with \(target)")
                        gameEngine.formAlliance(country1: player.id, country2: target)
                        print("[NL Command] Calling endTurn()")
                        gameEngine.endTurn()
                        print("[NL Command] endTurn() completed")
                    }
                case "BUILD_MILITARY", "BUILD_NUKES":
                    nlCommandResponse += "\n(Build actions happen automatically each turn)"
                    print("[NL Command] Calling endTurn()")
                    gameEngine.endTurn()
                    print("[NL Command] endTurn() completed")
                default:
                    break
                }
            }

            nlCommandText = ""
        } else {
            nlCommandResponse = "❌ Not understood. Try:\n  'attack Russia'\n  'nuke China'\n  'ally France'\n  'build military'"
        }
    }

    private func featureBadge(icon: String, label: String, count: Int, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text("\(label): \(count)")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
        }
        .foregroundColor(count > 0 ? color : AppSettings.terminalAmber.opacity(0.5))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(count > 0 ? color.opacity(0.1) : Color.clear)
        .border(count > 0 ? color : AppSettings.terminalAmber.opacity(0.3), width: 1)
    }

    private func actionButton(title: String, color: Color, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(enabled ? Color.black : color.opacity(0.3))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 80)
                .background(enabled ? color : Color.black)
                .border(color, width: 2)
        }
        .disabled(!enabled)
    }

    private func statPill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 11, design: .monospaced))
            .foregroundColor(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.black)
            .border(color, width: 1)
    }

    private func logColor(for type: LogType) -> Color {
        switch type {
        case .system: return AppSettings.terminalGreen
        case .info: return AppSettings.terminalGreen
        case .warning: return AppSettings.terminalAmber
        case .error: return AppSettings.terminalRed
        case .critical: return AppSettings.terminalRed
        }
    }
}

// MARK: - Country Picker

struct CountryPickerView: View {
    let gameState: GameState
    @Binding var selectedCountry: String?
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""

    private var filteredCountries: [Country] {
        let countries = gameState.countries.filter { !$0.isDestroyed && !$0.isPlayerControlled }
        if searchText.isEmpty {
            return countries.sorted { $0.name < $1.name }
        }
        return countries.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.code.localizedCaseInsensitiveContains(searchText)
        }.sorted { $0.name < $1.name }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("🎯 SELECT TARGET NATION")
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundColor(AppSettings.terminalGreen)

                Spacer()

                Button("CANCEL") {
                    dismiss()
                }
                .foregroundColor(AppSettings.terminalRed)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
            }
            .padding()
            .background(Color.black)
            .border(AppSettings.terminalGreen, width: 2)

            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(AppSettings.terminalAmber)
                TextField("Search nations...", text: $searchText)
                    .textFieldStyle(.plain)
                    .foregroundColor(AppSettings.terminalGreen)
                    .font(.system(size: 14, design: .monospaced))
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppSettings.terminalAmber)
                    }
                }
            }
            .padding()
            .background(Color.black.opacity(0.5))
            .border(AppSettings.terminalAmber, width: 1)
            .padding()

            // Country count
            Text("\(filteredCountries.count) nations available")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(AppSettings.terminalAmber)
                .padding(.bottom, 10)

            // Countries List
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(filteredCountries) { country in
                        Button(action: {
                            selectedCountry = country.id
                            dismiss()
                        }) {
                            HStack(spacing: 15) {
                                Text(country.flag)
                                    .font(.system(size: 32))

                                VStack(alignment: .leading, spacing: 5) {
                                    Text(country.name)
                                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                                        .foregroundColor(AppSettings.terminalGreen)

                                    HStack(spacing: 10) {
                                        Text("☢️ \(country.nuclearWarheads)")
                                            .font(.system(size: 12, design: .monospaced))
                                            .foregroundColor(country.nuclearWarheads > 0 ? AppSettings.terminalRed : AppSettings.terminalAmber)

                                        Text("•")
                                            .foregroundColor(AppSettings.terminalAmber)

                                        Text(country.alignment.rawValue)
                                            .font(.system(size: 12, design: .monospaced))
                                            .foregroundColor(AppSettings.terminalAmber)

                                        Text("•")
                                            .foregroundColor(AppSettings.terminalAmber)

                                        Text("Pop: \(country.population.formatted(.number.notation(.compactName)))")
                                            .font(.system(size: 12, design: .monospaced))
                                            .foregroundColor(AppSettings.terminalAmber)
                                    }
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .foregroundColor(AppSettings.terminalGreen)
                            }
                            .padding()
                            .background(Color.black.opacity(0.3))
                            .border(AppSettings.terminalGreen, width: 1)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
        }
        .background(AppSettings.terminalBackground)
        .frame(minWidth: 600, minHeight: 700)
    }
}

// MARK: - Covert Operations Menu

struct CovertOperationsMenu: View {
    @ObservedObject var gameEngine: GameEngine
    let playerID: String
    let targetID: String
    @Environment(\.dismiss) var dismiss

    var targetName: String {
        gameEngine.gameState?.getCountry(id: targetID)?.name ?? "Unknown"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("🕵️ COVERT OPERATIONS")
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundColor(AppSettings.terminalGreen)

                Spacer()

                Button("CANCEL") {
                    dismiss()
                }
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(AppSettings.terminalRed)
            }
            .padding()
            .background(Color.black)
            .border(AppSettings.terminalGreen, width: 2)

            Text("TARGET: \(targetName)")
                .font(.system(size: 16, design: .monospaced))
                .foregroundColor(AppSettings.terminalAmber)
                .padding()

            Divider().background(AppSettings.terminalGreen)

            ScrollView {
                VStack(spacing: 20) {
                    // Sabotage
                    covertOpButton(
                        title: "💣 SABOTAGE",
                        subtitle: "Destroy military infrastructure",
                        effect: "-20 military strength, -15 economic",
                        color: AppSettings.terminalRed
                    ) {
                        gameEngine.covertSabotage(from: playerID, to: targetID)
                        dismiss()
                    }

                    // Cyber Warfare
                    covertOpButton(
                        title: "📡 CYBER WARFARE",
                        subtitle: "Hack military and government systems",
                        effect: "-15 military, -10 stability, +DEFCON",
                        color: AppSettings.terminalAmber
                    ) {
                        gameEngine.cyberWarfare(from: playerID, to: targetID)
                        dismiss()
                    }

                    // Propaganda
                    covertOpButton(
                        title: "🎭 PROPAGANDA",
                        subtitle: "Undermine regime, reduce morale",
                        effect: "-20 stability, -10 public support, improved relations",
                        color: AppSettings.terminalGreen
                    ) {
                        gameEngine.propaganda(from: playerID, to: targetID)
                        dismiss()
                    }

                    // Special Forces
                    covertOpButton(
                        title: "🪖 SPECIAL FORCES",
                        subtitle: "Tactical strike on military targets",
                        effect: "-25 military, -10 warheads, high risk of war",
                        color: AppSettings.terminalRed
                    ) {
                        gameEngine.specialForces(from: playerID, to: targetID)
                        dismiss()
                    }
                }
                .padding()
            }
        }
        .background(AppSettings.terminalBackground)
        .frame(width: 600, height: 700)
    }

    private func covertOpButton(title: String, subtitle: String, effect: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(color)

                Text(subtitle)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(AppSettings.terminalGreen)

                Text("EFFECT: \(effect)")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(AppSettings.terminalAmber)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.black.opacity(0.7))
            .border(color, width: 2)
        }
    }
}

// MARK: - SDI Deployment Menu

struct SDIDeploymentMenu: View {
    @ObservedObject var gameEngine: GameEngine
    let playerID: String
    @Environment(\.dismiss) var dismiss

    var playerCountry: Country? {
        gameEngine.gameState?.getCountry(id: playerID)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("🛰️ STRATEGIC DEFENSE INITIATIVE")
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundColor(AppSettings.terminalGreen)

                Spacer()

                Button("CANCEL") {
                    dismiss()
                }
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(AppSettings.terminalRed)
            }
            .padding()
            .background(Color.black)
            .border(AppSettings.terminalGreen, width: 2)

            Text("\"STAR WARS\" MISSILE DEFENSE SYSTEM")
                .font(.system(size: 16, design: .monospaced))
                .foregroundColor(AppSettings.terminalAmber)
                .padding()

            // Current Status
            if let country = playerCountry {
                VStack(alignment: .leading, spacing: 8) {
                    Text("CURRENT STATUS:")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(AppSettings.terminalGreen)

                    if country.hasSDI {
                        HStack {
                            Text("✅ SDI DEPLOYED")
                                .font(.system(size: 14, design: .monospaced))
                                .foregroundColor(AppSettings.terminalGreen)
                            Spacer()
                        }
                        HStack {
                            Text("Coverage:")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(AppSettings.terminalAmber)
                            Text("\(country.sdiCoverage)%")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(AppSettings.terminalGreen)
                            Spacer()
                        }
                        HStack {
                            Text("Interception Rate:")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(AppSettings.terminalAmber)
                            Text("\(country.sdiInterceptionRate)%")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(AppSettings.terminalGreen)
                            Spacer()
                        }
                    } else {
                        Text("❌ NO SDI SYSTEM")
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(AppSettings.terminalRed)
                        Text("Deploy a defensive system to protect against nuclear attacks")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(AppSettings.terminalAmber)
                    }
                }
                .padding()
                .background(Color.black.opacity(0.5))
                .border(AppSettings.terminalGreen, width: 1)
                .padding(.horizontal)
            }

            Divider().background(AppSettings.terminalGreen).padding(.vertical)

            ScrollView {
                VStack(spacing: 20) {
                    if let country = playerCountry, !country.hasSDI {
                        // Deployment Options
                        Text("DEPLOYMENT OPTIONS:")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(AppSettings.terminalGreen)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)

                        // Basic Deployment
                        sdiDeploymentButton(
                            title: "🛰️ BASIC DEPLOYMENT",
                            cost: "$100 Billion",
                            coverage: "40%",
                            interception: "25%",
                            description: "Minimal satellite network with limited coverage",
                            color: AppSettings.terminalAmber
                        ) {
                            gameEngine.deploySDI(countryID: playerID, investmentAmount: 100_000_000_000)
                            dismiss()
                        }

                        // Enhanced Deployment
                        sdiDeploymentButton(
                            title: "🛰️ ENHANCED DEPLOYMENT",
                            cost: "$200 Billion",
                            coverage: "70%",
                            interception: "35%",
                            description: "Expanded satellite constellation with improved tracking",
                            color: AppSettings.terminalGreen
                        ) {
                            gameEngine.deploySDI(countryID: playerID, investmentAmount: 200_000_000_000)
                            dismiss()
                        }

                        // Full Deployment
                        sdiDeploymentButton(
                            title: "🛰️ FULL DEPLOYMENT",
                            cost: "$300 Billion",
                            coverage: "90%",
                            interception: "45%",
                            description: "Complete defensive shield with maximum protection",
                            color: AppSettings.terminalGreen
                        ) {
                            gameEngine.deploySDI(countryID: playerID, investmentAmount: 300_000_000_000)
                            dismiss()
                        }
                    } else if let country = playerCountry, country.hasSDI {
                        // Upgrade Options
                        Text("UPGRADE OPTIONS:")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(AppSettings.terminalGreen)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)

                        if country.sdiCoverage < 90 || country.sdiInterceptionRate < 45 {
                            sdiUpgradeButton(
                                title: "⬆️ UPGRADE SYSTEM",
                                cost: "$50 Billion",
                                improvement: "+10% coverage, +5% interception",
                                description: "Additional satellites and improved targeting systems",
                                color: AppSettings.terminalGreen
                            ) {
                                gameEngine.upgradeSDI(countryID: playerID, additionalInvestment: 50_000_000_000)
                                dismiss()
                            }

                            sdiUpgradeButton(
                                title: "⬆️⬆️ MAJOR UPGRADE",
                                cost: "$100 Billion",
                                improvement: "+20% coverage, +10% interception",
                                description: "Significant expansion of defensive capabilities",
                                color: AppSettings.terminalGreen
                            ) {
                                gameEngine.upgradeSDI(countryID: playerID, additionalInvestment: 100_000_000_000)
                                dismiss()
                            }
                        } else {
                            Text("✅ SYSTEM AT MAXIMUM CAPABILITY")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(AppSettings.terminalGreen)
                                .padding()
                        }
                    }

                    // Technical Details (Jane's Defence Weekly style)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SYSTEM COMPONENTS:")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(AppSettings.terminalAmber)

                        technicalDetail(icon: "🔬", text: "Space-based X-ray lasers (50 MW output)")
                        technicalDetail(icon: "🎯", text: "Brilliant Pebbles kinetic kill vehicles")
                        technicalDetail(icon: "📡", text: "PAVE PAWS phased-array radar systems")
                        technicalDetail(icon: "🛰️", text: "DSP satellite early warning network")
                        technicalDetail(icon: "⚡", text: "Ground-based neutral particle beam weapons")

                        Text("\nTECHNICAL SPECIFICATIONS:")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(AppSettings.terminalAmber)
                            .padding(.top)

                        technicalDetail(icon: "📊", text: "Detection range: 3,000 km")
                        technicalDetail(icon: "⏱️", text: "Engagement window: 5-7 minutes")
                        technicalDetail(icon: "🎯", text: "Kill vehicle velocity: 8 km/s")
                        technicalDetail(icon: "💫", text: "Tracking capacity: 100 simultaneous targets")

                        Text("\nLIMITATIONS:")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(AppSettings.terminalAmber)
                            .padding(.top)

                        technicalDetail(icon: "⚠️", text: "Limited by 1980s technology")
                        technicalDetail(icon: "⚠️", text: "Vulnerable to saturation attacks (100+ warheads)")
                        technicalDetail(icon: "⚠️", text: "System degrades under heavy bombardment")
                        technicalDetail(icon: "⚠️", text: "Cannot intercept 100% of warheads")
                        technicalDetail(icon: "⚠️", text: "Decoy discrimination remains challenging")
                    }
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .border(AppSettings.terminalAmber, width: 1)
                    .padding(.horizontal)
                }
                .padding()
            }
        }
        .background(AppSettings.terminalBackground)
        .frame(width: 700, height: 800)
    }

    private func sdiDeploymentButton(title: String, cost: String, coverage: String, interception: String, description: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(title)
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(color)
                    Spacer()
                    Text(cost)
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(AppSettings.terminalAmber)
                }

                HStack(spacing: 20) {
                    HStack {
                        Text("Coverage:")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(AppSettings.terminalGreen)
                        Text(coverage)
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(color)
                    }

                    HStack {
                        Text("Interception:")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(AppSettings.terminalGreen)
                        Text(interception)
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(color)
                    }
                }

                Text(description)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(AppSettings.terminalAmber)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.black.opacity(0.7))
            .border(color, width: 2)
        }
        .padding(.horizontal)
    }

    private func sdiUpgradeButton(title: String, cost: String, improvement: String, description: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(title)
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(color)
                    Spacer()
                    Text(cost)
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(AppSettings.terminalAmber)
                }

                Text("Improvement: \(improvement)")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(AppSettings.terminalGreen)

                Text(description)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(AppSettings.terminalAmber)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.black.opacity(0.7))
            .border(color, width: 2)
        }
        .padding(.horizontal)
    }

    private func technicalDetail(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Text(icon)
                .font(.system(size: 14))
            Text(text)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(AppSettings.terminalGreen)
        }
    }
}

// MARK: - Cyber Warfare Menu

struct CyberWarfareMenu: View {
    @ObservedObject var gameEngine: GameEngine
    let playerID: String
    let targetID: String
    @Environment(\.dismiss) var dismiss
    @State private var selectedProxy: HackerGroup?
    @State private var showProxyPicker = false

    var playerCountry: Country? {
        gameEngine.gameState?.getCountry(id: playerID)
    }

    var targetCountry: Country? {
        gameEngine.gameState?.getCountry(id: targetID)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("🖥️ CYBER WARFARE OPERATIONS")
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundColor(AppSettings.terminalGreen)

                Spacer()

                Button("CANCEL") {
                    dismiss()
                }
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(AppSettings.terminalRed)
            }
            .padding()
            .background(Color.black)
            .border(AppSettings.terminalGreen, width: 2)

            // Target Info
            if let target = targetCountry {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("TARGET: \(target.flag) \(target.name)")
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(AppSettings.terminalAmber)

                        HStack(spacing: 20) {
                            statusIndicator(label: "Cyber Defense", value: target.cyberDefenseLevel.description, color: AppSettings.terminalGreen)
                            statusIndicator(label: "Detection Bonus", value: "+\(target.cyberDefenseLevel.detectionBonus)%", color: AppSettings.terminalAmber)
                        }
                    }

                    Spacer()
                }
                .padding()
                .background(Color.black.opacity(0.5))
                .border(AppSettings.terminalAmber, width: 1)
                .padding(.horizontal)
                .padding(.top)
            }

            // Player Capabilities
            if let player = playerCountry {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("YOUR CAPABILITIES:")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(AppSettings.terminalGreen)

                        HStack(spacing: 20) {
                            statusIndicator(label: "Offense Level", value: "\(player.cyberOffenseLevel)", color: AppSettings.terminalGreen)
                            statusIndicator(label: "Active Ops", value: "\(player.activeCyberOperations.count)", color: AppSettings.terminalAmber)
                            statusIndicator(label: "Treasury", value: "$\((player.treasury / 1_000_000_000))B", color: AppSettings.terminalGreen)
                        }
                    }

                    Spacer()
                }
                .padding()
                .background(Color.black.opacity(0.5))
                .border(AppSettings.terminalGreen, width: 1)
                .padding(.horizontal)
            }

            // Proxy Selection
            HStack {
                Text("COVER:")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(AppSettings.terminalAmber)

                Button(action: {
                    showProxyPicker.toggle()
                }) {
                    HStack {
                        if let proxy = selectedProxy {
                            Text("\(proxy.rawValue) (Deniability: \(proxy.plausibleDeniability)%)")
                        } else {
                            Text("Direct Attack (No Cover)")
                        }
                    }
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(AppSettings.terminalGreen)
                    .padding(8)
                    .background(Color.black)
                    .border(AppSettings.terminalGreen, width: 1)
                }
                .popover(isPresented: $showProxyPicker) {
                    proxyPickerView
                }

                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 10)

            Divider().background(AppSettings.terminalGreen).padding(.vertical)

            // Attack Options
            ScrollView {
                VStack(spacing: 15) {
                    Text("SELECT CYBER ATTACK TYPE:")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(AppSettings.terminalGreen)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // Minor Attacks
                    sectionHeader("INTELLIGENCE GATHERING", color: AppSettings.terminalGreen)

                    cyberAttackButton(attack: .reconnaissance)
                    cyberAttackButton(attack: .dataTheft)

                    // Moderate Attacks
                    sectionHeader("INFLUENCE OPERATIONS", color: AppSettings.terminalAmber)

                    cyberAttackButton(attack: .propagandaCampaign)
                    cyberAttackButton(attack: .electionInterference)

                    // Major Attacks
                    sectionHeader("INFRASTRUCTURE TARGETING", color: .orange)

                    cyberAttackButton(attack: .infrastructureDisruption)
                    cyberAttackButton(attack: .supplyChainsDisruption)
                    cyberAttackButton(attack: .financialSabotage)

                    // Critical Attacks
                    sectionHeader("CRITICAL SYSTEMS", color: AppSettings.terminalRed)

                    cyberAttackButton(attack: .communicationsBlackout)
                    cyberAttackButton(attack: .powerGridAttack)
                    cyberAttackButton(attack: .militarySystemsHack)

                    // Catastrophic Attacks
                    sectionHeader("⚠️ CATASTROPHIC OPERATIONS ⚠️", color: AppSettings.terminalRed)

                    cyberAttackButton(attack: .bankingSystemCollapse)
                    cyberAttackButton(attack: .nuclearSystemsPenetration)
                }
                .padding()
            }

            // Defense Upgrade Section
            Divider().background(AppSettings.terminalGreen)

            if let player = playerCountry {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("YOUR CYBER DEFENSE:")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(AppSettings.terminalGreen)

                        Text("Level: \(player.cyberDefenseLevel.description)")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(AppSettings.terminalAmber)
                    }

                    Spacer()

                    if player.cyberDefenseLevel != .impenetrable {
                        Button(action: {
                            gameEngine.upgradeCyberDefense(countryID: playerID)
                            dismiss()
                        }) {
                            Text("⬆️ UPGRADE DEFENSE")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(Color.black)
                                .padding(10)
                                .background(AppSettings.terminalGreen)
                                .border(AppSettings.terminalGreen, width: 2)
                        }
                    } else {
                        Text("✅ MAX LEVEL")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(AppSettings.terminalGreen)
                    }
                }
                .padding()
                .background(Color.black.opacity(0.5))
                .border(AppSettings.terminalGreen, width: 1)
            }
        }
        .background(AppSettings.terminalBackground)
        .frame(width: 800, height: 900)
    }

    // MARK: - Proxy Picker

    private var proxyPickerView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SELECT COVER")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(AppSettings.terminalGreen)

            Button("No Cover (Direct Attack)") {
                selectedProxy = nil
                showProxyPicker = false
            }
            .font(.system(size: 12, design: .monospaced))
            .foregroundColor(AppSettings.terminalRed)

            Divider()

            ForEach(HackerGroup.allCases, id: \.self) { proxy in
                Button(action: {
                    selectedProxy = proxy
                    showProxyPicker = false
                }) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(proxy.rawValue)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(AppSettings.terminalGreen)
                        Text("Plausible Deniability: \(proxy.plausibleDeniability)%")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(AppSettings.terminalAmber)
                    }
                }
            }
        }
        .padding()
        .background(AppSettings.terminalBackground)
        .frame(width: 300)
    }

    // MARK: - Helper Views

    private func sectionHeader(_ title: String, color: Color) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .bold, design: .monospaced))
            .foregroundColor(color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 10)
    }

    private func statusIndicator(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(AppSettings.terminalAmber)
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(color)
        }
    }

    private func cyberAttackButton(attack: CyberAttackType) -> some View {
        let canAfford = (playerCountry?.treasury ?? 0) >= attack.cost
        let severity = attack.severity
        let severityColor: Color = {
            switch severity {
            case .minor: return AppSettings.terminalGreen
            case .moderate: return AppSettings.terminalAmber
            case .major: return .orange
            case .critical: return AppSettings.terminalRed
            case .catastrophic: return AppSettings.terminalRed
            }
        }()

        return Button(action: {
            if canAfford {
                gameEngine.launchCyberAttack(from: playerID, to: targetID, attackType: attack, useProxy: selectedProxy)
                dismiss()
            }
        }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(attack.rawValue)
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(severityColor)

                    Spacer()

                    Text("$\((attack.cost / 1_000_000))M")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(canAfford ? AppSettings.terminalAmber : AppSettings.terminalRed)
                }

                HStack(spacing: 20) {
                    cyberStatBadge(icon: "⏱️", label: "Duration", value: "\(attack.duration) turns")
                    cyberStatBadge(icon: "🔍", label: "Detectability", value: "\(attack.detectability)%")
                    cyberStatBadge(icon: "⚠️", label: "Severity", value: severity.rawValue)
                }

                // Effects Preview
                if let target = targetCountry {
                    let effects = CyberAttackEffect.effectsFor(attackType: attack, targetCountry: target)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("EFFECTS:")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(AppSettings.terminalAmber)

                        if effects.economicDamage > 0 {
                            effectLine(icon: "💰", text: "Economic: -\(effects.economicDamage)%")
                        }
                        if effects.militaryDegradation > 0 {
                            effectLine(icon: "⚔️", text: "Military: -\(effects.militaryDegradation)")
                        }
                        if effects.stabilityLoss > 0 {
                            effectLine(icon: "📊", text: "Stability: -\(effects.stabilityLoss)")
                        }
                        if effects.warheadsCompromised > 0 {
                            effectLine(icon: "☢️", text: "Warheads: -\(effects.warheadsCompromised)")
                        }
                        if effects.civilianCasualties > 0 {
                            effectLine(icon: "💀", text: "Casualties: \(effects.civilianCasualties.formatted())")
                        }
                        if effects.intelligenceLeak {
                            effectLine(icon: "🔓", text: "Intelligence compromised")
                        }
                    }
                    .padding(.top, 5)
                }

                if !canAfford {
                    Text("❌ INSUFFICIENT FUNDS")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(AppSettings.terminalRed)
                        .padding(.top, 5)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.black.opacity(0.7))
            .border(canAfford ? severityColor : Color.gray, width: 2)
            .opacity(canAfford ? 1.0 : 0.5)
        }
        .disabled(!canAfford)
    }

    private func cyberStatBadge(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 5) {
            Text(icon)
                .font(.system(size: 12))
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(AppSettings.terminalAmber)
                Text(value)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(AppSettings.terminalGreen)
            }
        }
    }

    private func effectLine(icon: String, text: String) -> some View {
        HStack(spacing: 5) {
            Text(icon)
                .font(.system(size: 10))
            Text(text)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(AppSettings.terminalGreen)
        }
    }
}

// MARK: - Prohibited Weapons Menu

struct ProhibitedWeaponsMenu: View {
    @ObservedObject var gameEngine: GameEngine
    let playerID: String
    @Environment(\.dismiss) var dismiss

    var playerCountry: Country? {
        gameEngine.gameState?.getCountry(id: playerID)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("🚀 SECRET WEAPONS PROGRAMS")
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundColor(AppSettings.terminalRed)
                    Text("SALT I & II TREATY VIOLATIONS")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(AppSettings.terminalAmber)
                }

                Spacer()

                Button("CANCEL") {
                    dismiss()
                }
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(AppSettings.terminalRed)
            }
            .padding()
            .background(Color.black)
            .border(AppSettings.terminalRed, width: 2)

            // Warning Banner
            VStack(spacing: 5) {
                Text("⚠️ CLASSIFICATION: TOP SECRET ⚠️")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(AppSettings.terminalRed)
                Text("Detection will trigger international crisis and DEFCON escalation")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(AppSettings.terminalAmber)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(AppSettings.terminalRed.opacity(0.1))
            .border(AppSettings.terminalRed, width: 1)

            // Player Status
            if let player = playerCountry {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("CURRENT STATUS:")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(AppSettings.terminalGreen)

                        HStack(spacing: 20) {
                            statusBadge(label: "Treasury", value: "$\((player.treasury / 1_000_000_000))B")
                            statusBadge(label: "Active Programs", value: "\(player.activeWeaponPrograms.count)")
                            statusBadge(label: "Violations", value: "\(player.treatyViolations)")
                        }
                    }
                    Spacer()
                }
                .padding()
                .background(Color.black.opacity(0.5))
                .border(AppSettings.terminalGreen, width: 1)
                .padding(.horizontal)
                .padding(.top)
            }

            Divider().background(AppSettings.terminalGreen).padding(.vertical)

            // Weapons Programs
            ScrollView {
                VStack(spacing: 15) {
                    Text("SELECT WEAPONS PROGRAM TO DEVELOP:")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(AppSettings.terminalGreen)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // ABM Systems
                    weaponProgramButton(weapon: .antiBallisticMissiles)
                    weaponProgramButton(weapon: .multipleReentryVehicles)
                    weaponProgramButton(weapon: .heavyICBM)
                    weaponProgramButton(weapon: .mobileLaunchers)

                    Text("CRUISE MISSILE PROGRAMS:")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(AppSettings.terminalAmber)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 10)

                    weaponProgramButton(weapon: .submarineLaunchedCruiseMissiles)
                    weaponProgramButton(weapon: .groundLaunchedCruiseMissiles)
                    weaponProgramButton(weapon: .bomberConversions)

                    Text("ADVANCED SYSTEMS:")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(AppSettings.terminalRed)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 10)

                    weaponProgramButton(weapon: .fractionalOrbitBombardment)
                    weaponProgramButton(weapon: .neutronBombs)
                    weaponProgramButton(weapon: .antisatelliteWeapons)
                }
                .padding()
            }
        }
        .background(AppSettings.terminalBackground)
        .frame(width: 900, height: 900)
    }

    // MARK: - Helper Views

    private func statusBadge(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(AppSettings.terminalAmber)
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(AppSettings.terminalGreen)
        }
    }

    private func weaponProgramButton(weapon: SALTProhibitedWeapon) -> some View {
        let canAfford = (playerCountry?.treasury ?? 0) >= weapon.developmentCost
        let alreadyDeployed = playerCountry?.deployedProhibitedWeapons.contains(weapon) ?? false
        let inDevelopment = gameEngine.gameState?.activeWeaponPrograms.contains { $0.weapon == weapon && $0.countryID == playerID } ?? false

        let isAvailable = canAfford && !alreadyDeployed && !inDevelopment

        return Button(action: {
            if isAvailable {
                gameEngine.startWeaponProgram(countryID: playerID, weapon: weapon)
                dismiss()
            }
        }) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(weapon.rawValue)
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(isAvailable ? AppSettings.terminalRed : Color.gray)

                    Spacer()

                    Text("$\((weapon.developmentCost / 1_000_000_000))B")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(canAfford ? AppSettings.terminalAmber : AppSettings.terminalRed)
                }

                Text(weapon.description)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(AppSettings.terminalAmber)

                HStack(spacing: 20) {
                    weaponStatBadge(icon: "⏱️", label: "Development", value: "\(weapon.developmentTime) turns")
                    weaponStatBadge(icon: "⚠️", label: "Detection Risk", value: "5-15% base")
                    weaponStatBadge(icon: "☢️", label: "Warheads", value: "+\(weapon.militaryBenefit.nuclearWarheads)")
                }

                // Historical Context
                Text(weapon.historicalContext)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(AppSettings.terminalGreen)
                    .padding(.top, 5)

                // Diplomatic Impact
                let impact = weapon.diplomaticConsequences
                HStack(spacing: 5) {
                    Text("⚖️")
                    Text("If detected: \(impact.relationsPenalty) relations penalty, \(impact.treatyViolation ? "TREATY VIOLATION" : "No treaty violation")")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(AppSettings.terminalRed)
                }
                .padding(.top, 3)

                // Status
                if alreadyDeployed {
                    Text("✅ ALREADY DEPLOYED")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(AppSettings.terminalGreen)
                        .padding(.top, 5)
                } else if inDevelopment {
                    if let program = gameEngine.gameState?.activeWeaponPrograms.first(where: { $0.weapon == weapon && $0.countryID == playerID }) {
                        Text("🔬 IN DEVELOPMENT (Turn \(program.completionTurn))")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(AppSettings.terminalAmber)
                            .padding(.top, 5)
                    }
                } else if !canAfford {
                    Text("❌ INSUFFICIENT FUNDS")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(AppSettings.terminalRed)
                        .padding(.top, 5)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.black.opacity(0.7))
            .border(isAvailable ? AppSettings.terminalRed : Color.gray, width: 2)
            .opacity(isAvailable ? 1.0 : 0.6)
        }
        .disabled(!isAvailable)
    }

    private func weaponStatBadge(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 5) {
            Text(icon)
                .font(.system(size: 12))
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(AppSettings.terminalAmber)
                Text(value)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(AppSettings.terminalGreen)
            }
        }
    }
}
