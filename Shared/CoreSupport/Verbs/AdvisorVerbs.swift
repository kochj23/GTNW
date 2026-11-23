//
//  AdvisorVerbs.swift
//  GTNWCore
//
//  The advisors' two ways out, as the app's buttons do them:
//    {"verb":"fireAdvisor","id":"…"}     the Situation Room briefing's FIRE (`departAdvisor`: an acting replacement
//                                        takes the post; no confirmation in the app)
//    {"verb":"dismissAdvisor","id":"…"}  the cabinet view's DISMISS FROM CABINET (`fireAdvisor`: cabinet loyalty and
//                                        approval pay for it; the app confirms first, so does the web)
//  The President is never dismissed.
//

#if GTNW_CORE
import Foundation

struct AdvisorArgs: Decodable { var id: String }

private func activeAdvisor(_ id: String, _ state: GameState) throws -> (Int, Advisor) {
    guard let i = state.advisors.firstIndex(where: { $0.id == id && $0.isActive }) else { throw QueryError("no active advisor \(id)") }
    let a = state.advisors[i]
    guard !a.title.contains("President") else { throw QueryError("the President can't be dismissed") }
    return (i, a)
}

enum DismissAdvisorVerb: BridgeVerb {
    static let name = "dismissAdvisor"
    static func run(_ args: AdvisorArgs, engine: GameEngine, state: GameState) throws -> GTNWBridge.Report? {
        _ = try activeAdvisor(args.id, state)
        engine.fireAdvisor(advisorID: args.id)
        return nil
    }
}

enum FireAdvisorVerb: BridgeVerb {
    static let name = "fireAdvisor"
    static func run(_ args: AdvisorArgs, engine: GameEngine, state: GameState) throws -> GTNWBridge.Report? {
        let (i, a) = try activeAdvisor(args.id, state)
        engine.departAdvisor(index: i, status: .fired, reason: "\(a.name) has been dismissed as \(a.title).")
        return nil
    }
}
#endif
