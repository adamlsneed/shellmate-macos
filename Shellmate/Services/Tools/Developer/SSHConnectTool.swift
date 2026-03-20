import Foundation

/// Executes a command on a remote host via SSH.
struct SSHConnectTool: AgentTool {
    let identifier = "ssh_connect"
    let toolDescription = "Execute a command on a remote host via SSH. Requires SSH keys to be configured."
    let category = ToolCategory.developer
    let actionTier = ActionTier.write
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "host": ToolProperty(type: "string", description: "SSH host (e.g. 'user@hostname' or a Host alias from ~/.ssh/config)"),
            "command": ToolProperty(type: "string", description: "Command to execute on the remote host"),
        ],
        required: ["host", "command"]
    )

    private let shellService: ShellService
    init(shellService: ShellService) { self.shellService = shellService }

    func confirmationDescription(parameters: [String: Any]) -> String {
        let host = parameters["host"] as? String ?? "unknown"
        let command = parameters["command"] as? String ?? ""
        return "Run '\(command)' on \(host) via SSH"
    }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let host = parameters["host"] as? String, !host.isEmpty else {
            return .error("Missing required parameter: host")
        }
        guard let command = parameters["command"] as? String, !command.isEmpty else {
            return .error("Missing required parameter: command")
        }

        let result = try await shellService.run(
            executable: "ssh",
            arguments: ["-o", "BatchMode=yes", "-o", "ConnectTimeout=10", host, command],
            timeout: 60
        )
        if result.succeeded {
            return .success(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return .error("SSH command failed: \(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines))")
    }
}
