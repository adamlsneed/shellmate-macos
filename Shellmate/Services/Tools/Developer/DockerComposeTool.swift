import Foundation

/// Runs a Docker Compose subcommand.
struct DockerComposeTool: AgentTool {
    let identifier = "docker_compose"
    let toolDescription = "Run a Docker Compose command (e.g. up, down, ps, logs, restart)."
    let category = ToolCategory.developer
    let actionTier = ActionTier.write
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "subcommand": ToolProperty(type: "string", description: "Compose subcommand: up, down, ps, logs, restart, build, pull, etc.", enumValues: ["up", "down", "ps", "logs", "restart", "build", "pull", "stop", "start"]),
            "service": ToolProperty(type: "string", description: "Optional service name to target."),
            "detach": ToolProperty(type: "boolean", description: "Run in detached mode (for 'up'). Defaults to true."),
            "directory": ToolProperty(type: "string", description: "Path to the directory containing docker-compose.yml."),
        ],
        required: ["subcommand"]
    )

    private let shellService: ShellService
    init(shellService: ShellService) { self.shellService = shellService }

    func confirmationDescription(parameters: [String: Any]) -> String {
        let sub = parameters["subcommand"] as? String ?? "unknown"
        let service = parameters["service"] as? String
        if let service {
            return "docker compose \(sub) \(service)"
        }
        return "docker compose \(sub)"
    }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let subcommand = parameters["subcommand"] as? String, !subcommand.isEmpty else {
            return .error("Missing required parameter: subcommand")
        }

        guard await shellService.which("docker") != nil else {
            return .error("Docker is not installed or not in PATH.")
        }

        let dir = workingDirectory(from: parameters)
        var args = ["compose", subcommand]

        if subcommand == "up" {
            let detach = parameters["detach"] as? Bool ?? true
            if detach { args.append("-d") }
        }

        if let service = parameters["service"] as? String, !service.isEmpty {
            args.append(service)
        }

        let result = try await shellService.run(
            executable: "docker", arguments: args,
            workingDirectory: dir, timeout: 300
        )
        if result.succeeded {
            let output = (result.stdout + result.stderr).trimmingCharacters(in: .whitespacesAndNewlines)
            return .success(output.isEmpty ? "docker compose \(subcommand) completed." : output)
        }
        return .error("docker compose \(subcommand) failed: \(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines))")
    }
}
