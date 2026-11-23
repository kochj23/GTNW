//
//  AnswerTreatyVerb.swift
//  GTNWCore
//
//  `{"verb":"answerTreaty","id":"<offer>","accept":true}`: TreatyOffersSheet ACCEPT / DECLINE.
//

#if GTNW_CORE
import Foundation

enum AnswerTreatyVerb: BridgeVerb {
    static let name = "answerTreaty"

    struct Args: Decodable { var id: String; var accept: Bool }

    static func run(_ a: Args, engine e: GameEngine, state gs: GameState) throws -> GTNWBridge.Report? {
        guard e.answerTreaty(try WarSupport.uuid(a.id), accept: a.accept) else { throw QueryError("That offer is no longer on the table.") }
        return nil
    }
}
#endif
