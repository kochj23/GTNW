//
//  AIBrain.swift
//  Global Thermal Nuclear War
//
//  "A brain per country." Each country can be driven by a different backend:
//    • .human          — a human at the keyboard (no automated move)
//    • .ruleBased      — the fast built-in rule-based AI (DEFAULT, network-free)
//    • .liveSession    — a LIVE Claude Code session answering over the PG
//                        coordination bus (true PvP)
//    • .gatewayClaude  — an always-on Gateway-Claude, answers inline
//    • .model(...)     — any OpenAI-compatible endpoint (local Ollama model or
//                        an OpenRouter frontier model)
//
//  Transport lives here; the request/response contract and the pure
//  buildMoveRequest/applyMove helpers live in AIMove.swift.
//
//  Created by Jordan Koch on 2026.
//

import Foundation

// MARK: - Brain identity

/// Which OpenAI-compatible backend a `.model` brain talks to.
enum ModelBackend: String, Codable, Equatable, Hashable, Sendable, CaseIterable {
    case ollama            // local Ollama (OpenAI-compatible /v1/chat/completions)
    case openRouter        // frontier models via OpenRouter
    case gateway           // Nova Gateway OpenAI-compatible route
    case openAICompatible  // any other OpenAI-compatible server
}

/// Identifies who plays a country.
enum AIBrain: Equatable, Hashable, Sendable, Codable {
    case human
    case ruleBased
    case liveSession
    case gatewayClaude
    case model(id: String, endpoint: String, backend: ModelBackend)

    /// True for brains that require an LLM/session round-trip (vs. local logic).
    var needsRemoteMove: Bool {
        switch self {
        case .human, .ruleBased: return false
        case .liveSession, .gatewayClaude, .model: return true
        }
    }

    /// Short label for the picker UI.
    var displayName: String {
        switch self {
        case .human:         return "Human"
        case .ruleBased:     return "Rule-Based AI"
        case .liveSession:   return "This Session (live)"
        case .gatewayClaude: return "Gateway-Claude"
        case .model(let id, _, _): return id
        }
    }

    // MARK: Codable (stable, discriminated)

    private enum CodingKeys: String, CodingKey { case kind, id, endpoint, backend }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(String.self, forKey: .kind) {
        case "human":         self = .human
        case "ruleBased":     self = .ruleBased
        case "liveSession":   self = .liveSession
        case "gatewayClaude": self = .gatewayClaude
        case "model":
            self = .model(
                id: try c.decode(String.self, forKey: .id),
                endpoint: try c.decode(String.self, forKey: .endpoint),
                backend: try c.decode(ModelBackend.self, forKey: .backend)
            )
        default: self = .ruleBased
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .human:         try c.encode("human", forKey: .kind)
        case .ruleBased:     try c.encode("ruleBased", forKey: .kind)
        case .liveSession:   try c.encode("liveSession", forKey: .kind)
        case .gatewayClaude: try c.encode("gatewayClaude", forKey: .kind)
        case .model(let id, let endpoint, let backend):
            try c.encode("model", forKey: .kind)
            try c.encode(id, forKey: .id)
            try c.encode(endpoint, forKey: .endpoint)
            try c.encode(backend, forKey: .backend)
        }
    }
}

// MARK: - Configuration

/// Tunable transport settings. All timeouts guarantee the turn loop never hangs.
struct BrainConfig: Sendable {
    /// Nova Gateway OpenAI-compatible chat endpoint (always-on Gateway-Claude).
    var gatewayEndpoint: String = "http://127.0.0.1:18792/v1/chat/completions"
    var gatewayModel: String = "chat"
    var gatewayTimeout: TimeInterval = 30

    /// Base URL of the live-session coordination bridge (see
    /// tools/gtnw_coordination_bridge.py). GTNW POSTs a MoveRequest to
    /// `<base>/move` and polls `<base>/move/<key>` for the answer.
    var liveSessionBaseURL: String = "http://127.0.0.1:18793/gtnw"
    /// If no live session answers within this window, the turn falls back to
    /// rule-based AI so the game never blocks on a human.
    var liveSessionTimeout: TimeInterval = 25
    var liveSessionPollInterval: TimeInterval = 1.0

    /// Timeout for `.model(...)` brains.
    var modelTimeout: TimeInterval = 30

    static let `default` = BrainConfig()
}

// MARK: - Model registry (pure parsing + optional fetch)

struct ModelInfo: Identifiable, Equatable, Hashable, Sendable {
    var id: String { name }
    var name: String
    var sizeBytes: Int64

    var sizeLabel: String {
        guard sizeBytes > 0 else { return "" }
        return String(format: "%.1f GB", Double(sizeBytes) / 1_000_000_000)
    }
}

enum ModelRegistry {
    static let ollamaHost = "http://localhost:11434"

    /// PURE: map an Ollama `/api/tags` body to models. Empty/garbage → [].
    static func parseOllamaTags(_ data: Data) -> [ModelInfo] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let models = json["models"] as? [[String: Any]] else { return [] }
        return models.compactMap { dict in
            guard let name = dict["name"] as? String, !name.isEmpty else { return nil }
            let size: Int64
            if let i64 = dict["size"] as? Int64 { size = i64 }
            else if let i = dict["size"] as? Int { size = Int64(i) }
            else { size = 0 }
            return ModelInfo(name: name, sizeBytes: size)
        }
    }

    /// Fetch installed local models from Ollama. Network — returns [] on failure.
    static func fetchLocalModels(host: String = ollamaHost) async -> [ModelInfo] {
        guard let url = URL(string: "\(host)/api/tags"),
              let (data, _) = try? await URLSession.shared.data(from: url) else { return [] }
        return parseOllamaTags(data)
    }
}

// MARK: - Minimal OpenAI-compatible client

/// A small vendored equivalent of AIStudio's `OpenAICompatibleRequest`: builds a
/// chat-completions POST and extracts `choices[0].message.content`.
struct OpenAICompatibleRequest {
    var endpoint: String
    var model: String
    var systemPrompt: String
    var userPrompt: String
    var temperature: Double = 0.5
    var maxTokens: Int = 300
    var timeout: TimeInterval = 30
    var apiKey: String? = nil

    func makeURLRequest() -> URLRequest? {
        guard let url = URL(string: endpoint) else { return nil }
        let body: [String: Any] = [
            "model": model,
            "temperature": temperature,
            "max_tokens": maxTokens,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ]
        ]
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let apiKey, !apiKey.isEmpty {
            req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        req.timeoutInterval = timeout
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return req
    }

    /// PURE: extract assistant content from an OpenAI-compatible response body.
    static func parseContent(_ data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if let choices = json["choices"] as? [[String: Any]], let first = choices.first {
            if let message = first["message"] as? [String: Any],
               let content = message["content"] as? String { return content }
            if let text = first["text"] as? String { return text }  // legacy completion shape
        }
        return json["response"] as? String  // ollama native fallback
    }

    /// Send and return the assistant text, or nil on any failure.
    func send() async -> String? {
        guard let req = makeURLRequest() else { return nil }
        guard let (data, resp) = try? await URLSession.shared.data(for: req) else { return nil }
        if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) { return nil }
        return Self.parseContent(data)
    }
}

// MARK: - Timeout wrapper

/// Race an async move-producing operation against a timeout. If the timeout
/// wins (or the operation yields nil), returns nil so the caller can fall back.
func withMoveTimeout(
    _ seconds: TimeInterval,
    operation: @escaping @Sendable () async -> MoveResponse?
) async -> MoveResponse? {
    await withTaskGroup(of: MoveResponse?.self) { group in
        group.addTask { await operation() }
        group.addTask {
            try? await Task.sleep(nanoseconds: UInt64(max(0, seconds) * 1_000_000_000))
            return nil
        }
        let first = await group.next() ?? nil
        group.cancelAll()
        return first
    }
}

// MARK: - Brain transport

/// Dispatches a MoveRequest to the correct backend and returns a MoveResponse,
/// or nil (caller falls back to rule-based). Never main-actor isolated so it can
/// run concurrently off the main thread.
enum BrainClient {

    static func requestMove(_ request: MoveRequest, brain: AIBrain, config: BrainConfig) async -> MoveResponse? {
        switch brain {
        case .human, .ruleBased:
            return nil
        case .gatewayClaude:
            return await withMoveTimeout(config.gatewayTimeout) {
                await openAICompatibleMove(request, endpoint: config.gatewayEndpoint, model: config.gatewayModel)
            }
        case .model(let id, let endpoint, _):
            return await withMoveTimeout(config.modelTimeout) {
                await openAICompatibleMove(request, endpoint: endpoint, model: id)
            }
        case .liveSession:
            return await withMoveTimeout(config.liveSessionTimeout) {
                await LiveSessionBus.requestMove(request, config: config)
            }
        }
    }

    /// Prompt an OpenAI-compatible endpoint for a MoveResponse.
    static func openAICompatibleMove(_ request: MoveRequest, endpoint: String, model: String) async -> MoveResponse? {
        let system = """
        You are the strategic AI for one nation in a Cold War / nuclear simulation. \
        Respond with ONLY a JSON object of the form \
        {"action":"<ACTION>","target":"<COUNTRY_ID or null>","params":{"warheads":N},"rationale":"..."}. \
        Choose exactly one action from the provided legalActions. Use a target country ID from the world state \
        for actions that require one. Do not add prose outside the JSON.
        """
        let user = """
        \(request.worldStateSummary)

        Turn: \(request.turn)  Year: \(request.year)  DEFCON: \(request.defcon)
        legalActions: \(request.legalActions.joined(separator: ", "))

        Reply with the JSON move now.
        """
        let text = await OpenAICompatibleRequest(
            endpoint: endpoint, model: model,
            systemPrompt: system, userPrompt: user,
            temperature: 0.6, maxTokens: 250
        ).send()
        guard let text else { return nil }
        return MoveResponse.decode(fromText: text)
    }
}

// MARK: - Live-session bus (true PvP)

/// Client for the live-session coordination bridge. GTNW parks a MoveRequest for
/// a live Claude Code session (which writes into `nova_ops.claude_coordination`)
/// and polls for the answer. If nothing answers before the timeout, the caller
/// falls back to rule-based AI.
///
/// TRANSPORT CHOICE: GTNW talks HTTP to a small local bridge on Nova Gateway
/// (`:18792`) rather than embedding a Postgres client. This keeps GTNW free of a
/// heavy pinned SPM dependency (PostgresNIO) that risked the CI dependency pain
/// seen elsewhere; the bridge owns the single PG write/read. See
/// tools/gtnw_coordination_bridge.py — Jordan must stand this up for end-to-end
/// live PvP. Until then, calls simply time out and fall back, harmlessly.
enum LiveSessionBus {

    static func moveKey(_ request: MoveRequest) -> String {
        "\(request.gameId)/\(request.turn)/\(request.countryId)"
    }

    static func requestMove(_ request: MoveRequest, config: BrainConfig) async -> MoveResponse? {
        let key = moveKey(request)
        // 1. POST the request so a live session can pick it up.
        guard await post(request, to: "\(config.liveSessionBaseURL)/move") else { return nil }

        // 2. Poll for the answer until the surrounding timeout fires.
        let pollNanos = UInt64(max(0.1, config.liveSessionPollInterval) * 1_000_000_000)
        while !Task.isCancelled {
            if let response = await fetchResponse(key: key, config: config) {
                return response
            }
            try? await Task.sleep(nanoseconds: pollNanos)
        }
        return nil
    }

    private static func post(_ request: MoveRequest, to urlString: String) async -> Bool {
        guard let url = URL(string: urlString),
              let body = try? JSONEncoder().encode(request) else { return false }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = body
        req.timeoutInterval = 10
        guard let (_, resp) = try? await URLSession.shared.data(for: req) else { return false }
        if let http = resp as? HTTPURLResponse { return (200...299).contains(http.statusCode) }
        return false
    }

    private static func fetchResponse(key: String, config: BrainConfig) async -> MoveResponse? {
        let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? key
        guard let url = URL(string: "\(config.liveSessionBaseURL)/move/\(encodedKey)") else { return nil }
        guard let (data, resp) = try? await URLSession.shared.data(from: url) else { return nil }
        // 200 = answered, anything else = still pending.
        if let http = resp as? HTTPURLResponse, http.statusCode == 200 {
            return MoveResponse.decode(from: data)
        }
        return nil
    }
}
