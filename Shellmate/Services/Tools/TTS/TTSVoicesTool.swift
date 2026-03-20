import Foundation

/// Lists available text-to-speech voices.
struct TTSVoicesTool: AgentTool {
    let identifier = "tts_voices"
    let toolDescription = "List all available text-to-speech voices on this Mac."
    let category = ToolCategory.tts
    let actionTier = ActionTier.read
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [:],
        required: []
    )

    private let shellService: ShellService
    init(shellService: ShellService) { self.shellService = shellService }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        let result = try await shellService.run(
            executable: "say",
            arguments: ["-v", "?"],
            timeout: 15
        )

        if result.succeeded {
            let output = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            if output.isEmpty {
                return .success("No voices found.")
            }
            return .success(output)
        }

        return .error("Failed to list voices: \(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines))")
    }
}
