//
//  AntarcticPanel.swift
//  Global Thermal Nuclear War
//
//  3.36.0: the Antarctic programme in the Antarctica dossier (unclaimed or held): treaty standing, stations, and
//  the orders (build a station, leave / rejoin / renegotiate the treaty). Each order uses one action; a button the
//  game can't carry out now is disabled and says why. Both skins; VoiceOver reads each button with its cost.
//  Repository: https://github.com/kochj23/GTNW
//

import SwiftUI

struct AntarcticPanel: View {
    @EnvironmentObject var gameEngine: GameEngine
    @ObservedObject var gameState: GameState

    var body: some View {
        let year = gameState.currentYear
        let cost = Antarctica.stationCost(year: year)
        let standing = gameState.antarcticStanding
        let busy = gameState.actionsRemaining == 0 || gameEngine.isProcessingAITurn || gameState.gameOver
        VStack(alignment: .leading, spacing: 4) {
            Text("ANTARCTIC PROGRAM").font(ThemeFont.mono(10, .bold)).foregroundColor(GTNWColors.terminalAmber)
            ForEach(Antarctica.programLines(gameState), id: \.self) { line in
                Text(verbatim: line).font(ThemeFont.mono(9)).foregroundColor(GTNWColors.neonCyan).fixedSize(horizontal: false, vertical: true)
            }
            if year >= Antarctica.firstStationYear {
                let problem = gameEngine.antarcticProblem(.station)
                Button(String(format: "BUILD %@ ($%.2fB)", year < 1946 ? "BASE" : "RESEARCH STATION", cost)) { gameEngine.runAntarcticOrder(.station) }
                    .buttonStyle(ThemedButtonStyle(color: GTNWColors.neonCyan))
                    .disabled(busy || problem != nil)
                    .help(problem ?? "Science prestige now and every year. On ice you hold, each station counts as one INVEST of development.")
                    .accessibilityLabel(String(format: "Build a research station in Antarctica, %.2f billion dollars, one action", cost))
            }
            if standing != .noTreaty {
                HStack(spacing: 6) {
                    if standing == .party {
                        treatyButton(.leave, "LEAVE TREATY", GTNWColors.terminalRed, busy,
                                     "Notice of withdrawal: it takes effect in two years. The signatories will not like it.")
                        treatyButton(.renegotiate, "RENEGOTIATE", GTNWColors.neonCyan, busy, gameEngine.renegotiationOutlook(gameState).why)
                    } else {
                        treatyButton(.join, "REJOIN TREATY", GTNWColors.terminalGreen, busy, "Sign the Antarctic Treaty again; the signatories welcome it.")
                    }
                }
            }
        }
        .padding(.top, 4)
    }

    private func treatyButton(_ op: AntarcticOrder, _ title: String, _ color: Color, _ busy: Bool, _ help: String) -> some View {
        let problem = gameEngine.antarcticProblem(op)
        return Button(title) { gameEngine.runAntarcticOrder(op) }
            .buttonStyle(ThemedButtonStyle(color: color))
            .disabled(busy || problem != nil)
            .help(problem ?? help)
            .accessibilityLabel(op.title.capitalized + ", one action")
            .accessibilityHint(problem ?? help)
    }
}
