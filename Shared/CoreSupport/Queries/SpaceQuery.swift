//
//  SpaceQuery.swift
//  GTNWCore
//
//  `{"q":"space"}`: the app's SpaceSheet (Space Force): satellites in orbit by type, what each launch costs, and
//  whether the space age (1957) has opened.
//

#if GTNW_CORE
import Foundation

enum SpaceQuery: BridgeQuery {
    static let name = "space"

    struct Satellite: Encodable {
        var type: String
        var title: String
        var inOrbit: Int
        var cost: Double
        var text: String
    }

    struct Result: Encodable {
        var dateLabel: String
        var spaceAge: Bool
        var spaceAgeYear: Int
        var satellites: [Satellite]
        var actionsRemaining: Int
        var gameOver: Bool
    }

    static func run(_ args: NoArgs, engine: GameEngine?) throws -> Result {
        let (_, gs) = try GTNWBridge.game(engine)
        let sat = { (t: SatType, title: String, text: String) in
            Satellite(type: t.rawValue, title: title, inOrbit: gs.shadow.satellites[t.rawValue] ?? 0, cost: GameEngine.satelliteCost(t), text: text)
        }
        return Result(dateLabel: gs.currentDateLabel, spaceAge: gs.currentYear >= GameEngine.spaceAgeYear, spaceAgeYear: GameEngine.spaceAgeYear,
                      satellites: [
                        sat(.recon, "Reconnaissance", "Sharpens your National Intelligence Estimate of every foreign power — a confirmed count where you'd otherwise see only a wide guess."),
                        sat(.warning, "Early warning", "Launch detection: when YOUR nation is the target of a nuclear strike, it adds missile-defense coverage (even without SDI) so more incoming warheads are tracked and intercepted."),
                      ],
                      actionsRemaining: gs.actionsRemaining, gameOver: gs.gameOver)
    }
}
#endif
