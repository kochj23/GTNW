//
//  AIBackendManager.swift
//  Global Thermal Nuclear War
//
//  The one AI backend manager GTNW ships. Everything that asks a model for text (Nova's commentary, the side
//  features) goes through `generate`; per-country brains use `BrainClient` (AIBrain.swift) with the same URLs and keys.
//
//  - Global switch: `aiEnabled`. Off = no AI request leaves the app; every feature keeps its scripted fallback.
//  - Backends: the canonical `LLMBackendType` ids (auto, ollama, mlx, tinyllm, tinychat, openwebui, novagateway,
//    openrouter, openai). Every URL is editable; defaults stay on localhost.
//  - Auto: probe reachable backends, use the first in `LLMBackendType.autoOrder`, fail over down the chain.
//    Each backend gets bounded retries (`Retry.run`, 408/429/5xx/transport only) and a per-request timeout.
//  - Keys: Keychain only (`AIKeyStore`, services com.jkoch.gtnw.openrouter / com.jkoch.gtnw.openai). A key is only
//    ever sent over https.
//  - Output: every reply passes `AIOutputSanitizer` before a caller sees it.
//
//  THIRD-PARTY: TinyLLM and TinyChat by Jason Cox (github.com/jasonacox), OpenWebUI (github.com/open-webui).
//

import Foundation
import SwiftUI
import Combine

// MARK: - AI Backend Manager

@MainActor
final class AIBackendManager: ObservableObject {
    static let shared = AIBackendManager()

    // MARK: Published state

    /// The global "Use AI" switch (persisted by `saveSettings`).
    @Published var aiEnabled: Bool = true
    @Published var selectedBackend: LLMBackendType = .auto
    /// The backend that will serve the next request, or nil (AI off / nothing reachable → scripted fallback).
    @Published var activeBackend: LLMBackendType? = nil

    @Published var isOllamaAvailable = false
    @Published var isMLXAvailable = false
    @Published var isTinyLLMAvailable = false
    @Published var isTinyChatAvailable = false
    @Published var isOpenWebUIAvailable = false
    @Published var isNovaGatewayAvailable = false
    @Published var isOpenRouterAvailable = false
    @Published var isOpenAIAvailable = false

    @Published var isProcessing = false
    @Published var isChecking = false
    @Published var lastError: String? = nil
    @Published var lastChecked: Date? = nil
    /// Human-readable result of the last "Test connection".
    @Published var lastTestResult: String? = nil

    // Models
    @Published var ollamaModels: [String] = []
    @Published var selectedOllamaModel: String = "mistral:latest"
    @Published var novaGatewayModel: String = "chat"
    @Published var openRouterModel: String = "anthropic/claude-sonnet-4.5"
    @Published var openAIModel: String = "gpt-4o"

    // Endpoints (all editable)
    @Published var ollamaBaseURL: String = AIEndpointSettings.ollamaDefault
    @Published var tinyLLMServerURL: String = "http://localhost:8000"
    @Published var tinyChatServerURL: String = "http://localhost:8000"
    @Published var openWebUIServerURL: String = "http://localhost:8080"
    @Published var novaGatewayURL: String = AIEndpointSettings.novaGatewayDefault
    @Published var pythonPath: String = "/opt/homebrew/bin/python3"
    @Published var mlxModel: String = "mlx-community/Llama-3.2-1B-Instruct-4bit"

    /// Key presence (the keys themselves are read from the Keychain at request time, never kept in a published var).
    @Published private(set) var hasOpenRouterKey = false
    @Published private(set) var hasOpenAIKey = false

    // Fixed cloud endpoints (https only).
    static let openRouterChatURL = "https://openrouter.ai/api/v1/chat/completions"
    static let openAIChatURL = "https://api.openai.com/v1/chat/completions"

    // MARK: Seams (tests stub these; production uses URLSession + backoff)

    var httpTransport: HTTPTransport = HTTP.live
    var generationRetryPolicy: RetryPolicy = .network
    var retrySleep: RetrySleeper = Retry.realSleep
    /// Per-request timeout for generation; probes use `probeTimeout`.
    var requestTimeout: TimeInterval = 30
    var probeTimeout: TimeInterval = 3
    /// MLX is probed by running python; tests keep that off so they never spawn a real interpreter.
    var probesMLX: Bool = !AudioGate.underXCTest
    /// Under XCTest nothing probes the real machine unless a test opts in (with a stub transport).
    var probesNetwork: Bool = !AudioGate.underXCTest

    private var defaults: UserDefaults { AIEndpointSettings.defaults }

    private enum Keys {
        static let selectedBackend = "AIBackendManager_SelectedBackend"
        static let ollamaModel = "AIBackendManager_OllamaModel"
        static let pythonPath = "AIBackendManager_PythonPath"
        static let mlxModel = "AIBackendManager_MLXModel"
        static let tinyLLMServerURL = "AIBackendManager_TinyLLMServerURL"
        static let tinyChatServerURL = "AIBackendManager_TinyChatServerURL"
        static let openWebUIServerURL = "AIBackendManager_OpenWebUIServerURL"
        static let novaGatewayModel = "AIBackendManager_NovaGatewayModel"
        static let openRouterModel = "AIBackendManager_OpenRouterModel"
        static let openAIModel = "AIBackendManager_OpenAIModel"
        /// Pre-3.23 cloud settings that were (wrongly) kept in UserDefaults; removed on load.
        static let legacyDefaults = ["AIBackendManager_OpenAI_Key", "AIBackendManager_GoogleCloud_Key",
                                     "AIBackendManager_Azure_Key", "AIBackendManager_Azure_Endpoint",
                                     "AIBackendManager_AWS_AccessKey", "AIBackendManager_AWS_SecretKey",
                                     "AIBackendManager_AWS_Region", "AIBackendManager_IBM_Key",
                                     "AIBackendManager_IBM_URL", "AIBackendManager_MLXScriptPath"]
    }

    // MARK: Init

    private init() {
        AIKeyStore.migrateLegacyKeys()
        loadSettings()
        // Tests stay hermetic: no probing of the real machine under XCTest.
        if !AudioGate.underXCTest {
            Task { await checkBackendAvailability() }
        }
    }

    // MARK: Settings

    func loadSettings() {
        for key in Keys.legacyDefaults { defaults.removeObject(forKey: key) }
        aiEnabled = AIEndpointSettings.aiEnabled
        selectedBackend = LLMBackendType.migrate(persisted: defaults.string(forKey: Keys.selectedBackend))
        selectedOllamaModel = defaults.string(forKey: Keys.ollamaModel) ?? "mistral:latest"
        pythonPath = defaults.string(forKey: Keys.pythonPath) ?? "/opt/homebrew/bin/python3"
        mlxModel = defaults.string(forKey: Keys.mlxModel) ?? "mlx-community/Llama-3.2-1B-Instruct-4bit"
        ollamaBaseURL = AIEndpointSettings.ollamaURL
        novaGatewayURL = AIEndpointSettings.novaGatewayURL
        tinyLLMServerURL = defaults.string(forKey: Keys.tinyLLMServerURL) ?? "http://localhost:8000"
        tinyChatServerURL = defaults.string(forKey: Keys.tinyChatServerURL) ?? "http://localhost:8000"
        openWebUIServerURL = defaults.string(forKey: Keys.openWebUIServerURL) ?? "http://localhost:8080"
        novaGatewayModel = defaults.string(forKey: Keys.novaGatewayModel) ?? "chat"
        openRouterModel = defaults.string(forKey: Keys.openRouterModel) ?? "anthropic/claude-sonnet-4.5"
        openAIModel = defaults.string(forKey: Keys.openAIModel) ?? "gpt-4o"
        refreshKeyPresence()
    }

    /// Persist every non-secret setting. Secrets go through `setAPIKey` (Keychain) only.
    func saveSettings() {
        AIEndpointSettings.aiEnabled = aiEnabled
        defaults.set(selectedBackend.rawValue, forKey: Keys.selectedBackend)
        defaults.set(selectedOllamaModel, forKey: Keys.ollamaModel)
        defaults.set(pythonPath, forKey: Keys.pythonPath)
        defaults.set(mlxModel, forKey: Keys.mlxModel)
        if AIEndpointPolicy.isValidServerURL(ollamaBaseURL) { AIEndpointSettings.ollamaURL = ollamaBaseURL }
        if AIEndpointPolicy.isValidServerURL(novaGatewayURL) { AIEndpointSettings.novaGatewayURL = novaGatewayURL }
        defaults.set(AIEndpointPolicy.normalized(tinyLLMServerURL), forKey: Keys.tinyLLMServerURL)
        defaults.set(AIEndpointPolicy.normalized(tinyChatServerURL), forKey: Keys.tinyChatServerURL)
        defaults.set(AIEndpointPolicy.normalized(openWebUIServerURL), forKey: Keys.openWebUIServerURL)
        defaults.set(novaGatewayModel, forKey: Keys.novaGatewayModel)
        defaults.set(openRouterModel, forKey: Keys.openRouterModel)
        defaults.set(openAIModel, forKey: Keys.openAIModel)
    }

    /// Turn AI on or off for the whole game, persist it, and re-resolve the active backend.
    func setAIEnabled(_ on: Bool) {
        aiEnabled = on
        saveSettings()
        determineActiveBackend()
    }

    /// Store (non-empty) or delete (empty) a cloud key in the Keychain.
    func setAPIKey(_ value: String, for slot: AIKeyStore.Slot) {
        AIKeyStore.setKey(value, for: slot)
        refreshKeyPresence()
        determineActiveBackend()
    }

    func refreshKeyPresence() {
        hasOpenRouterKey = AIKeyStore.hasKey(.openRouter)
        hasOpenAIKey = AIKeyStore.hasKey(.openAI)
        isOpenRouterAvailable = hasOpenRouterKey
        isOpenAIAvailable = hasOpenAIKey
    }

    // MARK: Availability

    /// Backends reachable right now (from the last probe).
    var availableBackends: Set<LLMBackendType> {
        var s = Set<LLMBackendType>()
        if isOllamaAvailable { s.insert(.ollama) }
        if isMLXAvailable { s.insert(.mlx) }
        if isTinyLLMAvailable { s.insert(.tinyLLM) }
        if isTinyChatAvailable { s.insert(.tinyChat) }
        if isOpenWebUIAvailable { s.insert(.openWebUI) }
        if isNovaGatewayAvailable { s.insert(.novaGateway) }
        if isOpenRouterAvailable { s.insert(.openRouter) }
        if isOpenAIAvailable { s.insert(.openAI) }
        return s
    }

    func isAvailable(_ backend: LLMBackendType) -> Bool {
        backend == .auto ? activeBackend != nil : availableBackends.contains(backend)
    }

    /// Probe every local backend (single short attempt each, in parallel) and re-resolve the active backend.
    /// Cloud backends count as available when their key is in the Keychain; probing them would send traffic.
    func checkBackendAvailability() async {
        guard probesNetwork || probesMLX else {
            // Hermetic (XCTest) path: nothing to probe, so finish without suspending — callers see the result at once.
            isOllamaAvailable = false; isMLXAvailable = false; isTinyLLMAvailable = false
            isTinyChatAvailable = false; isOpenWebUIAvailable = false; isNovaGatewayAvailable = false
            refreshKeyPresence()
            lastChecked = Date()
            determineActiveBackend()
            return
        }
        isChecking = true
        defer { isChecking = false }
        let unreachable: HTTPTransport = { @Sendable _ in throw URLError(.notConnectedToInternet) }
        let transport: HTTPTransport = probesNetwork ? httpTransport : unreachable
        let timeout = probeTimeout
        async let ollama = Self.probeOllama(base: ollamaBaseURL, transport: transport, timeout: timeout)
        let runMLXProbe = probesMLX
        async let mlx = runMLXProbe ? checkMLXAvailability() : false
        async let tinyLLM = Self.probe("\(AIEndpointPolicy.normalized(tinyLLMServerURL))/", transport: transport, timeout: timeout)
        async let tinyChat = Self.probe("\(AIEndpointPolicy.normalized(tinyChatServerURL))/", transport: transport, timeout: timeout)
        async let openWebUI = Self.probe("\(AIEndpointPolicy.normalized(openWebUIServerURL))/", transport: transport, timeout: timeout)
        async let gateway = Self.probe("\(AIEndpointPolicy.normalized(novaGatewayURL))/health", transport: transport, timeout: timeout)

        let (models, mlxOK, tinyLLMOK, tinyChatOK, openWebUIOK, gatewayOK) = await (ollama, mlx, tinyLLM, tinyChat, openWebUI, gateway)
        isOllamaAvailable = models != nil
        if let models {
            ollamaModels = models
            if !models.isEmpty && !models.contains(selectedOllamaModel) {
                selectedOllamaModel = models[0]
                saveSettings()
            }
        }
        isMLXAvailable = mlxOK
        isTinyLLMAvailable = tinyLLMOK
        isTinyChatAvailable = tinyChatOK
        isOpenWebUIAvailable = openWebUIOK
        isNovaGatewayAvailable = gatewayOK
        refreshKeyPresence()
        lastChecked = Date()
        determineActiveBackend()
    }

    func determineActiveBackend() {
        activeBackend = aiEnabled ? LLMBackendType.resolve(selected: selectedBackend, available: availableBackends) : nil
    }

    /// One GET; reachable = any HTTP answer below 500.
    nonisolated static func probe(_ urlString: String, transport: HTTPTransport, timeout: TimeInterval) async -> Bool {
        guard AIEndpointPolicy.isValidServerURL(urlString), let url = URL(string: urlString) else { return false }
        var req = URLRequest(url: url)
        req.timeoutInterval = timeout
        guard let (_, resp) = try? await transport(req), let http = resp as? HTTPURLResponse else { return false }
        return http.statusCode < 500
    }

    /// Ollama probe: nil = unreachable, otherwise the installed model names.
    nonisolated static func probeOllama(base: String, transport: HTTPTransport, timeout: TimeInterval) async -> [String]? {
        let s = "\(AIEndpointPolicy.normalized(base))/api/tags"
        guard AIEndpointPolicy.isValidServerURL(s), let url = URL(string: s) else { return nil }
        var req = URLRequest(url: url)
        req.timeoutInterval = timeout
        guard let (data, resp) = try? await transport(req),
              let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return nil }
        return ModelRegistry.parseOllamaTags(data).map(\.name)
    }

    private func checkMLXAvailability() async -> Bool {
        #if os(macOS)
        // Off the main thread with a 5 s limit (a slow python must never freeze launch).
        let path = pythonPath
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let task = Process()
                task.executableURL = URL(fileURLWithPath: path)
                task.arguments = ["-c", "import mlx_lm; print('OK')"]
                task.standardOutput = FileHandle.nullDevice
                task.standardError = FileHandle.nullDevice
                do { try task.run() } catch { continuation.resume(returning: false); return }
                let deadline = Date().addingTimeInterval(5)
                while task.isRunning && Date() < deadline { usleep(50_000) }
                if task.isRunning {
                    task.terminate()
                    continuation.resume(returning: false)
                } else {
                    continuation.resume(returning: task.terminationStatus == 0)
                }
            }
        }
        #else
        return false
        #endif
    }

    /// "Test connection": re-probe, then ask the active backend for a one-word reply and report what happened.
    @discardableResult
    func testConnection() async -> Bool {
        await checkBackendAvailability()
        guard aiEnabled else { lastTestResult = "AI is off — the game uses its built-in logic."; return false }
        guard let backend = activeBackend else {
            lastTestResult = "No backend reachable — the game uses its built-in logic."
            return false
        }
        let started = Date()
        do {
            _ = try await generate(prompt: "Reply with the single word OK.", systemPrompt: nil, temperature: 0, maxTokens: 5)
            lastTestResult = String(format: "%@ answered in %.1f s", backend.displayName, Date().timeIntervalSince(started))
            return true
        } catch {
            lastTestResult = "\(backend.displayName) failed: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: Generation

    /// Generate text with the active backend. Throws `noBackendAvailable` (without any network call) when AI is off
    /// or nothing is reachable; in Auto mode a failing backend hands over to the next reachable one.
    func generate(
        prompt: String,
        systemPrompt: String? = nil,
        temperature: Float = 0.7,
        maxTokens: Int = 2048
    ) async throws -> String {
        guard aiEnabled else { throw AIBackendError.noBackendAvailable }
        let chain = LLMBackendType.failoverChain(selected: selectedBackend, active: activeBackend, available: availableBackends)
        guard !chain.isEmpty else { throw AIBackendError.noBackendAvailable }

        isProcessing = true
        defer { isProcessing = false }

        var lastFailure: Error = AIBackendError.noBackendAvailable
        for backend in chain {
            do {
                let raw = try await Retry.run("AI backend \(backend.rawValue)", policy: generationRetryPolicy,
                                              sleep: retrySleep, shouldRetry: Self.isRetryable) {
                    try await generateOnce(backend: backend, prompt: prompt, systemPrompt: systemPrompt,
                                           temperature: temperature, maxTokens: maxTokens)
                }
                guard let clean = AIOutputSanitizer.clean(raw) else { throw AIBackendError.emptyResponse }
                lastError = nil
                return clean
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                lastFailure = error
                lastError = "\(backend.displayName): \(error.localizedDescription)"
            }
        }
        throw lastFailure
    }

    /// Permanent errors that must not be retried (configuration can't fix itself).
    nonisolated static func isRetryable(_ error: Error) -> Bool {
        if let e = error as? AIBackendError {
            switch e {
            case .noBackendAvailable, .invalidConfiguration, .invalidState, .mlxScriptNotConfigured,
                 .embeddingsNotSupported, .missingAPIKey, .insecureEndpoint, .emptyResponse:
                return false
            case .mlxExecutionFailed:
                return true
            }
        }
        if let status = error as? HTTPStatusError { return status.isRetryable }
        return !(error is CancellationError)
    }

    /// One attempt against one backend (no retry).
    private func generateOnce(backend: LLMBackendType, prompt: String, systemPrompt: String?,
                              temperature: Float, maxTokens: Int) async throws -> String {
        let messages = Self.chatMessages(prompt: prompt, systemPrompt: systemPrompt)
        switch backend {
        case .ollama:
            return try await generateWithOllama(prompt: prompt, systemPrompt: systemPrompt,
                                                temperature: temperature, maxTokens: maxTokens)
        case .mlx:
            return try await generateWithMLX(prompt: prompt, systemPrompt: systemPrompt,
                                             temperature: temperature, maxTokens: maxTokens)
        case .tinyLLM:
            return try await chatCompletion(url: "\(AIEndpointPolicy.normalized(tinyLLMServerURL))/v1/chat/completions",
                                            model: nil, messages: messages, temperature: temperature, maxTokens: maxTokens)
        case .tinyChat:
            return try await chatCompletion(url: "\(AIEndpointPolicy.normalized(tinyChatServerURL))/api/chat/stream",
                                            model: nil, messages: messages, temperature: temperature, maxTokens: maxTokens)
        case .openWebUI:
            return try await chatCompletion(url: "\(AIEndpointPolicy.normalized(openWebUIServerURL))/api/chat/completions",
                                            model: nil, messages: messages, temperature: temperature, maxTokens: maxTokens)
        case .novaGateway:
            return try await chatCompletion(url: "\(AIEndpointPolicy.normalized(novaGatewayURL))/v1/chat/completions",
                                            model: novaGatewayModel, messages: messages, temperature: temperature, maxTokens: maxTokens)
        case .openRouter:
            guard let key = AIKeyStore.key(.openRouter) else { throw AIBackendError.missingAPIKey }
            return try await chatCompletion(url: Self.openRouterChatURL, model: openRouterModel, messages: messages,
                                            temperature: temperature, maxTokens: maxTokens,
                                            headers: OpenRouterAuth.headers(apiKey: key))
        case .openAI:
            guard let key = AIKeyStore.key(.openAI) else { throw AIBackendError.missingAPIKey }
            return try await chatCompletion(url: Self.openAIChatURL, model: openAIModel, messages: messages,
                                            temperature: temperature, maxTokens: maxTokens,
                                            headers: ["Authorization": "Bearer \(key)"])
        case .auto:
            throw AIBackendError.invalidState
        }
    }

    nonisolated static func chatMessages(prompt: String, systemPrompt: String?) -> [[String: String]] {
        var messages: [[String: String]] = []
        if let systemPrompt { messages.append(["role": "system", "content": systemPrompt]) }
        messages.append(["role": "user", "content": prompt])
        return messages
    }

    /// PURE: build an OpenAI-compatible chat request. Refuses (throws) to attach any credential header to a
    /// non-https URL.
    nonisolated static func makeChatRequest(url urlString: String, model: String?, messages: [[String: String]],
                                            temperature: Float, maxTokens: Int, headers: [String: String] = [:],
                                            timeout: TimeInterval) throws -> URLRequest {
        guard AIEndpointPolicy.isValidServerURL(urlString), let url = URL(string: urlString) else {
            throw AIBackendError.invalidConfiguration
        }
        if !headers.isEmpty && !AIEndpointPolicy.mayCarryKey(url) { throw AIBackendError.insecureEndpoint }
        var body: [String: Any] = ["messages": messages, "max_tokens": maxTokens, "temperature": temperature, "stream": false]
        if let model, !model.isEmpty { body["model"] = model }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (k, v) in headers { request.setValue(v, forHTTPHeaderField: k) }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    private func chatCompletion(url: String, model: String?, messages: [[String: String]], temperature: Float,
                                maxTokens: Int, headers: [String: String] = [:]) async throws -> String {
        let request = try Self.makeChatRequest(url: url, model: model, messages: messages, temperature: temperature,
                                               maxTokens: maxTokens, headers: headers, timeout: requestTimeout)
        let (data, response) = try await httpTransport(request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw HTTPStatusError(statusCode: http.statusCode)
        }
        guard let text = OpenAICompatibleRequest.parseContent(data) else { throw AIBackendError.emptyResponse }
        return text
    }

    // MARK: Ollama

    private func generateWithOllama(prompt: String, systemPrompt: String?, temperature: Float, maxTokens: Int) async throws -> String {
        guard let url = URL(string: "\(AIEndpointPolicy.normalized(ollamaBaseURL))/api/generate"),
              AIEndpointPolicy.isValidServerURL(url.absoluteString) else {
            throw AIBackendError.invalidConfiguration
        }
        var requestBody: [String: Any] = [
            "model": selectedOllamaModel,
            "prompt": prompt,
            "stream": false,
            "options": ["temperature": temperature, "num_predict": maxTokens]
        ]
        if let systemPrompt { requestBody["system"] = systemPrompt }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = requestTimeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, urlResponse) = try await httpTransport(request)
        if let http = urlResponse as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw HTTPStatusError(statusCode: http.statusCode)
        }
        struct OllamaResponse: Codable { let response: String }
        return try JSONDecoder().decode(OllamaResponse.self, from: data).response
    }

    // MARK: MLX (macOS only)

    private func generateWithMLX(prompt: String, systemPrompt: String?, temperature: Float, maxTokens: Int) async throws -> String {
        #if os(macOS)
        var fullPrompt = ""
        if let systemPrompt { fullPrompt += "System: \(systemPrompt)\n\n" }
        fullPrompt += "User: \(prompt)\n\nAssistant:"
        // SECURITY: the prompt and model id travel as argv values, never interpolated into the Python source.
        let script = """
        import sys, json
        try:
            import mlx_lm
            model, tokenizer = mlx_lm.load(sys.argv[2])
            print(mlx_lm.generate(model, tokenizer, prompt=sys.argv[1], max_tokens=int(sys.argv[3]), verbose=False))
        except Exception as e:
            print(json.dumps({"error": str(e)}), file=sys.stderr)
            sys.exit(1)
        """
        return try await Self.runPython(pythonPath, script: script,
                                        arguments: [fullPrompt, mlxModel, String(max(1, maxTokens))], timeout: 120)
        #else
        throw AIBackendError.mlxScriptNotConfigured
        #endif
    }

    #if os(macOS)
    /// Run a python script off the main actor with a hard timeout.
    nonisolated static func runPython(_ python: String, script: String, arguments: [String], timeout: TimeInterval) async throws -> String {
        let scriptFile = FileManager.default.temporaryDirectory.appendingPathComponent("gtnw_mlx_\(UUID().uuidString).py")
        try script.write(to: scriptFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: scriptFile) }
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let task = Process()
                task.executableURL = URL(fileURLWithPath: python)
                task.arguments = [scriptFile.path] + arguments
                let out = Pipe(), err = Pipe()
                task.standardOutput = out
                task.standardError = err
                do { try task.run() } catch { continuation.resume(throwing: error); return }
                let deadline = Date().addingTimeInterval(timeout)
                while task.isRunning && Date() < deadline { usleep(50_000) }
                if task.isRunning {
                    task.terminate()
                    continuation.resume(throwing: AIBackendError.mlxExecutionFailed("timed out after \(Int(timeout)) s"))
                    return
                }
                let output = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                if task.terminationStatus != 0 {
                    let message = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "unknown error"
                    continuation.resume(throwing: AIBackendError.mlxExecutionFailed(String(message.prefix(500))))
                } else {
                    continuation.resume(returning: output.trimmingCharacters(in: .whitespacesAndNewlines))
                }
            }
        }
    }
    #endif

    // MARK: Embeddings (Ollama only)

    func generateEmbeddings(text: String) async throws -> [Float] {
        guard aiEnabled, isOllamaAvailable,
              let url = URL(string: "\(AIEndpointPolicy.normalized(ollamaBaseURL))/api/embeddings") else {
            throw AIBackendError.embeddingsNotSupported
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = requestTimeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["model": "nomic-embed-text", "prompt": text])
        let (data, _) = try await httpTransport(request)
        struct EmbeddingResponse: Codable { let embedding: [Float] }
        return try JSONDecoder().decode(EmbeddingResponse.self, from: data).embedding
    }
}

// MARK: - OpenRouter

/// OpenRouter auth + attribution headers (ported from Blompie/AIStudio `OpenRouterProvider`, attributed to GTNW).
enum OpenRouterAuth {
    static let referer = "https://github.com/kochj23/GTNW"
    static let title = "GTNW"

    static let attribution = ["HTTP-Referer": referer, "X-Title": title]

    static func headers(apiKey: String) -> [String: String] {
        attribution.merging(["Authorization": "Bearer \(apiKey)"]) { _, new in new }
    }
}

// MARK: - Errors

enum AIBackendError: LocalizedError, Equatable {
    case noBackendAvailable
    case invalidConfiguration
    case invalidState
    case mlxScriptNotConfigured
    case mlxExecutionFailed(String)
    case embeddingsNotSupported
    case missingAPIKey
    case insecureEndpoint
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .noBackendAvailable: return "No AI backend available (AI is off or nothing answered). The game uses its built-in logic."
        case .invalidConfiguration: return "AI backend configuration is invalid (check the URL)."
        case .invalidState: return "AI backend is in an invalid state."
        case .mlxScriptNotConfigured: return "MLX is only available on macOS."
        case .mlxExecutionFailed(let message): return "MLX execution failed: \(message)"
        case .embeddingsNotSupported: return "Embeddings need a reachable Ollama server."
        case .missingAPIKey: return "No API key in the Keychain for this backend (Settings → AI)."
        case .insecureEndpoint: return "Refused to send an API key over a non-https connection."
        case .emptyResponse: return "The model returned nothing usable."
        }
    }
}
