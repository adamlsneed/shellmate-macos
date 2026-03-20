import Foundation

/// Adds a new crontab entry.
struct CronAddTool: AgentTool {
    let identifier = "cron_add"
    let toolDescription = "Add a new cron job to the current user's crontab. Provide a full cron expression and command."
    let category = ToolCategory.automation
    let actionTier = ActionTier.write
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "schedule": ToolProperty(
                type: "string",
                description: "The cron schedule expression (e.g., '0 9 * * 1-5' for 9am weekdays)."
            ),
            "command": ToolProperty(
                type: "string",
                description: "The command to execute on the schedule."
            ),
        ],
        required: ["schedule", "command"]
    )

    private let shellService: ShellService
    init(shellService: ShellService) { self.shellService = shellService }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let schedule = parameters["schedule"] as? String else {
            return .error("Missing required parameter: schedule")
        }
        guard let command = parameters["command"] as? String else {
            return .error("Missing required parameter: command")
        }

        let cronLine = "\(schedule) \(command)"

        // Get existing crontab, append new entry
        let shellCmd = "(crontab -l 2>/dev/null; echo '\(cronLine.replacingOccurrences(of: "'", with: "'\\''"))') | crontab -"

        let result = try await shellService.runCommand(shellCmd, timeout: 10)

        if result.succeeded {
            return .success("Cron job added: \(cronLine)")
        }

        return .error("Failed to add cron job: \(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines))")
    }

    func confirmationDescription(parameters: [String: Any]) -> String {
        let schedule = parameters["schedule"] as? String ?? ""
        let command = parameters["command"] as? String ?? ""
        return "Add cron job: \(schedule) \(command)"
    }
}
