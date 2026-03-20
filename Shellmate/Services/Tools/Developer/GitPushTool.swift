import Foundation

/// Pushes commits to a remote Git repository.
struct GitPushTool: AgentTool {
    let identifier = "git_push"
    let toolDescription = "Push commits to the remote Git repository."
    let category = ToolCategory.developer
    let actionTier = ActionTier.write
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "remote": ToolProperty(type: "string", description: "Remote name. Defaults to 'origin'."),
            "branch": ToolProperty(type: "string", description: "Branch to push. If omitted, pushes the current branch."),
            "set_upstream": ToolProperty(type: "boolean", description: "If true, set upstream tracking (-u). Defaults to false."),
            "directory": ToolProperty(type: "string", description: "Path to the Git repository."),
        ],
        required: []
    )

    private let shellService: ShellService
    init(shellService: ShellService) { self.shellService = shellService }

    func confirmationDescription(parameters: [String: Any]) -> String {
        let remote = (parameters["remote"] as? String) ?? "origin"
        if let branch = parameters["branch"] as? String {
            return "Push to \(remote)/\(branch)"
        }
        return "Push to \(remote)"
    }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        let dir = workingDirectory(from: parameters)
        var args = ["push"]

        let setUpstream = parameters["set_upstream"] as? Bool ?? false
        if setUpstream { args.append("-u") }

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
            let output = (result.stdout + result.stderr).trimmingCharacters(in: .whitespacesAndNewlines)
            return .success(output.isEmpty ? "Push completed." : output)
        }
        return .error("git push failed: \(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines))")
    }
}
