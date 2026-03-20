import Foundation

// MARK: - AudioInputOutputTool

/// Lists audio input and output devices using system_profiler.
struct AudioInputOutputTool: AgentTool {
    let identifier = "audio_input_output"
    let toolDescription = "List audio input and output devices connected to this Mac."
    let category = ToolCategory.audio
    let actionTier = ActionTier.read
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [:],
        required: []
    )

    private let shellService: ShellService
    init(shellService: ShellService) { self.shellService = shellService }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        let result = try await shellService.runCommand(
            "system_profiler SPAudioDataType",
            timeout: 15
        )

        if result.succeeded, !result.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .success(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return .error("Failed to list audio devices: \(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines))")
    }
}
