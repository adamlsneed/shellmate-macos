import Foundation
import Observation
import os

enum WizardPhase: Int, CaseIterable, Codable, Sendable {
    case chat = 0, review = 1, generate = 2, capabilities = 3, done = 4
}

struct WizardProgress: Codable, Sendable {
    var phase: WizardPhase
    var agentSpec: AgentSpec
    var isSimpleMode: Bool
    var conversationComplete: Bool
}

@Observable @MainActor
final class WizardState {
    private static let logger = Logger(subsystem: "com.shellmate.app", category: "wizard")
    private static let progressFile = "wizard-progress.json"

    var phase: WizardPhase = .chat
    var agentSpec = AgentSpec()
    var conversationMessages: [ChatMessage] = []
    var conversationComplete: Bool = false
    var generatedFiles: [GeneratedFile] = []
    var isSimpleMode: Bool = false
    var isProcessing: Bool = false

    private let configService: ConfigService

    init(configService: ConfigService = ConfigService()) {
        self.configService = configService
    }

    func nextPhase() {
        guard let next = WizardPhase(rawValue: phase.rawValue + 1) else { return }
        phase = next
        persistProgress()
    }

    func previousPhase() {
        guard let prev = WizardPhase(rawValue: phase.rawValue - 1) else { return }
        phase = prev
        persistProgress()
    }

    func reset() {
        phase = .chat
        agentSpec = AgentSpec()
        conversationMessages = []
        conversationComplete = false
        generatedFiles = []
        isSimpleMode = false
        isProcessing = false
        clearProgress()
    }

    func populateSimpleDefaults() {
        if agentSpec.personality.isEmpty {
            agentSpec.personality = "Warm, patient, and encouraging. Explains things simply."
        }
        if agentSpec.mission.isEmpty {
            agentSpec.mission = "Help with everyday Mac tasks."
        }
        if agentSpec.failure.isEmpty {
            agentSpec.failure = "Apologize simply and suggest trying a different approach."
        }
        if agentSpec.escalation.isEmpty {
            agentSpec.escalation = "If something seems risky, always ask before doing it."
        }
        if agentSpec.never.isEmpty {
            agentSpec.never = [
                "Never delete files without asking first",
                "Never change system settings without asking first",
                "Never share personal information",
            ]
        }
        persistProgress()
    }

    func persistProgress() {
        let progress = WizardProgress(
            phase: phase,
            agentSpec: agentSpec,
            isSimpleMode: isSimpleMode,
            conversationComplete: conversationComplete
        )
        do {
            try configService.ensureConfigDirectory()
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted]
            let data = try encoder.encode(progress)
            let url = configService.configDirectory.appendingPathComponent(Self.progressFile)
            try data.write(to: url, options: .atomic)
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o600], ofItemAtPath: url.path
            )
        } catch {
            Self.logger.warning("Failed to persist wizard progress: \(error.localizedDescription)")
        }
    }

    @discardableResult
    func restoreProgress() -> Bool {
        let url = configService.configDirectory.appendingPathComponent(Self.progressFile)
        guard FileManager.default.fileExists(atPath: url.path) else { return false }
        do {
            let progress = try JSONDecoder().decode(WizardProgress.self, from: Data(contentsOf: url))
            phase = progress.phase
            agentSpec = progress.agentSpec
            isSimpleMode = progress.isSimpleMode
            conversationComplete = progress.conversationComplete
            return true
        } catch {
            Self.logger.warning("Failed to restore wizard progress: \(error.localizedDescription)")
            return false
        }
    }

    func clearProgress() {
        let url = configService.configDirectory.appendingPathComponent(Self.progressFile)
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            Self.logger.info("No wizard progress to clear: \(error.localizedDescription)")
        }
    }
}

struct GeneratedFile: Identifiable, Sendable {
    let id: String
    let filename: String
    let content: String
    var existsOnDisk: Bool = false
}
