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
//    • .model(...)     — a local Ollama model, an OpenRouter frontier model or any
//                        OpenAI-compatible server. Model brains go through NovaAIKit
//                        (3.24): OpenRouter sends the Keychain key over https only,
//                        and sends nothing without one.
//
//  Transport lives here; the request/response contract and the pure
//  buildMoveRequest/applyMove helpers live in AIMove.swift.
//
//  Created by Jordan Koch on 2026.
//

import Foundation
import NovaAIKit

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
    /// 3.27.0 model vs model: any NovaAIKit backend (`NovaAIBackend.rawValue`: ollama, anthropic, xai, gemini…)
    /// and model, sent with the kit's per-request override (exactly that backend, no failover). "auto" = Settings.
    case kit(backend: String, model: String)

    /// True for brains that require an LLM/session round-trip (vs. local logic).
    var needsRemoteMove: Bool {
        switch self {
        case .human, .ruleBased: return false
        case .liveSession, .gatewayClaude, .model, .kit: return true
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
        case .kit(let backend, let model):
            let name = NovaAIBackend(rawValue: backend)?.displayName ?? backend
            return model.isEmpty ? name : "\(name): \(model)"
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
        case "kit": self = .kit(backend: try c.decode(String.self, forKey: .backend), model: try c.decode(String.self, forKey: .id))
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
        case .kit(let backend, let model):
            try c.encode("kit", forKey: .kind)
            try c.encode(backend, forKey: .backend)
            try c.encode(model, forKey: .id)
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
    /// The NovaAIKit engine model brains go through (keys, https-only rule, retries, timeouts). Nil = the app's
    /// `AppAI.shared.engine` at the start of the turn; tests inject one with a stub session.
    var engine: NovaAIEngine? = nil

    /// Nova Gateway base URL for Gateway-Claude. Nil = Settings → AI → Nova Gateway URL.
    var gatewayBaseURL: String? = nil
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

    /// The live-session bridge (not an LLM) keeps GTNW's own retry/transport seams.
    var retryPolicy: RetryPolicy = .network
    var transport: HTTPTransport = HTTP.live
    var retrySleep: RetrySleeper = Retry.realSleep

    static let `default` = BrainConfig()
}

// MARK: - Brain routing (pure)

/// Where a model brain's request goes, in NovaAIKit terms.
struct BrainTarget: Equatable, Sendable {
    var backend: NovaAIBackend
    var baseURL: String
    var model: String
}

enum BrainRoute {
    /// Chat paths a stored brain endpoint may end with (brains saved before 3.24 store the full chat URL).
    static let chatSuffixes = ["/v1/chat/completions", "/chat/completions", "/api/chat", "/api/generate"]

    /// PURE: the base URL the kit wants for `backend`: the stored endpoint minus its chat path and trailing
    /// slashes. OpenRouter/OpenAI bases keep their `/v1` (the kit appends `/chat/completions`).
    static func baseURL(_ endpoint: String, for backend: NovaAIBackend = .novaGateway) -> String {
        var s = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        while s.hasSuffix("/") { s.removeLast() }
        let suffixes = [backend.chatPath] + (backend.requiresKey ? [] : chatSuffixes)
        for suffix in suffixes where !suffix.isEmpty && s.hasSuffix(suffix) {
            s.removeLast(suffix.count)
            break
        }
        while s.hasSuffix("/") { s.removeLast() }
        return s
    }

    /// PURE: the kit backend/URL/model for a brain; nil for brains that never call a model.
    static func target(for brain: AIBrain, gatewayBaseURL: String, gatewayModel: String) -> BrainTarget? {
        switch brain {
        case .human, .ruleBased, .liveSession, .kit:
            return nil   // a kit brain is routed per request (see BrainClient.requestMove)
        case .gatewayClaude:
            return BrainTarget(backend: .novaGateway, baseURL: baseURL(gatewayBaseURL, for: .novaGateway), model: gatewayModel)
        case .model(let id, let endpoint, let backend):
            let kit: NovaAIBackend
            switch backend {
            case .ollama: kit = .ollama
            case .openRouter: kit = .openRouter
            case .gateway, .openAICompatible: kit = .novaGateway   // OpenAI-compatible /v1/chat/completions
            }
            return BrainTarget(backend: kit, baseURL: baseURL(endpoint, for: kit), model: id)
        }
    }

    /// The engine for one brain call: the app's engine pinned to exactly this backend, server and model (no Auto
    /// failover to another provider, no extra LAN servers), with the brain's timeout.
    static func engine(_ base: NovaAIEngine, for target: BrainTarget, timeout: TimeInterval) -> NovaAIEngine {
        var e = base
        var s = base.settings
        s.backend = target.backend
        s.urls[target.backend.rawValue] = target.baseURL
        s.models[target.backend.rawValue] = target.model
        s.extraOllamaEndpoints = []
        s.timeout = min(max(timeout, NovaAISettings.timeoutRange.lowerBound), NovaAISettings.timeoutRange.upperBound)
        e.settings = s
        return e
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

    static let systemPrompt = """
        You are the strategic AI for one nation in a Cold War / nuclear simulation. \
        Respond with ONLY a JSON object of the form \
        {"action":"<ACTION>","target":"<COUNTRY_ID or null>","params":{"warheads":N},"rationale":"..."}. \
        Choose exactly one action from the provided legalActions. Use a target country ID from the world state \
        for actions that require one. Do not add prose outside the JSON.
        """

    static func userPrompt(_ request: MoveRequest) -> String {
        """
        \(request.worldStateSummary)

        Turn: \(request.turn)  Year: \(request.year)  DEFCON: \(request.defcon)
        legalActions: \(request.legalActions.joined(separator: ", "))
        \(request.previousError.map { "Your last answer was rejected: \($0). Choose again from legalActions." } ?? "")
        Reply with the JSON move now.
        """
    }

    static func requestMove(_ request: MoveRequest, brain: AIBrain, config: BrainConfig) async -> MoveResponse? {
        switch brain {
        case .human, .ruleBased:
            return nil
        case .liveSession:
            return await withMoveTimeout(config.liveSessionTimeout) {
                await LiveSessionBus.requestMove(request, config: config, transport: config.transport,
                                                 retryPolicy: config.retryPolicy, sleep: config.retrySleep)
            }
        case .gatewayClaude, .model:
            guard let base = config.engine else { return nil }
            let gateway = config.gatewayBaseURL ?? base.settings.url(for: .novaGateway)
            guard let target = BrainRoute.target(for: brain, gatewayBaseURL: gateway, gatewayModel: config.gatewayModel)
            else { return nil }
            let timeout = brain == .gatewayClaude ? config.gatewayTimeout : config.modelTimeout
            let engine = BrainRoute.engine(base, for: target, timeout: timeout)
            return await withMoveTimeout(timeout) { await modelMove(request, engine: engine) }
        case .kit(let backend, let model):
            // NovaAIKit 1.1.0: the request names its backend + model; the kit sends it exactly there (keys from the
            // Keychain, https only, nothing for a cloud backend without a key, nothing to Nova when Allow Nova is off).
            guard let engine = config.engine, let b = NovaAIBackend(rawValue: backend) else { return nil }
            let pinned = b == .auto ? nil : b
            return await withMoveTimeout(config.modelTimeout) {
                await modelMove(request, engine: engine, backend: pinned, model: pinned == nil || model.isEmpty ? nil : model)
            }
        }
    }

    /// One move from a model through NovaAIKit. OpenRouter needs its Keychain key and https: without either the kit
    /// sends nothing (the world state never leaves the Mac) and the country plays rule-based. The reply is
    /// validated by `MoveResponse.decode`; legality is checked by `applyMove`.
    static func modelMove(_ request: MoveRequest, engine: NovaAIEngine, backend: NovaAIBackend? = nil,
                          model: String? = nil) async -> MoveResponse? {
        let req = NovaAIRequest(prompt: userPrompt(request), system: systemPrompt, temperature: 0.6, maxTokens: 250,
                                backend: backend, model: model)
        guard let reply = try? await engine.complete(req) else { return nil }
        return MoveResponse.decode(fromText: reply.text)
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

    static func requestMove(
        _ request: MoveRequest, config: BrainConfig,
        transport: @escaping HTTPTransport = HTTP.live,
        retryPolicy: RetryPolicy = .network,
        sleep: @escaping RetrySleeper = Retry.realSleep
    ) async -> MoveResponse? {
        let key = moveKey(request)
        // 1. POST the request so a live session can pick it up (retried with backoff).
        guard await post(request, to: "\(config.liveSessionBaseURL)/move",
                         transport: transport, retryPolicy: retryPolicy, sleep: sleep) else { return nil }

        // 2. Poll for the answer until the surrounding timeout fires.
        let pollNanos = UInt64(max(0.1, config.liveSessionPollInterval) * 1_000_000_000)
        while !Task.isCancelled {
            if let response = await fetchResponse(key: key, config: config, transport: transport) {
                return response
            }
            try? await Task.sleep(nanoseconds: pollNanos)
        }
        return nil
    }

    static func post(
        _ request: MoveRequest, to urlString: String,
        transport: @escaping HTTPTransport = HTTP.live,
        retryPolicy: RetryPolicy = .network,
        sleep: @escaping RetrySleeper = Retry.realSleep
    ) async -> Bool {
        guard let url = URL(string: urlString),
              let body = try? JSONEncoder().encode(request) else { return false }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = body
        req.timeoutInterval = 10
        guard let (_, resp) = try? await Retry.http(req, label: "live-session POST",
                                                    transport: transport, policy: retryPolicy, sleep: sleep)
        else { return false }
        return resp is HTTPURLResponse
    }

    // Polling is itself a retry loop (bounded by the caller's timeout), so each
    // poll is a single attempt.
    static func fetchResponse(key: String, config: BrainConfig,
                              transport: HTTPTransport = HTTP.live) async -> MoveResponse? {
        let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? key
        guard let url = URL(string: "\(config.liveSessionBaseURL)/move/\(encodedKey)") else { return nil }
        guard let (data, resp) = try? await transport(URLRequest(url: url)) else { return nil }
        // 200 = answered, anything else = still pending.
        if let http = resp as? HTTPURLResponse, http.statusCode == 200 {
            return MoveResponse.decode(from: data)
        }
        return nil
    }
}
