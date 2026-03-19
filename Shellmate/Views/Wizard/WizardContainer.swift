import SwiftUI

/// Container for the wizard flow with phase progress indicator.
struct WizardContainer: View {
    @Environment(AppState.self) private var appState
    @Environment(AIConfigState.self) private var aiConfig
    @State private var wizardState = WizardState()

    var body: some View {
        VStack(spacing: 0) {
            // Progress bar
            ProgressIndicator(
                currentPhase: wizardState.phase.rawValue,
                totalPhases: WizardPhase.allCases.count,
                labels: ["Chat", "Review", "Generate", "Capabilities", "Done"]
            )
            .padding(.horizontal, 24)
            .padding(.top, 16)

            Divider()
                .background(ShellmateColors.navy700)

            // Phase content
            Group {
                switch wizardState.phase {
                case .chat:
                    // Placeholder — ConversationPhase will be built by UI agent
                    PlaceholderPhaseView(title: "Conversation", description: "AI-led personalization chat")
                case .review:
                    PlaceholderPhaseView(title: "Review", description: "Review and edit your agent spec")
                case .generate:
                    PlaceholderPhaseView(title: "Generate", description: "Generate workspace files")
                case .capabilities:
                    PlaceholderPhaseView(title: "Capabilities", description: "Configure tool permissions")
                case .done:
                    PlaceholderPhaseView(title: "Done", description: "Validation and completion")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(ShellmateColors.background)
        .environment(wizardState)
    }
}

/// Temporary placeholder for phases that haven't been built yet.
struct PlaceholderPhaseView: View {
    let title: String
    let description: String
    @Environment(WizardState.self) private var wizardState

    var body: some View {
        VStack(spacing: 16) {
            Text(title)
                .font(.title.bold())
                .foregroundStyle(ShellmateColors.textPrimary)
            Text(description)
                .foregroundStyle(ShellmateColors.textSecondary)

            HStack(spacing: 12) {
                if wizardState.phase.rawValue > 0 {
                    Button("Back") { wizardState.previousPhase() }
                        .buttonStyle(.bordered)
                }
                Button("Next") { wizardState.nextPhase() }
                    .buttonStyle(.borderedProminent)
                    .tint(ShellmateColors.accent)
            }
        }
        .padding(40)
    }
}
