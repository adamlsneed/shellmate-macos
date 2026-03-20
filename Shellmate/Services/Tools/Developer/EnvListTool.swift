import Foundation

/// Lists environment variables with secrets redacted.
struct EnvListTool: AgentTool {
    let identifier = "env_list"
    let toolDescription = "List environment variables. Values that look like secrets (API keys, tokens, passwords) are automatically redacted."
    let category = ToolCategory.developer
    let actionTier = ActionTier.read
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "filter": ToolProperty(type: "string", description: "Filter variable names by substring (case-insensitive)."),
        ],
        required: []
    )

    /// Patterns in variable names that indicate secrets.
    private static let secretPatterns = [
        "KEY", "SECRET", "TOKEN", "PASSWORD", "PASSWD", "CREDENTIAL",
        "AUTH", "PRIVATE", "API_KEY", "APIKEY", "ACCESS_KEY",
    ]

    private let shellService: ShellService
    init(shellService: ShellService) { self.shellService = shellService }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        let env = await shellService.environment()
        let filter = (parameters["filter"] as? String)?.lowercased()

        var entries: [(String, String)] = env.map { ($0.key, $0.value) }
        entries.sort { $0.0 < $1.0 }

        if let filter, !filter.isEmpty {
            entries = entries.filter { $0.0.lowercased().contains(filter) }
        }

        let lines = entries.map { key, value in
            let isSecret = Self.secretPatterns.contains { key.uppercased().contains($0) }
            return "\(key)=\(isSecret ? "[REDACTED]" : value)"
        }

        return lines.isEmpty
            ? .success("No matching environment variables found.")
            : .success(lines.joined(separator: "\n"))
    }
}
