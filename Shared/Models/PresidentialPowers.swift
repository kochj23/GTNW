//
//  PresidentialPowers.swift
//  GTNW
//
//  Cabinet firings, executive orders, pardons, and presidential addresses.
//  Created by Jordan Koch on 2026-03-05
//

import Foundation
import SwiftUI

// MARK: - Supporting Types

enum ExecutiveOrderType: String, CaseIterable, Identifiable {
    var id: String { rawValue }

    // Domestic
    case emergencyPowers     = "National Emergency Declaration"
    case domesticEconomy     = "Economic Stimulus Order"
    case civilRights         = "Civil Rights Executive Order"
    case immigrationPolicy   = "Immigration & Border Order"
    case energyPolicy        = "Energy & Environment Order"

    // Foreign / Military
    case foreignPolicy       = "Foreign Policy Directive"
    case defenseReadiness    = "Defense Readiness Order"
    case tradePolicy         = "Trade & Tariff Order"
    case sanctionsBypass     = "Emergency Sanctions Order"
    case deployReserves      = "National Guard Deployment"

    var icon: String {
        switch self {
        case .emergencyPowers:   return "exclamationmark.shield"
        case .domesticEconomy:   return "dollarsign.circle"
        case .civilRights:       return "person.badge.shield.checkmark"
        case .immigrationPolicy: return "person.crop.rectangle.badge.plus"
        case .energyPolicy:      return "bolt.fill"
        case .foreignPolicy:     return "globe.americas"
        case .defenseReadiness:  return "shield.lefthalf.filled"
        case .tradePolicy:       return "arrow.left.arrow.right"
        case .sanctionsBypass:   return "xmark.circle.fill"
        case .deployReserves:    return "figure.stand.line.dotted.figure.stand"
        }
    }

    var approvalImpact: Int {
        switch self {
        case .emergencyPowers:   return -5     // Controversial
        case .domesticEconomy:   return +8     // Popular
        case .civilRights:       return +10    // Very popular
        case .immigrationPolicy: return -3     // Divisive
        case .energyPolicy:      return +4
        case .foreignPolicy:     return +2
        case .defenseReadiness:  return -2
        case .tradePolicy:       return +3
        case .sanctionsBypass:   return +5     // Looks decisive
        case .deployReserves:    return -4     // Militaristic
        }
    }

    var description: String {
        switch self {
        case .emergencyPowers:
            return "Declare a national emergency, unlocking extra executive authority. Raises DEFCON by 1. +10 military strength for 3 turns."
        case .domesticEconomy:
            return "Bypass Congress to direct economic stimulus. +15% GDP next turn. +8 public approval."
        case .civilRights:
            return "Issue sweeping civil rights protections. +10 public approval. +15 relations with all democratic allies."
        case .immigrationPolicy:
            return "Restrict or expand immigration via executive action. +5 stability. Divisive: -3 approval."
        case .energyPolicy:
            return "Set energy policy by fiat. +5 economic strength. Affects trade relations with oil-producing states."
        case .foreignPolicy:
            return "Issue a formal foreign policy doctrine. +10 relations with chosen ally bloc. Warns adversaries."
        case .defenseReadiness:
            return "Order military to elevated readiness. +10 military strength. Costs treasury. May alarm neighbors."
        case .tradePolicy:
            return "Impose or remove tariffs by executive order. +5 GDP long-term. Some partners retaliate."
        case .sanctionsBypass:
            return "Emergency sanctions on a target without Congressional approval. -20 target relations. Fast & decisive."
        case .deployReserves:
            return "Activate National Guard domestically. +10 stability. Useful during civil unrest or disasters."
        }
    }

    /// Returns true if this order type requires a target country to be selected.
    var requiresTarget: Bool {
        switch self {
        case .foreignPolicy, .sanctionsBypass, .tradePolicy: return true
        default: return false
        }
    }
}

enum PardonType: String, CaseIterable, Identifiable {
    var id: String { rawValue }

    case politicalRival    = "Political Rival"
    case diplomaticGesture = "Foreign National (Diplomatic)"
    case whistleblower     = "Whistleblower / Dissident"
    case warCriminal       = "Pardoned War Criminal"
    case posthumous        = "Posthumous / Historical"
    case massPardon        = "Mass Pardon (draft, minor crimes)"

    var icon: String {
        switch self {
        case .politicalRival:    return "person.fill.checkmark"
        case .diplomaticGesture: return "flag.2.crossed.fill"
        case .whistleblower:     return "eye.slash.fill"
        case .warCriminal:       return "shield.slash"
        case .posthumous:        return "clock.arrow.circlepath"
        case .massPardon:        return "person.3.fill"
        }
    }

    var approvalImpact: Int {
        switch self {
        case .politicalRival:    return -8   // Looks self-serving
        case .diplomaticGesture: return +5   // Diplomatic goodwill
        case .whistleblower:     return +12  // Very popular
        case .warCriminal:       return -20  // Very unpopular
        case .posthumous:        return +15  // Usually popular
        case .massPardon:        return +10  // Popular
        }
    }

    var description: String {
        switch self {
        case .politicalRival:
            return "Pardon a political opponent. Seen as magnanimous or self-interested. -8 approval. +10 domestic stability."
        case .diplomaticGesture:
            return "Pardon a foreign national to improve bilateral relations. +20 relations with their country. +5 approval."
        case .whistleblower:
            return "Pardon someone who exposed government wrongdoing. +12 approval with civil liberties groups. -10 with intelligence agencies."
        case .warCriminal:
            return "Pardon convicted war criminals. -20 approval. -15 relations with affected countries. Very controversial."
        case .posthumous:
            return "Pardon historical figures posthumously. +15 approval with historians and civil rights groups. No downside."
        case .massPardon:
            return "Pardon large groups (draft evaders, minor offenses). +10 approval. Shows mercy."
        }
    }
}

enum AddressType: String, CaseIterable, Identifiable {
    var id: String { rawValue }

    case stateOfUnion  = "State of the Union"
    case ovalOffice    = "Oval Office Crisis Address"
    case foreignPolicy = "Foreign Policy Speech"
    case warAddress    = "Address to Armed Forces"
    case peaceInitiative = "Peace Initiative Speech"
    case warningAddress  = "Warning to Adversary"

    var icon: String {
        switch self {
        case .stateOfUnion:     return "building.columns.fill"
        case .ovalOffice:       return "moon.stars.fill"
        case .foreignPolicy:    return "globe.americas.fill"
        case .warAddress:       return "shield.fill"
        case .peaceInitiative:  return "dove.fill"
        case .warningAddress:   return "exclamationmark.triangle.fill"
        }
    }

    var cooldownTurns: Int {
        switch self {
        case .stateOfUnion:   return 8   // Once per year
        default:              return 2   // Can give more frequently
        }
    }

    var approvalImpact: Int {
        switch self {
        case .stateOfUnion:     return +12
        case .ovalOffice:       return +8
        case .foreignPolicy:    return +5
        case .warAddress:       return +7
        case .peaceInitiative:  return +15
        case .warningAddress:   return +3
        }
    }

    var description: String {
        switch self {
        case .stateOfUnion:
            return "Annual address to Congress and the nation. +12 approval. +10 congressional support. Announce legislative priorities."
        case .ovalOffice:
            return "Emergency address from the Oval Office during crisis. +8 approval. Reassures allies. Can explain military action."
        case .foreignPolicy:
            return "Major foreign policy speech (like Nixon to China, Reagan's 'Evil Empire'). +5 approval. +10 relations with named allies. Warns adversaries."
        case .warAddress:
            return "Address to military personnel. Boosts troop morale. +7 approval. +10 military effectiveness this turn."
        case .peaceInitiative:
            return "Announce a peace initiative. +15 approval. +15 relations with all countries. May reduce DEFCON. Signals de-escalation."
        case .warningAddress:
            return "Direct public warning to an adversary ('fire and fury'). +3 approval. -20 relations with target. Raises DEFCON by 1."
        }
    }
}

// MARK: - GameEngine Extensions

extension GameEngine {

    // MARK: - 1. Cabinet Firing

    /// Fire an advisor from the cabinet. Cannot fire the President.
    func fireAdvisor(advisorID: String) {
        guard let gameState = gameState else { return }

        guard let idx = gameState.advisors.firstIndex(where: { $0.id == advisorID }),
              !gameState.advisors[idx].title.contains("President") else {
            addLog("Cannot remove the President from their own cabinet.", type: .info)
            return
        }

        let fired = gameState.advisors[idx]
        gameState.advisors.remove(at: idx)

        // Remaining advisors become less loyal — unpredictability creates tension
        for i in gameState.advisors.indices {
            gameState.advisors[i].loyalty = max(10, gameState.advisors[i].loyalty - 5)
        }

        // Approval impact depends on how popular the fired advisor was
        if let playerIdx = gameState.countries.firstIndex(where: { $0.id == gameState.playerCountryID }) {
            let approvalDelta = fired.publicSupport > 60 ? -8 : fired.publicSupport < 40 ? +5 : -3
            gameState.countries[playerIdx].publicApproval =
                max(0, min(100, gameState.countries[playerIdx].publicApproval + approvalDelta))
        }

        addLog("", type: .system)
        addLog("CABINET CHANGE", type: .warning)
        addLog("\(fired.name) (\(fired.title)) removed from cabinet.", type: .warning)

        // Color commentary based on persona
        switch fired.hawkishness {
        case 80...:
            addLog("The hawk is gone. Adversaries may probe our resolve.", type: .info)
        case ...30:
            addLog("The dove has flown. Hawks in Congress celebrate.", type: .info)
        default:
            addLog("Remaining advisors on notice. Loyalty is now in question.", type: .info)
        }

        gameState.militaryActionsUsed += 0
        self.gameState = gameState
    }

    // MARK: - 2. Executive Orders

    /// Issue a presidential executive order bypassing Congress.
    func issueExecutiveOrder(type: ExecutiveOrderType, targetCountryID: String? = nil) {
        guard let gameState = gameState else { return }

        let playerID = gameState.playerCountryID

        addLog("", type: .system)
        addLog("EXECUTIVE ORDER SIGNED", type: .warning)
        addLog("Order: \(type.rawValue)", type: .info)

        // Apply approval change
        if let playerIdx = gameState.countries.firstIndex(where: { $0.id == playerID }) {
            gameState.countries[playerIdx].publicApproval =
                max(0, min(100, gameState.countries[playerIdx].publicApproval + type.approvalImpact))
        }

        // Apply specific effects
        switch type {
        case .emergencyPowers:
            raiseDEFCON()
            if let playerIdx = gameState.countries.firstIndex(where: { $0.id == playerID }) {
                gameState.countries[playerIdx].militaryStrength =
                    min(100, gameState.countries[playerIdx].militaryStrength + 10)
            }
            addLog("Emergency powers activated. DEFCON raised.", type: .critical)

        case .domesticEconomy:
            if let playerIdx = gameState.countries.firstIndex(where: { $0.id == playerID }) {
                gameState.countries[playerIdx].gdp *= 1.05
                gameState.countries[playerIdx].economicStrength =
                    min(100, gameState.countries[playerIdx].economicStrength + 5)
            }
            addLog("Stimulus order signed. GDP projected to grow.", type: .info)

        case .civilRights:
            // Boost relations with all democratic allies
            for country in gameState.countries where country.government == .democracy || country.government == .republic {
                modifyDiplomaticRelation(from: playerID, to: country.id, by: 10)
            }
            addLog("Civil rights order signals commitment to democracy.", type: .info)

        case .immigrationPolicy:
            if let playerIdx = gameState.countries.firstIndex(where: { $0.id == playerID }) {
                gameState.countries[playerIdx].stability =
                    min(100, gameState.countries[playerIdx].stability + 5)
            }
            addLog("Immigration order issued via executive action.", type: .info)

        case .energyPolicy:
            if let playerIdx = gameState.countries.firstIndex(where: { $0.id == playerID }) {
                gameState.countries[playerIdx].economicStrength =
                    min(100, gameState.countries[playerIdx].economicStrength + 3)
            }
            addLog("Energy policy directive issued.", type: .info)

        case .foreignPolicy:
            if let target = targetCountryID {
                modifyDiplomaticRelation(from: playerID, to: target, by: 15)
                let name = getCountry(target)?.name ?? target
                addLog("Foreign policy doctrine announced — signals strong commitment to \(name).", type: .info)
            } else {
                // Boost all allied relations slightly
                for country in gameState.countries where country.alignment == gameState.getPlayerCountry()?.alignment {
                    modifyDiplomaticRelation(from: playerID, to: country.id, by: 5)
                }
                addLog("Foreign policy doctrine announced. Allies reassured.", type: .info)
            }

        case .defenseReadiness:
            if let playerIdx = gameState.countries.firstIndex(where: { $0.id == playerID }) {
                gameState.countries[playerIdx].militaryStrength =
                    min(100, gameState.countries[playerIdx].militaryStrength + 8)
                gameState.countries[playerIdx].treasury -= 5_000_000_000
            }
            addLog("Armed forces placed on elevated readiness.", type: .info)

        case .tradePolicy:
            if let target = targetCountryID {
                let name = getCountry(target)?.name ?? target
                modifyDiplomaticRelation(from: playerID, to: target, by: -10)
                if let playerIdx = gameState.countries.firstIndex(where: { $0.id == playerID }) {
                    gameState.countries[playerIdx].gdp *= 1.02
                }
                addLog("Tariffs on \(name). Domestic industry protected. Trade tensions raised.", type: .info)
            }

        case .sanctionsBypass:
            if let target = targetCountryID {
                let name = getCountry(target)?.name ?? target
                modifyDiplomaticRelation(from: playerID, to: target, by: -25)
                if let targetIdx = gameState.countries.firstIndex(where: { $0.id == target }) {
                    gameState.countries[targetIdx].economicStrength =
                        max(0, gameState.countries[targetIdx].economicStrength - 10)
                }
                addLog("Emergency sanctions on \(name) signed into effect.", type: .warning)
            }

        case .deployReserves:
            if let playerIdx = gameState.countries.firstIndex(where: { $0.id == playerID }) {
                gameState.countries[playerIdx].stability =
                    min(100, gameState.countries[playerIdx].stability + 10)
            }
            addLog("National Guard activated. Domestic stability secured.", type: .info)
        }

        gameState.militaryActionsUsed += 1
        self.gameState = gameState
        gameState.hasUsedActionThisTurn = true
    }

    // MARK: - 3. Presidential Pardons

    /// Grant a presidential pardon.
    func grantPardon(type: PardonType, targetCountryID: String? = nil) {
        guard let gameState = gameState else { return }

        let playerID = gameState.playerCountryID

        addLog("", type: .system)
        addLog("PRESIDENTIAL PARDON ISSUED", type: .info)
        addLog("Pardon type: \(type.rawValue)", type: .info)

        // Apply approval change
        if let playerIdx = gameState.countries.firstIndex(where: { $0.id == playerID }) {
            gameState.countries[playerIdx].publicApproval =
                max(0, min(100, gameState.countries[playerIdx].publicApproval + type.approvalImpact))
        }

        // Apply specific effects
        switch type {
        case .politicalRival:
            if let playerIdx = gameState.countries.firstIndex(where: { $0.id == playerID }) {
                gameState.countries[playerIdx].stability =
                    min(100, gameState.countries[playerIdx].stability + 10)
            }
            addLog("Political rival pardoned. Nation notes the gesture of unity.", type: .info)

        case .diplomaticGesture:
            if let target = targetCountryID {
                modifyDiplomaticRelation(from: playerID, to: target, by: 20)
                let name = getCountry(target)?.name ?? target
                addLog("Foreign national pardoned as goodwill gesture. \(name) relations improved.", type: .info)
            }

        case .whistleblower:
            // Boost relations with civil liberties-minded nations, hurt intel community morale
            for country in gameState.countries where country.government == .democracy {
                modifyDiplomaticRelation(from: playerID, to: country.id, by: 8)
            }
            addLog("Whistleblower pardoned. Civil liberties advocates applaud.", type: .info)
            addLog("Intelligence community deeply unhappy with decision.", type: .warning)

        case .warCriminal:
            // Major diplomatic hit with affected countries
            if let target = targetCountryID {
                modifyDiplomaticRelation(from: playerID, to: target, by: -30)
                let name = getCountry(target)?.name ?? target
                addLog("War criminal pardon condemned by \(name) and international community.", type: .critical)
            }

        case .posthumous:
            if let playerIdx = gameState.countries.firstIndex(where: { $0.id == playerID }) {
                gameState.countries[playerIdx].publicApproval =
                    min(100, gameState.countries[playerIdx].publicApproval + 5)
            }
            addLog("Historical pardon granted. Justice delayed but not denied.", type: .info)

        case .massPardon:
            if let playerIdx = gameState.countries.firstIndex(where: { $0.id == playerID }) {
                gameState.countries[playerIdx].stability =
                    min(100, gameState.countries[playerIdx].stability + 8)
            }
            addLog("Mass pardon issued. Thousands released. Approval broadly positive.", type: .info)
        }

        self.gameState = gameState
    }

    // MARK: - 4. Presidential Address

    private static var lastAddressTurn: [String: Int] = [:]

    /// Deliver a presidential address from the bully pulpit.
    func deliverPresidentialAddress(type: AddressType, targetCountryID: String? = nil) {
        guard let gameState = gameState else { return }

        let playerID = gameState.playerCountryID
        let cooldownKey = "\(playerID)-\(type.rawValue)"
        let lastTurn = Self.lastAddressTurn[cooldownKey] ?? -99

        // Enforce cooldown
        if gameState.turn - lastTurn < type.cooldownTurns {
            let turnsLeft = type.cooldownTurns - (gameState.turn - lastTurn)
            addLog("Address cooldown: \(turnsLeft) turn(s) remaining before another \(type.rawValue).", type: .info)
            return
        }
        Self.lastAddressTurn[cooldownKey] = gameState.turn

        addLog("", type: .system)
        addLog("── PRESIDENTIAL ADDRESS ──", type: .system)
        addLog(type.rawValue.uppercased(), type: .info)

        // Apply approval change
        if let playerIdx = gameState.countries.firstIndex(where: { $0.id == playerID }) {
            gameState.countries[playerIdx].publicApproval =
                max(0, min(100, gameState.countries[playerIdx].publicApproval + type.approvalImpact))
        }

        // Apply specific effects
        switch type {
        case .stateOfUnion:
            // Major approval boost + congressional support
            if let playerIdx = gameState.countries.firstIndex(where: { $0.id == playerID }) {
                gameState.countries[playerIdx].congressionalSupport =
                    min(100, gameState.countries[playerIdx].congressionalSupport + 10)
            }
            addLog("Joint session of Congress addressed. Legislative agenda set.", type: .info)
            addLog("Nation rallies. Congressional support improves.", type: .info)

        case .ovalOffice:
            // Rally allies, reassure public during crisis
            for country in gameState.countries where country.alignment == gameState.getPlayerCountry()?.alignment {
                modifyDiplomaticRelation(from: playerID, to: country.id, by: 5)
            }
            addLog("Oval Office address delivered. Nation reassured.", type: .info)
            addLog("Allies receiving the message clearly.", type: .info)

        case .foreignPolicy:
            if let target = targetCountryID {
                modifyDiplomaticRelation(from: playerID, to: target, by: 15)
                let name = getCountry(target)?.name ?? target
                addLog("Major foreign policy speech delivered.", type: .info)
                addLog("\(name) designated as strategic partner. World is watching.", type: .info)
            } else {
                addLog("Foreign policy address sets new strategic doctrine.", type: .info)
            }

        case .warAddress:
            // Military effectiveness boost
            if let playerIdx = gameState.countries.firstIndex(where: { $0.id == playerID }) {
                gameState.countries[playerIdx].militaryStrength =
                    min(100, gameState.countries[playerIdx].militaryStrength + 5)
                gameState.countries[playerIdx].warSupport =
                    min(100, gameState.countries[playerIdx].warSupport + 15)
            }
            addLog("Forces addressed. Morale boosted. Military effectiveness +5.", type: .info)

        case .peaceInitiative:
            // Relations boost with all, reduce DEFCON
            for i in gameState.countries.indices {
                let id = gameState.countries[i].id
                if let rel = gameState.countries[i].diplomaticRelations[playerID], rel < 0 {
                    modifyDiplomaticRelation(from: playerID, to: id, by: 10)
                }
            }
            if gameState.defconLevel.rawValue < 5 {
                let newLevel = DefconLevel(rawValue: gameState.defconLevel.rawValue + 1) ?? .defcon5
                gameState.defconLevel = newLevel
                addLog("Peace initiative announced. DEFCON reduced to \(newLevel.rawValue).", type: .info)
            }
            addLog("All hostile nations receive the peace signal. Trust rebuilds.", type: .info)

        case .warningAddress:
            if let target = targetCountryID {
                modifyDiplomaticRelation(from: playerID, to: target, by: -20)
                let name = getCountry(target)?.name ?? target
                raiseDEFCON()
                addLog("Direct warning issued to \(name).", type: .critical)
                addLog("The world holds its breath. DEFCON raised.", type: .critical)
            }
        }

        self.gameState = gameState
    }
}
