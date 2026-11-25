//
//  RenamesQuery.swift
//  GTNWCore
//
//  `{"q":"renames","id":"…"?,"name":"…"?}` (3.37): everything the President may rename (Renaming.swift, 3.36.0),
//  grouped as the app's rename menus group it: his own nation and the lands he holds (TerritoryNameSheet), his
//  departments, this year's seas, straits and mountains, and the states and provinces he holds (POWER PLAYS → NAMES).
//  With `id` and `name`: the same check the app runs before RENAME (`NameScreen` through `renameCheck`; for a place
//  also `renamePlaceProblem`), the name as it would be stored, and the cabinet's read. Also the features renamed so
//  far and who uses the new names. Renaming is the `renameTarget` verb (no action spent).
//

#if GTNW_CORE
import Foundation

enum RenamesQuery: BridgeQuery {
    static let name = "renames"

    struct Args: Decodable { var id: String?; var name: String? }

    struct Target: Encodable {
        var id: String
        /// "nation", "land", "department", "feature", "province".
        var kind: String
        var name: String
        var realName: String
    }

    struct Group: Encodable { var title: String; var targets: [Target] }

    struct Warning: Encodable { var who: String; var text: String; var level: Int }

    struct Check: Encodable {
        var id: String
        var current: String?
        /// The name as it would be stored, or nil when refused.
        var name: String?
        var problem: String?
        var warnings: [Warning]
    }

    struct Renamed: Encodable { var id: String; var name: String; var real: String; var usedBy: [String] }

    struct Result: Encodable {
        var groups: [Group]
        var check: Check?
        var features: [Renamed]
        var maxLength: Int
    }

    static func target(_ t: RenameTarget, _ gs: GameState) -> Target {
        Target(id: t.id, kind: t.kind(in: gs), name: t.currentName(in: gs) ?? t.id, realName: t.realName(in: gs))
    }

    static func run(_ a: Args, engine: GameEngine?) throws -> Result {
        let (e, gs) = try GTNWBridge.game(engine)
        let lands = gs.renamableTargets.map { target($0, gs) }
        let depts = Departments.current(in: gs).map { target(.department($0.id), gs) }
        let features = MapFeatures.all.filter { $0.exists(in: gs.currentYear) }.map { target(.feature($0.id), gs) }
        let provinces = gs.renamableProvinces.map { target(.province($0.id), gs) }
        var groups = [Group(title: "Nation and lands", targets: lands), Group(title: "Government", targets: depts),
                      Group(title: "Map", targets: features)]
        if !provinces.isEmpty { groups.append(Group(title: "States and provinces", targets: provinces)) }

        var check: Check?
        if let id = a.id, !id.isEmpty {
            let t = RenameTarget.from(id: id, in: gs)
            let raw = a.name ?? ""
            let c = e.renameCheck(t, to: raw)
            var problem = raw.isEmpty ? "Type a new name." : c.refusal
            if problem == nil, t.isPlace { problem = e.renamePlaceProblem(id, to: raw) }
            if problem == nil, !t.isPlace, c.name == t.currentName(in: gs) { problem = "It already has that name." }
            let ws = t.isPlace && t.isHeld(in: gs) ? e.renamePlaceWarnings(id).map { Warning(who: $0.who, text: $0.text, level: $0.level) } : []
            check = Check(id: id, current: t.currentName(in: gs), name: problem == nil ? c.name : nil, problem: problem, warnings: ws)
        }
        let pp = gs.shadow.powerPlays
        let renamed = pp.featureNames.sorted { $0.key < $1.key }.map { id, name in
            Renamed(id: id, name: name, real: MapFeatures.feature(id)?.name(in: gs.currentYear) ?? id,
                    usedBy: pp.featureRecognition[id]?.compactMap { gs.getCountry(id: $0)?.name } ?? [])
        }
        return Result(groups: groups, check: check, features: renamed, maxLength: NameScreen.maxLength)
    }
}
#endif
