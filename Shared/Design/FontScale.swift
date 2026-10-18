//
//  FontScale.swift
//  Global Thermal Nuclear War
//
//  One central text-scale factor for the whole app. macOS SwiftUI ignores Dynamic Type, so every font in GTNW is
//  built through `Font.scaled(...)` (fixed sizes and text styles alike) and multiplied by `FontScale.factor`.
//  Default: 2.0 on macOS, 1.0 on iOS/iPadOS (where factor 1.0 keeps the native Dynamic Type text styles).
//  The value is a user preference (Settings > Game > Text size), persisted in UserDefaults and applied live.
//  A source-grep test (GTNWSecurityTests.testNoUnscaledFontCalls) fails if any `.font(` call bypasses it.
//  Repository: https://github.com/kochj23/GTNW
//

import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// The selected text scale, persisted in UserDefaults (inject a suite in tests).
final class FontScaleManager: ObservableObject {
    static let defaultsKey = "GTNW.fontScale"
    static let shared = FontScaleManager()

    private let defaults: UserDefaults

    @Published var factor: CGFloat {
        didSet { defaults.set(Double(factor), forKey: Self.defaultsKey) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.object(forKey: Self.defaultsKey) as? Double
        factor = FontScale.clamp(stored.map { CGFloat($0) } ?? FontScale.platformDefault)
    }
}

enum FontScale {
    /// The steps offered in Settings.
    static let steps: [CGFloat] = [1.0, 1.5, 2.0, 2.5]

    #if os(macOS)
    static let platformDefault: CGFloat = 2.0
    #else
    static let platformDefault: CGFloat = 1.0
    #endif

    /// Overrides the preference without touching saved settings (offscreen snapshot / layout tests).
    static var forced: CGFloat?

    /// The live multiplier applied to every font in the app.
    static var factor: CGFloat { forced ?? FontScaleManager.shared.factor }

    /// Scales a layout length (a fixed frame that holds text) by the current factor.
    static func of(_ value: CGFloat) -> CGFloat { (value * factor).rounded() }

    /// Scales a fixed width by the factor, capped to the usable screen width (sheets/windows never outgrow the display).
    static func w(_ value: CGFloat) -> CGFloat { min(of(value), max(value, screenSize.width * 0.94)) }

    /// Scales a fixed height by the factor, capped to the usable screen height.
    static func h(_ value: CGFloat) -> CGFloat { min(of(value), max(value, screenSize.height * 0.9)) }

    /// The usable area of the main display (a large default when no screen is attached, e.g. headless tests).
    static var screenSize: CGSize {
        #if os(macOS)
        return NSScreen.main?.visibleFrame.size ?? CGSize(width: 3440, height: 1400)
        #else
        return UIScreen.main.bounds.size
        #endif
    }

    static func clamp(_ value: CGFloat) -> CGFloat { min(max(value, steps.first!), steps.last!) }

    static func label(_ step: CGFloat) -> String {
        step == step.rounded() ? "\(Int(step))×" : String(format: "%.1f×", step)
    }

    /// Point size of a text style at factor 1.0 (the platform's default size for that style).
    static func pointSize(_ style: Font.TextStyle) -> CGFloat {
        #if os(macOS)
        switch style {
        case .largeTitle: return 26
        case .title: return 22
        case .title2: return 17
        case .title3: return 15
        case .headline: return 13
        case .subheadline: return 11
        case .body: return 13
        case .callout: return 12
        case .footnote: return 10
        case .caption: return 10
        case .caption2: return 10
        @unknown default: return 13
        }
        #else
        switch style {
        case .largeTitle: return 34
        case .title: return 28
        case .title2: return 22
        case .title3: return 20
        case .headline: return 17
        case .subheadline: return 15
        case .body: return 17
        case .callout: return 16
        case .footnote: return 13
        case .caption: return 12
        case .caption2: return 11
        @unknown default: return 17
        }
        #endif
    }

    /// The weight a text style carries by default.
    static func defaultWeight(_ style: Font.TextStyle) -> Font.Weight {
        #if os(macOS)
        switch style {
        case .headline: return .bold
        case .caption2: return .medium
        default: return .regular
        }
        #else
        return style == .headline ? .semibold : .regular
        #endif
    }
}

extension Font {
    /// A fixed-size system font multiplied by `FontScale.factor`. Drop-in for `.system(size:weight:design:)`.
    static func scaled(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> Font {
        .system(size: size * FontScale.factor, weight: weight, design: design)
    }

    /// A text style at its platform point size multiplied by `FontScale.factor`. Drop-in for `.caption`,
    /// `.headline`, `.system(.caption, design: .monospaced)` etc. On iOS at factor 1.0 the native (Dynamic Type) style is used.
    static func scaled(_ style: Font.TextStyle, design: Font.Design = .default, weight: Font.Weight? = nil) -> Font {
        let factor = FontScale.factor
        #if !os(macOS)
        // iOS/iPadOS at 1.0: keep the native text style so Dynamic Type still applies.
        if factor == 1 {
            let base = Font.system(style, design: design)
            return weight.map { base.weight($0) } ?? base
        }
        #endif
        return .system(size: FontScale.pointSize(style) * factor,
                       weight: weight ?? FontScale.defaultWeight(style), design: design)
    }

    /// A named font (e.g. the Retro skin's Monaco) multiplied by `FontScale.factor`.
    static func scaledCustom(_ name: String, size: CGFloat) -> Font {
        .custom(name, size: size * FontScale.factor)
    }
}

// MARK: - Scaled controls

// Native AppKit controls (segmented pickers, pop-up buttons, checkboxes) are drawn at a fixed size and ignore `.font`,
// and magnifying them with scaleEffect blurs them. These SwiftUI equivalents draw their text with `Font.scaled`.

/// A segmented choice (replaces `Picker` + `.segmented`).
struct ScaledSegmentedPicker<Value: Hashable>: View {
    @Binding var selection: Value
    let options: [(value: Value, label: String)]
    var size: CGFloat = 12
    var textColor: Color = .primary

    init(selection: Binding<Value>, options: [(Value, String)], size: CGFloat = 12, textColor: Color = .primary) {
        _selection = selection
        self.options = options.map { (value: $0.0, label: $0.1) }
        self.size = size
        self.textColor = textColor
    }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options.indices, id: \.self) { i in
                let option = options[i], on = option.value == selection
                Button { selection = option.value } label: {
                    Text(option.label)
                        .font(.scaled(size: size, weight: on ? .semibold : .regular))
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.horizontal, 8 * FontScale.factor).padding(.vertical, 3 * FontScale.factor)
                        .frame(maxWidth: .infinity)
                        .foregroundColor(on ? .white : textColor)
                        .background(RoundedRectangle(cornerRadius: 5 * FontScale.factor)
                            .fill(on ? Color.accentColor : Color.clear))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(option.label)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(2)
        .background(RoundedRectangle(cornerRadius: 6 * FontScale.factor).fill(textColor.opacity(0.1)))
    }
}

/// A drop-down choice (replaces a pop-up `Picker`).
struct ScaledMenuPicker<Value: Hashable>: View {
    @Binding var selection: Value
    let options: [(value: Value, label: String)]
    var size: CGFloat = 12
    var textColor: Color = .primary

    init(selection: Binding<Value>, options: [(Value, String)], size: CGFloat = 12, textColor: Color = .primary) {
        _selection = selection
        self.options = options.map { (value: $0.0, label: $0.1) }
        self.size = size
        self.textColor = textColor
    }

    private var current: String { options.first { $0.value == selection }?.label ?? "—" }

    var body: some View {
        Menu {
            ForEach(options.indices, id: \.self) { i in
                Button(options[i].label) { selection = options[i].value }
            }
        } label: {
            HStack(spacing: 6 * FontScale.factor) {
                Text(current).font(.scaled(size: size)).lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: "chevron.up.chevron.down").font(.scaled(size: size * 0.75, weight: .semibold))
            }
            .foregroundColor(textColor)
            .padding(.horizontal, 8 * FontScale.factor).padding(.vertical, 3 * FontScale.factor)
            .background(RoundedRectangle(cornerRadius: 5 * FontScale.factor).fill(textColor.opacity(0.12)))
            .contentShape(Rectangle())
        }
        .scaledMenuChrome()
        .menuIndicator(.hidden)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityValue(current)
    }
}

private extension View {
    /// macOS draws a Menu's label natively unless it uses the button menu style with a plain button style.
    /// (iOS already draws the SwiftUI label.)
    @ViewBuilder func scaledMenuChrome() -> some View {
        #if os(macOS)
        self.menuStyle(.button).buttonStyle(.plain)
        #else
        self
        #endif
    }
}

/// A settings row: a title and a control (LabeledContent where available; it needs iOS 16).
struct ScaledLabeledRow<Content: View>: View {
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View { row }

    private var row: AnyView {
        if #available(macOS 13, iOS 16, *) {
            return AnyView(LabeledContent { content } label: { Text(title) })
        }
        return AnyView(HStack { Text(title); Spacer(); content })
    }
}

/// A checkbox whose box grows with the text (replaces the native checkbox).
struct ScaledCheckboxStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            HStack(spacing: 6) {
                Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                    .font(.scaled(size: 14))
                    .foregroundColor(configuration.isOn ? .accentColor : .secondary)
                configuration.label
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(configuration.isOn ? .isSelected : [])
    }
}

extension ToggleStyle where Self == ScaledCheckboxStyle {
    static var scaledCheckbox: ScaledCheckboxStyle { .init() }
}

// MARK: - Settings

struct FontScalePicker: View {
    @ObservedObject private var scale = FontScaleManager.shared

    var body: some View {
        ScaledLabeledRow("Text size") {
            ScaledSegmentedPicker(selection: $scale.factor, options: FontScale.steps.map { ($0, FontScale.label($0)) })
                .fixedSize()
        }
    }
}
