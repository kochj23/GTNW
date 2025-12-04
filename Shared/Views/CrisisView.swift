//
//  CrisisView.swift
//  Global Thermal Nuclear War
//
//  UI for handling crisis events
//  Created by Jordan Koch on 2025-12-03.
//

import SwiftUI

struct DetailedCrisisView: View {
    let crisis: CrisisEvent
    let gameState: GameState
    let onResolve: (Int) -> Void
    @State private var selectedOption: Int? = nil
    @ObservedObject var crisisManager: CrisisManager

    var body: some View {
        ZStack {
            // Dark overlay
            Color.black.opacity(0.9)
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) {
                // Crisis Header
                crisisHeader

                // Crisis Description
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Description
                        Text(crisis.description)
                            .font(.system(size: 16, design: .monospaced))
                            .foregroundColor(AppSettings.terminalGreen)
                            .padding()
                            .background(Color.black.opacity(0.5))
                            .border(AppSettings.terminalGreen, width: 1)

                        // Options
                        ForEach(Array(crisis.options.enumerated()), id: \.offset) { index, option in
                            crisisOptionCard(option: option, index: index)
                        }
                    }
                    .padding()
                }

                // Action Buttons
                HStack(spacing: 20) {
                    if let selected = selectedOption {
                        Button(action: {
                            withAnimation {
                                onResolve(selected)
                            }
                        }) {
                            Text("CONFIRM DECISION")
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                .foregroundColor(.black)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(AppSettings.terminalGreen)
                        }

                        Button(action: {
                            selectedOption = nil
                        }) {
                            Text("RECONSIDER")
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                .foregroundColor(.black)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(AppSettings.terminalAmber)
                        }
                    }
                }
                .padding()
                .background(Color.black)
            }
        }
    }

    private var crisisHeader: some View {
        VStack(spacing: 10) {
            // Severity Badge
            HStack(spacing: 15) {
                Text(crisis.severity.description)
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundColor(crisis.severity.color)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.black)
                    .border(crisis.severity.color, width: 3)

                if let timeLimit = crisis.timeLimit, crisisManager.crisisTimeRemaining > 0 {
                    HStack(spacing: 5) {
                        Image(systemName: "clock.fill")
                        Text("\(crisisManager.crisisTimeRemaining)s")
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                    }
                    .foregroundColor(crisisManager.crisisTimeRemaining < 15 ? AppSettings.terminalRed : AppSettings.terminalAmber)
                }
            }

            // Title
            Text(crisis.title)
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .foregroundColor(crisis.severity.color)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
        .background(Color.black)
        .border(crisis.severity.color, width: 3)
    }

    private func crisisOptionCard(option: CrisisOption, index: Int) -> some View {
        Button(action: {
            selectedOption = index
        }) {
            VStack(alignment: .leading, spacing: 10) {
                // Option Title
                HStack {
                    Text(option.title)
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(selectedOption == index ? .black : AppSettings.terminalGreen)

                    Spacer()

                    if selectedOption == index {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.black)
                            .font(.system(size: 24))
                    }
                }

                // Description
                Text(option.description)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(selectedOption == index ? .black : AppSettings.terminalGreen.opacity(0.8))

                // Advisor Recommendation
                if let advisor = option.advisorRecommendation {
                    HStack {
                        Image(systemName: "person.fill")
                        Text("Recommended by: \(advisor)")
                            .font(.system(size: 12, design: .monospaced))
                            .italic()
                    }
                    .foregroundColor(selectedOption == index ? .black.opacity(0.7) : AppSettings.terminalAmber)
                }

                // Success Chance
                if option.successChance < 1.0 {
                    HStack {
                        Image(systemName: "dice.fill")
                        Text("Success Chance: \(Int(option.successChance * 100))%")
                            .font(.system(size: 12, design: .monospaced))
                    }
                    .foregroundColor(selectedOption == index ? .black.opacity(0.7) : getSuccessColor(option.successChance))
                }
            }
            .padding()
            .background(selectedOption == index ? AppSettings.terminalGreen : Color.black.opacity(0.3))
            .border(selectedOption == index ? AppSettings.terminalGreen : AppSettings.terminalGreen.opacity(0.5), width: selectedOption == index ? 3 : 1)
        }
        .buttonStyle(.plain)
    }

    private func getSuccessColor(_ chance: Double) -> Color {
        switch chance {
        case 0.8...: return AppSettings.terminalGreen
        case 0.5..<0.8: return AppSettings.terminalAmber
        default: return AppSettings.terminalRed
        }
    }
}

#Preview {
    let gameState = GameState(playerCountryID: "USA")
    let crisis = CrisisEvent(
        type: .falseAlarm,
        severity: .critical,
        title: "FALSE ALARM DETECTED",
        description: "NORAD has detected 200 ICBMs",
        affectedCountries: ["RUS"],
        turn: 5,
        timeLimit: 60,
        options: [
            CrisisOption(
                title: "Launch Counterstrike",
                description: "Launch all ICBMs",
                advisorRecommendation: "Pete Hegseth",
                consequences: CrisisConsequences(message: "War declared")
            )
        ]
    )

    DetailedCrisisView(
        crisis: crisis,
        gameState: gameState,
        onResolve: { _ in },
        crisisManager: CrisisManager()
    )
}
