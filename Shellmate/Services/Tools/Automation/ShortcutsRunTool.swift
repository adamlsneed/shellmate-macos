import Foundation

/// Runs a named Shortcut.
struct ShortcutsRunTool: AgentTool {
    let identifier = "shortcuts_run"
    let toolDescription = "Run a Shortcut by name."
    let category = ToolCategory.automation
    let actionTier = ActionTier.write
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "name": ToolProperty(
                type: "string",
                description: "The name of the Shortcut to run."
            ),
            "input": ToolProperty(
                type: "string",
                description: "Optional input text to pass to the Shortcut."
            ),
        ],
        required: ["name"]
    )

    private let shellService: ShellService
    init(shellService: ShellService) { self.shellService = shellService }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let name = parameters["name"] as? String else {
            return .error("Missing required parameter: name")
        }

        var args = ["run", name]
        if let input = parameters["input"] as? String {
            args += ["--input-type", "text", "--input", input]
        }

        let result = try await shellService.run(
            executable: "shortcuts",
            arguments: args,
            timeout: 60
        )

        if result.succeeded {
            let output = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            if output.isEmpty {
                return .success("Shortcut '\(name)' completed successfully.")
            }
            return .success("Shortcut '\(name)' output:\n\(output)")
        }

        return .error("Shortcut '\(name)' failed: \(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines))")
    }

    func confirmationDescription(parameters: [String: Any]) -> String {
        let name = parameters["name"] as? String ?? "unknown"
        return "Run Shortcut: \(name)"
    }
}
