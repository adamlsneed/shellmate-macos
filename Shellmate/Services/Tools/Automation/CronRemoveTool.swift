import Foundation

/// Removes a crontab entry by line number or pattern match.
struct CronRemoveTool: AgentTool {
    let identifier = "cron_remove"
    let toolDescription = "Remove a cron job from the current user's crontab by pattern match."
    let category = ToolCategory.automation
    let actionTier = ActionTier.destructive
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "pattern": ToolProperty(
                type: "string",
                description: "Pattern to match the cron entry to remove. Lines containing this text will be removed."
            ),
        ],
        required: ["pattern"]
    )

    private let shellService: ShellService
    init(shellService: ShellService) { self.shellService = shellService }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let pattern = parameters["pattern"] as? String else {
            return .error("Missing required parameter: pattern")
        }

        // Escape single quotes for safe shell usage
        let safePattern = pattern.replacingOccurrences(of: "'", with: "'\\''")

        // Remove matching lines from crontab
        let shellCmd = "crontab -l 2>/dev/null | grep -v '\(safePattern)' | crontab -"

        let result = try await shellService.runCommand(shellCmd, timeout: 10)

        if result.succeeded {
            return .success("Cron entries matching '\(pattern)' removed.")
        }

        return .error("Failed to remove cron job: \(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines))")
    }

    func confirmationDescription(parameters: [String: Any]) -> String {
        let pattern = parameters["pattern"] as? String ?? ""
        return "Remove cron jobs matching: \(pattern)"
    }
}
