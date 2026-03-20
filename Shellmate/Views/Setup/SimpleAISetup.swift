import SwiftUI
struct SimpleAISetup: View {
    @Environment(AIConfigState.self) private var aiConfig; var onDone: () -> Void
    enum SetupPath { case choose, signIn, code }
    @State private var path: SetupPath = .choose; @State private var accessCode = ""; @State private var isTesting = false; @State private var error: String?
    var body: some View {
        Group { switch path { case .choose: choosePath; case .signIn: signInPath; case .code: codePath } }
            .frame(maxWidth: .infinity, maxHeight: .infinity).background(ShellmateColors.background)
            .task { if let k = aiConfig.resolveApiKey(), !k.isEmpty { aiConfig.isConfigured = true; onDone() } }
    }
    private var choosePath: some View {
        VStack(spacing: 24) {
            Image(systemName: "terminal.fill").font(.system(size: 56)).foregroundStyle(ShellmateColors.accent)
            Text("Welcome to Shellmate").font(.largeTitle.bold()).foregroundStyle(ShellmateColors.textPrimary)
            Text("Pick how to connect:").font(.title3).foregroundStyle(ShellmateColors.textSecondary)
            VStack(spacing: 12) {
                pBtn(title: "Sign in with Claude", sub: "Use your Claude Pro/Max account") { path = .signIn }
                pBtn(title: "I have an access code", sub: "Someone gave me a code") { path = .code }
            }.frame(maxWidth: 360)
        }.padding(40)
    }
    private var signInPath: some View {
        VStack(spacing: 24) {
            Image(systemName: "terminal.fill").font(.system(size: 56)).foregroundStyle(ShellmateColors.accent)
            Text("Sign in with Claude").font(.title2.bold()).foregroundStyle(ShellmateColors.textPrimary)
            VStack(alignment: .leading, spacing: 16) { ns(1,"Go to console.anthropic.com and create an account."); ns(2,"Click API Keys in the sidebar."); ns(3,"Click Create Key, name it, copy it."); ns(4,"Paste below.") }.frame(maxWidth: 440)
            keySection; bBtn
        }.padding(40)
    }
    private var codePath: some View {
        VStack(spacing: 24) {
            Image(systemName: "terminal.fill").font(.system(size: 56)).foregroundStyle(ShellmateColors.accent)
            Text("Enter your access code").font(.title2.bold()).foregroundStyle(ShellmateColors.textPrimary)
            keySection; bBtn
        }.padding(40)
    }
    private var keySection: some View {
        VStack(spacing: 12) {
            SecureField("Paste your key here", text: $accessCode).textFieldStyle(.plain).font(.body).foregroundStyle(ShellmateColors.textPrimary).padding(14).background(ShellmateColors.surface).clipShape(RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(ShellmateColors.navy700, lineWidth: 2)).onSubmit { connect() }.frame(maxWidth: 360)
            if let error { Text(error).font(.callout).foregroundStyle(ShellmateColors.error).padding(12).frame(maxWidth: 360, alignment: .leading).background(ShellmateColors.error.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 10)) }
            BigButton(isTesting ? "Connecting..." : "Connect", icon: "arrow.right", action: connect).disabled(accessCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isTesting).opacity(accessCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isTesting ? 0.5 : 1).frame(maxWidth: 360)
        }
    }
    private var bBtn: some View { Button("Go back") { path = .choose; error = nil; accessCode = "" }.font(.callout).foregroundStyle(ShellmateColors.accent).buttonStyle(.plain) }
    private func pBtn(title: String, sub: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { VStack(alignment: .leading, spacing: 4) { Text(title).font(.body.bold()).foregroundStyle(ShellmateColors.textPrimary); Text(sub).font(.caption).foregroundStyle(ShellmateColors.textMuted) }.frame(maxWidth: .infinity, alignment: .leading).padding(16).background(ShellmateColors.surface).clipShape(RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(ShellmateColors.navy700, lineWidth: 2)) }.buttonStyle(.plain)
    }
    private func ns(_ n: Int, _ t: String) -> some View {
        HStack(alignment: .top, spacing: 12) { Text("\(n)").font(.callout.bold()).foregroundStyle(.white).frame(width: 32, height: 32).background(ShellmateColors.accent).clipShape(Circle()); Text(t).font(.callout).foregroundStyle(ShellmateColors.textSecondary).fixedSize(horizontal: false, vertical: true) }
    }
    private func connect() {
        let k = accessCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !k.isEmpty else { return }
        isTesting = true
        error = nil
        let p: AIProvider = k.hasPrefix("sk-ant-") ? .anthropic : .openai
        aiConfig.provider = p
        aiConfig.model = p.defaultModel
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
