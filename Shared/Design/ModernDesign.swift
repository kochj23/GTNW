//
//  ModernDesign.swift
//  TopGUI
//
//  Extreme glassmorphic design with floating colorful blobs
//  Inspired by iOS design and modern dashboard aesthetics
//
//  Created by Jordan Koch on 1/15/2026.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

struct ModernColors {
    // Dark blue gradient background (CleanMyMac style)
    static var gradientStart: Color { Theme.isRetro ? EGA.blue : Color(red: 0.08, green: 0.12, blue: 0.22) }  // Dark navy
    static var gradientMid: Color { Theme.isRetro ? EGA.blue : Color(red: 0.10, green: 0.15, blue: 0.28) }  // Navy blue
    static var gradientEnd: Color { Theme.isRetro ? EGA.blue : Color(red: 0.12, green: 0.18, blue: 0.32) }  // Lighter navy

    // Vibrant accent colors (CleanMyMac style)
    static var cyan: Color { Theme.isRetro ? EGA.lightCyan : Color(red: 0.3, green: 0.85, blue: 0.95) }  // Bright cyan
    static var teal: Color { Theme.isRetro ? EGA.cyan : Color(red: 0.2, green: 0.8, blue: 0.8) }  // Teal
    static var purple: Color { Theme.isRetro ? EGA.magenta : Color(red: 0.6, green: 0.4, blue: 0.95) }  // Purple
    static var orange: Color { Theme.isRetro ? EGA.brown : Color(red: 1.0, green: 0.6, blue: 0.2) }  // Warm orange
    static var yellow: Color { Theme.isRetro ? EGA.yellow : Color(red: 1.0, green: 0.85, blue: 0.3) }  // Bright yellow
    static var pink: Color { Theme.isRetro ? EGA.lightMagenta : Color(red: 1.0, green: 0.35, blue: 0.65) }  // Hot pink
    static var accent: Color { Theme.isRetro ? EGA.lightCyan : Color(red: 0.3, green: 0.85, blue: 0.95) }  // Cyan (primary)
    static var accentBlue: Color { Theme.isRetro ? EGA.lightBlue : Color(red: 0.3, green: 0.7, blue: 1.0) }  // Blue
    static var accentGreen: Color { Theme.isRetro ? EGA.lightGreen : Color(red: 0.3, green: 0.9, blue: 0.6) }  // Green
    static var accentOrange: Color { Theme.isRetro ? EGA.brown : Color(red: 1.0, green: 0.6, blue: 0.2) }  // Orange

    // Background blob colors (vibrant for dark background)
    static var blobCyan: Color { Theme.isRetro ? EGA.cyan : Color(red: 0.2, green: 0.7, blue: 0.9) }
    static var blobPurple: Color { Theme.isRetro ? EGA.magenta : Color(red: 0.5, green: 0.3, blue: 0.8) }
    static var blobPink: Color { Theme.isRetro ? EGA.lightMagenta : Color(red: 0.9, green: 0.3, blue: 0.6) }
    static var blobOrange: Color { Theme.isRetro ? EGA.brown : Color(red: 0.9, green: 0.5, blue: 0.2) }

    // Status colors (CleanMyMac health indicators)
    static var statusLow: Color { Theme.isRetro ? EGA.lightGreen : Color(red: 0.3, green: 0.9, blue: 0.6) }  // Bright green
    static var statusMedium: Color { Theme.isRetro ? EGA.yellow : Color(red: 1.0, green: 0.85, blue: 0.3) }  // Yellow
    static var statusHigh: Color { Theme.isRetro ? EGA.brown : Color(red: 1.0, green: 0.6, blue: 0.2) }  // Orange
    static var statusCritical: Color { Theme.isRetro ? EGA.lightRed : Color(red: 1.0, green: 0.3, blue: 0.4) }  // Red

    // Text colors (light for dark background)
    static var textPrimary: Color { Theme.isRetro ? EGA.white : Color.white }
    static var textSecondary: Color { Theme.isRetro ? EGA.lightGray : Color.white.opacity(0.7) }
    static var textTertiary: Color { Theme.isRetro ? EGA.lightGray : Color.white.opacity(0.5) }

    // Glass card colors (darker, more opaque)
    static var glassBackground: Color { Theme.isRetro ? EGA.blue : Color.white.opacity(0.05) }
    static var glassBorder: Color { Theme.isRetro ? EGA.lightGray : Color.white.opacity(0.15) }

    // Get color for percentage (heat map)
    static func heatColor(percentage: Double) -> Color {
        switch percentage {
        case 0..<25:
            return statusLow
        case 25..<50:
            return statusMedium
        case 50..<75:
            return statusHigh
        default:
            return statusCritical
        }
    }

    // Background gradient
    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [gradientStart, gradientMid, gradientEnd],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// Extreme glassmorphic card with heavy blur
struct GlassCard: ViewModifier {
    let prominent: Bool

    func body(content: Content) -> some View {
        if Theme.isRetro {
            content.padding(20).background(RetroBevel(fill: EGA.blue))
        } else {
        content
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(ModernColors.glassBackground)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(.ultraThinMaterial)
                            .opacity(0.9)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(ModernColors.glassBorder, lineWidth: 2)
                    )
                    .shadow(color: Color.black.opacity(0.05), radius: 10, y: 5)
                    .shadow(color: Color.white.opacity(0.8), radius: 1, x: -1, y: -1)
            )
        }
    }
}

extension View {
    func glassCard(prominent: Bool = false) -> some View {
        modifier(GlassCard(prominent: prominent))
    }
}

// Modern button style with glass effect
struct ModernButtonStyle: ButtonStyle {
    let color: Color
    let style: ButtonStyleType

    enum ButtonStyleType {
        case filled
        case outlined
        case destructive
        case glass
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Group {
                    if style == .glass {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.3))
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(.ultraThinMaterial)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.5), lineWidth: 1.5)
                            )
                    } else if style == .filled || style == .destructive {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(configuration.isPressed ? color.opacity(0.8) : color)
                    } else {
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(color, lineWidth: 2)
                    }
                }
            )
            .foregroundColor(style == .outlined ? color : (style == .glass ? ModernColors.textPrimary : .white))
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .shadow(color: color.opacity(0.3), radius: configuration.isPressed ? 5 : 8)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// Modern header text
struct ModernHeader: ViewModifier {
    let size: HeaderSize

    enum HeaderSize {
        case large, medium, small

        var fontSize: CGFloat {
            switch self {
            case .large: return 32
            case .medium: return 22
            case .small: return 18
            }
        }
    }

    func body(content: Content) -> some View {
        content
            .font(.system(size: size.fontSize, weight: .bold, design: .rounded))
            .foregroundColor(ModernColors.textPrimary)
    }
}

extension View {
    func modernHeader(size: ModernHeader.HeaderSize = .large) -> some View {
        modifier(ModernHeader(size: size))
    }
}

// Floating background blob
struct FloatingBlob: View {
    let color: Color
    let size: CGFloat
    let x: CGFloat
    let y: CGFloat
    let animation: Animation

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [color, color.opacity(0.6)],
                    center: .center,
                    startRadius: 0,
                    endRadius: size / 2
                )
            )
            .frame(width: size, height: size)
            .blur(radius: 50)
            .offset(x: x, y: y)
    }
}

// Background with floating blobs
struct GlassmorphicBackground: View {
    @State private var animateBlobs = false

    var body: some View {
        if Theme.isRetro {
            // Retro: a flat EGA-blue desktop, like a 1990s DOS front end.
            EGA.blue.ignoresSafeArea()
        } else {
            modernBody
        }
    }

    private var modernBody: some View {
        ZStack {
            // Base gradient
            ModernColors.backgroundGradient
                .ignoresSafeArea()

            // Large floating blobs (dark theme colors)
            FloatingBlob(
                color: ModernColors.blobCyan,
                size: 400,
                x: animateBlobs ? -100 : -150,
                y: animateBlobs ? -200 : -250,
                animation: .easeInOut(duration: 8).repeatForever(autoreverses: true)
            )

            FloatingBlob(
                color: ModernColors.blobPurple,
                size: 350,
                x: animateBlobs ? 150 : 100,
                y: animateBlobs ? -150 : -100,
                animation: .easeInOut(duration: 7).repeatForever(autoreverses: true)
            )

            FloatingBlob(
                color: ModernColors.blobPink,
                size: 450,
                x: animateBlobs ? 100 : 150,
                y: animateBlobs ? 300 : 350,
                animation: .easeInOut(duration: 9).repeatForever(autoreverses: true)
            )

            FloatingBlob(
                color: ModernColors.blobOrange,
                size: 300,
                x: animateBlobs ? -200 : -150,
                y: animateBlobs ? 250 : 300,
                animation: .easeInOut(duration: 10).repeatForever(autoreverses: true)
            )

            FloatingBlob(
                color: ModernColors.blobCyan.opacity(0.7),
                size: 250,
                x: animateBlobs ? 200 : 250,
                y: animateBlobs ? 100 : 50,
                animation: .easeInOut(duration: 6).repeatForever(autoreverses: true)
            )
        }
        .onAppear {
            withAnimation {
                animateBlobs = true
            }
        }
    }
}

// Hexagonal shape for heat map (kept for compatibility)
struct HexagonShape: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        var path = Path()
        for i in 0..<6 {
            let angle = CGFloat(i) * .pi / 3 - .pi / 2
            let point = CGPoint(
                x: center.x + radius * cos(angle),
                y: center.y + radius * sin(angle)
            )
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

// Reusable circular gauge component with smooth animations
struct CircularGauge: View {
    let value: Double // 0-100
    let color: Color
    let size: CGFloat
    let lineWidth: CGFloat
    let showValue: Bool
    let label: String?

    @State private var animatedValue: Double = 0

    init(value: Double, color: Color, size: CGFloat = 80, lineWidth: CGFloat = 8, showValue: Bool = true, label: String? = nil) {
        self.value = value
        self.color = color
        self.size = size
        self.lineWidth = lineWidth
        self.showValue = showValue
        self.label = label
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: min(animatedValue / 100.0, 1.0))
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: color.opacity(0.6), radius: 6)
                .animation(.easeInOut(duration: 0.6), value: animatedValue)

            if showValue {
                VStack(spacing: 2) {
                    Text(String(format: "%.0f", animatedValue))
                        .font(.system(size: size > 60 ? 24 : 16, weight: .bold, design: .rounded))
                        .foregroundColor(ModernColors.textPrimary)
                        .animation(.easeInOut(duration: 0.6), value: animatedValue)

                    if let label = label {
                        Text(label)
                            .font(.system(size: size > 60 ? 10 : 8, weight: .medium, design: .rounded))
                            .foregroundColor(ModernColors.textSecondary)
                    }
                }
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            animatedValue = value
        }
        .onChange(of: value) { newValue in
            withAnimation(.easeInOut(duration: 0.6)) {
                animatedValue = newValue
            }
        }
    }
}

// Mini circular gauge (for compact cards) with smooth animations
struct MiniGauge: View {
    let value: Double
    let color: Color

    @State private var animatedValue: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: 4)

            Circle()
                .trim(from: 0, to: min(animatedValue / 100.0, 1.0))
                .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: color.opacity(0.5), radius: 3)
                .animation(.easeInOut(duration: 0.6), value: animatedValue)
        }
        .frame(width: 40, height: 40)
        .onAppear {
            animatedValue = value
        }
        .onChange(of: value) { newValue in
            withAnimation(.easeInOut(duration: 0.6)) {
                animatedValue = newValue
            }
        }
    }
}
