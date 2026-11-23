//
//  PeaceQuery.swift
//  GTNWCore
//
//  `{"q":"peace"}`: PeaceSheet. The four peaceful paths to victory with progress and what is missing, what every
//  peace victory also needs, the peace score, and the wars elsewhere the President could broker an end to (with
//  the odds). Brokered with the `brokerPeace` verb.
//

#if GTNW_CORE
import Foundation

enum PeaceQuery: BridgeQuery {
    static let name = "peace"

    struct Path: Encodable {
        var id: String
        var title: String
        var victory: String
        var progress: String
        var fraction: Double
        var met: Bool
        var missing: String?
    }

    struct War: Encodable { var a: String; var aName: String; var b: String; var bName: String; var odds: Double }

    struct Result: Encodable {
        var score: Int
        var conditions: String
        var conditionsMet: Bool
        var paths: [Path]
        var brokerHeading: String
        var wars: [War]
        var actionsRemaining: Int
    }

    static func run(_ args: NoArgs, engine: GameEngine?) throws -> Result {
        let (_, gs) = try GTNWBridge.game(engine)
        let problem = PeaceModel.conditionsProblem(gs)
        let wars = PeaceModel.brokerable(gs)
        return Result(
            score: PeaceModel.scoreBonus(gs),
            conditions: problem.map { "Every peace victory also needs: \($0)" } ?? "At peace, no nuclear weapons used: any path completed wins.",
            conditionsMet: problem == nil,
            paths: PeacePath.allCases.map { path in
                let p = PeaceModel.progress(path, gs)
                return Path(id: path.rawValue, title: path.title, victory: path.victory.rawValue,
                            progress: path == .economicDominance ? String(format: "%.1f%% / %.1f%%", p.value * 100, p.target * 100) : "\(Int(p.value)) / \(Int(p.target))",
                            fraction: QueryText.round2(p.fraction), met: p.missing == nil, missing: p.missing)
            },
            brokerHeading: "Broker peace (\(wars.count) war\(wars.count == 1 ? "" : "s") elsewhere)",
            wars: wars.prefix(5).map { w in
                War(a: w.0.id, aName: w.0.name, b: w.1.id, bName: w.1.name, odds: QueryText.round2(PeaceModel.brokerOdds(w.0, w.1, player: gs.playerCountryID)))
            },
            actionsRemaining: gs.actionsRemaining)
    }
}
#endif
