import SwiftUI
struct AISetupView: View {
    @Environment(AIConfigState.self) private var aiConfig
    var onDone: () -> Void
    @State private var selectedProvider: AIProvider = .anthropic
    @State private var apiKey = ""; @State private var isTesting = false; @State private var error: String?; @State private var showGuide = true
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) { Text("Connect an AI model").font(.headline).foregroundStyle(ShellmateColors.textPrimary); Text("You need an API key from one of these providers.").font(.subheadline).foregroundStyle(ShellmateColors.textSecondary) }
            HStack(spacing: 8) { ForEach(AIProvider.allCases, id: \.self) { p in
                Button(action: { selectedProvider = p; apiKey = ""; error = nil }) {
                    Text(p.displayName).font(.subheadline.bold()).frame(maxWidth: .infinity).padding(.vertical, 10)
                    .background(selectedProvider == p ? ShellmateColors.shell600.opacity(0.2) : ShellmateColors.navy800)
                    .foregroundStyle(selectedProvider == p ? ShellmateColors.textPrimary : ShellmateColors.textSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(selectedProvider == p ? ShellmateColors.shell500 : ShellmateColors.navy700, lineWidth: 1))
                }.buttonStyle(.plain)
            } }
            SecureField(selectedProvider == .anthropic ? "sk-ant-api03-..." : "sk-proj-...", text: $apiKey)
                .textFieldStyle(.plain).font(.system(.body, design: .monospaced)).foregroundStyle(ShellmateColors.textPrimary)
                .padding(12).background(ShellmateColors.navy800).clipShape(RoundedRectangle(cornerRadius: 10)).onSubmit { handleConnect() }
            Text("Stored securely in Keychain.").font(.caption2).foregroundStyle(ShellmateColors.textMuted)
            if let error { Text(error).font(.caption).foregroundStyle(ShellmateColors.error).padding(8).background(ShellmateColors.error.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 8)) }
            BigButton(isTesting ? "Testing..." : "Connect", icon: "arrow.right", action: handleConnect)
                .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isTesting)
                .opacity(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isTesting ? 0.5 : 1)
        }.padding(24).background(ShellmateColors.surface).clipShape(RoundedRectangle(cornerRadius: 12)).frame(maxWidth: 480)
        .task { if let k = aiConfig.resolveApiKey(), !k.isEmpty { aiConfig.isConfigured = true; onDone() } }
    }
    private func handleConnect() {
        let k = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !k.isEmpty else { return }
        isTesting = true
        error = nil
        aiConfig.provider = selectedProvider
        aiConfig.model = selectedProvider.defaultModel
        Task {
            await aiConfig.saveAndValidateKey(k)
            isTesting = false
            if aiConfig.isConfigured {
                onDone()
            } else {
                error = aiConfig.keyValidationError ?? "API key validation failed"
            }
        }
    }
}
