import Foundation

/// Checks if a specific port is open on a host.
struct NetworkPortCheckTool: AgentTool {
    let identifier = "network_port_check"
    let toolDescription = "Check if a specific TCP port is open and accepting connections on a host."
    let category = ToolCategory.network
    let actionTier = ActionTier.read
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "host": ToolProperty(type: "string", description: "Hostname or IP address to check"),
            "port": ToolProperty(type: "string", description: "TCP port number to check"),
        ],
        required: ["host", "port"]
    )

    private let shellService: ShellService
    init(shellService: ShellService) { self.shellService = shellService }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let host = parameters["host"] as? String, !host.isEmpty else {
            return .error("Missing required parameter: host")
        }
        guard let port = parameters["port"] as? String, !port.isEmpty, Int(port) != nil else {
            return .error("Missing or invalid required parameter: port")
        }

        let result = try await shellService.run(
            executable: "nc", arguments: ["-z", "-w", "3", host, port],
            timeout: 10
        )

        if result.succeeded {
            return .success("Port \(port) on \(host) is OPEN.")
        }
        return .success("Port \(port) on \(host) is CLOSED or unreachable.")
    }
}
