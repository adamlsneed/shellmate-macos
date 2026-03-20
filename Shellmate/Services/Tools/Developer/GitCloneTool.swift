import Foundation

/// Clones a Git repository.
struct GitCloneTool: AgentTool {
    let identifier = "git_clone"
    let toolDescription = "Clone a Git repository from a URL."
    let category = ToolCategory.developer
    let actionTier = ActionTier.write
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "url": ToolProperty(type: "string", description: "Repository URL to clone"),
            "directory": ToolProperty(type: "string", description: "Parent directory to clone into. Defaults to home directory."),
            "name": ToolProperty(type: "string", description: "Custom directory name for the clone."),
        ],
        required: ["url"]
    )

    private let shellService: ShellService
    init(shellService: ShellService) { self.shellService = shellService }

    func confirmationDescription(parameters: [String: Any]) -> String {
        let url = parameters["url"] as? String ?? "unknown"
        return "Clone repository \(url)"
    }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let url = parameters["url"] as? String, !url.isEmpty else {
            return .error("Missing required parameter: url")
        }

        let dir = workingDirectory(from: parameters)
        var args = ["clone", url]
        if let name = parameters["name"] as? String, !name.isEmpty {
            args.append(name)
        }

        let result = try await shellService.run(
            executable: "git", arguments: args,
            workingDirectory: dir, timeout: 300
        )
        if result.succeeded {
            let output = (result.stdout + result.stderr).trimmingCharacters(in: .whitespacesAndNewlines)
            return .success(output.isEmpty ? "Clone completed." : output)
        }
        return .error("git clone failed: \(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines))")
    }
}
