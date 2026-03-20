import Foundation

// MARK: - DisplayBrightnessTool

/// Gets or sets the display brightness level.
struct DisplayBrightnessTool: AgentTool {
    let identifier = "display_brightness"
    let toolDescription = "Get or set the display brightness. Use action 'get' to read current brightness or 'set' with a level (0.0 to 1.0) to change it."
    let category = ToolCategory.display
    let actionTier = ActionTier.write
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "action": ToolProperty(
                type: "string",
                description: "The action to perform: 'get' or 'set'.",
                enumValues: ["get", "set"]
            ),
            "level": ToolProperty(
                type: "number",
                description: "Brightness level from 0.0 (darkest) to 1.0 (brightest). Required for 'set' action."
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
            return try await getBrightness()
        case "set":
            return try await setBrightness(parameters: parameters)
        default:
            return .error("Invalid action '\(action)'. Use 'get' or 'set'.")
        }
    }

    func confirmationDescription(parameters: [String: Any]) -> String {
        guard let action = parameters["action"] as? String, action == "set" else { return "" }
        if let level = parameters["level"] as? Double {
            return "Set display brightness to \(Int(level * 100))%"
        }
        return "Set display brightness"
    }

    // MARK: - Private

    private func getBrightness() async throws -> AgentToolResult {
        let result = try await shellService.runCommand(
            "ioreg -c AppleBacklightDisplay | grep brightness",
            timeout: 10
        )

        if result.succeeded, !result.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .success("Display brightness info:\n\(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines))")
        }

        // Fallback: try using the brightness AppleScript
        let asResult = try await shellService.runCommand(
            "osascript -e 'tell application \"System Events\" to get value of slider 1 of group 1 of window \"Control Center\" of application process \"ControlCenter\"' 2>/dev/null || echo 'Unable to read brightness level. Use System Settings > Displays to check.'",
            timeout: 10
        )

        return .success(asResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func setBrightness(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let level = parameters["level"] as? Double else {
            return .error("Missing required parameter 'level' for set action. Provide a value between 0.0 and 1.0.")
        }

        guard level >= 0.0, level <= 1.0 else {
            return .error("Brightness level must be between 0.0 and 1.0. Got \(level).")
        }

        // Attempt to set via osascript — this is unreliable on modern macOS
        let result = try await shellService.runCommand(
            "osascript -e 'tell application \"System Preferences\" to quit' 2>/dev/null; " +
            "brightness \(String(format: "%.2f", level)) 2>/dev/null",
            timeout: 10
        )

        if result.succeeded {
            return .success("Brightness set to \(Int(level * 100))%.")
        }

        return .success(
            "Setting brightness programmatically is not reliably supported on this macOS version. " +
            "Please adjust brightness manually using the keyboard brightness keys or " +
            "System Settings > Displays > Brightness."
        )
    }
}
