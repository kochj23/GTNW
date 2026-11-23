//
//  GroupActionQuery.swift
//  GTNWCore
//
//  `{"q":"groupAction","pick":"region","region":"Europe","kind":"aid","amount":10,"split":"byNeed"}`:
//  GroupActionSheet. Act on many nations at once: the group (territories, allies, a region, hand-picked, or a saved
//  group), the action and its amount, and the per-nation breakdown with the total before the President confirms once.
//  Carried out with the `groupAction` verb (same fields); a hand-picked group is saved with `saveGroup`.
//

#if GTNW_CORE
import Foundation

enum GroupActionQuery: BridgeQuery {
    static let name = "groupAction"

    /// pick: territories, allies, region, handPicked, saved. kind: GroupActionKind. split: even, byNeed. rate: ExtractionRate.
    struct Args: Decodable {
        var pick: String?
        var region: String?
        var ids: [String]?
        var saved: String?
        var kind: String?
        var amount: Double?
        var garrison: Double?
        var split: String?
        var rate: String?

        func selector(_ gs: GameState) -> GroupSelector {
            switch pick ?? "allies" {
            case "territories": return .territories
            case "region": return .region(region.flatMap(WorldRegion.init(rawValue:)) ?? .europe)
            case "handPicked": return .custom(name: "Hand-picked", ids: (ids ?? []).sorted())
            case "saved": let n = saved ?? ""; return .custom(name: n, ids: gs.shadow.savedGroups[n] ?? [])
            default: return .allies
            }
        }
        var kindValue: GroupActionKind { kind.flatMap(GroupActionKind.init(rawValue:)) ?? .message }
        var splitValue: AidSplit { split.flatMap(AidSplit.init(rawValue:)) ?? .byNeed }
        var rateValue: ExtractionRate { rate.flatMap(ExtractionRate.init(rawValue:)) ?? .normal }
        var amountValue: Double { kindValue == .garrison ? (garrison ?? 5) : (amount ?? 10) }
    }

    struct Choice: Encodable { var id: String; var title: String; var harsh: Bool }
    struct Nation: Encodable { var id: String; var name: String }

    struct Result: Encodable {
        var saved: [String]
        var regions: [String]
        var kinds: [Choice]
        var splits: [Choice]
        var rates: [Choice]
        var nations: [Nation]
        var aidLeft: String
        var freeTroops: String
        var summary: String
        var lines: [String]
        var more: String?
        var problem: String?
        var confirmTitle: String
        var groupTitle: String
    }

    static func run(_ args: Args, engine: GameEngine?) throws -> Result {
        let (e, gs) = try GTNWBridge.game(engine)
        let kind = args.kindValue
        let members = e.groupMembers(args.selector(gs))
        let plan = e.planGroupAction(kind, members: members, amount: args.amountValue, split: args.splitValue, rate: args.rateValue)
        let n = plan.lines.count
        return Result(
            saved: gs.shadow.savedGroups.keys.sorted(),
            regions: WorldRegion.allCases.map(\.rawValue),
            kinds: GroupActionKind.allCases.map { Choice(id: $0.rawValue, title: $0.title, harsh: $0 == .sanctions || $0 == .recall) },
            splits: AidSplit.allCases.map { Choice(id: $0.rawValue, title: $0.title, harsh: false) },
            rates: ExtractionRate.ordinary.map { Choice(id: $0.rawValue, title: $0.title, harsh: $0.insurgencyShift > 0) },
            nations: gs.countries.filter { !$0.isDestroyed && $0.id != gs.playerCountryID }.sorted { $0.name < $1.name }.map { Nation(id: $0.id, name: $0.name) },
            aidLeft: String(format: "$%.1fB left this year", gs.shadow.aidRemaining),
            freeTroops: "\(Int(AttackSizing.freeTroops(gs)))K free",
            summary: String(format: "%d nation%@ · total %@", n, n == 1 ? "" : "s",
                            kind == .garrison ? "\(Int(plan.total))K more troops" : String(format: "$%.2fB", plan.total)),
            lines: plan.lines.prefix(12).map { "\($0.name): \($0.detail)" },
            more: n > 12 ? "…and \(n - 12) more" : nil,
            problem: plan.problem,
            confirmTitle: "Confirm \(kind.title) for \(n)",
            groupTitle: args.selector(gs).title)
    }
}
#endif
