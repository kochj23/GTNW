//
//  LLMBackendType.swift
//  Global Thermal Nuclear War
//
//  The canonical backend ids shared by Jordan's games (same lowercase raw values as Blompie/BlompieTV's
//  `LLMBackendType`). Raw values are stable, Codable-safe ids; `displayName` is what the UI shows.
//
//  Google Cloud, Azure, AWS and IBM Watson were removed in 3.23.0: Google's URL held the literal YOUR_PROJECT_ID,
//  AWS was a stub that always threw, and none of them ever had a way to enter a key. Claude and other frontier
//  models are reached through OpenRouter (one Keychain key) or the Nova Gateway.
//
//  Created by Jordan Koch on 2026.
//

import Foundation

enum LLMBackendType: String, CaseIterable, Codable, Sendable, Hashable {
    case auto = "auto"
    case ollama = "ollama"
    case mlx = "mlx"
    case tinyLLM = "tinyllm"
    case tinyChat = "tinychat"
    case openWebUI = "openwebui"
    case novaGateway = "novagateway"
    case openRouter = "openrouter"
    case openAI = "openai"

    /// Auto mode tries backends in exactly this order (local first, cloud last).
    static let autoOrder: [LLMBackendType] = [.ollama, .mlx, .tinyChat, .tinyLLM, .openWebUI, .novaGateway, .openRouter, .openAI]

    /// Backends the picker offers on this platform (MLX runs a local python subprocess, so macOS only).
    static var pickerCases: [LLMBackendType] {
        #if os(macOS)
        return allCases
        #else
        return allCases.filter { $0 != .mlx }
        #endif
    }

    var displayName: String {
        switch self {
        case .auto: return "Auto (Prefer Local)"
        case .ollama: return "Ollama"
        case .mlx: return "MLX Toolkit"
        case .tinyLLM: return "TinyLLM"
        case .tinyChat: return "TinyChat"
        case .openWebUI: return "OpenWebUI"
        case .novaGateway: return "Nova Gateway"
        case .openRouter: return "OpenRouter"
        case .openAI: return "OpenAI"
        }
    }

    var icon: String {
        switch self {
        case .auto: return "sparkles"
        case .ollama: return "network"
        case .mlx: return "cpu"
        case .tinyLLM: return "cube"
        case .tinyChat: return "bubble.left.and.bubble.right.fill"
        case .openWebUI: return "globe"
        case .novaGateway: return "brain.head.profile"
        case .openRouter: return "cloud"
        case .openAI: return "brain"
        }
    }

    var description: String {
        switch self {
        case .auto: return "Use the first backend that answers: Ollama, MLX, TinyChat, TinyLLM, OpenWebUI, Nova Gateway, OpenRouter, OpenAI"
        case .ollama: return "Ollama server (default http://localhost:11434, any LAN host works)"
        case .mlx: return "Python MLX Toolkit (runs a model locally via python3)"
        case .tinyLLM: return "TinyLLM lightweight OpenAI-compatible server (default http://localhost:8000)"
        case .tinyChat: return "TinyChat by Jason Cox (default http://localhost:8000)"
        case .openWebUI: return "OpenWebUI self-hosted platform (default http://localhost:8080)"
        case .novaGateway: return "Nova Gateway OpenAI-compatible route (default http://127.0.0.1:18792); also reaches Claude"
        case .openRouter: return "Frontier models (Claude, GPT, Gemini, Llama) via OpenRouter; needs a key, https only"
        case .openAI: return "OpenAI API (api.openai.com); needs a key, https only"
        }
    }

    var attribution: String? {
        switch self {
        case .tinyLLM: return "TinyLLM by Jason Cox (https://github.com/jasonacox/TinyLLM)"
        case .tinyChat: return "TinyChat by Jason Cox (https://github.com/jasonacox/tinychat)"
        case .openWebUI: return "OpenWebUI Community Project (https://github.com/open-webui/open-webui)"
        case .openRouter: return "OpenRouter (https://openrouter.ai)"
        case .openAI: return "OpenAI (https://platform.openai.com)"
        default: return nil
        }
    }

    /// Cloud backends carry an API key, so they must use https and need a key to be available.
    var needsAPIKey: Bool { self == .openRouter || self == .openAI }

    /// Map a persisted selection to the canonical id. Before 3.23.0 GTNW stored display names ("Ollama",
    /// "MLX Toolkit", "Google Cloud AI", …); the removed cloud backends map to `.auto`.
    static func migrate(persisted raw: String?) -> LLMBackendType {
        guard let raw, !raw.isEmpty else { return .auto }
        if let id = LLMBackendType(rawValue: raw) { return id }
        switch raw {
        case "Ollama": return .ollama
        case "MLX Toolkit": return .mlx
        case "TinyLLM": return .tinyLLM
        case "TinyChat": return .tinyChat
        case "OpenWebUI": return .openWebUI
        case "OpenAI": return .openAI
        default: return .auto   // "Auto (Prefer Ollama)", Google Cloud AI, Microsoft Azure, AWS AI Services, IBM Watson
        }
    }

    /// PURE: which backend serves a request. An explicit choice is used only when it is reachable; `.auto` takes the
    /// first reachable backend in `autoOrder`. Nil means "no AI right now" and callers use their scripted fallback.
    static func resolve(selected: LLMBackendType, available: Set<LLMBackendType>) -> LLMBackendType? {
        if selected != .auto { return available.contains(selected) ? selected : nil }
        return autoOrder.first { available.contains($0) }
    }

    /// PURE: the failover chain for one request — the active backend first, then (in Auto only) every other
    /// reachable backend in `autoOrder`. Explicit choices never fail over to a different provider.
    static func failoverChain(selected: LLMBackendType, active: LLMBackendType?, available: Set<LLMBackendType>) -> [LLMBackendType] {
        guard let active else { return [] }
        guard selected == .auto else { return [active] }
        return [active] + autoOrder.filter { $0 != active && available.contains($0) }
    }
}

/// Source-compatible name for the old enum; every call site keeps compiling against the canonical ids.
typealias AIBackend = LLMBackendType

// MARK: - Endpoint validation

enum AIEndpointPolicy {
    /// A URL is usable for a local/LAN backend when it is http(s) with a host.
    static func isValidServerURL(_ string: String) -> Bool {
        guard let url = URL(string: string.trimmingCharacters(in: .whitespaces)),
              let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
              let host = url.host, !host.isEmpty else { return false }
        return true
    }

    /// A key may only travel over https. Anything else is refused before a request is built.
    static func mayCarryKey(_ url: URL?) -> Bool {
        guard let url, url.scheme?.lowercased() == "https", let host = url.host, !host.isEmpty else { return false }
        return true
    }

    /// Trim whitespace and a trailing slash so "http://host:11434/" and "http://host:11434" behave the same.
    static func normalized(_ string: String) -> String {
        var s = string.trimmingCharacters(in: .whitespacesAndNewlines)
        while s.hasSuffix("/") { s.removeLast() }
        return s
    }
}

// MARK: - Persisted endpoint settings (readable off the main actor)

/// URL settings live in UserDefaults (not secrets). They are read from both the main-actor manager and the
/// nonisolated brain transport, so they sit here rather than on `AIBackendManager`.
enum AIEndpointSettings {
    static let ollamaDefault = "http://localhost:11434"
    static let novaGatewayDefault = "http://127.0.0.1:18792"

    enum Keys {
        static let ollamaURL = "AIBackendManager_OllamaURL"
        static let novaGatewayURL = "AIBackendManager_NovaGatewayURL"
        static let aiEnabled = "AIBackendManager_AIEnabled"
    }

    /// Under XCTest every setting lives in a throwaway suite, never the real defaults (same rule as NovaCommentary).
    static var defaults: UserDefaults =
        AudioGate.underXCTest ? UserDefaults(suiteName: "GTNW.tests.ai.\(UUID().uuidString)")! : .standard

    static var ollamaURL: String {
        get { valid(defaults.string(forKey: Keys.ollamaURL)) ?? ollamaDefault }
        set { defaults.set(AIEndpointPolicy.normalized(newValue), forKey: Keys.ollamaURL) }
    }

    static var novaGatewayURL: String {
        get { valid(defaults.string(forKey: Keys.novaGatewayURL)) ?? novaGatewayDefault }
        set { defaults.set(AIEndpointPolicy.normalized(newValue), forKey: Keys.novaGatewayURL) }
    }

    /// The global "Use AI" switch. Off = no network AI anywhere; every feature uses its scripted fallback.
    static var aiEnabled: Bool {
        get { defaults.object(forKey: Keys.aiEnabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.aiEnabled) }
    }

    private static func valid(_ s: String?) -> String? {
        guard let s, AIEndpointPolicy.isValidServerURL(s) else { return nil }
        return AIEndpointPolicy.normalized(s)
    }
}
