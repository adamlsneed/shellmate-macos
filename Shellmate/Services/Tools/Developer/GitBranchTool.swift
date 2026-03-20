import Foundation

/// Lists, creates, or switches Git branches.
struct GitBranchTool: AgentTool {
    let identifier = "git_branch"
    let toolDescription = "List, create, or switch Git branches. Without parameters, lists all branches."
    let category = ToolCategory.developer
    let actionTier = ActionTier.write
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "name": ToolProperty(type: "string", description: "Branch name to create or switch to."),
            "create": ToolProperty(type: "boolean", description: "If true, create a new branch and switch to it. Defaults to false."),
            "directory": ToolProperty(type: "string", description: "Path to the Git repository."),
        ],
        required: []
    )

    private let shellService: ShellService
    init(shellService: ShellService) { self.shellService = shellService }

    func confirmationDescription(parameters: [String: Any]) -> String {
        let name = parameters["name"] as? String
        let create = parameters["create"] as? Bool ?? false
        if let name {
            return create ? "Create and switch to branch '\(name)'" : "Switch to branch '\(name)'"
        }
        return "List Git branches"
    }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        let dir = workingDirectory(from: parameters)

        guard let name = parameters["name"] as? String, !name.isEmpty else {
            // List branches
            let result = try await shellService.run(
                executable: "git", arguments: ["branch", "-a"],
                workingDirectory: dir
            )
            if result.succeeded {
                return .success(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            return .error("git branch failed: \(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines))")
        }

        let create = parameters["create"] as? Bool ?? false
        let args = create ? ["checkout", "-b", name] : ["checkout", name]

        let result = try await shellService.run(
            executable: "git", arguments: args,
            workingDirectory: dir
        )
        if result.succeeded {
            let output = (result.stdout + result.stderr).trimmingCharacters(in: .whitespacesAndNewlines)
            return .success(output)
        }
        return .error("git branch operation failed: \(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines))")
    }
}
