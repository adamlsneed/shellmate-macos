import Foundation

/// Launches a macOS application by name.
struct AppLaunchTool: AgentTool {
    let identifier = "app_launch"
    let toolDescription = "Launch a macOS application by name using the open command."
    let category = ToolCategory.apps
    let actionTier = ActionTier.write
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "name": ToolProperty(type: "string", description: "Name of the application to launch (e.g. 'Safari', 'Visual Studio Code')"),
        ],
        required: ["name"]
    )

    private let shellService: ShellService
    init(shellService: ShellService) { self.shellService = shellService }

    func confirmationDescription(parameters: [String: Any]) -> String {
        let name = parameters["name"] as? String ?? "unknown"
        return "Launch application '\(name)'"
    }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let name = parameters["name"] as? String, !name.isEmpty else {
            return .error("Missing required parameter: name")
        }

        let result = try await shellService.run(executable: "open", arguments: ["-a", name])
        if result.succeeded {
            return .success("Launched '\(name)'.")
        }
        return .error("Failed to launch '\(name)': \(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines))")
    }
}
