import Foundation

/// Pulls changes from a remote Git repository.
struct GitPullTool: AgentTool {
    let identifier = "git_pull"
    let toolDescription = "Pull changes from the remote Git repository."
    let category = ToolCategory.developer
    let actionTier = ActionTier.write
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "remote": ToolProperty(type: "string", description: "Remote name. Defaults to 'origin'."),
            "branch": ToolProperty(type: "string", description: "Branch to pull. If omitted, pulls the current branch's upstream."),
            "directory": ToolProperty(type: "string", description: "Path to the Git repository."),
        ],
        required: []
    )

    private let shellService: ShellService
    init(shellService: ShellService) { self.shellService = shellService }

    func confirmationDescription(parameters: [String: Any]) -> String {
        let remote = (parameters["remote"] as? String) ?? "origin"
        if let branch = parameters["branch"] as? String {
            return "Pull from \(remote)/\(branch)"
        }
        return "Pull from \(remote)"
    }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        let dir = workingDirectory(from: parameters)
        var args = ["pull"]

        if let remote = parameters["remote"] as? String, !remote.isEmpty {
            args.append(remote)
            if let branch = parameters["branch"] as? String, !branch.isEmpty {
                args.append(branch)
            }
        }

        let result = try await shellService.run(
            executable: "git", arguments: args,
            workingDirectory: dir, timeout: 120
        )
        if result.succeeded {
            return .success(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return .error("git pull failed: \(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines))")
    }
}
