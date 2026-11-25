//
//  CommandPlanner.swift
//  Global Thermal Nuclear War
//
//  3.34.0: turns a `CommandIntent` into what the confirmation card shows: the resolved target (by its name in the
//  game's year), the exact forces committed and held back, the warnings (out of reach, too few forces, a treaty
//  broken, a nuclear power on the other side, not enough actions left) and the `GameOrder`s that EXECUTE will run.
//  Ambiguous names come back as a question with choices; questions about the world are answered here from the game
//  state, read-only. Nothing in this file changes the game.
//  Repository: https://github.com/kochj23/GTNW
//

import Foundation

/// A warning on the confirmation card. `level` 0 note, 1 caution, 2 danger.
struct CommandWarning: Equatable, Hashable, Sendable {
    var text: String
    var level: Int
}

/// What EXECUTE will do, and everything the President should know first.
struct CommandPlan: Equatable, Sendable {
    var title: String
    /// "Merina Kingdom (Madagascar), 1850".
    var target: String
    var orders: [GameOrder]
    var committed: [String]
    var heldBack: [String]
    var warnings: [CommandWarning]
    var actionsNeeded: Int
    var actionsLeft: Int
    var source: CommandSource
    var nuclear: Bool { orders.contains(where: \.isNuclear) }
}

/// One choice in a clarifying question; picking it re-plans with `intent`.
struct ClarifyOption: Equatable, Identifiable, Sendable {
    var id: String { label }
    var label: String
    var intent: CommandIntent
}

struct Clarification: Equatable, Sendable {
    var question: String
    var options: [ClarifyOption]
    var source: CommandSource
}

enum CommandOutcome: Equatable, Sendable {
    case plan(CommandPlan)
    case clarify(Clarification)
    case answer([String])
    case rejected(String)
}

/// A name resolved against the game's own data for the game's year.
enum ResolvedTarget: Equatable, Hashable, Sendable {
    /// A nation on the board (a computer-run country or a territory).
    case nation(String)
    /// A colony another power holds (a colony of the record or a held territory).
    case colony(String)
    /// Land held by a people the game doesn't model as a state.
    case indigenous(String)
    /// Land nobody governs this year.
    case unclaimed(String)

    var id: String {
        switch self {
        case .nation(let i), .colony(let i), .indigenous(let i), .unclaimed(let i): return i
        }
    }
}

enum TargetResolution: Equatable {
    /// One match; `note` asks the President to confirm when the typed name differs from what the land is this year.
    case one(ResolvedTarget, note: String?)
    case many([ResolvedTarget])
    case none
}

// MARK: - Names

enum CommandTargets {
    /// Extra short names on top of `GameState.countryAliases`.
    static let aliases: [String: String] = [
        "united states": "USA", "the us": "USA", "u s": "USA", "united kingdom": "GBR", "england": "GBR", "the uk": "GBR",
        "soviet union": "RUS", "the soviets": "RUS", "soviets": "RUS", "russian empire": "RUS", "persia": "IRN",
        "siam": "THA", "burma": "MMR", "ceylon": "LKA", "holland": "NLD", "the netherlands": "NLD", "korea": "KOR",
        "west germany": "DEU", "prussia": "DEU", "ottoman empire": "TUR", "ottomans": "TUR", "turkey": "TUR",
        "ivory coast": "CIV", "czech republic": "CZE", "the vatican": "VAT", "vatican": "VAT", "uae": "ARE",
        "drc": "COD", "congo kinshasa": "COD", "congo brazzaville": "COG", "east timor": "TLS", "swaziland": "SWZ",
    ]

    /// What people call a nation's people or government ("the Brits", "the French"), for the model's translations.
    static let demonyms: [String: String] = {
        let table: [String: [String]] = [
            "USA": ["american", "americans", "yanks"], "GBR": ["british", "brits", "brit", "english"], "FRA": ["french"],
            "DEU": ["german", "germans"], "RUS": ["russian", "russians", "soviet", "soviets"], "CHN": ["chinese"],
            "JPN": ["japanese"], "ITA": ["italian", "italians"], "ESP": ["spanish", "spaniards"], "MEX": ["mexican", "mexicans"],
            "CAN": ["canadian", "canadians"], "IRN": ["iranian", "iranians", "persians"], "IRQ": ["iraqi", "iraqis"],
            "ISR": ["israeli", "israelis"], "IND": ["indian", "indians"], "PAK": ["pakistani", "pakistanis"],
            "PRK": ["north korean", "north koreans"], "KOR": ["south korean", "south koreans"], "CUB": ["cuban", "cubans"],
            "BRA": ["brazilian", "brazilians"], "ARG": ["argentine", "argentinian", "argentinians"], "TUR": ["turkish", "turks"],
            "EGY": ["egyptian", "egyptians"], "SAU": ["saudi", "saudis"], "SYR": ["syrian", "syrians"], "UKR": ["ukrainian", "ukrainians"],
            "POL": ["polish", "poles"], "NLD": ["dutch"], "BEL": ["belgian", "belgians"], "SWE": ["swedish", "swedes"],
            "NOR": ["norwegian", "norwegians"], "GRC": ["greek", "greeks"], "VNM": ["vietnamese"], "AUS": ["australian", "australians"],
            "AFG": ["afghan", "afghans"], "LBY": ["libyan", "libyans"], "VEN": ["venezuelan", "venezuelans"],
            "COL": ["colombian", "colombians"], "PRT": ["portuguese"], "AUT": ["austrian", "austrians"], "CHE": ["swiss"],
            "DNK": ["danish", "danes"], "FIN": ["finnish", "finns"], "IRL": ["irish"], "NGA": ["nigerian", "nigerians"],
            "ZAF": ["south african", "south africans"], "ETH": ["ethiopian", "ethiopians"], "KEN": ["kenyan", "kenyans"],
        ]
        return Dictionary(table.flatMap { id, words in words.map { ($0, id) } }, uniquingKeysWith: { a, _ in a })
    }()

    /// Formal-name words dropped on a second try ("the French Republic" → "french", "Kingdom of Spain" → "spain").
    static func stripFormal(_ n: String) -> String {
        var w = n.split(separator: " ").map(String.init)
        let lead: Set<String> = ["the", "republic", "kingdom", "state", "states", "of", "people", "peoples", "democratic", "federal",
                                 "federation", "commonwealth", "islamic", "united", "great"]
        let tail: Set<String> = ["republic", "kingdom", "government", "regime", "nation", "people", "forces", "army", "navy"]
        while let f = w.first, lead.contains(f), w.count > 1 { w.removeFirst() }
        while let l = w.last, tail.contains(l), w.count > 1 { w.removeLast() }
        return w.joined(separator: " ")
    }

    /// Modern map name (normalized) → land id, built once: every country template and small island.
    static let modernNames: [String: String] = {
        var d: [String: String] = [:]
        for t in WorldCountriesDatabase.allCountries() where d[CommandParser.normalize(t.name)] == nil { d[CommandParser.normalize(t.name)] = t.id }
        for i in Islands.all where d[CommandParser.normalize(i.name)] == nil { d[CommandParser.normalize(i.name)] = i.id }
        return d
    }()

    /// Every name a land goes by now: its era name in the game, its modern map name, its pre-state name.
    static func label(_ t: ResolvedTarget, in gs: GameState) -> String {
        let modern = WorldCountriesDatabase.template(id: t.id)?.name
        switch t {
        case .nation(let id):
            let name = gs.getCountry(id: id)?.name ?? modern ?? id
            if let m = modern, CommandParser.normalize(m) != CommandParser.normalize(name) { return "\(name) (\(m))" }
            return name
        case .colony(let id), .indigenous(let id):
            if let c = gs.getCountry(id: id) { return c.name }
            let st = gs.preState(id)
            let base = st?.label ?? modern ?? id
            if let m = modern, let n = st?.era.name, CommandParser.normalize(m) != CommandParser.normalize(n) { return "\(base), \(m)" }
            return base
        case .unclaimed(let id):
            return modern ?? id
        }
    }

    /// 3.36.0: a state or province typed as a target, when no nation on the board goes by that exact name.
    static func state(_ raw: String, in gs: GameState) -> Subdivision? {
        let n = CommandParser.normalizedName(raw)
        guard !gs.countries.contains(where: { !$0.isDestroyed && CommandParser.normalizedName($0.name) == n }) else { return nil }
        return Subdivisions.find(raw, in: gs)
    }

    /// 3.35.1: a continent or region typed as a target ("South America", "all of Africa", "the Middle East").
    static func region(_ raw: String) -> WorldRegion? {
        var n = CommandParser.normalize(raw)
        for p in ["all of ", "every nation in ", "all nations in ", "all the nations of ", "the whole of ", "the "] where n.hasPrefix(p) {
            n = String(n.dropFirst(p.count))
        }
        if n == "mideast" || n == "mid east" { return .middleEast }
        return WorldRegion.allCases.first { CommandParser.normalize($0.rawValue) == n }
    }

    /// The independent nations in a region the President could act against: alive, not a territory, not their own.
    static func regionMembers(_ r: WorldRegion, in gs: GameState) -> [ResolvedTarget] {
        gs.countries.filter { $0.region == r && !$0.isDestroyed && $0.territoryOf == nil && $0.id != gs.playerCountryID }
            .sorted { $0.name < $1.name }.map { .nation($0.id) }
    }

    /// Resolve one typed name. Exact id or code, the era name, an alias, the modern map name (with a note when the
    /// land is something else this year), a pre-state name, then a unique word prefix; several prefixes → choices.
    static func resolve(_ raw: String, in gs: GameState) -> TargetResolution {
        let first = resolveOnce(raw, in: gs)
        guard first == .none else { return first }
        let stripped = stripFormal(CommandParser.normalize(raw))
        return stripped == CommandParser.normalize(raw) ? .none : resolveOnce(stripped, in: gs)
    }

    private static func resolveOnce(_ raw: String, in gs: GameState) -> TargetResolution {
        let n = CommandParser.normalize(raw)
        guard !n.isEmpty, n.count <= 60 else { return .none }
        let year = gs.currentYear
        let live = gs.countries.filter { !$0.isDestroyed }
        let liveNames = live.map { ($0, CommandParser.normalizedName($0.name)) }
        // Every land that may be pre-state or unclaimed; `landTarget` says what it is this year (checked only on a name hit:
        // `preState` scans the era table, so it is never run over every land).
        let maybeLands = gs.unclaimedLandIDs.union(PreStateModel.lands)
        func landTarget(_ id: String) -> ResolvedTarget? {
            if let c = gs.getCountry(id: id), !c.isDestroyed { return .nation(id) }
            if let st = gs.preState(id) {
                if st.era.kind == .colony { return .colony(id) }
                return .indigenous(id)
            }
            if gs.unclaimedLandIDs.contains(id) { return .unclaimed(id) }
            return nil
        }
        // 1. Exact id or ISO code.
        let upper = n.uppercased().replacingOccurrences(of: " ", with: "_")
        if let c = live.first(where: { $0.id == upper || $0.code == upper }) { return .one(.nation(c.id), note: nil) }
        if upper.count <= 8, maybeLands.contains(upper), gs.getCountry(id: upper) == nil, let t = landTarget(upper) { return .one(t, note: nil) }
        // 2. The era name ("Merina Kingdom", "Soviet Union", "Prussia" when that is the board's name).
        if let c = liveNames.first(where: { $0.1 == n })?.0 { return .one(.nation(c.id), note: nil) }
        // 3. An alias.
        if let id = GameState.countryAliases[n] ?? aliases[n], let c = live.first(where: { $0.id == id }) {
            let differs = CommandParser.normalize(c.name) != n && aliases[n] != nil && WorldCountriesDatabase.template(id: id).map { CommandParser.normalize($0.name) != CommandParser.normalize(c.name) } == true
            return .one(.nation(c.id), note: differs ? "\(raw.capitalized) is \(c.name) in \(year)." : nil)
        }
        // 3b. What its people are called ("the Brits"), or its capital ("Paris").
        if let id = demonyms[n] ?? demonyms[n.hasPrefix("the ") ? String(n.dropFirst(4)) : n], let c = live.first(where: { $0.id == id }) {
            return .one(.nation(c.id), note: nil)
        }
        let byCapital = live.filter { $0.territoryOf == nil && CommandParser.normalizedName($0.capital) == n }
        if byCapital.count == 1 { return .one(.nation(byCapital[0].id), note: nil) }
        // 3c. A state or province ("California", "Bavaria"): orders go to whoever holds it.
        if let p = state(raw, in: gs), let owner = gs.provinceOwner(p.id), let c = live.first(where: { $0.id == owner }) {
            let what = Subdivisions.historical(p, on: gs.currentDate).kind.lowercased()
            if owner == gs.playerCountryID { return .one(.nation(owner), note: "\(gs.provinceName(p.id)) is one of your own \(what)s.") }
            return .one(.nation(owner), note: "\(gs.provinceName(p.id)) is a \(what) held by \(c.name); the order goes to \(c.name).")
        }
        // 4. The modern map name: say what the land is in this year.
        if let id = modernNames[n] {
            let modern = WorldCountriesDatabase.template(id: id)?.name ?? raw
            guard let t = landTarget(id) else { return .none }
            switch t {
            case .nation(let i):
                let c = gs.getCountry(id: i)
                if let c, CommandParser.normalize(c.name) != n {
                    let owner = c.territoryOf.flatMap { gs.getCountry(id: $0)?.name }
                    return .one(t, note: "\(modern) is \(c.name)\(owner.map { ", held by \($0)," } ?? "") in \(year).")
                }
                return .one(t, note: nil)
            case .colony(let i):
                if let c = gs.getCountry(id: i), let o = c.territoryOf, let owner = gs.getCountry(id: o) {
                    return .one(t, note: "\(modern) is \(c.name), a territory of \(owner.name), in \(year).")
                }
                let st = gs.preState(i)
                let owner = st.map { PreStateModel.ownerName($0.era.owner, from: $0.era.from) } ?? "another power"
                return .one(t, note: "\(modern) is \(st?.era.name ?? modern), a colony of \(owner), in \(year).")
            case .indigenous(let i):
                return .one(t, note: "\(modern) is held by the \(gs.preState(i)?.era.name ?? "people who live there") in \(year), not by a state in the game.")
            case .unclaimed:
                return .one(t, note: "\(modern) has no government in the game in \(year): unclaimed land.")
            }
        }
        // 5. A pre-state name ("New Spain", "Gold Coast", "Ashanti Empire").
        let pre = Set(PreStateModel.eras.filter { CommandParser.normalizedName($0.name) == n }.map(\.land))
            .filter { gs.preState($0).map { CommandParser.normalizedName($0.era.name) == n } == true }
        if pre.count == 1, let id = pre.first, let t = landTarget(id) { return .one(t, note: nil) }
        // 5b. 3.36.0: a land drawn as part of a nation this year ("Greenland" → Denmark), said plainly.
        if let part = partOf(n, in: gs), gs.preState(part.owner) == nil, let c = gs.getCountry(id: part.owner) {
            return .one(.nation(c.id), note: "\(part.name) is part of \(c.name) in \(year), not a separate land.")
        }
        // 6. A word prefix, only when it picks one ("isra" → Israel); several → the choices.
        let words = n.split(separator: " ").map(String.init)
        func matches(normalized nn: String) -> Bool {
            if nn.hasPrefix(n) { return true }
            let nameWords = nn.split(separator: " ")
            return words.count == 1 && nameWords.contains { $0.hasPrefix(n) }
        }
        var found = liveNames.filter { $0.0.id != gs.playerCountryID && matches(normalized: $0.1) }.map { ResolvedTarget.nation($0.0.id) }
        for id in maybeLands.sorted() where gs.getCountry(id: id) == nil {
            if let name = WorldCountriesDatabase.template(id: id)?.name, matches(normalized: CommandParser.normalizedName(name)), let t = landTarget(id) { found.append(t) }
        }
        if found.count == 1 { return .one(found[0], note: nil) }
        if found.count > 1 { return .many(Array(found.sorted { $0.id < $1.id }.prefix(6))) }
        return .none
    }
}

// MARK: - Planning

extension GameEngine {

    /// Plan a command, ask which nation was meant, answer a question, or refuse. Read-only.
    func planCommand(_ intent: CommandIntent, source: CommandSource) -> CommandOutcome {
        guard let gs = gameState, let me = gs.getPlayerCountry() else { return .rejected("Start a game first.") }
        if let q = intent.question { return .answer(answer(q, in: gs)) }
        guard let verb = intent.verb else {
            return .rejected("That isn't an order or a question the game knows. Type HELP for examples.")
        }
        if spectating { return .rejected("You are watching. Take the seat before giving orders.") }
        if gs.gameOver { return .rejected("The game is over.") }
        if isProcessingAITurn { return .rejected("The world is moving. Wait for your turn.") }
        if verb == .rename || verb == .renamePlace { return planRenames(intent, source: source) }   // 3.36.0: one rename path, no action (RenamePlanner.swift)
        // 3.36.0: land changes hands by province only at the peace table (the annex-provinces term), not by purchase.
        if [.claim, .buy, .liberate, .acquire].contains(verb), intent.confirmedTargets == nil,
           let p = intent.targets.lazy.compactMap({ CommandTargets.state(CommandParser.sanitize($0), in: gs) }).first {
            return .rejected("\(gs.provinceName(p.id)) is a \(Subdivisions.historical(p, on: gs.currentDate).kind.lowercased()), not a land "
                             + "on its own. Provinces change hands at the peace table: win the war, then annex the occupied provinces.")
        }
        if let p = planPowerPlay(intent, verb: verb, source: source) { return p }   // 3.36.0: PowerPlayPlanner.swift
        if gs.actionsRemaining == 0 {
            return .rejected("No actions left this \(gs.turnLength.displayName.lowercased()). End the turn first.")
        }
        if let play = HomePlay(verb: verb) { return planHomePlay(play, intent, source: source) }   // 3.36.0
        if let home = planOwnStateForce(intent, verb: verb, source: source) { return home }   // 3.37.0: "invade Texas"
        if let op = verb.antarcticOrder { return planAntarctic(op, intent: intent, source: source) }   // 3.36.0
        // Names → targets (or a question back).
        var targets: [ResolvedTarget] = []
        /// Nations added by a region name: one that can't take the order is skipped, not a refusal of the whole plan.
        var regionIDs = Set<String>()
        if let picked = intent.confirmedTargets {
            for id in picked.prefix(CommandParser.maxRegionTargets) {
                switch CommandTargets.resolve(id, in: gs) {
                case .one(let t, _): targets.append(t)
                default: return .rejected("That choice is no longer on the board.")
                }
            }
        } else {
            let names = intent.targets.prefix(CommandParser.maxTargets).map { CommandParser.sanitize($0) }.filter { !$0.isEmpty }
            guard !names.isEmpty else {
                return .rejected("Name a nation or a land, for example \"\(verb == .attack ? "attack" : verb.title.lowercased()) France\".")
            }
            for name in names {
                if let r = CommandTargets.region(name) {
                    // 3.36.0: a land verb takes the region's lands (free land to claim, colonies to buy or free, your own
                    // territories to develop); every other verb its independent nations.
                    let lands = verb.isLand || verb == .develop
                    let pool = lands ? CommandTargets.regionLands(r, verb: verb, in: gs, engine: self) : CommandTargets.regionMembers(r, in: gs)
                    let members = Array(pool.filter { m in !targets.contains(m) }.prefix(CommandParser.maxRegionTargets))
                    guard !members.isEmpty else {
                        return .rejected("No \(lands ? "land" : "nation") in \(r.rawValue) can take that order in \(gs.currentYear).")
                    }
                    targets += members
                    regionIDs.formUnion(members.map(\.id))
                    continue
                }
                switch CommandTargets.resolve(name, in: gs) {
                case .none:
                    if source == .parser {
                        return .rejected("No nation or land called \"\(String(name.prefix(40)))\" in \(gs.currentYear).")
                    }
                    return .rejected("One of those names isn't a nation or land in \(gs.currentYear).")
                case .many(let options):
                    return .clarify(Clarification(
                        question: "Which one do you mean?",
                        options: options.map { t in
                            var i = intent
                            i.confirmedTargets = targets.map(\.id) + [t.id]
                            i.targets = []
                            return ClarifyOption(label: CommandTargets.label(t, in: gs), intent: i)
                        }, source: source))
                case .one(let t, let note):
                    if let note {
                        var i = intent
                        i.confirmedTargets = targets.map(\.id) + [t.id]
                        i.targets = Array(names.dropFirst(targets.count + 1))
                        if !i.targets.isEmpty { i.confirmedTargets = nil; i.targets = [t.id] + i.targets }
                        return .clarify(Clarification(question: "\(note) Target it?",
                                                      options: [ClarifyOption(label: "Yes: \(CommandTargets.label(t, in: gs))", intent: i)],
                                                      source: source))
                    }
                    targets.append(t)
                }
            }
        }
        // Orders for each target.
        var plan = CommandPlan(title: verb.title, target: "", orders: [], committed: [], heldBack: [], warnings: [],
                               actionsNeeded: 0, actionsLeft: gs.actionsRemaining, source: source)
        var skipped: [String] = []
        for t in targets {
            if regionIDs.contains(t.id) {
                var trial = plan
                if addOrders(verb, intent.forces, against: t, to: &trial, in: gs) == nil,
                   !trial.orders.dropFirst(plan.orders.count).contains(where: { orderProblem($0) != nil }) {
                    plan = trial
                } else {
                    skipped.append(CommandTargets.label(t, in: gs))
                }
                continue
            }
            if t.id == me.id { return .rejected("That is your own nation.") }
            if case .nation(let id) = t, gs.getCountry(id: id)?.territoryOf == me.id, verb != .develop {
                return .rejected("\(gs.getCountry(id: id)?.name ?? id) flies your own flag.")
            }
            if let refusal = addOrders(verb, intent.forces, against: t, to: &plan, in: gs) { return .rejected(refusal) }
        }
        let planned = targets.filter { t in !skipped.contains(CommandTargets.label(t, in: gs)) }
        plan.target = planned.map { CommandTargets.label($0, in: gs) }.joined(separator: ", ") + ", \(gs.currentYear)"
        if !skipped.isEmpty {
            plan.warnings.append(CommandWarning(text: "Left out (that order can't be carried out against them): \(skipped.joined(separator: ", ")).", level: 1))
        }
        guard !plan.orders.isEmpty else {
            return .rejected(plan.warnings.first?.text ?? "Nothing in that order can be carried out in \(gs.currentYear).")
        }
        // Each order passes the same check EXECUTE will make.
        for o in plan.orders { if let p = orderProblem(o) { return .rejected(p) } }
        plan.actionsNeeded = plan.orders.count
        if plan.actionsNeeded > plan.actionsLeft {
            plan.warnings.append(CommandWarning(
                text: "Needs \(plan.actionsNeeded) actions; \(plan.actionsLeft) left this \(gs.turnLength.displayName.lowercased()). Only the first \(plan.actionsLeft) will be carried out.",
                level: 2))
        }
        if plan.nuclear {
            plan.warnings.insert(CommandWarning(text: "NUCLEAR RELEASE. A second confirmation is required.", level: 2), at: 0)
        }
        plan.warnings = plan.warnings.reduce(into: []) { if !$0.contains($1) { $0.append($1) } }
        return .plan(plan)
    }

    /// Add the orders for one verb against one target. Returns a refusal for an order that makes no sense at all.
    private func addOrders(_ verb: CommandVerb, _ f: ForceRequest, against t: ResolvedTarget, to plan: inout CommandPlan, in gs: GameState) -> String? {
        guard let me = gs.getPlayerCountry() else { return "No game." }
        let year = gs.currentYear
        let name = CommandTargets.label(t, in: gs)
        if f.nuclear == false && verb == .nuke { return "A nuclear strike that is non-nuclear is not an order. Say which you mean." }
        // 3.36.0: INVEST in a territory the President holds.
        if verb == .develop {
            guard case .nation(let id) = t, let c = gs.getCountry(id: id), c.territoryOf == me.id else {
                return "\(name) is not your territory. Only land you hold can be developed."
            }
            if let p = LandDevelopment.problem(id, in: gs), !p.hasPrefix("No actions") { return p }
            plan.orders.append(GameOrder(kind: .developLand, target: id))
            let m = LandDevelopment.monthsToDevelop(id, in: gs)
            plan.committed.append(String(format: "Invest $%.2fB in %@: %@", LandDevelopment.investCost(c, in: gs), c.name,
                                         m > 0 ? "six months of development (full output in \(m) months now)." : "stations, a harbour and fisheries."))
            return nil
        }

        // Land that is not a nation: claim, seize, buy, free.
        switch t {
        case .colony(let land):
            guard let col = colonyTarget(land) else { return "\(name) is not a colony in \(year)." }
            switch verb {
            case .buy:
                plan.orders.append(GameOrder(kind: .buyColony, target: land))
                plan.committed.append("Negotiate with \(col.owner.name) to buy \(col.label).")
                return nil
            case .liberate:
                plan.orders.append(GameOrder(kind: .backIndependence, target: land))
                plan.committed.append("Back the independence of \(col.label) ($2B).")
                plan.warnings.append(CommandWarning(text: "\(col.owner.name) will not thank you for it.", level: 1))
                return nil
            case .attack, .invade, .claim, .landing, .declareWar:
                let troops = expeditionTroops(f, in: gs, standard: max(AttackSizing.expeditionStandard, PreStateModel.garrison(owner: col.owner) * 3))
                guard troops >= 1 else { return "No free troops to send." }
                plan.orders.append(GameOrder(kind: .seizeColony, target: land, troops: troops))
                plan.committed.append("Ground: \(Int(troops))K troops to seize \(col.label) from \(col.owner.name).")
                plan.warnings.append(CommandWarning(text: "Seizing it means war with \(col.owner.name)" + (col.owner.nuclearWarheads > 0 ? ", a nuclear power." : "."),
                                                    level: col.owner.nuclearWarheads > 0 ? 2 : 1))
                noteUnusedForces(f, in: gs, to: &plan, landTarget: true)
                return nil
            default:
                return "\(name) is a colony of \(col.owner.name) in \(year), not a nation. Aim it at \(col.owner.name), or seize, buy or free the colony."
            }
        case .indigenous(let land), .unclaimed(let land):
            switch verb {
            case .attack, .invade, .claim, .landing, .declareWar:
                let troops = expeditionTroops(f, in: gs, standard: AttackSizing.expeditionStandard)
                guard troops >= 1 else { return "No free troops to send." }
                plan.orders.append(GameOrder(kind: .claimLand, target: land, troops: troops))
                plan.committed.append("Ground: \(Int(troops))K troops to claim \(name).")
                for w in advisorWarnings(for: .claim(land: land, troops: troops)) where w.level > 0 {
                    plan.warnings.append(CommandWarning(text: "\(w.who): \(w.text)", level: w.level))
                }
                if case .indigenous = t {
                    plan.warnings.append(CommandWarning(text: "Its people will resist; taking it brings an insurgency.", level: 1))
                }
                noteUnusedForces(f, in: gs, to: &plan, landTarget: true)
                return nil
            default:
                return "\(name) is not a nation in \(year). You can claim it."
            }
        case .nation:
            break
        }

        // A nation.
        guard let target = gs.getCountry(id: t.id) else { return "No such nation." }
        if verb.isLand {
            return verb == .claim ? "\(target.name) is a nation in \(year), not free land. Attack it, or claim land nobody holds."
                : "\(target.name) is a nation in \(year), not a colony."
        }
        if let a = verb.simpleAction {
            return addSimpleOrder(a, verb: verb, target: target, to: &plan, in: gs)
        }
        // Force verbs: which arms go in.
        var ground = false, air = false, naval = false, nuclear = false, declare = false
        switch verb {
        case .attack:
            if f.namesAKind {
                ground = f.ground == true; air = f.air == true; naval = f.naval == true; nuclear = f.nuclear == true
            } else if f.all {
                ground = true; air = true; naval = true
            } else {
                ground = true
            }
        case .declareWar:
            declare = true
            ground = f.ground == true || (f.all && f.ground != false)
            air = f.air == true || (f.all && f.air != false)
            naval = f.naval == true || (f.all && f.naval != false)
            nuclear = f.nuclear == true
        case .invade: ground = true; air = f.air == true; naval = f.naval == true
        case .airStrike: air = true
        case .navalStrike, .blockade, .showOfForce, .landing: naval = true
        case .nuke: nuclear = true
        default: break
        }
        if f.nuclear == false { nuclear = false }
        let hostile = verb != .showOfForce
        if declare {
            if me.atWarWith.contains(target.id) {
                plan.warnings.append(CommandWarning(text: "Already at war with \(target.name).", level: 0))
            } else {
                plan.orders.append(GameOrder(kind: .declareWar, target: target.id))
                plan.committed.append("Declare war on \(target.name).")
            }
        }
        if ground {
            let free = AttackSizing.available(.troops, in: gs).rounded(.down)
            if free < 1 {
                plan.warnings.append(CommandWarning(text: "No free ground troops: every soldier is fighting or on garrison.", level: 2))
            } else {
                let std = AttackSizing.standard(.groundInvasion, in: gs).troops
                let troops = sized(f.troops, all: f.all, share: f.share, light: f.light, standard: std, available: free)
                let o = GameOrder(kind: .action, target: target.id, action: PresidentialAction.groundInvasion.rawValue, troops: troops)
                plan.orders.append(o)
                plan.committed.append("Ground: \(Int(troops))K troops" + (troops >= free ? " (all free troops)" : " of \(Int(free))K free"))
                if troops < free { plan.heldBack.append("Ground: \(Int(free - troops))K troops stay home.") }
                addAdvisorWarnings(.groundInvasion, target: target.id, size: AttackSize(troops: troops), to: &plan)
            }
        }
        if air {
            let pool = AttackSizing.available(.aircraft, in: gs)
            if !PresidentialAction.airStrike.isAvailable(on: gs.currentDate, in: gs) || pool < 1 {
                plan.warnings.append(CommandWarning(text: year < 1914 ? "No air arm in \(year): military aviation begins in 1914." : "No aircraft available.", level: 1))
            } else {
                let std = Double(AttackSizing.standard(.airStrike, in: gs).aircraft)
                let n = Int(sized(f.aircraft.map(Double.init), all: f.all, share: f.share, light: f.light, standard: std, available: pool))
                plan.orders.append(GameOrder(kind: .action, target: target.id, action: PresidentialAction.airStrike.rawValue, aircraft: n))
                plan.committed.append("Air: \(n) aircraft" + (Double(n) >= pool ? " (the whole air arm)" : " of \(Int(pool))"))
                if Double(n) < pool { plan.heldBack.append("Air: \(Int(pool) - n) aircraft stay on the ground.") }
                addAdvisorWarnings(.airStrike, target: target.id, size: AttackSize(aircraft: n), to: &plan)
            }
        }
        if naval { addNavalOrder(verb, f, target: target, to: &plan, in: gs) }
        if nuclear {
            let a: PresidentialAction = f.tactical ? .tacticalNuke : .launchNukes
            let have = Int(AttackSizing.available(.warheads, in: gs))
            if !a.isAvailable(on: gs.currentDate, in: gs) {
                return "No nuclear weapons exist in \(year)."
            } else if have < 1 {
                return "You have no nuclear warheads."
            }
            let std = Double(AttackSizing.standard(a, in: gs).warheads)
            let w = max(1, Int(sized(f.warheads.map(Double.init), all: f.all, share: f.share, light: f.light, standard: std, available: Double(have))))
            plan.orders.append(GameOrder(kind: .action, target: target.id, action: a.rawValue, warheads: w))
            plan.committed.append("Nuclear: \(w) warhead\(w == 1 ? "" : "s")\(f.tactical ? " (tactical)" : "") of \(have)")
            if w < have { plan.heldBack.append("Nuclear: \(have - w) warheads stay in reserve.") }
            addAdvisorWarnings(a, target: target.id, size: AttackSize(warheads: w), to: &plan)
        } else if me.nuclearWarheads > 0, hostile {
            plan.heldBack.append("Nuclear: all \(me.nuclearWarheads.formatted()) warheads held back.")
        }
        if hostile { addHostileWarnings(target, in: gs, to: &plan, nuclear: nuclear) }
        return nil
    }

    /// A share of what is free: the number asked for, all of it, a fraction, the small preset or the standard size.
    private func sized(_ asked: Double?, all: Bool, share: Double?, light: Bool, standard: Double, available: Double) -> Double {
        let v: Double
        if let asked { v = asked }
        else if all { v = available }
        else if let share { v = available * share }
        else if light { v = standard * AttackPreset.probe.multiplier }
        else { v = standard }
        return max(1, min(available, v.rounded()))
    }

    private func expeditionTroops(_ f: ForceRequest, in gs: GameState, standard: Double) -> Double {
        let free = AttackSizing.freeTroops(gs).rounded(.down)
        guard free >= 1 else { return 0 }
        return sized(f.troops, all: f.all, share: f.share, light: f.light, standard: standard, available: free)
    }

    /// Air or naval arms named against land with no state to strike: say they are not used.
    private func noteUnusedForces(_ f: ForceRequest, in gs: GameState, to plan: inout CommandPlan, landTarget: Bool) {
        if f.air == true || f.naval == true || (f.all && landTarget) {
            plan.heldBack.append("Air and naval forces: not used; there is no state to strike, only land to take.")
        }
        if let me = gs.getPlayerCountry(), me.nuclearWarheads > 0 { plan.heldBack.append("Nuclear: all \(me.nuclearWarheads.formatted()) warheads held back.") }
    }

    private func addNavalOrder(_ verb: CommandVerb, _ f: ForceRequest, target: Country, to plan: inout CommandPlan, in gs: GameState) {
        let year = gs.currentYear
        if NavalModel.isLandlocked(target.id) {
            plan.warnings.append(CommandWarning(text: "\(target.name) is landlocked: no coast for a navy to reach.", level: 1))
            return
        }
        let mission: NavalMission = verb == .blockade ? .blockade : (verb == .showOfForce ? .showOfForce : (verb == .landing ? .amphibious : .strike))
        if gs.playerCountryID == "USA" {
            let deployed = Set(gs.shadow.fleetDeployments.map(\.fleetID))
            let ready = NavalModel.fleets(in: year).filter { !deployed.contains($0.id) }
            guard !ready.isEmpty else {
                plan.warnings.append(CommandWarning(text: NavalModel.fleets(in: year).isEmpty ? "No U.S. Navy fleet exists in \(year)." : "Every fleet is already at sea. Recall one first.", level: 1))
                return
            }
            func km(_ fl: USFleet) -> Double {
                guard let p = fl.period(in: year) else { return .infinity }
                return NavalModel.distanceKm(lat1: p.lat, lon1: p.lon, lat2: target.coordinates.lat, lon2: target.coordinates.lon)
            }
            let named = f.fleet.flatMap { hint in ready.first { fleetMatches($0, hint) } }
            if let hint = f.fleet, named == nil {
                plan.warnings.append(CommandWarning(text: "No fleet called \"\(String(hint.prefix(30)))\" is in port in \(year); sending the nearest.", level: 1))
            }
            guard let fleet = named ?? ready.min(by: { km($0) < km($1) }) else { return }
            let preset: AttackPreset = f.all ? .overwhelming : (f.light ? .probe : .standard)
            let o = GameOrder(kind: .fleet, target: target.id, fleet: fleet.id, mission: mission.rawValue, preset: preset.rawValue)
            if let p = fleetOrderProblem(fleetID: fleet.id, target: target.id, mission: mission) {
                plan.warnings.append(CommandWarning(text: p, level: 1)); return
            }
            let ships = NavalModel.composition(fleet, year: year).scaled(NavalMission.commitment(preset))
            plan.orders.append(o)
            let days = NavalModel.transitDays(km: km(fleet), year: year)
            plan.committed.append("Naval: \(fleet.name), \(ships.total) ships (\(preset == .overwhelming ? "full strength" : preset.title.lowercased())), \(mission.title.lowercased()), about \(days) days at sea")
            let others = ready.filter { $0.id != fleet.id }.map(\.name)
            if !others.isEmpty { plan.heldBack.append("Naval: \(others.joined(separator: ", ")) stay in port (one fleet per order).") }
            for w in advisorWarnings(for: .fleet(fleetID: fleet.id, target: target.id, mission: mission, preset: preset)) where w.level > 0 {
                plan.warnings.append(CommandWarning(text: "\(w.who): \(w.text)", level: w.level))
            }
            return
        }
        // Other navies are not modelled fleet by fleet: a blockade, a landing or an exercise.
        let a: PresidentialAction = mission == .showOfForce ? .militaryExercise : (mission == .amphibious ? .amphAssault : .navalBlockade)
        guard a.isAvailable(on: gs.currentDate, in: gs) else {
            plan.warnings.append(CommandWarning(text: "\(a.rawValue) is not available in \(year).", level: 1)); return
        }
        if a == .navalBlockade, !Reach.canBlockade(gs.playerCountryID, target.id, in: gs) {
            plan.warnings.append(CommandWarning(text: "Your navy can't reach \(target.name)'s ports.", level: 2))
        }
        plan.orders.append(GameOrder(kind: .action, target: target.id, action: a.rawValue))
        plan.committed.append("Naval: \(a.rawValue.lowercased()) (naval strength \(min(100, max(0, gs.getPlayerCountry()?.navalForces ?? 0))))")
        addAdvisorWarnings(a, target: target.id, size: nil, to: &plan)
    }

    private func fleetMatches(_ fleet: USFleet, _ hint: String) -> Bool {
        let common: Set<String> = ["fleet", "squadron", "us", "u", "s", "the", "united", "states"]
        let ordinals = ["1st": "first", "2nd": "second", "3rd": "third", "4th": "fourth", "5th": "fifth", "6th": "sixth",
                        "7th": "seventh", "8th": "eighth", "12th": "twelfth"]
        let h = Set(CommandParser.normalize(hint).split(separator: " ").map { ordinals[String($0)] ?? String($0) }).subtracting(common)
        let n = Set(CommandParser.normalize(fleet.name).split(separator: " ").map(String.init)).subtracting(common)
        return !h.isEmpty && h.isSubset(of: n)
    }

    private func addSimpleOrder(_ a: PresidentialAction, verb: CommandVerb, target: Country, to plan: inout CommandPlan, in gs: GameState) -> String? {
        guard OrderWhitelist.allows(a) else { return "That order is not one the command box can give." }
        guard a.isAvailable(on: gs.currentDate, in: gs) else { return "\(a.rawValue) is not available in \(gs.currentYear)." }
        guard let me = gs.getPlayerCountry() else { return "No game." }
        switch verb {
        case .peace, .ceasefire:
            if !me.atWarWith.contains(target.id) { return "You are not at war with \(target.name)." }
        case .leaveAlliance:
            if !me.alliances.contains(target.id) { return "You have no alliance with \(target.name)." }
        case .ally:
            if me.alliances.contains(target.id) { return "\(target.name) is already your ally." }
            if me.atWarWith.contains(target.id) { plan.warnings.append(CommandWarning(text: "You are at war with \(target.name).", level: 1)) }
        default:
            break
        }
        plan.orders.append(GameOrder(kind: .action, target: target.id, action: a.rawValue))
        plan.committed.append("\(a.rawValue) → \(target.name) (odds \(Int((a.successChance * 100).rounded()))%)")
        if [.militaryAid, .sellWeapons].contains(a), me.nuclearWarheads > 0 {
            // Nothing held back to speak of; arms only.
        }
        if a.isHostile && [EscalationRung.military, .covert, .economic].contains(a.rung) {
            addTreatyWarnings(target, in: gs, to: &plan)
        }
        if a.rung == .military && a.isHostile { addHostileWarnings(target, in: gs, to: &plan, nuclear: false) }
        if MajorAction.isMajor(a) { addAdvisorWarnings(a, target: target.id, size: nil, to: &plan) }
        return nil
    }

    private func addAdvisorWarnings(_ a: PresidentialAction, target: String, size: AttackSize?, to plan: inout CommandPlan) {
        for w in advisorWarnings(for: .attack(a, target: target, size: size)) where w.level > 0 {
            plan.warnings.append(CommandWarning(text: "\(w.who): \(w.text)", level: w.level))
        }
    }

    private func addTreatyWarnings(_ target: Country, in gs: GameState, to plan: inout CommandPlan) {
        let me = gs.playerCountryID
        let bloc = MilitaryAllianceSystem.areAllied(country1: me, country2: target.id, year: gs.currentYear)
            ? MilitaryAllianceSystem.allianceName(year: gs.currentYear, forCountryID: target.id) : nil
        if bloc != nil || target.alliances.contains(me) || gs.getPlayerCountry()?.alliances.contains(target.id) == true {
            plan.warnings.append(CommandWarning(text: "\(target.name) is your ally\(bloc.map { " (\($0))" } ?? ""): this breaks the alliance.", level: 2))
        }
        for tr in gs.treaties where Set(tr.signatories) == [me, target.id] && [TreatyType.nonAggression, .alliance, .mutualDefense].contains(tr.type) {
            plan.warnings.append(CommandWarning(text: "This breaks your \(tr.type.rawValue.lowercased()) with \(target.name).", level: 2))
        }
    }

    /// Out of reach, a broken treaty, a nuclear power on the other side.
    private func addHostileWarnings(_ target: Country, in gs: GameState, to plan: inout CommandPlan, nuclear: Bool) {
        let me = gs.playerCountryID
        if Reach.how(me, target.id, in: gs) == nil {
            plan.warnings.append(CommandWarning(text: "Out of reach: no shared border, sea route or air range to \(target.name) in \(gs.currentYear).", level: 2))
        }
        addTreatyWarnings(target, in: gs, to: &plan)
        plan.warnings += consequenceWarnings(target, in: gs, nuclear: nuclear)   // 3.36.0
        if target.nuclearWarheads > 0 {
            plan.warnings.append(CommandWarning(text: "\(target.name) has \(target.nuclearWarheads.formatted()) nuclear warheads: this risks a nuclear exchange.", level: 2))
        }
        let nuclearAllies = gs.countries.filter { c in
            c.id != me && c.id != target.id && !c.isDestroyed && c.nuclearWarheads > 0
                && (target.alliances.contains(c.id) || MilitaryAllianceSystem.areAllied(country1: c.id, country2: target.id, year: gs.currentYear))
        }.map(\.name).sorted()
        if !nuclearAllies.isEmpty {
            plan.warnings.append(CommandWarning(text: "\(target.name)'s allies with nuclear weapons: \(nuclearAllies.prefix(3).joined(separator: ", ")). They may answer for it.", level: 2))
        }
        if nuclear, gs.defconLevel.rawValue > 1 {
            plan.warnings.append(CommandWarning(text: "\(gs.defconName) will rise. Retaliation can follow within the hour.", level: 2))
        }
    }

    // MARK: - Questions (read-only)

    func answer(_ q: CommandQuestion, in gs: GameState) -> [String] {
        guard let me = gs.getPlayerCountry() else { return ["Start a game first."] }
        let year = gs.currentYear
        switch q.topic {
        case .help:
            return CommandHelp.lines
        case .actions:
            return ["\(gs.actionsRemaining) of \(gs.actionsPerTurn) actions left this \(gs.turnLength.displayName.lowercased())."]
        case .defcon:
            return ["\(gs.defconLabel)."]
        case .arsenal:
            if year < 1945 { return ["No nation has nuclear weapons in \(year)."] }
            return ["\(me.name): \(me.nuclearWarheads.formatted()) warheads, \(me.icbmCount) ICBMs, \(me.submarineLaunchedMissiles) submarine missiles, \(me.bombers) bombers."]
        case .wars:
            let wars = me.atWarWith.compactMap { gs.getCountry(id: $0)?.name }.sorted()
            return [wars.isEmpty ? "You are at war with no one." : "At war with: \(wars.joined(separator: ", "))."]
        case .allies:
            let allies = me.alliances.compactMap { gs.getCountry(id: $0) }.filter { !$0.isDestroyed && $0.territoryOf != me.id }.map(\.name).sorted()
            return [allies.isEmpty ? "No allies." : "Allies: \(allies.joined(separator: ", "))."]
        case .fleets:
            let at = gs.shadow.fleetDeployments.map { d in
                "\(NavalModel.fleet(id: d.fleetID)?.name ?? d.fleetID): \(d.mission.title.lowercased()), \(gs.getCountry(id: d.target)?.name ?? WorldCountriesDatabase.template(id: d.target)?.name ?? d.target), \(d.status == .onStation ? "on station" : "underway")"
            }
            guard me.id == "USA" else { return ["Named fleets are U.S. fleets; your navy strength is \(min(100, max(0, me.navalForces)))."] }
            let ready = NavalModel.fleets(in: year).filter { f in !gs.shadow.fleetDeployments.contains { $0.fleetID == f.id } }.map(\.name)
            return (at.isEmpty ? ["No fleet at sea."] : at) + [ready.isEmpty ? "None in port." : "In port: \(ready.joined(separator: ", "))."]
        case .reachMe:
            let weapon = q.weapon ?? .any
            let rivals = gs.countries.filter { !$0.isDestroyed && $0.id != me.id && $0.territoryOf == nil }
            let hits = rivals.filter { c in
                switch weapon {
                case .missiles: return year >= 1960 && (c.icbmCount > 0 || c.submarineLaunchedMissiles > 0) && c.nuclearWarheads > 0
                case .bombers: return Reach.airRange(c, year: year).km >= Reach.nearestKm(c.id, me.id, in: gs) && c.bombers > 0
                case .nuclear: return c.nuclearWarheads > 0 && Reach.how(c.id, me.id, in: gs) != nil
                case .any: return Reach.how(c.id, me.id, in: gs) != nil
                }
            }.sorted { ($0.nuclearWarheads, $0.militaryStrength) > ($1.nuclearWarheads, $1.militaryStrength) }
            let what: String
            switch weapon {
            case .missiles: what = "with missiles"
            case .bombers: what = "with bombers"
            case .nuclear: what = "with nuclear weapons"
            case .any: what = "by land, sea or air"
            }
            guard !hits.isEmpty else { return ["No nation can reach \(me.name) \(what) in \(year)."] }
            let shown = hits.prefix(12).map { c in
                c.nuclearWarheads > 0 && weapon != .any ? "\(c.name) (\(c.nuclearWarheads.formatted()) warheads)" : c.name
            }
            return ["\(hits.count) nation\(hits.count == 1 ? "" : "s") can reach \(me.name) \(what) in \(year):"] + shown
                + (hits.count > 12 ? ["…and \(hits.count - 12) more."] : [])
        case .canReach:
            guard let name = q.country, let t = resolvedNation(name, in: gs) else { return ["Which nation?"] }
            guard let how = Reach.how(me.id, t.id, in: gs) else {
                return ["\(t.name) is out of reach in \(year): no shared border, sea route or air range."]
            }
            let words: [Reach.Mode: String] = [.land: "across a land border", .sea: "by sea", .air: "by air", .missile: "with missiles"]
            return ["\(t.name) can be reached \(words[how] ?? "")."]
        case .stat:
            guard let name = q.country, let c = resolvedNation(name, in: gs) else {
                return ["No nation by that name in \(year)."]
            }
            return stat(q.field ?? .summary, of: c, in: gs)
        }
    }

    private func resolvedNation(_ name: String, in gs: GameState) -> Country? {
        if ["me", "us", "my nation", "my country", "our nation", "our country", "myself"].contains(CommandParser.normalize(name)) {
            return gs.getPlayerCountry()
        }
        switch CommandTargets.resolve(name, in: gs) {
        case .one(.nation(let id), _): return gs.getCountry(id: id)
        default: return nil
        }
    }

    private func stat(_ field: StatField, of c: Country, in gs: GameState) -> [String] {
        let me = gs.playerCountryID
        let rel = c.diplomaticRelations[me] ?? 0
        switch field {
        case .stability: return ["\(c.name): stability \(c.stability) of 100."]
        case .military: return ["\(c.name): military \(c.militaryStrength) of 100 (army \(min(100, c.groundForces)), navy \(min(100, c.navalForces)), air \(min(100, c.airForces)))."]
        case .warheads: return [gs.currentYear < 1945 ? "No nation has nuclear weapons in \(gs.currentYear)." : "\(c.name): \(c.nuclearWarheads.formatted()) nuclear warheads."]
        case .approval: return [c.id == me ? "Your popularity: \(Int(gs.shadow.popularity.rounded()))%." : "\(c.name): public approval \(c.publicApproval)%."]
        case .relations: return [c.id == me ? "That is you." : "\(c.name): relations with you \(rel) (\(A11y.relationWord(rel)))."]
        case .economy: return ["\(c.name): economy \(c.economicStrength) of 100, output $\(String(format: "%.2f", c.gdp))T."]
        case .population: return ["\(c.name): about \(c.population.formatted()) million people."]
        case .government: return ["\(c.name): \(c.government.rawValue.lowercased())."]
        case .leader:
            let h = NationModel.leader(for: c, on: gs.currentDate)
            return [h.generic ? "\(c.name): no record of its \(h.title.lowercased()) on this date." : "\(c.name): \(h.title) \(h.name)."]
        case .summary:
            return [A11y.countryLabel(c, in: gs) + ".", A11y.countryValue(c, in: gs) + "."]
        }
    }
}

/// HELP: what the command box understands.
enum CommandHelp {
    static let lines = [
        "Orders (each one is a Situation Room action and uses one of the turn's actions):",
        "  attack France with all air, naval and army forces that are non-nuclear",
        "  invade Mexico with 50k troops · bomb Spain · blockade Japan · nuke Moscow's nation with 5 warheads",
        "  declare war on Spain · make peace with Spain · ceasefire with Spain",
        "  ally with Britain · sanction Iran · lift sanctions on Cuba · send aid to Kenya",
        "  send an ambassador to China · condemn Iraq · spy on Germany · sabotage Libya",
        "  deploy the seventh fleet to Japan · claim Madagascar · buy Alaska · liberate Brazil",
        "  at home: fire the chief statistician · pressure the Fed to cut rates · buy a stake in steel",
        "  build a missile shield · conduct an underground nuclear test · postpone the election",
        "  build a research station in Antarctica · leave, rejoin or renegotiate the Antarctic Treaty",
        "Questions (answered from the game, nothing changes):",
        "  who can reach me with ICBMs? · can I reach Brazil? · what's France's stability?",
        "  who am I at war with? · who are my allies? · how many actions left? · where are my fleets?",
        "Up arrow recalls earlier commands. Every order is shown for confirmation before it runs.",
    ]
}
