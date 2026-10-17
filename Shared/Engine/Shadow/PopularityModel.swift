//
//  PopularityModel.swift
//  Global Thermal Nuclear War
//
//  Presidential popularity, opinion polls, elections (toggleable), impeachment, assassination and civil war.
//  Tied into the existing approval/Congress numbers on the player's Country. All wording is GTNW's own.
//  Repository: https://github.com/kochj23/GTNW
//

import Foundation

enum PopularityModel {
    /// Where popularity drifts to when nothing dramatic happens.
    static func equilibrium(usQoL: Double, growth: Double, warsInvolvingPlayer: Int, ruthlessness: Double,
                            nuclearHitsOnPlayer: Int) -> Double {
        var e = 50 + (usQoL - 60) * 0.4 + growth * 3
        e -= Double(warsInvolvingPlayer) * 4
        e -= ruthlessness * 0.3
        e -= Double(nuclearHitsOnPlayer) * 15
        return min(85, max(10, e))
    }

    /// Popularity drifts halfway to equilibrium every ~6 game months.
    static func drift(_ current: Double, toward target: Double, scale: TurnScale) -> Double {
        let keep = pow(0.5, scale.yearFraction / 0.5)
        return current * keep + target * (1 - keep)
    }

    static func clamp(_ v: Double) -> Double { min(100, max(0, v)) }

    /// How the Press Secretary describes a change between two polls.
    static func pollPhrase(from old: Double, to new: Double) -> String {
        let d = new - old
        let a = abs(d)
        let verbUp: String, verbDown: String
        switch a {
        case ..<1: return String(format: "Your approval held steady at %.0f%%.", new)
        case ..<3: verbUp = "edged up"; verbDown = "slipped"
        case ..<7: verbUp = "rose"; verbDown = "fell"
        case ..<12: verbUp = "jumped"; verbDown = "dropped sharply"
        default: verbUp = "soared"; verbDown = "collapsed"
        }
        return String(format: "Your approval %@ from %.0f%% to %.0f%%.", d > 0 ? verbUp : verbDown, old, new)
    }

    /// Popularity effect of a player action (immediate), by escalation rung and hostility.
    static func actionEffect(rung: EscalationRung, hostile: Bool, detected: Bool) -> Double {
        switch rung {
        case .social: return hostile ? -0.5 : 1.0
        case .economic: return hostile ? -0.3 : 0.5
        case .covert: return detected ? -6 : 0
        case .military: return hostile ? 2.0 : 0.5          // a short rally-round-the-flag effect
        case .nuclear: return hostile ? -25 : 1.0
        }
    }

    /// Ruthlessness added by an action (decays ~30% a year).
    static func ruthlessnessEffect(rung: EscalationRung, hostile: Bool) -> Double {
        guard hostile else { return 0 }
        switch rung {
        case .social, .economic: return 0
        case .covert: return 4
        case .military: return 6
        case .nuclear: return 40
        }
    }

    // MARK: Elections

    /// Vote share for the incumbent. `noise` in -1…1.
    static func voteShare(popularity: Double, termsWon: Int, noise: Double) -> Double {
        let fatigue = Double(termsWon) * 1.5
        return min(80, max(20, 50 + (popularity - 50) * 0.6 - fatigue + noise * 3))
    }

    static let challengers = ["Sen. Harlan Voss", "Gov. Celia Marchetti", "Rep. Dwight Okafor", "Gov. Ruth Calloway",
                              "Sen. Amos Whitcomb", "Gov. Teresa Lindqvist", "Sen. Marcus Delacroix", "Gov. Jo Hartigan"]

    static func challenger(for year: Int) -> String { challengers[abs(year / 4) % challengers.count] }

    // MARK: Impeachment

    /// Next impeachment stage given the current one. Congress acts on sustained unpopularity plus scandal/ruthlessness.
    static func nextImpeachmentStage(current: Int, popularity: Double, ruthlessness: Double, congress: Int) -> Int {
        if popularity > 38 && ruthlessness < 30 { return 0 }          // the storm passes
        let pressure = (30 - popularity) + ruthlessness * 0.4 + Double(max(0, 40 - congress)) * 0.3
        if pressure > 12 { return min(4, current + 1) }                // 4 = removed from office
        return current
    }

    static func impeachmentText(stage: Int) -> String {
        switch stage {
        case 1: return "House committees open hearings into the conduct of the Presidency."
        case 2: return "Articles of impeachment are being drafted on Capitol Hill."
        case 3: return "The House has voted to impeach. The Senate trial begins."
        default: return "The Senate has voted to remove the President from office."
        }
    }

    // MARK: Assassination

    /// Annual probability that an attempt on the President's life succeeds.
    static func assassinationAnnualProbability(popularity: Double, ruthlessness: Double) -> Double {
        var p = 0.002 + ruthlessness / 100 * 0.15
        if popularity < 20 { p += 0.04 }
        return min(0.5, p)
    }
}

/// The five rungs of the escalation ladder, left to right.
enum EscalationRung: Int, CaseIterable, Identifiable, Codable {
    case social, economic, covert, military, nuclear
    var id: Int { rawValue }

    var title: String {
        switch self {
        case .social: return "Social"
        case .economic: return "Economic"
        case .covert: return "Covert"
        case .military: return "Military"
        case .nuclear: return "Nuclear"
        }
    }

    var icon: String {
        switch self {
        case .social: return "person.2.fill"
        case .economic: return "dollarsign.circle.fill"
        case .covert: return "eye.slash.fill"
        case .military: return "shield.fill"
        case .nuclear: return "atom"
        }
    }

    /// The cabinet post that speaks first for actions on this rung.
    var leadAdvisorKey: String {
        switch self {
        case .social: return "state"
        case .economic: return "economic"
        case .covert: return "cia"
        case .military: return "defense"
        case .nuclear: return "nsa"
        }
    }

    static func of(_ category: ActionCategory) -> EscalationRung {
        switch category {
        case .diplomatic, .treaties, .propaganda: return .social
        case .economic: return .economic
        case .covert, .intelligence: return .covert
        case .military: return .military
        case .nuclear: return .nuclear
        }
    }
}

extension PresidentialAction {
    var rung: EscalationRung { EscalationRung.of(category) }

    /// Friendly (cooperative) actions; everything else is treated as pressure on the target.
    static let friendlyActions: Set<PresidentialAction> = [
        .sendAmbassador, .stateVisit, .summit, .mediateConflict, .issueApology, .restoreRelations, .recognizeGov,
        .jointStatement, .jointExercise, .sellWeapons, .provideTraining, .peacekeeping, .militaryAid, .defensivePact,
        .economicAid, .loanMoney, .forgiveDebt, .tradeDeal, .removeTariffs, .liftSanctions, .unfreezeAssets, .foodAid,
        .techAssist, .investment, .jointVenture, .proposeTreaty, .signTreaty, .nonAggression, .mutualDefense,
        .freeTrade, .nonProliferation, .armsControl, .ceasefire, .peace, .extradition, .joinNATO, .neutrality,
        .hostages, .cultural, .noFirstUse, .withdrawTroops, .closeBase,
    ]

    var isHostile: Bool { !Self.friendlyActions.contains(self) }
}
