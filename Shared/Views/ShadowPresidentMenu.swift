//
//  ShadowPresidentMenu.swift
//  Global Thermal Nuclear War
//
//  Shadow President-style actions menu
//  Repository: https://github.com/kochj23/GTNW
//  Created by Jordan Koch on 2025-12-03.
//

import SwiftUI

struct ShadowPresidentMenu: View {
    /// Shadow Pack animation playing after EXECUTE (nil = none); the sheet closes when it finishes or is clicked.
    @State private var playingAnimation: String?
    let player: Country
    let target: Country
    let gameState: GameState
    /// Called with the action and the advice the responsible cabinet post gave on it.
    let onExecute: (PresidentialAction, ActionAdvice?) -> Void
    @Environment(\.dismiss) var dismiss

    @State private var selectedCategory: ActionCategory = .diplomatic
    @State private var selectedAction: PresidentialAction?

    private var filteredActions: [PresidentialAction] {
        PresidentialAction.allCases.filter {
            $0.category == selectedCategory &&
            $0.isAvailable(on: gameState.currentDate, in: gameState)
        }
    }

    var body: some View {
        ZStack {
            GTNWColors.spaceBackground

            HStack(spacing: 0) {
                // Categories sidebar
                VStack(spacing: 8) {
                    Text("CATEGORIES")
                        .font(GTNWFonts.terminal(size: 14, weight: .bold))
                        .foregroundColor(GTNWColors.terminalAmber)
                        .padding()

                    ForEach(ActionCategory.allCases, id: \.self) { category in
                        categoryButton(category)
                    }

                    Spacer()
                }
                .frame(width: FontScale.w(250))
                .background(GTNWColors.glassPanelDark)

                // Actions list
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredActions) { action in
                            actionCard(action)
                        }
                    }
                    .padding()
                }
                .frame(minWidth: FontScale.w(500))

                // Details panel
                if let action = selectedAction {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            // Title
                            Text(action.rawValue.uppercased())
                                .font(GTNWFonts.subheading())
                                .foregroundColor(selectedCategory.color)

                            // Description
                            Text(action.description)
                                .font(GTNWFonts.terminal(size: 14))
                                .foregroundColor(GTNWColors.terminalGreen)

                            // Risk
                            HStack {
                                Text("RISK:")
                                    .font(GTNWFonts.caption())
                                Spacer()
                                Text(action.riskLevel.rawValue)
                                    .font(GTNWFonts.terminal(size: 14, weight: .bold))
                                    .foregroundColor(action.riskLevel.color)
                            }
                            .padding()
                            .background(action.riskLevel.color.opacity(0.1))
                            .cornerRadius(8)

                            // Success chance
                            if action.successChance < 1.0 {
                                HStack {
                                    Text("SUCCESS:")
                                        .font(GTNWFonts.caption())
                                    Spacer()
                                    Text("\(Int(action.successChance * 100))%")
                                        .font(GTNWFonts.terminal(size: 14, weight: .bold))
                                }
                            }

                            // Cost
                            if action.cost > 0 {
                                HStack {
                                    Text("COST:")
                                        .font(GTNWFonts.caption())
                                    Spacer()
                                    Text("$\(action.cost / 1_000_000_000)B")
                                        .font(GTNWFonts.terminal(size: 14, weight: .bold))
                                        .foregroundColor(GTNWColors.neonCyan)
                                }
                            }

                            // The responsible advisor weighs in before you commit
                            let advice = AdviceEngine.advise(action: action, player: player, target: target, gameState: gameState)
                            AdvicePanel(advice: advice)

                            // Execute button
                            Button(action: {
                                onExecute(action, advice)
                                let media = ShadowPack.media(forActionCase: String(describing: action))
                                if let sound = media.sound { ShadowPack.shared.play(sound) }
                                if let anim = media.animation, let a = ShadowPack.shared.animation(anim) {
                                    playingAnimation = anim
                                    DispatchQueue.main.asyncAfter(deadline: .now() + min(a.duration, 6)) {
                                        if playingAnimation == anim { playingAnimation = nil; dismiss() }
                                    }
                                } else {
                                    dismiss()
                                }
                            }) {
                                HStack {
                                    Image(systemName: "play.fill")
                                    Text("EXECUTE")
                                }
                                .font(GTNWFonts.terminal(size: 16, weight: .bold))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(selectedCategory.color)
                                .cornerRadius(12)
                            }
                            .hoverScale()

                            if action.riskLevel == .catastrophic {
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                    Text("EXTREME RISK")
                                }
                                .foregroundColor(GTNWColors.terminalRed)
                                .font(GTNWFonts.caption())
                                .padding()
                                .background(GTNWColors.terminalRed.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }
                        .padding()
                    }
                    .frame(width: FontScale.w(350))
                    .background(GTNWColors.glassPanelDark)
                }
            }
        }
        .frame(minWidth: FontScale.w(1100), minHeight: FontScale.h(700))
        .overlay {
            if let anim = playingAnimation {
                ZStack {
                    Color.black.opacity(0.85)
                    PackAnimationView(anim) { EmptyView() }
                        .frame(maxWidth: FontScale.w(520), maxHeight: FontScale.h(520))
                }
                .onTapGesture { playingAnimation = nil; dismiss() }
                .accessibilityLabel("Action animation, click to skip")
            }
        }
    }

    private func categoryButton(_ category: ActionCategory) -> some View {
        Button(action: {
            selectedCategory = category
            selectedAction = nil
        }) {
            HStack(spacing: 10) {
                Image(systemName: category.icon)
                    .foregroundColor(category.color)
                    .frame(width: FontScale.w(24))
                Text(category.rawValue)
                    .font(GTNWFonts.terminal(size: 11, weight: .bold))
                    .foregroundColor(selectedCategory == category ? .black : category.color)
                Spacer()
            }
            .padding(10)
            .background(selectedCategory == category ? category.color : Color.clear)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(category.color.opacity(0.5), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .hoverScale(scale: 1.03)
    }

    private func actionCard(_ action: PresidentialAction) -> some View {
        Button(action: { selectedAction = action }) {
            HStack(spacing: 12) {
                Circle()
                    .fill(action.riskLevel.color)
                    .frame(width: FontScale.w(10), height: FontScale.h(10))

                VStack(alignment: .leading, spacing: 4) {
                    Text(action.rawValue)
                        .font(GTNWFonts.terminal(size: 14, weight: .semibold))
                        .foregroundColor(selectedAction == action ? .black : GTNWColors.terminalGreen)

                    Text(action.description)
                        .font(GTNWFonts.terminal(size: 11))
                        .foregroundColor(selectedAction == action ? .black.opacity(0.7) : GTNWColors.terminalAmber.opacity(0.8))
                        .lineLimit(2)
                }

                Spacer()

                if action.cost > 0 {
                    Text("$\(action.cost / 1_000_000_000)B")
                        .font(GTNWFonts.terminal(size: 11))
                        .foregroundColor(selectedAction == action ? .black : GTNWColors.neonCyan)
                }
            }
            .padding(12)
            .background(selectedAction == action ? selectedCategory.color : GTNWColors.glassPanelMedium)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        selectedAction == action ? selectedCategory.color : action.riskLevel.color.opacity(0.3),
                        lineWidth: selectedAction == action ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .hoverScale(scale: 1.02)
    }
}
