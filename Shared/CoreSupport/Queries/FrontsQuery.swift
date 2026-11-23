//
//  FrontsQuery.swift
//  GTNWCore
//
//  `{"q":"fronts"}`: the War Room (WarRoomView): every front, fighting first, with its troop and damage
//  assessments, momentum, the U.S. commitment, what the President may order on it (commit, recall, demand surrender,
//  sue for peace, broker a ceasefire) with the odds a surrender demand is accepted, the War Powers clock where the
//  Resolution applies, and the operations log.
//

#if GTNW_CORE
import Foundation

enum FrontsQuery: BridgeQuery {
    static let name = "fronts"

    struct Row: Encodable { var label: String; var attacker: Int; var defender: Int }

    struct Front: Encodable {
        var id: String
        var attacker: String
        var attackerName: String
        var attackerFlag: String
        var defender: String
        var defenderName: String
        var defenderFlag: String
        /// fighting, attackerWon, defenderWon, ceasefire
        var status: String
        var statusText: String
        var started: String
        /// -1 (defender) … +1 (attacker)
        var momentum: Double
        var momentumLine: String
        var troops: [Row]
        var damage: [Row]
        var usSide: String?
        var usTroops: Int
        /// The player is one of the two belligerents.
        var usBelligerent: Bool
        /// Commit / recall (only on a front the player is not fighting itself).
        var canSendToDefender: Bool
        var canSendToAttacker: Bool
        var canRecall: Bool
        var canDemandSurrender: Bool
        var surrenderOdds: Double?
        /// Sue for peace (the player fights) or broker a ceasefire (it doesn't).
        var peaceVerb: String?
        /// "War Powers: 45 days" / "War Powers: withdraw 20 days" / "Authorized by Congress", for a U.S. war after 1973.
        var warPowers: String?
    }

    struct Result: Encodable {
        var date: String
        var player: String
        var freeTroops: Int
        var actionsRemaining: Int
        var fronts: [Front]
        var warLog: [String]
        /// The War Powers Resolution line the Congress sheet shows (U.S. only).
        var warPowersNote: String?
        var settlementWaiting: Bool
    }

    static func run(_ args: NoArgs, engine: GameEngine?) throws -> Result {
        let (e, gs) = try GTNWBridge.game(engine)
        let us = gs.playerCountryID
        let fronts = gs.shadow.fronts.sorted { ($0.status == .fighting ? 0 : 1, $0.startDate) < ($1.status == .fighting ? 0 : 1, $1.startDate) }
        func n(_ id: String) -> String { gs.getCountry(id: id)?.name ?? id }
        let out = fronts.map { f -> Front in
            let belligerent = f.attacker == us || f.defender == us
            let fighting = f.status == .fighting
            let status: String
            switch f.status {
            case .fighting: status = "Fighting · since \(GameCalendar.format(f.startDate))"
            case .attackerWon: status = "\(n(f.defender)) surrendered"
            case .defenderWon: status = "\(n(f.attacker)) withdrew"
            case .ceasefire: status = "Ceasefire"
            }
            let momentumLine = f.attackerMomentum > 0.05 ? "\(n(f.attacker)) is advancing"
                : (f.attackerMomentum < -0.05 ? "\(n(f.defender)) is holding and pushing back" : "The front is static")
            let demander = f.usSide ?? (f.attacker == us ? f.attacker : f.defender)
            let canDemand = fighting && (belligerent || f.usSide != nil)
            return Front(
                id: f.id.uuidString, attacker: f.attacker, attackerName: n(f.attacker), attackerFlag: WarSupport.flag(f.attacker, gs),
                defender: f.defender, defenderName: n(f.defender), defenderFlag: WarSupport.flag(f.defender, gs),
                status: f.status.rawValue, statusText: status, started: GameCalendar.format(f.startDate),
                momentum: QueryText.round2(f.attackerMomentum), momentumLine: momentumLine,
                troops: [
                    Row(label: "In theater (K)", attacker: Int(f.attackerTroops), defender: Int(f.defenderTroops)),
                    Row(label: "Initial (K)", attacker: Int(f.attackerInitial), defender: Int(f.defenderInitial)),
                    Row(label: "Will to fight %", attacker: Int(f.attackerWill * 100), defender: Int(f.defenderWill * 100)),
                    Row(label: "U.S. troops (K)", attacker: f.usSide == f.attacker ? Int(f.usTroops) : 0, defender: f.usSide == f.defender ? Int(f.usTroops) : 0),
                ],
                damage: [
                    Row(label: "Military dead (K)", attacker: Int(f.attackerDead), defender: Int(f.defenderDead)),
                    Row(label: "Civilian dead (K)", attacker: 0, defender: Int(f.civilianDead)),
                    Row(label: "Economic loss ($B)", attacker: 0, defender: Int(f.economicLoss)),
                    Row(label: "Weeks of fighting", attacker: f.battles, defender: f.battles),
                ],
                usSide: f.usSide, usTroops: Int(f.usTroops), usBelligerent: belligerent,
                canSendToDefender: fighting && !belligerent && f.usSide != f.attacker,
                canSendToAttacker: fighting && !belligerent && f.usSide != f.defender,
                canRecall: fighting && !belligerent && f.usTroops > 0 && f.usSide != nil,
                canDemandSurrender: canDemand,
                surrenderOdds: fighting ? QueryText.round2(CombatModel.surrenderAcceptance(f, demandedBy: demander)) : nil,
                peaceVerb: fighting ? (belligerent ? "sueForPeace" : "brokerCeasefire") : nil,
                warPowers: fighting ? warPowers(f, gs: gs, engine: e) : nil)
        }
        return Result(
            date: gs.currentDateLabel, player: us, freeTroops: Int(AttackSizing.freeTroops(gs)), actionsRemaining: gs.actionsRemaining,
            fronts: out, warLog: Array(gs.shadow.warLog.suffix(40).reversed()),
            warPowersNote: us == "USA" ? (gs.currentDate >= CongressModel.warPowersResolution
                ? "War Powers Resolution (1973): hostilities without authorization start a 60-day clock, then 30 days to withdraw."
                : "Before the War Powers Resolution (1973) Presidents often fought without asking; asking still rallies the country.") : nil,
            settlementWaiting: !gs.shadow.pendingSettlements.isEmpty)
    }

    /// CongressBadge's War Powers line, for the enemy on this front.
    static func warPowers(_ f: WarFront, gs: GameState, engine: GameEngine) -> String? {
        let us = gs.playerCountryID
        guard us == "USA", gs.currentDate >= CongressModel.warPowersResolution, f.usSide != nil || f.attacker == us || f.defender == us else { return nil }
        let enemy = f.usSide.map { $0 == f.attacker ? f.defender : f.attacker } ?? (f.attacker == us ? f.defender : f.attacker)
        if engine.isAuthorized(enemy) { return "Authorized by Congress" }
        guard let c = gs.shadow.warPowersClocks[enemy] else { return "War Powers: clear" }
        let left = CongressModel.clockDays - GameCalendar.days(from: c.started, to: gs.currentDate)
        return left > 0 ? "War Powers: \(left) days" : "War Powers: withdraw \(max(0, left + CongressModel.withdrawalDays)) days"
    }
}
#endif
