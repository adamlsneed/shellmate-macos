import SwiftUI
struct PreflightView: View {
    @Environment(AppState.self) private var appState
    @State private var migrationService = MigrationService(); @State private var showMigration = false; @State private var isChecking = true
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "terminal.fill").font(.system(size: 56)).foregroundStyle(ShellmateColors.accent)
            Text("Welcome to Shellmate").font(.largeTitle.bold()).foregroundStyle(ShellmateColors.textPrimary)
            Text("Your personal AI helper for Mac").font(.title3).foregroundStyle(ShellmateColors.textSecondary)
            if isChecking { ProgressView("Checking setup...").foregroundStyle(ShellmateColors.textSecondary) }
            else if showMigration { migCard } else { pathPicker }
        }.padding(40).frame(maxWidth: .infinity, maxHeight: .infinity).background(ShellmateColors.background)
        .task { if migrationService.needsMigration { showMigration = true }; isChecking = false }
    }
    private var migCard: some View {
        VStack(spacing: 16) { Text("Found existing OpenClaw configuration").font(.headline).foregroundStyle(ShellmateColors.textPrimary)
            HStack(spacing: 12) { Button("Migrate") { try? migrationService.migrate(); Task { await appState.checkSetupStatus() } }.buttonStyle(.borderedProminent).tint(ShellmateColors.accent); Button("Start Fresh") { appState.startWizard() }.buttonStyle(.bordered) }
        }.padding(24).background(ShellmateColors.surface).clipShape(RoundedRectangle(cornerRadius: 12))
    }
    private var pathPicker: some View {
        VStack(spacing: 20) {
            Text("How would you like to set up?").font(.title3).foregroundStyle(ShellmateColors.textSecondary)
            VStack(spacing: 12) {
                pb(t: "Quick Setup", s: "A short conversation. Best for most people.", i: "sparkles", b: "Recommended") { NotificationCenter.default.post(name: .shellmateSimpleMode, object: nil); appState.startWizard() }
                pb(t: "Detailed Setup", s: "Full control over every setting.", i: "slider.horizontal.3", b: nil) { appState.startWizard() }
            }.frame(maxWidth: 420)
        }
    }
    private func pb(t: String, s: String, i: String, b: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) { HStack(spacing: 16) { Image(systemName: i).font(.title2).foregroundStyle(ShellmateColors.accent).frame(width: 36); VStack(alignment: .leading, spacing: 4) { HStack(spacing: 8) { Text(t).font(.body.bold()).foregroundStyle(ShellmateColors.textPrimary); if let b { Text(b).font(.caption2).padding(.horizontal, 6).padding(.vertical, 2).background(ShellmateColors.shell600.opacity(0.3)).foregroundStyle(ShellmateColors.shell300).clipShape(Capsule()) } }; Text(s).font(.caption).foregroundStyle(ShellmateColors.textMuted).fixedSize(horizontal: false, vertical: true) }; Spacer(); Image(systemName: "chevron.right").font(.caption).foregroundStyle(ShellmateColors.textMuted) }.padding(16).background(ShellmateColors.surface).clipShape(RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(ShellmateColors.navy700, lineWidth: 1)).contentShape(Rectangle()) }.buttonStyle(.plain)
    }
}
extension Notification.Name { static let shellmateSimpleMode = Notification.Name("shellmateSimpleMode") }
