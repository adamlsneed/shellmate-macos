import AppKit
import SwiftUI

// MARK: - CapabilitiesSettingsView

/// Settings tab showing system permission statuses and tool category toggles.
struct CapabilitiesSettingsView: View {
    @State private var enabledCategories: Set<String> = Set(ToolCategory.allCases.map(\.rawValue))

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
                                }
                            }
                        )
                    )
                }
            }
        }
        .formStyle(.grouped)
    }
}
