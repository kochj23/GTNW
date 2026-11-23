//
//  SetExtractionVerb.swift
//  GTNWCore
//
//  `{"verb":"setExtraction","id":"<territory>","rate":"heavy"}`: ResourcesSheet rate buttons (free).
//

#if GTNW_CORE
import Foundation

enum SetExtractionVerb: BridgeVerb {
    static let name = "setExtraction"

    struct Args: Decodable { var id: String; var rate: String }

    static func run(_ a: Args, engine e: GameEngine, state gs: GameState) throws -> GTNWBridge.Report? {
        guard let rate = ExtractionRate(rawValue: a.rate), e.setExtraction(a.id, rate) else { throw QueryError("Those orders can't be carried out.") }
        return nil
    }
}
#endif
