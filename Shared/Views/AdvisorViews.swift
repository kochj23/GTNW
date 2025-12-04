//
//  AdvisorViews.swift
//  Global Thermal Nuclear War
//
//  Shadow President-style advisor consultation system
//  Trump administration 2025 cabinet
//

import SwiftUI

// MARK: - Advisor Grid View

/// Main grid view showing all advisors (Shadow President style)
struct AdvisorGridView: View {
    @EnvironmentObject var gameEngine: GameEngine
    @State private var selectedAdvisor: Advisor?

    let advisors: [Advisor]

    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("EXECUTIVE ADVISORS")
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundColor(AppSettings.terminalGreen)

                Spacer()

                // DEFCON indicator
                if let gameState = gameEngine.gameState {
                    DefconBadge(level: gameState.defconLevel)
                }
            }
            .padding()
            .background(Color.black)
            .border(AppSettings.terminalGreen, width: 2)

            // Advisor grid
            ScrollView {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(advisors) { advisor in
                        AdvisorCardView(advisor: advisor)
                            .onTapGesture {
                                selectedAdvisor = advisor
                            }
                    }
                }
                .padding()
            }
            .background(AppSettings.terminalBackground)
        }
        .sheet(item: $selectedAdvisor) { advisor in
            AdvisorDetailView(advisor: advisor)
        }
    }
}

// MARK: - Advisor Card View

/// Individual advisor card (portrait + stats)
struct AdvisorCardView: View {
    let advisor: Advisor

    var body: some View {
        VStack(spacing: 8) {
            // Portrait placeholder
            PlaceholderAdvisorImage(name: advisor.name, color: advisor.colorValue)
                .frame(width: 100, height: 100)
                .border(advisor.colorValue, width: 2)

            // Name
            Text(advisor.name)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(AppSettings.terminalGreen)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(height: 32)

            // Title
            Text(advisor.title)
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(AppSettings.terminalAmber)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(height: 28)

            // Primary stat based on role
            if advisor.title.contains("President") {
                MiniStatBar(label: "App", value: advisor.publicSupport, color: advisor.publicSupport > 50 ? .green : .red)
            } else if advisor.title.contains("Secretary") || advisor.title.contains("Director") {
                MiniStatBar(label: "Exp", value: advisor.expertise, color: .amber)
            } else {
                MiniStatBar(label: "Loy", value: advisor.loyalty, color: .green)
            }
        }
        .padding(8)
        .background(Color.black.opacity(0.8))
        .border(AppSettings.terminalGreen, width: 1)
        .frame(height: 220)
    }
}

// MARK: - Advisor Detail View

/// Detailed view of a single advisor
struct AdvisorDetailView: View {
    let advisor: Advisor
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var gameEngine: GameEngine

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(advisor.title.uppercased())
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundColor(AppSettings.terminalGreen)

                Spacer()

                Button("DISMISS") {
                    dismiss()
                }
                .font(.system(.body, design: .monospaced))
                .foregroundColor(AppSettings.terminalRed)
            }
            .padding()
            .background(Color.black)
            .border(AppSettings.terminalGreen, width: 2)

            ScrollView {
                VStack(spacing: 20) {
                    // Portrait and Bio Section
                    HStack(alignment: .top, spacing: 30) {
                        // Portrait
                        VStack(spacing: 10) {
                            PlaceholderAdvisorImage(name: advisor.name, color: advisor.colorValue)
                                .frame(width: 200, height: 200)
                                .border(advisor.colorValue, width: 3)

                            Text(advisor.name)
                                .font(.system(size: 20, weight: .bold, design: .monospaced))
                                .foregroundColor(advisor.colorValue)

                            Text(advisor.department)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(AppSettings.terminalGreen)
                                .multilineTextAlignment(.center)
                        }

                        // Stats
                        VStack(alignment: .leading, spacing: 12) {
                            Text("PROFILE:")
                                .font(.system(.headline, design: .monospaced))
                                .foregroundColor(AppSettings.terminalGreen)

                            StatBar(label: "Expertise", value: advisor.expertise)
                            StatBar(label: "Loyalty", value: advisor.loyalty)
                            StatBar(label: "Influence", value: advisor.influence)
                            StatBar(label: "Public Support", value: advisor.publicSupport)

                            Divider()
                                .background(AppSettings.terminalGreen)

                            Text("PERSONALITY:")
                                .font(.system(.headline, design: .monospaced))
                                .foregroundColor(AppSettings.terminalGreen)
                                .padding(.top, 8)

                            StatBar(label: "Hawkishness", value: advisor.hawkishness)
                            StatBar(label: "Interventionism", value: advisor.interventionism)
                            StatBar(label: "Fiscal Cons.", value: advisor.fiscalConservatism)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding()

                    // Bio
                    VStack(alignment: .leading, spacing: 8) {
                        Text("BACKGROUND:")
                            .font(.system(.headline, design: .monospaced))
                            .foregroundColor(AppSettings.terminalGreen)

                        Text(advisor.bio)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(AppSettings.terminalGreen)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.black.opacity(0.5))
                            .border(AppSettings.terminalGreen, width: 1)
                    }
                    .padding()

                    // Advice Areas
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ADVICE SPECIALTIES:")
                            .font(.system(.headline, design: .monospaced))
                            .foregroundColor(AppSettings.terminalGreen)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], spacing: 8) {
                            ForEach(advisor.adviceAreas, id: \.self) { area in
                                Text("☑ \(area.rawValue)")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(AppSettings.terminalAmber)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.black.opacity(0.5))
                                    .border(AppSettings.terminalAmber, width: 1)
                            }
                        }
                    }
                    .padding()

                    // Current Advice
                    if let advice = advisor.currentAdvice {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("CURRENT ADVICE:")
                                .font(.system(.headline, design: .monospaced))
                                .foregroundColor(AppSettings.terminalAmber)

                            Text("\"\(advice)\"")
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(AppSettings.terminalGreen)
                                .italic()
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.black.opacity(0.7))
                                .border(AppSettings.terminalAmber, width: 2)

                            // Action buttons
                            HStack(spacing: 16) {
                                Button("ACCEPT ADVICE") {
                                    // Accept action
                                    dismiss()
                                }
                                .buttonStyle(WOPRButtonStyle(color: AppSettings.terminalGreen))

                                Button("REJECT ADVICE") {
                                    // Reject action
                                    dismiss()
                                }
                                .buttonStyle(WOPRButtonStyle(color: AppSettings.terminalRed))

                                Button("REQUEST ALTERNATIVE") {
                                    // Alternative action
                                }
                                .buttonStyle(WOPRButtonStyle(color: AppSettings.terminalAmber))
                            }
                        }
                        .padding()
                    }

                    Spacer(minLength: 40)
                }
            }
            .background(AppSettings.terminalBackground)
        }
        .background(AppSettings.terminalBackground)
    }
}

// MARK: - Supporting Views

/// Placeholder advisor portrait with initials
struct PlaceholderAdvisorImage: View {
    let name: String
    let color: Color

    var initials: String {
        name.components(separatedBy: " ")
            .compactMap { $0.first }
            .map { String($0) }
            .joined()
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(color.opacity(0.2))
                .border(color, width: 2)

            Text(initials)
                .font(.system(size: 34, weight: .bold, design: .monospaced))
                .foregroundColor(color)
        }
    }
}

/// Full stat bar with label and percentage
struct StatBar: View {
    let label: String
    let value: Int

    var body: some View {
        HStack(spacing: 8) {
            Text("\(label):")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(AppSettings.terminalAmber)
                .frame(width: 100, alignment: .leading)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    Rectangle()
                        .fill(Color.black.opacity(0.5))
                        .border(AppSettings.terminalGreen, width: 1)

                    // Fill
                    Rectangle()
                        .fill(barColor)
                        .frame(width: geometry.size.width * CGFloat(value) / 100.0)
                }
            }
            .frame(height: 16)

            Text("\(value)%")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(AppSettings.terminalGreen)
                .frame(width: 40, alignment: .trailing)
        }
    }

    var barColor: Color {
        switch value {
        case 0..<33:
            return AppSettings.terminalRed
        case 33..<66:
            return AppSettings.terminalAmber
        default:
            return AppSettings.terminalGreen
        }
    }
}

/// Mini stat bar for cards
struct MiniStatBar: View {
    let label: String
    let value: Int
    let color: StatColor

    enum StatColor {
        case green, amber, red
    }

    var body: some View {
        HStack(spacing: 4) {
            Text("\(label):")
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(AppSettings.terminalAmber)
                .frame(width: 30, alignment: .leading)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.black.opacity(0.5))
                        .border(displayColor, width: 1)

                    Rectangle()
                        .fill(displayColor)
                        .frame(width: geometry.size.width * CGFloat(value) / 100.0)
                }
            }
            .frame(height: 8)

            Text("\(value)%")
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(displayColor)
                .frame(width: 30, alignment: .trailing)
        }
    }

    var displayColor: Color {
        switch color {
        case .green:
            return AppSettings.terminalGreen
        case .amber:
            return AppSettings.terminalAmber
        case .red:
            return AppSettings.terminalRed
        }
    }
}

/// WOPR-style button
struct WOPRButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .bold, design: .monospaced))
            .foregroundColor(color)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.black)
            .border(color, width: 2)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

/// DEFCON badge
struct DefconBadge: View {
    let level: DefconLevel

    var body: some View {
        HStack(spacing: 4) {
            Text("DEFCON:")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(AppSettings.terminalAmber)

            Text("\(level.rawValue)")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(level.color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.black)
        .border(level.color, width: 2)
    }
}

// MARK: - Preview

#if DEBUG
struct AdvisorViews_Previews: PreviewProvider {
    static var previews: some View {
        let gameEngine = GameEngine()
        gameEngine.gameState = GameState(playerCountryID: "USA", difficultyLevel: .normal)

        return Group {
            AdvisorGridView(advisors: Advisor.trumpCabinet())
                .environmentObject(gameEngine)
                .preferredColorScheme(.dark)
                .previewDisplayName("Advisor Grid")

            AdvisorDetailView(advisor: Advisor.trumpCabinet()[3]) // Pete Hegseth
                .environmentObject(gameEngine)
                .preferredColorScheme(.dark)
                .previewDisplayName("Advisor Detail")
        }
    }
}
#endif
