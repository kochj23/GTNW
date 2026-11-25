//
//  ProvincesQuery.swift
//  GTNWCore
//
//  `{"q":"provinces","nation":"USA"?}` (3.37): states and provinces (Subdivisions.swift) and the last presidential
//  election state by state (StateElection.swift), as the app's map hover, dossier and end-screen election map show
//  them: each subdivision that exists this year with its name (the President's, and the real one), kind, share of
//  the people, holder, occupier, unrest, electors and last result. The map geometry ships with the app only; the web
//  draws these as a list. `nations` lists the nations that have subdivisions this year. Default: the player's nation.
//

#if GTNW_CORE
import Foundation

enum ProvincesQuery: BridgeQuery {
    static let name = "provinces"

    struct Args: Decodable { var nation: String? }

    struct Row: Encodable {
        var id: String
        var name: String
        /// The name history gives it on the game's date (differs from `name` once the President renamed it).
        var realName: String
        var kind: String
        /// Share of the nation's people, percent.
        var share: Double
        var holder: String?
        var holderName: String?
        var occupier: String?
        var occupierName: String?
        var unrest: Int
        /// Electoral votes it casts now (U.S. player only).
        var electors: Int?
        /// The President's ticket's share of the two-party vote there at the last election, and who carried it.
        var lastShare: Double?
        var carried: String?
        /// The President holds it, so it can be renamed (`renamePlace`).
        var renamable: Bool
        var seceded: String?
    }

    struct Election: Encodable {
        var year: Int
        var carried: Int
        var lost: Int
        var third: Int
        var electorsFor: Int
        var electorsAgainst: Int
        var electorsThird: Int
    }

    struct NationEntry: Encodable { var id: String; var name: String; var count: Int }

    struct Result: Encodable {
        var nation: String
        var nationName: String
        /// Why the nation is shown undivided (before its modern subdivisions), or nil.
        var undivided: String?
        var rows: [Row]
        var election: Election?
        var electors: Int?
        var nations: [NationEntry]
    }

    static func run(_ a: Args, engine: GameEngine?) throws -> Result {
        let (_, gs) = try GTNWBridge.game(engine)
        let nation = a.nation ?? gs.playerCountryID
        let holders = gs.provinceHolders()
        let subs = gs.subdivisions(of: nation)
        let shares = gs.provinceShares(of: nation)
        let electorate = nation == "USA" ? gs.electorate(on: gs.currentDate) : nil
        let ledger = gs.shadow.provinces
        func name(_ id: String?) -> String? { id.map { gs.getCountry(id: $0)?.name ?? $0 } }
        let rows = subs.map { s -> Row in
            let h = Subdivisions.historical(s, on: gs.currentDate)
            let share = ledger.lastElection[s.id]
            var carried: String?
            if let v = share { carried = ledger.thirdCarried.contains(s.id) ? "third" : (v > 50 ? "you" : "opponent") }
            let holder = holders.owner[s.id]
            return Row(id: s.id, name: gs.provinceName(s.id), realName: h.name, kind: h.kind, share: QueryText.round2((shares[s.id] ?? 0) * 100),
                       holder: holder, holderName: name(holder), occupier: ledger.occupied[s.id], occupierName: name(ledger.occupied[s.id]),
                       unrest: Int((ledger.unrest[s.id] ?? 0).rounded()), electors: electorate?[s.id], lastShare: share, carried: carried,
                       renamable: holder == gs.playerCountryID, seceded: ledger.seceded[s.id].map(GameCalendar.format))
        }
        var election: Election?
        if nation == "USA", let year = ledger.lastElectionYear, !ledger.lastElection.isEmpty {
            let r = ledger.lastElection
            let ev = gs.electorate(on: gs.currentDate) ?? [:]
            let third = ledger.thirdCarried
            let won = r.filter { !third.contains($0.key) && $0.value > 50 }.map(\.key)
            let lost = r.filter { !third.contains($0.key) && $0.value <= 50 }.map(\.key)
            func sum(_ ids: [String]) -> Int { ids.reduce(0) { $0 + (ev[$1] ?? 0) } }
            election = Election(year: year, carried: won.count, lost: lost.count, third: third.count,
                                electorsFor: sum(won), electorsAgainst: sum(lost), electorsThird: sum(Array(third)))
        }
        var undivided: String?
        if subs.isEmpty {
            if Subdivisions.byNation[nation] == nil {
                undivided = "\(name(nation) ?? nation) has no states or provinces in the game."
            } else {
                undivided = "\(name(nation) ?? nation) is shown undivided in \(gs.currentYear)\(Subdivisions.since[nation].map { "; its modern provinces from about \($0)" } ?? "")."
            }
        }
        let present = Set(gs.countries.filter { !$0.isDestroyed }.map(\.id))
        let nations = Subdivisions.byNation.keys.sorted().compactMap { id -> NationEntry? in
            guard present.contains(id) else { return nil }
            let n = gs.subdivisions(of: id).count
            return n > 0 ? NationEntry(id: id, name: name(id) ?? id, count: n) : nil
        }
        return Result(nation: nation, nationName: name(nation) ?? nation, undivided: undivided, rows: rows, election: election,
                      electors: electorate.map { $0.values.reduce(0, +) }, nations: nations)
    }
}
#endif
