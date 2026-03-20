import Foundation

/// Lists TCP ports currently in LISTEN state.
struct PortsListeningTool: AgentTool {
    let identifier = "ports_listening"
    let toolDescription = "List all TCP ports currently in LISTEN state, showing the process that owns each port."
    let category = ToolCategory.developer
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
            executable: "lsof", arguments: ["-iTCP", "-sTCP:LISTEN", "-P", "-n"]
        )
        if result.succeeded {
            let output = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            return .success(output.isEmpty ? "No TCP ports are currently listening." : output)
        }
        // lsof may return exit code 1 with no results
        if result.exitCode == 1 && result.stderr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .success("No TCP ports are currently listening.")
        }
        return .error("lsof failed: \(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines))")
    }
}
