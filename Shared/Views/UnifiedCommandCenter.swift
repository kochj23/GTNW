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

    // Detail views
    @State private var showingDefconDetails = false
    @State private var showingNuclearPowersDetails = false
    @State private var showingWarsDetails = false
    @State private var showingTreatiesDetails = false
    @State private var showingRadiationDetails = false
    @State private var showingImageGeneration = false
    @State private var showingDiplomaticMessages = false

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
                            // Auto-end turn after action
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                gameEngine.endTurn()
                            }
                        }
                    )
                }
            }
            .sheet(isPresented: $showingDefconDetails) {
                DefconDetailView(gameState: gameState)
            }
            .sheet(isPresented: $showingNuclearPowersDetails) {
                NuclearPowersDetailView(gameState: gameState)
            }
            .sheet(isPresented: $showingWarsDetails) {
                WarsDetailView(gameState: gameState)
            }
            .sheet(isPresented: $showingTreatiesDetails) {
                TreatiesDetailView(gameState: gameState)
            }
            .sheet(isPresented: $showingRadiationDetails) {
                RadiationDetailView(gameState: gameState)
            }
            // Image generation disabled - file removed
            // .sheet(isPresented: $showingImageGeneration) {
            //     ImageGenerationView(isPresented: $showingImageGeneration)
            // }
            .sheet(isPresented: $showingDiplomaticMessages) {
                DiplomaticMessagesView(diplomacyService: gameEngine.diplomacyService, gameEngine: gameEngine, gameState: gameState)
            }
        }
    }

    // MARK: - Left Panel (Command Controls)

    private func leftCommandPanel(gameState: GameState) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                SectionHeader("⚡ COMMAND CENTER", icon: "command.circle.fill", color: GTNWColors.terminalGreen)

                // DEFCON Status (clickable)
                Button(action: { showingDefconDetails = true }) {
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
            Divider()
                .background(GTNWColors.neonCyan)

            // Header with AI settings
            HStack {
                SectionHeader("💻 TERMINAL & EVENT LOG", icon: "terminal.fill", color: GTNWColors.neonCyan)

                Spacer()

                // AI Backend & Model Selector
                aiBackendSelector
            }
            .padding()
            .background(GTNWColors.glassPanelDark)

            // Event Log (scrollable) - NEWEST AT TOP with CLEAR INDICATORS
            ScrollView {
                ScrollViewReader { proxy in
                    LazyVStack(alignment: .leading, spacing: 8) {
                        // LATEST INDICATOR - Makes it crystal clear which end is current
                        HStack {
                            Circle()
                                .fill(GTNWColors.terminalGreen)
                                .frame(width: 12, height: 12)
                                .shadow(color: GTNWColors.terminalGreen, radius: 4)

                            Text("🟢 LATEST EVENTS")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(GTNWColors.terminalGreen)

                            Text("(Turn \(gameEngine.gameState?.turn ?? 0))")
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundColor(GTNWColors.terminalAmber)

                            Spacer()

                            Text("↓ Scroll for History")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(GTNWColors.terminalAmber.opacity(0.6))
                        }
                        .padding(12)
                        .background(GTNWColors.terminalGreen.opacity(0.15))
                        .border(GTNWColors.terminalGreen, width: 2)
                        .id("latest-marker")

                        // Game engine logs (reversed = newest first)
                        ForEach(gameEngine.logMessages.reversed()) { log in
                            // Only show meaningful messages (not errors)
                            if !log.message.contains("UNRECOGNIZED") &&
                               !log.message.contains("Type 'help'") &&
                               !log.message.isEmpty {
                                enhancedLogRow(log)
                            }
                        }
                    }
                    .padding(16)
                    .onChange(of: gameEngine.logMessages.count) { _ in
                        // Auto-scroll to latest marker (fixed to always target stable ID)
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo("latest-marker", anchor: .top)
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

            // Category Quick Buttons
            HStack(spacing: 8) {
                CategoryButton(title: "Diplomatic", icon: "hand.raised.fill", color: GTNWColors.terminalGreen) {
                    showingShadowMenu = true
                    // TODO: Pre-filter to diplomatic
                }
                CategoryButton(title: "Military", icon: "shield.fill", color: GTNWColors.terminalRed) {
                    showingShadowMenu = true
                }
                CategoryButton(title: "Covert", icon: "eye.slash.fill", color: GTNWColors.neonPurple) {
                    showingShadowMenu = true
                }
                CategoryButton(title: "Economic", icon: "dollarsign.circle.fill", color: GTNWColors.neonCyan) {
                    showingShadowMenu = true
                }
            }
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
                    enabled: !gameEngine.isProcessingAITurn && selectedTarget != nil && (gameState.getPlayerCountry()?.nuclearWarheads ?? 0) > 0
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
                    title: "END TURN\n(MANUAL)",
                    icon: "arrow.right.circle.fill",
                    color: GTNWColors.terminalGreen,
                    enabled: true
                ) {
                    print("[Manual END TURN clicked]")
                    gameEngine.endTurn()
                }

                ModernButton(
                    title: "DIPLOMATIC\nMESSAGES",
                    icon: "envelope.fill",
                    color: GTNWColors.neonCyan,
                    enabled: true
                ) {
                    showingDiplomaticMessages = true
                }

                ModernButton(
                    title: "AI\nSETTINGS",
                    icon: "gearshape.fill",
                    color: GTNWColors.neonPurple,
                    enabled: true
                ) {
                    openAISettings()
                }

                // Info about auto-end turn
                Text("ℹ️ Actions auto-end turn - this button optional")
                    .font(GTNWFonts.caption())
                    .foregroundColor(GTNWColors.terminalAmber.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
            }
        }
    }

    private func quickStatsGrid(gameState: GameState) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            Button(action: { showingNuclearPowersDetails = true }) {
                StatCard(
                    title: "Nuclear Powers",
                    value: "\(gameState.countries.filter { $0.nuclearWarheads > 0 && !$0.isDestroyed }.count)",
                    icon: "flame.fill",
                    color: GTNWColors.terminalRed
                )
            }
            .buttonStyle(.plain)

            Button(action: { showingWarsDetails = true }) {
                StatCard(
                    title: "Active Wars",
                    value: "\(gameState.activeWars.count)",
                    icon: "exclamationmark.triangle.fill",
                    color: .orange
                )
            }
            .buttonStyle(.plain)

            Button(action: { showingTreatiesDetails = true }) {
                StatCard(
                    title: "Treaties",
                    value: "\(gameState.treaties.count)",
                    icon: "doc.text.fill",
                    color: GTNWColors.terminalGreen
                )
            }
            .buttonStyle(.plain)

            Button(action: { showingRadiationDetails = true }) {
                StatCard(
                    title: "Radiation",
                    value: "\(gameState.globalRadiation)",
                    icon: "radiation",
                    color: gameState.globalRadiation > 100 ? GTNWColors.terminalRed : GTNWColors.terminalGreen
                )
            }
            .buttonStyle(.plain)

            Button(action: { showingDiplomaticMessages = true }) {
                let unreadCount = gameEngine.diplomacyService.messages.filter { !$0.read }.count
                StatCard(
                    title: unreadCount > 0 ? "Messages (\(unreadCount) New)" : "Messages",
                    value: "\(gameEngine.diplomacyService.messages.count)",
                    icon: "envelope.fill",
                    color: unreadCount > 0 ? GTNWColors.neonCyan : GTNWColors.terminalAmber
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

    // MARK: - AI Backend Selector

    private var aiBackendSelector: some View {
        HStack(spacing: 12) {
            // Backend picker
            Menu {
                ForEach([AIBackend.ollama, .mlx, .tinyLLM, .tinyChat, .openWebUI, .auto], id: \.self) { backend in
                    Button(action: {
                        AIBackendManager.shared.selectedBackend = backend
                        AIBackendManager.shared.saveSettings()
                    }) {
                        HStack {
                            Text(backend.rawValue)
                            if AIBackendManager.shared.selectedBackend == backend {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 12))
                    Text(AIBackendManager.shared.selectedBackend.rawValue)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                }
                .foregroundColor(AIBackendManager.shared.activeBackend != nil ? GTNWColors.terminalGreen : GTNWColors.terminalRed)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.05))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(AIBackendManager.shared.activeBackend != nil ? GTNWColors.terminalGreen : GTNWColors.terminalRed, lineWidth: 1)
                )
            }
            .help("AI Backend: \(AIBackendManager.shared.activeBackend?.rawValue ?? "None Available")")

            // Ollama model picker (if Ollama selected)
            if AIBackendManager.shared.selectedBackend == .ollama && AIBackendManager.shared.isOllamaAvailable {
                Menu {
                    ForEach(AIBackendManager.shared.ollamaModels, id: \.self) { model in
                        Button(action: {
                            AIBackendManager.shared.selectedOllamaModel = model
                            AIBackendManager.shared.saveSettings()
                        }) {
                            HStack {
                                Text(model)
                                if AIBackendManager.shared.selectedOllamaModel == model {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "cpu")
                            .font(.system(size: 12))
                        Text(AIBackendManager.shared.selectedOllamaModel)
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .lineLimit(1)
                    }
                    .foregroundColor(GTNWColors.neonCyan)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(GTNWColors.neonCyan, lineWidth: 1)
                    )
                }
                .help("Ollama Model")
            }
        }
    }

    // MARK: - Actions

    private func openAISettings() {
        let settingsView = AIBackendSettingsView()
        let hostingController = NSHostingController(rootView: settingsView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "AI Backend Settings"
        window.styleMask = [.titled, .closable, .resizable]
        window.setContentSize(NSSize(width: 600, height: 700))
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    // MARK: - Helper Functions

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }

    private func extractTurnNumber(from log: LogMessage) -> Int? {
        let pattern = #"(?:TURN|Turn)\s*(\d+)"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: log.message, range: NSRange(log.message.startIndex..., in: log.message)),
           let range = Range(match.range(at: 1), in: log.message) {
            return Int(log.message[range])
        }
        return nil
    }

    // MARK: - Enhanced Log Display

    // Enhanced log row with timestamps, turn numbers, and TopGUI-style glass cards
    private func enhancedLogRow(_ log: LogMessage) -> some View {
        Group {
            if log.message.contains("=====") && log.message.contains("TURN") {
                turnMarkerView(log)
            } else {
                regularLogView(log)
            }
        }
    }

    private func turnMarkerView(_ log: LogMessage) -> some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(GTNWColors.neonCyan.opacity(0.5))
                .frame(height: 3)

            Text(log.message)
                .font(.system(size: 18, weight: .black, design: .monospaced))
                .foregroundColor(GTNWColors.neonCyan)
                .shadow(color: GTNWColors.neonCyan, radius: 6)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)

            Rectangle()
                .fill(GTNWColors.neonCyan.opacity(0.5))
                .frame(height: 3)
        }
    }

    private func regularLogView(_ log: LogMessage) -> some View {
        HStack(alignment: .top, spacing: 12) {
            logIcon(log.type, message: log.message)
                .font(.system(size: 18))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                logMetadata(log)
                logMessageText(log)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(logColor(log.type).opacity(0.3), lineWidth: 1)
                )
        )
    }

    private func logMetadata(_ log: LogMessage) -> some View {
        HStack(spacing: 8) {
            Text("[T\(extractTurnNumber(from: log) ?? gameEngine.gameState?.turn ?? 0)]")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(GTNWColors.neonCyan)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(GTNWColors.neonCyan.opacity(0.2))
                .cornerRadius(3)

            Text(formatTimestamp(log.timestamp))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(GTNWColors.terminalAmber.opacity(0.7))

            if log.type != .info && log.type != .system {
                Text(logTypeLabel(log.type))
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(logColor(log.type))
                    .cornerRadius(3)
            }

            Spacer()
        }
    }

    private func logMessageText(_ log: LogMessage) -> some View {
        Text(log.message)
            .font(.system(size: 13, weight: .medium, design: .monospaced))
            .foregroundColor(logColor(log.type))
            .lineSpacing(2)
    }

    // Original log row (kept for compatibility)
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
                    responseMessage = "✓ BUILD MILITARY: \(parsed.reason)\nProcessing turn..."
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        gameEngine.endTurn()
                    }
                case "BUILD_NUKES":
                    responseMessage = "✓ BUILD NUKES: \(parsed.reason)\nProcessing turn..."
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        gameEngine.endTurn()
                    }
                case "ALLY":
                    if let target = parsed.target {
                        gameEngine.formAlliance(country1: player.id, country2: target)
                        responseMessage = "✓ ALLIANCE FORMED: \(parsed.reason)"
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            gameEngine.endTurn()
                        }
                    }
                default:
                    responseMessage = "✓ Command understood: \(parsed.reason)\nProcessing turn..."
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        gameEngine.endTurn()
                    }
                }
            }
        } else if input.lowercased().contains("help") {
            showHelp()
        } else if input.lowercased().contains("what") || input.lowercased().contains("should") {
            // TODO: Re-enable Ollama integration when ollamaService is implemented in GameEngine
            responseMessage = "STRATEGIC ADVICE:\n\nAI analysis temporarily unavailable."
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

// MARK: - Detail Views

struct DefconDetailView: View {
    let gameState: GameState
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("🚨 DEFCON STATUS DETAILS")
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundColor(gameState.defconLevel.color)
                Spacer()
                Button("Close") { dismiss() }
                    .foregroundColor(.red)
            }
            .padding()

            VStack(alignment: .leading, spacing: 15) {
                Text("CURRENT LEVEL: DEFCON \(gameState.defconLevel.rawValue)")
                    .font(.system(size: 32, weight: .black, design: .monospaced))
                    .foregroundColor(gameState.defconLevel.color)

                Text(gameState.defconLevel.description)
                    .font(.system(size: 16, design: .monospaced))
                    .foregroundColor(GTNWColors.terminalGreen)

                Divider()

                Text("DEFCON LEVELS EXPLAINED:")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(GTNWColors.terminalAmber)

                VStack(alignment: .leading, spacing: 10) {
                    defconRow(5, "Normal Peacetime", "Lowest state of readiness")
                    defconRow(4, "Increased Intelligence", "Above normal readiness")
                    defconRow(3, "Increase Force Readiness", "Air Force ready to mobilize in 15 min")
                    defconRow(2, "Further Increase", "Armed Forces ready to deploy within 6 hours")
                    defconRow(1, "Maximum Readiness", "Nuclear war imminent or in progress")
                }

                Divider()

                Text("TRIGGERS:")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(GTNWColors.terminalAmber)

                Text("• Wars increase tension\n• Nuclear strikes raise DEFCON\n• Building nukes raises DEFCON\n• Peace over time lowers DEFCON")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(GTNWColors.terminalGreen)
            }
            .padding()

            Spacer()
        }
        .frame(width: 700, height: 600)
        .background(Color.black)
        .border(gameState.defconLevel.color, width: 3)
    }

    private func defconRow(_ level: Int, _ name: String, _ desc: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(level)")
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundColor(DefconLevel(rawValue: level)?.color ?? .white)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(GTNWColors.terminalGreen)
                Text(desc)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(GTNWColors.terminalAmber.opacity(0.8))
            }
        }
        .padding(10)
        .background(level == gameState.defconLevel.rawValue ? DefconLevel(rawValue: level)?.color.opacity(0.2) : Color.black.opacity(0.3))
        .border(level == gameState.defconLevel.rawValue ? DefconLevel(rawValue: level)?.color ?? .clear : Color.clear, width: 2)
        .cornerRadius(6)
    }
}

struct NuclearPowersDetailView: View {
    let gameState: GameState
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("☢️ NUCLEAR POWERS")
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundColor(GTNWColors.terminalRed)
                Spacer()
                Button("Close") { dismiss() }
                    .foregroundColor(.red)
            }
            .padding()

            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(gameState.countries.filter { $0.nuclearWarheads > 0 && !$0.isDestroyed }.sorted(by: { $0.nuclearWarheads > $1.nuclearWarheads })) { country in
                        HStack(spacing: 15) {
                            Text(country.flag)
                                .font(.system(size: 32))

                            VStack(alignment: .leading, spacing: 6) {
                                Text(country.name)
                                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                                    .foregroundColor(GTNWColors.terminalGreen)

                                HStack(spacing: 20) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "flame.fill")
                                        Text("\(country.nuclearWarheads) warheads")
                                    }
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(GTNWColors.terminalRed)

                                    HStack(spacing: 4) {
                                        Image(systemName: "person.3.fill")
                                        Text("\(country.population / 1_000_000)M people")
                                    }
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(GTNWColors.terminalAmber)

                                    if !country.atWarWith.isEmpty {
                                        HStack(spacing: 4) {
                                            Image(systemName: "exclamationmark.triangle.fill")
                                            Text("At war")
                                        }
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundColor(.orange)
                                    }
                                }
                            }

                            Spacer()
                        }
                        .padding()
                        .background(GTNWColors.terminalRed.opacity(0.1))
                        .border(GTNWColors.terminalRed, width: 1)
                        .cornerRadius(6)
                    }
                }
                .padding()
            }

            Spacer()
        }
        .frame(width: 700, height: 600)
        .background(Color.black)
        .border(GTNWColors.terminalRed, width: 3)
    }
}

struct WarsDetailView: View {
    let gameState: GameState
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("⚔️ ACTIVE WARS")
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundColor(.orange)
                Spacer()
                Button("Close") { dismiss() }
                    .foregroundColor(.red)
            }
            .padding()

            if gameState.activeWars.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(GTNWColors.terminalGreen)
                    Text("NO ACTIVE WARS")
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundColor(GTNWColors.terminalGreen)
                    Text("World at peace (for now)")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(GTNWColors.terminalAmber)
                }
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(gameState.activeWars, id: \.aggressor) { war in
                            if let aggressor = gameState.getCountry(id: war.aggressor),
                               let defender = gameState.getCountry(id: war.defender) {
                                VStack(spacing: 12) {
                                    HStack(spacing: 20) {
                                        VStack {
                                            Text(aggressor.flag)
                                                .font(.system(size: 40))
                                            Text(aggressor.name)
                                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                                .foregroundColor(GTNWColors.terminalRed)
                                            Text("☢️ \(aggressor.nuclearWarheads)")
                                                .font(.system(size: 12, design: .monospaced))
                                                .foregroundColor(GTNWColors.terminalAmber)
                                        }

                                        Image(systemName: "arrow.right")
                                            .font(.system(size: 30))
                                            .foregroundColor(.orange)

                                        VStack {
                                            Text(defender.flag)
                                                .font(.system(size: 40))
                                            Text(defender.name)
                                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                                .foregroundColor(GTNWColors.terminalGreen)
                                            Text("☢️ \(defender.nuclearWarheads)")
                                                .font(.system(size: 12, design: .monospaced))
                                                .foregroundColor(GTNWColors.terminalAmber)
                                        }
                                    }

                                    Text("Started: Turn \(war.startTurn)")
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(GTNWColors.terminalAmber.opacity(0.7))
                                }
                                .padding()
                                .background(Color.orange.opacity(0.1))
                                .border(Color.orange, width: 2)
                                .cornerRadius(6)
                            }
                        }
                    }
                    .padding()
                }
            }

            Spacer()
        }
        .frame(width: 700, height: 600)
        .background(Color.black)
        .border(Color.orange, width: 3)
    }
}

struct TreatiesDetailView: View {
    let gameState: GameState
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("📜 TREATIES")
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundColor(GTNWColors.terminalGreen)
                Spacer()
                Button("Close") { dismiss() }
                    .foregroundColor(.red)
            }
            .padding()

            if gameState.treaties.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 64))
                        .foregroundColor(GTNWColors.terminalAmber.opacity(0.5))
                    Text("NO ACTIVE TREATIES")
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundColor(GTNWColors.terminalAmber)
                    Text("No formal agreements in place")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(GTNWColors.terminalAmber.opacity(0.7))
                }
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(Array(gameState.treaties.enumerated()), id: \.offset) { index, treaty in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(treaty.type.rawValue)
                                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                                    .foregroundColor(GTNWColors.terminalGreen)

                                Text("Signatories:")
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundColor(GTNWColors.terminalAmber)

                                ForEach(treaty.signatories, id: \.self) { countryID in
                                    if let country = gameState.getCountry(id: countryID) {
                                        Text("\(country.flag) \(country.name)")
                                            .font(.system(size: 12, design: .monospaced))
                                            .foregroundColor(GTNWColors.terminalGreen.opacity(0.8))
                                    }
                                }

                                Text("Signed: Turn \(treaty.turn)")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(GTNWColors.terminalAmber.opacity(0.6))
                                    .padding(.top, 4)
                            }
                            .padding()
                            .background(GTNWColors.terminalGreen.opacity(0.1))
                            .border(GTNWColors.terminalGreen, width: 1)
                            .cornerRadius(6)
                        }
                    }
                    .padding()
                }
            }

            Spacer()
        }
        .frame(width: 700, height: 600)
        .background(Color.black)
        .border(GTNWColors.terminalGreen, width: 3)
    }
}

struct RadiationDetailView: View {
    let gameState: GameState
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("☢️ GLOBAL RADIATION")
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundColor(gameState.globalRadiation > 100 ? GTNWColors.terminalRed : GTNWColors.terminalGreen)
                Spacer()
                Button("Close") { dismiss() }
                    .foregroundColor(.red)
            }
            .padding()

            VStack(alignment: .leading, spacing: 15) {
                Text("CURRENT LEVEL: \(gameState.globalRadiation)")
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .foregroundColor(gameState.globalRadiation > 100 ? GTNWColors.terminalRed : GTNWColors.terminalGreen)

                // Radiation scale
                HStack {
                    Text("0")
                        .foregroundColor(GTNWColors.terminalGreen)
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))

                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [GTNWColors.terminalGreen, GTNWColors.terminalAmber, GTNWColors.terminalRed]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * min(Double(gameState.globalRadiation) / 500.0, 1.0))
                        }
                    }
                    .frame(height: 30)

                    Text("500+")
                        .foregroundColor(GTNWColors.terminalRed)
                }
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .padding(.vertical)

                Divider()

                Text("EFFECTS:")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(GTNWColors.terminalAmber)

                VStack(alignment: .leading, spacing: 8) {
                    radiationEffect(0..<100, "Safe", "Normal background radiation")
                    radiationEffect(100..<200, "Elevated", "Increased cancer risk")
                    radiationEffect(200..<300, "Dangerous", "Crop failures, contamination")
                    radiationEffect(300..<400, "Severe", "Mass casualties, uninhabitable zones")
                    radiationEffect(400..<500, "Catastrophic", "Nuclear winter possible")
                }

                Text("Nuclear Strikes: \(gameState.nuclearStrikes.count)")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(GTNWColors.terminalRed)
                    .padding(.top)
            }
            .padding()

            Spacer()
        }
        .frame(width: 700, height: 600)
        .background(Color.black)
        .border(gameState.globalRadiation > 100 ? GTNWColors.terminalRed : GTNWColors.terminalGreen, width: 3)
    }

    private func radiationEffect(_ range: Range<Int>, _ name: String, _ desc: String) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(gameState.globalRadiation >= range.lowerBound ? GTNWColors.terminalRed : Color.gray.opacity(0.3))
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(name) (\(range.lowerBound)-\(range.upperBound))")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(GTNWColors.terminalGreen)
                Text(desc)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(GTNWColors.terminalAmber.opacity(0.7))
            }
        }
    }
}

// MARK: - Category Button Component

struct CategoryButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(title)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(color.opacity(0.2))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(color, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    UnifiedCommandCenter()
        .environmentObject(GameEngine())
}
