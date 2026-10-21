//
//  ArsenalCatalog.swift
//  Global Thermal Nuclear War
//
//  The era-accurate U.S. weapons catalog (3.6.0). `ArsenalData.swift` (generated from Documentation/arsenal) lists
//  every offensive option the United States had, 1789–2030, with its years and its legal status by period. This
//  file decides what the President sees in a given year, labels restricted and treaty-banned options instead of
//  hiding them, and prices their use in world opinion, alliances, sanctions and impeachment risk.
//  Encyclopedia level only: names, dates, effects on game stats and diplomatic consequences.
//  Repository: https://github.com/kochj23/GTNW
//

import Foundation

enum LegalStatus: String, Codable {
    case legal, restricted, treatyBanned, destroyed

    var label: String {
        switch self {
        case .legal: return "Legal"
        case .restricted: return "Restricted"
        case .treatyBanned: return "Treaty-banned"
        case .destroyed: return "Stockpile destroyed"
        }
    }
}

struct ArsenalOption: Identifiable {
    struct Period {
        let from: Int
        let to: Int?
        let status: LegalStatus
        let note: String
    }
    let id: String
    let category: String
    let name: String
    let from: Int
    let to: Int?
    /// First available after ~April 2026: background flavour only, never the sole gate for an action.
    let lowConfidence: Bool
    let periods: [Period]
    let examples: [String]

    func exists(in year: Int) -> Bool { year >= from && year <= (to ?? Int.max) }

    /// Status in a year: the latest period that has begun (periods are chronological and may share a boundary year).
    func status(in year: Int) -> LegalStatus? { periods.last { $0.from <= year }?.status }
    func note(in year: Int) -> String? { periods.last { $0.from <= year }?.note }
}

/// Chemical and biological weapons: shown with their legal status, never as ordinary options.
enum WMDKind: String, Codable, CaseIterable, Identifiable {
    case chemical, biological
    var id: String { rawValue }
    var title: String { self == .chemical ? "Chemical" : "Biological" }
}

/// A restarted chemical or biological program (only possible once the stockpile is gone).
struct WMDProgram: Codable, Hashable {
    var kind: WMDKind
    var started: Date
    var ready: Date
    var discovered = false
}

enum ArsenalCatalog {
    static func option(_ id: String) -> ArsenalOption? { options.first { $0.id == id } }

    /// Options the U.S. has in a year (low-confidence future items included, flagged).
    static func options(in year: Int) -> [ArsenalOption] { options.filter { $0.exists(in: year) } }

    /// Trinity, 16 Jul 1945: no nuclear option before it.
    static let trinity = GameCalendar.date(year: 1945, month: 7, day: 16)
    /// The last declared U.S. chemical munition was destroyed 7 Jul 2023 (OPCW-verified).
    static let chemicalStockpileDestroyed = GameCalendar.date(year: 2023, month: 7, day: 7)

    /// Which catalog options an action draws on, for its ARSENAL line (the first is its main option).
    static func optionIDs(for action: PresidentialAction) -> [String] {
        switch action {
        case .groundInvasion: return ["land_infantry", "land_artillery", "land_cavalry_horse", "land_armor", "land_airborne", "land_helicopter"]
        case .amphAssault: return ["land_marines", "naval_sail_frigates", "naval_steam_ironclads", "naval_carriers"]
        case .specialForces: return ["land_special_forces"]
        case .airStrike: return ["air_tactical", "air_pgm", "air_stealth", "air_drones", "missile_cruise_modern"]
        case .bombardment: return ["land_artillery", "air_strategic_bombers", "naval_battleships", "missile_cruise_early"]
        case .navalBlockade: return ["naval_blockade", "naval_mines", "naval_submarines"]
        case .launchNukes, .strategicNuke, .firstStrike, .preemptive, .retaliate: return ["nuclear_strategic", "missile_icbm", "missile_slbm", "air_strategic_bombers"]
        case .tacticalNuke: return ["nuclear_tactical"]
        case .nuclearTest: return ["nuclear_test"]
        case .deployMissiles: return ["missile_theater_ballistic", "missile_cruise_modern"]
        case .cyberAttack: return ["cyber_offensive"]
        case .chemicalAttack, .restartChemical: return ["chemical"]
        case .biologicalAttack, .restartBiological: return ["biological"]
        default: return []
        }
    }

    /// The era's examples behind an action, e.g. "AEF divisions (1917-18)".
    static func examples(for action: PresidentialAction, year: Int) -> [String] {
        optionIDs(for: action).compactMap(option).filter { $0.exists(in: year) && !$0.lowConfidence }.map(\.name)
    }

    /// Legal status of an action's main option in a year (nil = not catalogued).
    static func status(for action: PresidentialAction, year: Int) -> LegalStatus? {
        optionIDs(for: action).first.flatMap(option)?.status(in: year)
    }

    // MARK: Chemical and biological

    /// Chemical: a stockpile from 1917 until 7 Jul 2023; biological: a program from 1943 to 1969 (Nixon ended it in
    /// Nov 1969). Before those years there is nothing to use; after them only a restarted program.
    static func stockpileExists(_ kind: WMDKind, on date: Date) -> Bool {
        let y = GameCalendar.year(of: date)
        switch kind {
        case .chemical: return y >= 1917 && date < chemicalStockpileDestroyed
        case .biological: return y >= 1943 && y <= 1969
        }
    }

    /// From when a destroyed stockpile can only be restarted.
    static func restartOnly(_ kind: WMDKind, on date: Date) -> Bool {
        switch kind {
        case .chemical: return date >= chemicalStockpileDestroyed
        case .biological: return GameCalendar.year(of: date) >= 1970
        }
    }

    /// Legal status of using the weapon on a date.
    static func legalStatus(_ kind: WMDKind, on date: Date) -> LegalStatus {
        let y = GameCalendar.year(of: date)
        if kind == .chemical && date >= chemicalStockpileDestroyed { return .treatyBanned }   // a restarted program breaks the CWC
        return option(kind.rawValue)?.status(in: y) ?? .legal
    }

    /// The treaty line shown next to the option.
    static func treatyLabel(_ kind: WMDKind, year: Int) -> String? {
        switch kind {
        case .chemical:
            if year >= 1997 { return "Banned by the Chemical Weapons Convention (in force 1997)" }
            if year >= 1975 { return "Restricted: Geneva Protocol (U.S. ratified 1975)" }
            if year >= 1919 { return "Restricted: Geneva Protocol 1925 (U.S. not yet a party)" }
            return nil
        case .biological:
            if year >= 1975 { return "Banned by the Biological Weapons Convention (in force 1975)" }
            if year >= 1970 { return "Restricted: renounced by the U.S. (Nov 1969)" }
            return nil
        }
    }

    /// Restart lead times. DESIGN CHOICES for the game, not published figures: a chemical program 2 years, a biological
    /// one 3 years, each with a 35% a year chance that the world finds out before it is ready.
    static func restartLeadYears(_ kind: WMDKind) -> Int { kind == .chemical ? 2 : 3 }
    static let restartDiscoveryAnnual = 0.35

    /// What using (or being caught preparing) a weapon costs, by its legal status. DESIGN CHOICES: a pre-treaty era
    /// (WWI) costs little; a treaty violation costs allies, sanctions and opens impeachment hearings.
    struct Cost: Equatable {
        var target: Int
        var world: Int
        var allies: Int
        var ruthlessness: Double
        var popularity: Double
        /// Share of U.S. output lost to sanctions.
        var sanctions: Double
        var opensImpeachment: Bool
    }

    static func cost(_ status: LegalStatus) -> Cost {
        switch status {
        case .legal: return Cost(target: 40, world: 5, allies: 0, ruthlessness: 10, popularity: 2, sanctions: 0, opensImpeachment: false)
        case .restricted: return Cost(target: 60, world: 15, allies: 10, ruthlessness: 25, popularity: 6, sanctions: 0, opensImpeachment: false)
        case .treatyBanned, .destroyed: return Cost(target: 90, world: 40, allies: 30, ruthlessness: 60, popularity: 20, sanctions: 0.03, opensImpeachment: true)
        }
    }
}

// MARK: - What the President sees

extension PresidentialAction {
    /// The WMD an action uses or restarts, if any.
    var wmd: WMDKind? {
        switch self {
        case .chemicalAttack, .restartChemical: return .chemical
        case .biologicalAttack, .restartBiological: return .biological
        default: return nil
        }
    }

    /// Shown on a date: the action's era year, nothing nuclear before Trinity, and chemical / biological options only
    /// while a stockpile exists or once it can be restarted (an attack then needs the restarted program).
    /// 3.17.0: `gs` lets a programme the President ran himself (a crude war-gas or human-subject programme, see
    /// `DirtyTactics`) put the option on the board before history did. Without it only the historical dates count.
    func isAvailable(on date: Date, in gs: GameState? = nil) -> Bool {
        let y = GameCalendar.year(of: date)
        let delivered = wmd.flatMap { gs?.shadow.wmdPrograms[$0.rawValue] }.map { $0.ready <= date } ?? false
        switch self {
        case .chemicalAttack, .biologicalAttack:
            if delivered { return true }
        default:
            break
        }
        guard eraAvailableYear <= y else { return false }
        if category == .nuclear && eraAvailableYear >= 1945 && date < ArsenalCatalog.trinity { return false }
        switch self {
        case .chemicalAttack, .biologicalAttack:
            return ArsenalCatalog.stockpileExists(wmd!, on: date) || ArsenalCatalog.restartOnly(wmd!, on: date)
        case .restartChemical, .restartBiological:
            return ArsenalCatalog.restartOnly(wmd!, on: date)
        default:
            return true
        }
    }
}

// MARK: - Engine

extension GameEngine {
    /// Why a chemical or biological order can't go ahead, or nil.
    func wmdProblem(_ action: PresidentialAction) -> String? {
        guard let kind = action.wmd, let gs = gameState else { return nil }
        let date = gs.currentDate
        guard action.isAvailable(on: date, in: gs) else { return "Not available in \(gs.currentYear)." }
        let program = gs.shadow.wmdPrograms[kind.rawValue]
        switch action {
        case .restartChemical, .restartBiological:
            if program != nil { return "A \(kind.title.lowercased()) program is already under way." }
            return nil
        default:
            if ArsenalCatalog.stockpileExists(kind, on: date) { return nil }
            guard let p = program else { return "No stockpile exists: the program must be restarted first." }
            return p.ready > date ? "The restarted program is not ready until \(GameCalendar.format(p.ready))." : nil
        }
    }

    /// Chemical or biological attack, or a program restart. Returns false (nothing happens) if not possible.
    @discardableResult
    func executeWMD(_ action: PresidentialAction, target: String) -> Bool {
        guard let kind = action.wmd, wmdProblem(action) == nil, let gs = gameState, let player = gs.getPlayerCountry() else { return false }
        let date = gs.currentDate, year = gs.currentYear
        if action == .restartChemical || action == .restartBiological {
            let ready = GameCalendar.calendar.date(byAdding: .year, value: ArsenalCatalog.restartLeadYears(kind), to: date) ?? date
            gs.shadow.wmdPrograms[kind.rawValue] = WMDProgram(kind: kind, started: date, ready: ready)
            addLog("🧪 A secret \(kind.title.lowercased()) weapons program is restarted. Ready \(GameCalendar.format(ready)).", type: .warning)
            gs.shadow.logWar("\(GameCalendar.format(date)): \(kind.title) weapons program secretly restarted.")
            logPlayEvent("wmd_program_started", detail: ["kind": kind.rawValue, "ready": PlayHistory.day(ready), "game_date": PlayHistory.day(date)])
            self.gameState = gs
            return true
        }
        guard let ti = gs.countries.firstIndex(where: { $0.id == target }), target != player.id else { return false }
        let status = ArsenalCatalog.legalStatus(kind, on: date)
        let tName = gs.countries[ti].name
        // Effects on game stats only: casualties, a weaker front line and army, shaken stability, fear.
        let severity = kind == .chemical ? 1.0 : 2.0
        gs.totalCasualties += Int(Double(max(1, gs.countries[ti].population)) * 400 * severity)
        gs.countries[ti].stability = max(0, gs.countries[ti].stability - Int(10 * severity))
        gs.countries[ti].militaryStrength = max(1, gs.countries[ti].militaryStrength - Int(5 * severity))
        gs.countries[ti].profile.anxieties.military += 30
        if let fi = gs.shadow.fronts.firstIndex(where: { $0.status == .fighting && $0.defender == target && ($0.attacker == player.id || $0.usSide == $0.attacker) }) {
            gs.shadow.fronts[fi].defenderTroops *= 1 - 0.15 * severity
            gs.shadow.fronts[fi].defenderWill = max(0, gs.shadow.fronts[fi].defenderWill - 0.1)
        }
        if !gs.countries[ti].atWarWith.contains(player.id) { declareWar(aggressor: player.id, defender: target) }
        if var p = gs.shadow.wmdPrograms[kind.rawValue] { p.discovered = true; gs.shadow.wmdPrograms[kind.rawValue] = p }
        applyWMDCost(status, kind: kind, target: target)
        let label = ArsenalCatalog.treatyLabel(kind, year: year)
        gs.shadow.post("The United States uses \(kind.title.lowercased()) weapons against \(tName).\(label.map { " \($0)." } ?? "")",
                       date: date, severity: 3)
        gs.shadow.logWar("\(GameCalendar.format(date)): \(kind.title) weapons used against \(tName) (\(status.label.lowercased())).")
        logPlayEvent("wmd_used", detail: ["kind": kind.rawValue, "target": target, "target_name": PlayHistory.text(tName),
                                          "legal_status": status.rawValue, "treaty": label ?? "", "game_date": PlayHistory.day(date)])
        self.gameState = gs
        return true
    }

    /// The diplomatic and domestic price of a weapon of this status (used on use, or when a restart is discovered).
    func applyWMDCost(_ status: LegalStatus, kind: WMDKind, target: String?) { applyTreatyCost(status, target: target) }

    /// What breaking (or bending) a treaty costs, by legal status: chemical / biological weapons (3.6.0), a claim on
    /// Antarctica (3.10.0).
    func applyTreatyCost(_ status: LegalStatus, target: String?) {
        guard let gs = gameState, let player = gs.getPlayerCountry() else { return }
        let c = ArsenalCatalog.cost(status)
        if let t = target { modifyDiplomaticRelation(from: t, to: player.id, by: -c.target) }
        for o in gs.countries where o.id != player.id && o.id != target && !o.isDestroyed && !o.isTerritory {
            modifyDiplomaticRelation(from: o.id, to: player.id, by: -(c.world + (o.alliances.contains(player.id) ? c.allies : 0)))
        }
        gs.shadow.ruthlessness += c.ruthlessness
        gs.shadow.popularity = PopularityModel.clamp(gs.shadow.popularity - c.popularity)
        if c.sanctions > 0, let pi = gs.countries.firstIndex(where: { $0.id == player.id }) {
            gs.countries[pi].gdp *= 1 - c.sanctions
            gs.shadow.post("Trading partners impose sanctions on the United States.", date: gs.currentDate, severity: 2)
        }
        if c.opensImpeachment && gs.shadow.impeachmentStage == 0 {
            gs.shadow.impeachmentStage = 1
            gs.shadow.post(PopularityModel.impeachmentText(stage: 1), date: gs.currentDate, severity: 2)
        }
        self.gameState = gs
    }

    /// Each turn: restarted programs risk discovery until they are ready.
    func processWMDPrograms() {
        guard let gs = gameState else { return }
        for (key, p) in gs.shadow.wmdPrograms where !p.discovered {
            if p.ready <= gs.currentDate { continue }
            if Double.random(in: 0..<1) < gs.scale.probability(annual: ArsenalCatalog.restartDiscoveryAnnual) {
                gs.shadow.wmdPrograms[key]?.discovered = true
                gs.shadow.post("Intelligence leaks expose a secret U.S. \(p.kind.title.lowercased()) weapons program.", date: gs.currentDate, severity: 3)
                applyWMDCost(.treatyBanned, kind: p.kind, target: nil)
                logPlayEvent("wmd_program_discovered", detail: ["kind": p.kind.rawValue, "game_date": PlayHistory.day(gs.currentDate)])
            }
        }
        self.gameState = gs
    }
}
