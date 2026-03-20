import Foundation

// MARK: - DisplayDarkModeTool

/// Gets, toggles, or sets the macOS dark mode appearance.
struct DisplayDarkModeTool: AgentTool {
    let identifier = "display_dark_mode"
    let toolDescription = "Get, toggle, or set macOS dark mode. Use 'get' to check current mode, 'toggle' to switch, or 'set' with mode 'dark'/'light'."
    let category = ToolCategory.display
    let actionTier = ActionTier.write
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "action": ToolProperty(
                type: "string",
                description: "The action to perform: 'get', 'toggle', or 'set'.",
                enumValues: ["get", "toggle", "set"]
            ),
            "mode": ToolProperty(
                type: "string",
                description: "The appearance mode to set. Required when action is 'set'.",
                enumValues: ["dark", "light"]
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
            return try await getMode()
        case "toggle":
            return try await toggleMode()
        case "set":
            return try await setMode(parameters: parameters)
        default:
            return .error("Invalid action '\(action)'. Use 'get', 'toggle', or 'set'.")
        }
    }

    func confirmationDescription(parameters: [String: Any]) -> String {
        guard let action = parameters["action"] as? String else { return "" }
        switch action {
        case "toggle": return "Toggle dark mode"
        case "set":
            let mode = parameters["mode"] as? String ?? "unknown"
            return "Set appearance to \(mode) mode"
        default: return ""
        }
    }

    // MARK: - Private

    private func getMode() async throws -> AgentToolResult {
        let result = try await shellService.runCommand(
            "defaults read -g AppleInterfaceStyle 2>/dev/null",
            timeout: 10
        )

        let output = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        let isDark = output == "Dark"
        return .success("Current appearance: \(isDark ? "Dark" : "Light") mode")
    }

    private func toggleMode() async throws -> AgentToolResult {
        let result = try await shellService.runCommand(
            "osascript -e 'tell application \"System Events\" to tell appearance preferences to set dark mode to not dark mode'",
            timeout: 10
        )

        if result.succeeded {
            // Read back the new state
            let check = try await getMode()
            return .success("Dark mode toggled. \(check.content)")
        }

        return .error("Failed to toggle dark mode: \(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines))")
    }

    private func setMode(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let mode = parameters["mode"] as? String else {
            return .error("Missing required parameter 'mode' for set action. Use 'dark' or 'light'.")
        }

        let darkValue: String
        switch mode.lowercased() {
        case "dark": darkValue = "true"
        case "light": darkValue = "false"
        default:
            return .error("Invalid mode '\(mode)'. Use 'dark' or 'light'.")
        }

        let result = try await shellService.runCommand(
            "osascript -e 'tell application \"System Events\" to tell appearance preferences to set dark mode to \(darkValue)'",
            timeout: 10
        )

        if result.succeeded {
            return .success("Appearance set to \(mode) mode.")
        }

        return .error("Failed to set dark mode: \(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines))")
    }
}
