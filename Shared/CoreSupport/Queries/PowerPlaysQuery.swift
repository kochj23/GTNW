//
//  PowerPlaysQuery.swift
//  GTNWCore
//
//  `{"q":"powerPlays","target":"DNK"?}` (3.37): the Situation Room's POWER PLAYS sheet (PowerPlaysSheet.swift,
//  3.36.0) as data. For a foreign nation or a land another power holds: the acquisition campaign (open or not, each
//  step with why it can't be taken now or the cabinet's warnings), and for a nation the limited strikes with hit odds,
//  the leader capture raid and emergency tariffs under each legal authority with the courts' likely ruling. Always:
//  the national emergency (in force, or the reasons it can be declared over) and the last twelve emergency orders
//  with their authority, status, court date and the authorities a struck-down one can be reissued under.
//  The buttons are the `powerPlay` verb; names (seas, mountains, departments, states) are the `renames` query.
//

#if GTNW_CORE
import Foundation

enum PowerPlaysQuery: BridgeQuery {
    static let name = "powerPlays"

    struct Args: Decodable { var target: String? }

    struct Warning: Encodable { var who: String; var text: String; var level: Int }

    struct Campaign: Encodable {
        var land: String
        var label: String
        var stage: String
        var leverage: Int
        var resistance: Int
        var protests: Int
        var objectors: [String]
    }

    struct Step: Encodable {
        var step: String
        var title: String
        var problem: String?
        var warnings: [Warning]
        /// A threat or a war: the Mac asks once more.
        var confirm: Bool
    }

    struct Strike: Encodable {
        var kind: String
        var title: String
        var problem: String?
        var odds: Double
        var warnings: [Warning]
        var confirm: Bool
    }

    struct Raid: Encodable { var problem: String?; var odds: Double; var warnings: [Warning] }

    struct Basis: Encodable {
        var id: String
        var title: String
        var note: String
        var holds: Bool
        var months: Int
    }

    struct Tariffs: Encodable { var bases: [Basis]; var problem: String? }

    struct Reason: Encodable { var id: String; var title: String; var problem: String? }

    struct Emergency: Encodable {
        var inForce: Bool
        var since: String?
        var reason: String?
        var reasons: [Reason]
    }

    struct EmergencyOrderRow: Encodable {
        var id: Int
        var subject: String
        var status: String
        var statusLabel: String
        var live: Bool
        var basis: String
        var signed: String
        var rulingInDays: Int?
        var reissue: [Basis]
    }

    struct Result: Encodable {
        var target: String?
        var targetName: String?
        /// A foreign nation or land: the campaign (and for a nation, strikes, raid, tariffs) apply.
        var foreign: Bool
        var nation: Bool
        var buyable: Bool
        var campaign: Campaign?
        var steps: [Step]
        var strikes: [Strike]
        var escalation: Int?
        var escalationLimit: Int
        var raid: Raid?
        var tariffs: Tariffs?
        var emergency: Emergency
        var orders: [EmergencyOrderRow]
        var actionsRemaining: Int
    }

    static func warnings(_ ws: [AdvisorWarning]) -> [Warning] { ws.map { Warning(who: $0.who, text: $0.text, level: $0.level) } }

    static func run(_ a: Args, engine: GameEngine?) throws -> Result {
        let (e, gs) = try GTNWBridge.game(engine)
        let pp = gs.shadow.powerPlays
        func name(_ id: String) -> String { gs.getCountry(id: id)?.name ?? id }
        let target = a.target.flatMap { $0.isEmpty ? nil : $0 }
        let foreign = target.map { $0 != gs.playerCountryID && gs.getCountry(id: $0)?.territoryOf != gs.playerCountryID } ?? false
        let isNation = target.flatMap { gs.getCountry(id: $0).map { !$0.isTerritory } } ?? false
        var result = Result(target: target, targetName: target.map { e.acquisitionTarget($0)?.label ?? name($0) }, foreign: foreign, nation: isNation,
                            buyable: false, campaign: nil, steps: [], strikes: [], escalation: nil,
                            escalationLimit: Int(LimitedStrikes.warThreshold), raid: nil, tariffs: nil,
                            emergency: Emergency(inForce: false, since: nil, reason: nil, reasons: []), orders: [],
                            actionsRemaining: gs.actionsRemaining)
        if let t = target, foreign {
            let open = e.openCampaign(t) ?? pp.campaigns.last { $0.owner == t && $0.stage.isOpen }
            let land = open?.land ?? t
            result.buyable = e.acquisitionTarget(t) != nil || open != nil
            if let c = open {
                result.campaign = Campaign(land: c.land, label: c.label, stage: c.stage.label, leverage: Int(c.leverage),
                                           resistance: Int(e.campaignResistance(c)), protests: Int(c.protests), objectors: c.objectors.map(name))
            }
            if e.acquisitionTarget(land) != nil || open != nil {
                let steps: [CampaignStep] = open == nil ? [.offer] : [.pressure, .posture, .deal, .escalate]
                result.steps = steps.map { s in
                    let problem = e.campaignProblem(land, step: s)
                    return Step(step: s.rawValue, title: s.title, problem: problem,
                                warnings: problem == nil ? warnings(Array(e.campaignWarnings(land, step: s).prefix(2))) : [],
                                confirm: s == .escalate || s == .posture)
                }
            }
            if isNation {
                result.strikes = StrikeKind.allCases.map { k in
                    let problem = e.strikeProblem(t, kind: k)
                    return Strike(kind: k.rawValue, title: k.title, problem: problem, odds: QueryText.round2(e.strikeOdds(t, kind: k)),
                                  warnings: problem == nil ? warnings(e.strikeWarnings(t, kind: k).filter { $0.level > 0 }) : [],
                                  confirm: k == .nuclearFacility)
                }
                result.escalation = pp.escalation[t].map { Int($0) }
                let rp = e.captureProblem(t)
                result.raid = Raid(problem: rp, odds: QueryText.round2(e.captureOdds(t)), warnings: rp == nil ? warnings(e.captureWarnings(t)) : [])
                let bases = e.legalBases(for: .tariff, target: t)
                result.tariffs = Tariffs(bases: bases.map { b in
                    Basis(id: b.rawValue, title: b.title, note: b.note,
                          holds: e.courtScore(b, kind: .tariff, target: t) >= EmergencyPowers.passMark, months: max(1, b.courtDays / 30))
                }, problem: bases.isEmpty ? "No authority lets you impose tariffs now." : nil)
            }
        }
        if let em = pp.emergency {
            result.emergency = Emergency(inForce: true, since: GameCalendar.format(em.declared), reason: em.reason.title, reasons: [])
        } else {
            result.emergency.reasons = EmergencyReason.allCases.map { Reason(id: $0.rawValue, title: $0.title, problem: e.emergencyDeclareProblem($0)) }
        }
        result.orders = pp.orders.suffix(12).reversed().map { o in
            let options = (o.status == .struckDown || o.status == .lapsed) ? LegalBasis.allCases.filter { e.reissueProblem(o.id, basis: $0) == nil } : []
            let target = o.kind == .tariff ? o.target : nil
            return EmergencyOrderRow(id: o.id, subject: o.subject, status: o.status.rawValue, statusLabel: o.status.label, live: o.status.isLive,
                                     basis: o.basis.title, signed: GameCalendar.format(o.issued), rulingInDays: e.daysToRuling(o),
                                     reissue: options.map { b in
                                         Basis(id: b.rawValue, title: b.title, note: b.note,
                                               holds: e.courtScore(b, kind: o.kind, target: target) >= EmergencyPowers.passMark, months: max(1, b.courtDays / 30))
                                     })
        }
        return result
    }
}
#endif
