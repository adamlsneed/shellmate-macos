import Foundation

/// Gracefully quits a running macOS application via AppleScript.
struct AppQuitTool: AgentTool {
    let identifier = "app_quit"
    let toolDescription = "Gracefully quit a running macOS application using AppleScript."
    let category = ToolCategory.apps
    let actionTier = ActionTier.write
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "name": ToolProperty(type: "string", description: "Name of the application to quit (e.g. 'Safari', 'Slack')"),
        ],
        required: ["name"]
    )

    private let shellService: ShellService
    init(shellService: ShellService) { self.shellService = shellService }

    func confirmationDescription(parameters: [String: Any]) -> String {
        let name = parameters["name"] as? String ?? "unknown"
        return "Quit application '\(name)'"
    }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let name = parameters["name"] as? String, !name.isEmpty else {
            return .error("Missing required parameter: name")
        }

        let script = "tell application \"\(name.replacingOccurrences(of: "\"", with: "\\\""))\" to quit"
        let result = try await shellService.run(executable: "osascript", arguments: ["-e", script])
        if result.succeeded {
            return .success("Sent quit command to '\(name)'.")
        }
        return .error("Failed to quit '\(name)': \(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines))")
    }
}
