import SwiftUI
import Sparkle

@main
struct ShellmateApp: App {
    @State private var appState = AppState()
    @State private var aiConfig = AIConfigState()
    @State private var toolingState = ToolingState()
    // BRIDGE: NSApplicationDelegate for dock click, termination cleanup
    @NSApplicationDelegateAdaptor(AppLifecycleManager.self) private var lifecycleManager
    @StateObject private var updateService = SparkleUpdateService()

    var body: some Scene {
        Window("Shellmate", id: "main") {
            ContentView()
                .environment(appState)
                .environment(aiConfig)
                .environment(toolingState)
                .environmentObject(updateService)
                .frame(minWidth: 800, minHeight: 600)
                .onAppear {
                    // BRIDGE: NSWindow.setFrameAutosaveName for window position persistence
                    WindowManager.configureMainWindow()
                }
        }
        .defaultSize(width: 1200, height: 800)
        .commands {
            // App menu: Check for Updates (About is automatic)
            CommandGroup(after: .appInfo) {
                CheckForUpdatesButton(updateService: updateService)
            }

            // SwiftUI provides standard Edit menu (Undo/Redo/Cut/Copy/Paste/Select All)
            // automatically when text fields are focused.

            // Custom chat commands
            CommandGroup(after: .newItem) {
                Button("New Chat") {
                    NotificationCenter.default.post(name: .shellmateNewChat, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("Clear Chat") {
                    NotificationCenter.default.post(name: .shellmateClearChat, object: nil)
                }
                .keyboardShortcut("k", modifiers: .command)
            }

            // Help menu
            CommandGroup(replacing: .help) {
                Button("Shellmate Help") {
                    ExternalLinkHandler.open("https://github.com/adamlsneed/shellmate")
                }

                Button("Report an Issue") {
                    ExternalLinkHandler.open("https://github.com/adamlsneed/shellmate/issues/new")
                }
            }
        }

        Settings {
            SettingsView()
                .environment(appState)
                .environment(aiConfig)
                .environment(toolingState)
                .environmentObject(updateService)
        }
    }
}

/// Menu item that triggers Sparkle update check with proper enabled state.
struct CheckForUpdatesButton: View {
    @ObservedObject var updateService: SparkleUpdateService

    var body: some View {
        Button("Check for Updates\u{2026}", action: updateService.checkForUpdates)
            .disabled(!updateService.canCheckForUpdates)
    }
}

// MARK: - Notification names for menu commands

extension Notification.Name {
    /// Posted when the user selects New Chat (Cmd+N) from the menu.
    static let shellmateNewChat = Notification.Name("shellmateNewChat")

    /// Posted when the user selects Clear Chat (Cmd+K) from the menu.
    static let shellmateClearChat = Notification.Name("shellmateClearChat")
}
