//
//  Renaming.swift
//  Global Thermal Nuclear War
//
//  3.36.0: rename at will. The President may rename his own country (its name everywhere: the map, the logs, the
//  news, the scoreboard, the chief of staff) and any land he holds (a territory: annexed, claimed, bought or seized),
//  any time, at no action cost, from the Situation Room, the command box or the chief of staff. Every name passes
//  `NameScreen`. Names have consequences: the people of a renamed land react (a mocking or gibberish name costs more
//  than a dignified one), and the nations that matter recognize the new name or refuse it. Every name is also
//  written to the Hall of Cartography (`CartographyHall`), a record kept across games.
//
//  `RenameTarget` is what can be renamed: a country (the President's own, or a land he holds), a sea or mountain, a
//  department (MapFeatures.swift). A new kind (a state or province) is a new case: give it its current name, its real
//  name, its holder check and how to apply the name in the switches below.
//  Repository: https://github.com/kochj23/GTNW
//

import Foundation

/// Something the President can rename.
enum RenameTarget: Hashable, Codable, Sendable {
    /// A country on the board: the President's own nation, or a land he holds (its `territoryOf` is the player).
    case country(String)
    /// A sea, gulf, strait, canal, mountain or range (MapFeatures.swift): the President's maps use his name.
    case feature(String)
    /// One of the President's own departments or ministries (MapFeatures.swift): his government uses his name.
    case department(String)
    /// 3.36.0: a state or province he holds (Subdivisions.swift): renamed like a place, its people mind (unrest there,
    /// and votes in a U.S. state).
    case province(String)

    /// The target an id means: a map feature, a department, else a country.
    static func from(id: String, in gs: GameState) -> RenameTarget {
        if MapFeatures.feature(id) != nil { return .feature(id) }
        if Departments.department(id) != nil { return .department(id) }
        if Subdivisions.byID[id] != nil { return .province(id) }
        return .country(id)
    }

    var id: String {
        switch self {
        case .country(let id), .feature(let id), .department(let id), .province(let id): return id
        }
    }

    /// Renamed as a place, not a nation (a sea, a mountain, a department, a state or province).
    var isPlace: Bool { if case .country = self { return false }; return true }

    /// The record's kind: "nation" (the President's own), "land" (a land he holds), "feature", "department".
    func kind(in gs: GameState) -> String {
        switch self {
        case .country(let id): return id == gs.playerCountryID ? "nation" : "land"
        case .feature: return "feature"
        case .department: return "department"
        case .province: return "province"
        }
    }

    /// The name it goes by now.
    func currentName(in gs: GameState) -> String? {
        switch self {
        case .country(let id): return gs.getCountry(id: id)?.name
        case .feature(let id): return MapFeatures.feature(id).map { MapFeatures.shownName($0, in: gs) }
        case .department(let id): return Departments.department(id).map { Departments.shownName($0, in: gs) }
        case .province(let id): return Subdivisions.byID[id] != nil ? gs.provinceName(id) : nil
        }
    }

    /// Its real name: a land's before the President's first rename, a feature's in this year, a department's in law.
    func realName(in gs: GameState) -> String {
        switch self {
        case .country(let id): return gs.realName(of: id)
        case .feature(let id): return MapFeatures.feature(id)?.name(in: gs.currentYear) ?? id
        case .department(let id): return Departments.department(id)?.name ?? id
        case .province(let id): return Subdivisions.byID[id].map { Subdivisions.historical($0, on: gs.currentDate).name } ?? id
        }
    }

    /// Is it the President's to rename? His own nation, a land he holds that still stands, a feature on this year's
    /// map, or a department of his government this year.
    func isHeld(in gs: GameState) -> Bool {
        switch self {
        case .country(let id):
            guard let c = gs.getCountry(id: id), !c.isDestroyed else { return false }
            return id == gs.playerCountryID || c.territoryOf == gs.playerCountryID
        case .feature(let id): return MapFeatures.feature(id)?.exists(in: gs.currentYear) ?? false
        case .department(let id): return Departments.current(in: gs).contains { $0.id == id }
        case .province(let id): return gs.provinceOwner(id) == gs.playerCountryID
        }
    }

    /// Does anybody live there to mind the name?
    func isInhabited(in gs: GameState) -> Bool {
        switch self {
        case .country(let id): return id != Antarctica.id && !Islands.uninhabited(id)
        case .province: return true
        case .feature, .department: return false
        }
    }
}

/// What a rename came to.
enum RenameOutcome: Equatable, Sendable {
    case renamed(from: String, to: String)
    /// The same name again: nothing changes.
    case unchanged
    case refused(String)

    var succeeded: Bool { if case .refused = self { return false }; return true }
}

extension GameState {
    /// The land's real name: the name it had before the President's first rename, else its modern map name.
    func realName(of id: String) -> String {
        if let first = shadow.renames.first(where: { $0.land == id }), !NameScreen.isBlocked(first.from) { return first.from }
        return WorldCountriesDatabase.template(id: id)?.name ?? id
    }

    /// Everything the President may rename: his own nation first, then the lands he holds, by name.
    var renamableTargets: [RenameTarget] {
        let lands = countries.filter { $0.territoryOf == playerCountryID && !$0.isDestroyed }.sorted { $0.name < $1.name }
        return [RenameTarget.country(playerCountryID)] + lands.map { .country($0.id) }
    }

    /// 3.36.0: an old save may hold a name the content rules now refuse. It is shown as the land's real name (and the
    /// news, war log and name book say the same); nothing else in the game changes.
    func repairBlockedNames() {
        var swaps: [(String, String)] = []
        for i in countries.indices where NameScreen.isBlocked(countries[i].name) {
            let real = NameScreen.shown(realName(of: countries[i].id), fallback: countries[i].id)
            swaps.append((countries[i].name, real))
            countries[i].name = real
        }
        for i in shadow.renames.indices {
            let real = NameScreen.shown(realName(of: shadow.renames[i].land), fallback: shadow.renames[i].land)
            for k in [\RenameRecord.from, \RenameRecord.to] where NameScreen.isBlocked(shadow.renames[i][keyPath: k]) {
                swaps.append((shadow.renames[i][keyPath: k], real))
                shadow.renames[i][keyPath: k] = real
            }
        }
        guard !swaps.isEmpty else { return }
        func scrub(_ s: String) -> String { swaps.reduce(s) { $0.replacingOccurrences(of: $1.0, with: $1.1) } }
        for i in shadow.ticker.indices { shadow.ticker[i].text = scrub(shadow.ticker[i].text) }
        shadow.warLog = shadow.warLog.map(scrub)
    }
}

extension GameEngine {
    /// Why the target can't take this name, or nil (and the name as it will be stored). Read-only.
    func renameCheck(_ t: RenameTarget, to raw: String) -> (name: String?, refusal: String?) {
        guard let gs = gameState else { return (nil, "Start a game first.") }
        if gs.gameOver { return (nil, "The game is over.") }
        guard t.isHeld(in: gs) else {
            return (nil, t.isPlace ? "Nothing by that name to rename in \(gs.currentYear)." : "You can rename your own country and the lands you hold.")
        }
        switch NameScreen.check(raw) {
        case .ok(let n): return (n, nil)
        case .invalid(let r), .blocked(let r): return (nil, r)
        }
    }

    /// Rename the President's country or a land he holds. No action is spent. The people react and the world takes
    /// a position; both are small and drawn from the game's seeded RNG.
    @discardableResult
    func rename(_ t: RenameTarget, to raw: String) -> RenameOutcome {
        let check = renameCheck(t, to: raw)
        guard let gs = gameState, let name = check.name, let old = t.currentName(in: gs) else {
            return .refused(check.refusal ?? "That can't be renamed.")
        }
        guard name != old else { return .unchanged }
        let kind = t.kind(in: gs)
        let tone = NameScreen.tone(name)
        if t.isPlace {
            // A sea, mountain or department: its own news, shore nations and Congress (MapFeatures.swift).
            applyPlaceName(t.id, name)
            gs.shadow.renames.append(RenameRecord(land: t.id, from: old, to: name, date: gs.currentDate))
            if gs.shadow.renames.count > 500 { gs.shadow.renames.removeFirst(gs.shadow.renames.count - 500) }
            addLog("🗺️ \(old) is now \(name).", type: .info)
            CartographyHall.record(t, kind: kind, from: old, to: name, in: gs)
            self.gameState = gs
            return .renamed(from: old, to: name)
        }
        guard let i = gs.countries.firstIndex(where: { $0.id == t.id }) else { return .refused("That can't be renamed.") }
        gs.countries[i].name = name
        gs.shadow.renames.append(RenameRecord(land: t.id, from: old, to: name, date: gs.currentDate))   // 3.29.0: the Names tab
        if gs.shadow.renames.count > 500 { gs.shadow.renames.removeFirst(gs.shadow.renames.count - 500) }
        if kind == "nation" {
            gs.shadow.post("By order of the President, \(old) is now \(name).", date: gs.currentDate, severity: 1)
        } else {
            gs.shadow.post("\(old) is renamed \(name) by order of the President.", date: gs.currentDate, severity: 1)
        }
        gs.shadow.logWar("\(GameCalendar.format(gs.currentDate)): \(old) renamed \(name).")
        addLog("🗺️ \(old) is now \(name).", type: .info)
        let reaction = nameConsequences(t, old: old, new: name, tone: tone)
        logPlayEvent("renamed_territory", detail: ["land": t.id, "kind": kind, "old_name": PlayHistory.text(old), "name": PlayHistory.text(name),
                                                   "tone": tone.label, "recognized": reaction.recognized, "refused": reaction.refused,
                                                   "game_date": PlayHistory.day(gs.currentDate)])
        CartographyHall.record(t, kind: kind, from: old, to: name, in: gs)
        self.gameState = gs
        if t.id == Antarctica.id { antarcticaRenamed(to: name) }   // 3.36.0: the penguins were not consulted
        return .renamed(from: old, to: name)
    }

    /// The people's reaction and the world's recognition. Returns how many nations recognized and refused.
    @discardableResult
    func nameConsequences(_ t: RenameTarget, old: String, new: String, tone: NameTone) -> (recognized: Int, refused: Int) {
        guard let gs = gameState, let me = gs.getPlayerCountry() else { return (0, 0) }
        let restored = new == t.realName(in: gs)
        let step = tone.rawValue   // 0 dignified, 1 silly, 2 mocking
        // The people.
        if case .country(let id) = t, let i = gs.countries.firstIndex(where: { $0.id == id }) {
            if id == gs.playerCountryID {
                let hit = [0.5, 2.0, 4.0][step] + Double.random(in: 0..<1, using: &gs.rng)
                gs.shadow.popularity = max(0, min(100, gs.shadow.popularity - (restored ? 0 : hit)))
                if step > 0 { gs.shadow.post("Polls: the public is not sure what to call its own country.", date: gs.currentDate) }
            } else if t.isInhabited(in: gs) {
                if restored {
                    gs.countries[i].stability = min(100, gs.countries[i].stability + 2)
                    gs.countries[i].profile.outcry = max(0, gs.countries[i].profile.outcry - 3)
                } else {
                    let hit = [1, 3, 6][step] + Int.random(in: 0...1, using: &gs.rng)
                    gs.countries[i].stability = max(1, gs.countries[i].stability - hit)
                    gs.countries[i].profile.outcry = min(100, gs.countries[i].profile.outcry + Double([2, 5, 10][step]))
                    if step > 0 { gs.shadow.post("Crowds in \(new) tear down the new signs.", date: gs.currentDate) }
                }
            }
        }
        // The world: the great powers and the land's neighbors decide whether to use the new name.
        let region = gs.getCountry(id: t.id)?.region
        let independent = gs.countries.filter { !$0.isDestroyed && $0.territoryOf == nil && $0.id != me.id }
        let powers = independent.sorted { $0.powerScore != $1.powerScore ? $0.powerScore > $1.powerScore : $0.id < $1.id }.prefix(5)
        let neighbors = independent.filter { $0.region == region }.sorted { $0.id < $1.id }.prefix(5)
        let observers = Array(Set(powers.map(\.id) + neighbors.map(\.id))).sorted()
        var yes: [String] = [], no: [String] = []
        for id in observers {
            guard let o = gs.getCountry(id: id) else { continue }
            let rel = Double(o.diplomaticRelations[me.id] ?? 0)
            let p = max(0.05, min(0.95, 0.55 + rel / 200 - [0, 0.15, 0.35][step] + (restored ? 0.3 : 0)))
            if Double.random(in: 0..<1, using: &gs.rng) < p {
                yes.append(o.name)
                if step == 0 { modifyDiplomaticRelation(from: id, to: me.id, by: 1) }
            } else {
                no.append(o.name)
                modifyDiplomaticRelation(from: id, to: me.id, by: -[1, 2, 3][step])
            }
        }
        func list(_ n: [String]) -> String {
            n.count <= 3 ? n.joined(separator: ", ") : n.prefix(3).joined(separator: ", ") + " and \(n.count - 3) more"
        }
        if !yes.isEmpty || !no.isEmpty {
            var line = ""
            if !yes.isEmpty { line += "\(list(yes)) recognize\(yes.count == 1 ? "s" : "") the name \(new)" }
            if !no.isEmpty { line += (line.isEmpty ? "" : "; ") + "\(list(no)) refuse\(no.count == 1 ? "s" : "") to use it" }
            gs.shadow.post(line + ".", date: gs.currentDate)
        }
        self.gameState = gs
        return (yes.count, no.count)
    }
}
