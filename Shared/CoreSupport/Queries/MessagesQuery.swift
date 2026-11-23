//
//  MessagesQuery.swift
//  GTNWCore
//
//  `{"q":"messages"}`: DiplomaticMessagesView. The inbox of messages other governments sent (newest first), each
//  with its sender, date, the sender's relation with the player, and the responses the app offers for it: the main
//  one (named by the message's kind), a context one or two (a pact, an apology, trade, mediation), decline, and a
//  counter-proposal for demands and statements. Answered with the `answerMessage` verb.
//

#if GTNW_CORE
import Foundation

enum MessagesQuery: BridgeQuery {
    static let name = "messages"

    struct Response: Encodable { var id: String; var title: String }

    struct Message: Encodable {
        var id: String
        var from: String
        var fromName: String
        var flag: String
        var dateLabel: String
        var relation: Int?
        var content: String
        /// request, proposal, demand, statement
        var kind: String
        var responses: [Response]
    }

    struct Result: Encodable { var messages: [Message] }

    /// MessageCard.messageType.
    static func kind(_ content: String) -> String {
        let c = content.lowercased()
        if c.contains("request") || c.contains("aid") { return "request" }
        if c.contains("propose") || c.contains("pact") { return "proposal" }
        if c.contains("demand") || c.contains("cease") { return "demand" }
        return "statement"
    }

    /// MessageCard's buttons, in its order.
    static func responses(_ content: String, gs: GameState) -> [Response] {
        let k = kind(content), c = content.lowercased()
        let main: String
        switch k {
        case "request": main = "Send Aid (\(gs.eraDiplomacyAmountLabel))"
        case "proposal": main = "Accept Proposal"
        case "demand": main = "Comply with Demand"
        default: main = "Acknowledge"
        }
        var out = [Response(id: "accept", title: main)]
        if c.contains("alliance") || c.contains("treaty") || c.contains("pact") {
            out.append(Response(id: "nonAggression", title: "Propose Non-Aggression"))
        } else if c.contains("warning") || c.contains("provocative") || c.contains("aggression") {
            out.append(Response(id: "apology", title: "Issue Apology"))
            out.append(Response(id: "standFirm", title: "Stand Firm"))
        } else if c.contains("trade") || c.contains("commerce") || c.contains("economic") {
            out.append(Response(id: "trade", title: "Offer Trade Deal"))
        } else if c.contains("war") || c.contains("attack") || c.contains("retaliation") {
            out.append(Response(id: "mediation", title: "Seek Mediation"))
        }
        out.append(Response(id: "decline", title: "Decline"))
        if k == "demand" || k == "statement" { out.append(Response(id: "counter", title: "Counter-Propose")) }
        return out
    }

    static func run(_ args: NoArgs, engine: GameEngine?) throws -> Result {
        let (e, gs) = try GTNWBridge.game(engine)
        let me = gs.playerCountryID
        return Result(messages: e.diplomacyService.messages.map { m in
            let c = gs.getCountry(id: m.from)
            return Message(id: m.id.uuidString, from: m.from, fromName: c?.name ?? m.from, flag: c?.flag ?? "",
                           dateLabel: gs.dateLabel(forTurn: m.turn), relation: c?.diplomaticRelations[me], content: m.content,
                           kind: kind(m.content), responses: responses(m.content, gs: gs))
        })
    }
}
#endif
