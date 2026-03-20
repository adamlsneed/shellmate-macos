import Foundation

/// Speaks text aloud using the macOS `say` command.
struct TTSSpeakTool: AgentTool {
    let identifier = "tts_speak"
    let toolDescription = "Speak text aloud using text-to-speech. Optionally specify a voice and speaking rate."
    let category = ToolCategory.tts
    let actionTier = ActionTier.write
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "text": ToolProperty(
                type: "string",
                description: "The text to speak aloud."
            ),
            "voice": ToolProperty(
                type: "string",
                description: "Voice name to use (e.g., 'Samantha', 'Alex'). Use tts_voices to see available voices."
            ),
            "rate": ToolProperty(
                type: "integer",
                description: "Speaking rate in words per minute. Default is ~175. Range: 50-500."
            ),
        ],
        required: ["text"]
    )

    private let shellService: ShellService
    init(shellService: ShellService) { self.shellService = shellService }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let text = parameters["text"] as? String else {
            return .error("Missing required parameter: text")
        }

        guard !text.isEmpty else {
            return .error("Text cannot be empty.")
        }

        var args: [String] = []

        if let voice = parameters["voice"] as? String, !voice.isEmpty {
            args += ["-v", voice]
        }

        if let rate = parameters["rate"] as? Int {
            let clampedRate = min(max(rate, 50), 500)
            args += ["-r", String(clampedRate)]
        } else if let rate = parameters["rate"] as? Double {
            let clampedRate = min(max(Int(rate), 50), 500)
            args += ["-r", String(clampedRate)]
        }

        args.append(text)

        let result = try await shellService.run(
            executable: "say",
            arguments: args,
            timeout: 120
        )

        if result.succeeded {
            return .success("Spoke: \(text.prefix(100))\(text.count > 100 ? "..." : "")")
        }

        return .error("Failed to speak text: \(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines))")
    }

    func confirmationDescription(parameters: [String: Any]) -> String {
        let text = parameters["text"] as? String ?? ""
        return "Speak: \(text.prefix(50))\(text.count > 50 ? "..." : "")"
    }
}
