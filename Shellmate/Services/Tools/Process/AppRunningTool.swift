import Foundation

/// Checks if a specific application is currently running.
struct AppRunningTool: AgentTool {
    let identifier = "app_running"
    let toolDescription = "Check if a specific application or process is currently running."
    let category = ToolCategory.apps
    let actionTier = ActionTier.read
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "name": ToolProperty(type: "string", description: "Name of the application or process to check"),
        ],
        required: ["name"]
    )

    private let shellService: ShellService
    init(shellService: ShellService) { self.shellService = shellService }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let name = parameters["name"] as? String, !name.isEmpty else {
            return .error("Missing required parameter: name")
        }

        let safeName = name.replacingOccurrences(of: "'", with: "'\\''")
        let result = try await shellService.runCommand("ps aux | grep -i '\(safeName)' | grep -v 'grep -i'", timeout: 10)

        let output = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        if output.isEmpty {
            return .success("'\(name)' is not currently running.")
        }
        let lines = output.split(separator: "\n")
        return .success("'\(name)' is running (\(lines.count) matching process\(lines.count == 1 ? "" : "es")):\n\(output)")
    }
}
