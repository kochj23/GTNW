//
//  ModernDesignSystem.swift
//  Global Thermal Nuclear War
//
//  Modern design system with WOPR + LCARS + Military aesthetic
//  Created by Jordan Koch on 2025-12-03.
//

import SwiftUI

// MARK: - Color Palette

struct GTNWColors {
    // Primary WOPR Colors (keep these)
    static let terminalGreen = Color(red: 0.0, green: 1.0, blue: 0.0)
    static let terminalAmber = Color(red: 1.0, green: 0.75, blue: 0.0)
    static let terminalRed = Color(red: 1.0, green: 0.0, blue: 0.0)

    // New Modern Colors
    static let neonCyan = Color(red: 0.0, green: 0.9, blue: 1.0)
    static let neonPurple = Color(red: 0.7, green: 0.3, blue: 1.0)
    static let neonBlue = Color(red: 0.3, green: 0.6, blue: 1.0)
    static let neonPink = Color(red: 1.0, green: 0.3, blue: 0.6)

    // LCARS-inspired
    static let lcarsOrange = Color(red: 1.0, green: 0.6, blue: 0.0)
    static let lcarsPeach = Color(red: 1.0, green: 0.7, blue: 0.5)
    static let lcarsSkyBlue = Color(red: 0.4, green: 0.7, blue: 1.0)
    static let lcarsLavender = Color(red: 0.9, green: 0.7, blue: 1.0)

    // Backgrounds
    static let spaceBackground = LinearGradient(
        colors: [
            Color(red: 0.0, green: 0.0, blue: 0.05),
            Color(red: 0.0, green: 0.05, blue: 0.1),
            Color.black
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let commandCenterBackground = LinearGradient(
        colors: [
            Color(red: 0.05, green: 0.05, blue: 0.1),
            Color(red: 0.0, green: 0.0, blue: 0.0)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    static let threatGradient = LinearGradient(
        colors: [terminalRed.opacity(0.3), terminalAmber.opacity(0.2), terminalGreen.opacity(0.1)],
        startPoint: .leading,
        endPoint: .trailing
    )

    // Glass panels
    static let glassPanelLight = Color.white.opacity(0.05)
    static let glassPanelMedium = Color.white.opacity(0.08)
    static let glassPanelDark = Color.black.opacity(0.6)
}

// MARK: - Typography

struct GTNWFonts {
    static func terminal(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    static func title() -> Font {
        .system(size: 48, weight: .bold, design: .monospaced)
    }

    static func heading() -> Font {
        .system(size: 32, weight: .bold, design: .monospaced)
    }

    static func subheading() -> Font {
        .system(size: 24, weight: .semibold, design: .monospaced)
    }

    static func body() -> Font {
        .system(size: 16, weight: .regular, design: .monospaced)
    }

    static func caption() -> Font {
        .system(size: 12, weight: .regular, design: .monospaced)
    }
}

// MARK: - Spacing

struct GTNWSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

// MARK: - Corner Radius

struct GTNWCorners {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
}

// MARK: - Animations

struct GTNWAnimations {
    static let quick = Animation.easeInOut(duration: 0.2)
    static let standard = Animation.easeInOut(duration: 0.3)
    static let slow = Animation.easeInOut(duration: 0.5)
    static let spring = Animation.spring(response: 0.4, dampingFraction: 0.7)

    static func pulse(duration: Double = 1.0) -> Animation {
        .easeInOut(duration: duration).repeatForever(autoreverses: true)
    }

    static func blink(duration: Double = 0.5) -> Animation {
        .easeInOut(duration: duration).repeatForever(autoreverses: true)
    }
}

// MARK: - View Modifiers

struct GlassPanel: ViewModifier {
    var cornerRadius: CGFloat = 16
    var borderColor: Color = GTNWColors.neonCyan.opacity(0.3)

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(borderColor, lineWidth: 1)
                    )
                    .shadow(color: borderColor.opacity(0.5), radius: 10, x: 0, y: 5)
            )
    }
}

struct NeonGlow: ViewModifier {
    var color: Color
    var radius: CGFloat = 10

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(0.8), radius: radius, x: 0, y: 0)
            .shadow(color: color.opacity(0.6), radius: radius * 1.5, x: 0, y: 0)
            .shadow(color: color.opacity(0.4), radius: radius * 2, x: 0, y: 0)
    }
}

struct HoverScale: ViewModifier {
    @State private var isHovered = false
    var scale: CGFloat = 1.05

    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovered ? scale : 1.0)
            .animation(GTNWAnimations.spring, value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

struct PulseEffect: ViewModifier {
    @State private var isPulsing = false
    var color: Color

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color, lineWidth: isPulsing ? 3 : 1)
                    .scaleEffect(isPulsing ? 1.05 : 1.0)
                    .opacity(isPulsing ? 0.0 : 1.0)
            )
            .onAppear {
                withAnimation(GTNWAnimations.pulse(duration: 1.5)) {
                    isPulsing = true
                }
            }
    }
}

struct ModernCard: ViewModifier {
    var cornerRadius: CGFloat = 16
    var glowColor: Color = GTNWColors.neonCyan

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(GTNWColors.glassPanelMedium)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(
                                LinearGradient(
                                    colors: [glowColor.opacity(0.5), glowColor.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
                    .shadow(color: glowColor.opacity(0.3), radius: 15, x: 0, y: 8)
            )
    }
}

// MARK: - View Extensions

extension View {
    func glassPanel(cornerRadius: CGFloat = 16, borderColor: Color = GTNWColors.neonCyan.opacity(0.3)) -> some View {
        modifier(GlassPanel(cornerRadius: cornerRadius, borderColor: borderColor))
    }

    func neonGlow(color: Color, radius: CGFloat = 10) -> some View {
        modifier(NeonGlow(color: color, radius: radius))
    }

    func hoverScale(scale: CGFloat = 1.05) -> some View {
        modifier(HoverScale(scale: scale))
    }

    func pulseEffect(color: Color) -> some View {
        modifier(PulseEffect(color: color))
    }

    func modernCard(cornerRadius: CGFloat = 16, glowColor: Color = GTNWColors.neonCyan) -> some View {
        modifier(ModernCard(cornerRadius: cornerRadius, glowColor: glowColor))
    }
}

// MARK: - Reusable Components

struct DefconIndicator: View {
    let level: DefconLevel
    @State private var isPulsing = false

    var body: some View {
        HStack(spacing: 12) {
            // Animated circle
            Circle()
                .fill(level.color)
                .frame(width: 24, height: 24)
                .overlay(
                    Circle()
                        .stroke(level.color, lineWidth: 2)
                        .scaleEffect(isPulsing ? 1.5 : 1.0)
                        .opacity(isPulsing ? 0.0 : 1.0)
                )
                .shadow(color: level.color, radius: isPulsing ? 20 : 10)

            VStack(alignment: .leading, spacing: 2) {
                Text("DEFCON \(level.rawValue)")
                    .font(GTNWFonts.terminal(size: 28, weight: .bold))
                    .foregroundColor(level.color)

                Text(level.description)
                    .font(GTNWFonts.caption())
                    .foregroundColor(GTNWColors.terminalAmber)
            }
        }
        .padding()
        .modernCard(glowColor: level.color)
        .onAppear {
            if level.rawValue <= 2 {
                withAnimation(GTNWAnimations.pulse()) {
                    isPulsing = true
                }
            }
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    @State private var show = false

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundColor(color)
                .neonGlow(color: color, radius: 8)

            Text(value)
                .font(GTNWFonts.terminal(size: 24, weight: .bold))
                .foregroundColor(color)

            Text(title)
                .font(GTNWFonts.caption())
                .foregroundColor(GTNWColors.terminalAmber)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .modernCard(glowColor: color)
        .scaleEffect(show ? 1.0 : 0.8)
        .opacity(show ? 1.0 : 0.0)
        .onAppear {
            withAnimation(GTNWAnimations.spring.delay(Double.random(in: 0...0.3))) {
                show = true
            }
        }
    }
}

struct ModernButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    let enabled: Bool
    @State private var isPressed = false
    @State private var isHovered = false

    init(title: String, icon: String, color: Color, enabled: Bool = true, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.color = color
        self.enabled = enabled
        self.action = action
    }

    var body: some View {
        Button(action: {
            if enabled {
                withAnimation(GTNWAnimations.quick) {
                    isPressed = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(GTNWAnimations.quick) {
                        isPressed = false
                    }
                    action()
                }
            }
        }) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundColor(enabled ? color : color.opacity(0.3))

                Text(title)
                    .font(GTNWFonts.terminal(size: 14, weight: .bold))
                    .foregroundColor(enabled ? color : color.opacity(0.3))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: GTNWCorners.md)
                    .fill(
                        enabled ?
                        LinearGradient(
                            colors: [
                                color.opacity(isPressed ? 0.3 : (isHovered ? 0.15 : 0.1)),
                                color.opacity(isPressed ? 0.2 : (isHovered ? 0.1 : 0.05))
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ) :
                        LinearGradient(
                            colors: [Color.gray.opacity(0.1), Color.gray.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: GTNWCorners.md)
                            .stroke(
                                enabled ? color.opacity(isHovered ? 0.8 : 0.5) : Color.gray.opacity(0.3),
                                lineWidth: isHovered ? 2 : 1
                            )
                    )
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .shadow(
                color: enabled ? color.opacity(isHovered ? 0.5 : 0.3) : .clear,
                radius: isHovered ? 15 : 8,
                x: 0,
                y: isHovered ? 8 : 4
            )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .onHover { hovering in
            withAnimation(GTNWAnimations.quick) {
                isHovered = hovering
            }
        }
    }
}

struct SectionHeader: View {
    let title: String
    let icon: String?
    let color: Color

    init(_ title: String, icon: String? = nil, color: Color = GTNWColors.terminalAmber) {
        self.title = title
        self.icon = icon
        self.color = color
    }

    var body: some View {
        HStack(spacing: 12) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(color)
            }

            Text(title)
                .font(GTNWFonts.heading())
                .foregroundColor(color)

            Spacer()

            // Decorative line
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [color, color.opacity(0.0)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 200, height: 2)
        }
        .padding(.horizontal)
    }
}

struct ProgressRing: View {
    let progress: Double  // 0.0 to 1.0
    let color: Color
    let lineWidth: CGFloat
    @State private var animatedProgress: Double = 0.0

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(color.opacity(0.2), lineWidth: lineWidth)

            // Progress ring
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    AngularGradient(
                        colors: [color.opacity(0.5), color, color.opacity(0.5)],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: color, radius: 10)
        }
        .onAppear {
            withAnimation(GTNWAnimations.slow) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { newValue in
            withAnimation(GTNWAnimations.standard) {
                animatedProgress = newValue
            }
        }
    }
}

struct ThreatLevelIndicator: View {
    let level: Int  // 0-100
    let label: String

    private var color: Color {
        switch level {
        case 0..<25: return GTNWColors.terminalGreen
        case 25..<50: return GTNWColors.neonCyan
        case 50..<75: return GTNWColors.terminalAmber
        default: return GTNWColors.terminalRed
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(GTNWFonts.caption())
                .foregroundColor(GTNWColors.terminalAmber)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.black.opacity(0.5))

                    // Progress
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [color, color.opacity(0.6)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * CGFloat(level) / 100.0)
                        .shadow(color: color, radius: 5)

                    // Percentage
                    Text("\(level)%")
                        .font(GTNWFonts.terminal(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 20)
        }
        .frame(height: 50)
    }
}

struct ScanlineOverlay: View {
    @State private var offset: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 4) {
                ForEach(0..<Int(geo.size.height / 8), id: \.self) { _ in
                    Rectangle()
                        .fill(Color.white.opacity(0.02))
                        .frame(height: 2)
                }
            }
            .offset(y: offset)
            .onAppear {
                withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                    offset = 8
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Extensions

extension View {
    func terminalBackground() -> some View {
        self.background(GTNWColors.spaceBackground.edgesIgnoringSafeArea(.all))
    }

    func commandCenterBackground() -> some View {
        self.background(GTNWColors.commandCenterBackground.edgesIgnoringSafeArea(.all))
    }
}
