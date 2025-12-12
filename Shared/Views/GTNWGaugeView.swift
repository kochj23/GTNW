//
//  GTNWGaugeView.swift
//  Global Thermal Nuclear War
//
//  Circular gauge/speedometer views for MLX performance metrics
//  Adapted from MLX Code by Jordan Koch on 2025-12-12.
//

import SwiftUI

/// Circular gauge view for displaying metrics with dial indicator
struct GTNWGaugeView: View {
    let value: Double
    let maxValue: Double
    let label: String
    let valueText: String
    let color: Color
    let size: CGFloat

    private var progress: Double {
        guard maxValue > 0 else { return 0 }
        return min(value / maxValue, 1.0)
    }

    init(value: Double, maxValue: Double, label: String, valueText: String, color: Color = GTNWColors.neonPurple, size: CGFloat = 80) {
        self.value = value
        self.maxValue = maxValue
        self.label = label
        self.valueText = valueText
        self.color = color
        self.size = size
    }

    var body: some View {
        VStack(spacing: 6) {
            // Circular dial
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: size * 0.1)
                    .frame(width: size, height: size)

                // Progress arc
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        color,
                        style: StrokeStyle(
                            lineWidth: size * 0.1,
                            lineCap: .round
                        )
                    )
                    .frame(width: size, height: size)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: progress)

                // Center value
                VStack(spacing: 2) {
                    Text(valueText)
                        .font(.system(size: size * 0.22, weight: .bold, design: .rounded))
                        .foregroundColor(color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .frame(width: size * 0.7)
            }

            // Label
            Text(label)
                .font(GTNWFonts.terminal(size: size * 0.14, weight: .medium))
                .foregroundColor(GTNWColors.terminalAmber.opacity(0.8))
                .lineLimit(1)
        }
    }
}

/// Speedometer-style gauge with 180° arc and needle
struct GTNWSpeedometerView: View {
    let value: Double
    let maxValue: Double
    let label: String
    let valueText: String
    let size: CGFloat

    private var progress: Double {
        guard maxValue > 0 else { return 0 }
        return min(value / maxValue, 1.0)
    }

    private var needleAngle: Double {
        -90 + (progress * 180)
    }

    private var gaugeColor: Color {
        if progress < 0.4 {
            return GTNWColors.terminalRed
        } else if progress < 0.6 {
            return GTNWColors.terminalAmber
        } else if progress < 0.8 {
            return GTNWColors.terminalGreen
        } else {
            return GTNWColors.neonCyan
        }
    }

    init(value: Double, maxValue: Double, label: String, valueText: String, size: CGFloat = 100) {
        self.value = value
        self.maxValue = maxValue
        self.label = label
        self.valueText = valueText
        self.size = size
    }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                // Background arc (180° semicircle)
                Circle()
                    .trim(from: 0, to: 0.5)
                    .stroke(Color.gray.opacity(0.2), lineWidth: size * 0.08)
                    .frame(width: size, height: size)
                    .rotationEffect(.degrees(90))

                // Colored segments (red, amber, green zones)
                ForEach(0..<3) { segment in
                    Circle()
                        .trim(from: Double(segment) * 0.5 / 3.0, to: Double(segment + 1) * 0.5 / 3.0)
                        .stroke(
                            segment == 0 ? GTNWColors.terminalRed : (segment == 1 ? GTNWColors.terminalAmber : GTNWColors.terminalGreen),
                            lineWidth: size * 0.08
                        )
                        .frame(width: size, height: size)
                        .rotationEffect(.degrees(90))
                        .opacity(0.3)
                }

                // Progress arc
                Circle()
                    .trim(from: 0, to: progress * 0.5)
                    .stroke(
                        gaugeColor,
                        style: StrokeStyle(
                            lineWidth: size * 0.08,
                            lineCap: .round
                        )
                    )
                    .frame(width: size, height: size)
                    .rotationEffect(.degrees(90))
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: progress)

                // Needle
                Rectangle()
                    .fill(gaugeColor)
                    .frame(width: 2, height: size * 0.4)
                    .offset(y: -size * 0.2)
                    .rotationEffect(.degrees(needleAngle))
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: needleAngle)

                // Center circle (needle pivot)
                Circle()
                    .fill(gaugeColor)
                    .frame(width: size * 0.1, height: size * 0.1)

                // Value display below gauge
                VStack {
                    Spacer()
                    Text(valueText)
                        .font(.system(size: size * 0.18, weight: .bold, design: .rounded))
                        .foregroundColor(gaugeColor)
                }
                .frame(height: size)
                .offset(y: size * 0.15)
            }
            .frame(height: size * 0.7)

            // Label
            Text(label)
                .font(GTNWFonts.terminal(size: size * 0.13, weight: .medium))
                .foregroundColor(GTNWColors.terminalAmber.opacity(0.8))
                .lineLimit(1)
        }
    }
}

/// Horizontal bar gauge for compact displays
struct GTNWBarGaugeView: View {
    let value: Double
    let maxValue: Double
    let label: String
    let valueText: String
    let width: CGFloat

    private var progress: Double {
        guard maxValue > 0 else { return 0 }
        return min(value / maxValue, 1.0)
    }

    private var color: Color {
        if progress < 0.4 {
            return GTNWColors.terminalRed
        } else if progress < 0.7 {
            return GTNWColors.terminalAmber
        } else {
            return GTNWColors.terminalGreen
        }
    }

    init(value: Double, maxValue: Double, label: String, valueText: String, width: CGFloat = 150) {
        self.value = value
        self.maxValue = maxValue
        self.label = label
        self.valueText = valueText
        self.width = width
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(GTNWFonts.caption())
                    .foregroundColor(GTNWColors.terminalAmber.opacity(0.7))

                Spacer()

                Text(valueText)
                    .font(GTNWFonts.terminal(size: 11, weight: .bold))
                    .foregroundColor(color)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)

                    // Progress
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: geometry.size.width * progress, height: 6)
                        .animation(.easeInOut(duration: 0.3), value: progress)
                }
            }
            .frame(height: 6)
        }
        .frame(width: width)
    }
}

// MARK: - Preview

#Preview("Gauge Views") {
    VStack(spacing: 30) {
        HStack(spacing: 20) {
            GTNWGaugeView(
                value: 65.3,
                maxValue: 100,
                label: "Tokens/Sec",
                valueText: "65.3",
                color: GTNWColors.neonPurple
            )

            GTNWGaugeView(
                value: 3420,
                maxValue: 8192,
                label: "Total Tokens",
                valueText: "3.4K",
                color: GTNWColors.neonCyan
            )
        }

        GTNWSpeedometerView(
            value: 78.5,
            maxValue: 100,
            label: "Processing Speed",
            valueText: "78.5 t/s"
        )

        VStack(spacing: 12) {
            GTNWBarGaugeView(
                value: 2500,
                maxValue: 8192,
                label: "Context Usage",
                valueText: "2,500 / 8,192"
            )

            GTNWBarGaugeView(
                value: 145,
                maxValue: 200,
                label: "Response Time",
                valueText: "1.45s"
            )
        }
    }
    .padding()
    .frame(width: 500, height: 600)
    .background(Color.black)
}
