//
//  AdvicePanel.swift
//  Global Thermal Nuclear War
//
//  The advisor's recommendation on a proposed action: portrait, APPROVE / CAUTION / OPPOSE, reason and odds.
//  Repository: https://github.com/kochj23/GTNW
//

import SwiftUI

struct AdvicePanel: View {
    let advice: ActionAdvice

    private var stanceColor: Color {
        switch advice.stance {
        case .approve: return GTNWColors.terminalGreen
        case .caution: return GTNWColors.terminalAmber
        case .oppose: return GTNWColors.terminalRed
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            AdvisorPortrait(title: advice.advisorTitle, name: advice.advisorName, size: 56)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(advice.advisorTitle.uppercased())
                        .font(ThemeFont.mono(10, .bold))
                        .foregroundColor(GTNWColors.neonCyan)
                    Spacer()
                    Text(advice.stance.label)
                        .font(ThemeFont.mono(12, .bold))
                        .foregroundColor(Theme.isRetro ? EGA.black : .black)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(stanceColor)
                }
                Text(advice.advisorName)
                    .font(ThemeFont.mono(11))
                    .foregroundColor(GTNWColors.terminalAmber)
                Text(advice.reason)
                    .font(ThemeFont.mono(11))
                    .foregroundColor(Theme.isRetro ? EGA.white : .white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
                Text(String(format: "Estimated chance of success: %.0f%%", advice.successEstimate * 100))
                    .font(ThemeFont.mono(10))
                    .foregroundColor(GTNWColors.neonCyan)
            }
        }
        .padding(10)
        .themedPanel(accent: stanceColor)
    }
}

/// Advisor portrait: the pack portrait for the post (retro art), otherwise a drawn badge with initials.
struct AdvisorPortrait: View {
    let title: String
    let name: String
    var size: CGFloat = 48
    var status: AdvisorStatus? = nil

    var body: some View {
        ZStack {
            if let key = ShadowPack.advisorKey(forTitle: title) {
                PackImage("advisor.\(key).button", "advisor.\(key).portrait") { drawn }
            } else {
                drawn
            }
            if let s = status, s != .active {
                Rectangle().fill(Color.black.opacity(0.55))
                Text(s == .killed ? "✝" : (s == .scandal ? "!" : "—"))
                    .font(ThemeFont.mono(size * 0.4, .bold))
                    .foregroundColor(GTNWColors.terminalRed)
            }
        }
        .frame(width: size * 1.2, height: size)
        .clipped()
    }

    private var drawn: some View {
        ZStack {
            if Theme.isRetro {
                RetroBevel(fill: EGA.cyan)
            } else {
                RoundedRectangle(cornerRadius: 8).fill(LinearGradient(colors: [Color.blue.opacity(0.6), Color.black], startPoint: .top, endPoint: .bottom))
            }
            Text(initials)
                .font(ThemeFont.mono(size * 0.35, .bold))
                .foregroundColor(Theme.isRetro ? EGA.white : .white)
        }
    }

    private var initials: String {
        let parts = name.replacingOccurrences(of: "Acting: ", with: "").split(separator: " ")
        return parts.prefix(2).compactMap { $0.first }.map(String.init).joined()
    }
}
