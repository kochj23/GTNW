//
//  TextCommandInterface.swift
//  Global Thermal Nuclear War
//
//  Space Quest-style text command interface with event log
//  Created by Jordan Koch & Claude Code on 2025-12-03.
//

import SwiftUI

struct TextCommandInterface: View {
    @EnvironmentObject var gameEngine: GameEngine
    @StateObject private var eventLogger = EventLogger()
    @StateObject private var mlxManager = MLXManager()
    @State private var commandText = ""
    @State private var commandHistory: [String] = []
    @State private var historyIndex = -1
    @State private var responseMessage = ""
    @FocusState private var isCommandFocused: Bool

    var body: some View {
        if let gameState = gameEngine.gameState {
            ZStack {
                GTNWColors.commandCenterBackground

                VStack(spacing: 0) {
                    // Header
                    commandHeader

                    HSplitView {
                        // Left: Event Log
                        eventLogPanel(gameState: gameState)
                            .frame(minWidth: 400)

                        // Right: Command Input
                        commandInputPanel(gameState: gameState)
                            .frame(minWidth: 500)
                    }
                }
            }
            .onAppear {
                Task {
                    await mlxManager.initialize()
                }
                isCommandFocused = true
            }
        }
    }

    private var commandHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("💻 WOPR TERMINAL INTERFACE")
                    .font(GTNWFonts.heading())
                    .foregroundColor(GTNWColors.terminalGreen)

                HStack(spacing: 16) {
                    Text("Type commands in natural language")
                        .font(GTNWFonts.caption())
                        .foregroundColor(GTNWColors.terminalAmber)

                    if mlxManager.isConnected {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(GTNWColors.terminalGreen)
                                .frame(width: 8, height: 8)
                            Text("MLX AI ONLINE")
                                .font(GTNWFonts.caption())
                                .foregroundColor(GTNWColors.terminalGreen)
                        }
                    }
                }
            }

            Spacer()

            Button(action: {
                commandText = "help"
                processCommand()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "questionmark.circle.fill")
                    Text("HELP")
                }
                .font(GTNWFonts.terminal(size: 14, weight: .bold))
                .foregroundColor(GTNWColors.neonCyan)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .modernCard(glowColor: GTNWColors.neonCyan)
            }
            .hoverScale()
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    private func eventLogPanel(gameState: GameState) -> some View {
        VStack(spacing: 0) {
            // Event Log Header
            HStack {
                Image(systemName: "doc.text.fill")
                    .foregroundColor(GTNWColors.neonCyan)
                Text("EVENT LOG")
                    .font(GTNWFonts.subheading())
                    .foregroundColor(GTNWColors.neonCyan)

                Spacer()

                Text("Turn \(gameState.turn)")
                    .font(GTNWFonts.caption())
                    .foregroundColor(GTNWColors.terminalAmber)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(GTNWColors.terminalAmber.opacity(0.2))
                    )
            }
            .padding()
            .background(GTNWColors.glassPanelDark)

            // Events scrollview
            ScrollView {
                ScrollViewReader { proxy in
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(eventLogger.events) { event in
                            eventRow(event)
                                .id(event.id)
                        }

                        // Show game engine logs too
                        ForEach(gameEngine.logMessages.reversed()) { log in
                            logRow(log)
                        }
                    }
                    .padding()
                    .onChange(of: eventLogger.events.count) { _ in
                        if let first = eventLogger.events.first {
                            withAnimation {
                                proxy.scrollTo(first.id, anchor: .top)
                            }
                        }
                    }
                }
            }
            .background(Color.black.opacity(0.5))
        }
    }

    private func eventRow(_ event: GameEvent) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon
            Text(event.type.rawValue)
                .font(.system(size: 20))

            VStack(alignment: .leading, spacing: 4) {
                // Message
                Text(event.message)
                    .font(GTNWFonts.terminal(size: 13))
                    .foregroundColor(event.color)

                // Metadata
                HStack(spacing: 8) {
                    if let country = event.country {
                        Text(country)
                            .font(GTNWFonts.caption())
                            .foregroundColor(GTNWColors.terminalAmber.opacity(0.7))
                    }

                    Text("Turn \(event.turn)")
                        .font(GTNWFonts.caption())
                        .foregroundColor(GTNWColors.terminalAmber.opacity(0.7))

                    Text(event.timestamp, style: .time)
                        .font(GTNWFonts.caption())
                        .foregroundColor(GTNWColors.terminalAmber.opacity(0.7))
                }
            }

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(event.color.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(event.color.opacity(0.3), lineWidth: 1)
                )
        )
    }

    private func logRow(_ log: LogMessage) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(log.message)
                .font(GTNWFonts.terminal(size: 12))
                .foregroundColor(logColor(log.type))
        }
        .padding(8)
        .background(Color.black.opacity(0.3))
    }

    private func logColor(_ type: LogType) -> Color {
        switch type {
        case .system: return GTNWColors.terminalGreen
        case .info: return GTNWColors.neonCyan
        case .warning: return GTNWColors.terminalAmber
        case .error: return GTNWColors.terminalRed
        case .critical: return GTNWColors.terminalRed
        }
    }

    private func commandInputPanel(gameState: GameState) -> some View {
        VStack(spacing: 0) {
            // Command Input Header
            HStack {
                Image(systemName: "terminal.fill")
                    .foregroundColor(GTNWColors.terminalGreen)
                Text("COMMAND INPUT")
                    .font(GTNWFonts.subheading())
                    .foregroundColor(GTNWColors.terminalGreen)

                Spacer()

                if mlxManager.isProcessing {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Processing...")
                            .font(GTNWFonts.caption())
                            .foregroundColor(GTNWColors.terminalAmber)
                    }
                }
            }
            .padding()
            .background(GTNWColors.glassPanelDark)

            // Command examples
            commandExamples

            // Response area
            if !responseMessage.isEmpty {
                ScrollView {
                    Text(responseMessage)
                        .font(GTNWFonts.terminal(size: 14))
                        .foregroundColor(GTNWColors.terminalGreen)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .frame(height: 200)
                .background(Color.black.opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(GTNWColors.terminalGreen.opacity(0.5), lineWidth: 1)
                )
                .padding()
            }

            Spacer()

            // Command input
            VStack(alignment: .leading, spacing: 8) {
                Text("> Enter command:")
                    .font(GTNWFonts.terminal(size: 14))
                    .foregroundColor(GTNWColors.terminalAmber)

                HStack(spacing: 12) {
                    Text(">")
                        .font(GTNWFonts.terminal(size: 18, weight: .bold))
                        .foregroundColor(GTNWColors.terminalGreen)

                    TextField("", text: $commandText)
                        .focused($isCommandFocused)
                        .textFieldStyle(.plain)
                        .font(GTNWFonts.terminal(size: 16))
                        .foregroundColor(GTNWColors.terminalGreen)
                        .onSubmit {
                            processCommand()
                        }

                    Button(action: processCommand) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(GTNWColors.terminalGreen)
                    }
                    .disabled(commandText.isEmpty)
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
            }
            .padding()
            .background(GTNWColors.glassPanelMedium)
        }
    }

    private var commandExamples: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("EXAMPLE COMMANDS:")
                .font(GTNWFonts.caption())
                .foregroundColor(GTNWColors.terminalAmber)

            VStack(alignment: .leading, spacing: 4) {
                exampleCommand("launch nuke at russia")
                exampleCommand("declare war on china")
                exampleCommand("form alliance with france")
                exampleCommand("give $5B to india")
                exampleCommand("what should i do?")
                exampleCommand("status report")
                exampleCommand("end turn")
            }
            .font(GTNWFonts.terminal(size: 11))
            .foregroundColor(GTNWColors.terminalGreen.opacity(0.6))
        }
        .padding()
        .background(Color.black.opacity(0.3))
    }

    private func exampleCommand(_ text: String) -> some View {
        Text("> \(text)")
    }

    private func processCommand() {
        guard !commandText.isEmpty, let gameState = gameEngine.gameState else { return }

        let input = commandText
        commandHistory.insert(input, at: 0)
        historyIndex = -1

        // Log command
        eventLogger.log("COMMAND: \(input)", type: .system, country: nil, turn: gameState.turn)

        // Try to parse command
        if let parsed = mlxManager.parseCommand(input, gameState: gameState) {
            executeCommand(parsed, gameState: gameState)
        } else if input.lowercased().contains("help") {
            showHelp()
        } else if input.lowercased().contains("what") || input.lowercased().contains("should") {
            // Ask MLX for advice
            Task {
                let advice = await mlxManager.getStrategicAdvice(situation: input, gameState: gameState)
                await MainActor.run {
                    responseMessage = "WOPR ANALYSIS:\n\n\(advice)"
                }
            }
        } else {
            responseMessage = "UNRECOGNIZED COMMAND\n\nType 'help' for available commands."
        }

        commandText = ""
    }

    private func executeCommand(_ command: ParsedCommand, gameState: GameState) {
        guard let player = gameState.getPlayerCountry() else { return }

        switch command.action {
        case .nuclearStrike:
            if let target = command.target {
                let warheads = Int(command.parameters["warheads"] ?? "1") ?? 1
                gameEngine.launchNuclearStrike(from: player.id, to: target, warheads: warheads)
                responseMessage = "NUCLEAR STRIKE AUTHORIZED\nTarget: \(gameState.getCountry(id: target)?.name ?? target)\nWarheads: \(warheads)"
                eventLogger.log("Nuclear strike launched at \(gameState.getCountry(id: target)?.name ?? target)", type: .nuclear, country: player.name, turn: gameState.turn)
            }

        case .declareWar:
            if let target = command.target {
                gameEngine.declareWar(aggressor: player.id, defender: target)
                responseMessage = "WAR DECLARED\nTarget: \(gameState.getCountry(id: target)?.name ?? target)"
                eventLogger.log("War declared on \(gameState.getCountry(id: target)?.name ?? target)", type: .war, country: player.name, turn: gameState.turn)
            }

        case .formAlliance:
            if let target = command.target {
                gameEngine.formAlliance(country1: player.id, country2: target)
                responseMessage = "ALLIANCE FORMED\nAlly: \(gameState.getCountry(id: target)?.name ?? target)"
                eventLogger.log("Alliance formed with \(gameState.getCountry(id: target)?.name ?? target)", type: .diplomacy, country: player.name, turn: gameState.turn)
            }

        case .economicAid:
            if let target = command.target {
                let amount = Int(command.parameters["amount"] ?? "5000000000") ?? 5_000_000_000
                gameEngine.economicDiplomacy(from: player.id, to: target, amount: amount)
                responseMessage = "ECONOMIC AID SENT\nRecipient: \(gameState.getCountry(id: target)?.name ?? target)\nAmount: $\(amount / 1_000_000_000)B"
                eventLogger.log("Economic aid sent to \(gameState.getCountry(id: target)?.name ?? target)", type: .economic, country: player.name, turn: gameState.turn)
            }

        case .endTurn:
            gameEngine.endTurn()
            responseMessage = "TURN ENDED\nProcessing AI moves..."
            eventLogger.log("Turn ended", type: .system, country: nil, turn: gameState.turn)

        case .showStatus:
            responseMessage = generateStatusReport(gameState: gameState)

        case .help:
            showHelp()

        case .covertOps:
            responseMessage = "COVERT OPERATIONS\nFeature in development"
        }
    }

    private func showHelp() {
        responseMessage = """
        WOPR TERMINAL COMMAND REFERENCE
        ════════════════════════════════════════

        NUCLEAR COMMANDS:
        > launch nuke at [country]
        > launch [number] nukes at [country]
        > nuclear strike [country]

        MILITARY COMMANDS:
        > declare war on [country]
        > attack [country]

        DIPLOMATIC COMMANDS:
        > form alliance with [country]
        > ally with [country]
        > give $5B to [country]
        > economic aid [country]

        INTELLIGENCE:
        > what should i do?
        > analyze situation
        > recommend action

        UTILITY:
        > status report / sitrep
        > end turn / pass
        > help

        AI ASSISTANCE:
        Ask questions in natural language and MLX will provide strategic analysis.

        Examples:
        > "Should I strike Russia?"
        > "What's the best diplomatic move?"
        > "How do I win without nukes?"

        ════════════════════════════════════════
        """
    }

    private func generateStatusReport(gameState: GameState) -> String {
        guard let player = gameState.getPlayerCountry() else {
            return "ERROR: Player country not found"
        }

        let nuclearPowers = gameState.countries.filter { !$0.isDestroyed && $0.nuclearWarheads > 0 }.count

        return """
        ════════════════════════════════════════
        SITUATION REPORT - TURN \(gameState.turn)
        ════════════════════════════════════════

        YOUR NATION: \(player.flag) \(player.name)
        DEFCON LEVEL: \(gameState.defconLevel.rawValue) - \(gameState.defconLevel.description)

        NUCLEAR CAPABILITIES:
        • Warheads: \(player.nuclearWarheads)
        • ICBMs: \(player.icbmCount)
        • SLBMs: \(player.submarineLaunchedMissiles)
        • Bombers: \(player.bombers)

        GLOBAL STATUS:
        • Nuclear Powers: \(nuclearPowers)
        • Active Wars: \(gameState.activeWars.count)
        • Total Casualties: \(gameState.totalCasualties.formatted())
        • Global Radiation: \(gameState.globalRadiation)
        • Treaties: \(gameState.treaties.count)

        ECONOMIC:
        • Your GDP: $\(String(format: "%.2f", player.gdp))T
        • Population: \(player.population)M

        MILITARY:
        • Wars: \(player.atWarWith.count)
        • Military Strength: \(player.militaryStrength)/100

        ════════════════════════════════════════
        """
    }
}

// MARK: - Event Integration

extension GameEngine {
    func logAIMove(country: Country, action: String) {
        // This will be called from processAITurns
        addLog("\(country.flag) \(country.name): \(action)", type: .info)
    }

    func logNationalEvent(country: String, event: String, type: LogType = .info) {
        addLog("[\(country)] \(event)", type: type)
    }
}

#Preview {
    TextCommandInterface()
        .environmentObject(GameEngine())
}
