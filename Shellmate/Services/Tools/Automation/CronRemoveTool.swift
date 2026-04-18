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

        // Reject empty/whitespace-only patterns — `grep -v ''` matches every non-empty
        // line and would silently wipe the entire crontab.
        let trimmed = pattern.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            return .error("Pattern cannot be empty (would wipe entire crontab). Provide a specific pattern that uniquely identifies the entry to remove.")
        }

        // Escape single quotes for safe shell usage
        let safePattern = pattern.replacingOccurrences(of: "'", with: "'\\''")

        // Pre-resolve matches so the user sees what will be removed.
        // -F is fixed-string (literal), so `.` and `*` aren't regex metacharacters.
        let listResult = try await shellService.runCommand(
            "crontab -l 2>/dev/null | grep -F '\(safePattern)'",
            timeout: 10
        )
        let matches = listResult.stdout
            .split(whereSeparator: \.isNewline)
            .map { String($0) }
            .filter { !$0.isEmpty }

        if matches.isEmpty {
            return .success("No cron entries matched '\(pattern)' — nothing to remove.")
        }

        // Remove matching lines from crontab
        let shellCmd = "crontab -l 2>/dev/null | grep -v -F '\(safePattern)' | crontab -"

        let result = try await shellService.runCommand(shellCmd, timeout: 10)

        if result.succeeded {
            let summary = matches.map { "  - \($0)" }.joined(separator: "\n")
            return .success("Removed \(matches.count) cron entr\(matches.count == 1 ? "y" : "ies") matching '\(pattern)':\n\(summary)")
        }

        return .error("Failed to remove cron job: \(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines))")
    }

    func confirmationDescription(parameters: [String: Any]) -> String {
        let pattern = parameters["pattern"] as? String ?? ""
        return "Remove cron jobs matching: \(pattern)"
    }
}
