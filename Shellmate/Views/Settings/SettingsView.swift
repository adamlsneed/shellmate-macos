import SwiftUI

/// macOS Settings scene (⌘,) — placeholder to be fully built by UI agent.
struct SettingsView: View {
    @Environment(AIConfigState.self) private var aiConfig

    var body: some View {
        TabView {
            connectionSettings
                .tabItem { Label("Connection", systemImage: "network") }

            themeSettings
                .tabItem { Label("Appearance", systemImage: "paintbrush") }

            advancedSettings
                .tabItem { Label("Advanced", systemImage: "gearshape") }
        }
        .frame(width: 500, height: 350)
    }

    private var connectionSettings: some View {
        Form {
            Section("AI Provider") {
                Picker("Provider", selection: Binding(
                    get: { aiConfig.provider },
                    set: { aiConfig.provider = $0 }
                )) {
                    ForEach(AIProvider.allCases, id: \.self) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                TextField("Model", text: Binding(
                    get: { aiConfig.model },
                    set: { aiConfig.model = $0 }
                ))
            }
        }
        .padding()
    }

    private var themeSettings: some View {
        Form {
            Section("Appearance") {
                Text("Theme follows system appearance")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }

    private var advancedSettings: some View {
        Form {
            Section("Configuration") {
                Text("~/.shellmate/shellmate.json")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}
