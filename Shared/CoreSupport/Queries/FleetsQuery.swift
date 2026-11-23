//
//  FleetsQuery.swift
//  GTNWCore
//
//  `{"q":"fleets","target":"CUB","fleet":"pac","mission":"blockade","preset":"standard"}` (all but target
//  optional): FleetOrderSheet. The era's named U.S. fleets with their ships and whether they are out, the four
//  missions and three commitments, and for the chosen fleet the honest numbers (ships, distance, days at sea,
//  expected losses, the strike weapon or troops landed), why the order can't go, the cabinet's warnings, and the
//  fleets already out. Ordered with the `orderFleet` verb, brought home with `recallFleet`.
//

#if GTNW_CORE
import Foundation

enum FleetsQuery: BridgeQuery {
    static let name = "fleets"

    struct Args: Decodable { var target: String; var fleet: String?; var mission: String?; var preset: String? }

    struct Fleet: Encodable { var id: String; var name: String; var home: String; var out: String?; var ships: String }
    struct Mission: Encodable { var id: String; var title: String; var summary: String }
    struct Commit: Encodable { var id: String; var title: String; var percent: Int }
    struct Out: Encodable { var id: String; var line: String }

    struct Result: Encodable {
        var year: Int
        var target: String
        var targetName: String
        /// "The United States has no navy in 1790." when there is none.
        var noNavy: String?
        var fleets: [Fleet]
        var chosen: String?
        var missions: [Mission]
        var mission: String
        var commitments: [Commit]
        var preset: String
        var readout: String?
        var problem: String?
        var warnings: [WarSupport.Warning]
        var orderTitle: String?
        var deployments: [Out]
    }

    static func shipLine(_ c: FleetComposition) -> String {
        var parts: [String] = []
        if c.carriers > 0 { parts.append("\(c.carriers) CV") }
        parts.append("\(c.surface) surface")
        if c.submarines > 0 { parts.append("\(c.submarines) sub") }
        if c.amphibious > 0 { parts.append("\(c.amphibious) amphib") }
        return parts.joined(separator: " · ")
    }

    static func run(_ args: Args, engine: GameEngine?) throws -> Result {
        let (e, gs) = try GTNWBridge.game(engine)
        let year = gs.currentYear
        let fleets = NavalModel.fleets(in: year)
        let mission = args.mission.flatMap(NavalMission.init(rawValue:)) ?? .showOfForce
        let preset = WarSupport.preset(args.preset)
        let chosen = args.fleet.flatMap { id in fleets.contains { $0.id == id } ? id : nil }
            ?? fleets.first { f in !gs.shadow.fleetDeployments.contains { $0.fleetID == f.id } }?.id
        var readout: String?, problem: String?, warnings: [AdvisorWarning] = [], orderTitle: String?
        if let id = chosen, let f = NavalModel.fleet(id: id) {
            let ships = NavalModel.composition(f, year: year).scaled(NavalMission.commitment(preset))
            let home = f.period(in: year)
            let to = gs.getCountry(id: args.target).map { ($0.coordinates.lat, $0.coordinates.lon) }
                ?? WorldCountriesDatabase.template(id: args.target).map { ($0.lat, $0.lon) } ?? (0, 0)
            let km = NavalModel.distanceKm(lat1: home?.lat ?? 0, lon1: home?.lon ?? 0, lat2: to.0, lon2: to.1)
            let days = NavalModel.transitDays(km: km, year: year)
            let probe = FleetDeployment(fleetID: f.id, target: args.target, mission: mission, commitment: NavalMission.commitment(preset), ships: ships,
                                        fromLat: 0, fromLon: 0, toLat: 0, toLon: 0, departed: gs.currentDate, arrives: gs.currentDate)
            let lost = mission == .showOfForce ? 0 : NavalModel.shipsLost(probe, defence: NavalModel.defence(gs.getCountry(id: args.target), year: year))
            var line = "\(ships.total) ships (\(shipLine(ships))) · \(Int(km)) km, about \(days) days at sea · expected losses on arrival ~\(lost)"
            if mission == .strike { line += " · weapons: \(NavalModel.strikeWeapon(year: year))" }
            if mission == .amphibious { line += " · lands ~\(Int(NavalModel.landingTroops(ships, year: year)))K troops" }
            readout = line
            problem = e.fleetOrderProblem(fleetID: id, target: args.target, mission: mission)
            warnings = e.advisorWarnings(for: .fleet(fleetID: id, target: args.target, mission: mission, preset: preset))
            orderTitle = WarSupport.proceedTitle(warnings, default: "Order \(f.name) out")
        }
        return Result(
            year: year, target: args.target, targetName: WarSupport.name(args.target, gs),
            noNavy: fleets.isEmpty ? "The United States has no navy in \(year)." : nil,
            fleets: fleets.map { f in
                let out = gs.shadow.fleetDeployments.first { $0.fleetID == f.id }
                return Fleet(id: f.id, name: f.name, home: f.period(in: year)?.home ?? "",
                             out: out.map { $0.status == .underway ? "Under way" : "On station" },
                             ships: shipLine(NavalModel.composition(f, year: year)))
            },
            chosen: chosen,
            missions: NavalMission.allCases.map { Mission(id: $0.rawValue, title: $0.title, summary: $0.summary) },
            mission: mission.rawValue,
            commitments: AttackPreset.allCases.map { Commit(id: $0.rawValue, title: $0.title, percent: Int(NavalMission.commitment($0) * 100)) },
            preset: preset.rawValue, readout: readout, problem: problem, warnings: WarSupport.warnings(warnings), orderTitle: orderTitle,
            deployments: gs.shadow.fleetDeployments.map { d in
                let name = NavalModel.fleet(id: d.fleetID)?.name ?? d.fleetID
                return Out(id: d.id.uuidString, line: "\(name) — \(d.mission.title) — \(WarSupport.name(d.target, gs)) — "
                           + "\(d.status == .underway ? "arrives \(GameCalendar.format(d.arrives))" : "on station") — \(d.shipsAfloat) ships")
            })
    }
}
#endif
