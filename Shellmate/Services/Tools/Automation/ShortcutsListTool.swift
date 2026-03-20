import Foundation

/// Lists all Shortcuts available on the system.
struct ShortcutsListTool: AgentTool {
    let identifier = "shortcuts_list"
    let toolDescription = "List all Shortcuts available on this Mac."
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
            executable: "shortcuts",
            arguments: ["list"],
            timeout: 15
        )

        if result.succeeded {
            let output = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            if output.isEmpty {
                return .success("No Shortcuts found.")
            }
            return .success(output)
        }

        return .error("Failed to list Shortcuts: \(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines))")
    }
}
