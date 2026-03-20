import Foundation

// MARK: - ShellEnvironmentTool

/// Displays the current shell environment variables, with sensitive value redaction.
struct ShellEnvironmentTool: AgentTool {
    let identifier = "shell_environment"
    let toolDescription = "List current shell environment variables. Sensitive values (tokens, passwords, keys, secrets, credentials) are automatically redacted."
    let category = ToolCategory.shell
    let actionTier = ActionTier.read
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "filter": ToolProperty(type: "string", description: "Only show variables whose name contains this text (case-insensitive)"),
        ],
        required: []
    )

    private static let sensitiveKeywords = ["secret", "token", "password", "key", "credential"]

    private let shellService: ShellService
    init(service: ShellService) { self.shellService = service }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        let filter = parameters["filter"] as? String
        let env = await shellService.environment()

        var entries = env.sorted(by: { $0.key < $1.key })

        if let filter, !filter.isEmpty {
            entries = entries.filter { $0.key.localizedCaseInsensitiveContains(filter) }
        }

        if entries.isEmpty {
            return .success("No environment variables found.")
        }

        let lines = entries.map { key, value in
            let displayValue = Self.shouldRedact(key: key) ? "[REDACTED]" : value
            return "\(key)=\(displayValue)"
        }

        return .success(lines.joined(separator: "\n"))
    }

    private static func shouldRedact(key: String) -> Bool {
        let lower = key.lowercased()
        return sensitiveKeywords.contains(where: { lower.contains($0) })
    }
}
