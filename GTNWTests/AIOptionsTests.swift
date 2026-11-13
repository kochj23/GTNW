//
//  AIOptionsTests.swift
//  GTNWTests
//
//  GTNW's AI options on NovaAIKit (3.24): global switch, canonical backend ids + legacy migration, Auto order and
//  failover, editable endpoints, Keychain-only keys (OpenRouter brains send theirs, over https only), output
//  sanitising, status and settings UI. One XCTestCase per category: Unit, Security, Retry, Performance,
//  Integration, Functional, Frame. No real network, no real Keychain, no real defaults.
//
//  Created by Jordan Koch on 2026.
//

import XCTest
import SwiftUI
import NovaAIKit
@testable import GTNW

// MARK: - Shared helpers

/// Records every request a transport sees (thread-safe).
final class RequestRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var _requests: [URLRequest] = []
    var requests: [URLRequest] { lock.withLock { _requests } }
    func record(_ r: URLRequest) { lock.withLock { _requests.append(r) } }

    /// Transport that records and then answers every request with `status` + `body`.
    func transport(status: Int = 200, body: String) -> HTTPTransport {
        { [self] request in
            record(request)
            return (Data(body.utf8), Stub.response(status, url: request.url))
        }
    }
}

enum AIFixtures {
    static func chat(_ json: String) -> String {
        let escaped = json.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        return #"{"choices":[{"message":{"content":""# + escaped + #""}}]}"#
    }
    static let declareWarOnUSA = chat(#"{"action":"DECLARE_WAR","target":"USA","rationale":"test"}"#)
    static let openRouterBrain = AIBrain.model(id: "anthropic/claude-sonnet-4.5",
                                               endpoint: "https://openrouter.ai/api/v1/chat/completions",
                                               backend: .openRouter)

    static var request: MoveRequest {
        MoveRequest(gameId: "g", countryId: "RUS", turn: 1, year: 1962, defcon: 3,
                    worldStateSummary: "world", legalActions: ["WAIT", "DECLARE_WAR"])
    }

    /// The shared (hermetic, in-memory) AI back to a fresh state: on, Auto, no keys.
    @MainActor
    static func resetShared() {
        AppAI.shared = AppAI.makeShared()
    }

    static var repoRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    static func source(_ relative: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(relative), encoding: .utf8)
    }

    static func config(_ engine: NovaAIEngine) -> BrainConfig {
        var c = BrainConfig()
        c.engine = engine
        c.modelTimeout = 5
        c.gatewayTimeout = 5
        return c
    }
}

// MARK: - Unit

final class AIOptionsUnitTests: XCTestCase {

    func testCanonicalBackendIds() {
        XCTAssertEqual(NovaAIBackend.allCases.map(\.rawValue),
                       ["auto", "ollama", "mlx", "tinyllm", "tinychat", "openwebui", "novagateway", "openrouter", "openai",
                        "anthropic", "gemini", "xai", "mistral", "deepseek", "meta"])   // NovaAIKit 1.1.0
        XCTAssertEqual(NovaAIBackend.autoOrder,
                       [.ollama, .mlx, .tinyChat, .tinyLLM, .openWebUI, .novaGateway, .openRouter, .openAI,
                        .anthropic, .gemini, .xAI, .mistral, .deepSeek, .meta])
        XCTAssertFalse(NovaAIBackend.autoOrder.contains(.auto))
        XCTAssertTrue(NovaAIBackend.selectable.contains(.mlx), "MLX is offered on macOS")
        XCTAssertEqual(NovaAIBackend.allCases.count, 15)
    }

    func testOldDisplayNameSelectionsMigrate() {
        XCTAssertEqual(NovaAIBackend(legacyName: "Ollama"), .ollama)
        XCTAssertEqual(NovaAIBackend(legacyName: "MLX Toolkit"), .mlx)
        XCTAssertEqual(NovaAIBackend(legacyName: "TinyLLM"), .tinyLLM)
        XCTAssertEqual(NovaAIBackend(legacyName: "TinyChat"), .tinyChat)
        XCTAssertEqual(NovaAIBackend(legacyName: "OpenWebUI"), .openWebUI)
        XCTAssertEqual(NovaAIBackend(legacyName: "OpenAI"), .openAI)
        XCTAssertEqual(NovaAIBackend(legacyName: "Auto (Prefer Ollama)"), .auto)
        XCTAssertEqual(NovaAIBackend(legacyName: "Auto (Prefer Local)"), .auto)
        for removed in ["Google Cloud AI", "Microsoft Azure", "AWS AI Services", "IBM Watson"] {
            XCTAssertEqual(NovaAIBackend(legacyName: removed), .auto, removed)
        }
        XCTAssertEqual(NovaAIBackend(legacyName: "openrouter"), .openRouter)
        XCTAssertNil(NovaAIBackend(legacyName: "garbage"))
    }

    func testAutoTriesBackendsInFixedOrder() {
        let auto = KitTest.engine()
        XCTAssertEqual(auto.chain(), NovaAIBackend.autoOrder)
        XCTAssertEqual(auto.candidates().map(\.backend), [.ollama, .mlx, .tinyChat, .tinyLLM, .openWebUI, .novaGateway],
                       "keyed clouds join only with a key")
        let keyed = KitTest.engine(keys: [.openRouter: "sk-or-x"])
        XCTAssertEqual(keyed.candidates().last?.backend, .openRouter)
    }

    func testExplicitChoiceNeverSwitchesProvider() {
        let e = KitTest.engine(settings: KitTest.settings { $0.backend = .novaGateway })
        XCTAssertEqual(e.chain(), [.novaGateway])
        XCTAssertEqual(e.candidates().map(\.backend), [.novaGateway])
    }

    func testSanitizerCleansModelOutput() {
        XCTAssertEqual(AIOutputSanitizer.clean("<think>plan the war</think>  DEFCON 3. "), "DEFCON 3.")
        XCTAssertEqual(AIOutputSanitizer.clean("Moscow\u{07}\u{1B}[31m blinks"), "Moscow[31m blinks")
        XCTAssertNil(AIOutputSanitizer.clean("   \n "))
        XCTAssertNil(AIOutputSanitizer.clean("<think>never finished"))
        XCTAssertNil(AIOutputSanitizer.clean("!!! ... ???"))
        XCTAssertEqual(AIOutputSanitizer.clean(String(repeating: "a", count: 10_000))?.count, AIOutputSanitizer.maxCharacters)
        XCTAssertEqual(AIOutputSanitizer.clean("line one\nline two"), "line one\nline two")
    }

    func testBrainEndpointsMapToKitBackends() {
        XCTAssertEqual(BrainRoute.baseURL(" http://h:11434/v1/chat/completions/ "), "http://h:11434")
        XCTAssertEqual(BrainRoute.baseURL("https://openrouter.ai/api/v1/chat/completions", for: .openRouter), "https://openrouter.ai/api/v1")
        XCTAssertEqual(BrainRoute.baseURL("http://h:11434/api/chat", for: .ollama), "http://h:11434")
        XCTAssertEqual(BrainRoute.baseURL("http://h:1///"), "http://h:1")
        XCTAssertEqual(BrainRoute.target(for: AIFixtures.openRouterBrain, gatewayBaseURL: "", gatewayModel: "chat"),
                       BrainTarget(backend: .openRouter, baseURL: "https://openrouter.ai/api/v1", model: "anthropic/claude-sonnet-4.5"))
        XCTAssertEqual(BrainRoute.target(for: .model(id: "qwen3:4b", endpoint: "http://nova-core8:11434/v1/chat/completions",
                                                     backend: .ollama), gatewayBaseURL: "", gatewayModel: "chat")?.backend, .ollama)
        XCTAssertEqual(BrainRoute.target(for: .model(id: "m", endpoint: "http://x:9/v1/chat/completions", backend: .openAICompatible),
                                         gatewayBaseURL: "", gatewayModel: "chat")?.backend, .novaGateway)
        XCTAssertEqual(BrainRoute.target(for: .gatewayClaude, gatewayBaseURL: "http://g:18792/", gatewayModel: "chat"),
                       BrainTarget(backend: .novaGateway, baseURL: "http://g:18792", model: "chat"))
        for local in [AIBrain.human, .ruleBased, .liveSession] {
            XCTAssertNil(BrainRoute.target(for: local, gatewayBaseURL: "", gatewayModel: "chat"), "\(local)")
        }
    }

    func testURLPolicyForLegacyImport() {
        XCTAssertTrue(AppAI.isServerURL("http://nova-core8:11434"))
        XCTAssertTrue(AppAI.isServerURL("https://openrouter.ai/api/v1"))
        XCTAssertFalse(AppAI.isServerURL("file:///etc/passwd"))
        XCTAssertFalse(AppAI.isServerURL("localhost:11434"))
        XCTAssertFalse(AppAI.isServerURL(""))
    }

    @MainActor
    func testStatusText() {
        let off = KitTest.ai(KitTest.settings { $0.enabled = false })
        XCTAssertEqual(off.status.label, "AI off · built-in answers")
        XCTAssertEqual(KitTest.ai().status.label, "AI not checked yet")
    }

    func testOnlyCloudBackendsNeedKeys() {
        XCTAssertEqual(Set(NovaAIBackend.allCases.filter(\.requiresKey)), [.openRouter, .openAI, .anthropic, .gemini, .xAI, .mistral, .deepSeek, .meta])
    }

    func testGTNWConfiguration() {
        let c = AppAI.configuration
        XCTAssertEqual(c.appID, "gtnw")
        XCTAssertEqual(c.retry.maxAttempts, 3, "three attempts per backend, as before 3.24")
        XCTAssertEqual(c.defaultSettings.timeout, 30)
        XCTAssertEqual(c.defaultSettings.model(for: .novaGateway), "chat")
        XCTAssertEqual(c.defaultSettings.backend, .auto)
        XCTAssertTrue(c.defaultSettings.enabled)
    }
}

// MARK: - Security

final class AIOptionsSecurityTests: XCTestCase {

    @MainActor override func setUp() async throws { AIFixtures.resetShared() }
    @MainActor override func tearDown() async throws { AIFixtures.resetShared() }

    private func config(_ rec: RequestRecorder, key: String?) -> BrainConfig {
        AIFixtures.config(KitTest.engine(transport: rec.transport(body: AIFixtures.chat(#"{"action":"WAIT"}"#)),
                                         keys: key.map { [.openRouter: $0] } ?? [:]))
    }

    /// The 3.22 bug: OpenRouter brains posted the world state with no key, got a 401 every turn.
    func testOpenRouterBrainCarriesBearerKey() async throws {
        let rec = RequestRecorder()
        let resp = await BrainClient.requestMove(AIFixtures.request, brain: AIFixtures.openRouterBrain,
                                                 config: config(rec, key: "sk-or-test-123"))
        XCTAssertEqual(resp?.action, "WAIT")
        let req = try XCTUnwrap(rec.requests.first)
        XCTAssertEqual(req.value(forHTTPHeaderField: "Authorization"), "Bearer sk-or-test-123")
        XCTAssertEqual(req.value(forHTTPHeaderField: "X-Title"), "GTNW")
        XCTAssertEqual(req.url?.scheme, "https")
        XCTAssertEqual(req.url?.absoluteString, "https://openrouter.ai/api/v1/chat/completions")
    }

    func testOpenRouterBrainWithoutKeySendsNothing() async {
        let rec = RequestRecorder()
        let resp = await BrainClient.requestMove(AIFixtures.request, brain: AIFixtures.openRouterBrain,
                                                 config: config(rec, key: nil))
        XCTAssertNil(resp)
        XCTAssertTrue(rec.requests.isEmpty, "no key = the world state never leaves the Mac")
    }

    func testOpenRouterKeyIsNeverSentOverHTTP() async throws {
        let rec = RequestRecorder()
        let downgraded = AIBrain.model(id: "x", endpoint: "http://openrouter.ai/api/v1/chat/completions", backend: .openRouter)
        let resp = await BrainClient.requestMove(AIFixtures.request, brain: downgraded, config: config(rec, key: "sk-or-test"))
        XCTAssertNil(resp)
        XCTAssertTrue(rec.requests.isEmpty)
        // The kit refuses to build the request at all.
        var s = KitTest.settings { $0.backend = .openAI }
        s.setURL("http://api.example.com/v1", for: .openAI)
        let e = KitTest.engine(keys: [.openAI: "k"], settings: s)
        let c = try XCTUnwrap(e.candidates().first)
        XCTAssertThrowsError(try e.chatRequest(c, NovaAIRequest(prompt: "x"), stream: false))
    }

    func testLocalAndGatewayBrainsSendNoAuthorization() async throws {
        for brain in [AIBrain.gatewayClaude,
                      .model(id: "qwen3:4b", endpoint: "http://127.0.0.1:1/v1/chat/completions", backend: .ollama)] {
            let rec = RequestRecorder()
            _ = await BrainClient.requestMove(AIFixtures.request, brain: brain, config: config(rec, key: "sk-or-secret"))
            let req = try XCTUnwrap(rec.requests.first, "\(brain)")
            XCTAssertNil(req.value(forHTTPHeaderField: "Authorization"), "the OpenRouter key leaked to \(brain)")
            XCTAssertFalse(String(data: req.httpBody ?? Data(), encoding: .utf8)!.contains("sk-or-secret"))
        }
    }

    /// Keys round-trip through the key store under GTNW's own services (in memory here; the Keychain in the app).
    func testKeyRoundTripUsesGTNWServices() {
        let store = NovaAIMemoryKeyStore()
        let keys = NovaAIKeys(configuration: AppAI.configuration, store: store)
        XCTAssertFalse(keys.hasKey(for: .openRouter))
        XCTAssertTrue(keys.setKey("  sk-or-abc  ", for: .openRouter))
        XCTAssertEqual(keys.key(for: .openRouter), "sk-or-abc", "trimmed")
        XCTAssertEqual(store.read(service: "com.jkoch.gtnw.openrouter", account: "apiKey"), "sk-or-abc")
        XCTAssertTrue(keys.setKey("sk-or-def", for: .openRouter), "replace in place")
        XCTAssertEqual(keys.key(for: .openRouter), "sk-or-def")
        XCTAssertTrue(keys.setKey("", for: .openRouter), "empty deletes instead of storing \"\"")
        XCTAssertNil(keys.key(for: .openRouter))
        XCTAssertEqual(store.count, 0)
    }

    func testLegacyOpenAIKeyMigratesOnce() {
        let store = NovaAIMemoryKeyStore()
        XCTAssertTrue(store.write("sk-legacy", service: AppAI.legacyKeychainService, account: AppAI.legacyOpenAIAccount))
        let keys = NovaAIKeys(configuration: AppAI.configuration, store: store)
        AppAI.migrateLegacyKeys(keys)
        XCTAssertEqual(keys.key(for: .openAI), "sk-legacy")
        XCTAssertNil(store.read(service: AppAI.legacyKeychainService, account: AppAI.legacyOpenAIAccount),
                     "old item removed after the verified copy")
        AppAI.migrateLegacyKeys(keys)   // idempotent
        XCTAssertEqual(keys.key(for: .openAI), "sk-legacy")
    }

    func testExistingGTNWKeychainItemsNeedNoMigration() {
        // 3.23 wrote com.jkoch.gtnw.openrouter/openai with account apiKey — exactly the kit's names.
        let store = NovaAIMemoryKeyStore()
        _ = store.write("sk-or-323", service: "com.jkoch.gtnw.openrouter", account: "apiKey")
        _ = store.write("sk-oa-323", service: "com.jkoch.gtnw.openai", account: "apiKey")
        let keys = NovaAIKeys(configuration: AppAI.configuration, store: store)
        AppAI.migrateLegacyKeys(keys)
        XCTAssertEqual(keys.key(for: .openRouter), "sk-or-323")
        XCTAssertEqual(keys.key(for: .openAI), "sk-oa-323")
    }

    @MainActor
    func testPlaintextLegacyKeyLeavesUserDefaults() {
        let (d, name) = KitTest.defaultsSuite()
        defer { UserDefaults().removePersistentDomain(forName: name) }
        d.set("sk-plain-322", forKey: "AIBackendManager_OpenAI_Key")
        d.set("sk-plain-old", forKey: "AIBackend_OpenAI_Key")
        d.set("goog", forKey: "AIBackendManager_GoogleCloud_Key")
        let store = NovaAIMemoryKeyStore()
        let ai = KitTest.ai(store: store)
        AppAI.migrateLegacySettings(ai, defaults: d)
        XCTAssertTrue(ai.hasAPIKey(for: .openAI))
        XCTAssertNil(d.object(forKey: "AIBackendManager_OpenAI_Key"))
        XCTAssertNil(d.object(forKey: "AIBackend_OpenAI_Key"))
        XCTAssertNil(d.object(forKey: "AIBackendManager_GoogleCloud_Key"), "removed backends' secrets are deleted")
    }

    @MainActor
    func testKeysNeverLandInUserDefaults() {
        let (d, name) = KitTest.defaultsSuite()
        defer { UserDefaults().removePersistentDomain(forName: name) }
        let ai = NovaAI(configuration: AppAI.configuration, storage: NovaAIUserDefaultsStorage(suiteName: name),
                        keyStore: NovaAIMemoryKeyStore(), session: TransportURLProtocol.session(TransportURLProtocol.refuse))
        XCTAssertTrue(ai.setAPIKey("sk-or-defaults-probe", for: .openRouter))
        ai.settings.backend = .openRouter          // forces a settings save
        XCTAssertTrue(ai.hasAPIKey(for: .openRouter))
        let dump = d.dictionaryRepresentation().values.map { "\($0)" }.joined()
        XCTAssertFalse(dump.contains("sk-or-defaults-probe"))
        XCTAssertFalse(String(describing: ai.settings).contains("sk-or-defaults-probe"))
    }

    func testSourceHasNoRemovedOrUnsafeBackends() throws {
        let appAI = try AIFixtures.source("Shared/AI/AppAI.swift")
        XCTAssertTrue(appAI.contains("appID = \"gtnw\""), "GTNW's own Keychain services (com.jkoch.gtnw.*)")
        XCTAssertFalse(appAI.contains("aistudio"), "never another app's Keychain service")
        let e = FileManager.default.enumerator(at: AIFixtures.repoRoot.appendingPathComponent("Shared"), includingPropertiesForKeys: nil)
        while let url = e?.nextObject() as? URL {
            guard url.pathExtension == "swift" else { continue }
            let text = try String(contentsOf: url, encoding: .utf8)
            for gone in ["YOUR_PROJECT_ID", "googleCloud", "azureCognitive", "awsAI", "ibmWatson", "OPENAI_API_KEY", "OPENROUTER_API_KEY"] {
                XCTAssertFalse(text.contains(gone), "\(gone) in \(url.lastPathComponent)")
            }
        }
    }

    @MainActor
    func testAIOffSendsNothing() async {
        let rec = RequestRecorder()
        let ai = KitTest.ai(KitTest.settings { $0.enabled = false }, transport: rec.transport(body: KitTest.ollama("hi")))
        do { _ = try await GameAI.shared.generate(prompt: "x", ai: ai); XCTFail("must throw") } catch {
            XCTAssertTrue(error is GameAIError)
        }
        let line = await NovaCommentary.liveLine("x", system: "s", temperature: 0.5, maxTokens: 10, ai: ai)
        XCTAssertNil(line)
        XCTAssertTrue(rec.requests.isEmpty)
    }
}

// MARK: - Retry

final class AIOptionsRetryTests: XCTestCase {

    @MainActor override func setUp() async throws { AIFixtures.resetShared() }
    @MainActor override func tearDown() async throws { AIFixtures.resetShared() }

    /// Auto: Ollama keeps failing (503) → bounded retries (3), then the next reachable backend answers.
    @MainActor
    func testAutoFailsOverToNextReachableBackend() async throws {
        let ollama = RetryProbe(), gateway = RetryProbe(), sleeps = RetryProbe()
        let ai = KitTest.ai(transport: { request in
            if request.url?.port == 11434 {
                ollama.hit()
                return (Data(), Stub.response(503, url: request.url))
            }
            if request.url?.port == 18792 {
                gateway.hit()
                return (Data(AIFixtures.chat("Nova here").utf8), Stub.response(200, url: request.url))
            }
            throw URLError(.cannotConnectToHost)
        }, sleep: sleeps.sleeper)
        let text = try await GameAI.shared.generate(prompt: "status?", ai: ai)
        XCTAssertEqual(text, "Nova here")
        XCTAssertEqual(ollama.calls, 3)
        XCTAssertEqual(gateway.calls, 1)
        XCTAssertEqual(sleeps.sleeps, [0.5, 1.0], "backoff only inside a backend, not between backends")
        XCTAssertEqual(ai.status.activeBackend, .novaGateway)
    }

    @MainActor
    func testExplicitBackendDoesNotSwitchProvider() async {
        let probe = RetryProbe()
        let ai = KitTest.ai(KitTest.settings { $0.backend = .ollama },
                            transport: Stub.transport(probe, script: [(500, "")]), sleep: probe.sleeper)
        do { _ = try await GameAI.shared.generate(prompt: "x", ai: ai); XCTFail("must throw") } catch {}
        XCTAssertEqual(probe.calls, 3, "three attempts at Ollama, never a hop to another provider")
    }

    @MainActor
    func testMissingKeyFailsFastWithoutRetryOrNetwork() async {
        let probe = RetryProbe()
        let ai = KitTest.ai(KitTest.settings { $0.backend = .openRouter },
                            transport: Stub.transport(probe, script: [(200, "")]), sleep: probe.sleeper)
        do { _ = try await ai.complete(NovaAIRequest(prompt: "x")); XCTFail("must throw") } catch {
            XCTAssertEqual(error as? NovaAIError, .missingKey(.openRouter))
        }
        XCTAssertEqual(probe.calls, 0)
        XCTAssertTrue(probe.sleeps.isEmpty)
    }

    func testOpenRouterBrainRetriesRateLimit() async {
        let probe = RetryProbe()
        let c = AIFixtures.config(KitTest.engine(
            transport: Stub.transport(probe, script: [(429, ""), (429, ""), (200, AIFixtures.chat(#"{"action":"WAIT"}"#))]),
            keys: [.openRouter: "sk-or-test"], sleep: probe.sleeper))
        let resp = await BrainClient.requestMove(AIFixtures.request, brain: AIFixtures.openRouterBrain, config: c)
        XCTAssertEqual(resp?.action, "WAIT")
        XCTAssertEqual(probe.calls, 3)
    }

    func testOpenRouterUnauthorizedIsNotRetried() async {
        let probe = RetryProbe()
        let c = AIFixtures.config(KitTest.engine(transport: Stub.transport(probe, script: [(401, "")]),
                                                 keys: [.openRouter: "sk-or-wrong"], sleep: probe.sleeper))
        let resp = await BrainClient.requestMove(AIFixtures.request, brain: AIFixtures.openRouterBrain, config: c)
        XCTAssertNil(resp)
        XCTAssertEqual(probe.calls, 1, "a bad key can't be fixed by retrying")
    }

    func testErrorsAreClassified() {
        XCTAssertFalse(NovaAIRetry.isRetryable(NovaAIError.missingKey(.openRouter)))
        XCTAssertFalse(NovaAIRetry.isRetryable(NovaAIError.emptyResponse))
        XCTAssertFalse(NovaAIRetry.isRetryable(NovaAIError.httpStatus(401)))
        XCTAssertTrue(NovaAIRetry.isRetryable(NovaAIError.httpStatus(429)))
        XCTAssertTrue(NovaAIRetry.isRetryable(NovaAIError.httpStatus(503)))
        XCTAssertFalse(NovaAIRetry.isRetryable(URLError(.cannotConnectToHost)), "refused: fail over at once")
    }

    /// A rejected (junk) reply is re-asked once with the reason; a good second reply is used.
    @MainActor
    func testRejectedReplyIsReaskedOnce() async throws {
        let probe = RetryProbe()
        let ai = KitTest.ai(KitTest.settings { $0.backend = .ollama },
                            transport: Stub.transport(probe, script: [(200, KitTest.ollama("!!! ???")), (200, KitTest.ollama("Moscow blinks."))]))
        let text = try await GameAI.shared.generate(prompt: "x", ai: ai)
        XCTAssertEqual(text, "Moscow blinks.")
        XCTAssertEqual(probe.calls, 2)
    }
}

// MARK: - Performance

final class AIOptionsPerformanceTests: XCTestCase {

    @MainActor override func setUp() async throws { AIFixtures.resetShared() }
    @MainActor override func tearDown() async throws { AIFixtures.resetShared() }

    /// AI off: thirty countries on remote brains resolve locally — no calls, well under a second.
    @MainActor
    func testAIOffTurnMakesNoBrainCalls() async throws {
        let e = GameEngine()
        e.startNewGame(playerCountryID: "USA")
        let ids = try XCTUnwrap(e.gameState).countries.filter { !$0.isPlayerControlled && !$0.isDestroyed }.prefix(30).map(\.id)
        for id in ids { e.setBrain(.gatewayClaude, for: id) }
        let calls = RetryProbe()
        e.brainTransportOverride = { _, _ in calls.hit(); return MoveResponse(action: "WAIT") }
        AppAI.shared.isEnabled = false
        let start = Date()
        await e.processAITurnsWithBrains()
        XCTAssertLessThan(Date().timeIntervalSince(start), 1.0)
        XCTAssertEqual(calls.calls, 0)
    }

    func testSanitizerIsCheap() {
        let blob = "<think>" + String(repeating: "x", count: 2000) + "</think>" + String(repeating: "Moscow blinks. ", count: 300)
        let start = Date()
        for _ in 0..<500 { _ = AIOutputSanitizer.clean(blob) }
        XCTAssertLessThan(Date().timeIntervalSince(start), 2.0)
    }

    /// Probes use the short probe timeout; generation uses the settings timeout (nothing waits on URLSession's 60 s).
    @MainActor
    func testRequestsCarryBoundedTimeouts() async throws {
        let rec = RequestRecorder()
        let ai = KitTest.ai(KitTest.settings { $0.backend = .ollama; $0.timeout = 20 },
                            transport: rec.transport(body: #"{"models":[{"name":"llama3.2"}],"message":{"content":"ok"}}"#))
        await ai.refreshStatus()
        XCTAssertTrue(ai.status.isReachable)
        XCTAssertTrue(rec.requests.allSatisfy { $0.timeoutInterval == AppAI.configuration.probeTimeout })
        _ = try await GameAI.shared.generate(prompt: "x", ai: ai)
        XCTAssertEqual(rec.requests.last?.timeoutInterval, 20)
    }

    /// Offline (every server refuses): an AI feature returns its fallback quickly, no hang.
    @MainActor
    func testOfflineFallbackIsFast() async {
        let ai = KitTest.ai()
        let start = Date()
        let r = await GameAI.shared.text(prompt: "x", ai: ai, fallback: { "template" })
        XCTAssertEqual(r.value, "template")
        XCTAssertFalse(r.isAI)
        XCTAssertLessThan(Date().timeIntervalSince(start), 2.0)
    }
}

// MARK: - Integration

final class AIOptionsIntegrationTests: XCTestCase {

    @MainActor override func setUp() async throws { AIFixtures.resetShared() }
    @MainActor override func tearDown() async throws { AIFixtures.resetShared() }

    @MainActor
    private func engine(_ transport: @escaping HTTPTransport, key: String?) -> GameEngine {
        let e = GameEngine()
        e.startNewGame(playerCountryID: "USA")
        e.useKitTransport(transport, keys: key.map { [.openRouter: $0] } ?? [:])
        e.brainConfig.modelTimeout = 5
        return e
    }

    /// Engine → OpenRouter brain (with key) → kit → HTTP → move → game state.
    @MainActor
    func testOpenRouterBrainMoveReachesGameState() async throws {
        let rec = RequestRecorder()
        let e = engine(rec.transport(body: AIFixtures.declareWarOnUSA), key: "sk-or-int")
        e.setBrain(AIFixtures.openRouterBrain, for: "RUS")
        await e.processAITurnsWithBrains()
        XCTAssertTrue(try XCTUnwrap(e.gameState?.getCountry(id: "RUS")).atWarWith.contains("USA"))
        XCTAssertFalse(e.lastTurnFallbackCountryIDs.contains("RUS"))
        XCTAssertEqual(rec.requests.first?.value(forHTTPHeaderField: "Authorization"), "Bearer sk-or-int")
    }

    @MainActor
    func testOpenRouterBrainWithoutKeyPlaysRuleBasedOffline() async {
        let rec = RequestRecorder()
        let e = engine(rec.transport(body: AIFixtures.declareWarOnUSA), key: nil)
        e.setBrain(AIFixtures.openRouterBrain, for: "RUS")
        await e.processAITurnsWithBrains()
        XCTAssertTrue(e.lastTurnFallbackCountryIDs.contains("RUS"))
        XCTAssertTrue(rec.requests.isEmpty)
    }

    /// Shared AI → Ollama (stub) → sanitiser → caller.
    @MainActor
    func testOutputIsSanitised() async throws {
        let ai = KitTest.ai(KitTest.settings { $0.backend = .ollama },
                            transport: RequestRecorder().transport(body: KitTest.ollama("<think>hmm</think> Moscow blinks.\u{07}")))
        let text = try await GameAI.shared.generate(prompt: "x", ai: ai)
        XCTAssertEqual(text, "Moscow blinks.")
    }

    @MainActor
    func testEmptyReplyFailsOverInAuto() async throws {
        let ai = KitTest.ai(transport: { request in
            if request.url?.port == 11434 { return (Data(KitTest.ollama("   ").utf8), Stub.response(200, url: request.url)) }
            if request.url?.port == 18792 { return (Data(AIFixtures.chat("Gateway line").utf8), Stub.response(200, url: request.url)) }
            throw URLError(.cannotConnectToHost)
        })
        let text = try await GameAI.shared.generate(prompt: "x", ai: ai)
        XCTAssertEqual(text, "Gateway line")
    }

    /// The Nova Gateway backend speaks the OpenAI-compatible route at the configured URL with the configured model.
    @MainActor
    func testNovaGatewayBackendUsesConfiguredURLAndModel() async throws {
        let rec = RequestRecorder()
        let ai = KitTest.ai(KitTest.settings { $0.backend = .novaGateway; $0.setURL("http://nova-gw.local:18792/", for: .novaGateway) },
                            transport: rec.transport(body: AIFixtures.chat("ok")))
        _ = try await GameAI.shared.generate(prompt: "x", ai: ai)
        let req = try XCTUnwrap(rec.requests.first)
        XCTAssertEqual(req.url?.absoluteString, "http://nova-gw.local:18792/v1/chat/completions")
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: req.httpBody ?? Data()) as? [String: Any])
        XCTAssertEqual(body["model"] as? String, "chat")
        XCTAssertNil(req.value(forHTTPHeaderField: "Authorization"))
    }

    /// Terminal advice: AI answer when one is reachable, the built-in read otherwise.
    @MainActor
    func testTerminalAdviceUsesAIThenFallsBack() async {
        let gs = GameState(playerCountryID: "USA")
        let online = TerminalAdvisor(ai: KitTest.ai(KitTest.settings { $0.backend = .ollama },
                                                    transport: RequestRecorder().transport(body: KitTest.ollama("HOLD AT DEFCON 3."))))
        let advice = await online.getStrategicAdvice(situation: "what should I do", gameState: gs)
        XCTAssertEqual(advice, "HOLD AT DEFCON 3.")
        XCTAssertEqual(online.lastSource?.isAI, true)
        let offline = TerminalAdvisor(ai: KitTest.ai())
        let fallback = await offline.getStrategicAdvice(situation: "what should I do", gameState: gs)
        XCTAssertEqual(fallback, TerminalAdvisor.builtInAdvice(gameState: gs))
        XCTAssertEqual(offline.lastSource?.isAI, false)
    }
}

// MARK: - Functional

final class AIOptionsFunctionalTests: XCTestCase {

    @MainActor override func setUp() async throws { AIFixtures.resetShared() }
    @MainActor override func tearDown() async throws { AIFixtures.resetShared() }

    /// Turning AI off from the menu/settings: the game still plays a full turn, every brain acts rule-based.
    @MainActor
    func testGameIsFullyPlayableWithAIOff() async throws {
        let probe = RetryProbe()
        let e = GameEngine()
        e.startNewGame(playerCountryID: "USA")
        e.useKitTransport(Stub.transport(probe, script: [(200, AIFixtures.declareWarOnUSA)]))
        e.setBrain(.gatewayClaude, for: "RUS")
        AppAI.shared.isEnabled = false
        XCTAssertFalse(AppAI.shared.settings.enabled, "the switch persists in the settings")
        let turn = e.gameState?.turn ?? 0
        e.endTurn()
        let deadline = Date().addingTimeInterval(10)
        while (e.turnPhase != .playerInput || e.isProcessingAITurn) && Date() < deadline {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTAssertEqual(e.gameState?.turn, turn + 1)
        XCTAssertEqual(e.turnPhase, .playerInput)
        XCTAssertEqual(probe.calls, 0, "AI off: no brain request")
    }

    @MainActor
    func testTurningAIBackOnRestoresActiveBackend() async {
        let ai = KitTest.ai(transport: { request in
            if request.url?.port == 11434 { return (Data(#"{"models":[{"name":"m1"}]}"#.utf8), Stub.response(200, url: request.url)) }
            throw URLError(.cannotConnectToHost)
        })
        await ai.refreshStatus()
        XCTAssertEqual(ai.status.activeBackend, .ollama)
        ai.isEnabled = false
        XCTAssertNil(ai.status.activeBackend)
        XCTAssertEqual(ai.status.state, .off)
        ai.isEnabled = true
        await ai.refreshStatus()
        XCTAssertEqual(ai.status.activeBackend, .ollama)
    }

    /// The Ollama URL is a real setting: it reaches generation and the brains' model list.
    @MainActor
    func testOllamaURLSettingFlowsEverywhere() async throws {
        let rec = RequestRecorder()
        let ai = KitTest.ai(KitTest.settings { $0.backend = .ollama; $0.setURL("http://nova-core8:11434/", for: .ollama) },
                            transport: rec.transport(body: #"{"models":[{"name":"qwen3:4b"}],"message":{"content":"ok"}}"#))
        XCTAssertEqual(ai.settings.url(for: .ollama), "http://nova-core8:11434")
        _ = try await GameAI.shared.generate(prompt: "x", ai: ai)
        XCTAssertEqual(rec.requests.first?.url?.host, "nova-core8")
        let models = await ai.listModels(for: .ollama)
        XCTAssertEqual(models, ["qwen3:4b"])
        XCTAssertEqual(rec.requests.last?.url?.absoluteString, "http://nova-core8:11434/api/tags")
    }

    func testGatewayURLSettingReachesBrains() async throws {
        let rec = RequestRecorder()
        var s = KitTest.settings()
        s.setURL("http://10.0.0.5:18792", for: .novaGateway)
        var c = AIFixtures.config(KitTest.engine(transport: rec.transport(body: AIFixtures.chat(#"{"action":"WAIT"}"#)), settings: s))
        _ = await BrainClient.requestMove(AIFixtures.request, brain: .gatewayClaude, config: c)
        XCTAssertEqual(rec.requests.last?.url?.absoluteString, "http://10.0.0.5:18792/v1/chat/completions")
        c.gatewayBaseURL = "http://pinned:1"
        _ = await BrainClient.requestMove(AIFixtures.request, brain: .gatewayClaude, config: c)
        XCTAssertEqual(rec.requests.last?.url?.absoluteString, "http://pinned:1/v1/chat/completions")
    }

    @MainActor
    func testSavedKeyMakesOpenRouterSelectable() {
        let ai = KitTest.ai(KitTest.settings { $0.backend = .openRouter })
        XCTAssertTrue(ai.engine.candidates().isEmpty, "no key, not available")
        XCTAssertTrue(ai.setAPIKey("sk-or-func", for: .openRouter))
        XCTAssertTrue(ai.hasAPIKey(for: .openRouter))
        XCTAssertEqual(ai.engine.candidates().map(\.backend), [.openRouter])
        XCTAssertTrue(ai.setAPIKey("", for: .openRouter))
        XCTAssertFalse(ai.hasAPIKey(for: .openRouter))
        XCTAssertTrue(ai.engine.candidates().isEmpty)
    }

    @MainActor
    func testTestConnectionReportsOutcome() async {
        let ai = KitTest.ai(transport: { request in
            if request.url?.path == "/api/tags" { return (Data(#"{"models":[{"name":"m1"}]}"#.utf8), Stub.response(200, url: request.url)) }
            throw URLError(.cannotConnectToHost)
        })
        let ok = await ai.testConnection(.ollama)
        XCTAssertTrue(ok.reachable)
        let down = await ai.testConnection(.tinyLLM)
        XCTAssertFalse(down.reachable)
        ai.isEnabled = false
        await ai.refreshStatus()
        XCTAssertEqual(ai.status.label, "AI off · built-in answers")
    }

    /// 3.23 settings (UserDefaults AIBackendManager_*) are imported once, then removed.
    @MainActor
    func testLegacySettingsImportOnce() {
        let (d, name) = KitTest.defaultsSuite()
        defer { UserDefaults().removePersistentDomain(forName: name) }
        d.set("ollama", forKey: "AIBackendManager_SelectedBackend")
        d.set("llama3.2:3b", forKey: "AIBackendManager_OllamaModel")
        d.set("http://nova-core8:11434", forKey: "AIBackendManager_OllamaURL")
        d.set(false, forKey: "AIBackendManager_AIEnabled")
        d.set("http://gw.local:18792", forKey: "AIBackendManager_NovaGatewayURL")
        d.set("http://tiny.local:8000", forKey: "AIBackendManager_TinyLLMServerURL")
        d.set("not a url", forKey: "AIBackendManager_OpenWebUIServerURL")
        d.set("openai/gpt-4o", forKey: "AIBackendManager_OpenRouterModel")
        d.set("/opt/homebrew/bin/python3", forKey: "AIBackendManager_PythonPath")
        let ai = KitTest.ai()
        AppAI.migrateLegacySettings(ai, defaults: d)
        let s = ai.settings
        XCTAssertEqual(s.backend, .ollama)
        XCTAssertFalse(s.enabled)
        XCTAssertEqual(s.model(for: .ollama), "llama3.2:3b")
        XCTAssertEqual(s.url(for: .ollama), "http://nova-core8:11434")
        XCTAssertEqual(s.url(for: .novaGateway), "http://gw.local:18792")
        XCTAssertEqual(s.url(for: .tinyLLM), "http://tiny.local:8000")
        XCTAssertEqual(s.url(for: .openWebUI), NovaAIBackend.openWebUI.defaultURL, "an invalid stored URL is ignored")
        XCTAssertEqual(s.model(for: .openRouter), "openai/gpt-4o")
        for key in AppAI.legacyDefaultsKeys { XCTAssertNil(d.object(forKey: key), key) }
        // Idempotent: a second launch changes nothing.
        ai.settings.backend = .auto
        AppAI.migrateLegacySettings(ai, defaults: d)
        XCTAssertEqual(ai.settings.backend, .auto)
    }

    @MainActor
    func testRemovedCloudSelectionBecomesAuto() {
        let (d, name) = KitTest.defaultsSuite()
        defer { UserDefaults().removePersistentDomain(forName: name) }
        d.set("Google Cloud AI", forKey: "AIBackendManager_SelectedBackend")
        d.set("mistral:latest", forKey: "AIBackendManager_OllamaModel")
        let ai = KitTest.ai()
        let report = AppAI.migrateLegacySettings(ai, defaults: d)
        XCTAssertTrue(report.settingsImported)
        XCTAssertEqual(ai.settings.backend, .auto, "a removed cloud backend becomes Auto")
        XCTAssertEqual(ai.settings.model(for: .ollama), "mistral:latest")
    }

    func testBuiltInTerminalAdviceFollowsTheSituation() {
        let gs = GameState(playerCountryID: "USA")
        XCTAssertTrue(TerminalAdvisor.builtInAdvice(gameState: gs).hasPrefix("RECOMMEND"))
        XCTAssertFalse(TerminalAdvisor.advicePrompt(situation: "what now", gameState: gs).isEmpty)
    }
}

// MARK: - Frame

final class AIOptionsFrameTests: XCTestCase {

    @MainActor override func setUp() async throws { AIFixtures.resetShared() }
    @MainActor override func tearDown() async throws { AIFixtures.resetShared() }

    @MainActor
    private func render<V: View>(_ view: V, _ w: CGFloat = 800, _ h: CGFloat = 900) -> CGImage? {
        let r = ImageRenderer(content: view.frame(width: w, height: h))
        r.scale = 1
        return r.cgImage
    }

    @MainActor
    func testSettingsRendersOnAndOff() {
        let ai = KitTest.ai()
        XCTAssertNotNil(render(GTNWAISettingsView(ai: ai)))
        ai.isEnabled = false
        XCTAssertNotNil(render(GTNWAISettingsView(ai: ai)))
    }

    @MainActor
    func testStatusMenuItemsAndToolbarRender() {
        let ai = KitTest.ai()
        XCTAssertNotNil(render(VStack { AIStatusMenuItems(ai: ai) }, 400, 160))
        XCTAssertNotNil(render(AIBackendToolbar(ai: ai), 500, 40))
        XCTAssertNotNil(render(NovaAIStatusIndicator(ai: ai, checksOnAppear: false), 300, 30))
        ai.isEnabled = false
        XCTAssertNotNil(render(AIBackendToolbar(ai: ai), 500, 40))
    }

    @MainActor
    func testBrainAssignmentRendersWithAndWithoutKey() {
        let e = GameEngine()
        e.startNewGame(playerCountryID: "USA")
        XCTAssertNotNil(render(BrainAssignmentView().environmentObject(e), 600, 600))
        AppAI.shared.setAPIKey("sk-or-frame", for: .openRouter)
        AppAI.shared.isEnabled = false
        XCTAssertNotNil(render(BrainAssignmentView().environmentObject(e), 600, 600))
    }
}
