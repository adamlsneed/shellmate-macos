import Foundation
import Observation

/// The top-level app phase — determines which root view is shown.
enum AppPhase: Sendable {
    case loading
    case preflight
    case wizard
    case chat
}

/// Root app state managing lifecycle and navigation between major phases.
@Observable
@MainActor
final class AppState {
    var currentPhase: AppPhase = .loading
    var setupComplete: Bool = false
    var error: String?

    private let configService = ConfigService()

    /// Check if first-time setup has been completed.
    func checkSetupStatus() async {
        do {
            let config = try configService.readConfig()
            if config.setupComplete {
                setupComplete = true
                currentPhase = .chat
            } else {
                currentPhase = .preflight
            }
        } catch ConfigError.notFound {
            currentPhase = .preflight
        } catch {
            self.error = error.localizedDescription
            currentPhase = .preflight
        }
    }

    /// Transition to wizard after preflight checks pass.
    func startWizard() {
        currentPhase = .wizard
    }

    /// Transition to chat after wizard completes.
    func completeSetup() {
        setupComplete = true
        currentPhase = .chat
    }
}
