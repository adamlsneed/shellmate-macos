import Foundation

/// Pings a host to check connectivity and latency.
struct NetworkPingTool: AgentTool {
    let identifier = "network_ping"
    let toolDescription = "Ping a host to check connectivity and measure round-trip latency."
    let category = ToolCategory.network
    let actionTier = ActionTier.read
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "host": ToolProperty(type: "string", description: "Hostname or IP address to ping"),
            "count": ToolProperty(type: "string", description: "Number of ping packets to send. Defaults to 4."),
        ],
        required: ["host"]
    )

    private let shellService: ShellService
    init(shellService: ShellService) { self.shellService = shellService }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let host = parameters["host"] as? String, !host.isEmpty else {
            return .error("Missing required parameter: host")
        }

        let count = (parameters["count"] as? String) ?? "4"

        let result = try await shellService.run(
            executable: "ping", arguments: ["-c", count, host],
            timeout: 30
        )
        if result.succeeded {
            return .success(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        // ping may fail if host unreachable but still give useful output
        let combined = (result.stdout + "\n" + result.stderr).trimmingCharacters(in: .whitespacesAndNewlines)
        return .error("Ping failed:\n\(combined)")
    }
}
