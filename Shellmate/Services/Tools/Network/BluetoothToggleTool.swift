import Foundation

/// Toggles Bluetooth power on or off.
struct BluetoothToggleTool: AgentTool {
    let identifier = "bluetooth_toggle"
    let toolDescription = "Turn Bluetooth on or off. Requires blueutil to be installed (brew install blueutil)."
    let category = ToolCategory.network
    let actionTier = ActionTier.write
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "enabled": ToolProperty(type: "boolean", description: "Set to true to enable Bluetooth, false to disable."),
        ],
        required: ["enabled"]
    )

    private let shellService: ShellService
    init(shellService: ShellService) { self.shellService = shellService }

    func confirmationDescription(parameters: [String: Any]) -> String {
        let enabled = parameters["enabled"] as? Bool ?? true
        return "Turn Bluetooth \(enabled ? "on" : "off")"
    }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let enabled = parameters["enabled"] as? Bool else {
            return .error("Missing required parameter: enabled (boolean)")
        }

        guard await shellService.which("blueutil") != nil else {
            return .error("blueutil is not installed. Install it with: brew install blueutil")
        }

        let result = try await shellService.run(
            executable: "blueutil", arguments: ["--power", enabled ? "1" : "0"]
        )
        if result.succeeded {
            return .success("Bluetooth turned \(enabled ? "on" : "off").")
        }
        return .error("Failed to toggle Bluetooth: \(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines))")
    }
}
