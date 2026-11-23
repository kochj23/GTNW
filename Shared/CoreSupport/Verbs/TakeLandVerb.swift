//
//  TakeLandVerb.swift
//  GTNWCore
//
//  `{"verb":"takeLand","id":"…","troops":5}`: the dossier's land orders (one action): SEND EXPEDITION to unclaimed
//  land, PLANT THE FLAG / TAKE BY FORCE on a people's land, SEIZE BY FORCE a colony or another power's territory.
//  `taken` in the report is whether the land is now the player's (the front end then offers to name it).
//

#if GTNW_CORE
import Foundation

enum TakeLandVerb: BridgeVerb {
    static let name = "takeLand"

    struct Args: Decodable { var id: String; var troops: Double? }

    static func run(_ a: Args, engine e: GameEngine, state gs: GameState) throws -> GTNWBridge.Report? {
        guard gs.actionsRemaining > 0 else { throw QueryError("no actions left this turn") }
        let troops = a.troops ?? AttackSizing.expeditionStandard
        guard troops.isFinite, troops >= 1 else { throw QueryError("troops must be at least 1 thousand") }
        let ok: Bool?
        if gs.unclaimedLandIDs.contains(a.id) {
            ok = e.claimLand(a.id, troops: troops)
        } else if let st = gs.preState(a.id) {
            guard troops <= AttackSizing.freeTroops(gs) else { throw QueryError("only \(Int(AttackSizing.freeTroops(gs)))K troops are free") }
            ok = st.era.kind == .colony ? e.seizeColony(a.id, troops: troops) : e.claimIndigenousLand(a.id, troops: troops)
        } else if let c = gs.getCountry(id: a.id), c.territoryOf != nil, c.territoryOf != gs.playerCountryID, e.colonyTarget(a.id) != nil {
            guard troops <= AttackSizing.freeTroops(gs) else { throw QueryError("only \(Int(AttackSizing.freeTroops(gs)))K troops are free") }
            ok = e.seizeColony(a.id, troops: troops)
        } else {
            throw QueryError("\(a.id) can't be taken")
        }
        guard let result = ok else { throw QueryError("the expedition can't be sent") }
        let mine = e.gameState?.getCountry(id: a.id)?.territoryOf == e.gameState?.playerCountryID
        return GTNWBridge.Report(title: mine ? "taken" : (result ? "under way" : "repulsed"), lines: [], success: mine)
    }
}
#endif
