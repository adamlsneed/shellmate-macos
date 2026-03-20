import AppKit
import SwiftUI

/// Settings tab showing system permission statuses, tool category toggles,
/// and auto-approve preferences. All changes persist to shellmate.json.
struct CapabilitiesSettingsView: View {
    @State private var enabledCategories: Set<String> = Set(ToolCategory.allCases.map(\.rawValue))
    @State private var autoApproveCategories: Set<String> = []

    private let configService = ConfigService()

    var body: some View {
        Form {
            Section("Permissions") {
                ForEach(SystemPermission.allCases, id: \.rawValue) { permission in
                    HStack {
                        Text(permission.displayName)
                        Spacer()
                        Text("Not Asked")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                        Button("Open Settings") {
                            if let url = URL(string: permission.settingsPaneURL) {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)
                    }
                }
            }

            Section("Tool Categories") {
                ForEach(ToolCategory.allCases, id: \.rawValue) { category in
                    Toggle(
                        category.displayName,
                        isOn: Binding(
                            get: { enabledCategories.contains(category.rawValue) },
                            set: { enabled in
                                if enabled {
                                    enabledCategories.insert(category.rawValue)
                                } else {
                                    enabledCategories.remove(category.rawValue)
                                    autoApproveCategories.remove(category.rawValue)
                                }
                                saveToConfig()
                            }
                        )
                    )
                }
            }

            Section("Auto-Approve") {
                Text("Skip confirmation for these categories. Destructive actions always require approval.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(ToolCategory.allCases, id: \.rawValue) { category in
                    if enabledCategories.contains(category.rawValue) {
                        Toggle(
                            category.displayName,
                            isOn: Binding(
                                get: { autoApproveCategories.contains(category.rawValue) },
                                set: { approved in
                                    if approved {
                                        autoApproveCategories.insert(category.rawValue)
                                    } else {
                                        autoApproveCategories.remove(category.rawValue)
                                    }
                                    saveToConfig()
                                }
                            )
                        )
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { loadFromConfig() }
    }

    private func loadFromConfig() {
        guard let config = try? configService.readConfig() else { return }
        enabledCategories = Set(config.capabilities.enabledCategories)
        autoApproveCategories = Set(config.capabilities.autoApproveCategories)
    }

    private func saveToConfig() {
        try? configService.patchConfig { config in
            config.capabilities.enabledCategories = Array(enabledCategories).sorted()
            config.capabilities.autoApproveCategories = Array(autoApproveCategories).sorted()
        }
    }
}
