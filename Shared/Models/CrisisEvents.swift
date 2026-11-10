//
//  CrisisEvents.swift
//  Global Thermal Nuclear War
//
//  Dynamic crisis events that create tension and force tough choices
//  Created by Jordan Koch on 2025-12-03.
//

import Foundation
import SwiftUI

/// Crisis event types that can occur during gameplay
enum CrisisEventType: String, Codable, CaseIterable {
    case falseAlarm = "False Alarm"
    case nuclearAccident = "Nuclear Accident"
    case terroristThreat = "Terrorist Threat"
    case espionageDiscovered = "Espionage Discovered"
    case militaryCoup = "Military Coup"
    case cyberAttack = "Cyber Attack"
    case diplomaticIncident = "Diplomatic Incident"
    case economicCollapse = "Economic Collapse"
    case rogueCommander = "Rogue Commander"
    case satelliteFailure = "Satellite Failure"
    case civilUnrest = "Civil Unrest"
    case weaponsMalfunction = "Weapons Malfunction"
    case radiationLeak = "Radiation Leak"
    case spyRingUncovered = "Spy Ring Uncovered"
    case assassinationAttempt = "Assassination Attempt"
    case naturalDisaster = "Natural Disaster"
    // 3.20.0: the world's news reaches the Oval Office as decisions, not footnotes.
    case worldDisaster = "World Disaster"     // a hurricane, quake, flood… strikes another nation
    case warOutbreak = "War Outbreak"         // two nations go to war
    case regimeChange = "Change of Power"     // a coup, a new regime, an annexation or a liberation
    // 3.21.0
    case election = "Election"                // a step in the election cycle that needs the President

    /// What an epigraph on this crisis should be about.
    var quoteTags: Set<QuoteTag> {
        switch self {
        case .falseAlarm: return [.nuclear, .accident, .uncertainty, .deterrence]
        case .nuclearAccident, .radiationLeak, .weaponsMalfunction: return [.accident, .nuclear, .apocalypse]
        case .terroristThreat: return [.terror, .fear]
        case .espionageDiscovered, .spyRingUncovered: return [.intelligence, .deception]
        case .militaryCoup: return [.coup, .power]
        case .cyberAttack: return [.cyber, .intelligence]
        case .diplomaticIncident: return [.diplomacy, .escalation]
        case .economicCollapse: return [.economy, .unrest]
        case .rogueCommander: return [.accident, .nuclear, .leadership]
        case .satelliteFailure: return [.space, .cyber, .uncertainty]
        case .civilUnrest: return [.unrest, .power]
        case .assassinationAttempt: return [.terror, .coup, .leadership]
        case .naturalDisaster, .worldDisaster: return [.disaster, .mercy, .fear]
        case .warOutbreak: return [.war, .escalation, .alliance]
        case .regimeChange: return [.power, .coup, .occupation]
        case .election: return [.election, .leadership, .power]
        }
    }
}

/// Severity levels for crisis events
enum CrisisSeverity: Int, Codable {
    case minor = 1
    case moderate = 2
    case serious = 3
    case critical = 4
    case catastrophic = 5

    var color: Color {
        switch self {
        case .minor: return .cyan
        case .moderate: return AppSettings.terminalAmber
        case .serious: return .orange
        case .critical: return AppSettings.terminalRed
        case .catastrophic: return .red
        }
    }

    var description: String {
        switch self {
        case .minor: return "MINOR"
        case .moderate: return "MODERATE"
        case .serious: return "SERIOUS"
        case .critical: return "CRITICAL"
        case .catastrophic: return "CATASTROPHIC"
        }
    }
}

/// A crisis event that requires player decision
struct CrisisEvent: Identifiable, Codable {
    let id: UUID
    let type: CrisisEventType
    let severity: CrisisSeverity
    var title: String
    var description: String
    let affectedCountries: [String]
    let turn: Int
    let timeLimit: Int?  // Seconds to respond (nil = no limit)
    var options: [CrisisOption]
    var resolved: Bool = false
    var chosenOption: Int?

    /// 3.20.0: the epigraph for this crisis — one line from the sacred texts, science fiction or military
    /// doctrine, matched to its subject and stable for its lifetime.
    var epigraph: Quotation { Quotations.pick(quoteTags ?? type.quoteTags, seed: id.uuidString) }
    /// Subject override for the epigraph (an epidemic wants different lines than an earthquake).
    var quoteTags: Set<QuoteTag>? = nil

    init(type: CrisisEventType, severity: CrisisSeverity, title: String, description: String,
         affectedCountries: [String], turn: Int, timeLimit: Int? = nil, options: [CrisisOption]) {
        self.id = UUID()
        self.type = type
        self.severity = severity
        self.title = title
        self.description = description
        self.affectedCountries = affectedCountries
        self.turn = turn
        self.timeLimit = timeLimit
        self.options = options
    }
}

/// An option for responding to a crisis
struct CrisisOption: Identifiable, Codable {
    let id: UUID
    var title: String
    var description: String
    var advisorRecommendation: String?  // Which advisor recommends this
    var consequences: CrisisConsequences
    let successChance: Double  // 0.0-1.0

    init(title: String, description: String, advisorRecommendation: String? = nil,
         consequences: CrisisConsequences, successChance: Double = 1.0) {
        self.id = UUID()
        self.title = title
        self.description = description
        self.advisorRecommendation = advisorRecommendation
        self.consequences = consequences
        self.successChance = successChance
    }
}

/// Consequences of a crisis decision
struct CrisisConsequences: Codable {
    var relationshipChanges: [String: Int] = [:]  // Country ID -> change
    var approvalChange: Int = 0
    var defconChange: Int = 0
    var economicImpact: Int = 0
    var militaryImpact: Int = 0
    var triggersWar: Bool = false
    var warTarget: String?
    var message: String
    // 3.20.0 — effects on other nations (optional so older saves and API payloads still decode).
    /// Relations moved in BOTH directions between the President's nation and these countries.
    var mutualRelations: [String: Int]? = nil
    var countryStability: [String: Int]? = nil
    var countryMilitary: [String: Int]? = nil
    var countryEconomy: [String: Int]? = nil
    /// Ends the wars between these countries (a brokered ceasefire).
    var ceasefireBetween: [String]? = nil
    /// The President's nation goes to war against this country.
    var joinWarAgainst: String? = nil
    // 3.21.0 — the election cycle.
    /// Points of vote share gained or lost.
    var campaign: Double? = nil
    /// A campaign decision handled by `ElectionCycle.apply` ("retire", "debate|mock", "gamble|…").
    var electionChoice: String? = nil

    init(relationshipChanges: [String: Int] = [:], approvalChange: Int = 0,
         defconChange: Int = 0, economicImpact: Int = 0, militaryImpact: Int = 0,
         triggersWar: Bool = false, warTarget: String? = nil, message: String,
         mutualRelations: [String: Int]? = nil, countryStability: [String: Int]? = nil,
         countryMilitary: [String: Int]? = nil, countryEconomy: [String: Int]? = nil,
         ceasefireBetween: [String]? = nil, joinWarAgainst: String? = nil,
         campaign: Double? = nil, electionChoice: String? = nil) {
        self.campaign = campaign
        self.electionChoice = electionChoice
        self.relationshipChanges = relationshipChanges
        self.approvalChange = approvalChange
        self.defconChange = defconChange
        self.economicImpact = economicImpact
        self.militaryImpact = militaryImpact
        self.triggersWar = triggersWar
        self.warTarget = warTarget
        self.message = message
        self.mutualRelations = mutualRelations
        self.countryStability = countryStability
        self.countryMilitary = countryMilitary
        self.countryEconomy = countryEconomy
        self.ceasefireBetween = ceasefireBetween
        self.joinWarAgainst = joinWarAgainst
    }
}

/// Manages crisis events during gameplay
class CrisisManager: ObservableObject {
    @Published var activeCrisis: CrisisEvent?
    @Published var crisisHistory: [CrisisEvent] = []
    @Published var crisisTimeRemaining: Int = 0
    /// 3.20.0: decisions waiting behind the one on the desk — a war, a coup and a hurricane in the same turn all
    /// reach the President instead of the later ones being dropped.
    @Published var pendingCrises: [CrisisEvent] = []
    static let maxPending = 8
    /// What the world looked like at the last watch (wars, who rules where). Not saved: a loaded game re-baselines.
    var worldBaseline: WorldWatch.Snapshot?

    private var timer: Timer?
    /// 3.22.0: told about every decision (the engine logs it for Nova's column), whichever screen or API made it.
    var onResolved: ((CrisisEvent, Int, Bool) -> Void)?
    /// 3.22.2: the game year, so every card is put into its era's words before the President sees it.
    var currentYear: (() -> Int?)?

    /// Generate a random crisis event based on game state
    func generateRandomCrisis(gameState: GameState) -> CrisisEvent? {
        // Higher DEFCON = more likely to have crisis
        let crisisProbability: Double
        switch gameState.defconLevel {
        // 3.20.0: raised from 5–50%/year — the desk should be busy (world emergencies are rolled separately).
        case .defcon5: crisisProbability = 0.60
        case .defcon4: crisisProbability = 0.75
        case .defcon3: crisisProbability = 0.88
        case .defcon2: crisisProbability = 0.95
        case .defcon1: crisisProbability = 0.98
        }

        // The table above is per game year; scale it to the turn length.
        guard Double.random(in: 0...1) < gameState.scale.probability(annual: crisisProbability) else { return nil }

        // Select random crisis type
        let crisisTypes: [CrisisEventType] = [
            .falseAlarm, .nuclearAccident, .terroristThreat, .espionageDiscovered,
            .militaryCoup, .cyberAttack, .diplomaticIncident, .economicCollapse,
            .rogueCommander, .satelliteFailure, .civilUnrest, .weaponsMalfunction,
            .radiationLeak, .spyRingUncovered, .assassinationAttempt, .naturalDisaster
        ]

        // 3.22.2: only crises that can happen in this year (no cyber attacks or stolen warheads in 1814).
        guard let type = crisisTypes.filter({ Self.exists($0, in: gameState.currentYear) }).randomElement() else {
            return nil
        }
        return createCrisis(type: type, gameState: gameState)
    }

    /// The first year a crisis type can happen (3.22.2). Before it, `createCrisis` returns nil from every path
    /// (the random roll, the local API, the email host), so nothing modern reaches an earlier era.
    static func firstYear(_ type: CrisisEventType) -> Int {
        switch type {
        case .cyberAttack: return 1990                                   // GameState.cyberWarfareAvailable
        case .satelliteFailure: return 1957                              // Sputnik; satelliteSurveillanceAvailable
        case .falseAlarm: return 1960                                    // NORAD radar + early-warning satellites
        case .terroristThreat: return 1955                               // a stolen tactical nuclear weapon
        case .nuclearAccident, .radiationLeak, .rogueCommander, .weaponsMalfunction, .militaryCoup:
            return 1945                                                  // these are written for nuclear states
        default: return Int.min
        }
    }

    static func exists(_ type: CrisisEventType, in year: Int) -> Bool { year >= firstYear(type) }

    /// Create a specific crisis event
    /// nil when no country qualifies for that crisis (e.g. no armed rivals left late in a game).
    func createCrisis(type: CrisisEventType, gameState: GameState) -> CrisisEvent? {
        guard Self.exists(type, in: gameState.currentYear) else { return nil }
        switch type {
        case .falseAlarm:
            return createFalseAlarmCrisis(gameState: gameState)
        case .nuclearAccident:
            return createNuclearAccidentCrisis(gameState: gameState)
        case .terroristThreat:
            return createTerroristThreatCrisis(gameState: gameState)
        case .rogueCommander:
            return createRogueCommanderCrisis(gameState: gameState)
        case .cyberAttack:
            return createCyberAttackCrisis(gameState: gameState)
        case .militaryCoup:
            return createMilitaryCoupCrisis(gameState: gameState)
        case .espionageDiscovered:
            return createEspionageCrisis(gameState: gameState)
        case .diplomaticIncident:
            return createDiplomaticIncidentCrisis(gameState: gameState)
        case .economicCollapse:
            return createEconomicCollapseCrisis(gameState: gameState)
        case .satelliteFailure:
            return createSatelliteFailureCrisis(gameState: gameState)
        case .civilUnrest:
            return createCivilUnrestCrisis(gameState: gameState)
        case .weaponsMalfunction:
            return createWeaponsMalfunctionCrisis(gameState: gameState)
        case .radiationLeak:
            return createRadiationLeakCrisis(gameState: gameState)
        case .spyRingUncovered:
            return createSpyRingCrisis(gameState: gameState)
        case .assassinationAttempt:
            return createAssassinationCrisis(gameState: gameState)
        case .naturalDisaster:
            return createNaturalDisasterCrisis(gameState: gameState)
        case .worldDisaster:
            return WorldWatch.disasterCrisis(gameState: gameState)
        case .warOutbreak, .regimeChange, .election:
            return nil   // built from what actually changed in the world (WorldWatch.decisions)
        }
    }

    /// A natural disaster (3.18.14): an era-agnostic shock at home. How the President responds moves approval and
    /// costs the treasury — relief is expensive but rallies the country; indifference is cheap and ruinous.
    private func createNaturalDisasterCrisis(gameState: GameState) -> CrisisEvent? {
        let disasters: [(String, String, Int)] = [
            ("🌀 HURRICANE MAKES LANDFALL", "A catastrophic hurricane has struck the coast", 3),
            ("🌎 MAJOR EARTHQUAKE", "A magnitude-7.8 earthquake has levelled a major city", 4),
            ("🦠 PANDEMIC OUTBREAK", "A fast-spreading new pathogen is overwhelming the hospitals", 4),
            ("🔥 WILDFIRES OUT OF CONTROL", "Record wildfires are burning across several states", 3),
            ("🌊 CATASTROPHIC FLOODING", "A hundred-year flood has swamped the river basin", 3),
        ]
        let d = disasters.randomElement()!
        return CrisisEvent(
            type: .naturalDisaster,
            severity: CrisisSeverity(rawValue: d.2) ?? .serious,
            title: d.0,
            description: """
            \(d.1).

            Thousands are displaced and the damage runs into the billions. The nation is watching how its President responds.
            """,
            affectedCountries: [gameState.playerCountryID],
            turn: gameState.turn,
            timeLimit: nil,
            options: [
                CrisisOption(
                    title: "Mobilize a full federal relief effort",
                    description: "National Guard, open the treasury, lead from the front",
                    advisorRecommendation: "Chief of Staff",
                    consequences: CrisisConsequences(approvalChange: 10, economicImpact: -8,
                        message: "The relief effort is swift and visible. The country rallies to its President. (−$8B, +10 approval)")
                ),
                CrisisOption(
                    title: "A measured, state-led response",
                    description: "Let the states lead; keep federal spending modest",
                    consequences: CrisisConsequences(approvalChange: -2, economicImpact: -2,
                        message: "The response is adequate but uninspiring. (−$2B, −2 approval)")
                ),
                CrisisOption(
                    title: "Downplay it and move on",
                    description: "Call it overblown; spend nothing",
                    consequences: CrisisConsequences(approvalChange: -12, economicImpact: 0,
                        message: "The images of suffering run for weeks. The President looks heartless. (−12 approval)")
                ),
            ])
    }

    // MARK: - Crisis Factories

    private func createFalseAlarmCrisis(gameState: GameState) -> CrisisEvent? {
        guard let enemy = gameState.liveCountries.filter({ $0.nuclearWarheads > 0 && !$0.isPlayerControlled }).randomElement() else { return nil }

        return CrisisEvent(
            type: .falseAlarm,
            severity: .critical,
            title: "🚨 FALSE ALARM DETECTED",
            description: """
            NORAD has detected what appears to be \(Int.random(in: 50...500)) \(gameState.deliverySystemProse) launched from \(enemy.name).

            Early warning satellites show multiple launches.
            Ground radar is attempting confirmation.

            Time to impact: 15 minutes

            WARNING: This may be a false alarm. Soviet officer Stanislav Petrov saved the world in 1983 by correctly identifying a false alarm.
            """,
            affectedCountries: [enemy.id],
            turn: gameState.turn,
            timeLimit: 60,
            options: [
                CrisisOption(
                    title: "Launch Immediate Counterstrike",
                    description: "Launch all \(gameState.deliverySystemLabel) before we're destroyed",
                    advisorRecommendation: "Secretary of Defense",
                    consequences: CrisisConsequences(
                        relationshipChanges: [enemy.id: -100],
                        approvalChange: -30,
                        defconChange: 0,
                        triggersWar: true,
                        warTarget: enemy.id,
                        message: "You launched nuclear weapons based on a FALSE ALARM. Millions dead. World condemns your rash action."
                    )
                ),
                CrisisOption(
                    title: "Wait for Confirmation",
                    description: "Wait for ground radar confirmation (Petrov's choice)",
                    advisorRecommendation: "Director of National Intelligence",
                    consequences: CrisisConsequences(
                        approvalChange: 15,
                        message: "Ground radar confirms: FALSE ALARM. You saved the world by remaining calm. +15 approval."
                    ),
                    successChance: 0.85
                ),
                CrisisOption(
                    title: "Alert Allies, Prepare Response",
                    description: "Increase readiness, notify NATO, but don't launch",
                    advisorRecommendation: "Secretary of State",
                    consequences: CrisisConsequences(
                        defconChange: -1,
                        message: "FALSE ALARM confirmed. Allies appreciate measured response."
                    )
                ),
                CrisisOption(
                    title: "Hotline to Enemy Leader",
                    description: "Use Moscow hotline to verify",
                    advisorRecommendation: "Secretary of State",
                    consequences: CrisisConsequences(
                        relationshipChanges: [enemy.id: 10],
                        message: "Hotline confirms no launch. Crisis averted through diplomacy."
                    ),
                    successChance: 0.90
                ),
                CrisisOption(
                    title: "Launch Limited Strike",
                    description: "Strike only military targets, hold reserves",
                    advisorRecommendation: "Secretary of Defense",
                    consequences: CrisisConsequences(
                        relationshipChanges: [enemy.id: -80],
                        approvalChange: -20,
                        triggersWar: true,
                        warTarget: enemy.id,
                        message: "Limited strike on false alarm. Escalation restrained but world horrified. War declared."
                    ),
                    successChance: 0.60
                ),
                CrisisOption(
                    title: "Evacuate Cities, Await Intel",
                    description: "Civil defense activation, wait for more data",
                    advisorRecommendation: "Secretary of Homeland Security",
                    consequences: CrisisConsequences(
                        approvalChange: 5,
                        economicImpact: -1000,
                        message: "FALSE ALARM confirmed. Evacuation costly but citizens appreciate caution."
                    ),
                    successChance: 0.95
                )
            ]
        )
    }

    private func createNuclearAccidentCrisis(gameState: GameState) -> CrisisEvent? {
        guard let country = gameState.liveCountries.filter({ $0.nuclearWarheads > 0 }).randomElement() else { return nil }

        return CrisisEvent(
            type: .nuclearAccident,
            severity: .serious,
            title: "☢️ NUCLEAR REACTOR MELTDOWN",
            description: """
            A nuclear reactor at \(country.name)'s largest power plant is experiencing a critical failure.

            Radiation levels rising rapidly.
            Meltdown imminent in 2 hours.
            Fallout will affect neighboring countries.

            \(country.name) government requesting international assistance.
            """,
            affectedCountries: [country.id],
            turn: gameState.turn,
            timeLimit: nil,
            options: [
                CrisisOption(
                    title: "Provide Emergency Aid",
                    description: "Send nuclear experts and equipment",
                    consequences: CrisisConsequences(
                        relationshipChanges: [country.id: 25],
                        approvalChange: 10,
                        economicImpact: -500,
                        message: "Your aid prevents total meltdown. \(country.name) deeply grateful. +25 relations."
                    ),
                    successChance: 0.75
                ),
                CrisisOption(
                    title: "Offer Humanitarian Support Only",
                    description: "Evacuation assistance, medical aid",
                    consequences: CrisisConsequences(
                        relationshipChanges: [country.id: 10],
                        approvalChange: 5,
                        economicImpact: -100,
                        message: "Limited support provided. Meltdown continues but casualties reduced."
                    )
                ),
                CrisisOption(
                    title: "Remain Neutral",
                    description: "This is their problem, not ours",
                    advisorRecommendation: "Director of National Intelligence",
                    consequences: CrisisConsequences(
                        relationshipChanges: [country.id: -15],
                        message: "Meltdown occurs. International community criticizes your inaction."
                    )
                ),
                CrisisOption(
                    title: "Blame Enemy Sabotage",
                    description: "Claim this was hostile act",
                    advisorRecommendation: "CIA Director",
                    consequences: CrisisConsequences(
                        relationshipChanges: [country.id: -20],
                        approvalChange: -5,
                        message: "Accusation strains relations. No evidence of sabotage found."
                    ),
                    successChance: 0.20
                ),
                CrisisOption(
                    title: "Deploy Military Containment",
                    description: "Send troops to establish quarantine zone",
                    advisorRecommendation: "Secretary of Defense",
                    consequences: CrisisConsequences(
                        relationshipChanges: [country.id: -10],
                        approvalChange: 8,
                        economicImpact: -750,
                        message: "Containment successful. Radiation limited. Military presence resented but effective."
                    ),
                    successChance: 0.80
                ),
                CrisisOption(
                    title: "Demand UN Investigation",
                    description: "Call for international nuclear safety review",
                    advisorRecommendation: "Secretary of State",
                    consequences: CrisisConsequences(
                        approvalChange: 3,
                        message: "UN investigation launched. Meltdown contained. Safety protocols strengthened globally."
                    ),
                    successChance: 0.70
                )
            ]
        )
    }

    private func createTerroristThreatCrisis(gameState: GameState) -> CrisisEvent? {
        guard let target = gameState.liveCountries.filter({ !$0.isPlayerControlled }).randomElement() else { return nil }

        return CrisisEvent(
            type: .terroristThreat,
            severity: .catastrophic,
            title: "💣 NUCLEAR DEVICE STOLEN",
            description: """
            URGENT: Terrorist group has stolen tactical nuclear weapon from \(target.name).

            Yield: 10 kilotons (Hiroshima-size)
            Location: Unknown
            Target: Likely major Western city

            CIA believes they plan to detonate within 48 hours.
            """,
            affectedCountries: [target.id],
            turn: gameState.turn,
            timeLimit: 90,
            options: [
                CrisisOption(
                    title: "Launch Special Forces Operation",
                    description: "SEAL Team 6 assault on suspected location",
                    advisorRecommendation: "Secretary of Defense",
                    consequences: CrisisConsequences(
                        approvalChange: 25,
                        message: "Special forces recover device! Crisis averted. World celebrates."
                    ),
                    successChance: 0.60
                ),
                CrisisOption(
                    title: "Demand \(target.name) Handle It",
                    description: "This is their weapon, their problem",
                    consequences: CrisisConsequences(
                        relationshipChanges: [target.id: -30],
                        approvalChange: -20,
                        message: "\(target.name) fails to recover device. Detonation kills 100,000. Blood on your hands."
                    ),
                    successChance: 0.30
                ),
                CrisisOption(
                    title: "Coordinate International Response",
                    description: "Share intelligence, coordinate with allies",
                    advisorRecommendation: "Secretary of State",
                    consequences: CrisisConsequences(
                        relationshipChanges: [target.id: 15],
                        approvalChange: 15,
                        message: "International cooperation locates and disarms device."
                    ),
                    successChance: 0.70
                ),
                CrisisOption(
                    title: "Launch Cyber Operation",
                    description: "NSA tracks terrorist communications",
                    advisorRecommendation: "CIA Director",
                    consequences: CrisisConsequences(
                        approvalChange: 20,
                        message: "NSA intercepts communications, pinpoints location. Device recovered."
                    ),
                    successChance: 0.65
                ),
                CrisisOption(
                    title: "Offer Ransom Payment",
                    description: "Negotiate $100M payment for device return",
                    advisorRecommendation: "Secretary of Treasury",
                    consequences: CrisisConsequences(
                        approvalChange: -15,
                        economicImpact: -10000,
                        message: "Ransom paid. Device recovered but setting dangerous precedent."
                    ),
                    successChance: 0.85
                ),
                CrisisOption(
                    title: "Evacuate Major Cities",
                    description: "Emergency evacuation, hope they don't detonate",
                    advisorRecommendation: "Secretary of Homeland Security",
                    consequences: CrisisConsequences(
                        approvalChange: -5,
                        economicImpact: -5000,
                        message: "Evacuation chaotic. Device detonates in evacuated area - 10K dead vs 100K if unprepared."
                    ),
                    successChance: 0.50
                )
            ]
        )
    }

    private func createRogueCommanderCrisis(gameState: GameState) -> CrisisEvent? {
        guard let country = gameState.liveCountries.filter({ $0.nuclearWarheads > 10 }).randomElement() else { return nil }
        let warheads = Int.random(in: 5...20)

        return CrisisEvent(
            type: .rogueCommander,
            severity: .catastrophic,
            title: "⚠️ ROGUE NUCLEAR COMMANDER",
            description: """
            \(country.name) colonel has gone rogue with access to \(warheads) nuclear warheads.

            Commander: Unstable, suffering mental breakdown
            Demands: Unclear, making incoherent threats
            Warheads: Under his control at remote silo
            Risk: May launch at any moment

            This is a CRIMSON TIDE scenario.
            """,
            affectedCountries: [country.id],
            turn: gameState.turn,
            timeLimit: 45,
            options: [
                CrisisOption(
                    title: "Neutralize with Military Strike",
                    description: "Destroy silo before he can launch",
                    advisorRecommendation: "Secretary of Defense",
                    consequences: CrisisConsequences(
                        relationshipChanges: [country.id: -40],
                        approvalChange: 10,
                        message: "Strike successful. Warheads destroyed. \(country.name) furious at violation of sovereignty."
                    ),
                    successChance: 0.70
                ),
                CrisisOption(
                    title: "Negotiate with Commander",
                    description: "Talk him down, de-escalate",
                    advisorRecommendation: "Director of National Intelligence",
                    consequences: CrisisConsequences(
                        relationshipChanges: [country.id: 5],
                        approvalChange: 15,
                        message: "Negotiation successful. Commander stands down. No casualties."
                    ),
                    successChance: 0.50
                ),
                CrisisOption(
                    title: "Support \(country.name) Forces",
                    description: "Provide intelligence, let them handle it",
                    advisorRecommendation: "Secretary of State",
                    consequences: CrisisConsequences(
                        relationshipChanges: [country.id: 20],
                        message: "\(country.name) special forces secure silo. Crisis resolved."
                    ),
                    successChance: 0.60
                ),
                CrisisOption(
                    title: "Prepare for Launch",
                    description: "Assume he'll launch, prepare response",
                    consequences: CrisisConsequences(
                        defconChange: -2,
                        message: "Commander launches warhead. Defensive systems intercept. 1 warhead detonates, 50K dead."
                    ),
                    successChance: 0.40
                ),
                CrisisOption(
                    title: "Deploy Psychological Operations",
                    description: "Use psyops to confuse/delay commander",
                    advisorRecommendation: "CIA Director",
                    consequences: CrisisConsequences(
                        approvalChange: 18,
                        message: "Psyops successful. Commander becomes disoriented. \(country.name) forces regain control."
                    ),
                    successChance: 0.65
                ),
                CrisisOption(
                    title: "EMP Strike on Silo",
                    description: "Disable electronics without destroying warheads",
                    advisorRecommendation: "Special Advisor",
                    consequences: CrisisConsequences(
                        relationshipChanges: [country.id: -25],
                        approvalChange: 12,
                        message: "EMP disables launch systems. Warheads secured. \(country.name) protests sovereignty violation."
                    ),
                    successChance: 0.75
                )
            ]
        )
    }

    private func createCyberAttackCrisis(gameState: GameState) -> CrisisEvent? {
        guard let enemy = gameState.liveCountries.filter({ !$0.isPlayerControlled }).randomElement() else { return nil }

        return CrisisEvent(
            type: .cyberAttack,
            severity: .critical,
            title: "💻 CYBER ATTACK ON NUCLEAR COMMAND",
            description: """
            Massive cyber attack detected on nuclear command and control systems.

            Origin: Traced to \(enemy.name)
            Target: Launch authorization systems
            Status: Partial penetration achieved
            Risk: Unauthorized launch possible

            NSA\(gameState.currentYear >= 2010 ? " and Cyber Command" : "") responding.
            """,
            affectedCountries: [enemy.id],
            turn: gameState.turn,
            timeLimit: 60,
            options: [
                CrisisOption(
                    title: "Launch Immediate Counterattack",
                    description: "Cyber warfare against \(enemy.name)",
                    advisorRecommendation: "National Security Advisor",
                    consequences: CrisisConsequences(
                        relationshipChanges: [enemy.id: -30],
                        message: "Counterattack successful. Their systems crippled. They retaliate conventionally."
                    ),
                    successChance: 0.70
                ),
                CrisisOption(
                    title: "Isolate Nuclear Systems",
                    description: "Air-gap critical infrastructure",
                    advisorRecommendation: "Secretary of Homeland Security",
                    consequences: CrisisConsequences(
                        message: "Systems isolated. Attack contained. No damage."
                    ),
                    successChance: 0.85
                ),
                CrisisOption(
                    title: "Public Attribution",
                    description: "Expose \(enemy.name) to world",
                    advisorRecommendation: "Secretary of State",
                    consequences: CrisisConsequences(
                        relationshipChanges: [enemy.id: -20],
                        approvalChange: 10,
                        message: "World condemns \(enemy.name). International sanctions imposed."
                    )
                ),
                CrisisOption(
                    title: "Silent Defense",
                    description: "Repel attack, don't escalate",
                    advisorRecommendation: "Director of National Intelligence",
                    consequences: CrisisConsequences(
                        message: "Attack repelled quietly. No escalation."
                    ),
                    successChance: 0.80
                ),
                CrisisOption(
                    title: "Launch Proportional Cyber Strike",
                    description: "Hit their infrastructure equally hard",
                    advisorRecommendation: "National Security Advisor",
                    consequences: CrisisConsequences(
                        relationshipChanges: [enemy.id: -35],
                        approvalChange: 8,
                        message: "Proportional response. Their power grid down 48 hours. Message sent."
                    ),
                    successChance: 0.75
                ),
                CrisisOption(
                    title: "Activate Cyber Defense Protocol Omega",
                    description: "NSA's most advanced countermeasures",
                    advisorRecommendation: "CIA Director",
                    consequences: CrisisConsequences(
                        approvalChange: 15,
                        economicImpact: -1000,
                        message: "Protocol Omega activated. Attack completely neutralized. Systems hardened."
                    ),
                    successChance: 0.90
                )
            ]
        )
    }

    // Stub implementations for remaining crisis types
    private func createMilitaryCoupCrisis(gameState: GameState) -> CrisisEvent? {
        guard let country = gameState.liveCountries.filter({ $0.nuclearWarheads > 0 && !$0.isPlayerControlled }).randomElement() else { return nil }
        let generalNames = ["General Alexei Volkov", "Colonel Chen Zhao", "General Hassan Al-Sayed", "Marshal Kim Yong-chol", "General Dmitri Petrov"]
        let general = generalNames.randomElement()!
        let units = ["3rd Mechanized Division", "Strategic Rocket Forces", "Republican Guard", "82nd Airborne Brigade", "Naval Infantry Brigade"]
        let unit = units.randomElement()!
        let demands = ["democratic elections", "removal of corrupt officials", "military control", "expulsion of foreign forces", "redistribution of wealth"]
        let demand = demands.randomElement()!

        return CrisisEvent(
            type: .militaryCoup,
            severity: .catastrophic,
            title: "⚔️ MILITARY COUP IN \(country.name.uppercased())",
            description: """
            URGENT: Military coup underway in \(country.name).

            Coup Leader: \(general)
            Forces: \(unit) (\(Int.random(in: 5000...50000)) troops)
            Status: Capital surrounded, president trapped
            Demands: \(demand.capitalized)

            Nuclear Situation:
            • \(country.nuclearWarheads) warheads
            • Launch authority disputed
            • Coup forces control \(Int.random(in: 2...8)) \(gameState.deliverySystemLabel) launch sites
            • Risk of unauthorized launch HIGH

            International Response:
            • UN Security Council emergency session
            • Neighboring countries mobilizing
            • Markets in free-fall
            • Refugees fleeing borders

            \(general) has made no statements. Intentions unclear.
            """,
            affectedCountries: [country.id],
            turn: gameState.turn,
            timeLimit: 90,
            options: [
                CrisisOption(
                    title: "Support Existing Government",
                    description: "Military aid to help president",
                    advisorRecommendation: "Secretary of Defense",
                    consequences: CrisisConsequences(
                        relationshipChanges: [country.id: 20],
                        approvalChange: 10,
                        economicImpact: -2000,
                        message: "Your support tips balance. Coup fails. Government restored. Relations excellent."
                    ),
                    successChance: 0.65
                ),
                CrisisOption(
                    title: "Recognize Coup Government",
                    description: "Pragmatic: work with whoever wins",
                    advisorRecommendation: "Director of National Intelligence",
                    consequences: CrisisConsequences(
                        relationshipChanges: [country.id: 15],
                        approvalChange: -15,
                        message: "Coup succeeds. New regime appreciates early recognition. Domestic criticism severe."
                    ),
                    successChance: 0.80
                ),
                CrisisOption(
                    title: "Negotiate with Both Sides",
                    description: "Mediate power-sharing agreement",
                    advisorRecommendation: "Secretary of State",
                    consequences: CrisisConsequences(
                        relationshipChanges: [country.id: 25],
                        approvalChange: 20,
                        message: "Negotiation successful. Coalition government formed. Civil war averted."
                    ),
                    successChance: 0.55
                ),
                CrisisOption(
                    title: "Secure Nuclear Weapons Only",
                    description: "Special forces seize nuclear sites, ignore politics",
                    advisorRecommendation: "CIA Director",
                    consequences: CrisisConsequences(
                        relationshipChanges: [country.id: -40],
                        approvalChange: 15,
                        message: "Warheads secured. Both sides furious at interference. No nukes launched."
                    ),
                    successChance: 0.75
                ),
                CrisisOption(
                    title: "Economic Sanctions on Coup Leaders",
                    description: "Freeze assets, pressure resignation",
                    advisorRecommendation: "Secretary of Treasury",
                    consequences: CrisisConsequences(
                        approvalChange: 8,
                        message: "Sanctions bite. Coup leaders negotiate. Peaceful transition achieved."
                    ),
                    successChance: 0.60
                ),
                CrisisOption(
                    title: "Wait and Observe",
                    description: "Let internal politics play out",
                    advisorRecommendation: "Director of National Intelligence",
                    consequences: CrisisConsequences(
                        defconChange: -1,
                        message: "Coup succeeds violently. \(Int.random(in: 5000...50000)) dead. New regime anti-Western."
                    ),
                    successChance: 1.0
                )
            ]
        )
    }

    private func createEspionageCrisis(gameState: GameState) -> CrisisEvent? {
        guard let country = gameState.liveCountries.filter({ !$0.isPlayerControlled }).randomElement() else { return nil }
        let agentNames = ["Sarah Chen", "Viktor Sokolov", "Abdul Rahman", "Li Wei", "Maria Volkov", "Hassan Al-Din"]
        let agent = agentNames.randomElement()!
        let y = gameState.currentYear
        let coverJob = EraWords.coverJobs(y).randomElement()!
        let classified = gameState.currentYear < 1945 ? ["war plans", "naval dispositions", "diplomatic cables", "fortification maps"]
            : ["nuclear launch codes", "\(gameState.deliverySystemLabel) deployment plans", "SDI technology", "submarine patrol routes", "CIA NOC list", "NSA encryption keys"]
        let documents = classified.randomElement()!
        let yearsActive = Int.random(in: 2...15)

        return CrisisEvent(
            type: .espionageDiscovered,
            severity: .serious,
            title: "🕵️ MAJOR SPY RING UNCOVERED IN \(country.name.uppercased())",
            description: """
            \(GameState.counterspies(gameState.currentYear)) arrest \(agent), deep-cover \(country.name) spy operating as \(coverJob).

            Spy Details:
            • Real name: \(agent)
            • Cover identity: \(Int.random(in: 3...7)) years established
            • Years active: \(yearsActive)
            • Handler: \(country.name) intelligence officer
            • Documents stolen: \(documents)

            Network Extent:
            • \(Int.random(in: 5...20)) co-conspirators identified
            • Penetration of \(EraWords.agencies(y).randomElement()!)
            • Damage assessment: SEVERE
            • Ongoing investigation

            \(country.name) denies everything. Ambassador recalled.

            This is \(EraWords.worstBreach(y)).
            """,
            affectedCountries: [country.id],
            turn: gameState.turn,
            timeLimit: nil,
            options: [
                CrisisOption(
                    title: "Public Trial and Execution",
                    description: "Make example of \(agent), deter future spies",
                    advisorRecommendation: EraWords.defenseChief(y),
                    consequences: CrisisConsequences(
                        relationshipChanges: [country.id: -40],
                        approvalChange: 15,
                        message: "\(EraWords.publicity(y)). \(agent) executed. \(country.name) retaliates by arresting your citizens."
                    ),
                    successChance: 1.0
                ),
                CrisisOption(
                    title: "Prisoner Exchange Negotiation",
                    description: "Trade \(agent) for your captured agents",
                    advisorRecommendation: "Secretary of State",
                    consequences: CrisisConsequences(
                        relationshipChanges: [country.id: 10],
                        approvalChange: -5,
                        message: "Exchange successful. 3 of your agents returned. Intelligence community furious."
                    ),
                    successChance: 0.85
                ),
                CrisisOption(
                    title: "Turn \(agent) Into Double Agent",
                    description: "Feed false information through spy network",
                    advisorRecommendation: EraWords.spyChief(y),
                    consequences: CrisisConsequences(
                        approvalChange: 20,
                        message: "\(agent) agrees to cooperate. Feed false intel to \(country.name) for 5 turns. Major advantage."
                    ),
                    successChance: 0.70
                ),
                CrisisOption(
                    title: "Massive Counterintelligence Sweep",
                    description: "Dismantle entire \(country.name) spy network",
                    advisorRecommendation: EraWords.spyChief(y),
                    consequences: CrisisConsequences(
                        relationshipChanges: [country.id: -30],
                        approvalChange: 25,
                        message: "Sweep successful. \(Int.random(in: 12...35)) \(country.name) agents arrested. Network destroyed."
                    ),
                    successChance: 0.80
                ),
                CrisisOption(
                    title: "Quiet Deportation",
                    description: "Expel spy quietly, avoid diplomatic incident",
                    advisorRecommendation: EraWords.intelligenceHead(y),
                    consequences: CrisisConsequences(
                        relationshipChanges: [country.id: -5],
                        approvalChange: -10,
                        message: "Quiet resolution. Public angry about weakness. \(country.name) continues spying."
                    ),
                    successChance: 1.0
                )
            ] + (EraWords.cyberAvailable(y) ? [
                CrisisOption(
                    title: "Cyber Retaliation Against \(country.name)",
                    description: "Hack their intelligence services",
                    advisorRecommendation: EraWords.securityAdvisor(y),
                    consequences: CrisisConsequences(
                        relationshipChanges: [country.id: -35],
                        approvalChange: 18,
                        message: "Cyber strike steals their entire spy database. You now know all their agents."
                    ),
                    successChance: 0.75
                )
            ] : [])
        )
    }

    private func createDiplomaticIncidentCrisis(gameState: GameState) -> CrisisEvent? {
        guard let country = gameState.liveCountries.filter({ !$0.isPlayerControlled }).randomElement() else { return nil }
        return createSimpleCrisis(type: .diplomaticIncident, title: "🏛️ Embassy Attack in \(country.name)", country: country, gameState: gameState)
    }

    private func createEconomicCollapseCrisis(gameState: GameState) -> CrisisEvent? {
        guard let country = gameState.liveCountries.filter({ !$0.isPlayerControlled }).randomElement() else { return nil }
        let y = gameState.currentYear
        let debt = y >= 1950 ? "$\(Int.random(in: 50...500))B" : y >= 1900 ? "$\(Int.random(in: 1...20))B" : "$\(Int.random(in: 20...400))M"
        let unemployment = Int.random(in: 25...60)
        return createDetailedCrisis(
            type: .economicCollapse,
            title: "💰 \(country.name) Economic Collapse",
            description: "\(country.name) economy in free-fall. National debt: \(debt). \(y >= 1900 ? "Unemployment: \(unemployment)%." : "Banks failing, mills idle.") Currency worthless. \(Int.random(in: 100...500))K refugees fleeing. Government requesting emergency aid. Risk of state failure.",
            country: country,
            gameState: gameState
        )
    }

    private func createSatelliteFailureCrisis(gameState: GameState) -> CrisisEvent? {
        guard let country = gameState.liveCountries.filter({ $0.nuclearWarheads > 10 }).randomElement() else { return nil }
        let satellites = ["DSP-23", "SBIRS GEO-5", "NRO L-82", "Oko-7"]
        let sat = satellites.randomElement()!
        return createDetailedCrisis(
            type: .satelliteFailure,
            title: "🛰️ \(country.name) Satellite \(sat) Failed",
            description: "\(country.name) early warning satellite \(sat) has failed. Orbit: \(Int.random(in: 500...35000))km. Telemetry lost. \(country.name) blind to missile launches. Early warning time reduced 15min → 5min. Risk of false alarm DRAMATICALLY increased.",
            country: country,
            gameState: gameState
        )
    }

    private func createCivilUnrestCrisis(gameState: GameState) -> CrisisEvent? {
        guard let country = gameState.liveCountries.filter({ !$0.isPlayerControlled }).randomElement() else { return nil }
        let protesters = Int.random(in: 50_000...1_000_000)
        let deaths = Int.random(in: 10...500)
        return createDetailedCrisis(
            type: .civilUnrest,
            title: "🔥 Massive Unrest in \(country.name)",
            description: "Civil unrest in \(country.name) capital. \(protesters.formatted()) protesters demanding reforms. Turned violent. \(deaths) dead, \(deaths * 3) injured. \(gameState.currentYear >= 1945 && country.nuclearWarheads > 0 ? "\(country.name) has \(country.nuclearWarheads) warheads. " : "")Military loyalty uncertain. Risk of coup.",
            country: country,
            gameState: gameState
        )
    }

    private func createWeaponsMalfunctionCrisis(gameState: GameState) -> CrisisEvent? {
        guard let country = gameState.liveCountries.filter({ $0.nuclearWarheads > 5 }).randomElement() else { return nil }
        let weaponType = [gameState.deliverySystemLabel, gameState.slbmLabel, "tactical nuke"].randomElement()!
        let warheads = Int.random(in: 1...5)
        return createDetailedCrisis(
            type: .weaponsMalfunction,
            title: "⚠️ \(country.name) Weapons Malfunction",
            description: "\(country.name) \(weaponType) malfunction. \(warheads) warheads. Launch sequence activated accidentally. Countdown: T-minus \(Int.random(in: 5...15)) minutes. Abort codes not responding. Target: UNKNOWN. Accidental launch imminent. This is BROKEN ARROW.",
            country: country,
            gameState: gameState
        )
    }

    private func createRadiationLeakCrisis(gameState: GameState) -> CrisisEvent? {
        guard let country = gameState.liveCountries.filter({ $0.nuclearWarheads > 0 }).randomElement() else { return nil }
        let facility = ["\(country.name) Nuclear Lab", "Weapons Facility", "Enrichment Plant"].randomElement()!
        let leakAmount = Int.random(in: 100...5000)
        return createDetailedCrisis(
            type: .radiationLeak,
            title: "☢️ Radiation Leak at \(facility)",
            description: "Critical radiation leak at \(facility), \(country.name). \(leakAmount) mSv detected (\(leakAmount > 1000 ? "LETHAL" : "DANGEROUS")). \(Int.random(in: 50...500)) workers exposed. \(Int.random(in: 10_000...500_000).formatted()) population at risk. Containment FAILED. \(country.name) requesting help.",
            country: country,
            gameState: gameState
        )
    }

    private func createSpyRingCrisis(gameState: GameState) -> CrisisEvent? {
        guard let country = gameState.liveCountries.filter({ !$0.isPlayerControlled }).randomElement() else { return nil }
        return createSimpleCrisis(type: .spyRingUncovered, title: "Spy Ring Uncovered", country: country, gameState: gameState)
    }

    private func createAssassinationCrisis(gameState: GameState) -> CrisisEvent? {
        guard let country = gameState.liveCountries.filter({ !$0.isPlayerControlled }).randomElement() else { return nil }
        let y = gameState.currentYear
        // The real head of state on this date when the record has one; otherwise a title of the era.
        let holder = NationModel.leader(for: country, on: gameState.currentDate)
        let leaderTitle = holder.generic ? EraWords.leaderTitles(y).randomElement()! : holder.title
        let leaderName = holder.generic ? "\(country.name)'s \(leaderTitle.lowercased())" : holder.name
        let eventLocation = EraWords.venues(y).randomElement()!
        let attackMethod = EraWords.assassinationMethods(y).randomElement()!

        return CrisisEvent(
            type: .assassinationAttempt,
            severity: .catastrophic,
            title: "🎯 ASSASSINATION ATTEMPT ON \(country.name.uppercased()) LEADER",
            description: """
            BREAKING: Assassination attempt on \(holder.generic ? leaderName : "\(country.name) \(leaderTitle) \(leaderName)").

            Location: \(eventLocation.capitalized)
            Method: \(attackMethod.capitalized)
            Status: Leader wounded, condition critical
            Suspects: Unknown, investigation ongoing

            Intelligence Assessment:
            • \(country.name) security forces in chaos
            • Hardliners demanding retaliation
            • \(y >= 1945 && country.nuclearWarheads > 0 ? "Nuclear command authority unclear" : "Command of the army unclear")
            • Some officers calling for immediate strikes

            \(country.name) requesting international assistance but threatening "consequences" if Western involvement discovered.

            The \(EraWords.spyService(y)) believes this may be an internal power struggle, NOT a foreign attack.
            """,
            affectedCountries: [country.id],
            turn: gameState.turn,
            timeLimit: 75,
            options: [
                CrisisOption(
                    title: "Offer Intelligence Assistance",
                    description: "Share \(EraWords.spyService(y)) findings, help investigation",
                    advisorRecommendation: EraWords.spyChief(y),
                    consequences: CrisisConsequences(
                        relationshipChanges: [country.id: 25],
                        approvalChange: 10,
                        message: "Intelligence sharing identifies conspirators. \(leaderName) survives. \(country.name) grateful."
                    ),
                    successChance: 0.75
                ),
                CrisisOption(
                    title: "Send Medical Team",
                    description: y >= 1900 ? "Emergency trauma surgeons and equipment" : "The best surgeons the Navy can spare",
                    advisorRecommendation: EraWords.healthChief(y),
                    consequences: CrisisConsequences(
                        relationshipChanges: [country.id: 30],
                        approvalChange: 15,
                        economicImpact: -200,
                        message: "Medical team saves \(leaderName)'s life. \(country.name) eternally grateful."
                    ),
                    successChance: 0.80
                ),
                CrisisOption(
                    title: "Exploit the Chaos",
                    description: "Launch covert operation during instability",
                    advisorRecommendation: EraWords.spyChief(y),
                    consequences: CrisisConsequences(
                        relationshipChanges: [country.id: -60],
                        approvalChange: -15,
                        message: "Operation detected. \(country.name) knows you exploited crisis. Relations destroyed."
                    ),
                    successChance: 0.60
                ),
                CrisisOption(
                    title: "Express Condolences, Remain Neutral",
                    description: "Diplomatic statement only, no involvement",
                    advisorRecommendation: "Secretary of State",
                    consequences: CrisisConsequences(
                        relationshipChanges: [country.id: 5],
                        message: "\(leaderName) dies. Hardliners seize power. New regime hostile."
                    ),
                    successChance: 1.0
                ),
                CrisisOption(
                    title: "Blame Rival Nation",
                    description: "Suggest \(gameState.liveCountries.filter { $0.id != country.id && !$0.isPlayerControlled }.randomElement()?.name ?? "enemy") responsible",
                    advisorRecommendation: EraWords.securityAdvisor(y),
                    consequences: CrisisConsequences(
                        approvalChange: -10,
                        message: "Accusation creates diplomatic incident. No proof. Relations worsen across board."
                    ),
                    successChance: 0.30
                ),
                CrisisOption(
                    title: "Deploy Peacekeeping Force",
                    description: "Stabilize situation with military presence",
                    advisorRecommendation: EraWords.defenseChief(y),
                    consequences: CrisisConsequences(
                        relationshipChanges: [country.id: -20],
                        approvalChange: 8,
                        economicImpact: -1500,
                        message: "Peacekeepers prevent civil war. \(country.name) resents occupation but stabilized."
                    ),
                    successChance: 0.70
                )
            ]
        )
    }

    private func createDetailedCrisis(type: CrisisEventType, title: String, description: String, country: Country, gameState: GameState) -> CrisisEvent {
        return CrisisEvent(
            type: type,
            severity: .serious,
            title: title,
            description: description,
            affectedCountries: [country.id],
            turn: gameState.turn,
            timeLimit: nil,
            options: [
                CrisisOption(
                    title: "Military Response",
                    description: "Deploy forces to address situation",
                    advisorRecommendation: EraWords.defenseChief(gameState.currentYear),
                    consequences: CrisisConsequences(
                        relationshipChanges: [country.id: -10],
                        approvalChange: 8,
                        economicImpact: -500,
                        message: "Military intervention successful. \(country.name) resents show of force but crisis resolved."
                    ),
                    successChance: 0.75
                ),
                CrisisOption(
                    title: "Diplomatic Resolution",
                    description: "Negotiate peaceful solution",
                    advisorRecommendation: "Secretary of State",
                    consequences: CrisisConsequences(
                        relationshipChanges: [country.id: 20],
                        approvalChange: 12,
                        message: "Diplomatic solution reached. Crisis averted peacefully. \(country.name) appreciates mediation."
                    ),
                    successChance: 0.65
                ),
                CrisisOption(
                    title: "Economic Aid Package",
                    description: "Provide financial assistance",
                    advisorRecommendation: "Secretary of Treasury",
                    consequences: CrisisConsequences(
                        relationshipChanges: [country.id: 25],
                        approvalChange: 5,
                        economicImpact: -5000,
                        message: "Aid stabilizes situation. \(country.name) grateful. Crisis resolved."
                    ),
                    successChance: 0.80
                ),
                CrisisOption(
                    title: "Covert Operation",
                    description: "\(EraWords.spyService(gameState.currentYear)) handles quietly",
                    advisorRecommendation: EraWords.spyChief(gameState.currentYear),
                    consequences: CrisisConsequences(
                        approvalChange: 15,
                        economicImpact: -200,
                        message: "Covert operation successful. Crisis resolved with no public knowledge."
                    ),
                    successChance: 0.60
                ),
                CrisisOption(
                    title: gameState.currentYear >= 1945 ? "UN/International Coalition" : "Concert of the Powers",
                    description: "Build multilateral response",
                    advisorRecommendation: "Secretary of State",
                    consequences: CrisisConsequences(
                        relationshipChanges: [country.id: 15],
                        approvalChange: 18,
                        economicImpact: -300,
                        message: "Coalition response legitimizes action. Crisis resolved with international support."
                    ),
                    successChance: 0.70
                ),
                CrisisOption(
                    title: "Monitor and Wait",
                    description: "Observe, avoid commitment",
                    advisorRecommendation: "Director of National Intelligence",
                    consequences: CrisisConsequences(
                        relationshipChanges: [country.id: -10],
                        approvalChange: -5,
                        message: "Situation deteriorates without intervention. Crisis worsens."
                    ),
                    successChance: 0.80
                )
            ]
        )
    }

    private func createSimpleCrisis(type: CrisisEventType, title: String, country: Country?, gameState: GameState) -> CrisisEvent {
        let countryName = country?.name ?? "affected nation"
        let countryID = country?.id

        return CrisisEvent(
            type: type,
            severity: .moderate,
            title: title,
            description: "Crisis event: \(title)",
            affectedCountries: country.map { [$0.id] } ?? [],
            turn: gameState.turn,
            timeLimit: nil,
            options: [
                CrisisOption(
                    title: "Military Response",
                    description: "Deploy military forces to address situation",
                    advisorRecommendation: EraWords.defenseChief(gameState.currentYear),
                    consequences: CrisisConsequences(
                        relationshipChanges: countryID.map { [$0: -10] } ?? [:],
                        approvalChange: 5,
                        economicImpact: -500,
                        message: "Military intervention successful. \(countryName) resents show of force but crisis resolved."
                    ),
                    successChance: 0.70
                ),
                CrisisOption(
                    title: "Diplomatic Resolution",
                    description: "Negotiate peaceful solution",
                    advisorRecommendation: "Secretary of State",
                    consequences: CrisisConsequences(
                        relationshipChanges: countryID.map { [$0: 15] } ?? [:],
                        approvalChange: 10,
                        message: "Diplomatic solution reached. Crisis averted peacefully. Relations improved."
                    ),
                    successChance: 0.60
                ),
                CrisisOption(
                    title: "Economic Pressure",
                    description: "Apply sanctions or economic leverage",
                    advisorRecommendation: "Secretary of Treasury",
                    consequences: CrisisConsequences(
                        relationshipChanges: countryID.map { [$0: -20] } ?? [:],
                        approvalChange: 8,
                        message: "Economic pressure forces compliance. Crisis resolved but relations damaged."
                    ),
                    successChance: 0.65
                ),
                CrisisOption(
                    title: "Covert Operation",
                    description: "CIA handles situation quietly",
                    advisorRecommendation: EraWords.spyChief(gameState.currentYear),
                    consequences: CrisisConsequences(
                        approvalChange: 12,
                        economicImpact: -200,
                        message: "Covert operation successful. Crisis resolved with no public knowledge."
                    ),
                    successChance: 0.55
                ),
                CrisisOption(
                    title: "International Coalition",
                    description: "Build UN/NATO consensus for action",
                    advisorRecommendation: "Secretary of State",
                    consequences: CrisisConsequences(
                        approvalChange: 15,
                        economicImpact: -300,
                        message: "Coalition response legitimizes action. Crisis resolved with international support."
                    ),
                    successChance: 0.75
                ),
                CrisisOption(
                    title: "Monitor and Wait",
                    description: "Observe situation, avoid commitment",
                    advisorRecommendation: "Director of National Intelligence",
                    consequences: CrisisConsequences(
                        relationshipChanges: countryID.map { [$0: -5] } ?? [:],
                        approvalChange: -3,
                        message: "Situation deteriorates without intervention. Minimal impact but crisis worsens."
                    ),
                    successChance: 0.80
                )
            ]
        )
    }

    /// Present crisis to player
    func presentCrisis(_ crisis: CrisisEvent) {
        let crisis = currentYear?().map { EraWords.localize(crisis, year: $0) } ?? crisis
        if activeCrisis != nil {
            // Queue it; the oldest waiting decision gives way when the desk is overflowing — but never an election
            // decision (3.21.0): those jump the queue, because the calendar won't wait.
            if crisis.type == .election {
                let at = pendingCrises.firstIndex { $0.type != .election } ?? pendingCrises.endIndex
                pendingCrises.insert(crisis, at: at)
            } else {
                pendingCrises.append(crisis)
            }
            while pendingCrises.count > Self.maxPending {
                guard let drop = pendingCrises.firstIndex(where: { $0.type != .election }) else { break }
                pendingCrises.remove(at: drop)
            }
            return
        }
        activeCrisis = crisis
        if let timeLimit = crisis.timeLimit {
            crisisTimeRemaining = timeLimit
            startTimer()
        }
    }

    /// Resolve crisis with chosen option
    func resolveCrisis(optionIndex: Int, gameState: inout GameState) {
        guard var crisis = activeCrisis, optionIndex >= 0, optionIndex < crisis.options.count else { return }

        let option = crisis.options[optionIndex]

        // Roll for success
        let success = Double.random(in: 0...1) < option.successChance

        if success {
            applyConsequences(option.consequences, to: &gameState)
        } else {
            // Failed attempt has worse consequences
            gameState.totalCasualties += Int.random(in: 1000...10000)
        }

        // Mark crisis as resolved
        crisis.resolved = true
        crisis.chosenOption = optionIndex
        crisisHistory.append(crisis)
        onResolved?(crisis, optionIndex, success)
        activeCrisis = nil
        stopTimer()
        presentNextPending(gameState: gameState)
    }

    /// Bring the next waiting decision to the desk, skipping any the world has already overtaken
    /// (a war that ended, a country that no longer exists).
    func presentNextPending(gameState: GameState) {
        while activeCrisis == nil, !pendingCrises.isEmpty {
            let next = pendingCrises.removeFirst()
            if WorldWatch.stillRelevant(next, in: gameState) { presentCrisis(next) }
        }
    }

    /// Apply consequences to game state
    private func applyConsequences(_ consequences: CrisisConsequences, to gameState: inout GameState) {
        // Apply relationship changes
        for (countryID, change) in consequences.relationshipChanges {
            gameState.modifyRelation(from: gameState.playerCountryID, to: countryID, by: change)
        }

        // Apply DEFCON change
        if consequences.defconChange != 0 {
            let newLevel = max(1, min(5, gameState.defconLevel.rawValue + consequences.defconChange))
            gameState.defconLevel = DefconLevel(rawValue: newLevel) ?? gameState.defconLevel
        }

        // 3.18.14: approval, dollars and military toll — previously declared on CrisisConsequences but never
        // applied, so every crisis's stated approval/economic cost was silently a no-op. Now they land, mapped to
        // the shadow-president model (approval = popularity; economicImpact = $B of spendable funds).
        if consequences.approvalChange != 0 {
            gameState.shadow.popularity = PopularityModel.clamp(gameState.shadow.popularity + Double(consequences.approvalChange))
        }
        if consequences.economicImpact != 0 {
            gameState.shadow.aidRemaining = max(0, gameState.shadow.aidRemaining + Double(consequences.economicImpact))
        }
        if consequences.militaryImpact != 0, let pi = gameState.countries.firstIndex(where: { $0.id == gameState.playerCountryID }) {
            gameState.countries[pi].militaryStrength = max(1, gameState.countries[pi].militaryStrength + consequences.militaryImpact)
        }

        // 3.20.0: effects on other nations.
        for (id, change) in consequences.mutualRelations ?? [:] {
            gameState.modifyRelation(from: gameState.playerCountryID, to: id, by: change)
            gameState.modifyRelation(from: id, to: gameState.playerCountryID, by: change)
        }
        func adjust(_ table: [String: Int]?, _ apply: (inout Country, Int) -> Void) {
            for (id, change) in table ?? [:] {
                if let i = gameState.countries.firstIndex(where: { $0.id == id }) { apply(&gameState.countries[i], change) }
            }
        }
        adjust(consequences.countryStability) { $0.stability = max(1, min(100, $0.stability + $1)) }
        adjust(consequences.countryMilitary) { $0.militaryStrength = max(1, min(100, $0.militaryStrength + $1)) }
        adjust(consequences.countryEconomy) { $0.economicStrength = max(1, min(100, $0.economicStrength + $1)) }
        if let pair = consequences.ceasefireBetween, pair.count == 2 {
            let (a, b) = (pair[0], pair[1])
            if let i = gameState.countries.firstIndex(where: { $0.id == a }) { gameState.countries[i].atWarWith.remove(b) }
            if let i = gameState.countries.firstIndex(where: { $0.id == b }) { gameState.countries[i].atWarWith.remove(a) }
            gameState.activeWars.removeAll { Set([$0.aggressor, $0.defender]) == Set(pair) }
        }
        if let enemy = consequences.joinWarAgainst, enemy != gameState.playerCountryID,
           let pi = gameState.countries.firstIndex(where: { $0.id == gameState.playerCountryID }),
           let ei = gameState.countries.firstIndex(where: { $0.id == enemy }) {
            gameState.countries[pi].atWarWith.insert(enemy)
            gameState.countries[ei].atWarWith.insert(gameState.playerCountryID)
            gameState.activeWars.append(War(aggressor: gameState.playerCountryID, defender: enemy, startTurn: gameState.turn, intensity: 6))
        }

        // 3.21.0: campaign decisions.
        if consequences.campaign != nil || consequences.electionChoice != nil {
            ElectionCycle.apply(consequences, to: gameState)
        }

        // Trigger war if needed
        if consequences.triggersWar, let target = consequences.warTarget {
            let war = War(aggressor: gameState.playerCountryID, defender: target, startTurn: gameState.turn, intensity: 8)
            gameState.activeWars.append(war)
        }
    }

    // MARK: - Timer Management

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.crisisTimeRemaining > 0 {
                self.crisisTimeRemaining -= 1
            } else {
                // Time ran out - force random decision
                self.stopTimer()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        crisisTimeRemaining = 0
    }
}
