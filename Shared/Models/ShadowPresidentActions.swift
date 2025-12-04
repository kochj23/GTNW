//
//  ShadowPresidentActions.swift
//  Global Thermal Nuclear War
//
//  Complete Shadow President (1993) action system
//  Repository: https://github.com/kochj23/GTNW
//  Created by Jordan Koch on 2025-12-03.
//

import Foundation
import SwiftUI

// MARK: - Action Categories

enum ActionCategory: String, CaseIterable {
    case diplomatic = "Diplomatic"
    case military = "Military"
    case economic = "Economic"
    case covert = "Covert Operations"
    case intelligence = "Intelligence"
    case nuclear = "Nuclear"
    case treaties = "Treaties"
    case propaganda = "Propaganda"

    var icon: String {
        switch self {
        case .diplomatic: return "hand.raised.fill"
        case .military: return "shield.fill"
        case .economic: return "dollarsign.circle.fill"
        case .covert: return "eye.slash.fill"
        case .intelligence: return "binoculars.fill"
        case .nuclear: return "flame.fill"
        case .treaties: return "doc.text.fill"
        case .propaganda: return "megaphone.fill"
        }
    }

    var color: Color {
        switch self {
        case .diplomatic: return GTNWColors.terminalGreen
        case .military: return GTNWColors.terminalRed
        case .economic: return GTNWColors.neonCyan
        case .covert: return GTNWColors.neonPurple
        case .intelligence: return GTNWColors.neonBlue
        case .nuclear: return GTNWColors.terminalRed
        case .treaties: return GTNWColors.terminalGreen
        case .propaganda: return GTNWColors.lcarsOrange
        }
    }
}

// MARK: - Presidential Actions (132 total)

enum PresidentialAction: String, CaseIterable, Identifiable {
    var id: String { rawValue }

    // DIPLOMATIC (15)
    case sendAmbassador = "Send Ambassador"
    case recallAmbassador = "Recall Ambassador"
    case stateVisit = "State Visit"
    case summit = "Arrange Summit"
    case mediateConflict = "Mediate Conflict"
    case demandApology = "Demand Apology"
    case issueApology = "Issue Apology"
    case expelDiplomats = "Expel Diplomats"
    case severRelations = "Sever Relations"
    case restoreRelations = "Restore Relations"
    case recognizeGov = "Recognize Government"
    case withdrawRecog = "Withdraw Recognition"
    case offerAsylum = "Offer Asylum"
    case extradite = "Extradite Dissident"
    case jointStatement = "Joint Statement"

    // MILITARY (20)
    case deployTroops = "Deploy Troops"
    case withdrawTroops = "Withdraw Troops"
    case militaryExercise = "Military Exercise"
    case jointExercise = "Joint Exercise"
    case sellWeapons = "Sell Weapons"
    case provideTraining = "Military Training"
    case establishBase = "Establish Base"
    case closeBase = "Close Base"
    case navalBlockade = "Naval Blockade"
    case airPatrol = "Air Patrol"
    case bombardment = "Bombardment"
    case airStrike = "Air Strike"
    case groundInvasion = "Ground Invasion"
    case amphAssault = "Amphibious Assault"
    case specialForces = "Special Forces"
    case peacekeeping = "Peacekeepers"
    case militaryAid = "Military Aid"
    case defensivePact = "Defensive Pact"
    case noFlyZone = "No-Fly Zone"
    case dmz = "DMZ"

    // ECONOMIC (18)
    case economicAid = "Economic Aid"
    case loanMoney = "Loan Money"
    case forgiveDebt = "Forgive Debt"
    case demandRepay = "Demand Repayment"
    case tradeDeal = "Trade Deal"
    case cancelTrade = "Cancel Trade"
    case imposeTariffs = "Impose Tariffs"
    case removeTariffs = "Remove Tariffs"
    case sanctions = "Economic Sanctions"
    case liftSanctions = "Lift Sanctions"
    case freezeAssets = "Freeze Assets"
    case unfreezeAssets = "Unfreeze Assets"
    case oilEmbargo = "Oil Embargo"
    case foodAid = "Food Aid"
    case techAssist = "Tech Assistance"
    case investment = "Investment Package"
    case jointVenture = "Joint Venture"
    case currencyManip = "Currency Manipulation"

    // COVERT (25)
    case infiltrate = "Infiltrate Government"
    case assassinate = "Assassinate Leader"
    case stageCoup = "Stage Coup"
    case supportRebels = "Support Rebels"
    case sabotageInfra = "Sabotage Infrastructure"
    case sabotageNuke = "Sabotage Nuclear"
    case stealTech = "Steal Technology"
    case plantEvidence = "Plant Evidence"
    case blackmail = "Blackmail Official"
    case bribe = "Bribe Officials"
    case fundOpposition = "Fund Opposition"
    case armResistance = "Arm Resistance"
    case trainInsurgents = "Train Insurgents"
    case extractAsset = "Extract Asset"
    case turnAgent = "Turn Agent"
    case poison = "Poison Leader"
    case cyberAttack = "Cyber Attack"
    case hackElection = "Hack Election"
    case disruptComms = "Disrupt Comms"
    case stealSecrets = "Steal Secrets"
    case defectSci = "Defect Scientist"
    case smuggleWeapons = "Smuggle Weapons"
    case blackMarket = "Black Market"
    case drugOps = "Drug Operations"
    case terrorSupport = "Terror Support"

    // INTELLIGENCE (12)
    case deploySpies = "Deploy Spies"
    case recallSpies = "Recall Spies"
    case satellite = "Satellite Recon"
    case sigint = "SIGINT"
    case humint = "HUMINT"
    case imint = "IMINT"
    case counterIntel = "Counter-Intel"
    case doubleAgent = "Double Agent"
    case codeBreak = "Code Breaking"
    case bugEmbassy = "Bug Embassy"
    case trackTroops = "Track Troops"
    case infiltrateSci = "Infiltrate Scientists"

    // NUCLEAR (15)
    case launchNukes = "Launch Nukes"
    case tacticalNuke = "Tactical Nuke"
    case strategicNuke = "Strategic Nuke"
    case preemptive = "Preemptive Strike"
    case retaliate = "Retaliate"
    case nuclearTest = "Nuclear Test"
    case haltNukes = "Halt Program"
    case sellNukeTech = "Sell Nuke Tech"
    case demandInspect = "Demand Inspection"
    case refuseInspect = "Refuse Inspection"
    case deployMissiles = "Deploy Missiles"
    case removeMissiles = "Remove Missiles"
    case nukeSharing = "Nuclear Sharing"
    case firstStrike = "First Strike Policy"
    case noFirstUse = "No First Use"

    // TREATIES (15)
    case proposeTreaty = "Propose Treaty"
    case signTreaty = "Sign Treaty"
    case breakTreaty = "Break Treaty"
    case nonAggression = "Non-Aggression"
    case mutualDefense = "Mutual Defense"
    case freeTrade = "Free Trade"
    case nonProliferation = "Non-Proliferation"
    case armsControl = "Arms Control"
    case ceasefire = "Ceasefire"
    case peace = "Peace Treaty"
    case extradition = "Extradition"
    case joinNATO = "Join Alliance"
    case leaveNATO = "Leave Alliance"
    case neutrality = "Neutrality"
    case hostages = "Release Hostages"

    // PROPAGANDA (12)
    case propaganda = "Propaganda"
    case counterProp = "Counter-Propaganda"
    case mediaBlackout = "Media Blackout"
    case rebelBroadcast = "Rebel Broadcast"
    case cultural = "Cultural Exchange"
    case boycott = "Olympic Boycott"
    case unCondemn = "UN Condemnation"
    case pressConf = "Press Conference"
    case leakIntel = "Leak Intel"
    case disinfo = "Disinformation"
    case radioFree = "Radio Free"
    case ideological = "Ideological War"

    var category: ActionCategory {
        let name = String(describing: self)
        
        // Diplomatic
        if ["sendAmbassador", "recallAmbassador", "stateVisit", "summit", "mediateConflict",
            "demandApology", "issueApology", "expelDiplomats", "severRelations", "restoreRelations",
            "recognizeGov", "withdrawRecog", "offerAsylum", "extradite", "jointStatement"].contains(name) {
            return .diplomatic
        }
        
        // Military
        if ["deployTroops", "withdrawTroops", "militaryExercise", "jointExercise", "sellWeapons",
            "provideTraining", "establishBase", "closeBase", "navalBlockade", "airPatrol",
            "bombardment", "airStrike", "groundInvasion", "amphAssault", "specialForces",
            "peacekeeping", "militaryAid", "defensivePact", "noFlyZone", "dmz"].contains(name) {
            return .military
        }
        
        // Economic
        if ["economicAid", "loanMoney", "forgiveDebt", "demandRepay", "tradeDeal",
            "cancelTrade", "imposeTariffs", "removeTariffs", "sanctions", "liftSanctions",
            "freezeAssets", "unfreezeAssets", "oilEmbargo", "foodAid", "techAssist",
            "investment", "jointVenture", "currencyManip"].contains(name) {
            return .economic
        }
        
        // Covert
        if ["infiltrate", "assassinate", "stageCoup", "supportRebels", "sabotageInfra",
            "sabotageNuke", "stealTech", "plantEvidence", "blackmail", "bribe",
            "fundOpposition", "armResistance", "trainInsurgents", "extractAsset", "turnAgent",
            "poison", "cyberAttack", "hackElection", "disruptComms", "stealSecrets",
            "defectSci", "smuggleWeapons", "blackMarket", "drugOps", "terrorSupport"].contains(name) {
            return .covert
        }
        
        // Intelligence
        if ["deploySpies", "recallSpies", "satellite", "sigint", "humint", "imint",
            "counterIntel", "doubleAgent", "codeBreak", "bugEmbassy", "trackTroops", "infiltrateSci"].contains(name) {
            return .intelligence
        }
        
        // Nuclear
        if ["launchNukes", "tacticalNuke", "strategicNuke", "preemptive", "retaliate",
            "nuclearTest", "haltNukes", "sellNukeTech", "demandInspect", "refuseInspect",
            "deployMissiles", "removeMissiles", "nukeSharing", "firstStrike", "noFirstUse"].contains(name) {
            return .nuclear
        }
        
        // Treaties
        if ["proposeTreaty", "signTreaty", "breakTreaty", "nonAggression", "mutualDefense",
            "freeTrade", "nonProliferation", "armsControl", "ceasefire", "peace",
            "extradition", "joinNATO", "leaveNATO", "neutrality", "hostages"].contains(name) {
            return .treaties
        }
        
        // Propaganda
        return .propaganda
    }

    var description: String {
        switch self {
        case .sendAmbassador: return "Establish diplomatic presence (+10 relations)"
        case .stateVisit: return "Official visit (+20 relations, +5 approval)"
        case .expelDiplomats: return "Expel diplomatic staff (-30 relations)"
        case .issueApology: return "Formal apology (+30 relations)"
        case .sellWeapons: return "Arms deal ($1B, +15 relations)"
        case .deployTroops: return "Move forces to border (-15 relations, threat)"
        case .navalBlockade: return "Block shipping (-60 relations, WAR)"
        case .airStrike: return "Precision bombing (-70 relations, WAR)"
        case .groundInvasion: return "Full invasion (-100 relations, WAR)"
        case .economicAid: return "Grant $5B (+25 relations)"
        case .sanctions: return "Economic sanctions (-40 relations)"
        case .freezeAssets: return "Freeze foreign assets (-35 relations)"
        case .forgiveDebt: return "Cancel debt (+40 relations)"
        case .infiltrate: return "Plant spies (60% success)"
        case .assassinate: return "Kill leader (40% success, CATASTROPHIC)"
        case .stageCoup: return "Overthrow government (50% success)"
        case .cyberAttack: return "Hack systems (70% success)"
        case .sabotageNuke: return "Sabotage nuclear (65% success)"
        case .deploySpies: return "Establish spy network"
        case .satellite: return "Overhead reconnaissance"
        case .counterIntel: return "Root out enemy spies"
        case .launchNukes: return "Launch nuclear weapons (MAD)"
        case .nuclearTest: return "Test device (-30 relations)"
        case .noFirstUse: return "Pledge no first use (+20 relations)"
        case .nonAggression: return "Non-aggression pact (+30 relations)"
        case .mutualDefense: return "Defense pact (+40 relations)"
        case .ceasefire: return "Halt hostilities"
        case .peace: return "End war (+50 relations)"
        case .propaganda: return "Media campaign (-20 relations)"
        case .unCondemn: return "UN condemnation (-25 relations)"
        default: return rawValue
        }
    }

    var cost: Int {
        switch self {
        case .economicAid: return 5_000_000_000
        case .loanMoney: return 10_000_000_000
        case .investment: return 20_000_000_000
        case .sellWeapons, .militaryAid: return 1_000_000_000
        case .assassinate, .stageCoup: return 100_000_000
        case .supportRebels, .armResistance: return 500_000_000
        case .deploySpies: return 50_000_000
        case .satellite: return 200_000_000
        case .nuclearTest: return 500_000_000
        case .propaganda, .disinfo: return 100_000_000
        default: return 0
        }
    }

    var successChance: Double {
        switch self {
        case .assassinate: return 0.40
        case .stageCoup, .turnAgent: return 0.50
        case .hackElection: return 0.55
        case .infiltrate, .stealSecrets: return 0.60
        case .sabotageNuke, .defectSci: return 0.65
        case .cyberAttack: return 0.70
        default: return 1.0
        }
    }

    var riskLevel: RiskLevel {
        switch self {
        case .assassinate, .stageCoup, .launchNukes, .preemptive, .poison, .terrorSupport:
            return .catastrophic
        case .sabotageNuke, .hackElection, .navalBlockade, .groundInvasion, .sanctions, .freezeAssets:
            return .high
        case .supportRebels, .cyberAttack, .deployTroops, .expelDiplomats, .nuclearTest, .severRelations:
            return .medium
        default:
            return .low
        }
    }
}

enum RiskLevel: String {
    case low = "Low Risk"
    case medium = "Medium Risk"
    case high = "High Risk"
    case catastrophic = "Catastrophic"

    var color: Color {
        switch self {
        case .low: return GTNWColors.terminalGreen
        case .medium: return GTNWColors.terminalAmber
        case .high: return .orange
        case .catastrophic: return GTNWColors.terminalRed
        }
    }
}

// MARK: - Action Result

struct ActionResult {
    var success: Bool
    var message: String
    var relationChange: Int
    var approvalChange: Int
    var economicImpact: Int
    var triggeredWar: Bool
    var triggeredCrisis: Bool
    var detectedProbability: Double
}

// MARK: - Action Manager

class ShadowPresidentActionManager {
    static func execute(
        action: PresidentialAction,
        from playerID: String,
        to targetID: String,
        gameState: inout GameState
    ) -> ActionResult {
        let success = Double.random(in: 0...1) < action.successChance

        guard success else {
            return ActionResult(
                success: false,
                message: "Operation failed!",
                relationChange: -50,
                approvalChange: -20,
                economicImpact: -action.cost,
                triggeredWar: action.riskLevel == .catastrophic,
                triggeredCrisis: true,
                detectedProbability: 0.9
            )
        }

        return executeAction(action, from: playerID, to: targetID, gameState: &gameState)
    }

    private static func executeAction(
        _ action: PresidentialAction,
        from playerID: String,
        to targetID: String,
        gameState: inout GameState
    ) -> ActionResult {
        var result = ActionResult(
            success: true,
            message: action.description,
            relationChange: 0,
            approvalChange: 0,
            economicImpact: -action.cost,
            triggeredWar: false,
            triggeredCrisis: false,
            detectedProbability: 0.0
        )

        switch action {
        case .sendAmbassador: result.relationChange = 10
        case .stateVisit: result.relationChange = 20; result.approvalChange = 5
        case .expelDiplomats: result.relationChange = -30
        case .issueApology: result.relationChange = 30
        case .severRelations: result.relationChange = -50
        
        case .deployTroops: result.relationChange = -15; result.triggeredCrisis = true
        case .sellWeapons: result.relationChange = 15; result.economicImpact = 1_000_000_000
        case .navalBlockade: result.relationChange = -60; result.triggeredWar = true
        case .airStrike: result.relationChange = -70; result.triggeredWar = true
        case .groundInvasion: result.relationChange = -100; result.triggeredWar = true
        
        case .economicAid: result.relationChange = 25; result.approvalChange = 5
        case .sanctions: result.relationChange = -40
        case .freezeAssets: result.relationChange = -35
        case .forgiveDebt: result.relationChange = 40
        
        case .infiltrate: result.detectedProbability = 0.30
        case .assassinate: result.detectedProbability = 0.60; result.triggeredWar = true
        case .stageCoup: result.detectedProbability = 0.70; result.triggeredCrisis = true
        case .cyberAttack: result.relationChange = -25; result.detectedProbability = 0.40
        case .sabotageNuke: result.detectedProbability = 0.50; result.triggeredWar = true
        
        case .deploySpies: result.message = "Spy network deployed"
        case .satellite: result.message = "Satellite surveillance active"
        case .counterIntel: result.message = "Counter-intel sweep complete"
        
        case .nuclearTest: result.relationChange = -30; result.approvalChange = -15
        case .noFirstUse: result.relationChange = 20; result.approvalChange = 10
        
        case .nonAggression: result.relationChange = 30
        case .mutualDefense: result.relationChange = 40
        case .peace: result.relationChange = 50
        
        case .propaganda: result.relationChange = -20
        case .unCondemn: result.relationChange = -25; result.approvalChange = 5
        
        default: break
        }

        return result
    }

    static func getAvailableActions(
        player: Country,
        target: Country,
        gameState: GameState
    ) -> [PresidentialAction] {
        var actions = PresidentialAction.allCases
        
        // Filter based on context
        if player.atWarWith.contains(target.id) {
            // At war - show war-related actions
            actions = actions.filter {
                [.ceasefire, .peace, .airStrike, .groundInvasion, .bombardment].contains($0) ||
                $0.category == .military || $0.category == .covert
            }
        }
        
        return actions
    }
}
