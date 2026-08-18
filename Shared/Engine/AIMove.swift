//
//  AIMove.swift
//  Global Thermal Nuclear War
//
//  Network-free request/response contract for the "brain per country" system.
//  A brain (human, live Claude session, gateway-Claude, or any local/frontier
//  model) receives a `MoveRequest` describing one country's situation and the
//  legal actions available, and answers with a `MoveResponse`.
//
//  `GameEngine.buildMoveRequest(for:)` and `GameEngine.applyMove(_:for:)` are
//  deliberately PURE (no networking) so they can be unit-tested without a live
//  LLM or bus. All transport lives in AIBrain.swift.
//
//  Created by Jordan Koch on 2026.
//

import Foundation

// MARK: - Move contract

/// A request describing one country's situation for a brain to act on.
struct MoveRequest: Codable, Equatable, Sendable {
    var gameId: String
    var countryId: String
    var turn: Int
    var year: Int
    var defcon: Int
    var worldStateSummary: String
    var legalActions: [String]
}

/// A brain's answer: which action to take, against whom, with what params.
struct MoveResponse: Codable, Equatable, Sendable {
    var action: String
    var target: String?
    /// Numeric parameters, e.g. ["warheads": 5]. Kept as Double for lossless JSON.
    var params: [String: Double]?
    var rationale: String?

    init(action: String, target: String? = nil, params: [String: Double]? = nil, rationale: String? = nil) {
        self.action = action
        self.target = target
        self.params = params
        self.rationale = rationale
    }

    /// Decode a MoveResponse from raw JSON data, tolerating malformed payloads.
    /// Returns nil rather than throwing so callers never crash on bad LLM output.
    static func decode(from data: Data) -> MoveResponse? {
        if let direct = try? JSONDecoder().decode(MoveResponse.self, from: data) {
            return direct
        }
        // Some models wrap the object or emit loose JSON — try to salvage.
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        guard let action = obj["action"] as? String else { return nil }
        var params: [String: Double]? = nil
        if let raw = obj["params"] as? [String: Any] {
            var out: [String: Double] = [:]
            for (k, v) in raw {
                if let d = v as? Double { out[k] = d }
                else if let i = v as? Int { out[k] = Double(i) }
                else if let s = v as? String, let d = Double(s) { out[k] = d }
            }
            params = out.isEmpty ? nil : out
        }
        return MoveResponse(
            action: action,
            target: obj["target"] as? String,
            params: params,
            rationale: obj["rationale"] as? String
        )
    }

    /// Decode a MoveResponse from a raw model text response. LLMs often wrap
    /// JSON in prose or code fences — extract the first `{...}` block.
    static func decode(fromText text: String) -> MoveResponse? {
        guard let start = text.firstIndex(of: "{"),
              let end = text.lastIndex(of: "}"), start < end else { return nil }
        let slice = String(text[start...end])
        return decode(from: Data(slice.utf8))
    }
}

/// Canonical action verbs a brain may choose. String rawValues are what appears
/// in `MoveRequest.legalActions` and what a `MoveResponse.action` is matched against.
enum MoveAction: String, CaseIterable, Sendable {
    case wait             = "WAIT"
    case buildMilitary    = "BUILD_MILITARY"
    case buildNukes       = "BUILD_NUKES"
    case declareWar       = "DECLARE_WAR"
    case launchNuke       = "LAUNCH_NUKE"
    case formAlliance     = "FORM_ALLIANCE"
    case improveRelations = "IMPROVE_RELATIONS"
    case threatenNuke     = "THREATEN_NUKE"
    case sueForPeace      = "SUE_FOR_PEACE"

    var requiresTarget: Bool {
        switch self {
        case .wait, .buildMilitary, .buildNukes: return false
        default: return true
        }
    }
}

/// Result of applying a MoveResponse — lets the turn loop decide whether to
/// fall back to rule-based AI.
enum MoveApplication: Equatable, Sendable {
    case applied(String)     // successfully applied verb (rawValue)
    case noOp                // legal but no state change (e.g. WAIT)
    case rejectedIllegal     // action not legal for this country / bad target
}

// MARK: - Pure engine helpers

extension GameEngine {

    /// The legal actions available to a given country right now. Pure.
    func legalActions(for country: Country) -> [String] {
        guard let gameState = gameState else { return [MoveAction.wait.rawValue] }
        var actions: [MoveAction] = [.wait, .buildMilitary]

        // Nuclear-age build only
        if gameState.currentYear >= 1945 {
            actions.append(.buildNukes)
        }

        // Actions needing at least one other living country
        let hasOthers = gameState.countries.contains {
            $0.id != country.id && !$0.isDestroyed
        }
        if hasOthers {
            actions.append(contentsOf: [.declareWar, .formAlliance, .improveRelations])
        }

        // Nuclear-only verbs
        if country.nuclearWarheads > 0 {
            actions.append(.launchNuke)
            actions.append(.threatenNuke)
        }

        // Peace only when actually at war
        if !country.atWarWith.isEmpty {
            actions.append(.sueForPeace)
        }

        return actions.map { $0.rawValue }
    }

    /// Build a pure, network-free MoveRequest for a country. Returns nil if the
    /// country is unknown. Reads only a snapshot of state.
    func buildMoveRequest(for countryID: String) -> MoveRequest? {
        guard let gameState = gameState,
              let country = gameState.getCountry(id: countryID) else { return nil }

        let wars = Array(country.atWarWith).compactMap { gameState.getCountry(id: $0)?.name }
        let allies = Array(country.alliances).compactMap { gameState.getCountry(id: $0)?.name }
        let neighbors = gameState.countries
            .filter { $0.id != country.id && !$0.isDestroyed }
            .sorted { $0.militaryStrength > $1.militaryStrength }
            .prefix(8)
            .map { "\($0.name) [\($0.id)] mil:\($0.militaryStrength) nukes:\($0.nuclearWarheads)" }

        let summary = """
        You are \(country.name) [\(country.id)] in \(gameState.currentYear).
        Alignment: \(country.alignment.rawValue). Government: \(country.government.rawValue).
        Military: \(country.militaryStrength)/100. Nuclear warheads: \(country.nuclearWarheads). \
        Aggression: \(country.aggressionLevel)/100. Stability: \(country.stability)/100.
        At war with: \(wars.isEmpty ? "none" : wars.joined(separator: ", ")).
        Allies: \(allies.isEmpty ? "none" : allies.joined(separator: ", ")).
        World: DEFCON \(gameState.defconLevel.rawValue), \(gameState.activeWars.count) active wars.
        Nearby powers: \(neighbors.joined(separator: "; ")).
        """

        return MoveRequest(
            gameId: gameState.playerCountryID + "-\(gameState.eraStartYear)",
            countryId: country.id,
            turn: gameState.turn,
            year: gameState.currentYear,
            defcon: gameState.defconLevel.rawValue,
            worldStateSummary: summary,
            legalActions: legalActions(for: country)
        )
    }

    /// Apply a brain's MoveResponse onto the engine's existing verbs. Rejects
    /// illegal actions (not in legalActions, or missing/invalid target).
    @discardableResult
    func applyMove(_ response: MoveResponse, for countryID: String) -> MoveApplication {
        guard let gameState = gameState,
              let country = gameState.getCountry(id: countryID) else { return .rejectedIllegal }

        let legal = Set(legalActions(for: country))
        let verb = response.action.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        guard legal.contains(verb), let action = MoveAction(rawValue: verb) else {
            return .rejectedIllegal
        }

        // Resolve target if required.
        var targetID: String? = nil
        if action.requiresTarget {
            guard let rawTarget = response.target,
                  let resolved = resolveMoveTarget(rawTarget, forCountry: country) else {
                return .rejectedIllegal
            }
            targetID = resolved
        }

        switch action {
        case .wait:
            return .noOp

        case .buildMilitary:
            if let idx = gameState.countries.firstIndex(where: { $0.id == countryID }) {
                gameState.countries[idx].militaryStrength = min(100, gameState.countries[idx].militaryStrength + 3)
                gameState.aiActionSummary.append("\(country.flag) \(country.name) 🪖 strengthened military")
            }
            return .applied(verb)

        case .buildNukes:
            if let idx = gameState.countries.firstIndex(where: { $0.id == countryID }) {
                gameState.countries[idx].nuclearWarheads += 5
                gameState.aiActionSummary.append("\(country.flag) \(country.name) ☢️ built 5 warheads")
                raiseDEFCON()
            }
            return .applied(verb)

        case .declareWar:
            declareWar(aggressor: countryID, defender: targetID!)
            if let t = getCountry(targetID!) {
                gameState.aiActionSummary.append("\(country.flag) \(country.name) ⚔️ declared war on \(t.flag) \(t.name)")
            }
            return .applied(verb)

        case .launchNuke:
            let requested = response.params?["warheads"].map { Int($0) } ?? min(3, country.nuclearWarheads)
            let warheads = max(1, min(requested, country.nuclearWarheads))
            launchNuclearStrike(from: countryID, to: targetID!, warheads: warheads)
            return .applied(verb)

        case .formAlliance:
            formAlliance(country1: countryID, country2: targetID!)
            return .applied(verb)

        case .improveRelations:
            modifyDiplomaticRelation(from: countryID, to: targetID!, by: 10)
            if let t = getCountry(targetID!) {
                gameState.aiActionSummary.append("\(country.flag) \(country.name) 🤝 improved relations with \(t.flag) \(t.name)")
            }
            return .applied(verb)

        case .threatenNuke:
            modifyDiplomaticRelation(from: countryID, to: targetID!, by: -20)
            raiseDEFCON()
            if let t = getCountry(targetID!) {
                addLog("\(country.flag) \(country.name) threatens \(t.flag) \(t.name) with nuclear strike!", type: .warning)
                gameState.aiActionSummary.append("\(country.flag) \(country.name) ☢️ threatened \(t.flag) \(t.name)")
            }
            return .applied(verb)

        case .sueForPeace:
            let ok = sueForPeace(from: countryID, to: targetID!)
            return ok ? .applied(verb) : .rejectedIllegal
        }
    }

    /// Resolve a target token (ID or name, case-insensitive) to a living country ID.
    private func resolveMoveTarget(_ token: String, forCountry country: Country) -> String? {
        guard let gameState = gameState else { return nil }
        let needle = token.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return nil }
        let match = gameState.countries.first {
            $0.id != country.id && !$0.isDestroyed &&
            ($0.id.lowercased() == needle ||
             $0.code.lowercased() == needle ||
             $0.name.lowercased() == needle ||
             $0.name.lowercased().contains(needle))
        }
        return match?.id
    }
}
