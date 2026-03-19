import SwiftUI
struct WizardContainer: View {
    @Environment(AppState.self) private var appState; @Environment(AIConfigState.self) private var aiConfig
    @State private var wizardState = WizardState()
    var body: some View {
        Group { if wizardState.isSimpleMode { SimpleSetup() } else { fullWizard } }
            .background(ShellmateColors.background).environment(wizardState)
            .onReceive(NotificationCenter.default.publisher(for: .shellmateSimpleMode)) { _ in wizardState.isSimpleMode = true }
    }
    private var fullWizard: some View {
        VStack(spacing: 0) {
            ProgressIndicator(currentPhase: wizardState.phase.rawValue, totalPhases: WizardPhase.allCases.count, labels: ["Chat", "Review", "Generate", "Capabilities", "Done"]).padding(.horizontal, 24).padding(.top, 16)
            Divider().background(ShellmateColors.navy700)
            Group { switch wizardState.phase { case .chat: ConversationPhase(); case .review: ReviewStep(); case .generate: GenerateStep(); case .capabilities: CapabilitiesStep(); case .done: DoneStep() } }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
