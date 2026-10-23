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
        case 2: return "Articles of impeachment are being drafted on Capitol Hill. The House votes at the next monthly poll unless approval recovers above 38% and the outrage fades."
        case 3: return "The House has voted to impeach. The Senate trial begins: two-thirds must vote to convict at the next poll."
        default: return "The Senate trial reaches its verdict."
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
        .freeTrade, .mostFavoredNation, .nonProliferation, .armsControl, .ceasefire, .peace, .extradition, .joinNATO, .neutrality,
        .hostages, .cultural, .noFirstUse, .withdrawTroops, .closeBase,
    ]

    var isHostile: Bool { !Self.friendlyActions.contains(self) }
}

// MARK: - Era public mood (3.18.x)

/// The public's era-specific appetite for the hard tools of statecraft — the mood of the decade. These scale the
/// approval/world-opinion COST of an action: ~0 = the era shrugs it off, 1 = neutral, >1 = the era recoils.
/// Territorial expansion's own era reaction already lives in `ExpansionModel.politics`; this adds the nuclear taboo —
/// the thread from Truman's bomb (little taboo, 1945) to the entrenched post-Cold-War horror.
enum EraMood {
    /// The nuclear taboo as a cost multiplier on *using* nuclear weapons, rising across the decades.
    static func nuclearTaboo(year: Int) -> Double {
        switch year {
        case ..<1950: return 0.3   // 1945–49 monopoly: the bomb just won a war; the taboo hasn't set
        case ..<1963: return 1.0   // Korea, the H-bomb, the near-misses — the taboo forms
        case ..<1992: return 2.5   // high Cold War: first use is near-unthinkable
        default:      return 4.0   // post-Cold-War: using one ends your presidency
        }
    }

    /// How the public reads the *use* of nukes by situation: cheapest once you've already been hit, dearest as an
    /// unprovoked peacetime first strike (even in 1945). `atWar` = already fighting the target;
    /// `retaliating` = the target has already nuked you.
    static func useContext(atWar: Bool, retaliating: Bool) -> Double {
        retaliating ? 0.3 : (atWar ? 0.7 : 1.5)
    }

    /// The public's tolerance for the human cost of foreign war — a cost multiplier on war-weariness. Below 1 when
    /// the decade is jingoist (the Spanish-American high tide, the unity of the Second World War), above 1 when it
    /// recoils (the isolationist 1930s, Vietnam, the post-9/11 forever-war fatigue). The same casualties cost a
    /// Vietnam-era President far more approval than a 1898 or 1943 one. DESIGN CHOICES, not published figures.
    static func interventionMood(year: Int) -> Double {
        switch year {
        case ..<1898: return 1.0   // a continental republic, wary of foreign wars but not yet scarred by one
        case ..<1919: return 0.6   // the imperial high tide: Manila Bay, San Juan Hill, the Great White Fleet
        case ..<1941: return 1.6   // between the wars: disillusion, the Nye Committee, the Neutrality Acts
        case ..<1946: return 0.5   // the Second World War: total war, and a casualty tolerance to match
        case ..<1965: return 1.0   // the early Cold War: Korea drains the country but it holds
        case ..<1976: return 2.2   // Vietnam: every casualty is on the evening news, and on the President
        case ..<2002: return 1.6   // the Vietnam syndrome: body-bag aversion, Beirut, Mogadishu
        case ..<2009: return 1.0   // after 11 September: resolve, and a few years' patience for it
        default:      return 1.8   // the forever wars: the country is tired of them
        }
    }
}
