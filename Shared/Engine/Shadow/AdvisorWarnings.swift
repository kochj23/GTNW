//
//  AdvisorWarnings.swift
//  Global Thermal Nuclear War
//
//  Advisor warnings (3.8.0): before any major action (an attack, a nuclear strike, a chemical or biological weapon,
//  an annexation, a land claim, a fleet order) the Joint Chiefs, the Secretary of State and the Vice President each
//  give one short risk read-out. Every number comes from the same functions the engine will use, so the warnings are
//  honest. The President can overrule (proceed) or cancel. A setting turns them off for speed players.
//  Repository: https://github.com/kochj23/GTNW
//

import Foundation

/// The decisions that get a warning.
enum MajorAction {
    case attack(PresidentialAction, target: String, size: AttackSize?)
    case annex(country: String)
    case claim(land: String, troops: Double)
    case fleet(fleetID: String, target: String, mission: NavalMission, preset: AttackPreset)

    /// Which presidential actions count as major: hostile military, nuclear and chemical / biological.
    static func isMajor(_ a: PresidentialAction) -> Bool {
        a.wmd != nil || a.rung == .nuclear && a.isHostile && a != .nuclearTest || [.groundInvasion, .airStrike, .bombardment, .navalBlockade, .amphAssault].contains(a)
    }
}

struct AdvisorWarning: Hashable {
    /// "Joint Chiefs", "Secretary of State", "Vice President".
    var who: String
    var text: String
    /// 0 calm, 1 caution, 2 danger.
    var level: Int
}

enum AdvisorWarnings {
    static let defaultsKey = "GTNW.advisorWarnings"
    static func enabled(_ d: UserDefaults = .standard) -> Bool { d.object(forKey: defaultsKey) as? Bool ?? true }
}

extension GameEngine {
    /// The three lines for a major action. Empty when there is no game.
    func advisorWarnings(for action: MajorAction) -> [AdvisorWarning] {
        guard let gs = gameState, let player = gs.getPlayerCountry() else { return [] }
        let year = gs.currentYear
        let stateName = AdviceEngine.advisor(for: "state", in: gs.advisors)?.name
        func pressure(dPop: Double, dRuth: Double) -> Double {
            ExpansionModel.impeachmentPressure(popularity: gs.shadow.popularity + dPop, ruthlessness: gs.shadow.ruthlessness + dRuth,
                                               congress: player.congressionalSupport)
        }
        func vp(dPop: Double, dRuth: Double, war: String?) -> AdvisorWarning {
            let p = pressure(dPop: dPop, dRuth: dRuth)
            var text = String(format: "Approval %+.0f at home.", dPop)
            var level = dPop < -3 ? 1 : 0
            if let t = war, gs.playerCountryID == "USA", !isAuthorized(t), gs.currentDate >= CongressModel.warPowersResolution {
                text += " No authorization from Congress: the 60-day War Powers clock starts."
                level = max(level, 1)
            }
            if p > ExpansionModel.impeachmentThreshold {
                text += " Congress will move to impeach at the next poll."
                level = 2
            } else if p > ExpansionModel.impeachmentThreshold / 2 {
                text += " Impeachment talk is rising on the Hill."
                level = max(level, 1)
            }
            return AdvisorWarning(who: "Vice President", text: text, level: level)
        }
        let stateWho = stateName.map { "Secretary of State \($0)" } ?? "Secretary of State"

        switch action {
        case .attack(let a, let target, let size):
            let t = gs.getCountry(id: target)
            let tName = t?.name ?? target
            let kinds = AttackSizing.kinds(for: a)
            let sized = size.map { AttackSizing.clamp($0, for: a, in: gs) }
            let m = sized.map { AttackSizing.scale($0, for: a, in: gs) } ?? 1
            // Joint Chiefs: the odds and the cost in forces.
            var jcs: String
            var jl = 0
            if let k = a.wmd {
                let status = ArsenalCatalog.legalStatus(k, on: gs.currentDate)
                jcs = "\(k.title) weapons will break \(tName)'s front line, but nothing about them stays contained."
                jl = status == .legal ? 1 : 2
            } else if AttackSizing.nuclearActions.contains(a) {
                let w = sized?.warheads ?? AttackSizing.standard(a, in: gs).warheads
                let ret = min(w * 2, t?.nuclearWarheads ?? 0)
                jcs = "\(w) warhead\(w == 1 ? "" : "s"), up to \((w * 1_000_000).formatted()) dead before defences."
                    + (ret > 0 ? " Expect retaliation: up to \(ret) warheads on us." : " They cannot strike back.")
                jl = ret > 0 ? 2 : 1
            } else if kinds.contains(.troops), let t, let s = sized ?? Optional(AttackSizing.standard(a, in: gs)) {
                let odds = AttackSizing.invasionOdds(troops: s.troops, attacker: player, defender: t)
                jcs = "Opening odds \(Int(odds * 100))% with \(Int(s.troops))K troops. A war of weeks, with casualties on both sides."
                jl = odds < 0.5 ? 2 : (odds < 0.75 ? 1 : 0)
            } else if kinds.contains(.aircraft), let t {
                let sorties = (sized ?? AttackSizing.standard(a, in: gs)).aircraft
                jcs = "Success \(Int(AttackSizing.successOdds(scale: m) * 100))%. Expect about \(AttackSizing.aircraftLost(sorties: sorties, against: t)) aircraft lost."
                jl = m < 1 ? 1 : 0
            } else {
                jcs = "This means war with \(tName)."
                jl = 1
            }
            // Secretary of State: the world's reaction.
            var state: String
            var sl = 0
            var dPop = PopularityModel.actionEffect(rung: a.rung, hostile: a.isHostile, detected: false)
            var dRuth = PopularityModel.ruthlessnessEffect(rung: a.rung, hostile: a.isHostile) + Double(AttackSizing.ruthlessness(scale: m))
            if let k = a.wmd {
                let status = ArsenalCatalog.legalStatus(k, on: gs.currentDate)
                let c = ArsenalCatalog.cost(status)
                state = "\(ArsenalCatalog.treatyLabel(k, year: year) ?? "No treaty binds us yet.") Every capital will turn on us: relations −\(c.world), allies −\(c.world + c.allies)\(c.sanctions > 0 ? ", sanctions" : "")."
                sl = status == .legal ? 1 : 2
                dPop = -c.popularity; dRuth = c.ruthlessness
            } else {
                let hit = AttackSizing.worldHit(scale: m)
                state = "\(tName) will treat this as war." + (hit > 0 ? " The rest of the world: relations −\(hit) for the size of it." : "")
                if let st = ArsenalCatalog.status(for: a, year: year), st == .treatyBanned { state += " This breaks a treaty we signed."; sl = 2 }
                if AttackSizing.nuclearActions.contains(a) { state += " Nobody has used these in anger since 1945."; sl = 2 }
                sl = max(sl, hit > 0 ? 1 : 0)
            }
            return [AdvisorWarning(who: "Joint Chiefs", text: jcs, level: jl),
                    AdvisorWarning(who: stateWho, text: state, level: sl),
                    vp(dPop: dPop, dRuth: dRuth, war: target)]

        case .annex(let id):
            let name = gs.getCountry(id: id)?.name ?? id
            return [AdvisorWarning(who: "Joint Chiefs", text: "Occupying \(name) means an insurgency: garrison it, or it will cost us.", level: 1),
                    AdvisorWarning(who: stateWho, text: "Annexation: rivals −20, the rest of the world −10, allies −3.\(year >= 1945 ? " The UN Charter era will not forgive it." : "")",
                                   level: year >= 1945 ? 2 : 1),
                    vp(dPop: 0, dRuth: 15, war: nil)]

        case .claim(let land, let troops):
            let name = WorldCountriesDatabase.template(id: land)?.name ?? land
            let n = ExpansionModel.takenLastYear(gs, before: gs.currentDate) + 1
            let pol = ExpansionModel.politics(year: year, nth: n)
            let f = AttackSizing.relationFactor(scale: troops / AttackSizing.expeditionStandard) * pol.worldFactor
            if land == Antarctica.id {
                let status = Antarctica.legalStatus(on: gs.currentDate)
                let c = ArsenalCatalog.cost(status)
                return [AdvisorWarning(who: "Joint Chiefs", text: "The ice needs only \(Antarctica.neededGarrison)K men, but the cold takes 5% of them a month and upkeep is heavy.", level: 1),
                        AdvisorWarning(who: stateWho, text: status == .treatyBanned ? "This breaks the Antarctic Treaty (in force 1961): relations −\(c.world) everywhere, allies −\(c.world + c.allies), sanctions."
                                       : (status == .restricted ? "The Antarctic Treaty is signed but not yet in force; claiming now looks like bad faith." : "Seven nations already claim slices of it; none really rules it."),
                                       level: status == .treatyBanned ? 2 : (status == .restricted ? 1 : 0)),
                        vp(dPop: pol.popularity - (status == .legal ? 0 : c.popularity), dRuth: pol.ruthlessness + (status == .legal ? 0 : c.ruthlessness), war: nil)]
            }
            return [AdvisorWarning(who: "Joint Chiefs", text: "No army to fight in \(name). \(Int(troops))K troops will hold it as a garrison.", level: 0),
                    AdvisorWarning(who: stateWho, text: "Claim #\(n) this year: rivals −\(Int((5 * f).rounded())), others −\(Int((2 * f).rounded())).",
                                   level: pol.worldFactor > 1.5 ? 1 : 0),
                    vp(dPop: pol.popularity, dRuth: pol.ruthlessness, war: nil)]

        case .fleet(let fleetID, let target, let mission, let preset):
            let fleet = NavalModel.fleet(id: fleetID)
            let name = gs.getCountry(id: target)?.name ?? WorldCountriesDatabase.template(id: target)?.name ?? target
            let ships = fleet.map { NavalModel.composition($0, year: year).scaled(NavalMission.commitment(preset)) } ?? FleetComposition()
            let probe = FleetDeployment(fleetID: fleetID, target: target, mission: mission, commitment: NavalMission.commitment(preset), ships: ships,
                                        fromLat: 0, fromLon: 0, toLat: 0, toLon: 0, departed: Date(), arrives: Date())
            let lost = mission == .showOfForce ? 0 : NavalModel.shipsLost(probe, defence: NavalModel.defence(gs.getCountry(id: target), year: year))
            let war = mission != .showOfForce && gs.getCountry(id: target) != nil
            return [AdvisorWarning(who: "Joint Chiefs", text: "\(ships.total) ships committed; expect about \(lost) lost on arrival.", level: lost > ships.total / 5 ? 2 : (lost > 0 ? 1 : 0)),
                    AdvisorWarning(who: stateWho, text: war ? "\(name) will treat a \(mission.title.lowercased()) as an act of war." : "Pressure without shots: \(name) will be angry, not at war.",
                                   level: war ? 1 : 0),
                    vp(dPop: war ? 2 : 0, dRuth: war ? 6 : 0, war: war ? target : nil)]
        }
    }
}
