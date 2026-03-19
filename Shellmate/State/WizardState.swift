import Foundation
import Observation

/// Wizard phases in order
enum WizardPhase: Int, CaseIterable, Sendable {
    case chat = 0          // AI-led personalization conversation
    case review = 1        // Review/edit agent spec
    case generate = 2      // Generate workspace files
    case capabilities = 3  // Configure tool permissions
    case done = 4          // Validation + completion
}

/// Observable state for the first-time setup wizard.
@Observable
@MainActor
final class WizardState {
    var phase: WizardPhase = .chat
    var agentSpec = AgentSpec()
    var conversationMessages: [ChatMessage] = []
    var generatedFiles: [GeneratedFile] = []
    var isSimpleMode: Bool = false
    var isProcessing: Bool = false

    /// Advance to the next wizard phase.
    func nextPhase() {
        guard let next = WizardPhase(rawValue: phase.rawValue + 1) else { return }
        phase = next
    }

    /// Go back to the previous wizard phase.
    func previousPhase() {
        guard let prev = WizardPhase(rawValue: phase.rawValue - 1) else { return }
        phase = prev
    }
}

/// A generated workspace file with preview content.
struct GeneratedFile: Identifiable, Sendable {
    let id: String
    let filename: String
    let content: String
    var existsOnDisk: Bool = false
}
