//
//  AnswerMessageVerb.swift
//  GTNWCore
//
//  `{"verb":"answerMessage","id":"<message>","response":"accept"}`: a reply to a diplomatic message
//  (DiplomaticMessagesView's MessageCard), with the same effects and log lines as the app's buttons. Responses:
//  accept, decline, counter, nonAggression, apology, standFirm, trade, mediation (the `messages` query lists which
//  a message offers). The message leaves the inbox.
//

#if GTNW_CORE
import Foundation

enum AnswerMessageVerb: BridgeVerb {
    static let name = "answerMessage"

    struct Args: Decodable { var id: String; var response: String }

    static func run(_ a: Args, engine e: GameEngine, state gs: GameState) throws -> GTNWBridge.Report? {
        let id = try WarSupport.uuid(a.id)
        guard let m = e.diplomacyService.messages.first(where: { $0.id == id }) else { throw QueryError("That message is gone.") }
        guard MessagesQuery.responses(m.content, gs: gs).contains(where: { $0.id == a.response }) else {
            throw QueryError("\(a.response) is not a reply to that message")
        }
        guard let p = gs.getPlayerCountry(), let from = gs.getCountry(id: m.from) else { throw QueryError("The sender is gone.") }
        let kind = MessagesQuery.kind(m.content)
        switch a.response {
        case "accept":
            switch kind {
            case "request":
                e.modifyDiplomaticRelation(from: p.id, to: from.id, by: 30)
                e.modifyDiplomaticRelation(from: from.id, to: p.id, by: 30)
                e.addLog("✅ Sent \(gs.eraDiplomacyAmountLabel) aid to \(from.name). Relations improved (+30).", type: .info)
                e.addLog("📨 \(from.flag) \(from.name): \"We are grateful for this aid. Our friendship is secured.\"", type: .info)
            case "proposal":
                e.formAlliance(country1: p.id, country2: from.id)
                e.addLog("✅ Accepted proposal from \(from.name). Alliance formed.", type: .info)
                e.addLog("📨 \(from.flag) \(from.name): \"This alliance strengthens both our nations. We stand together.\"", type: .info)
            case "demand":
                e.modifyDiplomaticRelation(from: from.id, to: p.id, by: 20)
                e.addLog("✓ Complied with \(from.name)'s demands. Relations improved (+20).", type: .info)
            default:
                e.modifyDiplomaticRelation(from: from.id, to: p.id, by: 10)
                e.addLog("✓ Acknowledged message from \(from.name). Relations +10.", type: .info)
            }
        case "decline":
            let change = kind == "demand" ? -20 : -10
            e.modifyDiplomaticRelation(from: from.id, to: p.id, by: change)
            e.addLog("❌ Declined message from \(from.name). Relations \(change).", type: .warning)
            e.addLog("📨 \(from.flag) \(from.name): \"Your refusal is noted. Do not expect this offer again.\"", type: .info)
        case "counter":
            e.modifyDiplomaticRelation(from: p.id, to: from.id, by: 5)
            e.addLog("📝 Counter-proposal sent to \(from.name). Negotiations ongoing. Relations +5.", type: .info)
            e.addLog("📨 \(from.flag) \(from.name): \"We have received your counter-proposal and will deliberate.\"", type: .info)
        case "nonAggression":
            e.modifyDiplomaticRelation(from: p.id, to: from.id, by: 15)
            e.addLog("📜 Proposed non-aggression pact with \(from.name). Relations +15.", type: .info)
            e.addLog("📨 \(from.flag) \(from.name): \"We will consider your proposal carefully.\"", type: .info)
        case "apology":
            e.modifyDiplomaticRelation(from: p.id, to: from.id, by: 20)
            e.modifyDiplomaticRelation(from: from.id, to: p.id, by: 20)
            e.addLog("✅ Issued formal apology to \(from.name). Relations +20.", type: .info)
            e.addLog("📨 \(from.flag) \(from.name): \"Your apology is noted. Tensions ease somewhat.\"", type: .info)
        case "standFirm":
            e.modifyDiplomaticRelation(from: from.id, to: p.id, by: -10)
            e.addLog("⚠️ Rejected \(from.name)'s warning. Relations -10. They may escalate.", type: .warning)
            e.addLog("📨 \(from.flag) \(from.name): \"Your defiance is noted. We will act accordingly.\"", type: .info)
        case "trade":
            e.modifyDiplomaticRelation(from: p.id, to: from.id, by: 20)
            e.modifyDiplomaticRelation(from: from.id, to: p.id, by: 20)
            e.addLog("💱 Trade agreement initiated with \(from.name). Relations +20.", type: .info)
            e.addLog("📨 \(from.flag) \(from.name): \"This trade partnership benefits both our peoples. Agreed.\"", type: .info)
        case "mediation":
            e.modifyDiplomaticRelation(from: p.id, to: from.id, by: 10)
            e.addLog("🕊️ Offered mediation to \(from.name). De-escalation attempted.", type: .info)
            e.addLog("📨 \(from.flag) \(from.name): \"We agree to discuss terms, though our grievances remain.\"", type: .info)
        default:
            throw QueryError("unknown response \(a.response)")
        }
        e.diplomacyService.messages.removeAll { $0.id == id }
        return nil
    }
}
#endif
