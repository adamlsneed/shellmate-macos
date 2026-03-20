import Foundation

/// Shows the working tree status of a Git repository.
struct GitStatusTool: AgentTool {
    let identifier = "git_status"
    let toolDescription = "Show the working tree status of a Git repository, including staged, unstaged, and untracked files."
    let category = ToolCategory.developer
    let actionTier = ActionTier.read
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "directory": ToolProperty(type: "string", description: "Path to the Git repository. Defaults to home directory."),
        ],
        required: []
    )

    private let shellService: ShellService
    init(shellService: ShellService) { self.shellService = shellService }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        let dir = workingDirectory(from: parameters)
        let result = try await shellService.run(
            executable: "git", arguments: ["status"],
            workingDirectory: dir
        )
        if result.succeeded {
            return .success(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return .error("git status failed: \(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines))")
    }
}

// MARK: - Shared helper

func workingDirectory(from parameters: [String: Any]) -> URL? {
    guard let dir = parameters["directory"] as? String, !dir.isEmpty else { return nil }
    return URL(fileURLWithPath: NSString(string: dir).expandingTildeInPath)
}
