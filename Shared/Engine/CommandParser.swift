//
//  CommandParser.swift
//  Global Thermal Nuclear War
//
//  3.34.0: the command box's built-in reader. Common phrasings ("attack Madagascar with all air, naval and army
//  forces that are non-nuclear", "sanction Iran", "make peace with Spain", "who can reach me with ICBMs?") are read
//  here with no AI at all; the local model is asked only when this reader can't place the text. Either way the result
//  is a `CommandIntent`: a verb from a fixed list, the names as typed, and the forces asked for. Names are resolved and
//  numbers filled in by `CommandPlanner` from the game's own data.
//  Repository: https://github.com/kochj23/GTNW
//

import Foundation

/// The verbs the command box understands. Each one maps onto existing engine verbs (see `CommandPlanner`).
enum CommandVerb: String, Codable, CaseIterable, Sendable {
    // Force
    case attack, declareWar, invade, airStrike, navalStrike, blockade, showOfForce, landing, nuke
    // Alliances and treaties
    case ally, leaveAlliance, peace, ceasefire, nonAggression
    // Economic
    case sanction, liftSanctions, embargo, freezeAssets, tariffs, trade, aid, foodAid, militaryAid, sellWeapons
    // Diplomatic
    case ambassador, recallAmbassador, summit, stateVisit, demandApology, severRelations, restoreRelations, condemn, propaganda
    // Covert and intelligence
    case spy, satellite, sabotage, cyber, supportRebels, stealTech
    // Troops
    case deployTroops, withdrawTroops, exercise, caseForWar
    // Land
    case claim, buy, liberate
    // Power plays (3.36.0, PowerPlayPlanner.swift): an acquisition campaign's steps, emergency powers, a raid, a strike
    case acquire, pressure, posture, frameworkDeal, escalateCampaign, emergency, endEmergency, emergencyTariffs, reissue
    case captureLeader, limitedStrike, renamePlace
    // Names (3.36.0): the President's own country or a land he holds; no action spent
    case rename
    /// 3.36.0: invest in a territory the President holds (six months of development).
    case develop
    // 3.36.0: power plays at home (`HomePlay`, planned by `planHomePlay`)
    case troopsHome, fixNumbers, leanOnBank, buyStake, stayInPower, missileShield, nuclearTest
    // Antarctica (3.36.0)
    case researchStation, joinAntarcticTreaty, leaveAntarcticTreaty, renegotiateAntarcticTreaty

    /// The Situation Room action a simple (non-force) verb runs; nil for the force and land verbs.
    var simpleAction: PresidentialAction? {
        switch self {
        case .ally: return .joinNATO
        case .leaveAlliance: return .leaveNATO
        case .peace: return .peace
        case .ceasefire: return .ceasefire
        case .nonAggression: return .nonAggression
        case .sanction: return .sanctions
        case .liftSanctions: return .liftSanctions
        case .embargo: return .oilEmbargo
        case .freezeAssets: return .freezeAssets
        case .tariffs: return .imposeTariffs
        case .trade: return .tradeDeal
        case .aid: return .economicAid
        case .foodAid: return .foodAid
        case .militaryAid: return .militaryAid
        case .sellWeapons: return .sellWeapons
        case .ambassador: return .sendAmbassador
        case .recallAmbassador: return .recallAmbassador
        case .summit: return .summit
        case .stateVisit: return .stateVisit
        case .demandApology: return .demandApology
        case .severRelations: return .severRelations
        case .restoreRelations: return .restoreRelations
        case .condemn: return .unCondemn
        case .propaganda: return .propaganda
        case .spy: return .deploySpies
        case .satellite: return .satellite
        case .sabotage: return .sabotageInfra
        case .cyber: return .cyberAttack
        case .supportRebels: return .supportRebels
        case .stealTech: return .stealTech
        case .deployTroops: return .deployTroops
        case .withdrawTroops: return .withdrawTroops
        case .exercise: return .militaryExercise
        case .caseForWar: return .makeCaseForWar
        default: return nil
        }
    }

    var isForce: Bool { [.attack, .declareWar, .invade, .airStrike, .navalStrike, .blockade, .showOfForce, .landing, .nuke].contains(self) }
    var isLand: Bool { [.claim, .buy, .liberate].contains(self) }

    /// The card's heading.
    var title: String {
        switch self {
        case .attack: return "ATTACK"
        case .declareWar: return "DECLARE WAR"
        case .invade: return "GROUND INVASION"
        case .airStrike: return "AIR STRIKE"
        case .navalStrike: return "NAVAL STRIKE"
        case .blockade: return "BLOCKADE"
        case .showOfForce: return "SHOW OF FORCE"
        case .landing: return "AMPHIBIOUS LANDING"
        case .nuke: return "NUCLEAR STRIKE"
        case .claim: return "CLAIM LAND"
        case .buy: return "BUY COLONY"
        case .liberate: return "BACK INDEPENDENCE"
        case .rename: return "RENAME"
        case .develop: return "INVEST"
        default: return antarcticOrder?.title ?? powerPlayTitle ?? HomePlay(verb: self)?.title ?? (simpleAction?.rawValue ?? rawValue).uppercased()
        }
    }
}

/// The forces a command asks for. nil = not said.
struct ForceRequest: Codable, Equatable, Sendable {
    var ground: Bool?
    var air: Bool?
    var naval: Bool?
    /// false = "non-nuclear" / "conventional"; true = nuclear asked for by name.
    var nuclear: Bool?
    /// "all", "everything", "full force".
    var all = false
    /// "half": a share of what is free (0…1).
    var share: Double?
    var troops: Double?
    var aircraft: Int?
    var warheads: Int?
    var tactical = false
    /// "probe", "light": the small preset.
    var light = false
    /// A fleet named in the text ("seventh fleet"), matched against the era's fleets by the planner.
    var fleet: String?

    var namesAKind: Bool { ground == true || air == true || naval == true || nuclear == true }
}

/// The read-only questions the command box answers from the game state.
enum QuestionTopic: String, Codable, CaseIterable, Sendable {
    case reachMe, canReach, stat, wars, allies, actions, defcon, arsenal, fleets, help
}

/// A country figure a question can ask about.
enum StatField: String, Codable, CaseIterable, Sendable {
    case stability, military, warheads, approval, relations, economy, population, government, leader, summary
}

/// What weapon a "who can reach me" question means.
enum ReachWeapon: String, Codable, CaseIterable, Sendable {
    case any, missiles, bombers, nuclear
}

struct CommandQuestion: Codable, Equatable, Sendable {
    var topic: QuestionTopic
    var country: String?
    var field: StatField?
    var weapon: ReachWeapon?
}

/// What a command asks for, before any name is resolved or number filled in.
struct CommandIntent: Codable, Equatable, Sendable {
    var verb: CommandVerb?
    /// Names as typed (a nation, a land, an era name, an alias, an ISO code), at most `CommandParser.maxTargets`.
    var targets: [String] = []
    var forces = ForceRequest()
    var question: CommandQuestion?
    /// Ids the player picked in a clarification; they skip the name resolver and its questions.
    var confirmedTargets: [String]?
    /// 3.36.0: a power play's parameter (a strike kind, a legal authority, an emergency's reason), from a closed list.
    var detail: String?
    /// 3.36.0: for `.rename`, each land (as typed, or "me" for the President's own country) and its new name.
    var renames: [RenameRequest]?

    static func ask(_ q: CommandQuestion) -> CommandIntent { CommandIntent(question: q) }
}

/// One rename asked for: the land as typed and the new name exactly as typed (case and punctuation kept).
struct RenameRequest: Codable, Equatable, Sendable {
    var target: String
    var name: String
}

enum CommandParser {
    static let maxInput = 200
    /// Renames one plan may hold (the chief of staff's "rename every colony…").
    static let maxRenames = 20
    static let maxTargets = 4
    /// Targets one plan may hold when a region name expands to its nations.
    static let maxRegionTargets = 80

    /// Trim, drop control characters, and cap the length (the prompt-injection and memory bound).
    static func sanitize(_ raw: String) -> String {
        let kept = raw.unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) && !CharacterSet.illegalCharacters.contains($0) }
        return String(String(String.UnicodeScalarView(kept)).trimmingCharacters(in: .whitespacesAndNewlines).prefix(maxInput))
    }

    /// Lowercase words separated by single spaces: punctuation and hyphens become spaces, possessives and accents go.
    static func normalize(_ s: String) -> String {
        var t = s.lowercased()
        if !t.unicodeScalars.allSatisfy(\.isASCII) { t = t.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US")) }
        t = t.replacingOccurrences(of: "’", with: "'").replacingOccurrences(of: "'s ", with: " ")
        if t.hasSuffix("'s") { t.removeLast(2) }
        let mapped = t.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) ? Character($0) : " " }
        return String(mapped).split(separator: " ").joined(separator: " ")
    }

    /// `normalize` for the game's own names (a finite set), remembered: name lookups run it for every nation.
    static func normalizedName(_ s: String) -> String {
        nameLock.lock(); defer { nameLock.unlock() }
        if let n = nameCache[s] { return n }
        let n = normalize(s)
        if nameCache.count < 5_000 { nameCache[s] = n }
        return n
    }
    private static let nameLock = NSLock()
    nonisolated(unsafe) private static var nameCache: [String: String] = [:]

    // MARK: Phrases

    /// Polite or framing words in front of an order.
    static let prefixes = ["please", "i want to", "i would like to", "i d like to", "id like to", "let us", "lets", "let s",
                           "we should", "we will", "go ahead and", "now", "immediately", "order", "i order", "we",
                           "i", "you", "the president orders", "mr president", "computer"]

    /// Verb phrases, matched at the start of the command (longest first).
    static let phrases: [(String, CommandVerb)] = {
        let table: [CommandVerb: [String]] = [
            .attack: ["attack", "strike", "hit", "assault", "launch an attack on", "launch an attack against", "launch attack on",
                      "launch an offensive against", "launch an offensive on", "offensive against", "go after", "destroy"],
            .declareWar: ["declare war on", "declare war against", "declare war", "go to war with", "go to war against",
                          "start a war with", "start war with", "wage war on", "wage war against"],
            .invade: ["invade", "ground invasion of", "send troops into", "send the army into", "send army into",
                      "march on", "march into", "occupy"],
            .airStrike: ["air strike on", "air strike against", "air strikes on", "air strike", "airstrike", "airstrikes on",
                         "bomb", "air raid on", "air raid", "bombard"],
            .navalStrike: ["naval strike on", "naval strike against", "naval strike", "shell"],
            .blockade: ["naval blockade of", "naval blockade on", "naval blockade", "blockade the ports of", "blockade"],
            .showOfForce: ["show of force against", "show of force near", "show of force off", "show of force", "show the flag off",
                           "show the flag", "send the fleet to", "send a fleet to", "send the navy to", "send navy to", "sail to"],
            .landing: ["amphibious landing on", "amphibious landing in", "amphibious landing", "amphibious assault on",
                       "amphibious assault", "land troops in", "land troops on", "land marines in"],
            .nuke: ["nuke", "nuclear strike on", "nuclear strike against", "nuclear strike", "launch a nuclear strike on",
                    "launch a nuclear strike against", "launch nukes at", "launch nukes on", "launch nukes", "launch nuclear weapons at",
                    "launch missiles at", "fire nukes at", "tactical nuke", "use nukes on", "use nuclear weapons on"],
            .ally: ["ally with", "form an alliance with", "form alliance with", "alliance with", "make an alliance with",
                    "join an alliance with", "sign a defense pact with", "defensive pact with", "mutual defense with", "ally"],
            .leaveAlliance: ["leave the alliance with", "leave alliance with", "break the alliance with", "break alliance with",
                             "end the alliance with", "end alliance with"],
            .peace: ["make peace with", "peace with", "sue for peace with", "sign a peace treaty with", "peace treaty with",
                     "end the war with", "end war with", "end the war against"],
            .ceasefire: ["ceasefire with", "cease fire with", "call a ceasefire with", "agree a ceasefire with", "truce with"],
            .nonAggression: ["non aggression pact with", "nonaggression pact with", "sign a non aggression pact with"],
            .sanction: ["sanction", "impose sanctions on", "sanctions on", "put sanctions on", "economic sanctions on",
                        "impose economic sanctions on"],
            .liftSanctions: ["lift sanctions on", "lift the sanctions on", "remove sanctions on", "end sanctions on", "unsanction"],
            .embargo: ["oil embargo on", "oil embargo against", "impose an oil embargo on", "embargo"],
            .freezeAssets: ["freeze the assets of", "freeze assets of", "freeze"],
            .tariffs: ["impose tariffs on", "put tariffs on", "tariffs on", "tariff"],
            .trade: ["sign a trade deal with", "trade deal with", "trade agreement with", "trade with"],
            .aid: ["send aid to", "send economic aid to", "economic aid to", "give aid to", "give economic aid to", "aid"],
            .foodAid: ["send food aid to", "food aid to", "send food to"],
            .militaryAid: ["send military aid to", "military aid to", "arm"],
            .sellWeapons: ["sell weapons to", "sell arms to"],
            .ambassador: ["send an ambassador to", "send ambassador to", "send our ambassador to"],
            .recallAmbassador: ["recall our ambassador from", "recall the ambassador from", "recall ambassador from"],
            .summit: ["hold a summit with", "arrange a summit with", "summit with", "meet with"],
            .stateVisit: ["state visit to", "make a state visit to", "visit"],
            .demandApology: ["demand an apology from", "demand apology from"],
            .severRelations: ["sever relations with", "cut ties with", "break off relations with", "break relations with"],
            .restoreRelations: ["restore relations with", "normalize relations with"],
            .condemn: ["condemn", "un condemnation of"],
            .propaganda: ["run propaganda against", "propaganda campaign against", "propaganda against"],
            .spy: ["spy on", "send spies to", "deploy spies to", "deploy spies in", "deploy spies against"],
            .satellite: ["satellite recon of", "satellite reconnaissance of", "satellite recon on"],
            .sabotage: ["sabotage"],
            .cyber: ["cyber attack on", "cyber attack against", "cyber attack", "cyberattack", "hack"],
            .supportRebels: ["support rebels in", "support the rebels in", "arm rebels in", "arm the rebels in",
                             "back the rebels in", "back rebels in"],
            .stealTech: ["steal technology from", "steal tech from"],
            .deployTroops: ["deploy troops to", "deploy forces to", "deploy", "send", "send troops to", "station troops in", "station troops on"],
            .withdrawTroops: ["withdraw troops from", "withdraw from", "pull troops out of", "pull out of"],
            .exercise: ["hold military exercises near", "military exercise near", "military exercises near", "hold exercises near",
                        "war games near"],
            .caseForWar: ["make the case for war against", "make the case for war on", "make case for war against",
                          "make the case for war with"],
            .claim: ["claim", "colonize", "colonise", "settle"],
            .buy: ["buy", "purchase"],
            .liberate: ["back the independence of", "back independence of", "support independence of", "support the independence of",
                        "liberate", "free"],
            .develop: ["invest in", "develop", "build up"],
            .researchStation: ["build a research station in", "build a research station on", "build a research station",
                               "build a station in", "build a station on", "open a research station in", "open a research station",
                               "establish a research station in", "establish a research station", "set up a research station in",
                               "research station in", "research station on", "build an antarctic station", "build a base in antarctica"],
            .joinAntarcticTreaty: ["sign the antarctic treaty", "sign antarctic treaty", "rejoin the antarctic treaty", "rejoin antarctic treaty",
                                   "join the antarctic treaty", "join antarctic treaty", "return to the antarctic treaty", "ratify the antarctic treaty"],
            .leaveAntarcticTreaty: ["withdraw from the antarctic treaty", "withdraw from antarctic treaty", "leave the antarctic treaty",
                                    "leave antarctic treaty", "quit the antarctic treaty", "pull out of the antarctic treaty", "exit the antarctic treaty",
                                    "tear up the antarctic treaty", "break the antarctic treaty"],
            .renegotiateAntarcticTreaty: ["renegotiate the antarctic treaty", "renegotiate antarctic treaty", "amend the antarctic treaty",
                                          "reopen the antarctic treaty"],
        ]
        return table.flatMap { verb, list in list.map { ($0, verb) } }.sorted { $0.0.count > $1.0.count }
    }()

    /// Prepositions and articles between the verb and the target.
    static let leadIns: Set<String> = ["on", "against", "to", "with", "into", "in", "of", "from", "at", "near", "off", "the", "for"]

    /// Where the target names stop and the force clause starts.
    static let clauseBreaks = [" with ", " using ", " by ", " but ", " except ", " excluding ", " without ", " that ", " and hold",
                               " hold back", " only ", " keep ", " leaving "]

    // MARK: Parse

    /// The intent of a command, or nil when the built-in reader can't place it (then the local model is asked).
    static func parse(_ raw: String) -> CommandIntent? {
        let text = normalize(sanitize(raw))
        guard !text.isEmpty else { return nil }
        // 3.36.0: renames (a sea, mountain or department first, then a country or land; RenamePlanner.swift), power plays.
        if let r = PowerPlayParser.parseRename(raw) ?? parseRename(sanitize(raw)) { return r }
        // Power plays at home before the campaign steps ("pressure the Fed" is the central bank, not a campaign step).
        if let home = parseOrder(text), let v = home.verb, HomePlay(verb: v) != nil { return home }
        if let p = PowerPlayParser.parse(text) { return p }
        if questionStarts.contains(where: { text == $0 || text.hasPrefix($0 + " ") }) || helpWords.contains(text) {
            return parseQuestion(text, raw: raw).map(CommandIntent.ask)
        }
        if let order = parseOrder(text) { return order }
        return raw.contains("?") ? parseQuestion(text, raw: raw).map(CommandIntent.ask) : nil
    }

    /// Words a question starts with.
    static let questionStarts = ["who", "what", "whats", "what s", "how", "which", "can i", "can we", "is", "are", "do", "does",
                                 "show", "list", "tell me", "status", "where", "help"]
    static let helpWords: Set<String> = ["help", "commands", "what can i say", "what can i do", "what can i type", "examples", "h"]

    static func parseOrder(_ text: String) -> CommandIntent? {
        var body = " " + text + " "
        // Strip framing words ("please", "I want to") repeatedly.
        var stripped = true
        while stripped {
            stripped = false
            for p in prefixes where body.hasPrefix(" " + p + " ") {
                body = String(body.dropFirst(p.count + 1))
                stripped = true
            }
        }
        body = body.trimmingCharacters(in: .whitespaces)
        if let home = HomePlayCommands.parse(body) { return home }   // 3.36.0: power plays at home
        guard let (phrase, verb0) = phrases.first(where: { body == $0.0 || body.hasPrefix($0.0 + " ") }) else { return nil }
        var verb = verb0
        let rest = String(body.dropFirst(phrase.count)).trimmingCharacters(in: .whitespaces)
        var forces = parseForces(" " + rest + " ")
        if phrase == "tactical nuke" { forces.tactical = true }
        // "deploy the navy to X" / "deploy the seventh fleet to X": a fleet, not troops.
        if verb == .deployTroops, forces.naval == true || forces.fleet != nil, forces.ground != true { verb = .showOfForce }
        if verb == .nuke { forces.nuclear = forces.nuclear ?? true }
        let targets = targetNames(in: rest, verb: verb)
        return CommandIntent(verb: verb, targets: targets, forces: forces)
    }

    /// Words that mean the President's own country in a rename ("rename my country to …").
    static let selfNames: Set<String> = ["me", "my country", "my nation", "our country", "our nation", "us", "the country", "my own country",
                                         "this country", "my homeland", "our homeland", "home", "my state", "my people"]

    /// "rename X to Y", "rename X as Y", "rename my country to Y". The new name keeps its case and punctuation;
    /// quotes around it are dropped. Nil when the text is not a rename.
    static func parseRename(_ raw: String) -> CommandIntent? {
        var body = raw.trimmingCharacters(in: .whitespaces)
        for p in ["please ", "i want to ", "let's ", "lets ", "now ", "go ahead and ", "i order you to ", "we should "]
        where body.lowercased().hasPrefix(p) { body = String(body.dropFirst(p.count)) }
        guard body.lowercased().hasPrefix("rename ") else { return nil }
        body = String(body.dropFirst("rename ".count))
        let lower = body.lowercased()
        guard let r = lower.range(of: " to ") ?? lower.range(of: " as ") else {
            return CommandIntent(verb: .rename, renames: [])
        }
        let what = String(body[..<r.lowerBound])
        var name = String(body[r.upperBound...]).trimmingCharacters(in: .whitespaces)
        if name.hasSuffix(".") || name.hasSuffix("!") { name.removeLast() }
        name = name.trimmingCharacters(in: CharacterSet(charactersIn: "\"'“”‘’ "))
        // 3.37.0: a list ("Texas, Ohio and Iowa") keeps its commas; the planner splits it (RenamePlanner.swift).
        let target = what.split(separator: ",").map { piece -> String in
            var t = normalize(String(piece))
            for lead in ["the "] where t.hasPrefix(lead) && t.count > lead.count + 2 && !selfNames.contains(t) { t = String(t.dropFirst(lead.count)) }
            return selfNames.contains(t) ? "me" : t
        }.filter { !$0.isEmpty }.joined(separator: ", ")
        guard !target.isEmpty else { return CommandIntent(verb: .rename, renames: []) }
        return CommandIntent(verb: .rename, targets: [target], renames: [RenameRequest(target: target, name: name)])
    }

    /// The names between the verb and the force clause: "madagascar", or "iran and iraq" → two.
    static func targetNames(in rest: String, verb: CommandVerb) -> [String] {
        var words = rest.split(separator: " ").map(String.init)
        // "deploy troops to X", "send the seventh fleet to X": skip what is being sent.
        if [.deployTroops, .showOfForce].contains(verb), let to = words.firstIndex(where: { $0 == "to" || $0 == "near" || $0 == "off" }) {
            words = Array(words[(to + 1)...])
        }
        while let first = words.first, leadIns.contains(first) { words.removeFirst() }
        // 3.36.0: "claim all of Africa", "the whole of Africa": a region, not the force word "all".
        for lead in [["all", "of"], ["whole", "of"], ["every", "nation", "in"], ["all", "nations", "in"], ["all", "lands", "in"],
                     ["all", "land", "in"], ["every", "land", "in"]] where words.count > lead.count && Array(words.prefix(lead.count)) == lead {
            words.removeFirst(lead.count)
            if words.first == "the", words.count > 1 { words.removeFirst() }
            break
        }
        var s = " " + words.joined(separator: " ") + " "
        for b in clauseBreaks { if let r = s.range(of: b) { s = String(s[..<r.lowerBound]) + " " } }
        // Force words that end the names without a preposition ("attack france all air").
        let stops: Set<String> = ["all", "every", "everything", "full", "air", "naval", "navy", "army", "ground", "nuclear", "nukes",
                                  "troops", "forces", "conventional", "non", "half", "now", "immediately", "today", "please", "right",
                                  "asap", "quickly", "at", "this", "tonight", "soon", "first", "again"]
        var kept: [String] = []
        for w in s.split(separator: " ").map(String.init) {
            if stops.contains(w) || w.first?.isNumber == true { break }
            kept.append(w)
        }
        let name = kept.joined(separator: " ")
        guard !name.isEmpty else { return [] }
        return [name]
    }

    /// The forces named in a command's text (`text` padded with spaces).
    static func parseForces(_ text: String) -> ForceRequest {
        var f = ForceRequest()
        var t = text
        let negations = [" non nuclear ", " nonnuclear ", " conventional ", " no nukes ", " no nuclear ", " without nukes ",
                         " without nuclear ", " not nuclear ", " hold back nukes ", " hold back the nukes ", " keep the nukes ",
                         " no nuclear weapons ", " without nuclear weapons ", " except nuclear ", " except nukes ",
                         " excluding nuclear ", " excluding nukes ", " but nuclear ", " but not nuclear "]
        for n in negations where t.contains(n) {
            f.nuclear = false
            t = t.replacingOccurrences(of: n, with: " ")
        }
        func has(_ words: [String]) -> Bool { words.contains { t.contains(" \($0) ") } }
        if f.nuclear == nil, has(["nuclear", "nukes", "nuke", "warheads", "warhead", "atomic", "icbms", "icbm"]) { f.nuclear = true }
        if has(["air", "aircraft", "air force", "airforce", "planes", "bombers", "jets", "sorties", "air forces"]) { f.air = true }
        if has(["naval", "navy", "fleet", "fleets", "ships", "sea", "squadron", "warships"]) { f.naval = true }
        if has(["army", "ground", "troops", "land forces", "infantry", "soldiers", "armies", "men", "divisions"]) { f.ground = true }
        if has(["all", "everything", "every", "full force", "maximum", "whole", "everything we have", "all out"]) { f.all = true }
        if has(["half"]) { f.share = 0.5 }
        if has(["tactical"]) { f.tactical = true }
        if has(["probe", "light", "small", "limited"]) { f.light = true }
        // "naval only" / "only air": the other kinds are off.
        if t.contains(" only ") {
            if f.air != true { f.air = false }
            if f.naval != true { f.naval = false }
            if f.ground != true { f.ground = false }
        }
        // Numbers: "50k troops", "50000 troops", "200 aircraft", "3 warheads".
        let words = t.split(separator: " ").map(String.init)
        for (i, w) in words.enumerated() {
            var digits = w
            var thousands = false
            if digits.hasSuffix("k"), digits.count > 1 { digits.removeLast(); thousands = true }
            guard let n = Double(digits), n.isFinite, n >= 0 else { continue }
            var j = i + 1
            if j < words.count, words[j] == "thousand" || words[j] == "k" { thousands = true; j += 1 }
            guard j < words.count else { continue }
            let unit = words[j]
            if ["troops", "men", "soldiers", "infantry"].contains(unit) {
                f.troops = thousands ? n : (n >= 1000 ? n / 1000 : n)
                f.ground = true
            } else if ["aircraft", "planes", "sorties", "bombers", "jets"].contains(unit) {
                f.aircraft = Int(min(n * (thousands ? 1000 : 1), 1_000_000))
                f.air = true
            } else if ["warheads", "warhead", "nukes", "nuke", "missiles", "bombs"].contains(unit) {
                f.warheads = Int(min(n * (thousands ? 1000 : 1), 1_000_000))
                if f.nuclear == nil { f.nuclear = true }
            }
        }
        // A named fleet: "seventh fleet", "7th fleet", "pacific fleet", "home squadron".
        for (i, w) in words.enumerated() where (w == "fleet" || w == "squadron") && i > 0 {
            let before = words[i - 1]
            if !["the", "a", "our", "whole", "entire", "naval", "all"].contains(before) {
                f.fleet = before + " " + w
                if i > 1, !["the", "a", "our", "send", "deploy", "with"].contains(words[i - 2]) { f.fleet = words[i - 2] + " " + before + " " + w }
            }
        }
        return f
    }

    // MARK: Questions

    static func parseQuestion(_ t: String, raw: String) -> CommandQuestion? {
        let p = " " + t + " "
        let asks = raw.contains("?") || ["who ", "what ", "whats ", "what s ", "how ", "which ", "can ", "is ", "are ", "do ", "does ",
                                         "show ", "list ", "tell me", "status", "where "].contains { t.hasPrefix($0) }
        if helpWords.contains(t) {
            return CommandQuestion(topic: .help)
        }
        guard asks else { return nil }
        func has(_ s: String) -> Bool { p.contains(" \(s) ") }
        if has("help") { return CommandQuestion(topic: .help) }
        if (has("reach") || has("hit") || has("strike") || has("nuke") || has("attack")) && (has("me") || has("us")) && (has("who") || has("which")) {
            let weapon: ReachWeapon = (has("icbms") || has("icbm") || has("missiles") || has("missile") || has("slbms")) ? .missiles
                : (has("bombers") || has("bomber")) ? .bombers : (has("nukes") || has("nuclear") || has("nuke")) ? .nuclear : .any
            return CommandQuestion(topic: .reachMe, weapon: weapon)
        }
        if (has("can i") || has("can we")) && (has("reach") || has("hit") || has("attack") || has("strike")) {
            let name = stripWords(t, ["can", "i", "we", "reach", "hit", "attack", "strike", "with", "our", "my", "forces", "army", "navy"])
            return CommandQuestion(topic: .canReach, country: name.isEmpty ? nil : name)
        }
        if (has("war") || has("fighting")) && (has("me") || has("i") || has("we") || has("us") || has("my")) {
            return CommandQuestion(topic: .wars)
        }
        if has("allies") || has("ally") || has("alliances") { return CommandQuestion(topic: .allies) }
        if has("actions") || has("moves left") { return CommandQuestion(topic: .actions) }
        if has("defcon") || has("alert level") { return CommandQuestion(topic: .defcon) }
        if has("fleets") || has("fleet") || has("navy") && has("where") { return CommandQuestion(topic: .fleets) }
        let mine = has("my") || has("our") || has("do i") || has("do we")
        if mine && (has("warheads") || has("nukes") || has("arsenal")) { return CommandQuestion(topic: .arsenal) }
        // A figure about a nation: "what's France's stability?", "how strong is Spain?", "tell me about Japan".
        let fields: [(StatField, [String])] = [
            (.stability, ["stability", "stable", "unrest"]),
            (.military, ["military", "strong", "strength", "army", "forces"]),
            (.warheads, ["warheads", "nukes", "nuclear", "arsenal"]),
            (.approval, ["approval", "popularity", "popular"]),
            (.relations, ["relations", "relationship", "think of us", "feel about us"]),
            (.economy, ["economy", "gdp", "rich", "wealth"]),
            (.population, ["population", "people", "big"]),
            (.government, ["government", "regime"]),
            (.leader, ["leader", "runs", "rules", "in charge"]),
        ]
        var field: StatField = .summary
        for (f, words) in fields where words.contains(where: { has($0) }) { field = f; break }
        let filler = ["what", "whats", "what s", "is", "are", "the", "how", "which", "show", "me", "list", "tell", "about", "status", "of",
                      "s", "does", "do", "have", "has", "many", "much", "who", "where", "a", "an", "in", "on", "with", "us", "our", "their",
                      "its", "intel", "dossier", "report", "level", "rating", "score", "current", "currently", "now", "think", "feel", "charge",
                      "runs", "rules", "toward", "towards", "stand", "stands", "doing", "big"]
            + fields.flatMap(\.1).flatMap { $0.split(separator: " ").map(String.init) }
        let name = stripWords(t, filler)
        guard !name.isEmpty else { return nil }
        return CommandQuestion(topic: .stat, country: name, field: field)
    }

    private static func stripWords(_ t: String, _ words: [String]) -> String {
        let drop = Set(words)
        return t.split(separator: " ").map(String.init).filter { !drop.contains($0) }.joined(separator: " ")
    }
}
