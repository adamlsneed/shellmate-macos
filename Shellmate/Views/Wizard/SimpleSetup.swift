import SwiftUI
struct SimpleSetup: View {
    @Environment(AppState.self) private var appState; @Environment(AIConfigState.self) private var aiConfig; @Environment(WizardState.self) private var wizardState
    enum Step { case auth, chat, finishing, ready, caps }
    @State private var step: Step = .auth; @State private var error: String?
    private let cs = ConfigService(); private let ws = WorkspaceService()
    var body: some View {
        Group { switch step { case .auth: SimpleAISetup(onDone: { step = .chat }); case .chat: chatStep; case .finishing: finishStep; case .ready: readyStep; case .caps: SimpleCapabilities(onDone: { done() }, onSkip: { done() }) } }.background(ShellmateColors.background)
        .onChange(of: aiConfig.isConfigured) { if aiConfig.isConfigured && step == .auth { step = .chat } }
    }
    private var chatStep: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) { Image(systemName: "terminal.fill").font(.system(size: 36)).foregroundStyle(ShellmateColors.accent); Text("Let's get to know you").font(.title2.bold()).foregroundStyle(ShellmateColors.textPrimary); Text("Just a few quick questions").font(.callout).foregroundStyle(ShellmateColors.textSecondary) }.padding(.top, 16).padding(.bottom, 8)
            ConversationPhase(simpleMode: true)
        }
    }
    private var finishStep: some View { VStack(spacing: 24) { LoadingSpinner().scaleEffect(2); Text("Setting things up...").font(.title2.bold()).foregroundStyle(ShellmateColors.textPrimary) }.frame(maxWidth: .infinity, maxHeight: .infinity) }
    private var readyStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "terminal.fill").font(.system(size: 56)).foregroundStyle(ShellmateColors.accent)
            Text("All set!").font(.largeTitle.bold()).foregroundStyle(ShellmateColors.textPrimary)
            Text("Shellmate is ready to help.").font(.title3).foregroundStyle(ShellmateColors.textSecondary)
            VStack(spacing: 12) { BigButton("Start chatting", icon: "arrow.right") { done() }
                Button(action: { step = .caps }) { Text("Set up extra features").font(.callout).foregroundStyle(ShellmateColors.textSecondary).padding(14).frame(maxWidth: .infinity).background(ShellmateColors.surface).clipShape(RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(ShellmateColors.navy700, lineWidth: 2)) }.buttonStyle(.plain)
            }.frame(maxWidth: 360)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    private func done() { var c: ShellmateConfig; do { c = try cs.readConfig() } catch { c = ShellmateConfig() }; c.setupComplete = true; try? cs.writeConfig(c); appState.completeSetup() }
}
