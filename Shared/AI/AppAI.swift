//
//  AppAI.swift
//  Global Thermal Nuclear War
//
//  GTNW's one AI object, built on NovaAIKit (https://github.com/kochj23/NovaAIKit, 1.0.0+).
//
//  - Toggle, backends (auto, ollama, mlx, tinyllm, tinychat, openwebui, novagateway, openrouter, openai), Auto
//    failover, retries, timeouts, https-only keys and the status come from the kit.
//  - Keys live only in the Keychain: com.jkoch.gtnw.openrouter / com.jkoch.gtnw.openai (account apiKey) — the same
//    items GTNW 3.23 wrote, so existing keys keep working.
//  - GTNW keeps its own parts: the prompts, `AIOutputSanitizer` as the text validator, `MoveResponse` validation and
//    the rule-based brains / template commentary as the fallback (AIBrain.swift, NovaCommentary.swift).
//  - Settings persist in UserDefaults (`NovaAIKit.settings`, no secrets). The pre-3.24 `AIBackendManager_*` settings
//    are imported once and then removed.
//
//  Created by Jordan Koch on 2026.
//

import Foundation
import NovaAIKit

@MainActor
enum AppAI {
    nonisolated static let appID = "gtnw"
    nonisolated static let appName = "GTNW"

    /// GTNW's defaults on a fresh install: 30 s per request and three attempts per backend (as before 3.24), and the
    /// Nova Gateway "chat" agent for Gateway-Claude.
    nonisolated static var configuration: NovaAIConfiguration {
        var defaults = NovaAISettings()
        defaults.timeout = 30
        defaults.setModel("chat", for: .novaGateway)
        return NovaAIConfiguration(appID: appID, appName: appName, appURL: "https://github.com/kochj23/GTNW",
                                   defaultSettings: defaults, retry: NovaAIRetryPolicy(maxAttempts: 3))
    }

    /// The shared instance. Under XCTest it is hermetic: settings and keys in memory, and every request refused
    /// before it leaves the process (tests that need answers build their own `NovaAI` / `NovaAIEngine`).
    static var shared: NovaAI = makeShared()

    static func makeShared() -> NovaAI {
        if AudioGate.underXCTest {
            let cfg = URLSessionConfiguration.ephemeral
            cfg.protocolClasses = [OfflineURLProtocol.self]
            return NovaAI(configuration: configuration, storage: NovaAIMemoryStorage(), keyStore: NovaAIMemoryKeyStore(),
                          session: URLSession(configuration: cfg))
        }
        let ai = NovaAI(configuration: configuration)
        migrateLegacySettings(ai)
        // Keychain work stays off the main thread: an access prompt (after an ad hoc rebuild) must never block launch.
        if !CommandLine.arguments.contains("--launch-smoke") {
            let keys = ai.keys
            Task.detached(priority: .utility) { migrateLegacyKeys(keys) }
        }
        return ai
    }
}

// MARK: - One-time migration from GTNW's own AIBackendManager (3.23 and earlier)

extension AppAI {
    /// Pre-3.24 Keychain item for the OpenAI key (GTNW's alone, so it is deleted after a verified copy).
    nonisolated static let legacyKeychainService = "com.jordankoch.GTNW"
    nonisolated static let legacyOpenAIAccount = "AIBackendManager_OpenAI_Key"

    /// GTNW-specific URL settings the kit's generic migration doesn't know.
    nonisolated static let legacyURLKeys: [String: NovaAIBackend] = [
        "AIBackendManager_TinyLLMServerURL": .tinyLLM, "AIBackendManager_TinyChatServerURL": .tinyChat,
        "AIBackendManager_OpenWebUIServerURL": .openWebUI, "AIBackendManager_NovaGatewayURL": .novaGateway,
    ]
    nonisolated static let legacyModelKeys: [String: NovaAIBackend] = [
        "AIBackendManager_NovaGatewayModel": .novaGateway, "AIBackendManager_OpenRouterModel": .openRouter,
        "AIBackendManager_OpenAIModel": .openAI,
    ]
    /// Every UserDefaults key the old manager wrote; all are gone after the migration (no second copy).
    nonisolated static let legacyDefaultsKeys: [String] = [
        "AIBackendManager_SelectedBackend", "AIBackendManager_OllamaModel", "AIBackendManager_OllamaURL",
        "AIBackendManager_AIEnabled", "AIBackendManager_PythonPath", "AIBackendManager_MLXModel",
        "AIBackendManager_MLXScriptPath", "AIBackendManager_GoogleCloud_Key", "AIBackendManager_Azure_Key",
        "AIBackendManager_Azure_Endpoint", "AIBackendManager_AWS_AccessKey", "AIBackendManager_AWS_SecretKey",
        "AIBackendManager_AWS_Region", "AIBackendManager_IBM_Key", "AIBackendManager_IBM_URL",
    ] + Array(legacyURLKeys.keys) + Array(legacyModelKeys.keys)
    nonisolated static let migratedMarker = "GTNW.NovaAIKit.legacyMigrated"

    /// Import the old settings once (kit keys + GTNW's extra URLs/models), move a plaintext OpenAI key to the
    /// Keychain, delete the removed backends' secrets, then remove the old keys. Idempotent.
    @discardableResult
    static func migrateLegacySettings(_ ai: NovaAI, defaults: UserDefaults = .standard) -> NovaAI.LegacyMigrationReport {
        var report = ai.migrateFromLegacyAIBackendManager(defaults: defaults)
        // GTNW kept a plaintext OpenAI key here before 3.23 (3.23 already removed it on load; belt and braces).
        if defaults.object(forKey: "AIBackendManager_OpenAI_Key") != nil {
            report.keys["AIBackendManager_OpenAI_Key"] = ai.migrateLegacyDefaultsKey("AIBackendManager_OpenAI_Key",
                                                                                     defaults: defaults, to: .openAI)
        }
        guard !defaults.bool(forKey: migratedMarker) else { return report }
        defaults.set(true, forKey: migratedMarker)
        var s = ai.settings
        for (key, backend) in legacyURLKeys {
            if let v = defaults.string(forKey: key), Self.isServerURL(v) { s.setURL(v, for: backend) }
        }
        for (key, backend) in legacyModelKeys {
            if let v = defaults.string(forKey: key), !v.isEmpty { s.setModel(v, for: backend) }
        }
        if s != ai.settings { ai.settings = s }
        for key in legacyDefaultsKeys where defaults.object(forKey: key) != nil {
            defaults.removeObject(forKey: key)
            report.removedKeys.append(key)
        }
        return report
    }

    /// Keychain half of the migration (runs off the main thread). Reads the old item only when it exists.
    nonisolated static func migrateLegacyKeys(_ keys: NovaAIKeys) {
        if keys.store.read(service: legacyKeychainService, account: legacyOpenAIAccount) != nil {
            _ = keys.migrateLegacyKey(service: legacyKeychainService, account: legacyOpenAIAccount, to: .openAI, deleteLegacy: true)
        }
        keys.deleteObsoleteLegacyItems(service: legacyKeychainService)
    }

    nonisolated static func isServerURL(_ s: String) -> Bool {
        guard let u = URL(string: s.trimmingCharacters(in: .whitespaces)), let scheme = u.scheme?.lowercased(),
              scheme == "http" || scheme == "https", let host = u.host, !host.isEmpty else { return false }
        return true
    }
}

// MARK: - Feature-facing text calls

/// What GTNW's side features (war room, narrative, news, intel, voices, crises, Nova's commentary) call. Every reply
/// passes `AIOutputSanitizer` (feature 8); a rejected reply is re-asked once, then the caller's fallback runs.
struct GameAI: Sendable {
    static let shared = GameAI()

    /// The backend that answered or probed last; nil = AI off or nothing reachable → the caller's built-in path.
    @MainActor var activeBackend: NovaAIBackend? { AppAI.shared.isEnabled ? AppAI.shared.status.activeBackend : nil }

    /// The text validator: sanitised text, or a rejection with the reason.
    static let validateText: @Sendable (String) throws -> String = { raw in
        guard let clean = AIOutputSanitizer.clean(raw) else { throw NovaAIValidationError("no usable text") }
        return clean
    }

    /// Never throws: AI (sanitised) or `fallback()`.
    @MainActor
    func text(prompt: String, systemPrompt: String? = nil, temperature: Double = 0.7, maxTokens: Int = 2048,
              ai: NovaAI? = nil, fallback: @escaping @Sendable () -> String) async -> NovaAIResult<String> {
        await (ai ?? AppAI.shared).text(NovaAIRequest(prompt: prompt, system: systemPrompt, temperature: temperature,
                                                      maxTokens: maxTokens),
                                       validate: Self.validateText, fallback: fallback)
    }

    /// Throwing form for features that keep their own `catch` fallback. Throws when AI is off, nothing answered, or
    /// the reply was rejected twice.
    @MainActor
    func generate(prompt: String, systemPrompt: String? = nil, temperature: Double = 0.7, maxTokens: Int = 2048,
                  ai: NovaAI? = nil) async throws -> String {
        let r = await text(prompt: prompt, systemPrompt: systemPrompt, temperature: temperature, maxTokens: maxTokens,
                           ai: ai, fallback: { "" })
        guard r.isAI else { throw GameAIError.unavailable(r.source.label) }
        return r.value
    }
}

enum GameAIError: LocalizedError, Equatable {
    case unavailable(String)
    var errorDescription: String? {
        switch self {
        case .unavailable(let why): return "No AI answer (\(why)). The game uses its built-in logic."
        }
    }
}

// MARK: - Test hermeticity

/// Installed only on the shared instance under XCTest: refuses every request so no test can reach a real server.
final class OfflineURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() { client?.urlProtocol(self, didFailWithError: URLError(.cannotConnectToHost)) }
    override func stopLoading() {}
}
