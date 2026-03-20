import Foundation

/// Searches for emails using Spotlight (mdfind).
struct EmailSearchTool: AgentTool {
    let identifier = "email_search"
    let toolDescription = "Search for emails using macOS Spotlight. Returns matching email subjects and senders."
    let category = ToolCategory.email
    let actionTier = ActionTier.read
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "query": ToolProperty(
                type: "string",
                description: "The search query to find emails."
            ),
            "limit": ToolProperty(
                type: "integer",
                description: "Maximum number of results to return. Defaults to 10."
            ),
        ],
        required: ["query"]
    )

    private let shellService: ShellService
    init(shellService: ShellService) { self.shellService = shellService }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let query = parameters["query"] as? String else {
            return .error("Missing required parameter: query")
        }

        let limit: Int
        if let l = parameters["limit"] as? Int {
            limit = min(max(l, 1), 50)
        } else if let l = parameters["limit"] as? Double {
            limit = min(max(Int(l), 1), 50)
        } else {
            limit = 10
        }

        // Use mdfind to search for email messages
        let safeQuery = query.replacingOccurrences(of: "'", with: "'\\''")
        let command = "mdfind 'kMDItemContentType == \"com.apple.mail.emlx\" && kMDItemTextContent == \"\(safeQuery)\"' | head -\(limit)"

        let result = try await shellService.runCommand(command, timeout: 30)

        if result.succeeded {
            let output = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            if output.isEmpty {
                return .success("No emails found matching: \(query)")
            }
            return .success("Found emails:\n\(output)")
        }

        return .error("Failed to search emails: \(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines))")
    }
}
