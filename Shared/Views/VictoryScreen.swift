//
//  VictoryScreen.swift
//  Global Thermal Nuclear War
//
//  Victory/defeat screen with scoring
//  Created by Jordan Koch & Claude Code on 2025-12-03.
//

import SwiftUI

struct VictoryScreen: View {
    let gameState: GameState
    let victoryType: VictoryType?
    let score: GameScore
    let onNewGame: () -> Void
    let onViewLeaderboard: () -> Void

    var body: some View {
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
            if victoryType == .peaceMaker || victoryType == .secretEnding {
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
