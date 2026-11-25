//
//  PowerPlayVerb.swift
//  GTNWCore
//
//  `{"verb":"powerPlay","op":…}` (3.37): the POWER PLAYS sheet's buttons (PowerPlaysSheet.swift, 3.36.0), each the
//  GameEngine method the Mac button calls:
//
//    {"op":"campaign","target":land,"step":"offer"|"pressure"|"posture"|"deal"|"escalate"}   campaignStep
//    {"op":"strike","target":id,"kind":"precision"|"boats"|"facility"|"nuclearFacility"}     limitedStrike
//    {"op":"raid","target":id}                                                                captureLeader
//    {"op":"tariff","target":id,"basis":LegalBasis}                                           emergencyTariffs
//    {"op":"declare","reason":EmergencyReason}  /  {"op":"end"}                               the national emergency
//    {"op":"rescind","order":id}  /  {"op":"reissue","order":id,"basis":LegalBasis}           an emergency order
//
//  Each refuses with the engine's own reason (the `powerPlays` query's `problem`) before changing anything. The
//  campaign's target is the land the query's `campaign.land` names (or the target itself before an offer).
//

#if GTNW_CORE
import Foundation

enum PowerPlayVerb: BridgeVerb {
    static let name = "powerPlay"

    struct Args: Decodable {
        var op: String
        var target: String?
        var step: String?
        var kind: String?
        var basis: String?
        var reason: String?
        var order: Int?
    }

    static func run(_ a: Args, engine e: GameEngine, state gs: GameState) throws -> GTNWBridge.Report? {
        func need<T>(_ v: T?, _ what: String) throws -> T { guard let v else { throw QueryError("\(a.op) needs \(what)") }; return v }
        func check(_ problem: String?) throws { if let problem { throw QueryError(problem) } }
        switch a.op {
        case "campaign":
            let land = try need(a.target, "a target")
            let step = try need(a.step.flatMap(CampaignStep.init(rawValue:)), "a step (offer, pressure, posture, deal, escalate)")
            try check(e.campaignProblem(land, step: step))
            guard e.campaignStep(land, step: step) else { throw QueryError("That step can't be taken now.") }
            let c = gs.shadow.powerPlays.campaigns.last { $0.land == land }
            return c.map { GTNWBridge.Report(title: "\(step.title): \($0.label)", lines: ["\($0.stage.label)."], success: $0.stage == .acquired ? true : nil) }
        case "strike":
            let t = try need(a.target, "a target")
            let kind = try need(a.kind.flatMap(StrikeKind.init(rawValue:)), "a kind (precision, boats, facility, nuclearFacility)")
            try check(e.strikeProblem(t, kind: kind))
            guard let hit = e.limitedStrike(t, kind: kind) else { throw QueryError("That strike can't be ordered now.") }
            return GTNWBridge.Report(title: "\(kind.title): \(gs.getCountry(id: t)?.name ?? t)", lines: [hit ? "On target." : "Missed."], success: hit)
        case "raid":
            let t = try need(a.target, "a target")
            try check(e.captureProblem(t))
            guard let outcome = e.captureLeader(t) else { throw QueryError("The raid can't be ordered now.") }
            return GTNWBridge.Report(title: "Leader capture raid: \(gs.getCountry(id: t)?.name ?? t)", lines: [outcome.title], success: outcome == .captured)
        case "tariff":
            let t = try need(a.target, "a target")
            let basis = try need(a.basis.flatMap(LegalBasis.init(rawValue:)), "a legal authority")
            try check(e.emergencyTariffProblem(t, basis: basis))
            guard let o = e.emergencyTariffs(on: t, basis: basis) else { throw QueryError("Those tariffs can't be imposed now.") }
            return GTNWBridge.Report(title: "Emergency tariffs", lines: ["\(o.subject.prefix(1).uppercased() + o.subject.dropFirst()) under \(o.basis.title)."], success: nil)
        case "declare":
            let reason = try need(a.reason.flatMap(EmergencyReason.init(rawValue:)), "a reason")
            try check(e.emergencyDeclareProblem(reason))
            guard e.declareNationalEmergency(reason) else { throw QueryError("A national emergency can't be declared now.") }
            return nil
        case "end":
            guard gs.shadow.powerPlays.emergency != nil else { throw QueryError("No national emergency is in force.") }
            guard e.endNationalEmergency() else { throw QueryError("The national emergency can't be ended now.") }
            return nil
        case "rescind":
            let id = try need(a.order, "an order id")
            guard gs.shadow.powerPlays.orders.contains(where: { $0.id == id && $0.status.isLive }) else { throw QueryError("No such order in force.") }
            guard e.rescindEmergencyOrder(id) else { throw QueryError("That order can't be withdrawn now.") }
            return nil
        case "reissue":
            let id = try need(a.order, "an order id")
            let basis = try need(a.basis.flatMap(LegalBasis.init(rawValue:)), "a legal authority")
            try check(e.reissueProblem(id, basis: basis))
            guard e.reissueEmergencyOrder(id, basis: basis) != nil else { throw QueryError("That order can't be reissued now.") }
            return nil
        default:
            throw QueryError("op must be campaign, strike, raid, tariff, declare, end, rescind or reissue")
        }
    }
}
#endif
