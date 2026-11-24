//
//  PresidencyEpilogueView.swift
//  Global Thermal Nuclear War
//
//  3.36.0: the end screen's "after the presidency" section (the history books' verdict, the library, fifty years
//  later, the awards this game) and the Records sheet's AWARDS tab. Both skins through the terminal colors; no
//  animation; each block reads as one VoiceOver element. The content comes from PresidencyRecord.swift.
//  Repository: https://github.com/kochj23/GTNW
//

import SwiftUI

/// The end screen's epilogue. Its own section, beside the debrief, so other end-screen sections fit around it.
struct PresidencyEpilogueView: View {
    @ObservedObject var gameState: GameState
    let victoryType: VictoryType?

    private var record: PresidencyRecord { gameState.shadow.presidency }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("AFTER THE PRESIDENCY")
                .font(.scaled(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(AppSettings.terminalAmber)
                .accessibilityAddTraits(.isHeader)

            block("THE HISTORY BOOKS", PresidencyEpilogue.verdict(gameState, victory: victoryType),
                  note: record.verdict == nil ? nil : "Polished by Nova from the record; every fact is the game's.")
            block("THE LIBRARY", PresidencyEpilogue.library(gameState))

            let later = PresidencyEpilogue.fiftyYearsLater(gameState)
            if !later.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    heading("FIFTY YEARS LATER")
                    ForEach(later) { a in
                        Text(verbatim: a.line)
                            .font(.scaled(size: 11, design: .monospaced))
                            .foregroundColor(a.survives ? AppSettings.terminalGreen : .white.opacity(0.8))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .accessibilityElement(children: .combine)
            }

            if !record.awards.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    heading("AWARDS THIS GAME")
                    ForEach(record.awards, id: \.self) { id in
                        if let a = PresidencyAwards.award(id) {
                            AwardRow(award: a, unlocked: true, isNew: record.firstAwards.contains(id))
                        }
                    }
                    if let line = record.careerLine {
                        Text(verbatim: "Career: \(line).")
                            .font(.scaled(size: 10, design: .monospaced))
                            .foregroundColor(AppSettings.terminalAmber)
                    }
                }
            }
        }
        .frame(maxWidth: 860, alignment: .leading)
        .padding(.horizontal, 40)
    }

    private func heading(_ s: String) -> some View {
        Text(s)
            .font(.scaled(size: 12, weight: .bold, design: .monospaced))
            .foregroundColor(AppSettings.terminalGreen)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func block(_ title: String, _ body: String, note: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            heading(title)
            Text(verbatim: body)
                .font(.scaled(size: 11, design: .monospaced))
                .foregroundColor(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
            if let note {
                Text(verbatim: note)
                    .font(.scaled(size: 9, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// One award: icon, name, description; NEW when first earned this game.
struct AwardRow: View {
    let award: PresidencyAward
    let unlocked: Bool
    var isNew = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: award.icon)
                .font(.scaled(size: 14))
                .foregroundColor(unlocked ? AppSettings.terminalAmber : .gray)
                .frame(width: 22)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: award.name + (isNew ? "  · NEW" : ""))
                    .font(.scaled(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(unlocked ? AppSettings.terminalGreen : .gray)
                Text(verbatim: award.description)
                    .font(.scaled(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(unlocked ? 0.8 : 0.45))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(award.name), \(unlocked ? (isNew ? "new award" : "earned") : "locked"). \(award.description)")
    }
}

/// The Records sheet's AWARDS tab: every presidency award, earned or not, across all games.
struct PresidencyAwardsPanel: View {
    @ObservedObject var gameState: GameState
    var career: PresidencyCareer = PresidencyCareer.load()

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("THE RECORD OF THE PRESIDENCY").font(ThemeFont.mono(16, .bold)).foregroundColor(GTNWColors.terminalAmber)
                .accessibilityAddTraits(.isHeader)
            Text(verbatim: "\(career.awards.count) of \(PresidencyAwards.all.count) earned · \(career.games) game\(career.games == 1 ? "" : "s") · \(career.line) · Antarctica claimed in \(career.antarcticaGames)")
                .font(ThemeFont.mono(10)).foregroundColor(GTNWColors.neonCyan)
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(PresidencyAwards.all) { a in
                        AwardRow(award: a, unlocked: career.awards.contains(a.id))
                            .padding(3).themedPanel(retroFill: EGA.black)
                    }
                    let warnings = gameState.shadow.presidency.warnings
                    if !warnings.isEmpty {
                        Text("I TOLD YOU SO").font(ThemeFont.mono(12, .bold)).foregroundColor(GTNWColors.terminalAmber).padding(.top, 6)
                        ForEach(warnings.suffix(10).reversed()) { w in
                            Text(verbatim: "\(GameCalendar.format(w.date)) · \(w.speaker) on \(w.order): \"\(ToldYouSo.quote(w.text))\"\(w.testified ? " (testified)" : "")")
                                .font(ThemeFont.mono(9)).foregroundColor(Theme.isRetro ? EGA.white : .white)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .frame(maxHeight: FontScale.h(360))
        }
    }
}
