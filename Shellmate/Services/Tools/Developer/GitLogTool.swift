import Foundation

/// Shows recent Git commit history.
struct GitLogTool: AgentTool {
    let identifier = "git_log"
    let toolDescription = "Show recent Git commit history in a compact one-line format."
    let category = ToolCategory.developer
    let actionTier = ActionTier.read
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "count": ToolProperty(type: "string", description: "Number of commits to show. Defaults to 10."),
            "directory": ToolProperty(type: "string", description: "Path to the Git repository."),
        ],
        required: []
    )

    private let shellService: ShellService
    init(shellService: ShellService) { self.shellService = shellService }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        let count = (parameters["count"] as? String).flatMap(Int.init) ?? 10
        let dir = workingDirectory(from: parameters)

        let result = try await shellService.run(
            executable: "git", arguments: ["log", "--oneline", "-\(count)"],
            workingDirectory: dir
        )
        if result.succeeded {
            let output = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            return .success(output.isEmpty ? "No commits found." : output)
        }
        return .error("git log failed: \(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines))")
    }
}
