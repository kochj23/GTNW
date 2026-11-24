//
//  CartographyHallView.swift
//  Global Thermal Nuclear War
//
//  3.36.0: the Hall of Cartography in the Records sheet's Names tab: every name the President has used, in every
//  game, newest first (game, date in that game, old → new). Both skins; one VoiceOver line per name.
//  Repository: https://github.com/kochj23/GTNW
//

import SwiftUI

struct CartographyHallList: View {
    /// Read once when the tab opens; the hall changes only when the President renames something.
    @State private var entries: [CartographyEntry] = CartographyHall.entries()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("HALL OF CARTOGRAPHY").font(ThemeFont.mono(14, .bold)).foregroundColor(GTNWColors.terminalAmber).padding(.top, 8)
                .accessibilityAddTraits(.isHeader)
            Text(entries.isEmpty ? "Every name you give a land, in any game, is kept here."
                 : "\(entries.count) name\(entries.count == 1 ? "" : "s") across your games.")
                .font(ThemeFont.mono(10)).foregroundColor(GTNWColors.neonCyan)
            ScrollView {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(entries.prefix(200)) { e in
                        let real = WorldCountriesDatabase.template(id: e.targetID)?.name ?? e.targetID
                        let from = NameScreen.shown(e.from, fallback: real), to = NameScreen.shown(e.to, fallback: real)
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(verbatim: "\(from) → \(to)").font(ThemeFont.mono(10, .bold))
                                    .foregroundColor(Theme.isRetro ? EGA.white : .white).fixedSize(horizontal: false, vertical: true)
                                Text(verbatim: e.gameLabel.uppercased()).font(ThemeFont.mono(8)).foregroundColor(GTNWColors.terminalGreen)
                            }
                            Spacer()
                            Text(verbatim: GameCalendar.format(e.gameDate)).font(ThemeFont.mono(9)).foregroundColor(GTNWColors.neonCyan)
                        }
                        .padding(3).themedPanel(retroFill: EGA.black)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(from) renamed \(to), \(e.gameLabel), \(GameCalendar.format(e.gameDate))")
                    }
                }
            }
            .frame(maxHeight: FontScale.h(260))
        }
    }
}
