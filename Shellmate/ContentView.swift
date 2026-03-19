import SwiftUI

/// Root view: routes between loading, preflight/wizard, and chat based on app state.
struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            switch appState.currentPhase {
            case .loading:
                LoadingView()
            case .preflight:
                PreflightView()
            case .wizard:
                WizardContainer()
            case .chat:
                ChatView()
            }
        }
        .background(ShellmateColors.navy950)
        .task {
            await appState.checkSetupStatus()
        }
    }
}

/// Simple loading state shown during initial setup check
struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Loading Shellmate…")
                .font(.headline)
                .foregroundStyle(ShellmateColors.shell400)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ShellmateColors.navy950)
    }
}
