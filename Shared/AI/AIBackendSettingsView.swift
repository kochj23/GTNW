//
//  AIBackendSettingsView.swift
//  Global Thermal Nuclear War
//
//  Settings → AI: the global "Use AI" switch, backend + model pickers, every endpoint URL, Keychain key fields,
//  live status and "Test connection".
//
//  Created by Jordan Koch on 2026.
//

import SwiftUI

struct AIBackendSettingsView: View {
    @ObservedObject var manager = AIBackendManager.shared
    @State private var openRouterKeyDraft = ""
    @State private var openAIKeyDraft = ""
    @State private var testing = false

    var body: some View {
        Form {
            Section(header: Text("AI")) {
                Toggle("Use AI (off = built-in rule-based logic only, nothing leaves this Mac)", isOn: Binding(
                    get: { manager.aiEnabled },
                    set: { manager.setAIEnabled($0) }))
                Text("When AI is off or no backend answers, every country, advisor and commentary line uses the game's own scripted logic. A failed AI call never costs a turn.")
                    .font(.scaled(.caption))
                    .foregroundColor(.secondary)
            }

            Section(header: Text("Backend")) {
                ScaledLabeledRow("Backend") {
                    ScaledMenuPicker(selection: $manager.selectedBackend,
                                     options: LLMBackendType.pickerCases.map { ($0, $0.displayName) })
                        .frame(width: FontScale.of(240))
                }
                .onChange(of: manager.selectedBackend) { _ in
                    manager.saveSettings()
                    Task { await manager.checkBackendAvailability() }
                }
                Text(manager.selectedBackend.description)
                    .font(.scaled(.caption))
                    .foregroundColor(.secondary)
                AIStatusLine(manager: manager)
                HStack {
                    Button(manager.isChecking ? "Checking…" : "Refresh Status") {
                        Task { await manager.checkBackendAvailability() }
                    }
                    .disabled(manager.isChecking)
                    Button(testing ? "Testing…" : "Test Connection") {
                        testing = true
                        Task { await manager.testConnection(); testing = false }
                    }
                    .disabled(testing || !manager.aiEnabled)
                }
                if let result = manager.lastTestResult {
                    Text(result).font(.scaled(.caption)).foregroundColor(.secondary)
                }
                ForEach(LLMBackendType.pickerCases.filter { $0 != .auto }, id: \.self) { backend in
                    HStack {
                        Image(systemName: backend.icon)
                        Text(backend.displayName)
                        Spacer()
                        Text(manager.isAvailable(backend) ? "Available" : (backend.needsAPIKey ? "No key" : "Unreachable"))
                            .foregroundColor(manager.isAvailable(backend) ? .green : .secondary)
                    }
                }
            }

            Section(header: Text("Local servers")) {
                urlField("Ollama URL", text: $manager.ollamaBaseURL)
                if !manager.ollamaModels.isEmpty {
                    ScaledLabeledRow("Ollama model") {
                        ScaledMenuPicker(selection: $manager.selectedOllamaModel, options: manager.ollamaModels.map { ($0, $0) })
                            .frame(width: FontScale.of(260))
                    }
                    .onChange(of: manager.selectedOllamaModel) { _ in manager.saveSettings() }
                } else {
                    TextField("Ollama model", text: $manager.selectedOllamaModel)
                        .onSubmit { manager.saveSettings() }
                }
                urlField("TinyLLM URL", text: $manager.tinyLLMServerURL)
                urlField("TinyChat URL", text: $manager.tinyChatServerURL)
                urlField("OpenWebUI URL", text: $manager.openWebUIServerURL)
                urlField("Nova Gateway URL", text: $manager.novaGatewayURL)
                TextField("Nova Gateway model", text: $manager.novaGatewayModel)
                    .onSubmit { manager.saveSettings() }
                #if os(macOS)
                TextField("Python path (MLX)", text: $manager.pythonPath)
                    .onSubmit { manager.saveSettings() }
                TextField("MLX model", text: $manager.mlxModel)
                    .onSubmit { manager.saveSettings() }
                #endif
            }

            Section(header: Text("Cloud keys (stored only in the Keychain, sent only over https)")) {
                keyRow(title: "OpenRouter API key", draft: $openRouterKeyDraft, has: manager.hasOpenRouterKey, slot: .openRouter)
                TextField("OpenRouter model (e.g. anthropic/claude-sonnet-4.5)", text: $manager.openRouterModel)
                    .onSubmit { manager.saveSettings() }
                Text("OpenRouter also powers the \"Frontier Models\" country brains. Without a key those brains stay rule-based and nothing is sent.")
                    .font(.scaled(.caption))
                    .foregroundColor(.secondary)
                keyRow(title: "OpenAI API key", draft: $openAIKeyDraft, has: manager.hasOpenAIKey, slot: .openAI)
                TextField("OpenAI model", text: $manager.openAIModel)
                    .onSubmit { manager.saveSettings() }
            }

            Section(header: Text("Setup")) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ollama: brew install ollama · ollama serve · ollama pull llama3.2")
                    Text("TinyLLM / TinyChat by Jason Cox: github.com/jasonacox/TinyLLM, github.com/jasonacox/tinychat")
                    Text("OpenWebUI: github.com/open-webui/open-webui")
                    Text("MLX (macOS): pip install mlx-lm")
                    Text("Claude: choose Nova Gateway, or OpenRouter with an anthropic/claude-* model")
                }
                .font(.scaled(.caption))
                .foregroundColor(.secondary)
            }
        }
        .frame(minWidth: FontScale.w(600), minHeight: FontScale.h(600))
        .padding()
        .onDisappear { manager.saveSettings() }   // URL/model edits persist even without pressing Return
    }

    private func urlField(_ title: String, text: Binding<String>) -> some View {
        HStack {
            TextField(title, text: text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onSubmit {
                    manager.saveSettings()
                    Task { await manager.checkBackendAvailability() }
                }
            if !AIEndpointPolicy.isValidServerURL(text.wrappedValue) {
                Text("invalid URL").font(.scaled(.caption)).foregroundColor(.red)
            }
        }
    }

    private func keyRow(title: String, draft: Binding<String>, has: Bool, slot: AIKeyStore.Slot) -> some View {
        HStack {
            SecureField(has ? "\(title) (saved — type to replace)" : title, text: draft)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onSubmit { save(draft, slot) }
            Button("Save") { save(draft, slot) }
                .disabled(draft.wrappedValue.trimmingCharacters(in: .whitespaces).isEmpty)
            if has {
                Button("Remove") { manager.setAPIKey("", for: slot) }
            }
        }
    }

    private func save(_ draft: Binding<String>, _ slot: AIKeyStore.Slot) {
        manager.setAPIKey(draft.wrappedValue, for: slot)
        draft.wrappedValue = ""   // never keep the secret in view state
    }
}

/// "● Active: Ollama (reachable)" — shared by Settings and the AI menu.
struct AIStatusLine: View {
    @ObservedObject var manager: AIBackendManager

    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: FontScale.w(10), height: FontScale.h(10))
            Text(AIStatusText.line(enabled: manager.aiEnabled, active: manager.activeBackend))
                .foregroundColor(color)
        }
    }

    private var color: Color {
        !manager.aiEnabled ? .secondary : (manager.activeBackend != nil ? .green : .red)
    }
}

enum AIStatusText {
    /// PURE: the one status string the UI shows.
    static func line(enabled: Bool, active: LLMBackendType?) -> String {
        guard enabled else { return "AI off — built-in logic" }
        guard let active else { return "No backend reachable — built-in logic" }
        return "Active: \(active.displayName) (reachable)"
    }
}

/// Items for the menu-bar "AI" menu: on/off, live status, test.
struct AIStatusMenuItems: View {
    @ObservedObject var manager = AIBackendManager.shared

    var body: some View {
        Toggle("Use AI", isOn: Binding(get: { manager.aiEnabled }, set: { manager.setAIEnabled($0) }))
        Text(AIStatusText.line(enabled: manager.aiEnabled, active: manager.activeBackend))
        Button("Test Connection") { Task { await manager.testConnection() } }
            .disabled(!manager.aiEnabled)
        if let result = manager.lastTestResult {
            Text(result)
        }
    }
}

#if DEBUG
struct AIBackendSettingsView_Previews: PreviewProvider {
    static var previews: some View { AIBackendSettingsView() }
}
#endif
