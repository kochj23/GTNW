//
//  main.swift
//  gtnw-golden
//
//  Plays the golden games with GTNWCore and prints them as one JSON object, for the parity check (Wasm/parity.sh):
//    {"rngVectors": {...}, "games": [<game in the fixture format>, ...]}
//
//  Usage: gtnw-golden <repo root> [year:seedhex:turns ...]   (default: the fixtures' 1789, 1962 and 2025 games)
//         gtnw-golden <repo root> --bench [year] [turns]      times each endTurn (full rules), one line per turn
//  The data files come from the repo (Shared/Resources, Documentation/wars), as the app bundles them.
//

import Foundation
import GTNWCore

let args = CommandLine.arguments.dropFirst()
guard let root = args.first else {
    FileHandle.standardError.write(Data("usage: gtnw-golden <repo root> [year:seedhex:turns ...]\n".utf8))
    exit(2)
}
let rootURL = URL(fileURLWithPath: root, isDirectory: true)
for (name, dir) in [("nation_cabinets", "Shared/Resources"), ("nation_characters", "Shared/Resources"),
                    ("world_countries", "Shared/Resources"), ("base_rates", "Documentation/wars"), ("open_wars", "Documentation/wars")] {
    guard let data = try? Data(contentsOf: rootURL.appendingPathComponent(dir).appendingPathComponent(name + ".json")) else {
        FileHandle.standardError.write(Data("missing \(dir)/\(name).json under \(root)\n".utf8))
        exit(1)
    }
    GTNWBridge.setResource(name, data)
}

if args.dropFirst().first == "--bench" {
    let rest = Array(args.dropFirst(2))
    let year = rest.first.flatMap { Int($0) } ?? 1962, turns = rest.dropFirst().first.flatMap { Int($0) } ?? 12
    _ = GTNWBridge.newGame(#"{"year":\#(year),"seed":"7aa","rules":"full"}"#)
    var times: [Double] = []
    for _ in 0..<turns {
        let t0 = Date()
        _ = GTNWBridge.endTurn()
        times.append(Date().timeIntervalSince(t0) * 1000)
    }
    print("native end turn (\(year), full rules): " + times.map { String(format: "%.1f", $0) }.joined(separator: ", ") + " ms")
    exit(0)
}

var games: [(Int, UInt64, Int)] = [(1789, 1789, 12), (1962, 1962, 12), (2025, 2025, 12)]
if args.count > 1 {
    games = args.dropFirst().compactMap { spec in
        let p = spec.split(separator: ":")
        guard p.count == 3, let y = Int(p[0]), let s = UInt64(p[1], radix: 16), let t = Int(p[2]) else { return nil }
        return (y, s, t)
    }
}
var out = #"{"rngVectors":"# + GTNWBridge.goldenVectors() + #","games":["#
for (i, g) in games.enumerated() {
    let start = Date()
    out += (i > 0 ? "," : "") + GTNWBridge.golden(year: g.0, seed: g.1, turns: g.2)
    FileHandle.standardError.write(Data(String(format: "game %d: %.0f ms\n", g.0, Date().timeIntervalSince(start) * 1000).utf8))
}
out += "]}\n"
FileHandle.standardOutput.write(Data(out.utf8))
