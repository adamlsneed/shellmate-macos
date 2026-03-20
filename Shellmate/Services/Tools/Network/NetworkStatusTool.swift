import Foundation

/// Shows network interface status and connectivity.
struct NetworkStatusTool: AgentTool {
    let identifier = "network_status"
    let toolDescription = "Show network interface status including IP addresses and internet connectivity."
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
        var sections: [String] = []

        // Network interfaces
        let ifResult = try await shellService.run(executable: "ifconfig", arguments: [])
        if ifResult.succeeded {
            // Extract active interfaces with IPs
            let lines = ifResult.stdout.split(separator: "\n")
            var current = ""
            var activeInterfaces: [String] = []

            for line in lines {
                if !line.hasPrefix("\t") && !line.hasPrefix(" ") {
                    current = String(line)
                } else if line.contains("inet ") && !line.contains("127.0.0.1") {
                    activeInterfaces.append("\(current)\n\(line)")
                }
            }

            if !activeInterfaces.isEmpty {
                sections.append("--- Active Interfaces ---\n" + activeInterfaces.joined(separator: "\n"))
            }
        }

        // Connectivity check
        let pingResult = try await shellService.run(
            executable: "ping", arguments: ["-c", "1", "-W", "3", "8.8.8.8"],
            timeout: 10
        )
        sections.append("--- Internet Connectivity ---\n\(pingResult.succeeded ? "Connected (ping to 8.8.8.8 succeeded)" : "Disconnected or unreachable")")

        return .success(sections.joined(separator: "\n\n"))
    }
}
