import SwiftUI
struct SettingsView: View {
    @Environment(AIConfigState.self) private var aiConfig
    var body: some View {
        TabView {
            connTab.tabItem { Label("Connection", systemImage: "network") }
            permsTab.tabItem { Label("Permissions", systemImage: "lock.shield") }
            appearTab.tabItem { Label("Appearance", systemImage: "paintbrush") }
            advTab.tabItem { Label("Advanced", systemImage: "gearshape") }
        }.frame(width: 520, height: 420)
    }
    @State private var newKey = ""; @State private var hasKey = false; @State private var keySaved = false
    private var connTab: some View {
        Form {
            Section("AI Provider") {
                Picker("Provider", selection: Binding(get: { aiConfig.provider }, set: { aiConfig.provider = $0 })) { ForEach(AIProvider.allCases, id: \.self) { Text($0.displayName).tag($0) } }.pickerStyle(.segmented)
                TextField("Model", text: Binding(get: { aiConfig.model }, set: { aiConfig.model = $0 })).font(.system(.body, design: .monospaced))
                Text("Default: \(aiConfig.provider.defaultModel)").font(.caption).foregroundStyle(.secondary)
            }
            Section("API Key") {
                if hasKey { HStack(spacing: 6) { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green); Text("Configured").foregroundStyle(.secondary) } } else { Text("Not set").foregroundStyle(.secondary) }
                HStack { SecureField("New API key...", text: $newKey).textFieldStyle(.roundedBorder)
                    Button("Save") { let t = newKey.trimmingCharacters(in: .whitespacesAndNewlines); guard !t.isEmpty else { return }; KeychainHelper.save(service: "com.shellmate.api", account: aiConfig.provider.rawValue, value: t); aiConfig.isConfigured = true; hasKey = true; keySaved = true; newKey = "" }.disabled(newKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
                if keySaved { Text("Saved to Keychain").font(.caption).foregroundStyle(.green) }
                Button("Remove key", role: .destructive) { KeychainHelper.delete(service: "com.shellmate.api", account: aiConfig.provider.rawValue); hasKey = false }.font(.caption)
            }
        }.padding().onAppear { hasKey = aiConfig.resolveApiKey() != nil }
    }
    @State private var aE = true; @State private var aW = true; @State private var aB = true; @State private var pSaved = false
    private var permsTab: some View {
        Form {
            Section("Tool Permissions") { Toggle("Run terminal commands", isOn: $aE); Toggle("Create and modify files", isOn: $aW); Toggle("Browse the web", isOn: $aB) }
            Section { Button("Save") { let cs = ConfigService(); guard var c = try? cs.readConfig() else { return }; var d: [String] = []; if !aE { d.append("exec") }; if !aW { d.append("write") }; if !aB { d.append("browser") }; c.capabilities.tools.deny = d; if let i = c.agents.list.firstIndex(where: { $0.id == "main" }) { c.agents.list[i].tools.deny = d }; try? cs.writeConfig(c); pSaved = true }; if pSaved { Text("Saved").font(.caption).foregroundStyle(.green) } }
        }.padding().onAppear { let cs = ConfigService(); guard let c = try? cs.readConfig() else { return }; let d = c.capabilities.tools.deny; aE = !d.contains("exec"); aW = !d.contains("write"); aB = !d.contains("browser") }
    }
    private var appearTab: some View { Form { Section("Theme") { Text("Follows system appearance.").foregroundStyle(.secondary) } }.padding() }
    // BRIDGE: NSWorkspace required for opening Finder
    private var advTab: some View {
        Form {
            Section("Configuration") { LabeledContent("Config") { Text("~/.shellmate/shellmate.json").font(.system(.body, design: .monospaced)).foregroundStyle(.secondary).textSelection(.enabled) }; Button("Open in Finder") { NSWorkspace.shared.open(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".shellmate")) } }
            Section("Reset") { Button("Reset Setup", role: .destructive) { let cs = ConfigService(); if var c = try? cs.readConfig() { c.setupComplete = false; try? cs.writeConfig(c) } } }
            Section("About") { LabeledContent("Version") { Text("0.0.1").foregroundStyle(.secondary) } }
        }.padding()
    }
}
