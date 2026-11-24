//
//  ForeignPowerPlays.swift
//  Global Thermal Nuclear War
//
//  3.36.0: presidential power plays. Five generic mechanics any head of government can use in any era, each with its
//  own file:
//    • AcquisitionCampaign.swift: a campaign to acquire a land or a nation without war (offer to buy, tariffs on the
//      nations that object, military posturing, then a framework deal or escalation).
//    • EmergencyPowers.swift: a national emergency, emergency orders that each record their legal basis, and the
//      court challenge that can strike an order down months later (tariffs first; a hook for any other order).
//    • LeaderCapture.swift: a special-forces raid to seize a foreign head of government.
//    • LimitedStrikes.swift: precision, boat, facility and nuclear-facility strikes without a declaration of war,
//      which start the War Powers clock and can make Congress vote.
//    • MapFeatures.swift: seas, gulfs, straits and mountains, and the President's own departments, renamed.
//  This file holds the state they share (`ShadowState.powerPlays`), the cabinet's read-outs and the order dispatch
//  the command box uses. Outcomes come from formulas or the game's seeded RNG; nothing here touches the game until
//  the player uses one of these orders, so a game that never does plays exactly as before.
//  Repository: https://github.com/kochj23/GTNW
//

import Foundation

/// Everything the power plays keep between turns. Decodes from older saves (every field optional on the wire).
struct PowerPlayState: Codable, Equatable {
    /// Acquisition campaigns, newest last (finished ones stay as the record).
    var campaigns: [AcquisitionCampaign] = []
    /// The national emergency in force, and the ones that ended.
    var emergency: NationalEmergency?
    var pastEmergencies: [NationalEmergency] = []
    /// Emergency orders with their legal basis and court status; ids count up from 1.
    var orders: [EmergencyOrder] = []
    var nextOrderID = 1
    /// Leader-capture raids, and Americans (or the player's nationals) held after a failed one.
    var raids: [CaptureRaid] = []
    var hostages: [HostageCrisis] = []
    /// Limited strikes, Congress's forced votes on them, targets Congress has ordered the strikes stopped on (a veto
    /// overridden), the escalation each target has built up, and nuclear programmes set back (target → until).
    var strikes: [LimitedStrikeRecord] = []
    var strikeVotes: [StrikeVote] = []
    var strikeBans: Set<String> = []
    var escalation: [String: Double] = [:]
    var programDelays: [String: ProgramDelay] = [:]
    /// The President's names for map features and his own departments (id → name), and who recognizes each feature
    /// name (feature id → nation ids).
    var featureNames: [String: String] = [:]
    var departmentNames: [String: String] = [:]
    var featureRecognition: [String: [String]] = [:]

    init() {}

    enum CodingKeys: String, CodingKey {
        case campaigns, emergency, pastEmergencies, orders, nextOrderID, raids, hostages, strikes, strikeVotes, strikeBans
        case escalation, programDelays, featureNames, departmentNames, featureRecognition
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        campaigns = (try? c.decodeIfPresent([AcquisitionCampaign].self, forKey: .campaigns)) ?? []
        emergency = try? c.decodeIfPresent(NationalEmergency.self, forKey: .emergency)
        pastEmergencies = (try? c.decodeIfPresent([NationalEmergency].self, forKey: .pastEmergencies)) ?? []
        orders = (try? c.decodeIfPresent([EmergencyOrder].self, forKey: .orders)) ?? []
        nextOrderID = (try? c.decodeIfPresent(Int.self, forKey: .nextOrderID)) ?? (orders.map(\.id).max() ?? 0) + 1
        raids = (try? c.decodeIfPresent([CaptureRaid].self, forKey: .raids)) ?? []
        hostages = (try? c.decodeIfPresent([HostageCrisis].self, forKey: .hostages)) ?? []
        strikes = (try? c.decodeIfPresent([LimitedStrikeRecord].self, forKey: .strikes)) ?? []
        strikeVotes = (try? c.decodeIfPresent([StrikeVote].self, forKey: .strikeVotes)) ?? []
        strikeBans = (try? c.decodeIfPresent(Set<String>.self, forKey: .strikeBans)) ?? []
        escalation = (try? c.decodeIfPresent([String: Double].self, forKey: .escalation)) ?? [:]
        programDelays = (try? c.decodeIfPresent([String: ProgramDelay].self, forKey: .programDelays)) ?? [:]
        featureNames = (try? c.decodeIfPresent([String: String].self, forKey: .featureNames)) ?? [:]
        departmentNames = (try? c.decodeIfPresent([String: String].self, forKey: .departmentNames)) ?? [:]
        featureRecognition = (try? c.decodeIfPresent([String: [String]].self, forKey: .featureRecognition)) ?? [:]
    }

    /// True when nothing has been used yet (the turn step skips everything).
    var isIdle: Bool {
        campaigns.allSatisfy { !$0.stage.isOpen } && emergency == nil && orders.allSatisfy { !$0.status.isLive }
            && hostages.allSatisfy(\.released) && escalation.isEmpty && strikes.isEmpty && programDelays.isEmpty
    }

    static let historyCap = 120

    mutating func trim() {
        if campaigns.count > Self.historyCap { campaigns.removeFirst(campaigns.count - Self.historyCap) }
        if raids.count > Self.historyCap { raids.removeFirst(raids.count - Self.historyCap) }
        if strikes.count > Self.historyCap * 2 { strikes.removeFirst(strikes.count - Self.historyCap * 2) }
        if strikeVotes.count > Self.historyCap { strikeVotes.removeFirst(strikeVotes.count - Self.historyCap) }
        if pastEmergencies.count > 40 { pastEmergencies.removeFirst(pastEmergencies.count - 40) }
        let dead = orders.filter { !$0.status.isLive }
        if dead.count > Self.historyCap * 2, let cut = dead.dropLast(Self.historyCap * 2).last?.id {
            orders.removeAll { !$0.status.isLive && $0.id <= cut }
        }
    }
}

/// The kinds of power play the command box and the chief of staff can order (`GameOrder.mission` carries the step).
enum PowerPlay {
    /// The cabinet member who reads out the law.
    static let counsel = "Attorney General"

    /// A short list of names: "Canada, Mexico and 2 more".
    static func list(_ names: [String]) -> String {
        guard !names.isEmpty else { return "" }
        if names.count == 1 { return names[0] }
        if names.count <= 3 { return names.dropLast().joined(separator: ", ") + " and " + names.last! }
        return names.prefix(3).joined(separator: ", ") + " and \(names.count - 3) more"
    }

    /// Clamp to 0…1.
    static func unit(_ v: Double) -> Double { min(1, max(0, v)) }
}

// MARK: - Engine

extension GameEngine {

    /// Each turn: campaigns, emergency orders and court rulings, hostages, strike escalation and Congress's votes.
    /// Does nothing (and draws nothing from the RNG) until a power play has been used.
    func processPowerPlays() {
        guard let gs = gameState, !gs.shadow.powerPlays.isIdle else { return }
        processCampaigns()
        processEmergencyOrders()
        processLimitedStrikes()
        processHostages()
        gameState?.shadow.powerPlays.trim()
    }

    /// The Vice President's read-out on a power play: approval, impeachment talk and (for the U.S. after 1973) War
    /// Powers. The same numbers `AdvisorWarnings` uses.
    func powerPlayPolitics(dPop: Double, dRuth: Double, hostilities target: String?) -> AdvisorWarning {
        guard let gs = gameState, let me = gs.getPlayerCountry() else { return AdvisorWarning(who: "Vice President", text: "", level: 0) }
        let p = ExpansionModel.impeachmentPressure(popularity: gs.shadow.popularity + dPop, ruthlessness: gs.shadow.ruthlessness + dRuth,
                                                   congress: me.congressionalSupport)
        var text = "Approval \(dPop >= 0 ? "+" : "")\(Int(dPop.rounded())) at home."
        var level = dPop < -3 ? 1 : 0
        if let t = target, gs.playerCountryID == "USA", !isAuthorized(t), gs.currentDate >= CongressModel.warPowersResolution {
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

    /// The name the Secretary of State goes by on a card ("Secretary of State Rusk").
    var powerPlayStateWho: String {
        AdviceEngine.advisor(for: "state", in: gameState?.advisors ?? []).map { "Secretary of State \($0.name)" } ?? "Secretary of State"
    }

    /// Why a power-play order can't run now, or nil. Checked when the card is built and again at EXECUTE.
    func powerPlayProblem(_ o: GameOrder) -> String? {
        guard let gs = gameState else { return "No game in progress." }
        switch o.kind {
        case .acquire:
            guard let step = o.mission.flatMap(CampaignStep.init(rawValue:)) else { return "Not a campaign step." }
            return campaignProblem(o.target, step: step)
        case .emergency:
            guard let step = o.mission.flatMap(EmergencyStep.init(rawValue:)) else { return "Not an emergency order." }
            switch step {
            case .declare:
                return emergencyDeclareProblem(EmergencyReason(rawValue: o.detail ?? "") ?? .security)
            case .end:
                return gs.shadow.powerPlays.emergency == nil ? "No national emergency is in force." : nil
            case .tariff:
                guard let basis = o.detail.flatMap(LegalBasis.init(rawValue:)) else { return "Name the legal authority." }
                return emergencyTariffProblem(o.target, basis: basis)
            case .reissue:
                guard let basis = o.detail.flatMap(LegalBasis.init(rawValue:)), let id = EmergencyOrder.id(fromTarget: o.target) else {
                    return "Name the order and the new authority."
                }
                return reissueProblem(id, basis: basis)
            }
        case .captureLeader:
            return captureProblem(o.target)
        case .renamePlace:   // 3.36.0: one rename path (Renaming.swift)
            return renamePlaceProblem(o.target, to: o.detail ?? "")
        case .limitedStrike:
            guard let k = o.mission.flatMap(StrikeKind.init(rawValue:)) else { return "Not a strike." }
            return strikeProblem(o.target, kind: k)
        default:
            return "Not a power play."
        }
    }

    /// Carry out a power-play order (one action each, except ending an emergency). Returns whether it went through.
    @discardableResult
    func executePowerPlay(_ o: GameOrder) -> Bool {
        guard powerPlayProblem(o) == nil else { return false }
        switch o.kind {
        case .acquire:
            guard let step = o.mission.flatMap(CampaignStep.init(rawValue:)) else { return false }
            return campaignStep(o.target, step: step)
        case .emergency:
            guard let step = o.mission.flatMap(EmergencyStep.init(rawValue:)) else { return false }
            switch step {
            case .declare: return declareNationalEmergency(EmergencyReason(rawValue: o.detail ?? "") ?? .security)
            case .end: return endNationalEmergency()
            case .tariff:
                guard let b = o.detail.flatMap(LegalBasis.init(rawValue:)) else { return false }
                return emergencyTariffs(on: o.target, basis: b) != nil
            case .reissue:
                guard let b = o.detail.flatMap(LegalBasis.init(rawValue:)), let id = EmergencyOrder.id(fromTarget: o.target) else { return false }
                return reissueEmergencyOrder(id, basis: b) != nil
            }
        case .captureLeader:
            return captureLeader(o.target) != nil
        case .renamePlace:
            return renamePlace(o.target, to: o.detail ?? "")
        case .limitedStrike:
            guard let k = o.mission.flatMap(StrikeKind.init(rawValue:)) else { return false }
            return limitedStrike(o.target, kind: k) != nil
        default:
            return false
        }
    }
}

// MARK: - Consequences (Consequences.swift)

extension GameEngine {
    /// A strike or raid on a nation that surrendered to the player, or on an ally: the tribunal case and the
    /// alliance council the same as any other attack. No dice.
    func powerPlayConsequences(_ target: String, how: String) {
        guard let gs = gameState else { return }
        if Consequences.protection(of: target, in: gs) == .surrendered {
            punishProtectedAttack(target, protection: .surrendered, nuclear: false)
        }
        if Consequences.alliance(with: target, in: gs) != nil { attackOnAlly(target, how: how) }
    }
}
