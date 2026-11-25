//
//  RenameTargetVerb.swift
//  GTNWCore
//
//  `{"verb":"renameTarget","id":"…","name":"…"}` (3.37): rename anything the `renames` query lists, no action spent.
//  A sea, strait, mountain, department, state or province goes through POWER PLAYS → NAMES' RENAME
//  (`GameEngine.renamePlace`); the President's nation or a land he holds through TerritoryNameSheet's (`rename`).
//  Both run `NameScreen`, and a refusal is the app's neutral line.
//

#if GTNW_CORE
import Foundation

enum RenameTargetVerb: BridgeVerb {
    static let name = "renameTarget"

    struct Args: Decodable { var id: String; var name: String }

    static func run(_ a: Args, engine e: GameEngine, state gs: GameState) throws -> GTNWBridge.Report? {
        let t = RenameTarget.from(id: a.id, in: gs)
        if t.isPlace {
            if let problem = e.renamePlaceProblem(a.id, to: a.name) { throw QueryError(problem) }
            guard e.renamePlace(a.id, to: a.name) else { throw QueryError("That can't be renamed.") }
            return nil
        }
        guard t.isHeld(in: gs) else { throw QueryError("You can rename your own country and the lands you hold.") }
        if case .refused(let why) = e.rename(t, to: a.name) { throw QueryError(why) }
        return nil
    }
}
#endif
