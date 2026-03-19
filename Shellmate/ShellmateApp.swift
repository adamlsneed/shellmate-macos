import SwiftUI
import Sparkle

@main
struct ShellmateApp: App {
    @State private var appState = AppState()
    @State private var aiConfig = AIConfigState()
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .environment(aiConfig)
                .frame(minWidth: 800, minHeight: 600)
        }
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updater: updaterController.updater)
            }
            CommandGroup(replacing: .help) {
                Link("Shellmate Help", destination: URL(string: "https://github.com/adamlsneed/shellmate")!)
            }
        }

        Settings {
            SettingsView()
                .environment(appState)
                .environment(aiConfig)
        }
    }
}

/// Sparkle "Check for Updates…" menu item
struct CheckForUpdatesView: View {
    let updater: SPUUpdater

    var body: some View {
        Button("Check for Updates…", action: updater.checkForUpdates)
    }
}
