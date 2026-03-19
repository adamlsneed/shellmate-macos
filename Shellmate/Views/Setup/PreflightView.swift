import SwiftUI

/// Preflight check: detects config, offers migration, routes to wizard.
struct PreflightView: View {
    @Environment(AppState.self) private var appState
    @State private var migrationService = MigrationService()
    @State private var showMigration = false
    @State private var isChecking = true

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "terminal.fill")
                .font(.system(size: 48))
                .foregroundStyle(ShellmateColors.accent)

            Text("Welcome to Shellmate")
                .font(.largeTitle.bold())
                .foregroundStyle(ShellmateColors.textPrimary)

            Text("Your personal AI helper for Mac")
                .font(.title3)
                .foregroundStyle(ShellmateColors.textSecondary)

            if isChecking {
                ProgressView("Checking setup…")
                    .foregroundStyle(ShellmateColors.textSecondary)
            } else if showMigration {
                migrationCard
            } else {
                setupButtons
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ShellmateColors.background)
        .task {
            await checkPreflight()
        }
    }

    private var migrationCard: some View {
        VStack(spacing: 16) {
            Text("Found existing OpenClaw configuration")
                .font(.headline)
                .foregroundStyle(ShellmateColors.textPrimary)
            Text("Would you like to migrate your settings to Shellmate?")
                .foregroundStyle(ShellmateColors.textSecondary)

            HStack(spacing: 12) {
                Button("Migrate") {
                    try? migrationService.migrate()
                    Task { await appState.checkSetupStatus() }
                }
                .buttonStyle(.borderedProminent)
                .tint(ShellmateColors.accent)

                Button("Start Fresh") {
                    appState.startWizard()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(24)
        .background(ShellmateColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var setupButtons: some View {
        VStack(spacing: 12) {
            Button(action: { appState.startWizard() }) {
                Label("Get Started", systemImage: "arrow.right.circle.fill")
                    .font(.title3)
                    .frame(maxWidth: 280)
            }
            .buttonStyle(.borderedProminent)
            .tint(ShellmateColors.accent)
            .controlSize(.large)
        }
    }

    private func checkPreflight() async {
        if migrationService.needsMigration {
            showMigration = true
        }
        isChecking = false
    }
}
