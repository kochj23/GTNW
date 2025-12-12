//
//  MLXInteractionPanel.swift
//  Global Thermal Nuclear War
//
//  Shows MLX AI toolkit interactions and processing
//  Created by Jordan Koch on 2025-12-11.
//

import SwiftUI

/// MLX AI Toolkit interaction panel
///
/// Shows real-time AI processing, strategic analysis, and command parsing with performance metrics
struct MLXInteractionPanel: View {
    @ObservedObject var mlxManager: MLXManager
    @ObservedObject var performanceMetrics = GTNWPerformanceMetrics.shared
    @EnvironmentObject var gameEngine: GameEngine
    @State private var showMetrics: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(GTNWColors.neonPurple)
                Text("MLX AI TOOLKIT")
                    .font(GTNWFonts.subheading())
                    .foregroundColor(GTNWColors.neonPurple)

                Spacer()

                // Connection status indicator
                HStack(spacing: 6) {
                    Circle()
                        .fill(mlxManager.isConnected ? GTNWColors.terminalGreen : GTNWColors.terminalRed)
                        .frame(width: 10, height: 10)
                    Text(mlxManager.isConnected ? "ONLINE" : "OFFLINE")
                        .font(GTNWFonts.caption())
                        .foregroundColor(mlxManager.isConnected ? GTNWColors.terminalGreen : GTNWColors.terminalRed)
                }
            }
            .padding()
            .background(GTNWColors.glassPanelDark)

            // Performance Metrics Panel (when connected)
            if mlxManager.isConnected {
                performanceMetricsPanel
            }

            // Connection info
            if !mlxManager.isConnected {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(GTNWColors.terminalAmber)

                    Text("MLX Toolkit Not Available")
                        .font(GTNWFonts.body())
                        .foregroundColor(GTNWColors.terminalAmber)

                    Text("Install: pip install mlx")
                        .font(GTNWFonts.caption())
                        .foregroundColor(GTNWColors.terminalGreen)
                        .padding(8)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(4)

                    Text("Falling back to rule-based AI")
                        .font(GTNWFonts.caption())
                        .foregroundColor(GTNWColors.terminalAmber.opacity(0.7))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                // MLX interaction log
                ScrollView {
                    ScrollViewReader { proxy in
                        LazyVStack(alignment: .leading, spacing: 12) {
                            // Processing indicator
                            if mlxManager.isProcessing {
                                processingIndicator
                            }

                            // Last response
                            if !mlxManager.lastResponse.isEmpty {
                                lastResponseCard
                            }

                            // Recent interactions
                            ForEach(mlxManager.interactionHistory) { interaction in
                                interactionCard(interaction)
                                    .id(interaction.id)
                            }
                        }
                        .padding()
                        .onChange(of: mlxManager.interactionHistory.count) { _ in
                            if let latest = mlxManager.interactionHistory.first {
                                withAnimation {
                                    proxy.scrollTo(latest.id, anchor: .top)
                                }
                            }
                        }
                    }
                }
                .background(Color.black.opacity(0.3))
            }
        }
        .frame(minWidth: 350)
    }

    // MARK: - Performance Metrics

    private var performanceMetricsPanel: some View {
        VStack(spacing: 0) {
            // Metrics header with collapse toggle
            HStack {
                Image(systemName: "speedometer")
                    .foregroundColor(GTNWColors.neonCyan)
                Text("PERFORMANCE METRICS")
                    .font(GTNWFonts.terminal(size: 12, weight: .bold))
                    .foregroundColor(GTNWColors.neonCyan)

                Spacer()

                Button(action: {
                    withAnimation {
                        showMetrics.toggle()
                    }
                }) {
                    Image(systemName: showMetrics ? "chevron.up" : "chevron.down")
                        .foregroundColor(GTNWColors.terminalAmber.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(GTNWColors.glassPanelDark.opacity(0.5))

            if showMetrics {
                Divider()
                    .background(GTNWColors.neonPurple.opacity(0.3))

                // Metrics content
                HStack(spacing: 20) {
                    // Tokens per second speedometer dial
                    GTNWSpeedometerView(
                        value: performanceMetrics.tokensPerSecond,
                        maxValue: 100.0,
                        label: "TOKENS/SEC",
                        valueText: String(format: "%.1f", performanceMetrics.tokensPerSecond),
                        size: 90
                    )

                    VStack(spacing: 16) {
                        // Total tokens
                        VStack(spacing: 6) {
                            Text("TOTAL TOKENS")
                                .font(GTNWFonts.caption())
                                .foregroundColor(GTNWColors.terminalAmber.opacity(0.7))

                            HStack(spacing: 8) {
                                Image(systemName: "number.circle.fill")
                                    .foregroundColor(GTNWColors.neonPurple)
                                Text("\(performanceMetrics.totalTokens)")
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundColor(GTNWColors.neonPurple)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(GTNWColors.neonPurple.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(GTNWColors.neonPurple.opacity(0.4), lineWidth: 1)
                                    )
                            )
                        }

                        // Average tokens/sec
                        VStack(spacing: 6) {
                            Text("AVG TOKENS/SEC")
                                .font(GTNWFonts.caption())
                                .foregroundColor(GTNWColors.terminalAmber.opacity(0.7))

                            HStack(spacing: 6) {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .foregroundColor(GTNWColors.terminalGreen)
                                Text(String(format: "%.1f t/s", performanceMetrics.averageTokensPerSecond))
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundColor(GTNWColors.terminalGreen)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(GTNWColors.terminalGreen.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(GTNWColors.terminalGreen.opacity(0.4), lineWidth: 1)
                                    )
                            )
                        }
                    }

                    Spacer()

                    // Current processing status
                    if performanceMetrics.isProcessing {
                        VStack(spacing: 6) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: GTNWColors.neonPurple))
                                .scaleEffect(0.8)

                            Text("PROCESSING")
                                .font(GTNWFonts.caption())
                                .foregroundColor(GTNWColors.neonPurple)

                            Text(String(format: "%.1f t/s", performanceMetrics.tokensPerSecond))
                                .font(GTNWFonts.terminal(size: 14, weight: .bold))
                                .foregroundColor(GTNWColors.neonPurple)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(GTNWColors.neonPurple.opacity(0.15))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(GTNWColors.neonPurple.opacity(0.5), lineWidth: 1)
                                )
                        )
                    }
                }
                .padding(16)
                .background(Color.black.opacity(0.3))

                // Additional stats bar
                HStack(spacing: 16) {
                    // Peak tokens/sec
                    statItem(
                        icon: "arrow.up.circle.fill",
                        label: "PEAK",
                        value: String(format: "%.1f t/s", performanceMetrics.peakTokensPerSecond),
                        color: GTNWColors.neonCyan
                    )

                    Divider()
                        .frame(height: 30)
                        .background(GTNWColors.terminalAmber.opacity(0.3))

                    // Average response time
                    statItem(
                        icon: "clock.fill",
                        label: "AVG TIME",
                        value: String(format: "%.2fs", performanceMetrics.averageResponseTime),
                        color: GTNWColors.terminalAmber
                    )

                    Divider()
                        .frame(height: 30)
                        .background(GTNWColors.terminalAmber.opacity(0.3))

                    // Total queries processed
                    statItem(
                        icon: "arrow.triangle.2.circlepath",
                        label: "QUERIES",
                        value: "\(performanceMetrics.responseTimeHistory.count)",
                        color: GTNWColors.terminalGreen
                    )

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(GTNWColors.glassPanelDark.opacity(0.5))
            }
        }
        .background(GTNWColors.glassPanelDark.opacity(0.3))
    }

    private func statItem(icon: String, label: String, value: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 12))

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(GTNWFonts.caption())
                    .foregroundColor(GTNWColors.terminalAmber.opacity(0.6))
                Text(value)
                    .font(GTNWFonts.terminal(size: 12, weight: .bold))
                    .foregroundColor(color)
            }
        }
    }

    // MARK: - Components

    private var processingIndicator: some View {
        HStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: GTNWColors.neonPurple))
                .scaleEffect(0.9)

            VStack(alignment: .leading, spacing: 4) {
                Text("PROCESSING...")
                    .font(GTNWFonts.terminal(size: 13, weight: .bold))
                    .foregroundColor(GTNWColors.neonPurple)

                Text("MLX analyzing game state")
                    .font(GTNWFonts.caption())
                    .foregroundColor(GTNWColors.terminalAmber.opacity(0.7))
            }

            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(GTNWColors.neonPurple.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(GTNWColors.neonPurple.opacity(0.5), lineWidth: 1)
                )
        )
    }

    private var lastResponseCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(GTNWColors.neonPurple)
                Text("LATEST ANALYSIS")
                    .font(GTNWFonts.terminal(size: 12, weight: .bold))
                    .foregroundColor(GTNWColors.neonPurple)

                Spacer()

                Text("NOW")
                    .font(GTNWFonts.caption())
                    .foregroundColor(GTNWColors.terminalAmber.opacity(0.7))
            }

            Text(mlxManager.lastResponse)
                .font(GTNWFonts.terminal(size: 12))
                .foregroundColor(GTNWColors.terminalGreen)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black.opacity(0.5))
                .cornerRadius(4)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(GTNWColors.neonPurple.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(GTNWColors.neonPurple.opacity(0.6), lineWidth: 2)
                )
        )
    }

    private func interactionCard(_ interaction: MLXInteraction) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: interaction.icon)
                    .foregroundColor(interaction.color)
                Text(interaction.type.uppercased())
                    .font(GTNWFonts.terminal(size: 11, weight: .bold))
                    .foregroundColor(interaction.color)

                Spacer()

                Text(interaction.timestamp, style: .time)
                    .font(GTNWFonts.caption())
                    .foregroundColor(GTNWColors.terminalAmber.opacity(0.6))
            }

            // Input (if any)
            if let input = interaction.input {
                VStack(alignment: .leading, spacing: 4) {
                    Text("INPUT:")
                        .font(GTNWFonts.caption())
                        .foregroundColor(GTNWColors.terminalAmber.opacity(0.7))

                    Text(input)
                        .font(GTNWFonts.terminal(size: 11))
                        .foregroundColor(GTNWColors.terminalGreen.opacity(0.8))
                }
            }

            // Output
            VStack(alignment: .leading, spacing: 4) {
                Text("OUTPUT:")
                    .font(GTNWFonts.caption())
                    .foregroundColor(GTNWColors.terminalAmber.opacity(0.7))

                Text(interaction.output)
                    .font(GTNWFonts.terminal(size: 11))
                    .foregroundColor(GTNWColors.terminalGreen)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(interaction.color.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(interaction.color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - MLX Interaction Model

/// Represents an MLX AI interaction
struct MLXInteraction: Identifiable {
    let id = UUID()
    let timestamp: Date
    let type: String
    let input: String?
    let output: String

    var icon: String {
        switch type.lowercased() {
        case "command": return "terminal.fill"
        case "analysis": return "chart.bar.fill"
        case "strategic": return "brain.head.profile"
        case "prediction": return "crystal.ball.fill"
        case "recommendation": return "lightbulb.fill"
        default: return "cpu"
        }
    }

    var color: Color {
        switch type.lowercased() {
        case "command": return GTNWColors.neonCyan
        case "analysis": return GTNWColors.neonPurple
        case "strategic": return GTNWColors.neonBlue
        case "prediction": return GTNWColors.terminalAmber
        case "recommendation": return GTNWColors.terminalGreen
        default: return GTNWColors.terminalGreen
        }
    }
}

// MARK: - MLXManager Extension

extension MLXManager {
    @Published var interactionHistory: [MLXInteraction] = []
    private let maxHistory = 20

    /// Log an MLX interaction
    func logInteraction(type: String, input: String? = nil, output: String) {
        let interaction = MLXInteraction(
            timestamp: Date(),
            type: type,
            input: input,
            output: output
        )

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.interactionHistory.insert(interaction, at: 0)

            // Keep only recent interactions
            if self.interactionHistory.count > self.maxHistory {
                self.interactionHistory = Array(self.interactionHistory.prefix(self.maxHistory))
            }
        }
    }
}

#Preview {
    MLXInteractionPanel(mlxManager: MLXManager())
        .environmentObject(GameEngine())
        .frame(width: 350, height: 600)
}
