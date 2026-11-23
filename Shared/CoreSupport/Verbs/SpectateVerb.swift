//
//  SpectateVerb.swift
//  GTNWCore
//
//  `{"verb":"spectate","op":"watch"|"turn"|"takeSeat"}`: Watch AI vs AI (3.25.0). `watch` hands the player's seat
//  to its brain (right after newGame), `turn` plays one spectated turn (crises answered the advised or likeliest
//  way, settlements the computer's way, then the end of turn) and `takeSeat` gives the seat back to the player.
//  The front end keeps the clock (speed, pause): a bridge call has no timer.
//

#if GTNW_CORE
import Foundation

enum SpectateVerb: BridgeVerb {
    static let name = "spectate"

    struct Args: Decodable { var op: String }

    static func run(_ a: Args, engine e: GameEngine, state gs: GameState) throws -> GTNWBridge.Report? {
        switch a.op {
        case "watch":
            guard !e.spectating else { throw QueryError("already watching") }
            e.spectating = true
            e.spectatorPaused = false
            e.addLog("👁 SPECTATING: the computer plays \(gs.playerCountryID) too (recorded as AI vs AI). Take the seat at any time.", type: .system)
        case "turn":
            guard e.spectating else { throw QueryError("not watching") }
            e.spectatorTurn()
        case "takeSeat":
            guard e.spectating else { throw QueryError("not watching") }
            e.takeSeat()
        default:
            throw QueryError("op is watch, turn or takeSeat")
        }
        return nil
    }
}
#endif
