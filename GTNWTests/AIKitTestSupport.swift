//
//  AIKitTestSupport.swift
//  GTNWTests
//
//  Drives NovaAIKit with GTNW's scripted `HTTPTransport` stubs (Stub.transport, RequestRecorder): a URLProtocol
//  bridges the kit's URLSession to the stub, so no request ever reaches a server. Keys live in an in-memory store,
//  never the real Keychain; settings in memory, never the real defaults.
//
//  Created by Jordan Koch on 2026.
//

import Foundation
import XCTest
import NovaAIKit
@testable import GTNW

/// Hands every request of a session to that session's `HTTPTransport` (body read out of the stream first).
final class TransportURLProtocol: URLProtocol {
    static let header = "X-GTNW-Test-Transport"
    private static let lock = NSLock()
    private static var transports: [String: HTTPTransport] = [:]

    /// A session whose requests all go to `transport`.
    static func session(_ transport: @escaping HTTPTransport) -> URLSession {
        let token = UUID().uuidString
        lock.withLock { transports[token] = transport }
        let cfg = URLSessionConfiguration.ephemeral
        cfg.protocolClasses = [TransportURLProtocol.self]
        cfg.httpAdditionalHeaders = [header: token]
        return URLSession(configuration: cfg)
    }

    /// Answers nothing: every request fails as "cannot connect".
    static let refuse: HTTPTransport = { _ in throw URLError(.cannotConnectToHost) }

    private var work: Task<Void, Never>?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        var req = request
        if req.httpBody == nil, let stream = req.httpBodyStream {
            var body = Data()
            stream.open()
            var buf = [UInt8](repeating: 0, count: 65_536)
            while stream.hasBytesAvailable {
                let n = stream.read(&buf, maxLength: buf.count)
                if n <= 0 { break }
                body.append(buf, count: n)
            }
            stream.close()
            req.httpBodyStream = nil
            req.httpBody = body
        }
        let token = req.value(forHTTPHeaderField: Self.header) ?? ""
        req.setValue(nil, forHTTPHeaderField: Self.header)
        let transport = Self.lock.withLock { Self.transports[token] } ?? Self.refuse
        let client = self.client
        let finalRequest = req
        work = Task { [self] in
            do {
                let (data, response) = try await transport(finalRequest)
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: data)
                client?.urlProtocolDidFinishLoading(self)
            } catch {
                client?.urlProtocol(self, didFailWithError: error)
            }
        }
    }

    override func stopLoading() { work?.cancel() }
}

/// Factories for kit objects wired to stubs.
enum KitTest {
    static var configuration: NovaAIConfiguration { AppAI.configuration }

    /// An in-memory key store holding `keys`.
    static func keyStore(_ keys: [NovaAIBackend: String] = [:]) -> NovaAIMemoryKeyStore {
        let store = NovaAIMemoryKeyStore()
        let k = NovaAIKeys(configuration: configuration, store: store)
        for (backend, key) in keys { _ = k.setKey(key, for: backend) }
        return store
    }

    /// GTNW's settings (30 s, gateway "chat"), adjusted by `edit`.
    static func settings(_ edit: (inout NovaAISettings) -> Void = { _ in }) -> NovaAISettings {
        var s = configuration.defaultSettings
        edit(&s)
        return s
    }

    /// A NovaAI with GTNW's configuration; requests go to `transport` (default: refused).
    @MainActor
    static func ai(_ settings: NovaAISettings = settings(), transport: @escaping HTTPTransport = TransportURLProtocol.refuse,
                   keys: [NovaAIBackend: String] = [:], store: NovaAIMemoryKeyStore? = nil,
                   sleep: @escaping NovaAISleeper = { _ in }) -> NovaAI {
        NovaAI(configuration: configuration, storage: NovaAIMemoryStorage(settings),
               keyStore: store ?? keyStore(keys), session: TransportURLProtocol.session(transport), sleep: sleep)
    }

    /// A NovaAIEngine (what brains use) with GTNW's configuration and `transport`.
    static func engine(transport: @escaping HTTPTransport = TransportURLProtocol.refuse, keys: [NovaAIBackend: String] = [:],
                       settings: NovaAISettings = settings(), sleep: @escaping NovaAISleeper = { _ in }) -> NovaAIEngine {
        NovaAIEngine(configuration: configuration, settings: settings,
                     keys: NovaAIKeys(configuration: configuration, store: keyStore(keys)),
                     session: TransportURLProtocol.session(transport), sleep: sleep)
    }

    /// Ollama `/api/chat` reply.
    static func ollama(_ text: String) -> String {
        let quoted = String(data: try! JSONSerialization.data(withJSONObject: [text]), encoding: .utf8)!.dropFirst().dropLast()
        return #"{"model":"m","message":{"role":"assistant","content":"# + quoted + #"},"done":true}"#
    }

    /// A throwaway UserDefaults suite (removed by the caller with `removePersistentDomain`).
    static func defaultsSuite() -> (UserDefaults, String) {
        let name = "GTNW.tests.kit.\(UUID().uuidString)"
        return (UserDefaults(suiteName: name)!, name)
    }
}

extension GameEngine {
    /// Route this engine's model brains through NovaAIKit with a stub transport (live-session brains keep using
    /// `brainConfig.transport`).
    @MainActor
    func useKitTransport(_ transport: @escaping HTTPTransport, keys: [NovaAIBackend: String] = [:],
                         sleep: @escaping NovaAISleeper = { _ in }) {
        brainConfig.engine = KitTest.engine(transport: transport, keys: keys, sleep: sleep)
    }
}
