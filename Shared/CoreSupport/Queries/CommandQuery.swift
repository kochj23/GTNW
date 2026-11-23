//
//  CommandQuery.swift
//  GTNWCore
//
//  The command box (3.34.0) for a front end. Reading and planning only; nothing here changes the game:
//
//    {"q":"command","text":"attack France with all air forces"}   the built-in reader (CommandParser), then the
//                                                                  planner (CommandPlanner), exactly as the app runs them
//    {"q":"command","intent":{...}}                                re-plan a clarification choice (its `intent`)
//    {"q":"command","model":{...}}                                 a local model's translation (the app's `ModelCommand`
//                                                                  JSON), checked field by field against the closed
//                                                                  lists and then planned by the same planner
//    {"q":"command","schema":true}                                 the closed lists (verbs, topics, fields, weapons)
//
//  The answer is one of: `plan` (the confirmation card and the `GameOrder`s EXECUTE will run), `clarify` (a question
//  with choices, each carrying the intent to send back), `answer` (lines answering a question), `rejected` (why not),
//  or `unparsed` (the built-in reader could not place the text: ask the model, or say why it can't be asked).
//  EXECUTE is `act` with `"orders":[...]` and `"source"`: the engine checks every order again before it runs.
//

#if GTNW_CORE
import Foundation

enum CommandQuery: BridgeQuery {
    static let name = "command"

    /// The app's `ModelCommand` (Shared/AI/CommandTranslator.swift, app-only): the JSON a model must return.
    struct ModelCommand: Codable, Equatable {
        var kind: String
        var verb: String
        var targets: [String]
        var ground: Bool
        var air: Bool
        var naval: Bool
        var nuclear: String
        var all: Bool
        var troops: Double?
        var aircraft: Int?
        var warheads: Int?
        var topic: String
        var field: String
        var weapon: String?

        static let kinds = ["order", "question", "unknown"]
        static let nuclearWords = ["yes", "no", "unspecified"]

        /// `ModelCommand.intent()`, rule for rule: every field checked against its list; nil = nothing the game may
        /// act on; a thrown error = the reply broke the schema.
        func intent() throws -> CommandIntent? {
            guard Self.kinds.contains(kind) else { throw QueryError("kind must be order, question or unknown") }
            guard targets.count <= CommandParser.maxTargets, targets.allSatisfy({ $0.count <= 60 }) else {
                throw QueryError("at most \(CommandParser.maxTargets) short names")
            }
            for v in [troops, aircraft.map(Double.init), warheads.map(Double.init)] {
                if let v, !v.isFinite || v < 0 || v > 10_000_000 { throw QueryError("numbers out of range") }
            }
            let names = targets.map(CommandParser.sanitize).filter { !$0.isEmpty }
            switch kind {
            case "order":
                guard let v = CommandVerb(rawValue: verb) else { throw QueryError("verb must be one of the listed verbs") }
                guard Self.nuclearWords.contains(nuclear) else { throw QueryError("nuclear must be yes, no or unspecified") }
                var f = ForceRequest()
                f.ground = ground ? true : nil
                f.air = air ? true : nil
                f.naval = naval ? true : nil
                f.nuclear = nuclear == "yes" ? true : (nuclear == "no" ? false : nil)
                f.all = all
                f.troops = troops.flatMap { $0 > 0 ? $0 : nil }
                f.aircraft = aircraft.flatMap { $0 > 0 ? $0 : nil }
                f.warheads = warheads.flatMap { $0 > 0 ? $0 : nil }
                if v == .nuke, f.nuclear == nil { f.nuclear = true }
                return CommandIntent(verb: v, targets: names, forces: f)
            case "question":
                guard let t = QuestionTopic(rawValue: topic) else { throw QueryError("topic must be one of the listed topics") }
                let fld = StatField(rawValue: field)
                let w = weapon.flatMap(ReachWeapon.init(rawValue:))
                return .ask(CommandQuestion(topic: t, country: names.first, field: t == .stat ? (fld ?? .summary) : nil,
                                            weapon: t == .reachMe ? (w ?? .any) : nil))
            default:
                return nil
            }
        }
    }

    struct Args: Decodable {
        var text: String?
        var intent: CommandIntent?
        var model: ModelCommand?
        /// The source a re-planned `intent` came from (`parser` or `model`), as the clarification said.
        var source: String?
        var schema: Bool?
    }

    struct Warning: Encodable { var text: String; var level: Int }

    struct Plan: Encodable {
        var title: String
        var target: String
        var orders: [GameOrder]
        var summaries: [String]
        var committed: [String]
        var heldBack: [String]
        var warnings: [Warning]
        var actionsNeeded: Int
        var actionsLeft: Int
        var source: String
        var nuclear: Bool
    }

    struct Option: Encodable { var label: String; var intent: CommandIntent }
    struct Clarify: Encodable { var question: String; var options: [Option]; var source: String }

    struct Schema: Encodable {
        var kinds: [String]
        var verbs: [String]
        var nuclear: [String]
        var topics: [String]
        var fields: [String]
        var weapons: [String]
        var maxTargets: Int
        var maxInput: Int
    }

    struct Result: Encodable {
        /// plan, clarify, answer, rejected, unparsed, schema
        var kind: String
        var plan: Plan?
        var clarify: Clarify?
        var lines: [String]?
        var reason: String?
        var schema: Schema?
        /// What the reader kept of the text (trimmed, control characters gone, capped), for the history.
        var text: String?
    }

    static let schema = Schema(
        kinds: ModelCommand.kinds, verbs: CommandVerb.allCases.map(\.rawValue), nuclear: ModelCommand.nuclearWords,
        topics: QuestionTopic.allCases.map(\.rawValue), fields: StatField.allCases.map(\.rawValue),
        weapons: ReachWeapon.allCases.map(\.rawValue), maxTargets: CommandParser.maxTargets, maxInput: CommandParser.maxInput)

    /// What CommandBoxModel says when the model understood nothing it may act on.
    static let notUnderstood = "No order or question the game knows matches that. Type HELP for examples."

    static func run(_ args: Args, engine: GameEngine?) throws -> Result {
        if args.schema == true { return Result(kind: "schema", schema: schema) }
        let (e, _) = try GTNWBridge.game(engine)
        if let m = args.model {
            guard let intent = (try? m.intent()) ?? nil else { return Result(kind: "rejected", reason: notUnderstood) }
            return result(e.planCommand(intent, source: .model))
        }
        if let intent = args.intent {
            let source = args.source.flatMap(CommandSource.init(rawValue:)) ?? .parser
            return result(e.planCommand(intent, source: source == .replay ? .parser : source))
        }
        guard let raw = args.text else { throw QueryError("text, intent or model is required") }
        let clean = CommandParser.sanitize(raw)
        guard !clean.isEmpty else { throw QueryError("empty command") }
        guard let intent = CommandParser.parse(clean) else { return Result(kind: "unparsed", text: clean) }
        var r = result(e.planCommand(intent, source: .parser))
        r.text = clean
        return r
    }

    static func result(_ outcome: CommandOutcome) -> Result {
        switch outcome {
        case .plan(let p):
            return Result(kind: "plan", plan: Plan(
                title: p.title, target: p.target, orders: p.orders, summaries: p.orders.map(\.summary), committed: p.committed,
                heldBack: p.heldBack, warnings: p.warnings.map { Warning(text: $0.text, level: $0.level) },
                actionsNeeded: p.actionsNeeded, actionsLeft: p.actionsLeft, source: p.source.rawValue, nuclear: p.nuclear))
        case .clarify(let c):
            return Result(kind: "clarify", clarify: Clarify(question: c.question, options: c.options.map { Option(label: $0.label, intent: $0.intent) },
                                                            source: c.source.rawValue))
        case .answer(let lines):
            return Result(kind: "answer", lines: lines)
        case .rejected(let why):
            return Result(kind: "rejected", reason: why)
        }
    }
}
#endif
