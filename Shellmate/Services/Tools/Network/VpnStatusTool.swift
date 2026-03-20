import Foundation

/// Shows the status of VPN connections.
struct VpnStatusTool: AgentTool {
    let identifier = "vpn_status"
    let toolDescription = "Show the status of configured VPN connections on macOS."
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
            executable: "scutil", arguments: ["--nc", "list"]
        )
        if result.succeeded {
            let output = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            return .success(output.isEmpty ? "No VPN configurations found." : output)
        }
        return .error("Failed to list VPN connections: \(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines))")
    }
}
