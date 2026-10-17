//
//  Theme.swift
//  Global Thermal Nuclear War
//
//  Two skins, one layout: Modern (GTNW's glass/neon look) and Retro (a 1990s EGA look — the 16-colour palette,
//  monospaced type and beveled VGA-era panels). Every colour token in GTNWColors / ModernColors / AppSettings asks
//  the theme, so existing screens reskin without per-view changes. Retro works with or without the optional
//  Shadow Pack: pixel art from the pack is used where available, drawn equivalents otherwise.
//  Repository: https://github.com/kochj23/GTNW
//

import SwiftUI

enum GameTheme: String, CaseIterable, Identifiable, Codable {
    case modern, retro
    var id: String { rawValue }
    var displayName: String { self == .modern ? "Modern" : "Retro (EGA)" }
}

/// The selected skin, persisted in UserDefaults (inject a suite in tests).
final class ThemeManager: ObservableObject {
    static let defaultsKey = "GTNW.theme"
    static let shared = ThemeManager()

    private let defaults: UserDefaults

    @Published var theme: GameTheme {
        didSet { defaults.set(theme.rawValue, forKey: Self.defaultsKey) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        theme = defaults.string(forKey: Self.defaultsKey).flatMap(GameTheme.init(rawValue:)) ?? .modern
    }

    var isRetro: Bool { theme == .retro }
    func toggle() { theme = isRetro ? .modern : .retro }
}

/// Global switch read by the colour tokens.
enum Theme {
    /// Forces a skin without touching saved preferences (used by offscreen snapshot tests).
    static var forced: GameTheme?
    static var isRetro: Bool { (forced ?? ThemeManager.shared.theme) == .retro }
}

/// The standard 16-colour EGA palette.
enum EGA {
    static let black = Color(red: 0, green: 0, blue: 0)
    static let blue = Color(red: 0, green: 0, blue: 0xAA / 255.0)
    static let green = Color(red: 0, green: 0xAA / 255.0, blue: 0)
    static let cyan = Color(red: 0, green: 0xAA / 255.0, blue: 0xAA / 255.0)
    static let red = Color(red: 0xAA / 255.0, green: 0, blue: 0)
    static let magenta = Color(red: 0xAA / 255.0, green: 0, blue: 0xAA / 255.0)
    static let brown = Color(red: 0xAA / 255.0, green: 0x55 / 255.0, blue: 0)
    static let lightGray = Color(red: 0xAA / 255.0, green: 0xAA / 255.0, blue: 0xAA / 255.0)
    static let darkGray = Color(red: 0x55 / 255.0, green: 0x55 / 255.0, blue: 0x55 / 255.0)
    static let lightBlue = Color(red: 0x55 / 255.0, green: 0x55 / 255.0, blue: 1)
    static let lightGreen = Color(red: 0x55 / 255.0, green: 1, blue: 0x55 / 255.0)
    static let lightCyan = Color(red: 0x55 / 255.0, green: 1, blue: 1)
    static let lightRed = Color(red: 1, green: 0x55 / 255.0, blue: 0x55 / 255.0)
    static let lightMagenta = Color(red: 1, green: 0x55 / 255.0, blue: 1)
    static let yellow = Color(red: 1, green: 1, blue: 0x55 / 255.0)
    static let white = Color(red: 1, green: 1, blue: 1)

    static let all: [Color] = [black, blue, green, cyan, red, magenta, brown, lightGray,
                               darkGray, lightBlue, lightGreen, lightCyan, lightRed, lightMagenta, yellow, white]

    /// A 7-band ramp (calm → crisis) built only from EGA colours, for map filters and gauges.
    static let ramp: [Color] = [blue, cyan, green, lightGreen, yellow, brown, lightRed]

    /// Solid "gradient" so token types stay LinearGradient in both themes.
    static func solid(_ c: Color) -> LinearGradient { LinearGradient(colors: [c, c], startPoint: .top, endPoint: .bottom) }

    /// The retro typeface: a monospaced bitmap-style face.
    static func font(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        #if os(macOS)
        return Font.custom("Monaco", size: size).weight(weight == .regular ? .regular : .bold)
        #else
        return Font.custom("Courier", size: size).weight(weight == .regular ? .regular : .bold)
        #endif
    }
}

// MARK: - Retro panel chrome

/// A beveled VGA-era panel: light edge top-left, dark edge bottom-right, hard black outline.
struct RetroBevel: View {
    var fill: Color = EGA.blue
    var raised = true
    var width: CGFloat = 2

    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            ZStack {
                Rectangle().fill(fill)
                Path { p in
                    p.addRect(CGRect(x: 0, y: 0, width: w, height: width))
                    p.addRect(CGRect(x: 0, y: 0, width: width, height: h))
                }.fill(raised ? EGA.white : EGA.darkGray)
                Path { p in
                    p.addRect(CGRect(x: 0, y: h - width, width: w, height: width))
                    p.addRect(CGRect(x: w - width, y: 0, width: width, height: h))
                }.fill(raised ? EGA.darkGray : EGA.white)
                Rectangle().stroke(EGA.black, lineWidth: 1)
            }
        }
    }
}

/// Panel background for either theme: glass in Modern, a beveled EGA panel in Retro.
struct ThemedPanel: ViewModifier {
    @ObservedObject private var themes = ThemeManager.shared
    var accent: Color = GTNWColors.neonCyan
    var retroFill: Color = EGA.blue

    func body(content: Content) -> some View {
        if Theme.isRetro {
            content.background(RetroBevel(fill: retroFill))
        } else {
            content.background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.55))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(accent.opacity(0.35), lineWidth: 1))
            )
        }
    }
}

/// Button look for either theme.
struct ThemedButtonStyle: ButtonStyle {
    var color: Color = GTNWColors.neonCyan
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        Group {
            if Theme.isRetro {
                configuration.label
                    .font(EGA.font(size: 12, weight: .bold))
                    .foregroundColor(prominent ? EGA.black : EGA.white)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(RetroBevel(fill: prominent ? EGA.lightGray : EGA.blue, raised: !configuration.isPressed))
            } else {
                configuration.label
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(prominent ? .black : color)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 8).fill(prominent ? color : color.opacity(configuration.isPressed ? 0.3 : 0.12)))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.6), lineWidth: 1))
            }
        }
    }
}

extension View {
    func themedPanel(accent: Color = GTNWColors.neonCyan, retroFill: Color = EGA.blue) -> some View {
        modifier(ThemedPanel(accent: accent, retroFill: retroFill))
    }
}

/// Theme-aware font helper for new views.
enum ThemeFont {
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        Theme.isRetro ? EGA.font(size: size, weight: weight) : .system(size: size, weight: weight, design: .monospaced)
    }
}

// MARK: - Settings

struct ThemeSettingsView: View {
    @ObservedObject private var themes = ThemeManager.shared
    @AppStorage(GameCalendar.turnLengthDefaultsKey) private var turnLength: String = TurnLength.month.rawValue
    @AppStorage(ShadowSettings.electionsKey) private var elections: Bool = true

    var body: some View {
        Form {
            Section("Look") {
                Picker("Skin", selection: $themes.theme) {
                    ForEach(GameTheme.allCases) { Text($0.displayName).tag($0) }
                }
                Text("Retro uses the 16-colour EGA palette and beveled panels. Shadow Pack art appears when the pack is installed.")
                    .font(.caption).foregroundColor(.secondary)
            }
            Section("New games") {
                Picker("Turn length", selection: $turnLength) {
                    ForEach(TurnLength.allCases) { Text("\($0.displayName) (\($0.actionsPerTurn) action\($0.actionsPerTurn == 1 ? "" : "s"))").tag($0.rawValue) }
                }
                Toggle("Presidential elections", isOn: $elections)
            }
        }
        .padding()
        .frame(minWidth: 420)
    }
}
