import Foundation

// MARK: - AudioVolumeTool

/// Gets or sets the system audio volume, or mutes/unmutes output.
struct AudioVolumeTool: AgentTool {
    let identifier = "audio_volume"
    let toolDescription = "Get or set the system audio volume (0-100), or mute/unmute the output."
    let category = ToolCategory.audio
    let actionTier = ActionTier.write
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "action": ToolProperty(
                type: "string",
                description: "The action to perform: 'get', 'set', 'mute', or 'unmute'.",
                enumValues: ["get", "set", "mute", "unmute"]
            ),
            "level": ToolProperty(
                type: "integer",
                description: "Volume level from 0 to 100. Required for 'set' action."
            ),
        ],
        required: ["action"]
    )

    private let shellService: ShellService
    init(shellService: ShellService) { self.shellService = shellService }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let action = parameters["action"] as? String else {
            return .error("Missing required parameter: action")
        }

        switch action {
        case "get":
            return try await getVolume()
        case "set":
            return try await setVolume(parameters: parameters)
        case "mute":
            return try await setMute(muted: true)
        case "unmute":
            return try await setMute(muted: false)
        default:
            return .error("Invalid action '\(action)'. Use 'get', 'set', 'mute', or 'unmute'.")
        }
    }

    func confirmationDescription(parameters: [String: Any]) -> String {
        guard let action = parameters["action"] as? String else { return "" }
        switch action {
        case "set":
            if let level = parameters["level"] as? Int {
                return "Set volume to \(level)%"
            } else if let level = parameters["level"] as? Double {
                return "Set volume to \(Int(level))%"
            }
            return "Set volume"
        case "mute": return "Mute audio output"
        case "unmute": return "Unmute audio output"
        default: return ""
        }
    }

    // MARK: - Private

    private func getVolume() async throws -> AgentToolResult {
        let result = try await shellService.runCommand(
            "osascript -e 'get volume settings'",
            timeout: 10
        )

        if result.succeeded {
            return .success("Volume settings: \(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines))")
        }

        return .error("Failed to get volume: \(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines))")
    }

    private func setVolume(parameters: [String: Any]) async throws -> AgentToolResult {
        let level: Int
        if let intLevel = parameters["level"] as? Int {
            level = intLevel
        } else if let doubleLevel = parameters["level"] as? Double {
            level = Int(doubleLevel)
        } else {
            return .error("Missing required parameter 'level' for set action. Provide a value between 0 and 100.")
        }

        guard level >= 0, level <= 100 else {
            return .error("Volume level must be between 0 and 100. Got \(level).")
        }

        let result = try await shellService.runCommand(
            "osascript -e 'set volume output volume \(level)'",
            timeout: 10
        )

        if result.succeeded {
            return .success("Volume set to \(level)%.")
        }

        return .error("Failed to set volume: \(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines))")
    }

    private func setMute(muted: Bool) async throws -> AgentToolResult {
        let result = try await shellService.runCommand(
            "osascript -e 'set volume output muted \(muted)'",
            timeout: 10
        )

        if result.succeeded {
            return .success("Audio output \(muted ? "muted" : "unmuted").")
        }

        return .error("Failed to \(muted ? "mute" : "unmute"): \(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines))")
    }
}
