import Foundation

/// Lists current user's crontab entries.
struct CronListTool: AgentTool {
    let identifier = "cron_list"
    let toolDescription = "List all crontab entries for the current user."
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
        let result = try await shellService.run(
            executable: "crontab",
            arguments: ["-l"],
            timeout: 10
        )

        if result.succeeded {
            let output = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            if output.isEmpty {
                return .success("No crontab entries found.")
            }
            return .success(output)
        }

        // crontab -l exits with 1 when there's no crontab
        let stderr = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        if stderr.contains("no crontab") {
            return .success("No crontab entries found.")
        }

        return .error("Failed to list crontab: \(stderr)")
    }
}
