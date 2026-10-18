//
//  LeaderboardView.swift
//  Global Thermal Nuclear War
//
//  High scores leaderboard
//  Created by Jordan Koch on 2025-12-03.
//

import SwiftUI

struct LeaderboardView: View {
    @StateObject var leaderboardManager = LeaderboardManager(records: GameStoreService.shared.records.leaderboard)
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("🏆 WOPR HIGH SCORES 🏆")
                    .font(.scaled(size: 32, weight: .bold, design: .monospaced))
                    .foregroundColor(AppSettings.terminalGreen)

                Spacer()

                Button("CLOSE") {
                    dismiss()
                }
                .buttonStyle(ThemedButtonStyle(color: AppSettings.terminalRed))
            }
            .padding()
            .background(Color.black)
            .border(AppSettings.terminalGreen, width: 3)

            // Column Headers
            HStack {
                Text("RANK")
                    .frame(width: FontScale.w(80), alignment: .center)
                Text("PLAYER")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("SCORE")
                    .frame(width: FontScale.w(120), alignment: .trailing)
                Text("VICTORY")
                    .padding(.leading, 12)
                    .frame(width: FontScale.w(200), alignment: .leading)
                Text("TURNS")
                    .frame(width: FontScale.w(80), alignment: .center)
                Text("DATE")
                    .frame(width: FontScale.w(100), alignment: .center)
            }
            .font(.scaled(size: 14, weight: .bold, design: .monospaced))
            .foregroundColor(AppSettings.terminalAmber)
            .padding()
            .background(Color.black.opacity(0.5))
            .border(AppSettings.terminalAmber, width: 1)
            .padding(.horizontal)
            .padding(.top)

            // Leaderboard Entries
            ScrollView {
                LazyVStack(spacing: 5) {
                    ForEach(leaderboardManager.getTopEntries(count: 25)) { entry in
                        leaderboardRow(entry: entry)
                    }

                    if leaderboardManager.entries.isEmpty {
                        Text("NO SCORES YET")
                            .font(.scaled(size: 20, design: .monospaced))
                            .foregroundColor(AppSettings.terminalAmber)
                            .padding(40)
                        Text("Play a game to set the first record!")
                            .font(.scaled(size: 14, design: .monospaced))
                            .foregroundColor(AppSettings.terminalGreen)
                    }
                }
                .padding()
            }
        }
        .background(AppSettings.terminalBackground)
        .frame(minWidth: FontScale.w(1000), minHeight: FontScale.h(700))
    }

    private func leaderboardRow(entry: LeaderboardEntry) -> some View {
        HStack {
            // Rank
            Text("\(entry.rank)")
                .frame(width: FontScale.w(80), alignment: .center)
                .font(.scaled(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(rankColor(entry.rank))

            // Player
            Text(entry.playerName)
                .frame(maxWidth: .infinity, alignment: .leading)
                .font(.scaled(size: 16, design: .monospaced))
                .foregroundColor(AppSettings.terminalGreen)

            // Score
            Text("\(entry.score.finalScore)")
                .frame(width: FontScale.w(120), alignment: .trailing)
                .font(.scaled(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(AppSettings.terminalGreen)

            // Victory Type
            Text(entry.score.victoryType?.rawValue ?? "Defeat")
                .padding(.leading, 12)
                .frame(width: FontScale.w(200), alignment: .leading)
                .font(.scaled(size: 14, design: .monospaced))
                .foregroundColor(entry.score.victoryType != nil ? AppSettings.terminalGreen : AppSettings.terminalRed)

            // Turns
            Text("\(entry.score.turnsPlayed)")
                .frame(width: FontScale.w(80), alignment: .center)
                .font(.scaled(size: 16, design: .monospaced))
                .foregroundColor(AppSettings.terminalAmber)

            // Date
            Text(entry.formattedDate)
                .frame(width: FontScale.w(100), alignment: .center)
                .font(.scaled(size: 12, design: .monospaced))
                .foregroundColor(AppSettings.terminalAmber)
        }
        .padding(.vertical, 8)
        .padding(.horizontal)
        .background(entry.rank <= 3 ? rankColor(entry.rank).opacity(0.1) : Color.black.opacity(0.2))
        .border(entry.rank <= 3 ? rankColor(entry.rank) : AppSettings.terminalGreen.opacity(0.3), width: entry.rank <= 3 ? 2 : 1)
    }

    private func rankColor(_ rank: Int) -> Color {
        switch rank {
        case 1: return .yellow  // Gold
        case 2: return .gray    // Silver
        case 3: return .orange  // Bronze
        default: return AppSettings.terminalGreen
        }
    }
}

#Preview {
    LeaderboardView()
}
