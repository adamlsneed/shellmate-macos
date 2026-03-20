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

        // Get plist files in LaunchAgents
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let plists = try await shellService.runCommand(
            "ls -1 '\(home)/Library/LaunchAgents/' 2>/dev/null || echo 'No LaunchAgents directory'",
            timeout: 10
        )

        var output = "## Loaded Services (launchctl list)\n"
        if loaded.succeeded {
            output += loaded.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            output += "Failed to list: \(loaded.stderr.trimmingCharacters(in: .whitespacesAndNewlines))"
        }

        output += "\n\n## ~/Library/LaunchAgents\n"
        output += plists.stdout.trimmingCharacters(in: .whitespacesAndNewlines)

        return .success(output)
    }
}
