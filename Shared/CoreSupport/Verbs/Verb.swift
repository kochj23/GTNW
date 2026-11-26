//
//  Verb.swift
//  GTNWCore
//
//  The Situation Room's sheet buttons as bridge orders: `act({"verb":"<name>", ...that verb's own fields})`. Each
//  verb calls the same GameEngine method the app's button calls (commit troops, order a fleet, enact a budget, send
//  aid, answer a treaty…), so a game played through verbs is the game the app plays. Verbs change the game and may
//  draw from its RNG, exactly as the buttons do; queries (Queries/) only read.
//
//  Reply: `{"ok":true,"events":[…],"state":{…},"report":{title,lines,success}?}`; a verb that can't be carried out
//  answers `{"ok":false,"error":"…"}` with the reason the app would show (and the game unchanged).
//
//  Adding a verb: one file in this folder with a type that conforms to `BridgeVerb`, plus one line in
//  `VerbRegistry.all` (kept alphabetical). Verbs never call each other, so screens add theirs in parallel.
//

#if GTNW_CORE
import Foundation

/// One Situation Room order. `Args` is decoded from the whole request object (unknown keys, `verb` included, are
/// ignored).
protocol BridgeVerb {
    associatedtype Args: Decodable
    /// The `verb` value.
    static var name: String { get }
    /// Carry it out on the live game. Throw `QueryError` with the reason when it can't be done (before changing
    /// anything); return a report for the front end to show, or nil.
    static func run(_ args: Args, engine: GameEngine, state: GameState) throws -> GTNWBridge.Report?
}

/// Every verb, by name. Alphabetical; one line each.
enum VerbRegistry {
    static let all: [any BridgeVerb.Type] = [
        AcceptAcquisitionVerb.self,
        AnnexProvincesVerb.self,
        AnswerMessageVerb.self,
        AnswerTreatyVerb.self,
        AntarcticOrderVerb.self,
        AskCongressVerb.self,
        AssignBrainVerb.self,
        BrainMovesVerb.self,
        BrokerCeasefireVerb.self,
        BrokerPeaceVerb.self,
        CallUpVerb.self,
        ClaimCampaignVerb.self,
        CollectLevyVerb.self,
        ColonyDealVerb.self,
        CommitTroopsVerb.self,
        DemandSurrenderVerb.self,
        DevelopIslandVerb.self,
        DirtyTacticVerb.self,
        DismissAdvisorVerb.self,
        EnactBudgetVerb.self,
        ExecuteCommandVerb.self,
        FireAdvisorVerb.self,
        GovernTerritoryVerb.self,
        GroupActionVerb.self,
        HallOfInfamyVerb.self,
        HolySeeVerb.self,
        InvestLandVerb.self,
        LandBidVerb.self,
        LaunchSatelliteVerb.self,
        OrderFleetVerb.self,
        PetitionStatehoodVerb.self,
        PowerPlayVerb.self,
        PresidencyCareerVerb.self,
        RecallFleetVerb.self,
        RenameTargetVerb.self,
        RenameTerritoryVerb.self,
        RequestCoalitionVerb.self,
        SaveGroupVerb.self,
        SendAidVerb.self,
        SetExtractionVerb.self,
        SettleVerb.self,
        SizedOrderVerb.self,
        SpectateVerb.self,
        StandDownVerb.self,
        StrategicBombingVerb.self,
        SueForPeaceVerb.self,
        TakeLandVerb.self,
    ]

    static let byName: [String: any BridgeVerb.Type] = Dictionary(all.map { ($0.name, $0) }, uniquingKeysWith: { a, _ in a })
}

extension GTNWBridge {
    /// Run one verb on the live game (`act` has checked there is one and it isn't over).
    static func verb(_ name: String, _ json: String) -> String {
        guard let type = VerbRegistry.byName[name] else { return failure("act: unknown verb \(name)") }
        return perform(type, json)
    }

    private static func perform<V: BridgeVerb>(_ type: V.Type, _ json: String) -> String {
        guard let e = engine, let gs = e.gameState else { return failure("act: no game") }
        guard let args = decode(V.Args.self, json) else { return failure("act \(V.name): bad arguments") }
        do {
            let report = try V.run(args, engine: e, state: gs)
            JobPump.pump(while: { e.isProcessingAITurn })
            return reply(report: report)
        } catch let err as QueryError {
            return failure("act \(V.name): \(err.message)")
        } catch {
            return failure("act \(V.name): \(error)")
        }
    }
}
#endif
