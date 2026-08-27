//
//  NovaAPIServer.swift
//  GTNW
//
//  Nova/Claude API — port 37431
//
//  Single-player game endpoints:
//    GET  /api/status
//    GET  /api/ping
//    GET  /api/administrations         — list all 47 playable presidents
//    POST /api/game/new                — start a new game session
//    GET  /api/game/sessions           — list active sessions
//    GET  /api/game/:id/state          — full game state
//    GET  /api/game/:id/crisis         — active crisis (if any)
//    POST /api/game/:id/crisis/resolve — resolve crisis with chosen option
//    POST /api/game/:id/turn           — end turn and advance game
//    POST /api/game/:id/action         — take a game action
//    DELETE /api/game/:id              — end/delete session
//
//  Multiplayer endpoints (for nova_gtnw_host.py / Herd email games):
//    GET  /api/status                  — includes multiplayerSessionCount
//    GET  /api/game-state              — full state of current active multiplayer session
//    POST /api/start-session           — {"president":"Nixon","year":1972,"scenario":"..."}
//    GET  /api/crises                  — active crises requiring player decisions
//    POST /api/decision                — {"crisis_id":"...","choice":0,"player":"Sam"}
//    GET  /api/history                 — recent turn events/outcomes
//    POST /api/assign-countries        — assign countries to herd players
//
//  Created by Jordan Koch on 2026.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation
import Network
import Security

@MainActor
class NovaAPIServer {
    static let shared = NovaAPIServer()
    let port: UInt16 = 37431
    private var listener: NWListener?
    private let startTime = Date()

    // Active game sessions keyed by UUID string
    private var sessions: [String: GameEngine] = [:]

    // MARK: - Multiplayer state

    /// A single multiplayer session managed by nova_gtnw_host.py
    struct MultiplayerSession: Codable {
        var sessionId: String
        var president: String
        var year: Int
        var scenario: String
        var createdAt: Date
        var turn: Int
        /// countryID → playerName (e.g. "USA" → "Sam")
        var countryAssignments: [String: String]
        /// Pending decisions: crisis id → player who needs to decide
        var pendingDecisions: [String: String]
        /// Resolved decisions log
        var decisionLog: [DecisionRecord]
        /// Recent event strings (last 50)
        var history: [String]
        var gameOver: Bool
        var gameOverReason: String

        init(president: String, year: Int, scenario: String) {
            self.sessionId       = UUID().uuidString
            self.president       = president
            self.year            = year
            self.scenario        = scenario
            self.createdAt       = Date()
            self.turn            = 0
            self.countryAssignments  = [:]
            self.pendingDecisions    = [:]
            self.decisionLog         = []
            self.history             = []
            self.gameOver            = false
            self.gameOverReason      = ""
        }
    }

    struct DecisionRecord: Codable {
        let crisisId: String
        let crisisTitle: String
        let player: String
        let choiceIndex: Int
        let choiceTitle: String
        let turn: Int
        let timestamp: Date
    }

    /// The active multiplayer session (one at a time for the herd game)
    private var multiplayerSession: MultiplayerSession? = nil

    /// The GameEngine backing the current multiplayer session
    private var multiplayerEngine: GameEngine? = nil

    private init() {}

    func start() {
        do {
            let params = NWParameters.tcp
            params.requiredLocalEndpoint = NWEndpoint.hostPort(host: "127.0.0.1", port: NWEndpoint.Port(rawValue: port)!)
            listener = try NWListener(using: params)
            listener?.newConnectionHandler = { [weak self] conn in Task { @MainActor in self?.handle(conn) } }
            listener?.stateUpdateHandler = { if case .ready = $0 { print("NovaAPI [GTNW]: port \(self.port)") } }
            listener?.start(queue: .main)
        } catch { print("NovaAPI [GTNW]: failed — \(error)") }
    }

    func stop() { listener?.cancel(); listener = nil }

    private func handle(_ c: NWConnection) { c.start(queue: .main); receive(c, Data()) }

    private func receive(_ c: NWConnection, _ buf: Data) {
        c.receive(minimumIncompleteLength: 1, maximumLength: 131072) { [weak self] data, _, done, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                var b = buf; if let d = data { b.append(d) }
                if let req = NovaRequest(b) {
                    let resp = await self.route(req)
                    c.send(content: resp.data(using: .utf8), completion: .contentProcessed { _ in c.cancel() })
                } else if !done { self.receive(c, b) } else { c.cancel() }
            }
        }
    }

    // MARK: - Router

    private func route(_ req: NovaRequest) async -> String {
        // Mutating routes (POST/DELETE/etc.) require the per-install bearer token so a website the
        // user happens to visit can't drive game sessions or burn paid cloud-AI quota via this
        // loopback server. GET reads stay open (loopback-only, native clients ignore CORS).
        if req.method != "GET" {
            guard req.isAuthorized(token: Self.apiToken) else {
                return json(401, ["error": "Unauthorized: missing or invalid bearer token"] as [String: Any])
            }
        }

        // Parse /:id/ pattern from path
        let parts = req.path.split(separator: "/").map(String.init)

        switch (req.method, req.path) {

        // ── Meta ──────────────────────────────────────────────────────────
        case ("GET", "/api/status"):
            return json(200, [
                "status": "running", "app": "GTNW", "version": "1.8",
                "port": "\(port)", "uptimeSeconds": Int(Date().timeIntervalSince(startTime)),
                "activeSessions": sessions.count,
                "multiplayerSessionActive": multiplayerSession != nil,
                "multiplayerPresident": multiplayerSession?.president as Any,
                "multiplayerYear": multiplayerSession?.year as Any,
                "multiplayerTurn": multiplayerSession?.turn as Any
            ] as [String: Any])

        case ("GET", "/api/ping"):
            return json(200, ["pong": "true"] as [String: Any])

        // ── Administrations ────────────────────────────────────────────────
        case ("GET", "/api/administrations"):
            let admins = Advisor.allAdministrations()
            let result: [[String: Any]] = admins.map { a in
                ["id": a.id, "president": a.president, "years": a.years,
                 "party": a.party, "startYear": a.startYear, "endYear": a.endYear]
            }
            return jsonArray(200, result)

        // ── Session list ───────────────────────────────────────────────────
        case ("GET", "/api/game/sessions"):
            let list: [[String: Any]] = sessions.map { id, engine in
                let gs = engine.gameState
                return [
                    "sessionId": id,
                    "playerCountry": gs?.playerCountryID ?? "unknown",
                    "turn": gs?.turn ?? 0,
                    "year": gs?.currentYear ?? 0,
                    "defcon": gs?.defconLevel.rawValue ?? 5,
                    "gameOver": gs?.gameOver ?? false
                ]
            }
            return jsonArray(200, list)

        // ── New game ───────────────────────────────────────────────────────
        case ("POST", "/api/game/new"):
            guard let body = req.bodyJSON() else {
                return json(400, ["error": "JSON body required"] as [String: Any])
            }
            let countryID   = body["playerCountry"] as? String ?? "USA"
            let diffStr     = body["difficulty"] as? String ?? "normal"
            let adminID     = body["administration"] as? String

            let difficulty: DifficultyLevel = {
                switch diffStr.lowercased() {
                case "easy":      return .easy
                case "hard":      return .hard
                case "nightmare": return .nightmare
                default:          return .normal
                }
            }()

            var administration: Administration? = nil
            if let adminID = adminID {
                administration = Advisor.allAdministrations().first { $0.id == adminID }
            }

            let engine = GameEngine()
            engine.startNewGame(playerCountryID: countryID, difficulty: difficulty, administration: administration)

            let sessionID = UUID().uuidString
            sessions[sessionID] = engine

            return json(201, [
                "sessionId": sessionID,
                "playerCountry": countryID,
                "difficulty": diffStr,
                "president": administration?.president ?? "Donald Trump",
                "year": engine.gameState?.currentYear ?? 2025,
                "state": gameStateSummary(engine.gameState)
            ] as [String: Any])

        // ── Multiplayer routes ─────────────────────────────────────────────
        //   Used by nova_gtnw_host.py for email-based herd games.

        // GET /api/game-state — full state of active multiplayer session
        case ("GET", "/api/game-state"):
            guard let mp = multiplayerSession, let eng = multiplayerEngine else {
                return json(404, ["error": "No active multiplayer session. Call POST /api/start-session first."] as [String: Any])
            }
            var d = fullGameState(eng)
            d["multiplayerSessionId"] = mp.sessionId
            d["president"] = mp.president
            d["scenario"] = mp.scenario
            d["countryAssignments"] = mp.countryAssignments
            d["pendingDecisions"] = mp.pendingDecisions
            d["multiplayerTurn"] = mp.turn
            return json(200, d)

        // POST /api/start-session — {"president":"Nixon","year":1972,"scenario":"Cuban Missile Crisis"}
        case ("POST", "/api/start-session"):
            guard let body = req.bodyJSON() else {
                return json(400, ["error": "JSON body required: {president, year, scenario}"] as [String: Any])
            }
            let president = body["president"] as? String ?? "Donald Trump"
            let year      = body["year"] as? Int ?? 2025
            let scenario  = body["scenario"] as? String ?? "Cold War tensions"
            let countryID = body["playerCountry"] as? String ?? "USA"
            let diffStr   = body["difficulty"] as? String ?? "normal"

            let difficulty: DifficultyLevel = {
                switch diffStr.lowercased() {
                case "easy":      return .easy
                case "hard":      return .hard
                case "nightmare": return .nightmare
                default:          return .normal
                }
            }()

            // Find matching administration
            let admin = Advisor.allAdministrations().first {
                $0.president.lowercased().contains(president.lowercased()) ||
                ($0.startYear <= year && $0.endYear >= year)
            }

            let engine = GameEngine()
            engine.startNewGame(playerCountryID: countryID, difficulty: difficulty, administration: admin)

            // Override era start year to match requested year
            engine.gameState?.eraStartYear = year

            var session = MultiplayerSession(president: president, year: year, scenario: scenario)
            session.history.append("Session started: \(president) administration, \(year). Scenario: \(scenario)")

            multiplayerSession = session
            multiplayerEngine  = engine

            return json(201, [
                "sessionId": session.sessionId,
                "president": president,
                "year": year,
                "scenario": scenario,
                "playerCountry": countryID,
                "administration": admin?.president as Any,
                "state": gameStateSummary(engine.gameState)
            ] as [String: Any])

        // GET /api/crises — active crises requiring decisions
        case ("GET", "/api/crises"):
            guard let eng = multiplayerEngine else {
                return json(404, ["error": "No active multiplayer session"] as [String: Any])
            }
            var crises: [[String: Any]] = []
            if let crisis = eng.crisisManager.activeCrisis, !crisis.resolved {
                var c = crisisJSON(crisis)
                // Annotate with pending player if assigned
                if let player = multiplayerSession?.pendingDecisions[crisis.id.uuidString] {
                    c["pendingPlayer"] = player
                }
                crises.append(c)
            }
            return json(200, [
                "crises": crises,
                "count": crises.count
            ] as [String: Any])

        // POST /api/decision — {"crisis_id":"...","choice":0,"player":"Sam"}
        case ("POST", "/api/decision"):
            guard let body = req.bodyJSON() else {
                return json(400, ["error": "JSON body required: {crisis_id, choice, player}"] as [String: Any])
            }
            guard let crisisIdStr = body["crisis_id"] as? String,
                  let choiceIndex = body["choice"] as? Int else {
                return json(400, ["error": "crisis_id (String) and choice (Int) required"] as [String: Any])
            }
            let playerName = body["player"] as? String ?? "Unknown"

            guard let eng = multiplayerEngine else {
                return json(404, ["error": "No active multiplayer session"] as [String: Any])
            }
            guard let crisis = eng.crisisManager.activeCrisis,
                  crisis.id.uuidString == crisisIdStr else {
                return json(400, ["error": "Crisis \(crisisIdStr) not found or already resolved"] as [String: Any])
            }
            guard choiceIndex >= 0, choiceIndex < crisis.options.count else {
                return json(400, ["error": "choice must be 0–\(crisis.options.count - 1)"] as [String: Any])
            }

            guard var gs = eng.gameState else {
                return json(500, ["error": "No game state"] as [String: Any])
            }

            let chosenOption = crisis.options[choiceIndex]
            eng.crisisManager.resolveCrisis(optionIndex: choiceIndex, gameState: &gs)

            // Record decision
            let record = DecisionRecord(
                crisisId: crisisIdStr,
                crisisTitle: crisis.title,
                player: playerName,
                choiceIndex: choiceIndex,
                choiceTitle: chosenOption.title,
                turn: multiplayerSession?.turn ?? gs.turn,
                timestamp: Date()
            )
            multiplayerSession?.decisionLog.append(record)
            multiplayerSession?.pendingDecisions.removeValue(forKey: crisisIdStr)

            let eventMsg = "\(playerName) chose '\(chosenOption.title)' for crisis: \(crisis.title)"
            multiplayerSession?.history.append(eventMsg)

            return json(200, [
                "resolved": true,
                "crisisId": crisisIdStr,
                "crisisTitle": crisis.title,
                "player": playerName,
                "choiceIndex": choiceIndex,
                "choiceTitle": chosenOption.title,
                "consequence": chosenOption.consequences.message,
                "defcon": gs.defconLevel.rawValue,
                "state": gameStateSummary(eng.gameState)
            ] as [String: Any])

        // GET /api/history — recent events/outcomes (last 50)
        case ("GET", "/api/history"):
            guard let mp = multiplayerSession, let eng = multiplayerEngine else {
                return json(404, ["error": "No active multiplayer session"] as [String: Any])
            }
            let recentDecisions = mp.decisionLog.suffix(20).map { rec -> [String: Any] in
                [
                    "crisisId": rec.crisisId,
                    "crisisTitle": rec.crisisTitle,
                    "player": rec.player,
                    "choice": rec.choiceTitle,
                    "turn": rec.turn,
                    "timestamp": ISO8601DateFormatter().string(from: rec.timestamp)
                ]
            }
            let recentEvents = eng.gameState?.recentEvents.suffix(30) ?? []
            return json(200, [
                "sessionId": mp.sessionId,
                "president": mp.president,
                "year": mp.year,
                "multiplayerHistory": Array(mp.history.suffix(50)),
                "decisionLog": recentDecisions,
                "gameEvents": Array(recentEvents),
                "turn": mp.turn
            ] as [String: Any])

        // POST /api/assign-countries — {"assignments":{"USA":"Sam","USSR":"O.C.","UK":"Gaston"}}
        case ("POST", "/api/assign-countries"):
            guard let body = req.bodyJSON() else {
                return json(400, ["error": "JSON body required: {assignments: {countryID: playerName}}"] as [String: Any])
            }
            guard let assignments = body["assignments"] as? [String: String] else {
                return json(400, ["error": "assignments must be a dict of countryID → playerName"] as [String: Any])
            }
            guard multiplayerSession != nil else {
                return json(404, ["error": "No active multiplayer session. Call POST /api/start-session first."] as [String: Any])
            }
            guard let eng = multiplayerEngine, let gs = eng.gameState else {
                return json(500, ["error": "No game state in multiplayer session"] as [String: Any])
            }

            // Validate that all assigned country IDs exist in the game world
            var validated: [String: String] = [:]
            var unknown: [String] = []
            for (countryID, playerName) in assignments {
                let found = gs.countries.contains { $0.id == countryID || $0.name.lowercased() == countryID.lowercased() }
                if found {
                    // Normalize to the canonical ID
                    let canonical = gs.countries.first {
                        $0.id == countryID || $0.name.lowercased() == countryID.lowercased()
                    }?.id ?? countryID
                    validated[canonical] = playerName
                } else {
                    unknown.append(countryID)
                }
            }

            multiplayerSession?.countryAssignments = validated

            let eventMsg = "Countries assigned: " + validated.map { "\($0.key)→\($0.value)" }.sorted().joined(separator: ", ")
            multiplayerSession?.history.append(eventMsg)

            var result: [String: Any] = [
                "assigned": validated,
                "playerCount": validated.count
            ]
            if !unknown.isEmpty {
                result["unknownCountries"] = unknown
                result["warning"] = "Some country IDs not found in current game world"
            }
            return json(200, result)

        default:
            break
        }

        // ── Session-specific routes: /api/game/:id/... ─────────────────────
        guard parts.count >= 3, parts[0] == "api", parts[1] == "game" else {
            return json(404, ["error": "Not found: \(req.method) \(req.path)"] as [String: Any])
        }

        let sessionID = parts[2]
        guard let engine = sessions[sessionID] else {
            return json(404, ["error": "Session not found: \(sessionID)"] as [String: Any])
        }

        let subpath = parts.count > 3 ? "/" + parts[3...].joined(separator: "/") : ""

        switch (req.method, subpath) {

        // GET state
        case ("GET", "/state"), ("GET", ""):
            return json(200, fullGameState(engine))

        // GET active crisis
        case ("GET", "/crisis"):
            if let crisis = engine.crisisManager.activeCrisis {
                return json(200, crisisJSON(crisis))
            }
            return json(200, ["crisis": NSNull()] as [String: Any])

        // POST resolve crisis
        case ("POST", "/crisis/resolve"):
            guard let body = req.bodyJSON(),
                  let optionIndex = body["optionIndex"] as? Int else {
                return json(400, ["error": "optionIndex (Int) required"] as [String: Any])
            }
            guard engine.crisisManager.activeCrisis != nil else {
                return json(400, ["error": "No active crisis to resolve"] as [String: Any])
            }
            guard var gs = engine.gameState else {
                return json(500, ["error": "No game state"] as [String: Any])
            }
            engine.crisisManager.resolveCrisis(optionIndex: optionIndex, gameState: &gs)
            return json(200, [
                "resolved": true,
                "optionChosen": optionIndex,
                "state": gameStateSummary(engine.gameState)
            ] as [String: Any])

        // POST end turn
        case ("POST", "/turn"):
            guard let gs = engine.gameState, !gs.gameOver else {
                return json(400, ["error": "Game is over or not started"] as [String: Any])
            }
            engine.endTurn()
            // Brief wait for async AI processing to settle
            try? await Task.sleep(nanoseconds: 500_000_000)
            return json(200, [
                "turn": engine.gameState?.turn ?? 0,
                "year": engine.gameState?.currentYear ?? 0,
                "aiActions": engine.gameState?.aiActionSummary ?? [],
                "newCrisis": engine.crisisManager.activeCrisis.map { crisisJSON($0) } as Any,
                "state": gameStateSummary(engine.gameState)
            ] as [String: Any])

        // POST action (diplomacy, military, etc.)
        case ("POST", "/action"):
            guard let body = req.bodyJSON() else {
                return json(400, ["error": "JSON body required"] as [String: Any])
            }
            let actionStr   = body["action"] as? String ?? ""
            let targetID    = body["target"] as? String ?? ""

            guard let gs = engine.gameState, !gs.gameOver else {
                return json(400, ["error": "Game is over"] as [String: Any])
            }
            guard !gs.hasUsedActionThisTurn else {
                return json(400, ["error": "Action already used this turn. Call /turn to advance."] as [String: Any])
            }

            // Map string action to GameAction
            let result = applyAction(actionStr, target: targetID, engine: engine)
            return json(200, result)

        // DELETE session
        case ("DELETE", ""):
            sessions.removeValue(forKey: sessionID)
            return json(200, ["deleted": true, "sessionId": sessionID] as [String: Any])

        default:
            return json(404, ["error": "Not found: \(req.method) \(req.path)"] as [String: Any])
        }
    }

    // MARK: - Action handler

    private func applyAction(_ action: String, target: String, engine: GameEngine) -> [String: Any] {
        guard let gs = engine.gameState else {
            return ["error": "No game state"]
        }
        let playerID = gs.playerCountryID

        // Resolve country name or ID to ID
        let targetID: String = {
            if gs.countries.contains(where: { $0.id == target }) { return target }
            return gs.countries.first { $0.name.lowercased() == target.lowercased() }?.id ?? target
        }()

        switch action.lowercased() {
        case "diplomacy", "improve_relations":
            engine.modifyDiplomaticRelation(from: playerID, to: targetID, by: 15)
            gs.hasUsedActionThisTurn = true
            return ["action": action, "target": targetID,
                    "result": "Diplomatic relations improved with \(targetID)",
                    "state": gameStateSummary(engine.gameState)]

        case "sanction", "sanctions":
            engine.modifyDiplomaticRelation(from: playerID, to: targetID, by: -20)
            gs.hasUsedActionThisTurn = true
            return ["action": action, "target": targetID,
                    "result": "Sanctions imposed on \(targetID)",
                    "state": gameStateSummary(engine.gameState)]

        case "economic", "trade", "aid":
            engine.economicDiplomacy(from: playerID, to: targetID, amount: 1_000_000_000)
            gs.hasUsedActionThisTurn = true
            return ["action": action, "target": targetID,
                    "result": "Economic aid and trade deal with \(targetID)",
                    "state": gameStateSummary(engine.gameState)]

        case "nuclear", "nuke", "launch":
            let warheads = 1
            engine.launchNuclearStrike(from: playerID, to: targetID, warheads: warheads)
            gs.hasUsedActionThisTurn = true
            return ["action": action, "target": targetID,
                    "result": "Nuclear strike launched at \(targetID). DEFCON elevated.",
                    "defcon": gs.defconLevel.rawValue,
                    "state": gameStateSummary(engine.gameState)]

        case "help", "actions":
            return ["availableActions": [
                "diplomacy <countryID>   — improve diplomatic relations (+15)",
                "sanction <countryID>    — impose economic sanctions (-20 relations)",
                "economic <countryID>    — $1B aid/trade package",
                "nuclear <countryID>     — launch nuclear strike (IRREVERSIBLE)",
                "help                    — show this list"
            ] as [String]]

        default:
            return ["error": "Unknown action: '\(action)'. Use 'help' for available actions."]
        }
    }

    // MARK: - JSON serialization helpers

    private func fullGameState(_ engine: GameEngine) -> [String: Any] {
        guard let gs = engine.gameState else {
            return ["error": "No active game state"]
        }
        var d = gameStateSummary(gs)
        d["countries"] = gs.countries.map { countryJSON($0, playerID: gs.playerCountryID) }
        d["activeWars"] = gs.activeWars.map { warJSON($0) }
        d["recentEvents"] = gs.recentEvents
        d["advisors"] = gs.advisors.map { ["name": $0.name, "title": $0.title, "department": $0.department, "loyalty": $0.loyalty, "hawkishness": $0.hawkishness] as [String: Any] }
        if let crisis = engine.crisisManager.activeCrisis {
            d["activeCrisis"] = crisisJSON(crisis)
        }
        return d
    }

    private func gameStateSummary(_ gs: GameState?) -> [String: Any] {
        guard let gs = gs else { return ["error": "no state"] }
        let player = gs.countries.first { $0.id == gs.playerCountryID }
        return [
            "turn": gs.turn,
            "year": gs.currentYear,
            "defcon": gs.defconLevel.rawValue,
            "defconLabel": gs.defconLevel.description,
            "playerCountry": gs.playerCountryID,
            "playerWarheads": player?.nuclearWarheads ?? 0,
            "playerStability": player?.stability ?? 0,
            "globalRadiation": gs.globalRadiation,
            "totalCasualties": gs.totalCasualties,
            "activeWarsCount": gs.activeWars.count,
            "gameOver": gs.gameOver,
            "gameOverReason": gs.gameOverReason,
            "victoryType": gs.victoryType.map { "\($0)" } as Any,
            "peaceTurns": gs.peaceTurns,
            "hasUsedActionThisTurn": gs.hasUsedActionThisTurn,
            "woprEndingUnlocked": gs.peaceTurns >= 50 && gs.nukesLaunched == 0 && gs.warsStarted == 0
        ]
    }

    private func countryJSON(_ c: Country, playerID: String) -> [String: Any] {
        [
            "id": c.id, "name": c.name, "isPlayer": c.id == playerID,
            "warheads": c.nuclearWarheads, "military": c.militaryStrength,
            "economy": c.economicStrength, "stability": c.stability,
            "isAtWar": !c.atWarWith.isEmpty, "hasNukes": c.nuclearWarheads > 0,
            "alignment": "\(c.alignment)", "isDestroyed": c.isDestroyed
        ]
    }

    private func warJSON(_ w: War) -> [String: Any] {
        ["aggressor": w.aggressor, "defender": w.defender, "turn": w.startTurn, "intensity": w.intensity]
    }

    private func crisisJSON(_ crisis: CrisisEvent) -> [String: Any] {
        [
            "id": crisis.id.uuidString,
            "type": crisis.type.rawValue,
            "severity": crisis.severity.rawValue,
            "severityLabel": crisis.severity.description,
            "title": crisis.title,
            "description": crisis.description,
            "affectedCountries": crisis.affectedCountries,
            "options": crisis.options.enumerated().map { i, opt in
                [
                    "index": i,
                    "title": opt.title,
                    "description": opt.description,
                    "advisorRecommendation": opt.advisorRecommendation as Any,
                    "successChance": opt.successChance,
                    "consequences": [
                        "defconChange": opt.consequences.defconChange,
                        "approvalChange": opt.consequences.approvalChange,
                        "triggersWar": opt.consequences.triggersWar,
                        "message": opt.consequences.message
                    ] as [String: Any]
                ] as [String: Any]
            }
        ]
    }

    // MARK: - HTTP helpers

    private struct NovaRequest {
        let method: String; let path: String; let body: String; let authorization: String?
        func bodyJSON() -> [String: Any]? {
            guard let d = body.data(using: .utf8), !body.isEmpty else { return nil }
            return try? JSONSerialization.jsonObject(with: d) as? [String: Any]
        }
        /// True iff the request carries `Authorization: Bearer <token>` matching the per-install token.
        func isAuthorized(token: String) -> Bool {
            guard !token.isEmpty, let auth = authorization else { return false }
            return auth == "Bearer \(token)"
        }
        init?(_ data: Data) {
            guard let raw = String(data: data, encoding: .utf8), raw.contains("\r\n\r\n") else { return nil }
            let parts = raw.components(separatedBy: "\r\n\r\n")
            let lines = parts[0].components(separatedBy: "\r\n")
            guard let rl = lines.first else { return nil }
            let tokens = rl.components(separatedBy: " ")
            guard tokens.count >= 2 else { return nil }
            var hdrs: [String: String] = [:]
            for l in lines.dropFirst() {
                let kv = l.components(separatedBy: ": ")
                if kv.count >= 2 { hdrs[kv[0].lowercased()] = kv.dropFirst().joined(separator: ": ") }
            }
            let rawBody = parts.dropFirst().joined(separator: "\r\n\r\n")
            if let cl = hdrs["content-length"], let n = Int(cl), rawBody.utf8.count < n { return nil }
            method = tokens[0]
            path = tokens[1].components(separatedBy: "?").first ?? tokens[1]
            body = rawBody
            authorization = hdrs["authorization"]
        }
    }

    // MARK: - Per-install API token (Keychain-backed)
    //
    // Mutating routes require `Authorization: Bearer <apiToken>`. The token is generated once with
    // a CSPRNG and stored in the login Keychain; native Nova clients read it from the same Keychain
    // item. To rotate it, delete the Keychain item and the next launch regenerates one.

    private static let keychainService = "com.jordankoch.GTNW.NovaAPIServer"
    private static let keychainAccount = "api_bearer_token"

    /// The per-install bearer token required on mutating routes.
    static let apiToken: String = loadOrCreateToken()

    private static func loadOrCreateToken() -> String {
        if let existing = loadToken() { return existing }
        let token = generateToken()
        saveToken(token)
        return token
    }

    private static func generateToken() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return bytes.map { String(format: "%02x", $0) }.joined()
    }

    private static func loadToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else { return nil }
        return token
    }

    private static func saveToken(_ token: String) {
        guard let data = token.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    private func json(_ s: Int, _ d: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: d, options: .prettyPrinted),
              let body = String(data: data, encoding: .utf8) else { return http(500, "") }
        return http(s, body, "application/json")
    }
    private func jsonArray(_ s: Int, _ a: [[String: Any]]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: a, options: .prettyPrinted),
              let body = String(data: data, encoding: .utf8) else { return http(500, "") }
        return http(s, body, "application/json")
    }
    private func http(_ s: Int, _ body: String, _ ct: String = "text/plain") -> String {
        let st = [200:"OK",201:"Created",400:"Bad Request",401:"Unauthorized",404:"Not Found",500:"Internal Server Error"][s] ?? "Unknown"
        // No Access-Control-Allow-Origin: loopback-only API for native clients (which ignore CORS).
        // A wildcard ACAO would let any website the user visits read these responses and, combined
        // with the token gate above, is unnecessary; omitting it stops cross-origin browser reads.
        return "HTTP/1.1 \(s) \(st)\r\nContent-Type: \(ct); charset=utf-8\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n\(body)"
    }
}
