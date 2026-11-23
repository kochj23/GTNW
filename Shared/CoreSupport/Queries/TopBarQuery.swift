//
//  TopBarQuery.swift
//  GTNWCore
//
//  `{"q":"topbar"}`: what the Situation Room's top bar shows beyond `state` (the app's SituationTopBar): who you
//  are, the turn line, the election countdown, world peace, impeachment, and which sheets have something waiting
//  (budget ready, an offer, a treaty, a scorecard).
//

#if GTNW_CORE
import Foundation

enum TopBarQuery: BridgeQuery {
    static let name = "topbar"

    struct Result: Encodable {
        var leader: String
        var nation: String
        var flag: String
        var year: Int
        var dateLabel: String
        var turnLength: String
        var turnLabel: String
        var actionsRemaining: Int
        var actionsPerTurn: Int
        var popularity: Double
        var electionLine: String
        /// "DEFCON" from 1959, "ALERT" before.
        var defconName: String
        var defconLabel: String
        var peaceLabel: String
        var peaceIndex: Int
        var impeachmentStage: Int
        var freeTroops: Int
        var budgetReady: Bool
        var hasTerritories: Bool
        var offer: String?
        var landBids: Int
        var treatyFrom: String?
        var scenario: String?
        var scenarioTitle: String?
        var sitting: String?
        var sittingTurnsLeft: Int?
        var spaceAge: Bool
        var gameOver: Bool
        var gameOverReason: String
    }

    static func run(_ args: NoArgs, engine: GameEngine?) throws -> Result {
        let (e, gs) = try GTNWBridge.game(engine)
        let me = gs.getPlayerCountry()
        let eval = WorldEvaluation.evaluate(gs)
        let sitting = gs.shadow.sittingID.flatMap(OneSitting.find)
        let president = Advisor.allAdministrations().last { $0.startYear <= gs.currentYear }?.president
        let leader = gs.shadow.playerLeader ?? (gs.playerCountryID == "USA" ? president.map { "President \($0)" } : nil) ?? me?.name ?? gs.playerCountryID
        return Result(
            leader: leader, nation: me?.name ?? gs.playerCountryID, flag: me?.flag ?? "", year: gs.currentYear,
            dateLabel: gs.currentDateLabel, turnLength: gs.turnLength.rawValue,
            turnLabel: "\(gs.turnLength.displayName) \(gs.turn + 1) · \(gs.actionsRemaining)/\(gs.actionsPerTurn) actions left",
            actionsRemaining: gs.actionsRemaining, actionsPerTurn: gs.actionsPerTurn,
            popularity: QueryText.round2(gs.shadow.popularity), electionLine: electionLine(gs),
            defconName: gs.defconName, defconLabel: gs.defconLabel,
            peaceLabel: eval.peaceLevel.label, peaceIndex: Int(eval.peaceIndex),
            impeachmentStage: gs.shadow.impeachmentStage, freeTroops: Int(AttackSizing.freeTroops(gs)),
            budgetReady: gs.shadow.budgetReviewPending,
            hasTerritories: gs.countries.contains { $0.territoryOf == gs.playerCountryID },
            offer: e.openAcquisitions().first?.name, landBids: gs.shadow.landBids.count,
            treatyFrom: gs.shadow.treatyOffers.first.map { gs.getCountry(id: $0.from)?.name ?? $0.from },
            scenario: gs.shadow.scenarioID, scenarioTitle: gs.shadow.scenarioID.flatMap(ScenarioDefinition.find)?.title,
            sitting: sitting?.title, sittingTurnsLeft: sitting.map { max(0, $0.turns - gs.turn) },
            spaceAge: gs.currentYear >= GameEngine.spaceAgeYear, gameOver: gs.gameOver, gameOverReason: gs.gameOverReason)
    }

    /// SituationTopBar.electionLine, in sentence case.
    static func electionLine(_ gs: GameState) -> String {
        guard gs.shadow.electionsEnabled else { return "Elections off" }
        if let leave = gs.shadow.campaign.leaveOfficeOn {
            return "Lame duck: \(GameCalendar.days(from: gs.currentDate, to: leave)) days left"
        }
        if let next = ElectionCycle.next(after: gs.currentDate) {
            return "\(next.stage.label(year: next.year)) in \(GameCalendar.days(from: gs.currentDate, to: next.date)) days"
        }
        return "\(GameCalendar.days(from: gs.currentDate, to: GameCalendar.nextElection(after: gs.currentDate))) days to election"
    }
}
#endif
