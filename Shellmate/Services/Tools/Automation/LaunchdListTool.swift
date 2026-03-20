import Foundation

/// Lists launchd agents and daemons for the current user.
struct LaunchdListTool: AgentTool {
    let identifier = "launchd_list"
    let toolDescription = "List launchd agents for the current user, including both loaded services and plist files in ~/Library/LaunchAgents."
    let category = ToolCategory.automation
    let actionTier = ActionTier.read
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [:],
        required: []
    )

    private let shellService: ShellService
    init(shellService: ShellService) { self.shellService = shellService }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        // Get loaded services
        let loaded = try await shellService.run(
            executable: "launchctl",
            arguments: ["list"],
            timeout: 10
        )

        // Get plist files in LaunchAgents using structured execution (bypasses shell command security check)
        let agentsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents")
        var agentFiles = "No LaunchAgents directory"
        if FileManager.default.fileExists(atPath: agentsDir.path) {
            let plists = try await shellService.run(
                executable: "ls",
                arguments: ["-1", agentsDir.path],
                timeout: 10
            )
            if plists.succeeded {
                let content = plists.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
                agentFiles = content.isEmpty ? "No plist files found" : content
            }
        }

        var output = "## Loaded Services (launchctl list)\n"
        if loaded.succeeded {
            output += loaded.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            output += "Failed to list: \(loaded.stderr.trimmingCharacters(in: .whitespacesAndNewlines))"
        }

        output += "\n\n## ~/Library/LaunchAgents\n"
        output += agentFiles

        return .success(output)
    }
}
