//
//  RenamePlanner.swift
//  Global Thermal Nuclear War
//
//  3.36.0: the command box's and the chief of staff's RENAME card. "rename Kenya to New Albion", "rename my country
//  to Freedonia", "rename the Gulf of Mexico to …", or (from the chief of staff) up to `CommandParser.maxRenames`
//  renames on one card. Each target is resolved against the game's names, must be the President's own country, a land
//  he holds, a sea, strait or mountain on this year's map or one of his departments, and each name passes
//  `NameScreen`; a bulk card leaves out what can't be renamed and says so. Renames spend no action. Read-only.
//  3.37.0: one typed rename may name many places: "rename all of Africa to X" (the lands he holds there), "rename all
//  my states to X", "rename Texas, Ohio and Iowa to X". One name for many places numbers them (X, X 2, X 3…); one
//  name the content check refuses blocks the whole card; at most `CommandParser.maxRegionTargets` on one card.
//  Repository: https://github.com/kochj23/GTNW
//

import Foundation

extension GameEngine {
    /// The rename target a typed name means, or why there is none.
    func renameTarget(_ raw: String, in gs: GameState) -> (target: RenameTarget?, refusal: String?) {
        let n = CommandParser.normalize(raw)
        if n.isEmpty { return (nil, "Name the land to rename, for example \"rename Kenya to New Albion\".") }
        if n == "me" || CommandParser.selfNames.contains(n) || CommandParser.normalize(gs.getPlayerCountry()?.name ?? "") == n {
            return (.country(gs.playerCountryID), nil)
        }
        // A sea, strait, mountain or department (MapFeatures.swift).
        if let f = MapFeatures.match(raw, in: gs) { return (.feature(f.id), nil) }
        if let d = Departments.match(raw, in: gs) { return (.department(d.id), nil) }
        let notYours = "You can rename your own country and the lands you hold."
        // 3.36.0: a state or province (before the nation resolver, which would hand back the nation that holds it).
        if let p = CommandTargets.state(raw, in: gs) {
            let r = RenameTarget.province(p.id)
            return r.isHeld(in: gs) ? (r, nil) : (nil, "\(gs.provinceName(p.id)) isn't yours to rename. You can rename the states and provinces you hold.")
        }
        switch CommandTargets.resolve(raw, in: gs) {
        case .one(let t, _):
            let r = RenameTarget.country(t.id)
            return r.isHeld(in: gs) ? (r, nil) : (nil, "\(CommandTargets.label(t, in: gs)) isn't yours to rename. \(notYours)")
        case .many(let options):
            let held = options.map { RenameTarget.country($0.id) }.filter { $0.isHeld(in: gs) }
            if held.count == 1 { return (held[0], nil) }
            return (nil, "Which one? \(options.map { CommandTargets.label($0, in: gs) }.joined(separator: ", ")).")
        case .none:
            return (nil, "No land called \"\(String(raw.prefix(40)))\" in \(gs.currentYear).")
        }
    }

    /// The RENAME card for one or more renames. 3.37.0: one request may name several places (a region, "all my
    /// states", "all my territories", or a list: "Texas, Ohio and Iowa"); each gets a name of its own from the one
    /// typed (`RenameGroups.numbered`), and one name the content check refuses blocks the whole card.
    func planRenames(_ intent: CommandIntent, source: CommandSource) -> CommandOutcome {
        guard let gs = gameState else { return .rejected("Start a game first.") }
        // `.renamePlace` (the power-plays card) carries one target and the new name in `detail`.
        let single = intent.targets.first.map { [RenameRequest(target: $0, name: intent.detail ?? "")] } ?? []
        let asked = Array((intent.renames ?? single).prefix(CommandParser.maxRenames))
        guard !asked.isEmpty else {
            return .rejected("Say what to rename and the new name, for example \"rename Kenya to New Albion\" or \"rename my country to Freedonia\".")
        }
        var plan = CommandPlan(title: CommandVerb.rename.title, target: "", orders: [], committed: [], heldBack: [], warnings: [],
                               actionsNeeded: 0, actionsLeft: gs.actionsRemaining, source: source)
        var left: [String] = []
        var groupLeft: [String] = []
        var firstRefusal: String?
        var seen = Set<String>()
        var numberedExample: (first: String, base: String)?
        // Each request as the places it names: (target, name, strict). A strict name (one of a group's) that the content
        // check refuses blocks the card.
        var jobs: [(target: RenameTarget, name: String, strict: Bool)] = []
        var overCap = 0
        for r in asked {
            guard let g = renameGroup(r.target, in: gs) else {
                let (target, refusal) = renameTarget(r.target, in: gs)
                guard let target else { firstRefusal = firstRefusal ?? refusal; left.append(String(r.target.prefix(40))); continue }
                jobs.append((target, r.name, false))
                continue
            }
            groupLeft += g.left
            if g.targets.isEmpty { firstRefusal = firstRefusal ?? g.refusal; continue }
            var fresh: [RenameTarget] = []
            for t in g.targets where !fresh.contains(t) && !jobs.contains(where: { $0.target == t }) { fresh.append(t) }
            let room = max(0, CommandParser.maxRegionTargets - jobs.count)
            overCap += max(0, fresh.count - room)
            for (t, n) in zip(fresh.prefix(room), RenameGroups.names(r.name, count: min(room, fresh.count))) { jobs.append((t, n, true)) }
            if fresh.count > 1, numberedExample == nil, case .ok(let n) = NameScreen.check(r.name) {
                numberedExample = (fresh[0].currentName(in: gs) ?? fresh[0].id, n)
            }
        }
        for j in jobs {
            let target = j.target
            let old = target.currentName(in: gs) ?? target.id
            let check = renameCheck(target, to: j.name)
            guard let name = check.name else {
                if j.strict { return .rejected(check.refusal ?? NameScreen.blockedReason) }   // one bad name blocks them all
                firstRefusal = firstRefusal ?? check.refusal; left.append(old); continue
            }
            guard !seen.contains(target.id) else { continue }
            seen.insert(target.id)
            if name == old { plan.heldBack.append("\(old) keeps its name."); continue }
            plan.orders.append(GameOrder(kind: .rename, target: target.id, detail: name))
            plan.committed.append("\(old) → \(name)")
            if target.isPlace {
                plan.warnings += renamePlaceWarnings(target.id).map { CommandWarning(text: "\($0.who): \($0.text)", level: $0.level) }
                continue
            }
            let tone = NameScreen.tone(name)
            let own = target.id == gs.playerCountryID
            switch tone {
            case .mocking:
                plan.warnings.append(CommandWarning(text: own ? "The voters will not like being the butt of the joke: approval falls."
                                                        : "Its people will take \(name) as an insult: unrest rises and most capitals refuse the name.", level: 1))
            case .silly:
                plan.warnings.append(CommandWarning(text: "Nobody can pronounce \(name). Expect grumbling and a few capitals refusing it.", level: 0))
            case .dignified:
                break
            }
        }
        if asked.count == 1, plan.orders.isEmpty, let firstRefusal { return .rejected(firstRefusal) }
        if plan.orders.isEmpty { return .rejected(firstRefusal ?? (plan.heldBack.first ?? "Nothing to rename.")) }
        if let ex = numberedExample {
            plan.warnings.insert(CommandWarning(text: "One name for many places: \(ex.first) becomes \(ex.base), the next \(ex.base) 2, then \(ex.base) 3 "
                                                + "and so on, so each keeps a name of its own.", level: 0), at: 0)
        }
        if !left.isEmpty {
            plan.warnings.append(CommandWarning(text: "Left out: \(left.joined(separator: ", ")). \(firstRefusal ?? "")", level: 1))
        }
        for g in groupLeft { plan.warnings.append(CommandWarning(text: "Left out: \(g)", level: 1)) }
        if overCap > 0 {
            plan.warnings.append(CommandWarning(text: "Left out: \(overCap) more past the limit of \(CommandParser.maxRegionTargets) renames on one card.", level: 1))
        }
        plan.warnings.append(CommandWarning(text: "Renaming spends no action. Other nations decide whether to use the new name.", level: 0))
        plan.warnings = plan.warnings.reduce(into: []) { if !$0.contains($1) { $0.append($1) } }
        let names = plan.orders.map { RenameTarget.from(id: $0.target, in: gs).currentName(in: gs) ?? $0.target }
        plan.target = (names.count > 8 ? names.prefix(8).joined(separator: ", ") + " and \(names.count - 8) more" : names.joined(separator: ", "))
            + ", \(gs.currentYear)"
        return .plan(plan)
    }

    /// 3.37.0: what a rename request naming several places means, or nil when it names one place (or nothing the
    /// game knows, which `renameTarget` explains). `left` says what was left out and why.
    func renameGroup(_ raw: String, in gs: GameState) -> (targets: [RenameTarget], left: [String], refusal: String?)? {
        let whole = CommandParser.normalize(raw)
        if let kind = RenameGroups.kind(whole, bareRegion: false) { return expandRenameGroup(kind, in: gs) }
        if renameNameKnown(raw, in: gs) { return nil }
        if let kind = RenameGroups.kind(whole, bareRegion: true) { return expandRenameGroup(kind, in: gs) }
        // A list: commas, then "and" inside a piece the game doesn't know whole ("Trinidad and Tobago" stays one).
        var pieces: [String] = []
        for part in raw.split(separator: ",").map({ String($0).trimmingCharacters(in: .whitespaces) }) {
            var p = CommandParser.normalize(part)
            if p.hasPrefix("and ") { p = String(p.dropFirst(4)) }
            guard !p.isEmpty else { continue }
            if RenameGroups.kind(p, bareRegion: false) != nil || renameNameKnown(p, in: gs) { pieces.append(p); continue }
            pieces += p.components(separatedBy: " and ").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        }
        guard pieces.count > 1 else { return nil }
        var out: [RenameTarget] = [], left: [String] = []
        for p in pieces.prefix(CommandParser.maxRegionTargets) {
            if let kind = RenameGroups.kind(p, bareRegion: true) {
                let g = expandRenameGroup(kind, in: gs)
                out += g.targets
                left += g.left + (g.targets.isEmpty ? g.refusal.map { [$0] } ?? [] : [])
                continue
            }
            let (t, why) = renameTarget(p, in: gs)
            if let t { out.append(t) } else { left.append(why ?? "\(String(p.prefix(40))): not a land you hold.") }
        }
        return (out, left, out.isEmpty ? (left.first ?? "Nothing on that list is yours to rename.") : nil)
    }

    /// The name is something `renameTarget` would place on its own (yours or not).
    private func renameNameKnown(_ raw: String, in gs: GameState) -> Bool {
        let n = CommandParser.normalize(raw)
        return n == "me" || CommandParser.selfNames.contains(n) || MapFeatures.match(raw, in: gs) != nil || Departments.match(raw, in: gs) != nil
            || CommandTargets.state(raw, in: gs) != nil || CommandTargets.resolve(raw, in: gs) != .none
    }

    /// The places a group phrase covers, only those the President may rename, and what was left out and why.
    func expandRenameGroup(_ kind: RenameGroups.Kind, in gs: GameState) -> (targets: [RenameTarget], left: [String], refusal: String?) {
        let me = gs.playerCountryID, year = gs.currentYear
        switch kind {
        case .provinces:
            let held = gs.renamableProvinces.map { RenameTarget.province($0.id) }
            return (held, [], held.isEmpty ? "You hold no states or provinces in \(year)." : nil)
        case .lands:
            let held = Array(gs.renamableTargets.dropFirst())
            return (held, [], held.isEmpty ? "You hold no lands beyond your own country in \(year)." : nil)
        case .region(let r):
            let lands = gs.countries.filter { $0.territoryOf == me && !$0.isDestroyed && $0.region == r }.sorted { $0.name < $1.name }
                .map { RenameTarget.country($0.id) }
            let provinces = gs.renamableProvinces.filter { s in
                gs.provinceHomeNation(s.id) != me && (WorldCountriesDatabase.template(id: s.nation)?.region ?? gs.getCountry(id: s.nation)?.region) == r
            }.map { RenameTarget.province($0.id) }
            let others = CommandTargets.regionMembers(r, in: gs).map { CommandTargets.label($0, in: gs) }
            var left: [String] = []
            if !others.isEmpty {
                let shown = others.count <= 4 ? others.joined(separator: ", ") : others.prefix(3).joined(separator: ", ") + " and \(others.count - 3) more"
                left.append("\(shown) in \(r.rawValue): \(others.count == 1 ? "a nation" : "nations") of \(others.count == 1 ? "its" : "their") own, not yours to rename.")
            }
            if gs.getPlayerCountry()?.region == r {
                left.append("\(gs.getPlayerCountry()?.name ?? me), your own country: rename it on its own.")
            }
            let held = lands + provinces
            return (held, left, held.isEmpty ? "You hold no land in \(r.rawValue) to rename in \(year). You can rename your own country and the lands you hold." : nil)
        }
    }
}

/// 3.37.0: the phrases that name several places in one rename, and how one name covers many.
enum RenameGroups {
    enum Kind: Equatable {
        /// "all my states", "my provinces": every state or province the President holds.
        case provinces
        /// "all my territories", "my colonies": every land he holds beyond his own country.
        case lands
        /// "all of Africa": the lands he holds there (`CommandTargets.region`).
        case region(WorldRegion)
    }

    static let provinceWords: Set<String> = ["my states", "my provinces", "our states", "our provinces", "states", "provinces", "state", "province",
                                             "my states and provinces", "my provinces and states", "states i hold", "provinces i hold",
                                             "the states i hold", "the provinces i hold", "my own states", "my own provinces"]
    static let landWords: Set<String> = ["my territories", "my lands", "my colonies", "our territories", "our lands", "our colonies", "territories",
                                         "colonies", "lands", "territory", "colony", "land", "my possessions", "territories i hold", "lands i hold",
                                         "my own territories", "my own lands"]
    static let leads = ["all of the ", "all of ", "all the ", "all ", "every one of my ", "every ", "each of ", "each ", "the whole of "]

    /// What a normalized phrase names: a group with "all"/"every"/"my" in front, or a bare region when allowed.
    static func kind(_ n: String, bareRegion: Bool) -> Kind? {
        var t = n
        var led = false
        for l in leads where t.hasPrefix(l) { t = String(t.dropFirst(l.count)); led = true; break }
        if provinceWords.contains(t), led || t.hasPrefix("my ") || t.hasPrefix("our ") { return .provinces }
        if landWords.contains(t), led || t.hasPrefix("my ") || t.hasPrefix("our ") { return .lands }
        if led || bareRegion, let r = CommandTargets.region(t) { return .region(r) }
        return nil
    }

    /// The name for the `index`th place (0-based) when one name covers many: the name itself, then "2", "3"…, so
    /// every place keeps a name of its own (a duplicate would make the map's names, and typed orders, ambiguous).
    /// Plain numbers, not Roman numerals: 30 to 39 in Roman numerals contain a sequence the content check refuses.
    static func numbered(_ name: String, _ index: Int) -> String {
        index == 0 ? name : name.trimmingCharacters(in: .whitespaces) + " \(index + 1)"
    }

    /// `count` names from one: the name, then numbered, skipping a number whose name the content check refuses (a
    /// number can be a code) when the name itself is fine. A refused name stays as it is, so the card is refused.
    static func names(_ name: String, count: Int) -> [String] {
        guard count > 0 else { return [] }
        guard case .ok = NameScreen.check(name) else { return Array(repeating: name, count: count) }
        var out = [name], k = 1
        while out.count < count, k < count + 200 {
            let n = numbered(name, k)
            if case .blocked = NameScreen.check(n) {} else { out.append(n) }
            k += 1
        }
        return out
    }
}
