//
//  UnifiedCommandCenter.swift
//  Global Thermal Nuclear War
//
//  Combined Command + Terminal interface
//  Repository: https://github.com/kochj23/GTNW
//  Created by Jordan Koch on 2025-12-03.
//

import SwiftUI

struct UnifiedCommandCenter: View {
    @EnvironmentObject var gameEngine: GameEngine
    @State private var selectedTarget: String?
    @State private var showingCountryPicker = false
    @State private var showingShadowMenu = false
    @State private var warheadCount: Int = 1
    @State private var commandText = ""
    @State private var responseMessage = ""
    @FocusState private var isCommandFocused: Bool
    @State private var showingDefconDetails = false
    @State private var showingNuclearPowersDetail = false
    @State private var showingWarsDetail = false
    @State private var showingTreatiesDetail = false
    @State private var showingRadiationDetail = false

    var body: some View {
        if let gameState = gameEngine.gameState {
            ZStack {
                GTNWColors.spaceBackground
                    .overlay(ScanlineOverlay().opacity(0.3))

                HSplitView {
                    // LEFT: Command Panel
                    leftCommandPanel(gameState: gameState)
                        .frame(minWidth: 500, maxWidth: 700)

                    // CENTER: Event Log + Terminal
                    rightTerminalPanel(gameState: gameState)
                        .frame(minWidth: 500)

                    // RIGHT: MLX AI Toolkit Panel
                    mlxPanel
                        .frame(minWidth: 280, idealWidth: 320, maxWidth: 400)
                }
                .onAppear {
                    Task {
                        await gameEngine.mlxManager.initialize()
                    }
                }
            }
            .sheet(isPresented: $showingCountryPicker) {
                ModernCountryPicker(gameState: gameState, selectedCountry: $selectedTarget)
            }
            .sheet(isPresented: $showingShadowMenu) {
                if let targetID = selectedTarget,
                   let target = gameState.getCountry(id: targetID),
                   let player = gameState.getPlayerCountry() {
                    ShadowPresidentMenu(
                        player: player,
                        target: target,
                        gameState: gameState,
                        onExecute: { action in
                            gameEngine.executeShadowPresidentAction(action, from: player.id, to: target.id)
                        }
                    )
                }
            }
            .sheet(isPresented: $showingDefconDetails) {
                DefconDetailView(gameState: gameState)
            }
            .sheet(isPresented: $showingNuclearPowersDetail) {
                NuclearPowersDetailView(gameState: gameState)
            }
            .sheet(isPresented: $showingWarsDetail) {
                ActiveWarsDetailView(gameState: gameState)
            }
            .sheet(isPresented: $showingTreatiesDetail) {
                TreatiesDetailView(gameState: gameState)
            }
            .sheet(isPresented: $showingRadiationDetail) {
                RadiationDetailView(gameState: gameState)
            }
        }
    }

    // MARK: - Left Panel (Command Controls)

    private func leftCommandPanel(gameState: GameState) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                SectionHeader("⚡ COMMAND CENTER", icon: "command.circle.fill", color: GTNWColors.terminalGreen)

                // DEFCON Status - Clickable
                Button(action: {
                    showingDefconDetails = true
                }) {
                    DefconIndicator(level: gameState.defconLevel)
                }
                .buttonStyle(.plain)

                // Player Status
                if let player = gameState.getPlayerCountry() {
                    playerStatusCard(player: player, gameState: gameState)
                }

                // Target Selection
                targetSelectionCard(gameState: gameState)

                // Action Buttons
                actionButtons(gameState: gameState)

                // Quick Stats
                SectionHeader("📊 STATUS", icon: "chart.bar.fill", color: GTNWColors.neonCyan)
                    .padding(.top)
                quickStatsGrid(gameState: gameState)
            }
            .padding()
        }
        .background(Color.black.opacity(0.3))
    }

    // MARK: - Right Panel (Terminal + Event Log)

    private func rightTerminalPanel(gameState: GameState) -> some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                SectionHeader("💻 TERMINAL & EVENT LOG", icon: "terminal.fill", color: GTNWColors.neonCyan)

                Spacer()

                if gameEngine.mlxManager.isConnected {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(GTNWColors.terminalGreen)
                            .frame(width: 8, height: 8)
                        Text("MLX AI")
                            .font(GTNWFonts.caption())
                            .foregroundColor(GTNWColors.terminalGreen)
                    }
                }
            }
            .padding()
            .background(GTNWColors.glassPanelDark)

            // Event Log (scrollable)
            ScrollView {
                ScrollViewReader { proxy in
                    LazyVStack(alignment: .leading, spacing: 8) {
                        // Event logger events
                        ForEach(gameEngine.eventLogger.events) { event in
                            eventRow(event)
                                .id(event.id)
                        }

                        // Game engine logs
                        ForEach(gameEngine.logMessages.reversed()) { log in
                            logRow(log)
                        }
                    }
                    .padding()
                    .onChange(of: gameEngine.eventLogger.events.count) { _ in
                        if let first = gameEngine.eventLogger.events.first {
                            withAnimation {
                                proxy.scrollTo(first.id, anchor: .top)
                            }
                        }
                    }
                }
            }
            .frame(minHeight: 300)
            .background(Color.black.opacity(0.5))

            // Response area (if command generates response)
            if !responseMessage.isEmpty {
                ScrollView {
                    Text(responseMessage)
                        .font(GTNWFonts.terminal(size: 13))
                        .foregroundColor(GTNWColors.terminalGreen)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .frame(height: 150)
                .background(Color.black.opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(GTNWColors.terminalGreen, lineWidth: 1)
                )
                .padding()
            }

            // Command Input
            VStack(alignment: .leading, spacing: 8) {
                Text("Enter command (or 'help'):")
                    .font(GTNWFonts.caption())
                    .foregroundColor(GTNWColors.terminalAmber)

                HStack(spacing: 12) {
                    Text(">")
                        .font(GTNWFonts.terminal(size: 18, weight: .bold))
                        .foregroundColor(GTNWColors.terminalGreen)

                    TextField("Type command...", text: $commandText)
                        .focused($isCommandFocused)
                        .textFieldStyle(.plain)
                        .font(GTNWFonts.terminal(size: 16))
                        .foregroundColor(GTNWColors.terminalGreen)
                        .onSubmit {
                            processCommand(gameState: gameState)
                        }

                    Button(action: { processCommand(gameState: gameState) }) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(GTNWColors.terminalGreen)
                    }
                    .disabled(commandText.isEmpty)
                    .hoverScale()
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.7))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(GTNWColors.terminalGreen, lineWidth: 2)
                        )
                )

                // Quick commands
                HStack(spacing: 8) {
                    quickCommandButton("help", icon: "questionmark.circle")
                    quickCommandButton("status", icon: "chart.bar")
                    quickCommandButton("end turn", icon: "arrow.right")
                }
            }
            .padding()
            .background(GTNWColors.glassPanelMedium)
        }
        .onAppear {
            isCommandFocused = true
        }
    }

    // MARK: - Components

    private func playerStatusCard(player: Country, gameState: GameState) -> some View {
        HStack(spacing: 20) {
            Text(player.flag)
                .font(.system(size: 64))

            VStack(alignment: .leading, spacing: 8) {
                Text(player.name)
                    .font(GTNWFonts.subheading())
                    .foregroundColor(GTNWColors.terminalAmber)

                HStack(spacing: 12) {
                    statPill("☢️ \(player.nuclearWarheads)", color: GTNWColors.terminalRed)
                    statPill("Turn \(gameState.turn)", color: GTNWColors.neonCyan)
                    statPill("Wars: \(gameState.activeWars.count)", color: gameState.activeWars.count > 0 ? GTNWColors.terminalRed : GTNWColors.terminalGreen)
                }
            }

            Spacer()
        }
        .padding(20)
        .modernCard(glowColor: GTNWColors.terminalAmber)
    }

    private func targetSelectionCard(gameState: GameState) -> some View {
        Button(action: { showingCountryPicker = true }) {
            HStack(spacing: 12) {
                Image(systemName: "scope")
                    .font(.system(size: 24))
                    .foregroundColor(GTNWColors.terminalRed)

                if let targetID = selectedTarget,
                   let target = gameState.getCountry(id: targetID) {
                    Text(target.flag)
                        .font(.system(size: 32))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(target.name)
                            .font(GTNWFonts.terminal(size: 16, weight: .bold))
                        Text("☢️ \(target.nuclearWarheads) • \(target.alignment.rawValue)")
                            .font(GTNWFonts.caption())
                    }
                } else {
                    Text("SELECT TARGET NATION")
                        .font(GTNWFonts.terminal(size: 16, weight: .bold))
                }

                Spacer()
                Image(systemName: "chevron.right.circle.fill")
                    .font(.system(size: 24))
            }
            .foregroundColor(GTNWColors.terminalGreen)
            .padding()
            .modernCard(glowColor: GTNWColors.terminalGreen)
        }
        .hoverScale()
    }

    private func actionButtons(gameState: GameState) -> some View {
        VStack(spacing: 16) {
            // Primary: Shadow President Actions
            ModernButton(
                title: "SHADOW PRESIDENT ACTIONS",
                icon: "list.bullet.rectangle.fill",
                color: GTNWColors.neonPurple,
                enabled: selectedTarget != nil
            ) {
                showingShadowMenu = true
            }

            Text("132 diplomatic, military, economic, & covert actions")
                .font(GTNWFonts.caption())
                .foregroundColor(GTNWColors.terminalAmber)
                .padding(.bottom, 8)

            Divider().background(GTNWColors.terminalGreen.opacity(0.3))

            Text("QUICK ACTIONS")
                .font(GTNWFonts.caption())
                .foregroundColor(GTNWColors.terminalAmber)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Quick actions grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ModernButton(
                    title: "NUCLEAR\nSTRIKE",
                    icon: "flame.fill",
                    color: GTNWColors.terminalRed,
                    enabled: selectedTarget != nil && (gameState.getPlayerCountry()?.nuclearWarheads ?? 0) > 0
                ) {
                    if let target = selectedTarget, let player = gameState.getPlayerCountry() {
                        gameEngine.launchNuclearStrike(from: player.id, to: target, warheads: 1)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            gameEngine.endTurn()
                        }
                    }
                }

                ModernButton(
                    title: "DECLARE\nWAR",
                    icon: "exclamationmark.triangle.fill",
                    color: GTNWColors.terminalAmber,
                    enabled: selectedTarget != nil
                ) {
                    if let target = selectedTarget, let player = gameState.getPlayerCountry() {
                        gameEngine.declareWar(aggressor: player.id, defender: target)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            gameEngine.endTurn()
                        }
                    }
                }

                ModernButton(
                    title: "FORM\nALLIANCE",
                    icon: "hand.raised.fill",
                    color: GTNWColors.terminalGreen,
                    enabled: selectedTarget != nil
                ) {
                    if let target = selectedTarget, let player = gameState.getPlayerCountry() {
                        gameEngine.formAlliance(country1: player.id, country2: target)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            gameEngine.endTurn()
                        }
                    }
                }

                ModernButton(
                    title: "END TURN\n(MANUAL)",
                    icon: "arrow.right.circle.fill",
                    color: GTNWColors.terminalGreen,
                    enabled: true
                ) {
                    gameEngine.endTurn()
                }
            }
        }
    }

    private func quickStatsGrid(gameState: GameState) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            Button(action: {
                showingNuclearPowersDetail = true
            }) {
                StatCard(
                    title: "Nuclear Powers",
                    value: "\(gameState.countries.filter { $0.nuclearWarheads > 0 && !$0.isDestroyed }.count)",
                    icon: "flame.fill",
                    color: GTNWColors.terminalRed
                )
            }
            .buttonStyle(.plain)

            Button(action: {
                showingWarsDetail = true
            }) {
                StatCard(
                    title: "Active Wars",
                    value: "\(gameState.activeWars.count)",
                    icon: "exclamationmark.triangle.fill",
                    color: .orange
                )
            }
            .buttonStyle(.plain)

            Button(action: {
                showingTreatiesDetail = true
            }) {
                StatCard(
                    title: "Treaties",
                    value: "\(gameState.treaties.count)",
                    icon: "doc.text.fill",
                    color: GTNWColors.terminalGreen
                )
            }
            .buttonStyle(.plain)

            Button(action: {
                showingRadiationDetail = true
            }) {
                StatCard(
                    title: "Radiation",
                    value: "\(gameState.globalRadiation)",
                    icon: "radiation",
                    color: gameState.globalRadiation > 100 ? GTNWColors.terminalRed : GTNWColors.terminalGreen
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func eventRow(_ event: GameEvent) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(event.type.rawValue)
                .font(.system(size: 16))

            VStack(alignment: .leading, spacing: 4) {
                Text(event.message)
                    .font(GTNWFonts.terminal(size: 12))
                    .foregroundColor(event.color)

                HStack(spacing: 8) {
                    if let country = event.country {
                        Text(country)
                            .font(GTNWFonts.terminal(size: 10))
                            .foregroundColor(GTNWColors.terminalAmber.opacity(0.7))
                    }
                    Text("T\(event.turn)")
                        .font(GTNWFonts.terminal(size: 10))
                        .foregroundColor(GTNWColors.terminalAmber.opacity(0.7))
                }
            }

            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(event.color.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(event.color.opacity(0.3), lineWidth: 1)
                )
        )
    }

    private func logRow(_ log: LogMessage) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(log.message)
                .font(GTNWFonts.terminal(size: 11))
                .foregroundColor(logColor(log.type))
        }
        .padding(8)
        .background(Color.black.opacity(0.2))
        .cornerRadius(4)
    }

    private func logColor(_ type: LogType) -> Color {
        switch type {
        case .system: return GTNWColors.terminalGreen
        case .info: return GTNWColors.neonCyan
        case .warning: return GTNWColors.terminalAmber
        case .error, .critical: return GTNWColors.terminalRed
        }
    }

    private func quickCommandButton(_ command: String, icon: String) -> some View {
        Button(action: {
            commandText = command
            processCommand(gameState: gameEngine.gameState!)
        }) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                Text(command)
            }
            .font(GTNWFonts.terminal(size: 10))
            .foregroundColor(GTNWColors.neonCyan)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(GTNWColors.neonCyan.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(GTNWColors.neonCyan.opacity(0.5), lineWidth: 1)
                    )
            )
        }
        .hoverScale(scale: 1.05)
    }

    private func processCommand(gameState: GameState) {
        guard !commandText.isEmpty else { return }

        let input = commandText
        gameEngine.eventLogger.log("COMMAND: \(input)", type: .system, country: nil, turn: gameState.turn)

        if let parsed = gameEngine.mlxManager.parseCommand(input, gameState: gameState) {
            executeTextCommand(parsed, gameState: gameState)
        } else if input.lowercased().contains("help") {
            showHelp()
        } else if input.lowercased().contains("what") || input.lowercased().contains("should") {
            Task {
                let advice = await gameEngine.mlxManager.getStrategicAdvice(situation: input, gameState: gameState)
                await MainActor.run {
                    responseMessage = "WOPR ANALYSIS:\n\n\(advice)"
                }
            }
        } else {
            responseMessage = "UNRECOGNIZED COMMAND\nType 'help' for commands"
        }

        commandText = ""
    }

    private func executeTextCommand(_ command: ParsedCommand, gameState: GameState) {
        guard let player = gameState.getPlayerCountry() else { return }

        switch command.action {
        case .nuclearStrike:
            if let target = command.target {
                gameEngine.launchNuclearStrike(from: player.id, to: target, warheads: 1)
                responseMessage = "NUCLEAR STRIKE AUTHORIZED"
            }
        case .declareWar:
            if let target = command.target {
                gameEngine.declareWar(aggressor: player.id, defender: target)
                responseMessage = "WAR DECLARED"
            }
        case .formAlliance:
            if let target = command.target {
                gameEngine.formAlliance(country1: player.id, country2: target)
                responseMessage = "ALLIANCE FORMED"
            }
        case .endTurn:
            gameEngine.endTurn()
            responseMessage = "TURN ENDED"
        case .showStatus:
            responseMessage = generateStatusReport(gameState: gameState)
        default:
            responseMessage = "Command acknowledged"
        }
    }

    private func showHelp() {
        responseMessage = """
        COMMAND REFERENCE:
        ══════════════════════════════════════
        > launch nuke at [country]
        > declare war on [country]
        > ally with [country]
        > what should i do?
        > status report
        > end turn
        ══════════════════════════════════════
        """
    }

    private func generateStatusReport(gameState: GameState) -> String {
        guard let player = gameState.getPlayerCountry() else { return "ERROR" }

        return """
        SITREP - TURN \(gameState.turn)
        ══════════════════════════════════════
        NATION: \(player.flag) \(player.name)
        DEFCON: \(gameState.defconLevel.rawValue)
        WARHEADS: \(player.nuclearWarheads)
        WARS: \(gameState.activeWars.count)
        CASUALTIES: \(gameState.totalCasualties.formatted())
        ══════════════════════════════════════
        """
    }

    private func statPill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(GTNWFonts.caption())
            .foregroundColor(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(color.opacity(0.2))
                    .overlay(Capsule().stroke(color.opacity(0.5), lineWidth: 1))
            )
    }

    // MARK: - MLX AI Panel

    private var mlxPanel: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.purple)
                Text("🧠 MLX AI")
                    .font(GTNWFonts.terminal(size: 14, weight: .bold))
                    .foregroundColor(.purple)
                Spacer()
                Circle()
                    .fill(gameEngine.mlxManager.isConnected ? Color.green : Color.red)
                    .frame(width: 12, height: 12)
            }
            .padding()
            .background(Color.black)
            .border(Color.purple, width: 2)

            if gameEngine.mlxManager.isConnected {
                VStack(spacing: 12) {
                    // Performance Gauge
                    performanceGauge

                    Divider()

                    // Latest Analysis
                    if !gameEngine.mlxManager.lastResponse.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("LATEST ANALYSIS")
                                .font(GTNWFonts.terminal(size: 10, weight: .bold))
                                .foregroundColor(.purple)
                            Text(gameEngine.mlxManager.lastResponse)
                                .font(GTNWFonts.terminal(size: 10))
                                .foregroundColor(GTNWColors.terminalGreen)
                                .padding(8)
                                .background(Color.black.opacity(0.7))
                        }
                        .padding(.horizontal)
                    }

                    // Interaction History
                    Text("HISTORY (\(gameEngine.mlxManager.interactionHistory.count))")
                        .font(GTNWFonts.terminal(size: 10, weight: .bold))
                        .foregroundColor(.purple)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)

                    ForEach(gameEngine.mlxManager.interactionHistory.prefix(8)) { interaction in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(interaction.type.uppercased())
                                    .font(GTNWFonts.terminal(size: 9, weight: .bold))
                                    .foregroundColor(.purple)
                                if let input = interaction.input {
                                    Text("→ \(input)")
                                        .font(GTNWFonts.terminal(size: 9))
                                        .foregroundColor(GTNWColors.terminalAmber)
                                }
                                Text("✓ \(interaction.output)")
                                    .font(GTNWFonts.terminal(size: 9))
                                    .foregroundColor(GTNWColors.terminalGreen)
                            }
                        }
                    }
                }
                .padding()
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32))
                        .foregroundColor(GTNWColors.terminalAmber)
                    Text("MLX OFFLINE")
                        .font(GTNWFonts.terminal(size: 12, weight: .bold))
                    Text("pip install mlx")
                        .font(GTNWFonts.terminal(size: 10))
                        .foregroundColor(GTNWColors.terminalGreen)
                }
                .frame(maxHeight: .infinity)
                .padding()
            }
        }
        .background(Color.black)
        .border(Color.purple, width: 2)
    }

    // Performance gauge (tokens/sec dial from MLX Code)
    private var performanceGauge: some View {
        let metrics = GTNWPerformanceMetrics.shared

        return HStack(spacing: 16) {
            // Tokens/Sec Dial
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                    .frame(width: 60, height: 60)

                Circle()
                    .trim(from: 0, to: min(metrics.averageTokensPerSecond / 100.0, 1.0))
                    .stroke(
                        tokenSpeedColor(metrics.averageTokensPerSecond),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 1) {
                    Text(String(format: "%.0f", metrics.averageTokensPerSecond))
                        .font(GTNWFonts.terminal(size: 14, weight: .bold))
                        .foregroundColor(GTNWColors.terminalGreen)
                    Text("t/s")
                        .font(GTNWFonts.terminal(size: 8))
                        .foregroundColor(GTNWColors.terminalAmber.opacity(0.7))
                }
            }

            // Stats
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("TOKENS:")
                        .font(GTNWFonts.terminal(size: 9))
                        .foregroundColor(.purple.opacity(0.7))
                    Text("\(metrics.totalTokens)")
                        .font(GTNWFonts.terminal(size: 12, weight: .bold))
                        .foregroundColor(GTNWColors.terminalGreen)
                }

                HStack {
                    Text("AVG:")
                        .font(GTNWFonts.terminal(size: 9))
                        .foregroundColor(.purple.opacity(0.7))
                    Text(String(format: "%.2fs", metrics.averageResponseTime))
                        .font(GTNWFonts.terminal(size: 11))
                        .foregroundColor(GTNWColors.terminalAmber)
                }

                if metrics.peakTokensPerSecond > 0 {
                    HStack {
                        Text("PEAK:")
                            .font(GTNWFonts.terminal(size: 9))
                            .foregroundColor(.purple.opacity(0.7))
                        Text(String(format: "%.0f t/s", metrics.peakTokensPerSecond))
                            .font(GTNWFonts.terminal(size: 11))
                            .foregroundColor(GTNWColors.terminalGreen)
                    }
                }
            }
        }
        .padding()
        .background(Color.black.opacity(0.7))
        .border(Color.purple, width: 1)
    }

    private func tokenSpeedColor(_ speed: Double) -> Color {
        if speed < 20 { return GTNWColors.terminalRed }
        else if speed < 40 { return .orange }
        else if speed < 60 { return .yellow }
        else { return GTNWColors.terminalGreen }
    }
}

// MARK: - Detail Views

struct DefconDetailView: View {
    let gameState: GameState
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("🎯 DEFCON \(gameState.defconLevel.rawValue) DETAILS")
                    .font(GTNWFonts.heading())
                    .foregroundColor(gameState.defconLevel.color)
                Spacer()
                Button("CLOSE") { dismiss() }
                    .font(GTNWFonts.terminal(size: 14, weight: .bold))
                    .foregroundColor(GTNWColors.terminalRed)
            }
            .padding()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("MILITARY READINESS")
                        .font(GTNWFonts.subheading())
                        .foregroundColor(GTNWColors.terminalAmber)

                    Text(gameState.defconLevel.description)
                        .font(GTNWFonts.body())
                        .foregroundColor(GTNWColors.terminalGreen)

                    Divider()

                    Text("ACTIVE MILITARY OPERATIONS")
                        .font(GTNWFonts.subheading())
                        .foregroundColor(GTNWColors.terminalAmber)

                    ForEach(gameState.activeWars) { war in
                        HStack {
                            if let aggressor = gameState.getCountry(id: war.aggressor),
                               let defender = gameState.getCountry(id: war.defender) {
                                Text("\(aggressor.flag) \(aggressor.name)")
                                    .foregroundColor(GTNWColors.terminalRed)
                                Text("⚔️")
                                Text("\(defender.flag) \(defender.name)")
                                    .foregroundColor(GTNWColors.terminalRed)
                                Spacer()
                                Text("Turn \(war.startTurn)")
                                    .font(GTNWFonts.caption())
                                    .foregroundColor(GTNWColors.terminalAmber.opacity(0.7))
                            }
                        }
                        .padding()
                        .background(Color.black.opacity(0.5))
                    }

                    if gameState.activeWars.isEmpty {
                        Text("No active military conflicts")
                            .foregroundColor(GTNWColors.terminalGreen)
                            .padding()
                    }

                    Divider()

                    Text("NUCLEAR STRIKES")
                        .font(GTNWFonts.subheading())
                        .foregroundColor(GTNWColors.terminalAmber)

                    ForEach(Array(gameState.nuclearStrikes.enumerated()), id: \.offset) { index, strike in
                        HStack {
                            if let attacker = gameState.getCountry(id: strike.attacker),
                               let target = gameState.getCountry(id: strike.target) {
                                Text("\(attacker.flag) \(attacker.name)")
                                Text("☢️ → \(strike.warheadsUsed)")
                                Text("\(target.flag) \(target.name)")
                                Spacer()
                                Text("T\(strike.turn)")
                                    .font(GTNWFonts.caption())
                            }
                        }
                        .foregroundColor(GTNWColors.terminalRed)
                        .padding()
                        .background(GTNWColors.terminalRed.opacity(0.1))
                    }

                    if gameState.nuclearStrikes.isEmpty {
                        Text("✅ No nuclear weapons fired")
                            .foregroundColor(GTNWColors.terminalGreen)
                            .padding()
                    }
                }
                .padding()
            }
        }
        .frame(width: 700, height: 600)
        .background(GTNWColors.commandCenterBackground)
    }
}

struct NuclearPowersDetailView: View {
    let gameState: GameState
    @Environment(\.dismiss) var dismiss

    var nuclearNations: [Country] {
        gameState.countries.filter { $0.nuclearWarheads > 0 && !$0.isDestroyed }.sorted { $0.nuclearWarheads > $1.nuclearWarheads }
    }

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("☢️ NUCLEAR POWERS")
                    .font(GTNWFonts.heading())
                    .foregroundColor(GTNWColors.terminalRed)
                Spacer()
                Button("CLOSE") { dismiss() }
            }
            .padding()

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(nuclearNations) { country in
                        HStack {
                            Text(country.flag)
                                .font(.system(size: 32))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(country.name)
                                    .font(GTNWFonts.terminal(size: 14, weight: .bold))
                                    .foregroundColor(GTNWColors.terminalGreen)
                                HStack {
                                    Text("☢️ \(country.nuclearWarheads) warheads")
                                    Text("•")
                                    Text("\(country.alignment.rawValue)")
                                }
                                .font(GTNWFonts.caption())
                                .foregroundColor(GTNWColors.terminalAmber)
                            }
                            Spacer()
                        }
                        .padding()
                        .background(Color.black.opacity(0.5))
                    }
                }
                .padding()
            }
        }
        .frame(width: 600, height: 500)
        .background(GTNWColors.commandCenterBackground)
    }
}

struct ActiveWarsDetailView: View {
    let gameState: GameState
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("⚔️ ACTIVE WARS")
                    .font(GTNWFonts.heading())
                    .foregroundColor(.orange)
                Spacer()
                Button("CLOSE") { dismiss() }
            }
            .padding()

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(gameState.activeWars) { war in
                        if let aggressor = gameState.getCountry(id: war.aggressor),
                           let defender = gameState.getCountry(id: war.defender) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("\(aggressor.flag) \(aggressor.name)")
                                        .font(GTNWFonts.terminal(size: 14, weight: .bold))
                                        .foregroundColor(GTNWColors.terminalRed)
                                    Text("VS")
                                        .foregroundColor(GTNWColors.terminalAmber)
                                    Text("\(defender.flag) \(defender.name)")
                                        .font(GTNWFonts.terminal(size: 14, weight: .bold))
                                        .foregroundColor(GTNWColors.terminalRed)
                                }
                                Text("Started: Turn \(war.startTurn) • Duration: \(gameState.turn - war.startTurn) turns")
                                    .font(GTNWFonts.caption())
                                    .foregroundColor(GTNWColors.terminalAmber)
                            }
                            .padding()
                            .background(Color.black.opacity(0.5))
                        }
                    }

                    if gameState.activeWars.isEmpty {
                        Text("No active wars")
                            .foregroundColor(GTNWColors.terminalGreen)
                            .padding()
                    }
                }
                .padding()
            }
        }
        .frame(width: 600, height: 500)
        .background(GTNWColors.commandCenterBackground)
    }
}

struct TreatiesDetailView: View {
    let gameState: GameState
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("📜 TREATIES & ALLIANCES")
                    .font(GTNWFonts.heading())
                    .foregroundColor(GTNWColors.terminalGreen)
                Spacer()
                Button("CLOSE") { dismiss() }
            }
            .padding()

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(Array(gameState.treaties.enumerated()), id: \.offset) { index, treaty in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(treaty.type.rawValue.capitalized)")
                                .font(GTNWFonts.terminal(size: 12, weight: .bold))
                                .foregroundColor(GTNWColors.terminalGreen)

                            Text("Signatories: \(treaty.signatories.compactMap { gameState.getCountry(id: $0)?.name }.joined(separator: ", "))")
                                .font(GTNWFonts.caption())
                                .foregroundColor(GTNWColors.terminalAmber)

                            Text("Turn \(treaty.turn)")
                                .font(GTNWFonts.caption())
                                .foregroundColor(GTNWColors.terminalAmber.opacity(0.7))
                        }
                        .padding()
                        .background(Color.black.opacity(0.5))
                    }

                    if gameState.treaties.isEmpty {
                        Text("No active treaties")
                            .foregroundColor(GTNWColors.terminalAmber)
                            .padding()
                    }
                }
                .padding()
            }
        }
        .frame(width: 600, height: 500)
        .background(GTNWColors.commandCenterBackground)
    }
}

struct RadiationDetailView: View {
    let gameState: GameState
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("☢️ GLOBAL RADIATION")
                    .font(GTNWFonts.heading())
                    .foregroundColor(gameState.globalRadiation > 100 ? GTNWColors.terminalRed : GTNWColors.terminalGreen)
                Spacer()
                Button("CLOSE") { dismiss() }
            }
            .padding()

            VStack(alignment: .leading, spacing: 16) {
                Text("Current Level: \(gameState.globalRadiation)")
                    .font(GTNWFonts.subheading())
                    .foregroundColor(gameState.globalRadiation > 100 ? GTNWColors.terminalRed : GTNWColors.terminalGreen)

                ProgressView(value: Double(min(gameState.globalRadiation, 500)), total: 500.0)
                    .tint(gameState.globalRadiation > 100 ? GTNWColors.terminalRed : GTNWColors.terminalGreen)

                Text("RADIATION LEVELS")
                    .font(GTNWFonts.subheading())
                    .foregroundColor(GTNWColors.terminalAmber)

                VStack(alignment: .leading, spacing: 8) {
                    radiationLevel("0-50", "Safe", .green)
                    radiationLevel("51-100", "Elevated", .yellow)
                    radiationLevel("101-200", "Dangerous", .orange)
                    radiationLevel("201-500", "Critical", .red)
                    radiationLevel("500+", "Uninhabitable", GTNWColors.terminalRed)
                }
                .padding()
                .background(Color.black.opacity(0.5))

                Text("Total Nuclear Strikes: \(gameState.nuclearStrikes.count)")
                    .font(GTNWFonts.body())
                    .foregroundColor(GTNWColors.terminalAmber)

                Text("Total Casualties: \(gameState.totalCasualties.formatted())")
                    .font(GTNWFonts.body())
                    .foregroundColor(GTNWColors.terminalRed)
            }
            .padding()
        }
        .frame(width: 600, height: 500)
        .background(GTNWColors.commandCenterBackground)
    }

    private func radiationLevel(_ range: String, _ label: String, _ color: Color) -> some View {
        HStack {
            Text(range)
                .font(GTNWFonts.terminal(size: 12))
                .foregroundColor(GTNWColors.terminalAmber)
                .frame(width: 80, alignment: .leading)
            Text(label)
                .font(GTNWFonts.terminal(size: 12))
                .foregroundColor(color)
        }
    }
}

#Preview {
    UnifiedCommandCenter()
        .environmentObject(GameEngine())
}
