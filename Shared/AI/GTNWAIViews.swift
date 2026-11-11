//
//  GTNWAIViews.swift
//  Global Thermal Nuclear War
//
//  GTNW's AI screens, built from NovaAIKit's drop-in views: the Settings → AI tab, the menu-bar "AI" menu items
//  and the command-center toolbar (status dot + backend + model).
//
//  Created by Jordan Koch on 2026.
//

import SwiftUI
import NovaAIKit

/// Text shown under the settings and in the menu when the game explains its fallback.
enum GTNWAICopy {
    static let footer = "When AI is off or nothing answers, GTNW plays every country with its built-in rule-based AI "
        + "and Nova uses her template lines. Nothing leaves this Mac. Per-country brains: Command Center → Brains."
}

/// Settings → AI.
struct GTNWAISettingsView: View {
    @ObservedObject var ai: NovaAI

    @MainActor init() { self.ai = AppAI.shared }
    init(ai: NovaAI) { self.ai = ai }

    var body: some View {
        NovaAISettingsView(ai: ai, footer: GTNWAICopy.footer)
            .frame(minWidth: FontScale.w(520), minHeight: FontScale.h(560))
    }
}

/// Items for the menu-bar "AI" menu: on/off, live status, re-check.
struct AIStatusMenuItems: View {
    @ObservedObject var ai: NovaAI

    @MainActor init() { self.ai = AppAI.shared }
    init(ai: NovaAI) { self.ai = ai }

    var body: some View {
        Toggle("Use AI", isOn: $ai.settings.enabled)
        Text(ai.status.label)
        Button("Test Connection") { Task { await ai.refreshStatus() } }
            .disabled(!ai.isEnabled)
    }
}

/// Command-center toolbar: status indicator, backend picker and (for Ollama) the model picker.
struct AIBackendToolbar: View {
    @ObservedObject var ai: NovaAI
    @State private var ollamaModels: [String] = []

    @MainActor init() { self.ai = AppAI.shared }
    init(ai: NovaAI) { self.ai = ai }

    private var tint: Color { ai.status.isReachable ? GTNWColors.terminalGreen : (ai.isEnabled ? GTNWColors.terminalRed : .gray) }

    var body: some View {
        HStack(spacing: 12) {
            NovaAIStatusIndicator(ai: ai, showsLabel: false, checksOnAppear: false)
            Menu {
                Toggle("Use AI", isOn: $ai.settings.enabled)
                Divider()
                ForEach(NovaAIBackend.selectable.filter(\.isSupportedOnThisPlatform)) { backend in
                    Button {
                        ai.settings.backend = backend
                        Task { await ai.refreshStatus() }
                    } label: {
                        HStack {
                            Text(backend.displayName)
                            if ai.status.reachability[backend] == true { Text("●") }
                            if ai.settings.backend == backend { Image(systemName: "checkmark") }
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "brain.head.profile").font(.scaled(size: 12))
                    Text(ai.isEnabled ? ai.settings.backend.displayName : "AI Off")
                        .font(.scaled(size: 11, weight: .semibold, design: .monospaced))
                }
                .foregroundColor(tint)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.05))
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(tint, lineWidth: 1))
            }
            .help(ai.status.label)

            if ai.isEnabled && ai.settings.backend == .ollama && !ollamaModels.isEmpty {
                Menu {
                    ForEach(ollamaModels, id: \.self) { model in
                        Button {
                            ai.settings.setModel(model, for: .ollama)
                        } label: {
                            HStack {
                                Text(model)
                                if ai.settings.model(for: .ollama) == model { Image(systemName: "checkmark") }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "cpu").font(.scaled(size: 12))
                        Text(ai.settings.model(for: .ollama))
                            .font(.scaled(size: 11, weight: .semibold, design: .monospaced))
                            .lineLimit(1)
                    }
                    .foregroundColor(GTNWColors.neonCyan)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(GTNWColors.neonCyan, lineWidth: 1))
                }
                .help("Ollama Model")
            }
        }
        .task(id: ai.settings.backend) {
            guard ai.isEnabled, ai.settings.backend == .ollama else { return }
            ollamaModels = await ai.listModels(for: .ollama)
        }
    }
}
