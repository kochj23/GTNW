//
//  Scenarios.swift
//  Global Thermal Nuclear War
//
//  Scenario definitions (start date, administration, pre-existing wars, relations, and a queue of dated scripted
//  events) plus save/load slots. Descriptions and event text are written for GTNW from the historical record.
//  The 1990 scenario can optionally refine leader personalities from the player's local Shadow Pack
//  (~/Library/Application Support/GTNW/ShadowPack/data/scenario_S0.json); nothing from that file is in this repo.
//  Repository: https://github.com/kochj23/GTNW
//

import Foundation

// MARK: - Scripted events

enum ScriptedEventKind: String, Codable {
    case news            // headline only
    case condemn         // actor denounces target (relations fall, target political anxiety rises)
    case massTroops      // actor masses troops on target's border (military anxiety)
    case invade          // actor declares war on target
    case strike          // missile/air strike: target damaged, war if not already
    case assassination   // attempt on target's leader
    case unrest          // target's internal unrest rises
    case ceasefire       // actor and target stop fighting
}

struct ScheduledEvent: Codable, Hashable, Identifiable {
    var id = UUID()
    var date: Date
    var kind: ScriptedEventKind
    var actor: String?
    var target: String?
    var text: String
    var fired = false
}

// MARK: - Scenario definitions

struct ScenarioDefinition: Identifiable {
    let id: String
    let title: String
    let summary: String
    let startDate: Date
    /// Year used to pick the historical administration and era country data.
    let eraYear: Int
    let defcon: DefconLevel
    let wars: [(String, String)]
    let relations: [(String, String, Int)]
    let events: [ScheduledEvent]
    let suggestedTurnLength: TurnLength

    var administration: Administration? {
        let all = Advisor.allAdministrations()
        return all.first { $0.startYear <= eraYear && eraYear < $0.endYear } ?? all.last { $0.startYear <= eraYear }
    }

    static func d(_ y: Int, _ m: Int, _ day: Int) -> Date { GameCalendar.date(year: y, month: m, day: day) }

    static let all: [ScenarioDefinition] = [world1990, cuba1962, ableArcher1983, modern2025]

    static func find(_ id: String) -> ScenarioDefinition? { all.first { $0.id == id } }

    /// Summer 1990: the Wall is down, the Gulf is about to ignite, the Soviet Union is wobbling.
    static let world1990 = ScenarioDefinition(
        id: "world1990",
        title: "The World in 1990",
        summary: "June 1, 1990. The Berlin Wall has fallen and the Cold War is ending — but not quietly. Ethiopia and "
            + "Somalia are still fighting, Baghdad is making threats toward Kuwait, and the Soviet republics are "
            + "restless. You have a little over two years until the next election.",
        startDate: d(1990, 6, 1), eraYear: 1990, defcon: .defcon4,
        wars: [("ETH", "SOM")],
        relations: [("IRQ", "KWT", -70), ("KWT", "IRQ", -60), ("IRQ", "ISR", -90), ("IRQ", "SAU", -40), ("USA", "IRQ", -30)],
        events: [
            ScheduledEvent(date: d(1990, 6, 20), kind: .condemn, actor: "IRQ", target: "KWT",
                           text: "Baghdad accuses Kuwait of stealing oil and flooding the market."),
            ScheduledEvent(date: d(1990, 7, 17), kind: .condemn, actor: "IRQ", target: "KWT",
                           text: "Iraq's president warns Gulf neighbours that 'cutting our necks' will not go unanswered."),
            ScheduledEvent(date: d(1990, 7, 24), kind: .massTroops, actor: "IRQ", target: "KWT",
                           text: "Satellite imagery shows Iraqi armoured divisions moving toward the Kuwaiti border."),
            ScheduledEvent(date: d(1990, 8, 2), kind: .invade, actor: "IRQ", target: "KWT",
                           text: "FLASH: Iraqi forces have crossed into Kuwait."),
            ScheduledEvent(date: d(1990, 8, 19), kind: .unrest, actor: nil, target: "RUS",
                           text: "Strikes and independence rallies spread across several Soviet republics."),
            ScheduledEvent(date: d(1990, 9, 15), kind: .massTroops, actor: "IRQ", target: "SAU",
                           text: "Iraqi units dig in along the Saudi border."),
            ScheduledEvent(date: d(1990, 11, 29), kind: .news, actor: nil, target: "IRQ",
                           text: "The UN Security Council sets a deadline for Iraq to leave Kuwait."),
            ScheduledEvent(date: d(1991, 1, 18), kind: .strike, actor: "IRQ", target: "ISR",
                           text: "Missiles fired from Iraq strike Israeli cities."),
            ScheduledEvent(date: d(1991, 8, 19), kind: .unrest, actor: nil, target: "RUS",
                           text: "Tanks in Moscow: hardliners attempt to seize power from the Soviet leadership."),
            ScheduledEvent(date: d(1991, 12, 8), kind: .news, actor: nil, target: "RUS",
                           text: "Leaders of three Soviet republics declare the Union finished."),
        ],
        suggestedTurnLength: .week)

    static let cuba1962 = ScenarioDefinition(
        id: "cuba1962",
        title: "Thirteen Days, 1962",
        summary: "October 16, 1962. Reconnaissance photos show Soviet missile sites under construction in Cuba. "
            + "Get them out without starting the war everyone fears.",
        startDate: d(1962, 10, 16), eraYear: 1962, defcon: .defcon3,
        wars: [],
        relations: [("USA", "RUS", -80), ("USA", "CUB", -90), ("CUB", "USA", -90), ("RUS", "USA", -75)],
        events: [
            ScheduledEvent(date: d(1962, 10, 22), kind: .news, actor: nil, target: "CUB",
                           text: "The world waits as Soviet freighters steam toward Cuba."),
            ScheduledEvent(date: d(1962, 10, 24), kind: .massTroops, actor: "RUS", target: "USA",
                           text: "Soviet submarines are shadowing the quarantine line."),
            ScheduledEvent(date: d(1962, 10, 27), kind: .strike, actor: "CUB", target: "USA",
                           text: "A U.S. reconnaissance plane has been shot down over Cuba."),
        ],
        suggestedTurnLength: .day)

    static let ableArcher1983 = ScenarioDefinition(
        id: "ablearcher1983",
        title: "Able Archer, 1983",
        summary: "November 1983. A NATO command exercise looks, from Moscow, a lot like the real thing. "
            + "Soviet early-warning crews are jumpy. Keep the exercise an exercise.",
        startDate: d(1983, 11, 2), eraYear: 1983, defcon: .defcon3,
        wars: [("RUS", "AFG")],
        relations: [("USA", "RUS", -70), ("RUS", "USA", -80)],
        events: [
            ScheduledEvent(date: d(1983, 11, 7), kind: .massTroops, actor: "RUS", target: "DEU",
                           text: "Soviet air units in East Germany are placed on heightened alert."),
            ScheduledEvent(date: d(1983, 11, 9), kind: .news, actor: nil, target: "RUS",
                           text: "Moscow cables its stations: look for signs of a Western surprise attack."),
        ],
        suggestedTurnLength: .day)

    static let modern2025 = ScenarioDefinition(
        id: "modern2025",
        title: "The World Today",
        summary: "January 20, 2025. Wars in Europe and the Middle East, a rising rival in the Pacific, and an "
            + "electorate that wants results.",
        startDate: d(2025, 1, 20), eraYear: 2025, defcon: .defcon4,
        wars: [("RUS", "UKR")],
        relations: [("USA", "RUS", -60), ("USA", "CHN", -30)],
        events: [],
        suggestedTurnLength: .month)
}

// MARK: - Applying a scenario

enum ScenarioLoader {
    /// Build a fresh GameState for a scenario.
    static func makeGameState(_ s: ScenarioDefinition, difficulty: DifficultyLevel = .normal,
                              turnLength: TurnLength? = nil, packFolder: URL? = ShadowPack.shared.isInstalled ? ShadowPack.shared.folder : nil) -> GameState {
        let gs = GameState(playerCountryID: "USA", difficultyLevel: difficulty, administration: s.administration,
                           turnLength: turnLength ?? s.suggestedTurnLength, startDate: s.startDate)
        apply(s, to: gs, packFolder: packFolder)
        return gs
    }

    static func apply(_ s: ScenarioDefinition, to gs: GameState, packFolder: URL?) {
        gs.eraStartYear = s.eraYear
        gs.defconLevel = s.defcon
        gs.shadow.scenarioID = s.id
        for (a, b) in s.wars where gs.getCountry(id: a) != nil && gs.getCountry(id: b) != nil {
            gs.activeWars.append(War(aggressor: a, defender: b, startTurn: 0))
            if let i = gs.countries.firstIndex(where: { $0.id == a }) { gs.countries[i].atWarWith.insert(b) }
            if let i = gs.countries.firstIndex(where: { $0.id == b }) { gs.countries[i].atWarWith.insert(a) }
            gs.setRelation(from: a, to: b, value: -90)
            gs.setRelation(from: b, to: a, value: -90)
        }
        for (a, b, v) in s.relations { gs.setRelation(from: a, to: b, value: v) }
        gs.shadow.eventQueue = s.events.filter { e in
            [e.actor, e.target].compactMap { $0 }.allSatisfy { gs.getCountry(id: $0) != nil }
        }
        if s.id == "world1990", let folder = packFolder {
            applyPackPersonalities(from: folder.appendingPathComponent("data/scenario_S0.json"), to: gs)
        }
    }

    /// Old-name → ISO3 aliases for the pack's 1990 country names.
    static let aliases: [String: String] = [
        "ussr": "RUS", "soviet union": "RUS", "united states": "USA", "usa": "USA", "united kingdom": "GBR", "uk": "GBR",
        "west germany": "DEU", "germany, west": "DEU", "north korea": "PRK", "korea, north": "PRK", "south korea": "KOR",
        "korea, south": "KOR", "china": "CHN", "iran": "IRN", "iraq": "IRQ", "kuwait": "KWT", "israel": "ISR",
        "saudi arabia": "SAU", "ethiopia": "ETH", "somalia": "SOM", "japan": "JPN", "france": "FRA", "india": "IND",
        "pakistan": "PAK", "cuba": "CUB", "egypt": "EGY", "syria": "SYR", "libya": "LBY", "jordan": "JOR",
    ]

    /// Map a generic ideology label onto GTNW's ideology list.
    static func ideologyFromLabel(_ label: String) -> LeaderIdeology? {
        let l = label.lowercased()
        if l.contains("commun") { return .communism }
        if l.contains("fundamental") { return .theocracy }
        if l.contains("islam") { return .islamicRepublic }
        if l.contains("imperial") { return .expansionism }
        if l.contains("fascis") || l.contains("national") { return .nationalism }
        if l.contains("central") { return .oneParty }
        if l.contains("socialis") { return l.contains("democ") ? .socialDemocracy : .oneParty }
        if l.contains("developing") { return .developingDemocracy }
        if l.contains("capital") || l.contains("democ") { return .liberalDemocracy }
        if l.contains("monarch") { return .absoluteMonarchy }
        return nil
    }

    /// Refine ambition/ethic/anxieties from the local pack's 1990 data, when the player has built the pack.
    @discardableResult
    static func applyPackPersonalities(from url: URL, to gs: GameState) -> Int {
        guard let data = try? Data(contentsOf: url),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rows = root["countries"] as? [[String: Any]] else { return 0 }
        var applied = 0
        for row in rows {
            guard let name = (row["name"] as? String)?.lowercased() else { continue }
            let id = aliases[name] ?? gs.countries.first { $0.name.lowercased() == name }?.id
            guard let cid = id, let i = gs.countries.firstIndex(where: { $0.id == cid }) else { continue }
            var p = gs.countries[i].profile
            if let a = row["Ambition"] as? Double { p.ambition = min(6, max(1, Int(a.rounded()))) }
            if let e = row["Ethic"] as? Double { p.ethic = min(6, max(1, Int(e.rounded()))) }
            let keys: [(String, ThreatAnxieties.Kind)] = [("NTA_nuclear_threat_anxiety", .nuclear), ("MTA_military_threat_anxiety", .military),
                                                          ("PTA_political_threat_anxiety", .political), ("ETA_economic_threat_anxiety", .economic),
                                                          ("STA_social_threat_anxiety", .social)]
            for (k, kind) in keys { if let v = row[k] as? Double { p.anxieties[kind] = v } }
            if let ideology = (row["Ideology"] as? String).flatMap(ideologyFromLabel) { p.ideology = ideology }
            gs.countries[i].profile = p
            applied += 1
        }
        return applied
    }
}

// MARK: - Save slots

struct SaveSlotInfo: Identifiable, Equatable {
    let slot: Int
    let label: String
    let modified: Date
    var id: Int { slot }
}

/// JSON save slots under Application Support/GTNW/Saves. Slot 0 is the autosave.
/// This folder is the on-device cache of the slots; `GameStoreService` syncs it with the Games DB
/// (see `Shared/Storage/`). Every load is size-capped and validated by `SaveCodec`.
struct SaveManager {
    let folder: URL
    static let slotCount = 5

    static var defaultFolder: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("GTNW/Saves", isDirectory: true)
    }

    init(folder: URL = SaveManager.defaultFolder) { self.folder = folder }

    func url(slot: Int) -> URL { folder.appendingPathComponent(slot == 0 ? "autosave.json" : "slot\(slot).json") }

    func save(_ gs: GameState, slot: Int) throws {
        try write(SaveCodec.encode(gs), slot: slot, modified: nil)
    }

    /// Write raw (already validated) payload bytes, optionally stamping the modification date (used when pulling from the DB).
    func write(_ data: Data, slot: Int, modified: Date?) throws {
        guard StoreValidation.slotRange.contains(slot) else { throw GameStoreError.invalid("slot \(slot) out of range") }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try data.write(to: url(slot: slot), options: .atomic)
        if let modified { try FileManager.default.setAttributes([.modificationDate: modified], ofItemAtPath: url(slot: slot).path) }
    }

    /// Raw bytes of a slot, refusing anything over the payload cap before reading it.
    func data(slot: Int) throws -> Data {
        let u = url(slot: slot)
        let size = (try FileManager.default.attributesOfItem(atPath: u.path)[.size] as? NSNumber)?.intValue ?? 0
        guard size <= StoreValidation.maxPayloadBytes else { throw GameStoreError.invalid("save file is \(size) bytes") }
        return try Data(contentsOf: u)
    }

    func modified(slot: Int) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: url(slot: slot).path))?[.modificationDate] as? Date
    }

    func load(slot: Int) throws -> GameState {
        try Self.decode(data(slot: slot))
    }

    /// Validated decode (size cap, JSON, sanity checks). Use this for anything read from disk or the network.
    static func decode(_ data: Data) throws -> GameState { try SaveCodec.decode(data) }

    /// Decode a save, accepting both ISO-8601 dates (current) and the default numeric encoding. No validation.
    static func decodeUnchecked(_ data: Data) throws -> GameState {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        if let gs = try? dec.decode(GameState.self, from: data) { return gs }
        return try JSONDecoder().decode(GameState.self, from: data)
    }

    func list() -> [SaveSlotInfo] {
        (0...Self.slotCount).compactMap { slot in
            guard let mod = modified(slot: slot) else { return nil }
            var label = slot == 0 ? "Autosave" : "Slot \(slot)"
            if let gs = try? load(slot: slot) {
                label += " — \(gs.currentDateLabel), turn \(gs.turn)"
            }
            return SaveSlotInfo(slot: slot, label: label, modified: mod)
        }
    }

    func delete(slot: Int) { try? FileManager.default.removeItem(at: url(slot: slot)) }
}
