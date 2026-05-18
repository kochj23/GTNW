//
//  MilitaryAllianceSystem.swift
//  GTNW
//
//  NATO Article 5, Warsaw Pact collective defense, and nuclear arms race dynamics
//  Created by Jordan Koch on 2026-03-05
//

import Foundation

// MARK: - Military Alliance Registry

/// Defines formal military alliances and their membership by era.
struct MilitaryAllianceSystem {

    // MARK: - NATO Membership by Year

    /// Returns the set of NATO member country IDs for a given year.
    static func natoMembers(year: Int) -> Set<String> {
        guard year >= 1949 else { return [] }

        var members: Set<String> = [
            // Founding members (1949)
            "USA", "GBR", "FRA", "BEL", "NLD", "LUX",
            "NOR", "DNK", "ISL", "CAN", "ITA", "PRT"
        ]

        if year >= 1952 { members.formUnion(["GRC", "TUR"]) }
        if year >= 1955 { members.formUnion(["DEU", "DDR".isEmpty ? "" : "DEU"]) }   // West Germany joins
        if year >= 1982 { members.insert("ESP") }
        if year >= 1999 { members.formUnion(["CZE", "HUN", "POL"]) }
        if year >= 2004 { members.formUnion(["BGR", "EST", "LVA", "LTU", "ROU", "SVK", "SVN"]) }
        if year >= 2009 { members.formUnion(["ALB", "HRV"]) }
        if year >= 2017 { members.insert("MNE") }
        if year >= 2020 { members.insert("MKD") }
        if year >= 2023 { members.insert("FIN") }
        if year >= 2024 { members.insert("SWE") }

        // France withdrew from NATO military command 1966–2009
        // (still a member but not integrated command — simplify: keep as member)

        return members
    }

    // MARK: - Warsaw Pact Membership by Year

    /// Returns the set of Warsaw Pact member country IDs for a given year.
    static func warsawPactMembers(year: Int) -> Set<String> {
        guard year >= 1955, year < 1991 else { return [] }

        var members: Set<String> = [
            "RUS",  // Soviet Union (shown as RUS in game but represents USSR)
            "BGR",  // Bulgaria
            "HUN",  // Hungary
            "POL",  // Poland
            "ROU",  // Romania
            "CSK",  // Czechoslovakia (historical ID)
            "DDR",  // East Germany (historical ID)
        ]

        // Yugoslavia was never in the Warsaw Pact (Tito split with Stalin 1948)
        // Albania was expelled from Warsaw Pact in 1968
        if year < 1968 {
            members.insert("ALB")
        }

        return members
    }

    // MARK: - Non-NATO/Warsaw Regional Alliances

    static func cstoMembers(year: Int) -> Set<String> {
        guard year >= 2002 else { return [] }
        return ["RUS","BLR","ARM","KAZ","KGZ","TJK"]
    }

    static func scoMembers(year: Int) -> Set<String> {
        guard year >= 2001 else { return [] }
        var m: Set<String> = ["CHN","RUS","KAZ","KGZ","TJK","UZB"]
        if year >= 2017 { m.formUnion(["IND","PAK"]) }
        if year >= 2023 { m.insert("IRN") }
        return m
    }

    static func arabLeagueMembers(year: Int) -> Set<String> {
        guard year >= 1945 else { return [] }
        return ["EGY","SYR","JOR","IRQ","SAU","LBN","YEM","LBY","SDN","MAR",
                "TUN","KWT","DZA","ARE","QAT","BHR","OMN","PSE","SOM","DJI","COM","MRT"]
    }

    static func aseanMembers(year: Int) -> Set<String> {
        guard year >= 1967 else { return [] }
        var m: Set<String> = ["IDN","MYS","PHL","SGP","THA"]
        if year >= 1984 { m.insert("BRN") }
        if year >= 1995 { m.insert("VNM") }
        if year >= 1997 { m.formUnion(["MMR","LAO"]) }
        if year >= 1999 { m.insert("KHM") }
        return m
    }

    static func africanUnionMembers(year: Int) -> Set<String> {
        guard year >= 2002 else { return [] }
        return ["DZA","AGO","BEN","BWA","BFA","BDI","CPV","CMR","CAF","TCD","COM",
                "COD","DJI","EGY","GNQ","ERI","SWZ","ETH","GAB","GMB","GHA","GIN",
                "GNB","KEN","LSO","LBR","LBY","MDG","MWI","MLI","MRT","MUS","MAR",
                "MOZ","NAM","NER","NGA","RWA","STP","SEN","SYC","SLE","SOM","ZAF",
                "SSD","SDN","TZA","TGO","TUN","UGA","ZMB","ZWE","COG","CIV"]
    }

    static func aukusMembers(year: Int) -> Set<String> {
        guard year >= 2021 else { return [] }
        return ["AUS","GBR","USA"]
    }

    /// Returns regional alliance info for a country: (name, members, responseStrength 0-1).
    /// Strength: AUKUS 0.7, CSTO 0.6, SCO 0.3, Arab League 0.25, ASEAN 0.2, AU 0.15
    static func regionalAlliance(for id: String, year: Int) -> (name: String, members: Set<String>, strength: Double)? {
        if cstoMembers(year: year).contains(id)        { return ("CSTO", cstoMembers(year: year), 0.6) }
        if aukusMembers(year: year).contains(id)       { return ("AUKUS", aukusMembers(year: year), 0.7) }
        if scoMembers(year: year).contains(id)         { return ("SCO", scoMembers(year: year), 0.3) }
        if arabLeagueMembers(year: year).contains(id)  { return ("Arab League", arabLeagueMembers(year: year), 0.25) }
        if aseanMembers(year: year).contains(id)       { return ("ASEAN", aseanMembers(year: year), 0.2) }
        if africanUnionMembers(year: year).contains(id){ return ("African Union", africanUnionMembers(year: year), 0.15) }
        return nil
    }

    // MARK: - Alliance Name

    static func allianceName(year: Int, forCountryID countryID: String) -> String? {
        if natoMembers(year: year).contains(countryID)      { return "NATO" }
        if warsawPactMembers(year: year).contains(countryID){ return "Warsaw Pact" }
        if let r = regionalAlliance(for: countryID, year: year) { return r.name }
        return nil
    }

    // MARK: - Article 5 / Collective Defense Check

    /// Checks if attacking `targetID` triggers collective defense.
    /// NATO/Warsaw: full Article 5. Regional alliances: partial solidarity.
    static func collectiveDefenseResponse(
        aggressor: String,
        target: String,
        year: Int,
        allCountries: [Country]
    ) -> CollectiveDefenseResult {

        let natoSet    = natoMembers(year: year)
        let warsawSet  = warsawPactMembers(year: year)
        let existingIDs = Set(allCountries.map { $0.id })

        let targetInNATO   = natoSet.contains(target)
        let targetInWarsaw = warsawSet.contains(target)

        // ── Regional (non-NATO/Warsaw) solidarity ───────────────────────────
        if !targetInNATO && !targetInWarsaw {
            if let regional = regionalAlliance(for: target, year: year),
               !regional.members.contains(aggressor) {
                let maxResponders = max(1, Int(Double(regional.members.count) * regional.strength))
                let responders = regional.members
                    .filter { $0 != target && $0 != aggressor && existingIDs.contains($0) }
                    .sorted()
                    .prefix(maxResponders)
                    .map { $0 }
                if !responders.isEmpty {
                    return CollectiveDefenseResult(
                        triggered: true,
                        allianceName: "\(regional.name) Solidarity",
                        responders: responders
                    )
                }
            }
            return CollectiveDefenseResult(triggered: false, allianceName: nil, responders: [])
        }

        // ── NATO / Warsaw Pact full collective defense ───────────────────────
        guard targetInNATO || targetInWarsaw else {
            return CollectiveDefenseResult(triggered: false, allianceName: nil, responders: [])
        }

        if targetInNATO   && natoSet.contains(aggressor)   { return CollectiveDefenseResult(triggered: false, allianceName: nil, responders: []) }
        if targetInWarsaw && warsawSet.contains(aggressor)  { return CollectiveDefenseResult(triggered: false, allianceName: nil, responders: []) }

        let allianceName    = targetInNATO ? "NATO Article 5" : "Warsaw Pact Treaty"
        let allianceMembers = targetInNATO ? natoSet : warsawSet

        // All alliance members except the target itself and any already at war with each other
        let existingCountryIDs = Set(allCountries.map { $0.id })
        let responders = allianceMembers
            .filter { $0 != target && $0 != aggressor }
            .filter { existingCountryIDs.contains($0) }
            .sorted()

        return CollectiveDefenseResult(
            triggered: true,
            allianceName: allianceName,
            responders: responders
        )
    }

    // MARK: - Shared Interest Check

    /// Returns true if two countries are in the same alliance.
    static func areAllied(country1: String, country2: String, year: Int) -> Bool {
        let nato = natoMembers(year: year)
        let warsaw = warsawPactMembers(year: year)
        return (nato.contains(country1) && nato.contains(country2)) ||
               (warsaw.contains(country1) && warsaw.contains(country2))
    }
}

// MARK: - Collective Defense Result

struct CollectiveDefenseResult {
    let triggered: Bool
    let allianceName: String?
    let responders: [String]   // Country IDs that join the war
}

// MARK: - Arms Race Engine

/// Simulates the nuclear arms race between major powers.
/// Each turn: if one side has a significant arsenal advantage, the lagging side builds up.
struct ArmsRaceEngine {

    // MARK: - Major Nuclear Powers

    static let majorPowers = ["USA", "RUS", "CHN", "GBR", "FRA"]

    // MARK: - Process Arms Race Turn

    /// Adjusts nuclear arsenals based on the arms race dynamic for the given year.
    /// Returns log messages describing what happened.
    static func processTurn(gameState: GameState) -> [String] {
        var logs: [String] = []
        let year = gameState.currentYear

        // Arms race only meaningful when nukes exist (post-1945)
        guard year >= 1945 else { return [] }

        // Get current nuclear powers among major nations
        let nuclearMajors = gameState.countries.filter {
            majorPowers.contains($0.id) && $0.nuclearWarheads > 0 && !$0.isDestroyed
        }

        guard nuclearMajors.count >= 2 else { return [] }

        // Find the leader (most warheads)
        guard let leader = nuclearMajors.max(by: { $0.nuclearWarheads < $1.nuclearWarheads }) else { return [] }

        for i in gameState.countries.indices {
            let country = gameState.countries[i]
            guard majorPowers.contains(country.id),
                  country.id != leader.id,
                  !country.isDestroyed else { continue }

            let ratio = Double(leader.nuclearWarheads) / max(1.0, Double(country.nuclearWarheads))

            // If leader has 40%+ advantage, lagging power responds
            guard ratio >= 1.4 else { continue }

            let buildRate = armsRaceBuildRate(year: year, country: country, ratio: ratio)
            guard buildRate > 0 else { continue }

            gameState.countries[i].nuclearWarheads += buildRate
            gameState.countries[i].icbmCount += max(0, buildRate / 10)

            let flag = country.flag
            let name = country.name
            logs.append("ARMS RACE: \(flag) \(name) accelerates nuclear buildup (+\(buildRate) warheads)")
        }

        // Conversely: if major powers have SALT-era treaties, reduce slightly
        if year >= 1972 {
            logs += processSALTReductions(gameState: gameState, year: year)
        }

        return logs
    }

    // MARK: - Build Rate by Era

    /// Returns the number of warheads a country builds this turn given the era and gap.
    private static func armsRaceBuildRate(year: Int, country: Country, ratio: Double) -> Int {
        let gapMultiplier = min(ratio - 1.0, 2.0)   // cap at 2x advantage effect

        switch year {
        case ..<1950:
            // Early nuclear age: very slow build (USA had monopoly 1945-1949)
            return 0
        case 1950..<1960:
            // 1950s: Bomber-missile race ramps up fast
            return Int(Double.random(in: 20...80) * gapMultiplier)
        case 1960..<1970:
            // 1960s: ICBM race, both sides sprint
            return Int(Double.random(in: 100...300) * gapMultiplier)
        case 1970..<1980:
            // 1970s: MIRV technology, arsenals explode
            return Int(Double.random(in: 200...600) * gapMultiplier)
        case 1980..<1989:
            // Reagan era: USA builds up, USSR responds
            return Int(Double.random(in: 150...400) * gapMultiplier)
        case 1989..<1993:
            // Cold War ending: buildups slow
            return Int(Double.random(in: 50...150) * gapMultiplier)
        case 1993..<2010:
            // Post-Cold War: significant reductions, race slows
            return country.id == "CHN" ? Int(Double.random(in: 5...20) * gapMultiplier) : 0
        default:
            // Modern: China builds up; US/Russia hold static
            return country.id == "CHN" ? Int(Double.random(in: 10...30) * gapMultiplier) : 0
        }
    }

    // MARK: - SALT / START Reductions

    private static func processSALTReductions(gameState: GameState, year: Int) -> [String] {
        var logs: [String] = []
        guard year >= 1972 else { return [] }

        // Only applies if no active nuclear wars
        guard gameState.nuclearStrikes.isEmpty else { return [] }

        // SALT I (1972): caps at ~2000 for each
        // START I (1991): reduces to 6000
        // START II (1993): reduces to 3500
        // New START (2010): reduces to 1550

        let cap: Int
        let label: String
        switch year {
        case 1972..<1991: cap = 2500; label = "SALT I"
        case 1991..<2010: cap = 6000; label = "START I"
        case 2010...:     cap = 1550; label = "New START"
        default: return []
        }

        let mainPowers = ["USA", "RUS"]
        for i in gameState.countries.indices {
            let country = gameState.countries[i]
            guard mainPowers.contains(country.id),
                  !country.isDestroyed,
                  country.nuclearWarheads > cap else { continue }

            // Small natural reduction each turn toward the cap
            let reduction = min(50, (country.nuclearWarheads - cap) / 10)
            if reduction > 0 {
                gameState.countries[i].nuclearWarheads -= reduction
                logs.append("ARMS CONTROL: \(country.flag) \(country.name) reduces arsenal under \(label) (-\(reduction))")
            }
        }

        return logs
    }
}

// MARK: - GameEngine Extension: Collective Defense

extension GameEngine {

    /// Call this after any war declaration to check if collective defense is triggered.
    /// Automatically joins alliance members on the defender's side.
    func checkAndInvokeCollectiveDefense(aggressor aggressorID: String, target targetID: String) {
        guard let gameState = gameState else { return }
        let year = gameState.currentYear

        let result = MilitaryAllianceSystem.collectiveDefenseResponse(
            aggressor: aggressorID,
            target: targetID,
            year: year,
            allCountries: gameState.countries
        )

        guard result.triggered, let allianceName = result.allianceName else { return }

        let aggressorName = getCountry(aggressorID)?.name ?? aggressorID
        let targetName = getCountry(targetID)?.name ?? targetID

        addLog("", type: .system)
        addLog("!! \(allianceName) INVOKED !!", type: .critical)
        addLog("Attack on \(targetName) triggers collective defense.", type: .critical)
        addLog("Aggressor: \(aggressorName)", type: .warning)

        var membersJoined: [String] = []

        for memberID in result.responders {
            guard let memberCountry = getCountry(memberID) else { continue }

            // Skip members that are already at war with the target (internal)
            // Skip members that have very poor relations with the target
            let relationToTarget = memberCountry.diplomaticRelations[targetID] ?? 0
            guard relationToTarget > -50 else { continue }

            // Join the war on the defender's side
            if let memberIndex = gameState.countries.firstIndex(where: { $0.id == memberID }),
               let aggressorIndex = gameState.countries.firstIndex(where: { $0.id == aggressorID }) {
                gameState.countries[memberIndex].atWarWith.insert(aggressorID)
                gameState.countries[aggressorIndex].atWarWith.insert(memberID)

                let war = War(aggressor: aggressorID, defender: memberID, startTurn: gameState.turn)
                gameState.activeWars.append(war)

                membersJoined.append("\(memberCountry.flag) \(memberCountry.name)")
            }
        }

        if !membersJoined.isEmpty {
            addLog("Entering war: \(membersJoined.joined(separator: ", "))", type: .warning)
            gameState.warsStarted += membersJoined.count

            // Raise DEFCON — a major alliance war is extremely dangerous
            if gameState.defconLevel.rawValue > 2 {
                let newLevel = DefconLevel(rawValue: gameState.defconLevel.rawValue - 1) ?? .defcon1
                gameState.defconLevel = newLevel
                addLog("DEFCON raised to \(newLevel.description) — \(allianceName) mobilizing", type: .critical)
            }
        } else {
            addLog("Alliance members chose non-intervention.", type: .info)
        }

        self.gameState = gameState
    }

    /// Process the arms race at the start of each turn.
    func processArmsRace() {
        guard let gameState = gameState else { return }
        let logs = ArmsRaceEngine.processTurn(gameState: gameState)
        for log in logs {
            addLog(log, type: .info)
        }
        self.gameState = gameState
    }
}
