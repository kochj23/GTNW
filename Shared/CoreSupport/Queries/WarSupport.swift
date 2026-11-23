//
//  WarSupport.swift
//  GTNWCore
//
//  Small helpers the war, diplomacy and budget queries and verbs share (names for ids, ids from strings, the
//  cabinet's three-line warnings). Read-only.
//

#if GTNW_CORE
import Foundation

enum WarSupport {
    /// A nation's (or a template land's) name for an id, else the id.
    static func name(_ id: String, _ gs: GameState) -> String {
        gs.getCountry(id: id)?.name ?? WorldCountriesDatabase.template(id: id)?.name ?? id
    }

    static func flag(_ id: String, _ gs: GameState) -> String { gs.getCountry(id: id)?.flag ?? "" }

    static func uuid(_ s: String) throws -> UUID {
        guard let u = UUID(uuidString: s) else { throw QueryError("bad id \(s)") }
        return u
    }

    /// CabinetWarningsView's lines (hidden when the app setting is off; the web always shows them).
    struct Warning: Encodable { var who: String; var text: String; var level: Int }

    static func warnings(_ list: [AdvisorWarning]) -> [Warning] { list.map { Warning(who: $0.who, text: $0.text, level: $0.level) } }

    /// CabinetWarningsView.proceedTitle: "Overrule & proceed" when a danger line is showing.
    static func proceedTitle(_ list: [AdvisorWarning], default title: String) -> String {
        list.contains { $0.level == 2 } ? "Overrule & proceed" : title
    }

    static func preset(_ raw: String?) -> AttackPreset { raw.flatMap(AttackPreset.init(rawValue:)) ?? .standard }
}
#endif
