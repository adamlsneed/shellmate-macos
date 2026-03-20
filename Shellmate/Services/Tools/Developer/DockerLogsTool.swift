import Foundation

/// Shows logs for a Docker container.
struct DockerLogsTool: AgentTool {
    let identifier = "docker_logs"
    let toolDescription = "Show logs for a Docker container."
    let category = ToolCategory.developer
    let actionTier = ActionTier.read
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "container": ToolProperty(type: "string", description: "Container name or ID"),
            "tail": ToolProperty(type: "string", description: "Number of lines to show from the end. Defaults to 100."),
        ],
        required: ["container"]
    )

    private let shellService: ShellService
    init(shellService: ShellService) { self.shellService = shellService }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let container = parameters["container"] as? String, !container.isEmpty else {
            return .error("Missing required parameter: container")
        }

        guard await shellService.which("docker") != nil else {
            return .error("Docker is not installed or not in PATH.")
        }

        let tail = (parameters["tail"] as? String) ?? "100"
        let result = try await shellService.run(
            executable: "docker", arguments: ["logs", "--tail", tail, container]
        )
        if result.succeeded {
            let output = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            return .success(output.isEmpty ? "No logs available." : output)
        }
        return .error("docker logs failed: \(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines))")
    }
}
