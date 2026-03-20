import Foundation

/// Shows Bluetooth status and connected devices.
struct BluetoothStatusTool: AgentTool {
    let identifier = "bluetooth_status"
    let toolDescription = "Show Bluetooth status, controller info, and connected devices."
    let category = ToolCategory.network
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
            executable: "system_profiler", arguments: ["SPBluetoothDataType"],
            timeout: 15
        )
        if result.succeeded {
            return .success(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return .error("Failed to get Bluetooth status: \(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines))")
    }
}
