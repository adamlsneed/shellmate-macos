import Foundation

/// Stages and commits changes in a Git repository.
struct GitCommitTool: AgentTool {
    let identifier = "git_commit"
    let toolDescription = "Stage and commit changes in a Git repository. Can stage all changes or specific files."
    let category = ToolCategory.developer
    let actionTier = ActionTier.write
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "message": ToolProperty(type: "string", description: "Commit message"),
            "files": ToolProperty(type: "string", description: "Space-separated list of files to stage. If omitted, stages all changes."),
            "directory": ToolProperty(type: "string", description: "Path to the Git repository."),
        ],
        required: ["message"]
    )

    private let shellService: ShellService
    init(shellService: ShellService) { self.shellService = shellService }

    func confirmationDescription(parameters: [String: Any]) -> String {
        let message = parameters["message"] as? String ?? ""
        return "Git commit: \(message)"
    }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let message = parameters["message"] as? String, !message.isEmpty else {
            return .error("Missing required parameter: message")
        }

        let dir = workingDirectory(from: parameters)

        // Stage files
        if let files = parameters["files"] as? String, !files.isEmpty {
            let fileList = files.split(separator: " ").map(String.init)
            let addResult = try await shellService.run(
                executable: "git", arguments: ["add"] + fileList,
                workingDirectory: dir
            )
            if !addResult.succeeded {
                return .error("git add failed: \(addResult.stderr.trimmingCharacters(in: .whitespacesAndNewlines))")
            }
        } else {
            let addResult = try await shellService.run(
                executable: "git", arguments: ["add", "-A"],
                workingDirectory: dir
            )
            if !addResult.succeeded {
                return .error("git add failed: \(addResult.stderr.trimmingCharacters(in: .whitespacesAndNewlines))")
            }
        }

        // Commit
        let result = try await shellService.run(
            executable: "git", arguments: ["commit", "-m", message],
            workingDirectory: dir
        )
        if result.succeeded {
            return .success(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return .error("git commit failed: \(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines))")
    }
}
