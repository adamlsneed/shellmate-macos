import Foundation

/// Lists running Docker containers.
struct DockerPsTool: AgentTool {
    let identifier = "docker_ps"
    let toolDescription = "List running Docker containers. Use all parameter to include stopped containers."
    let category = ToolCategory.developer
    let actionTier = ActionTier.read
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "all": ToolProperty(type: "boolean", description: "If true, show all containers including stopped. Defaults to false."),
        ],
        required: []
    )

    private let shellService: ShellService
    init(shellService: ShellService) { self.shellService = shellService }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard await shellService.which("docker") != nil else {
            return .error("Docker is not installed or not in PATH.")
        }

        var args = ["ps"]
        if parameters["all"] as? Bool == true {
            args.append("-a")
        }

        let result = try await shellService.run(executable: "docker", arguments: args)
        if result.succeeded {
            return .success(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return .error("docker ps failed: \(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines))")
    }
}
