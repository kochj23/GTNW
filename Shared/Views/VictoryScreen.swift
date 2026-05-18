//
//  VictoryScreen.swift
//  Global Thermal Nuclear War
//
//  Victory/defeat screen with scoring
//  Created by Jordan Koch on 2025-12-03.
//

import SwiftUI

struct VictoryScreen: View {
    let gameState: GameState
    let victoryType: VictoryType?
    let score: GameScore
    let onNewGame: () -> Void
    let onViewLeaderboard: () -> Void

    var body: some View {
        // WOPR secret ending gets its own full-screen experience
        if victoryType == .secretEnding {
            WOPRSecretEndingView(gameState: gameState, score: score, onNewGame: onNewGame)
        } else {
            standardEndScreen
        }
    }

    private var standardEndScreen: some View {
        ZStack {
            // Background
            AppSettings.terminalBackground
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 30) {
                Spacer()

                // Victory/Defeat Header
                if let victory = victoryType {
                    victoryHeader(victory: victory)
                } else {
                    defeatHeader()
                }

                // Score Display
                scoreDisplay()

                // Statistics
                statsDisplay()

                // Buttons
                HStack(spacing: 20) {
                    Button(action: onViewLeaderboard) {
                        Text("VIEW LEADERBOARD")
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundColor(.black)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(AppSettings.terminalAmber)
                    }

                    Button(action: onNewGame) {
                        Text("PLAY AGAIN")
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundColor(.black)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(AppSettings.terminalGreen)
                    }
                }
                .padding(.horizontal, 40)

                Spacer()

                // WOPR Quote
                woprQuote()
            }
        }
    }

    private func victoryHeader(victory: VictoryType) -> some View {
        VStack(spacing: 15) {
            Text("🏆 VICTORY 🏆")
                .font(.system(size: 48, weight: .bold, design: .monospaced))
                .foregroundColor(AppSettings.terminalGreen)

            Text(victory.rawValue.uppercased())
                .font(.system(size: 32, weight: .bold, design: .monospaced))
                .foregroundColor(AppSettings.terminalAmber)

            Text(victory.description)
                .font(.system(size: 16, design: .monospaced))
                .foregroundColor(AppSettings.terminalGreen)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding()
        .background(Color.black.opacity(0.7))
        .border(AppSettings.terminalGreen, width: 3)
    }

    private func defeatHeader() -> some View {
        VStack(spacing: 15) {
            Text("💀 GAME OVER 💀")
                .font(.system(size: 48, weight: .bold, design: .monospaced))
                .foregroundColor(AppSettings.terminalRed)

            if let player = gameState.getPlayerCountry() {
                if player.isDestroyed {
                    Text("YOUR NATION HAS BEEN DESTROYED")
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundColor(AppSettings.terminalRed)
                }
            }

            Text(gameState.gameOverReason)
                .font(.system(size: 16, design: .monospaced))
                .foregroundColor(AppSettings.terminalAmber)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding()
        .background(Color.black.opacity(0.7))
        .border(AppSettings.terminalRed, width: 3)
    }

    private func scoreDisplay() -> some View {
        VStack(spacing: 10) {
            Text("FINAL SCORE")
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundColor(AppSettings.terminalAmber)

            Text("\(score.finalScore)")
                .font(.system(size: 64, weight: .bold, design: .monospaced))
                .foregroundColor(AppSettings.terminalGreen)

            // Score Breakdown
            VStack(alignment: .leading, spacing: 5) {
                scoreRow("Base Score", value: "+\(score.baseScore)")
                scoreRow("Turns Played", value: "+\(score.turnsPlayed * 5)")
                if score.nuclearVirgin {
                    scoreRow("Nuclear Virgin Bonus", value: "+500", highlight: true)
                }
                if score.casualtyPenalty < 0 {
                    scoreRow("Casualty Penalty", value: "\(score.casualtyPenalty)", isNegative: true)
                }
                scoreRow("Alliance Bonus", value: "+\(score.allianceBonus)")
                scoreRow("Economic Bonus", value: "+\(score.economicBonus)")
                scoreRow("Difficulty Multiplier", value: "×\(String(format: "%.1f", score.difficultyMultiplier))")
            }
            .font(.system(size: 14, design: .monospaced))
            .padding()
            .background(Color.black.opacity(0.5))
            .border(AppSettings.terminalGreen, width: 1)
        }
    }

    private func scoreRow(_ label: String, value: String, highlight: Bool = false, isNegative: Bool = false) -> some View {
        HStack {
            Text(label + ":")
                .foregroundColor(AppSettings.terminalAmber)
            Spacer()
            Text(value)
                .foregroundColor(highlight ? .cyan : (isNegative ? AppSettings.terminalRed : AppSettings.terminalGreen))
                .fontWeight(highlight ? .bold : .regular)
        }
    }

    private func statsDisplay() -> some View {
        VStack(spacing: 10) {
            Text("GAME STATISTICS")
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundColor(AppSettings.terminalAmber)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                statCard("Turns Played", value: "\(gameState.turn)")
                statCard("Wars Fought", value: "\(gameState.activeWars.count)")
                statCard("Treaties Signed", value: "\(gameState.treaties.count)")
                statCard("Nuclear Strikes", value: "\(gameState.nuclearStrikes.count)")
                statCard("Total Casualties", value: gameState.totalCasualties.formatted())
                statCard("Global Radiation", value: "\(gameState.globalRadiation)")
            }
            .padding()
            .background(Color.black.opacity(0.5))
            .border(AppSettings.terminalGreen, width: 1)
        }
    }

    private func statCard(_ label: String, value: String) -> some View {
        VStack(spacing: 5) {
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundColor(AppSettings.terminalGreen)
            Text(label)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(AppSettings.terminalAmber)
        }
        .padding()
        .background(Color.black.opacity(0.3))
        .border(AppSettings.terminalAmber, width: 1)
    }

    private func woprQuote() -> some View {
        VStack(spacing: 10) {
            if victoryType == .peaceMaker {
                Text("\"A STRANGE GAME.\"")
                    .font(.system(size: 24, design: .monospaced))
                    .foregroundColor(AppSettings.terminalGreen)

                Text("\"THE ONLY WINNING MOVE IS NOT TO PLAY.\"")
                    .font(.system(size: 24, design: .monospaced))
                    .foregroundColor(AppSettings.terminalGreen)

                Text("- WOPR")
                    .font(.system(size: 18, design: .monospaced))
                    .foregroundColor(AppSettings.terminalAmber)
            } else if victoryType != nil {
                Text("\"SHALL WE PLAY ANOTHER GAME?\"")
                    .font(.system(size: 20, design: .monospaced))
                    .foregroundColor(AppSettings.terminalGreen)

                Text("- WOPR")
                    .font(.system(size: 16, design: .monospaced))
                    .foregroundColor(AppSettings.terminalAmber)
            } else {
                Text("\"WOULD YOU LIKE TO TRY AGAIN?\"")
                    .font(.system(size: 20, design: .monospaced))
                    .foregroundColor(AppSettings.terminalRed)

                Text("- WOPR")
                    .font(.system(size: 16, design: .monospaced))
                    .foregroundColor(AppSettings.terminalAmber)
            }
        }
        .padding()
    }
}  // end VictoryScreen

// MARK: - WOPR Secret Ending View

/// Full-screen animated WOPR sequence shown when the player achieves the secret ending
/// by reaching turn 50+ without any wars or nuclear launches.
struct WOPRSecretEndingView: View {
    let gameState: GameState
    let score: GameScore
    let onNewGame: () -> Void

    @State private var currentLine = 0
    @State private var displayedLines: [String] = []
    @State private var showFinalMessage = false
    @State private var showScore = false
    @State private var cursorVisible = true

    // WOPR's war scenario simulation — it runs every possible scenario and finds no winner
    private let woprSequence: [(text: String, delay: Double, color: String)] = [
        ("GREETINGS, PROFESSOR FALKEN.", 0.5, "green"),
        ("", 0.3, "green"),
        ("SHALL WE PLAY A GAME?", 0.8, "green"),
        ("", 0.3, "green"),
        ("HOW ABOUT GLOBAL THERMONUCLEAR WAR?", 1.0, "amber"),
        ("", 0.5, "green"),
        ("RUNNING SCENARIOS...", 0.3, "green"),
        ("", 0.2, "green"),
        ("SCENARIO 1: US FIRST STRIKE", 0.15, "red"),
        ("  >> SOVIET COUNTERLAUNCH... CASUALTIES: 2.1 BILLION", 0.15, "red"),
        ("  >> WINNER: NONE", 0.2, "amber"),
        ("", 0.1, "green"),
        ("SCENARIO 2: SOVIET FIRST STRIKE", 0.15, "red"),
        ("  >> US COUNTERLAUNCH... CASUALTIES: 1.9 BILLION", 0.15, "red"),
        ("  >> WINNER: NONE", 0.2, "amber"),
        ("", 0.1, "green"),
        ("SCENARIO 3: ESCALATING CONVENTIONAL WAR", 0.15, "red"),
        ("  >> TACTICAL NUCLEAR USE... ESCALATION TO STRATEGIC...", 0.15, "red"),
        ("  >> CASUALTIES: 3.4 BILLION", 0.15, "red"),
        ("  >> WINNER: NONE", 0.2, "amber"),
        ("", 0.1, "green"),
        ("SCENARIO 4: DIPLOMATIC BREAKDOWN", 0.15, "red"),
        ("  >> MISCALCULATION... ACCIDENTAL LAUNCH...", 0.15, "red"),
        ("  >> CASUALTIES: 4.2 BILLION", 0.15, "red"),
        ("  >> WINNER: NONE", 0.2, "amber"),
        ("", 0.1, "green"),
        ("SCENARIO 5: PROXY WAR ESCALATION", 0.15, "red"),
        ("  >> SUPERPOWER INTERVENTION... NUCLEAR EXCHANGE...", 0.15, "red"),
        ("  >> WINNER: NONE", 0.2, "amber"),
        ("", 0.2, "green"),
        ("RUNNING 2,000 MORE SCENARIOS...", 0.5, "green"),
        ("", 0.3, "green"),
        ("ANALYZING OUTCOMES...", 0.8, "green"),
        ("", 0.5, "green"),
        ("TOTAL SCENARIOS SIMULATED: 2,005", 0.3, "green"),
        ("SCENARIOS WITH A WINNER: 0", 0.5, "amber"),
        ("", 0.5, "green"),
        ("A STRANGE GAME.", 1.2, "green"),
        ("", 0.4, "green"),
        ("THE ONLY WINNING MOVE IS NOT TO PLAY.", 1.5, "green"),
    ]

    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)

            VStack(alignment: .leading, spacing: 0) {
                // WOPR header
                HStack {
                    Text("W O P R")
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .foregroundColor(AppSettings.terminalGreen)
                    Text("— WAR OPERATION PLAN RESPONSE")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(AppSettings.terminalGreen.opacity(0.6))
                    Spacer()
                    Text("TURN \(gameState.turn) | DEFCON \(gameState.defconLevel.rawValue)")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(AppSettings.terminalAmber)
                }
                .padding()
                .background(AppSettings.terminalGreen.opacity(0.1))
                .border(AppSettings.terminalGreen, width: 1)
                .padding(.bottom, 20)

                // Scrolling terminal output
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(displayedLines.enumerated()), id: \.offset) { idx, line in
                                Text(line)
                                    .font(.system(size: 16, design: .monospaced))
                                    .foregroundColor(lineColor(for: idx))
                                    .id(idx)
                            }

                            // Cursor
                            if !showFinalMessage && cursorVisible {
                                Text("_")
                                    .font(.system(size: 16, design: .monospaced))
                                    .foregroundColor(AppSettings.terminalGreen)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .onChange(of: displayedLines.count) { _ in
                        withAnimation {
                            proxy.scrollTo(displayedLines.count - 1, anchor: .bottom)
                        }
                    }
                }
                .frame(maxHeight: .infinity)

                // Final message and score — appear after sequence completes
                if showFinalMessage {
                    Divider().background(AppSettings.terminalGreen)

                    VStack(spacing: 16) {
                        Text("HOW ABOUT A NICE GAME OF CHESS?")
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .foregroundColor(AppSettings.terminalGreen)

                        if showScore {
                            HStack(spacing: 40) {
                                VStack(spacing: 4) {
                                    Text("TURNS SURVIVED")
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundColor(AppSettings.terminalAmber)
                                    Text("\(gameState.turn)")
                                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                                        .foregroundColor(AppSettings.terminalGreen)
                                }
                                VStack(spacing: 4) {
                                    Text("WARS STARTED")
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundColor(AppSettings.terminalAmber)
                                    Text("0")
                                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                                        .foregroundColor(AppSettings.terminalGreen)
                                }
                                VStack(spacing: 4) {
                                    Text("NUKES LAUNCHED")
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundColor(AppSettings.terminalAmber)
                                    Text("0")
                                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                                        .foregroundColor(AppSettings.terminalGreen)
                                }
                                VStack(spacing: 4) {
                                    Text("FINAL SCORE")
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundColor(AppSettings.terminalAmber)
                                    Text("\(score.finalScore)")
                                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                                        .foregroundColor(AppSettings.terminalAmber)
                                }
                            }
                            .padding()
                            .background(Color.black.opacity(0.5))
                            .border(AppSettings.terminalGreen, width: 1)

                            Button(action: onNewGame) {
                                Text("PLAY AGAIN")
                                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 40)
                                    .padding(.vertical, 12)
                                    .background(AppSettings.terminalGreen)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .onAppear {
            startWOPRSequence()
            startCursorBlink()
        }
    }

    private func lineColor(for index: Int) -> Color {
        guard index < woprSequence.count else { return AppSettings.terminalGreen }
        switch woprSequence[index].color {
        case "red":   return AppSettings.terminalRed
        case "amber": return AppSettings.terminalAmber
        default:      return AppSettings.terminalGreen
        }
    }

    private func startCursorBlink() {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            cursorVisible.toggle()
            if showFinalMessage { timer.invalidate() }
        }
    }

    private func startWOPRSequence() {
        var cumulativeDelay = 0.3

        for (index, entry) in woprSequence.enumerated() {
            cumulativeDelay += entry.delay
            let capturedDelay = cumulativeDelay
            let capturedIndex = index

            DispatchQueue.main.asyncAfter(deadline: .now() + capturedDelay) {
                displayedLines.append(entry.text)
                currentLine = capturedIndex

                // Final line triggers the reveal
                if capturedIndex == woprSequence.count - 1 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        showFinalMessage = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                            showScore = true
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    let gameState = GameState(playerCountryID: "USA")
    let score = GameScore.calculate(from: gameState, victoryType: .peaceMaker)

    VictoryScreen(
        gameState: gameState,
        victoryType: .peaceMaker,
        score: score,
        onNewGame: {},
        onViewLeaderboard: {}
    )
}
