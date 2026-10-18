//
//  GameStoreViews.swift
//  Global Thermal Nuclear War
//
//  The top-bar storage indicator (online / offline / syncing / local) in both skins, and the
//  "Saves & DB" settings tab (host/port override, reconnect, counts). No secrets are shown or edited here:
//  the password stays in the Keychain.
//

import SwiftUI

struct StoreStatusBadge: View {
    @ObservedObject var store: GameStoreService = .shared

    var body: some View {
        let (color, icon) = style
        HStack(spacing: 4) {
            Image(systemName: icon).font(.scaled(size: 10, weight: .bold))
            Text(store.status.shortLabel).font(ThemeFont.mono(10, .bold))
        }
        .foregroundColor(Theme.isRetro ? EGA.black : color)
        .padding(.horizontal, 6).padding(.vertical, 3)
        .background(Theme.isRetro ? AnyView(Rectangle().fill(color)) : AnyView(Capsule().stroke(color, lineWidth: 1)))
        .help(store.status.detail)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Storage: \(store.status.detail)")
    }

    private var style: (Color, String) {
        switch store.status {
        case .online: return (Theme.isRetro ? EGA.lightGreen : GTNWColors.terminalGreen, "checkmark.icloud")
        case .syncing: return (Theme.isRetro ? EGA.lightCyan : GTNWColors.neonCyan, "arrow.triangle.2.circlepath")
        case .offline: return (Theme.isRetro ? EGA.yellow : GTNWColors.terminalAmber, "icloud.slash")
        case .localOnly: return (Theme.isRetro ? EGA.lightGray : Color.gray, "internaldrive")
        }
    }
}

#if os(macOS)
struct GameStoreSettingsView: View {
    @ObservedObject var store: GameStoreService = .shared
    @State private var config = GameStoreConfig.load()
    @State private var portText = ""
    @State private var counts: StoreCounts?
    @State private var message = ""
    @State private var pasted = ""
    @State private var pasteRole = "gtnw"
    @State private var hasPassword = KeychainGameStoreCredentials().password(account: GameStoreConfig.load().user) != nil

    var body: some View {
        Form {
            Section("Games DB") {
                Toggle("Sync saves, leaderboard and history to the Games DB", isOn: $config.enabled).toggleStyle(.scaledCheckbox)
                TextField("Host", text: $config.host)
                TextField("Port", text: $portText)
                TextField("TLS server name", text: $config.tlsServerName)
                Text("CA: bundled games-pg CA, or \(GameStoreCA.overrideURL.path).")
                    .font(.scaled(.caption)).foregroundColor(.secondary)
                HStack {
                    Button("Save & Reconnect") { apply() }
                    Button("Reset to defaults") { config = .defaults; portText = String(config.port) }
                    Spacer()
                    StoreStatusBadge(store: store)
                }
                Text(store.status.detail).font(.scaled(.caption))
                if !message.isEmpty { Text(message).font(.scaled(.caption)).foregroundColor(.red) }
            }
            Section("Credentials (one-time setup)") {
                Text(hasPassword ? "Password for \(config.user) is in GTNW's keychain." : "Not set up yet: GTNW saves on this device only.")
                    .font(.scaled(.caption))
                HStack {
                    Button("Fetch from core3 (SSH)") { fetchFromCore3() }
                    Text("runs remote.sh getpw over ssh -o BatchMode=yes").font(.scaled(.caption2)).foregroundColor(.secondary)
                }
                HStack {
                    ScaledMenuPicker(selection: $pasteRole, options: [("gtnw", "gtnw"), ("gtnw_owner", "gtnw_owner")])
                        .frame(width: FontScale.of(130))
                    SecureField("or paste (deploy.sh macpw gtnw | pbcopy)", text: $pasted)
                    Button("Store") { storePasted() }.disabled(pasted.isEmpty)
                }
            }
            Section("On this device") {
                Text("Pending changes: \(store.pendingCount)")
                if let counts { Text("Local cache: \(counts.description)").font(.scaled(.caption)) }
            }
        }
        .padding()
        .frame(width: FontScale.w(520))
        .onAppear {
            portText = String(config.port)
            Task { counts = try? await store.local.counts() }
        }
    }

    private func fetchFromCore3() {
        message = "Fetching..."
        Task.detached {
            let result: String
            do { result = "Stored: " + (try GameStoreSetup.fetchFromCore3()).joined(separator: ", ") } catch { result = "\(error)" }
            await MainActor.run { message = result; refreshAfterCredentials() }
        }
    }

    private func storePasted() {
        do { try KeychainGameStoreCredentials().store(GameStoreSetup.clean(pasted), account: pasteRole); message = "Stored \(pasteRole)" }
        catch { message = "\(error)" }
        pasted = ""
        refreshAfterCredentials()
    }

    private func refreshAfterCredentials() {
        hasPassword = KeychainGameStoreCredentials().password(account: config.user) != nil
        store.reconfigure(config)
    }

    private func apply() {
        var c = config
        c.host = c.host.trimmingCharacters(in: .whitespaces)
        c.tlsServerName = c.tlsServerName.trimmingCharacters(in: .whitespaces)
        guard let port = Int(portText) else { message = "Port must be a number"; return }
        c.port = port
        do { try c.validate() } catch { message = "\(error)"; return }
        message = ""
        c.save()
        config = c
        store.reconfigure(c)
    }
}
#endif
