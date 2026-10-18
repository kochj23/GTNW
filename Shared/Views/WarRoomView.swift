//
//  WarRoomView.swift
//  GTNW
//
//  The War Room: every active front with troop and damage assessments and an operations log. The President can
//  commit or recall U.S. troops on either side, demand the enemy's surrender, or sue for peace. Fighting itself is
//  resolved week by week by CombatModel (Shared/Engine/Shadow/CombatModel.swift) as turns pass.
//  Created by Jordan Koch on 2026-01-22; rebuilt around the combat model 2026-10.
//

import SwiftUI

struct WarRoomView: View {
    @EnvironmentObject var gameEngine: GameEngine
    @ObservedObject var gameState: GameState
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFront: UUID?
    @State private var troopStep: Double = 50
    @State private var notice = ""

    private var fronts: [WarFront] {
        gameState.shadow.fronts.sorted { ($0.status == .fighting ? 0 : 1, $0.startDate) < ($1.status == .fighting ? 0 : 1, $1.startDate) }
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                PackImage("warroom.sword") {
                    Image(systemName: "shield.lefthalf.filled").font(.scaled(.title)).foregroundColor(GTNWColors.terminalRed)
                }
                .frame(width: FontScale.w(32), height: FontScale.h(32))
                PackImage("warroom.title") {
                    Text("THE WAR ROOM").font(ThemeFont.mono(22, .bold)).foregroundColor(GTNWColors.terminalRed)
                }
                .frame(maxHeight: FontScale.h(28))
                Spacer()
                Text(gameState.currentDateLabel.uppercased()).font(ThemeFont.mono(12, .bold)).foregroundColor(GTNWColors.terminalAmber)
                Button("CLOSE") { dismiss() }.buttonStyle(ThemedButtonStyle())
            }
            HStack(alignment: .top, spacing: 10) {
                frontList.frame(width: FontScale.w(280))
                if let f = fronts.first(where: { $0.id == selectedFront }) ?? fronts.first(where: { $0.status == .fighting }) {
                    frontDetail(f)
                } else {
                    VStack {
                        Spacer()
                        Text("No wars are being fought. Long may it last.").font(ThemeFont.mono(13)).foregroundColor(GTNWColors.terminalGreen)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            operationsLog.frame(height: FontScale.h(120))
        }
        .padding(14)
        .frame(width: FontScale.w(940), height: FontScale.h(640))
        .background(Theme.isRetro ? EGA.black : Color.black)
        .onAppear { ShadowPack.shared.play("sfx.warroom_enter") }
    }

    private var frontList: some View {
        ScrollView {
            VStack(spacing: 4) {
                ForEach(fronts) { f in
                    Button { selectedFront = f.id } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(name(f.attacker)) → \(name(f.defender))").font(ThemeFont.mono(11, .bold))
                            Text(statusText(f)).font(ThemeFont.mono(9))
                                .foregroundColor(f.status == .fighting ? GTNWColors.terminalRed : GTNWColors.neonCyan)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(6)
                        .foregroundColor(Theme.isRetro ? EGA.white : .white)
                        .background(f.id == selectedFront ? GTNWColors.terminalRed.opacity(0.35) : Color.clear)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .themedPanel(retroFill: EGA.blue)
    }

    private func frontDetail(_ f: WarFront) -> some View {
        let us = gameState.playerCountryID
        let usIsBelligerent = f.attacker == us || f.defender == us
        return VStack(alignment: .leading, spacing: 10) {
            Text("\(flag(f.attacker)) \(name(f.attacker).uppercased())  vs  \(flag(f.defender)) \(name(f.defender).uppercased())")
                .font(ThemeFont.mono(15, .bold)).foregroundColor(GTNWColors.terminalAmber)
            momentumBar(f)
            HStack(alignment: .top, spacing: 12) {
                assessment(title: "TROOP ASSESSMENT", rows: [
                    ("In theater (K)", Int(f.attackerTroops), Int(f.defenderTroops)),
                    ("Initial (K)", Int(f.attackerInitial), Int(f.defenderInitial)),
                    ("Will to fight %", Int(f.attackerWill * 100), Int(f.defenderWill * 100)),
                    ("U.S. troops (K)", f.usSide == f.attacker ? Int(f.usTroops) : 0, f.usSide == f.defender ? Int(f.usTroops) : 0),
                ], f: f)
                assessment(title: "DAMAGE ASSESSMENT", rows: [
                    ("Military dead (K)", Int(f.attackerDead), Int(f.defenderDead)),
                    ("Civilian dead (K)", 0, Int(f.civilianDead)),
                    ("Economic loss ($B)", 0, Int(f.economicLoss)),
                    ("Weeks of fighting", f.battles, f.battles),
                ], f: f)
            }
            if f.status == .fighting {
                HStack(spacing: 8) {
                    Stepper("Troops: \(Int(troopStep))K", value: $troopStep, in: 10...500, step: 10).frame(width: FontScale.w(170))
                    if !usIsBelligerent {
                        Button("SEND TO \(name(f.defender).uppercased())") { act { gameEngine.commitTroops(frontID: f.id, side: f.defender, thousands: troopStep) } }
                            .buttonStyle(ThemedButtonStyle(color: GTNWColors.terminalGreen)).disabled(f.usSide == f.attacker)
                        Button("SEND TO \(name(f.attacker).uppercased())") { act { gameEngine.commitTroops(frontID: f.id, side: f.attacker, thousands: troopStep) } }
                            .buttonStyle(ThemedButtonStyle(color: GTNWColors.terminalRed)).disabled(f.usSide == f.defender)
                        if f.usTroops > 0, let side = f.usSide {
                            Button("RECALL") { act { gameEngine.commitTroops(frontID: f.id, side: side, thousands: -troopStep) } }
                                .buttonStyle(ThemedButtonStyle())
                        }
                    }
                }
                .font(ThemeFont.mono(10))
                HStack(spacing: 8) {
                    if usIsBelligerent || f.usSide != nil {
                        Button("DEMAND SURRENDER") {
                            let accepted = gameEngine.demandSurrender(frontID: f.id)
                            notice = accepted ? "They have accepted your terms." : "Surrender demand rejected. The fighting continues."
                            gameEngine.recordPlayerAction(rung: .military, hostile: true, detected: true)
                        }
                        .buttonStyle(ThemedButtonStyle(color: GTNWColors.terminalAmber, prominent: true))
                    }
                    if usIsBelligerent {
                        Button("SUE FOR PEACE") {
                            let other = f.attacker == us ? f.defender : f.attacker
                            _ = gameEngine.sueForPeace(from: us, to: other)
                            notice = "Ceasefire signed with \(name(other))."
                        }
                        .buttonStyle(ThemedButtonStyle(color: GTNWColors.terminalGreen))
                    } else {
                        Button("BROKER CEASEFIRE") {
                            _ = gameEngine.sueForPeace(from: f.attacker, to: f.defender)
                            gameEngine.completePlayerAction()
                            notice = "U.S. mediators have brokered a ceasefire."
                        }
                        .buttonStyle(ThemedButtonStyle(color: GTNWColors.terminalGreen))
                        .disabled(gameState.actionsRemaining == 0)
                    }
                }
                Text(String(format: "Odds they accept a surrender demand now: %.0f%%",
                            CombatModel.surrenderAcceptance(f, demandedBy: f.usSide ?? (f.attacker == us ? f.attacker : f.defender)) * 100))
                    .font(ThemeFont.mono(10)).foregroundColor(GTNWColors.neonCyan)
            }
            if !notice.isEmpty { Text(notice).font(ThemeFont.mono(11, .bold)).foregroundColor(GTNWColors.terminalAmber) }
            Spacer()
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedPanel(retroFill: EGA.blue)
    }

    private var operationsLog: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                Text("OPERATIONS STATUS").font(ThemeFont.mono(10, .bold)).foregroundColor(GTNWColors.terminalAmber)
                ForEach(Array(gameState.shadow.warLog.suffix(40).reversed().enumerated()), id: \.offset) { _, line in
                    Text(line).font(ThemeFont.mono(10)).foregroundColor(GTNWColors.terminalGreen)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(6)
        }
        .themedPanel(retroFill: EGA.black)
    }

    private func momentumBar(_ f: WarFront) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(f.attackerMomentum > 0.05 ? "\(name(f.attacker)) is advancing" : (f.attackerMomentum < -0.05 ? "\(name(f.defender)) is holding and pushing back" : "The front is static"))
                .font(ThemeFont.mono(10)).foregroundColor(GTNWColors.neonCyan)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Rectangle().fill(GTNWColors.terminalGreen)
                    Rectangle().fill(GTNWColors.terminalRed).frame(width: g.size.width * (f.attackerMomentum + 1) / 2)
                }
            }
            .frame(height: FontScale.h(10))
        }
    }

    private func assessment(title: String, rows: [(String, Int, Int)], f: WarFront) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(ThemeFont.mono(10, .bold)).foregroundColor(GTNWColors.terminalAmber)
            HStack {
                Text("").frame(width: FontScale.w(130), alignment: .leading)
                Text(code(f.attacker)).frame(width: FontScale.w(60), alignment: .trailing)
                Text(code(f.defender)).frame(width: FontScale.w(60), alignment: .trailing)
            }
            .font(ThemeFont.mono(10, .bold)).foregroundColor(GTNWColors.neonCyan)
            ForEach(rows, id: \.0) { r in
                HStack {
                    Text(r.0).frame(width: FontScale.w(130), alignment: .leading)
                    Text("\(r.1)").frame(width: FontScale.w(60), alignment: .trailing)
                    Text("\(r.2)").frame(width: FontScale.w(60), alignment: .trailing)
                }
                .font(ThemeFont.mono(10)).foregroundColor(Theme.isRetro ? EGA.white : .white)
            }
        }
        .padding(6)
        .themedPanel(retroFill: EGA.black)
    }

    private func act(_ f: () -> Bool) {
        notice = f() ? "Orders sent." : "Those orders can't be carried out."
    }

    private func name(_ id: String) -> String { gameState.getCountry(id: id)?.name ?? id }
    private func flag(_ id: String) -> String { gameState.getCountry(id: id)?.flag ?? "" }
    private func code(_ id: String) -> String { id }

    private func statusText(_ f: WarFront) -> String {
        switch f.status {
        case .fighting: return "FIGHTING · since \(GameCalendar.format(f.startDate))"
        case .attackerWon: return "\(name(f.defender)) surrendered"
        case .defenderWon: return "\(name(f.attacker)) withdrew"
        case .ceasefire: return "Ceasefire"
        }
    }
}
