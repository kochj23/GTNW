//
//  RenamePlanner.swift
//  Global Thermal Nuclear War
//
//  3.36.0: the command box's and the chief of staff's RENAME card. "rename Kenya to New Albion", "rename my country
//  to Freedonia", "rename the Gulf of Mexico to …", or (from the chief of staff) up to `CommandParser.maxRenames`
//  renames on one card. Each target is resolved against the game's names, must be the President's own country, a land
//  he holds, a sea, strait or mountain on this year's map or one of his departments, and each name passes
//  `NameScreen`; a bulk card leaves out what can't be renamed and says so. Renames spend no action. Read-only.
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

    /// The RENAME card for one or more renames.
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
        var firstRefusal: String?
        var seen = Set<String>()
        for r in asked {
            let (target, refusal) = renameTarget(r.target, in: gs)
            guard let target else { firstRefusal = firstRefusal ?? refusal; left.append(String(r.target.prefix(40))); continue }
            let old = target.currentName(in: gs) ?? target.id
            let check = renameCheck(target, to: r.name)
            guard let name = check.name else { firstRefusal = firstRefusal ?? check.refusal; left.append(old); continue }
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
        if !left.isEmpty {
            plan.warnings.append(CommandWarning(text: "Left out: \(left.joined(separator: ", ")). \(firstRefusal ?? "")", level: 1))
        }
        plan.warnings.append(CommandWarning(text: "Renaming spends no action. Other nations decide whether to use the new name.", level: 0))
        plan.warnings = plan.warnings.reduce(into: []) { if !$0.contains($1) { $0.append($1) } }
        plan.target = plan.orders.map { RenameTarget.from(id: $0.target, in: gs).currentName(in: gs) ?? $0.target }.joined(separator: ", ")
            + ", \(gs.currentYear)"
        return .plan(plan)
    }
}
