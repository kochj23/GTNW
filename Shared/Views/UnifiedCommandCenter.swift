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

    var body: some View {
        if let gameState = gameEngine.gameState {
            ZStack {
                GTNWColors.spaceBackground
                    .overlay(ScanlineOverlay().opacity(0.3))

                HSplitView {
                    // LEFT: Command Panel
                    leftCommandPanel(gameState: gameState)
                        .frame(minWidth: 500, maxWidth: 700)

                    // RIGHT: Event Log + Terminal
                    rightTerminalPanel(gameState: gameState)
                        .frame(minWidth: 500)
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
        }
    }

    // MARK: - Left Panel (Command Controls)

    private func leftCommandPanel(gameState: GameState) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                SectionHeader("⚡ COMMAND CENTER", icon: "command.circle.fill", color: GTNWColors.terminalGreen)

                // DEFCON Status
                DefconIndicator(level: gameState.defconLevel)

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
            // AI STATS PANEL - TOP OF RIGHT SIDE
            VStack(spacing: 0) {
                // Header
                HStack {
                    Image(systemName: "chart.bar.fill")
                        .foregroundColor(.cyan)
                        .font(.system(size: 18))
                    Text("📊 AI PERFORMANCE")
                        .font(GTNWFonts.terminal(size: 16, weight: .bold))
                        .foregroundColor(.cyan)

                    Spacer()

                    if gameEngine.ollamaService.isConnected {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(GTNWColors.terminalGreen)
                                .frame(width: 8, height: 8)
                            Text("OLLAMA")
                                .font(GTNWFonts.caption())
                                .foregroundColor(GTNWColors.terminalGreen)
                        }
                    } else {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(GTNWColors.terminalAmber)
                                .frame(width: 8, height: 8)
                            Text("LOCAL")
                                .font(GTNWFonts.caption())
                                .foregroundColor(GTNWColors.terminalAmber)
                        }
                    }
                }
                .padding(12)
                .background(GTNWColors.glassPanelDark)

                // Stats metrics - SINGLE TABLE
                VStack(spacing: 0) {
                    // GPU Utilization (Top priority - real-time hardware metric)
                    statsRow(
                        label: "GPU",
                        value: String(format: "%.0f%%", gameEngine.ollamaService.gpuUtilization),
                        color: gameEngine.ollamaService.gpuUtilization > 80 ? GTNWColors.terminalRed :
                               gameEngine.ollamaService.gpuUtilization > 50 ? GTNWColors.terminalAmber :
                               GTNWColors.terminalGreen
                    )

                    // Token metrics
                    statsRow(label: "CURRENT", value: String(format: "%.1f t/s", gameEngine.ollamaService.tokensPerSecond), color: .cyan)
                    statsRow(label: "AVERAGE", value: String(format: "%.1f t/s", gameEngine.ollamaService.averageTokensPerSecond), color: GTNWColors.terminalGreen)
                    statsRow(label: "PEAK", value: String(format: "%.1f t/s", gameEngine.ollamaService.peakTokensPerSecond), color: GTNWColors.terminalRed)
                    statsRow(label: "TOTAL TOKENS", value: "\(gameEngine.ollamaService.totalTokens)", color: .purple)
                    statsRow(label: "REQUESTS", value: "\(gameEngine.ollamaService.totalRequests)", color: .orange)

                    if gameEngine.ollamaService.isGenerating {
                        HStack {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .cyan))
                                .scaleEffect(0.7)
                            Text("PROCESSING...")
                                .font(GTNWFonts.terminal(size: 12, weight: .bold))
                                .foregroundColor(.cyan)
                            Spacer()
                        }
                        .padding(8)
                        .background(Color.cyan.opacity(0.1))
                    }
                }
                .padding(12)
                .background(Color.black.opacity(0.7))
            }
            .background(GTNWColors.glassPanelDark)
            .border(Color.cyan, width: 3)

            Divider()
                .background(GTNWColors.neonCyan)

            // Header
            HStack {
                SectionHeader("💻 TERMINAL & EVENT LOG", icon: "terminal.fill", color: GTNWColors.neonCyan)

                Spacer()
            }
            .padding()
            .background(GTNWColors.glassPanelDark)

            // Event Log (scrollable) - NEWEST AT TOP, ENHANCED VISIBILITY
            ScrollView {
                ScrollViewReader { proxy in
                    LazyVStack(alignment: .leading, spacing: 6) {
                        // Game engine logs (reversed = newest first)
                        ForEach(gameEngine.logMessages.reversed()) { log in
                            // Only show meaningful messages (not errors)
                            if !log.message.contains("UNRECOGNIZED") &&
                               !log.message.contains("Type 'help'") &&
                               !log.message.isEmpty {
                                logRow(log)
                            }
                        }
                    }
                    .padding(16)
                    .onChange(of: gameEngine.logMessages.count) { _ in
                        // Auto-scroll to top (newest)
                        if let first = gameEngine.logMessages.reversed().first {
                            withAnimation(.easeInOut) {
                                proxy.scrollTo(first.id, anchor: .top)
                            }
                        }
                    }
                }
            }
            .frame(minHeight: 300)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.black.opacity(0.8),
                        Color.black.opacity(0.6)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            // Response area (only show success messages)
            if !responseMessage.isEmpty && !responseMessage.contains("UNRECOGNIZED") && !responseMessage.contains("Type 'help'") {
                ScrollView {
                    Text(responseMessage)
                        .font(GTNWFonts.terminal(size: 13))
                        .foregroundColor(GTNWColors.terminalGreen)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .frame(height: 120)
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
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
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
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
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
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            gameEngine.endTurn()
                        }
                    }
                }

                ModernButton(
                    title: "END\nTURN",
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
            StatCard(
                title: "Nuclear Powers",
                value: "\(gameState.countries.filter { $0.nuclearWarheads > 0 && !$0.isDestroyed }.count)",
                icon: "flame.fill",
                color: GTNWColors.terminalRed
            )

            StatCard(
                title: "Active Wars",
                value: "\(gameState.activeWars.count)",
                icon: "exclamationmark.triangle.fill",
                color: .orange
            )

            StatCard(
                title: "Treaties",
                value: "\(gameState.treaties.count)",
                icon: "doc.text.fill",
                color: GTNWColors.terminalGreen
            )

            StatCard(
                title: "Radiation",
                value: "\(gameState.globalRadiation)",
                icon: "radiation",
                color: gameState.globalRadiation > 100 ? GTNWColors.terminalRed : GTNWColors.terminalGreen
            )
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
        VStack(spacing: 0) {
            // Add thick divider before turn markers for clear separation
            if log.message.contains("=====") {
                Rectangle()
                    .fill(GTNWColors.neonCyan)
                    .frame(height: 4)
                    .padding(.vertical, 10)
            }

            HStack(alignment: .top, spacing: 12) {
                // Icon badge for log type
                logIcon(log.type, message: log.message)
                    .font(.system(size: 20))
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 6) {
                    // Main message with dynamic sizing
                    Text(log.message)
                        .font(
                            log.message.contains("=====") && log.message.contains("TURN") ?
                                .system(size: 18, weight: .black, design: .monospaced) :
                            log.message.contains("AI TURN SUMMARY") || log.message.contains("OLLAMA") ?
                                .system(size: 15, weight: .bold, design: .monospaced) :
                            log.message.starts(with: "  •") ?
                                .system(size: 14, design: .monospaced) :
                                .system(size: 13, weight: .medium, design: .monospaced)
                        )
                        .foregroundColor(logColor(log.type))
                        .shadow(color: logColor(log.type).opacity(0.4), radius: 3)
                        .lineSpacing(2)

                    // Add type badge for warnings/errors (more visible)
                    if log.type == .warning || log.type == .error || log.type == .critical {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 10))
                            Text(logTypeLabel(log.type))
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(logColor(log.type))
                        .cornerRadius(4)
                    }
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                Group {
                    if log.message.contains("=====") && log.message.contains("TURN") {
                        // Turn markers: Extra prominent
                        LinearGradient(
                            gradient: Gradient(colors: [
                                GTNWColors.neonCyan.opacity(0.25),
                                GTNWColors.neonCyan.opacity(0.15)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    } else if log.message.contains("AI TURN SUMMARY") {
                        // AI summary: Highlighted
                        GTNWColors.terminalGreen.opacity(0.18)
                    } else if log.message.contains("OLLAMA") || log.message.contains("AI NATIONS") {
                        // AI status: Subtle highlight
                        GTNWColors.neonPurple.opacity(0.12)
                    } else {
                        // Regular messages
                        Color.black.opacity(0.35)
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        log.message.contains("=====") && log.message.contains("TURN") ?
                            GTNWColors.neonCyan :
                        log.message.contains("AI TURN SUMMARY") ?
                            GTNWColors.terminalGreen :
                        log.type == .critical || log.type == .error ?
                            GTNWColors.terminalRed :
                        log.type == .warning ?
                            GTNWColors.terminalAmber :
                            Color.clear,
                        lineWidth: log.message.contains("TURN") ? 3 : 1.5
                    )
            )
            .cornerRadius(8)
            .shadow(
                color: log.message.contains("TURN") ?
                    GTNWColors.neonCyan.opacity(0.3) :
                    Color.clear,
                radius: 8
            )
        }
    }

    private func logIcon(_ type: LogType, message: String) -> some View {
        Group {
            if message.contains("TURN") {
                Image(systemName: "arrow.clockwise.circle.fill")
                    .foregroundColor(GTNWColors.neonCyan)
            } else if message.contains("AI") {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(GTNWColors.neonPurple)
            } else if message.contains("OLLAMA") {
                Image(systemName: "cpu.fill")
                    .foregroundColor(GTNWColors.terminalGreen)
            } else {
                Image(systemName: logIconName(type))
                    .foregroundColor(logColor(type))
            }
        }
    }

    private func logIconName(_ type: LogType) -> String {
        switch type {
        case .system: return "circle.fill"
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error, .critical: return "xmark.octagon.fill"
        }
    }

    private func logTypeLabel(_ type: LogType) -> String {
        switch type {
        case .system: return "SYSTEM"
        case .info: return "INFO"
        case .warning: return "WARNING"
        case .error, .critical: return "CRITICAL"
        }
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

        // Use new Safe NLP Processor (no MLX dependency)
        if let parsed = gameEngine.nlpProcessor.parseCommand(input, gameState: gameState) {
            // Execute parsed command
            if let player = gameState.getPlayerCountry() {
                switch parsed.action {
                case "ATTACK":
                    if let target = parsed.target {
                        gameEngine.declareWar(aggressor: player.id, defender: target)
                        responseMessage = "✓ WAR DECLARED: \(parsed.reason)"
                    }
                case "NUKE":
                    if let target = parsed.target {
                        gameEngine.launchNuclearStrike(from: player.id, to: target, warheads: 1)
                        responseMessage = "✓ NUCLEAR STRIKE LAUNCHED: \(parsed.reason)"
                    }
                case "BUILD_MILITARY":
                    responseMessage = "✓ BUILD MILITARY: \(parsed.reason)\n(Will execute automatically each turn)"
                case "BUILD_NUKES":
                    responseMessage = "✓ BUILD NUKES: \(parsed.reason)\n(Will execute automatically each turn)"
                default:
                    responseMessage = "✓ Command understood: \(parsed.reason)"
                }
            }
        } else if input.lowercased().contains("help") {
            showHelp()
        } else if input.lowercased().contains("what") || input.lowercased().contains("should") {
            // Use Ollama for strategic advice if connected
            if gameEngine.ollamaService.isConnected {
                Task {
                    let prompt = "As WOPR from WarGames, analyze this situation and provide strategic advice in 2-3 sentences: \(input)\n\nCurrent DEFCON: \(gameState.defconLevel.rawValue)"
                    if let advice = await gameEngine.ollamaService.generate(prompt: prompt, maxTokens: 80) {
                        await MainActor.run {
                            responseMessage = "WOPR ANALYSIS:\n\n\(advice)"
                        }
                    } else {
                        await MainActor.run {
                            responseMessage = "ANALYSIS UNAVAILABLE\nOllama not responding"
                        }
                    }
                }
            } else {
                responseMessage = "STRATEGIC ADVICE:\n\nOllama AI offline. Run 'ollama serve' for LLM-powered analysis."
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
    private func statBadge(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(GTNWFonts.caption())
                .foregroundColor(GTNWColors.terminalAmber.opacity(0.7))
            Text(value)
                .font(GTNWFonts.terminal(size: 16, weight: .bold))
                .foregroundColor(color)
        }
        .padding(8)
        .background(color.opacity(0.1))
        .border(color, width: 1)
    }

    private func statsRow(label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label)
                .font(GTNWFonts.terminal(size: 11, weight: .bold))
                .foregroundColor(GTNWColors.terminalAmber)
                .frame(width: 100, alignment: .leading)

            Spacer()

            Text(value)
                .font(GTNWFonts.terminal(size: 14, weight: .bold))
                .foregroundColor(color)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(color.opacity(0.3)),
            alignment: .bottom
        )
    }
}

#Preview {
    UnifiedCommandCenter()
        .environmentObject(GameEngine())
}
