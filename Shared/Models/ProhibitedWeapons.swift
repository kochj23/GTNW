//
//  ProhibitedWeapons.swift
//  Global Thermal Nuclear War
//
//  Weapons programs halted by SALT I (1972) and SALT II (1979) treaties
//  Based on actual historical arms control agreements
//

import Foundation

/// Weapons programs prohibited or limited by SALT treaties
enum SALTProhibitedWeapon: String, Codable, CaseIterable {
    case antiBallisticMissiles = "Anti-Ballistic Missile Systems"
    case multipleReentryVehicles = "Multiple Independently Targetable Reentry Vehicles (MIRV)"
    case heavyICBM = "Heavy ICBMs (SS-18 Satan class)"
    case mobileLaunchers = "Mobile ICBM Launchers"
    case submarineLaunchedCruiseMissiles = "Nuclear-Armed Sea-Launched Cruise Missiles"
    case bomberConversions = "Strategic Bomber Conversions"
    case fractionalOrbitBombardment = "Fractional Orbital Bombardment System (FOBS)"
    case neutronBombs = "Enhanced Radiation Weapons (Neutron Bombs)"
    case antisatelliteWeapons = "Anti-Satellite Weapons (ASAT)"
    case groundLaunchedCruiseMissiles = "Ground-Launched Cruise Missiles (GLCM) >600km"

    var description: String {
        switch self {
        case .antiBallisticMissiles:
            return "ABM systems limited to 100 interceptors per side (SALT I, 1972)"
        case .multipleReentryVehicles:
            return "MIRVs limited to specific platforms (SALT II, 1979)"
        case .heavyICBM:
            return "Heavy ICBMs like SS-18 limited to 308 launchers (SALT II)"
        case .mobileLaunchers:
            return "Mobile ICBMs prohibited to ensure verification (SALT II)"
        case .submarineLaunchedCruiseMissiles:
            return "SLCMs with range >600km prohibited (SALT II)"
        case .bomberConversions:
            return "Limited conversion of bombers to cruise missile carriers (SALT II)"
        case .fractionalOrbitBombardment:
            return "Orbital nuclear weapons prohibited (Outer Space Treaty 1967)"
        case .neutronBombs:
            return "Enhanced radiation warheads (tactical neutron bombs)"
        case .antisatelliteWeapons:
            return "Kinetic kill vehicles and directed-energy ASAT systems"
        case .groundLaunchedCruiseMissiles:
            return "Ground-based cruise missiles >600km range (INF Treaty 1987)"
        }
    }

    var historicalContext: String {
        switch self {
        case .antiBallisticMissiles:
            return "ABM Treaty (1972) limited defensive systems to preserve MAD. Reagan's SDI (1983) challenged this framework."
        case .multipleReentryVehicles:
            return "MIRVs multiplied warhead count per missile. Minuteman III: 3 warheads, MX Peacekeeper: 10 warheads."
        case .heavyICBM:
            return "SS-18 Satan: 10 MIRVs, 750kt each. Most powerful ICBM ever deployed. USSR had 308 silos."
        case .mobileLaunchers:
            return "Rail-mobile SS-24 Scalpel and road-mobile SS-25 Sickle made verification impossible."
        case .submarineLaunchedCruiseMissiles:
            return "Nuclear Tomahawk SLCM: 1,350 nautical mile range, W80 warhead (5-150kt yield)."
        case .bomberConversions:
            return "B-52G converted to carry 20x AGM-86B ALCMs with W80 warheads (200kt)."
        case .fractionalOrbitBombardment:
            return "Soviet FOBS could attack from any direction, including over South Pole, avoiding early warning."
        case .neutronBombs:
            return "W70-3 warhead: 1kt yield but intense neutron radiation. Kills tank crews, minimal blast."
        case .antisatelliteWeapons:
            return "F-15 launched ASM-135 ASAT (1985). Soviet co-orbital ASAT operational 1970s."
        case .groundLaunchedCruiseMissiles:
            return "BGM-109G Gryphon: 2,500km range, W84 warhead (0.2-150kt). Deployed to Europe 1983-1987."
        }
    }

    var developmentCost: Int {
        // Research and deployment cost in dollars
        switch self {
        case .antiBallisticMissiles: return 50_000_000_000 // $50B (Safeguard ABM)
        case .multipleReentryVehicles: return 20_000_000_000 // $20B (MIRV tech)
        case .heavyICBM: return 30_000_000_000 // $30B (MX Peacekeeper program)
        case .mobileLaunchers: return 40_000_000_000 // $40B (Midgetman program)
        case .submarineLaunchedCruiseMissiles: return 15_000_000_000 // $15B
        case .bomberConversions: return 10_000_000_000 // $10B
        case .fractionalOrbitBombardment: return 25_000_000_000 // $25B
        case .neutronBombs: return 8_000_000_000 // $8B
        case .antisatelliteWeapons: return 12_000_000_000 // $12B (ASM-135)
        case .groundLaunchedCruiseMissiles: return 18_000_000_000 // $18B (Pershing II/GLCM)
        }
    }

    var developmentTime: Int {
        // Number of turns to complete
        switch self {
        case .antiBallisticMissiles: return 8
        case .multipleReentryVehicles: return 6
        case .heavyICBM: return 7
        case .mobileLaunchers: return 6
        case .submarineLaunchedCruiseMissiles: return 5
        case .bomberConversions: return 4
        case .fractionalOrbitBombardment: return 7
        case .neutronBombs: return 5
        case .antisatelliteWeapons: return 6
        case .groundLaunchedCruiseMissiles: return 5
        }
    }

    var militaryBenefit: WeaponBenefit {
        switch self {
        case .antiBallisticMissiles:
            return WeaponBenefit(
                nuclearWarheads: 0,
                interceptors: 100,
                firstStrike: false,
                secondStrike: true,
                description: "+100 ABM interceptors, 30% interception rate"
            )
        case .multipleReentryVehicles:
            return WeaponBenefit(
                nuclearWarheads: 500,
                interceptors: 0,
                firstStrike: true,
                secondStrike: true,
                description: "+500 warheads via MIRV upgrades, +30 first strike capability"
            )
        case .heavyICBM:
            return WeaponBenefit(
                nuclearWarheads: 300,
                interceptors: 0,
                firstStrike: true,
                secondStrike: true,
                description: "+300 heavy warheads (10 MIRVs each), +40 first strike"
            )
        case .mobileLaunchers:
            return WeaponBenefit(
                nuclearWarheads: 200,
                interceptors: 0,
                firstStrike: false,
                secondStrike: true,
                description: "+200 mobile warheads, +50% second strike survivability"
            )
        case .submarineLaunchedCruiseMissiles:
            return WeaponBenefit(
                nuclearWarheads: 150,
                interceptors: 0,
                firstStrike: false,
                secondStrike: true,
                description: "+150 SLCM warheads, stealthy delivery"
            )
        case .bomberConversions:
            return WeaponBenefit(
                nuclearWarheads: 200,
                interceptors: 0,
                firstStrike: false,
                secondStrike: false,
                description: "+200 cruise missiles on converted bombers"
            )
        case .fractionalOrbitBombardment:
            return WeaponBenefit(
                nuclearWarheads: 50,
                interceptors: 0,
                firstStrike: true,
                secondStrike: false,
                description: "+50 orbital warheads, surprise attack capability"
            )
        case .neutronBombs:
            return WeaponBenefit(
                nuclearWarheads: 100,
                interceptors: 0,
                firstStrike: false,
                secondStrike: false,
                description: "+100 enhanced radiation warheads, anti-armor"
            )
        case .antisatelliteWeapons:
            return WeaponBenefit(
                nuclearWarheads: 0,
                interceptors: 0,
                firstStrike: false,
                secondStrike: false,
                description: "Can destroy enemy satellites, blind early warning"
            )
        case .groundLaunchedCruiseMissiles:
            return WeaponBenefit(
                nuclearWarheads: 200,
                interceptors: 0,
                firstStrike: true,
                secondStrike: false,
                description: "+200 GLCM warheads, 2,500km range"
            )
        }
    }

    var diplomaticConsequences: DiplomaticImpact {
        switch self {
        case .antiBallisticMissiles:
            return DiplomaticImpact(
                relationsPenalty: -20,
                treatyViolation: true,
                defconIncrease: true,
                message: "ABM Treaty violation triggers diplomatic crisis"
            )
        case .multipleReentryVehicles, .heavyICBM, .mobileLaunchers:
            return DiplomaticImpact(
                relationsPenalty: -30,
                treatyViolation: true,
                defconIncrease: true,
                message: "SALT II violation destabilizes strategic balance"
            )
        case .submarineLaunchedCruiseMissiles, .bomberConversions, .groundLaunchedCruiseMissiles:
            return DiplomaticImpact(
                relationsPenalty: -25,
                treatyViolation: true,
                defconIncrease: true,
                message: "Cruise missile deployment violates arms control agreements"
            )
        case .fractionalOrbitBombardment:
            return DiplomaticImpact(
                relationsPenalty: -40,
                treatyViolation: true,
                defconIncrease: true,
                message: "Orbital weapons violate Outer Space Treaty (1967)"
            )
        case .neutronBombs:
            return DiplomaticImpact(
                relationsPenalty: -15,
                treatyViolation: false,
                defconIncrease: false,
                message: "Neutron bomb deployment causes international outcry"
            )
        case .antisatelliteWeapons:
            return DiplomaticImpact(
                relationsPenalty: -20,
                treatyViolation: false,
                defconIncrease: true,
                message: "ASAT deployment threatens space-based assets"
            )
        }
    }
}

/// Benefits gained from deploying prohibited weapons
struct WeaponBenefit {
    let nuclearWarheads: Int
    let interceptors: Int
    let firstStrike: Bool // Improves first strike capability
    let secondStrike: Bool // Improves second strike survivability
    let description: String
}

/// Diplomatic consequences of treaty violations
struct DiplomaticImpact {
    let relationsPenalty: Int // Relations loss with all nuclear powers
    let treatyViolation: Bool // Is this a treaty violation?
    let defconIncrease: Bool // Does this raise DEFCON?
    let message: String // Diplomatic fallout message
}

/// Active weapons development program
struct WeaponsDevelopmentProgram: Identifiable, Codable {
    let id: UUID
    let countryID: String
    let weapon: SALTProhibitedWeapon
    let startTurn: Int
    var completionTurn: Int
    var isCompleted: Bool
    var wasDetected: Bool
    var detectedOnTurn: Int?

    init(countryID: String, weapon: SALTProhibitedWeapon, startTurn: Int) {
        self.id = UUID()
        self.countryID = countryID
        self.weapon = weapon
        self.startTurn = startTurn
        self.completionTurn = startTurn + weapon.developmentTime
        self.isCompleted = false
        self.wasDetected = false
        self.detectedOnTurn = nil
    }
}

/// Detection chance for secret weapons programs
enum WeaponsIntelligence {
    /// Calculate detection chance per turn
    static func detectionChance(for weapon: SALTProhibitedWeapon, targetIntelligence: Int, turn: Int, startTurn: Int) -> Int {
        // Base detection by weapon type
        let baseDetection: Int = {
            switch weapon {
            case .antiBallisticMissiles, .mobileLaunchers, .fractionalOrbitBombardment:
                return 15 // Hard to hide
            case .heavyICBM, .groundLaunchedCruiseMissiles:
                return 10 // Moderate visibility
            case .multipleReentryVehicles, .submarineLaunchedCruiseMissiles, .bomberConversions:
                return 5 // Easier to hide
            case .neutronBombs, .antisatelliteWeapons:
                return 8 // Secret programs
            }
        }()

        // Intelligence bonus
        let intelBonus = targetIntelligence / 10

        // Time increases detection risk (+2% per turn)
        let timeBonus = (turn - startTurn) * 2

        return min(80, baseDetection + intelBonus + timeBonus)
    }
}
