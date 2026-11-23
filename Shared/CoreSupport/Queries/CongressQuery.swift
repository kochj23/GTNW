//
//  CongressQuery.swift
//  GTNWCore
//
//  `{"q":"congress","target":"CUB"}`: the app's CongressBadge and ImpeachmentRiskBadge (top-bar read-outs) and the
//  CongressSheet for a target: support by chamber, the War Powers clock, the odds of a declaration or an
//  authorization, and the votes already taken. `target` is optional (the badges need none).
//

#if GTNW_CORE
import Foundation

enum CongressQuery: BridgeQuery {
    static let name = "congress"

    struct Args: Decodable { var target: String? }

    struct Kind: Encodable {
        var id: String
        var title: String
        var odds: Double
        var house: Double
        var senate: Double
        /// strong, some, none
        var casusBelli: String
    }

    struct Vote: Encodable {
        var date: String
        var kind: String
        var passed: Bool
        var houseYes: Int
        var senateYes: Int
    }

    struct Result: Encodable {
        /// Congress and the War Powers clock are U.S.-only (3.11.0); the removal badge is for every nation.
        var usa: Bool
        var house: Double
        var senate: Double
        var warSupport: Int
        /// "WAR POWERS: 45 DAYS", "WAR POWERS: WITHDRAW 20 DAYS" or "WAR POWERS: CLEAR".
        var warPowers: String
        var warPowersRunning: Bool
        /// How the head of government is removed ("Impeachment", "No confidence"…), the risk (LOW, RISING, HIGH), the
        /// stage name when proceedings are under way, and the pressure against its threshold.
        var removal: String
        var risk: String
        var stage: Int
        var stageName: String
        var pressure: Double
        var threshold: Double
        var approvalFloor: Double
        var target: String?
        var targetName: String?
        var authorized: Bool
        var kinds: [Kind]
        var actionsRemaining: Int
        var warPowersNote: String
        var votes: [Vote]
    }

    static func run(_ args: Args, engine: GameEngine?) throws -> Result {
        let (e, gs) = try GTNWBridge.game(engine)
        let p = gs.getPlayerCountry()
        let congress = p?.congressionalSupport ?? 50
        let h = CongressModel.house(congress: congress, popularity: gs.shadow.popularity)
        let s = CongressModel.senate(congress: congress, popularity: gs.shadow.popularity)
        var warPowers = "WAR POWERS: CLEAR"
        let clock = gs.shadow.warPowersClocks.values.min { $0.started < $1.started }
        if let c = clock {
            let left = CongressModel.clockDays - GameCalendar.days(from: c.started, to: gs.currentDate)
            warPowers = left > 0 ? "WAR POWERS: \(left) DAYS" : "WAR POWERS: WITHDRAW \(max(0, left + CongressModel.withdrawalDays)) DAYS"
        }
        let pressure = ExpansionModel.impeachmentPressure(popularity: gs.shadow.popularity, ruthlessness: gs.shadow.ruthlessness, congress: congress)
        let mech = p.map { NationModel.removal($0, on: gs.currentDate) } ?? .impeachment
        var kinds: [Kind] = []
        var targetName: String?
        var votes: [Vote] = []
        var authorized = false
        if let t = args.target, let c = gs.getCountry(id: t), c.id != gs.playerCountryID {
            targetName = c.name
            authorized = e.isAuthorized(t)
            for k in WarAuthorizationKind.allCases {
                guard let o = e.authorizationOdds(target: t, kind: k) else { continue }
                kinds.append(Kind(id: k.rawValue, title: k.title, odds: QueryText.round2(o.odds), house: QueryText.round2(o.house),
                                  senate: QueryText.round2(o.senate), casusBelli: o.casusBelli >= 0.7 ? "strong" : (o.casusBelli > 0 ? "some" : "none")))
            }
            votes = gs.shadow.authorizations.filter { $0.target == t }.map {
                Vote(date: GameCalendar.format($0.date), kind: $0.kind.title, passed: $0.passed, houseYes: $0.houseYes, senateYes: $0.senateYes)
            }
        }
        return Result(
            usa: gs.playerCountryID == "USA", house: QueryText.round2(h), senate: QueryText.round2(s), warSupport: p?.warSupport ?? 0,
            warPowers: warPowers, warPowersRunning: clock != nil,
            removal: mech == .impeachment ? "Impeachment" : mech.title, risk: ExpansionModel.risk(pressure: pressure).rawValue,
            stage: gs.shadow.impeachmentStage, stageName: CongressModel.impeachmentStageName(gs.shadow.impeachmentStage),
            pressure: QueryText.round2(pressure), threshold: ExpansionModel.impeachmentThreshold, approvalFloor: ExpansionModel.popularityFloor,
            target: targetName == nil ? nil : args.target, targetName: targetName, authorized: authorized, kinds: kinds,
            actionsRemaining: gs.actionsRemaining,
            warPowersNote: gs.currentDate >= CongressModel.warPowersResolution
                ? "War Powers Resolution (1973): hostilities without authorization start a 60-day clock, then 30 days to withdraw."
                : "Before the War Powers Resolution (1973) Presidents often fought without asking; asking still rallies the country.",
            votes: votes)
    }
}
#endif
