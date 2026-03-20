import Foundation

// MARK: - ShellHistoryTool

/// Displays recent shell command history for the current session.
struct ShellHistoryTool: AgentTool {
    let identifier = "shell_history"
    let toolDescription = "Show recent shell commands executed during this session, including exit codes and durations."
    let category = ToolCategory.shell
    let actionTier = ActionTier.read
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "limit": ToolProperty(type: "integer", description: "Maximum number of entries to return (default 20)"),
        ],
        required: []
    )

    private let shellService: ShellService
    init(service: ShellService) { self.shellService = service }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        let limit = (parameters["limit"] as? Int)
            ?? (parameters["limit"] as? Double).map(Int.init)
            ?? 20

        let history = await shellService.recentHistory(limit: limit)

        if history.isEmpty {
            return .success("No commands have been run yet this session.")
        }

        let lines = history.map { entry in
            let status = entry.exitCode == 0
                ? "[OK]"
                : "[EXIT \(entry.exitCode)]"
            let duration = String(format: "%.1f", entry.duration)
            return "\(status) (\(duration)s) \(entry.command)"
        }

        return .success(lines.joined(separator: "\n"))
    }
}
