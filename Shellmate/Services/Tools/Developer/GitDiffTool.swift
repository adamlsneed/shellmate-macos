import Foundation

/// Shows Git diff of working directory or staged changes.
struct GitDiffTool: AgentTool {
    let identifier = "git_diff"
    let toolDescription = "Show Git diff of working directory changes. Use staged parameter to see staged changes."
    let category = ToolCategory.developer
    let actionTier = ActionTier.read
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "staged": ToolProperty(type: "boolean", description: "If true, show staged changes (--cached). Defaults to false."),
            "directory": ToolProperty(type: "string", description: "Path to the Git repository."),
        ],
        required: []
    )

    private let shellService: ShellService
    init(shellService: ShellService) { self.shellService = shellService }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        let staged = parameters["staged"] as? Bool ?? false
        let dir = workingDirectory(from: parameters)

        var args = ["diff"]
        if staged { args.append("--cached") }

        let result = try await shellService.run(
            executable: "git", arguments: args,
            workingDirectory: dir
        )
        if result.succeeded {
            let output = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            return .success(output.isEmpty ? "No changes." : output)
        }
        return .error("git diff failed: \(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines))")
    }
}
