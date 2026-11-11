//
//  AIKeyStore.swift
//  Global Thermal Nuclear War
//
//  API keys for the cloud AI backends. Keys live ONLY in the Keychain, under GTNW's own service names
//  (com.jkoch.gtnw.openrouter, com.jkoch.gtnw.openai). Never UserDefaults, files, logs or the environment.
//  `KeychainStore` is ported from Blompie/AIStudio (Services/KeychainStore.swift).
//
//  Created by Jordan Koch on 2026.
//

import Foundation
import Security

/// Minimal Keychain wrapper (classic generic-password items, so the round trip also works in an unsigned test host).
struct KeychainStore {
    let service: String
    let account: String

    init(service: String, account: String = "apiKey") {
        self.service = service
        self.account = account
    }

    private var baseQuery: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    /// Store (or replace) a secret. An empty value deletes the item instead of storing "".
    @discardableResult
    func set(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return delete() }
        guard let data = trimmed.data(using: .utf8) else { return false }
        let update = SecItemUpdate(baseQuery as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if update == errSecSuccess { return true }
        var attributes = baseQuery
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlocked
        return SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess
    }

    func get() -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data, let value = String(data: data, encoding: .utf8) else { return nil }
        return value
    }

    @discardableResult
    func delete() -> Bool {
        let status = SecItemDelete(baseQuery as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    var hasValue: Bool { !(get() ?? "").isEmpty }

    /// True when an item exists. Reads attributes only, never the secret, so it can't raise a Keychain access
    /// prompt (an ad hoc rebuild is a "new" app to the Keychain). GTNW never stores an empty secret.
    var exists: Bool {
        var query = baseQuery
        query[kSecReturnAttributes as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        return SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess
    }
}

/// The two keys GTNW knows about, and where each one lives.
enum AIKeyStore {
    enum Slot: String, CaseIterable, Sendable {
        case openRouter = "openrouter"
        case openAI = "openai"
    }

    /// Service prefix. Under XCTest a per-run prefix keeps tests away from the real items.
    static var servicePrefix: String =
        AudioGate.underXCTest ? "com.jkoch.gtnw.tests.\(UUID().uuidString)" : "com.jkoch.gtnw"

    /// Pre-3.23 GTNW kept the OpenAI key in this service/account (still GTNW's own item; migrated once).
    static var legacyService: String =
        AudioGate.underXCTest ? "com.jordankoch.GTNW.tests.\(UUID().uuidString)" : "com.jordankoch.GTNW"
    static let legacyOpenAIAccount = "AIBackendManager_OpenAI_Key"

    static func store(_ slot: Slot) -> KeychainStore {
        KeychainStore(service: "\(servicePrefix).\(slot.rawValue)")
    }

    static func key(_ slot: Slot) -> String? {
        guard let v = store(slot).get(), !v.isEmpty else { return nil }
        return v
    }

    @discardableResult
    static func setKey(_ value: String, for slot: Slot) -> Bool { store(slot).set(value) }

    /// Presence only (no secret read, no prompt). The secret itself is read when a request needs it.
    static func hasKey(_ slot: Slot) -> Bool { store(slot).exists }

    /// One-time move of the legacy OpenAI key into `com.jkoch.gtnw.openai`. Reads the old item once, writes the new
    /// one, deletes the old one only after the write succeeded. Safe to call on every launch.
    static func migrateLegacyKeys() {
        let legacy = KeychainStore(service: legacyService, account: legacyOpenAIAccount)
        guard legacy.exists else { return }
        let old = (legacy.get() ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !old.isEmpty && !hasKey(.openAI) {
            guard setKey(old, for: .openAI) else { return }
        }
        legacy.delete()   // also clears the empty item pre-3.23 saveSettings() wrote
    }
}
