import SwiftUI
struct DoneStep: View {
    @Environment(WizardState.self) private var wizardState; @Environment(AppState.self) private var appState; @Environment(AIConfigState.self) private var aiConfig
    @State private var checks: [ValidationCheck] = []; @State private var isValidating = true; @State private var allPassed = false; @State private var validated = false
    @State private var previewChat = ChatState()
    private let vs = ValidationService()
    var body: some View {
        VStack(spacing: 0) {
            ScrollView { VStack(alignment: .leading, spacing: 20) {
                if isValidating { HStack(spacing: 8) { LoadingSpinner(); Text("Validating...").font(.callout).foregroundStyle(ShellmateColors.textMuted) } }
                if validated && allPassed { banner("\(wizardState.agentSpec.name.isEmpty ? "Helper" : wizardState.agentSpec.name) is ready!", "All checks passed.", ShellmateColors.success) }
                if validated && !allPassed { banner("Some checks need attention", "Fix later.", ShellmateColors.warning) }
                if !checks.isEmpty { checksView }
                if validated { BigButton("Start chatting", icon: "arrow.right") { complete() } }
                previewSection
            }.padding(24) }
            HStack { Button("Start over") { wizardState.phase = .chat; wizardState.agentSpec = AgentSpec(); wizardState.conversationMessages = []; wizardState.generatedFiles = [] }.font(.caption).foregroundStyle(ShellmateColors.textMuted).buttonStyle(.plain); Spacer() }.padding(.horizontal, 24).padding(.vertical, 12)
        }.task { isValidating = true; checks = await vs.runAll(aiConfig: aiConfig); allPassed = checks.allSatisfy(\.passed); validated = true; isValidating = false }
    }
    private func banner(_ t: String, _ s: String, _ c: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) { Text(t).font(.callout.weight(.semibold)).foregroundStyle(c); Text(s).font(.caption).foregroundStyle(c.opacity(0.8)) }.padding(12).frame(maxWidth: .infinity, alignment: .leading).background(c.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 10))
    }
    private var checksView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) { Circle().fill(.red).frame(width: 10, height: 10); Circle().fill(.yellow).frame(width: 10, height: 10); Circle().fill(.green).frame(width: 10, height: 10); Text("checks").font(.system(.caption2, design: .monospaced)).foregroundStyle(ShellmateColors.textMuted).padding(.leading, 8) }.padding(.horizontal, 12).padding(.vertical, 8).background(ShellmateColors.navy900)
            Divider().background(ShellmateColors.navy700)
            VStack(alignment: .leading, spacing: 4) { ForEach(checks) { c in HStack(spacing: 8) { Text(c.passed ? "PASS" : "FAIL").font(.system(.caption, design: .monospaced).bold()).foregroundStyle(c.passed ? ShellmateColors.success : ShellmateColors.error).frame(width: 36, alignment: .leading); Text(c.name).font(.system(.caption, design: .monospaced)).foregroundStyle(ShellmateColors.textMuted); Text(c.detail).font(.system(.caption, design: .monospaced)).foregroundStyle(ShellmateColors.textSecondary) } } }.padding(12)
        }.background(ShellmateColors.navy950).clipShape(RoundedRectangle(cornerRadius: 10))
    }
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CHAT PREVIEW").font(.caption2.weight(.semibold)).foregroundStyle(ShellmateColors.textMuted).tracking(1)
            VStack(spacing: 0) {
                ScrollView { LazyVStack(alignment: .leading, spacing: 8) {
                    if previewChat.messages.isEmpty { Text("Say hello to test.").font(.caption).foregroundStyle(ShellmateColors.textMuted).frame(maxWidth: .infinity).padding(.top, 32) }
                    ForEach(previewChat.messages) { m in MessageBubble(message: m) }
                    if previewChat.isStreaming { BouncingDots().padding(8).background(ShellmateColors.navy800).clipShape(RoundedRectangle(cornerRadius: 12)) }
                }.padding(12) }.frame(minHeight: 150)
                Divider().background(ShellmateColors.navy700)
                HStack(spacing: 8) { TextField("Message...", text: $previewChat.inputText).textFieldStyle(.plain).font(.caption).foregroundStyle(ShellmateColors.textPrimary).padding(8).background(ShellmateColors.navy800).clipShape(RoundedRectangle(cornerRadius: 8)).onSubmit { sendPreview() }
                    Button(action: sendPreview) { Text("Send").font(.caption.bold()).foregroundStyle(.white).padding(.horizontal, 12).padding(.vertical, 8).background(ShellmateColors.shell600).clipShape(RoundedRectangle(cornerRadius: 8)) }.buttonStyle(.plain).disabled(previewChat.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }.padding(10)
            }.background(ShellmateColors.navy900.opacity(0.5)).clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
    private func complete() { let c = ConfigService(); if var cfg = try? c.readConfig() { cfg.setupComplete = true; try? c.writeConfig(cfg) }; appState.completeSetup() }
    private func sendPreview() {
        let t = previewChat.inputText.trimmingCharacters(in: .whitespacesAndNewlines); guard !t.isEmpty else { return }; previewChat.addUserMessage(t); guard let k = aiConfig.resolveApiKey() else { return }; previewChat.isStreaming = true
        Task { let r = AIRouter(); nonisolated(unsafe) let msgs: [[String: Any]] = previewChat.messages.map { ["role":$0.role.rawValue,"content":$0.content] }
            do { let resp = try await r.call(messages: msgs, system: GeneratorService.generateSystem(agent: wizardState.agentSpec), provider: aiConfig.provider, model: aiConfig.model, apiKey: k, maxTokens: 1024); await MainActor.run { previewChat.addAssistantMessage(resp.text); previewChat.isStreaming = false } }
            catch { await MainActor.run { previewChat.addAssistantMessage("Error: \(error.localizedDescription)"); previewChat.isStreaming = false } } }
    }
}
