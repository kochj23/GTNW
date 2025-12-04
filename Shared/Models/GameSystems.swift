//
//  GameSystems.swift
//  Global Thermal Nuclear War
//
//  Consolidated implementation of all game systems
//

import Foundation
import SwiftUI

// MARK: - Unified Operation Base
protocol GameOperation: Identifiable, Codable {
    var id: UUID { get }
    var initiatorID: String { get }
    var targetID: String { get }
    var turn: Int { get }
    var success: Bool { get set }
}

// MARK: - Intelligence & Espionage
enum IntelType: String, Codable, CaseIterable {
    case sigint, humint, imint, osint, techint
    var cost: Int { [10, 150, 100, 10, 75][IntelType.allCases.firstIndex(of: self)!] * 1_000_000 }
    var risk: Int { [15, 40, 5, 0, 20][IntelType.allCases.firstIndex(of: self)!] }
}

struct SpyNetwork: Identifiable, Codable {
    let id = UUID()
    let owner: String, location: String, deployed: Int
    var strength: Int, cover: Int, compromised = false
}

struct IntelOp: GameOperation {
    let id = UUID()
    let initiatorID: String, targetID: String, turn: Int
    let type: IntelType
    var success = false
    var data: String = ""
}

// MARK: - Crisis Events
enum Crisis: String, Codable, CaseIterable {
    case missiles, falseAlarm, accident, coup, meltdown, rogue, terrorist
    var time: Int { [13, 1, 1, 3, 2, 1, 3][Crisis.allCases.firstIndex(of: self)!] }
}

struct CrisisEvent: Identifiable, Codable {
    let id = UUID()
    let type: Crisis, turn: Int
    var deadline: Int, resolved = false
    var options: [String] = []
}

// MARK: - Nuclear Winter & Environment
enum WinterStage: Int, Codable {
    case none, early, regional, hemispheric, global, extinction
    var tempDrop: Int { rawValue * 5 }
    var foodMult: Double { [1.0, 0.8, 0.4, 0.1, 0.01, 0.0][rawValue] }
}

struct EnvironState: Codable {
    var stage: WinterStage = .none
    var temp = 0, soot = 0, ozone = 0, uv = 0, water = 0
    var food = 100, land = 100, extinct = 0
}

struct FamineState: Codable {
    var severity = 0, affected = 0, deaths = 0, reserves = 12, unrest = 0
}

struct DiseaseState: Codable {
    var cholera = 0, typhus = 0, radiation = 0, total = 0
}

struct RefugeeCrisis: Codable {
    var total = 0, camps: [String: Int] = [:]
}

struct RecoveryState: Codable {
    var stage = 0, progress = 0, years = 0
}

// MARK: - Diplomacy & Treaties
enum TreatyKind: String, Codable {
    case start, abm, testBan, inf, npt
    var reduction: Int { self == .start ? 500 : self == .inf ? 200 : 0 }
}

struct TreatyProposal: Identifiable, Codable {
    let id = UUID()
    let proposer: String, targets: [String], type: TreatyKind
    var accepted = false
}

struct Verification: GameOperation {
    let id = UUID()
    let initiatorID: String, targetID: String, turn: Int
    var success = false, cheating = false
}

// MARK: - Proxy Wars
enum ProxyType: String, Codable {
    case rebels, insurgency, advisors, air, special
}

struct ProxyWar: GameOperation {
    let id = UUID()
    let initiatorID: String, targetID: String, turn: Int
    let type: ProxyType
    var success = false, strength = 50, casualties = 0
}

struct ArmsSale: Identifiable, Codable {
    let id = UUID()
    let seller: String, buyer: String, weapon: String, qty: Int, price: Int
}

// MARK: - Economic Warfare
enum Sanction: String, Codable, CaseIterable {
    case oil, trade, finance, tech, blockade
    var damage: Int { ([20, 10, 30, 15, 50][Sanction.allCases.firstIndex(of: self)!]) * 1_000_000 }
}

struct EconSanction: Identifiable, Codable {
    let id = UUID()
    let imposer: String, target: String, type: Sanction
}

struct CurrencyAttack: GameOperation {
    let id = UUID()
    let initiatorID: String, targetID: String, turn: Int
    var success = false, invest: Int = 0, inflation = 0
}

// MARK: - AI Personalities
enum Personality: String, Codable, CaseIterable {
    case aggressive, defensive, reformer, unpredictable, pragmatic, ideologue
    var aggro: Int { [-20, 40, -30, 0, 10, 25][Personality.allCases.firstIndex(of: self)!] }
    var diplo: Int { [50, 30, 80, 20, 70, 40][Personality.allCases.firstIndex(of: self)!] }
    var risk: Int { [30, 90, 40, 95, 50, 70][Personality.allCases.firstIndex(of: self)!] }
}

enum Ideology: String, Codable {
    case communist, capitalist, nationalist, theocratic, authoritarian
}

enum Goal: String, Codable {
    case domination, hegemony, ideology, economic, nuclear, peace
}

struct Leader: Codable {
    let name: String, personality: Personality, ideology: Ideology, goal: Goal
    static let presets = [
        Leader(name: "Reagan", personality: .aggressive, ideology: .capitalist, goal: .nuclear),
        Leader(name: "Gorbachev", personality: .reformer, ideology: .communist, goal: .peace),
        Leader(name: "Mao", personality: .unpredictable, ideology: .communist, goal: .ideology),
        Leader(name: "Thatcher", personality: .pragmatic, ideology: .capitalist, goal: .economic),
        Leader(name: "Kim", personality: .unpredictable, ideology: .authoritarian, goal: .nuclear)
    ]
}

// MARK: - Submarine Warfare
enum SubClass: String, Codable, CaseIterable {
    case ohio, typhoon, vanguard, triomphant, jin
    var warheads: Int { [24, 20, 16, 16, 12][SubClass.allCases.firstIndex(of: self)!] }
    var stealth: Int { [90, 75, 85, 80, 70][SubClass.allCases.firstIndex(of: self)!] }
}

enum SubLoc: String, Codable {
    case patrol, coast, arctic, port
}

struct Sub: Identifiable, Codable {
    let id = UUID()
    let owner: String, subClass: SubClass, deployed: Int
    var loc: SubLoc = .patrol, warheads: Int, detected = false, stealth: Int
    init(owner: String, type: SubClass, turn: Int) {
        self.owner = owner; self.subClass = type; self.deployed = turn
        self.warheads = type.warheads; self.stealth = type.stealth
    }
}

struct ASW: GameOperation {
    let id = UUID()
    let initiatorID: String, targetID: String, turn: Int
    var success = false
}

// MARK: - Space Warfare
enum SatType: String, Codable, CaseIterable {
    case recon, comms, gps, warning, weather
    var cost: Int { [500, 300, 400, 1000, 200][SatType.allCases.firstIndex(of: self)!] * 1_000_000 }
    var bonus: String { ["+20% intel", "Global comms", "+10% accuracy", "Launch detect", "Weather"][SatType.allCases.firstIndex(of: self)!] }
}

struct Sat: Identifiable, Codable {
    let id = UUID()
    let owner: String, type: SatType, launched: Int
    var operational = true, destroyed = false
}

struct ASAT: GameOperation {
    let id = UUID()
    let initiatorID: String, targetID: String, turn: Int
    var success = false, debris = 0
}

struct Debris: Codable {
    var total = 0, kessler = 0, zones: [String] = []
    mutating func add(_ n: Int) {
        total += n; kessler = min(100, total / 100)
        zones = kessler > 75 ? ["LEO","MEO","GEO"] : kessler > 50 ? ["LEO","MEO"] : kessler > 25 ? ["LEO"] : []
    }
}

// MARK: - Historical Scenarios
struct WarPair: Codable {
    let attacker: String, defender: String
}

struct Scenario: Identifiable, Codable {
    let id = UUID()
    let name: String, year: Int, desc: String, objective: String
    let defcon: DefconLevel, wars: [WarPair], warheads: Int
    let relations: [String:[String:Int]], events: [String]
    let difficulty: DifficultyLevel

    static let all = [
        Scenario(name: "Cuban Missile Crisis", year: 1962,
                desc: "October 1962. Soviet missiles in Cuba. 13 days.",
                objective: "Remove missiles without war",
                defcon: .defcon2, wars: [], warheads: 3000,
                relations: ["USA":["RUS":-90,"CUB":-95]], events: ["Crisis Active"],
                difficulty: .hard),
        Scenario(name: "Able Archer 83", year: 1983,
                desc: "NATO exercise mistaken for war prep.",
                objective: "Prevent Soviet first strike",
                defcon: .defcon2, wars: [], warheads: 5000,
                relations: ["USA":["RUS":-80]], events: ["Exercise","Soviet Paranoia"],
                difficulty: .nightmare),
        Scenario(name: "Petrov Incident", year: 1983,
                desc: "False alarm: 5 missiles detected.",
                objective: "Don't launch WW3",
                defcon: .defcon1, wars: [], warheads: 4000,
                relations: [:], events: ["False Alarm"],
                difficulty: .nightmare),
        Scenario(name: "Cold War 1980", year: 1980,
                desc: "Reagan era. USSR in Afghanistan.",
                objective: "Win without going hot",
                defcon: .defcon3, wars: [WarPair(attacker:"RUS", defender:"AFG")], warheads: 4500,
                relations: [:], events: ["Afghanistan","Reagan"],
                difficulty: .normal),
        Scenario(name: "What If: JFK", year: 1964,
                desc: "Kennedy lives. History changes.",
                objective: "Prevent Vietnam. Achieve detente",
                defcon: .defcon4, wars: [], warheads: 2500,
                relations: [:], events: ["JFK Alive","Vietnam"],
                difficulty: .hard)
    ]
}

// MARK: - Unified Game Systems Manager
class SystemsManager: ObservableObject {
    // Intelligence
    @Published var intelOps: [IntelOp] = []
    @Published var spyNets: [SpyNetwork] = []

    // Crises
    @Published var crises: [CrisisEvent] = []
    @Published var resolved: [CrisisEvent] = []

    // Environment
    @Published var environ = EnvironState()
    @Published var famine = FamineState()
    @Published var disease = DiseaseState()
    @Published var refugees = RefugeeCrisis()
    @Published var recovery = RecoveryState()

    // Diplomacy
    @Published var treaties: [TreatyProposal] = []
    @Published var verifications: [Verification] = []

    // Warfare
    @Published var proxies: [ProxyWar] = []
    @Published var arms: [ArmsSale] = []
    @Published var sanctions: [EconSanction] = []
    @Published var currency: [CurrencyAttack] = []
    @Published var subs: [Sub] = []
    @Published var asw: [ASW] = []
    @Published var sats: [Sat] = []
    @Published var asat: [ASAT] = []
    @Published var debris = Debris()

    // Scenarios
    @Published var scenario: Scenario?

    // Process all systems per turn
    func processTurn(gameState: GameState) {
        processIntel(gameState)
        processCrises(gameState)
        updateEnvironment(gameState)
        processDiplomacy(gameState)
        processWarfare(gameState)
        processSpace(gameState)
    }

    private func processIntel(_ gs: GameState) {
        intelOps.removeAll { $0.turn < gs.turn - 5 }
        spyNets.indices.forEach { i in
            if Int.random(in: 0...100) < (100 - spyNets[i].cover) / 3 {
                spyNets[i].compromised = true
            }
        }
    }

    private func processCrises(_ gs: GameState) {
        crises.indices.forEach { crises[$0].deadline -= 1 }
        resolved.append(contentsOf: crises.filter { $0.resolved || $0.deadline <= 0 })
        crises.removeAll { $0.resolved || $0.deadline <= 0 }

        if gs.defconLevel.rawValue <= 2 && Int.random(in: 0...100) < 20 {
            let crisis = Crisis.allCases.randomElement()!
            crises.append(CrisisEvent(type: crisis, turn: gs.turn, deadline: crisis.time))
        }
    }

    private func updateEnvironment(_ gs: GameState) {
        let warheads = gs.nuclearStrikes.reduce(0) { $0 + $1.warheadsUsed }
        environ.stage = WinterStage(rawValue: min(5, warheads / 100)) ?? .none
        environ.temp = environ.stage.tempDrop
        environ.food = Int(100 * environ.stage.foodMult)

        if environ.stage.rawValue >= 2 {
            famine.severity = environ.stage.rawValue * 20
            famine.deaths += famine.severity * 1000
            disease.total = famine.severity * 500
            refugees.total += famine.affected / 10
        }
    }

    private func processDiplomacy(_ gs: GameState) {
        treaties.indices.forEach { i in
            if treaties[i].accepted {
                let treaty = treaties[i]
                treaty.targets.forEach { target in
                    if let idx = gs.countries.firstIndex(where: { $0.id == target }) {
                        gs.countries[idx].nuclearWarheads -= treaty.type.reduction
                    }
                }
            }
        }
    }

    private func processWarfare(_ gs: GameState) {
        proxies.indices.forEach { i in
            proxies[i].casualties += Int.random(in: 100...1000)
            proxies[i].strength = max(0, proxies[i].strength - Int.random(in: 1...5))
        }
        proxies.removeAll { $0.strength <= 0 }

        subs.indices.forEach { i in
            if subs[i].loc == .coast { subs[i].stealth -= 10 }
            subs[i].detected = Int.random(in: 0...100) > subs[i].stealth
        }
    }

    private func processSpace(_ gs: GameState) {
        asat.indices.forEach { i in
            if asat[i].success {
                if let idx = sats.firstIndex(where: { $0.id.uuidString == asat[i].targetID }) {
                    sats[idx].destroyed = true
                    sats[idx].operational = false
                    debris.add(Int.random(in: 50...200))
                }
            }
        }
        sats.removeAll { $0.destroyed }
    }
}
