import Foundation

/// Searches for applications and packages available via Homebrew.
struct AppSearchTool: AgentTool {
    let identifier = "app_search"
    let toolDescription = "Search for applications and packages available via Homebrew. Returns matching formulae and casks."
    let category = ToolCategory.apps
    let actionTier = ActionTier.read
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "query": ToolProperty(type: "string", description: "Search term for finding apps or packages"),
        ],
        required: ["query"]
    )

    private let shellService: ShellService
    init(shellService: ShellService) { self.shellService = shellService }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let query = parameters["query"] as? String, !query.isEmpty else {
            return .error("Missing required parameter: query")
        }

        guard await shellService.which("brew") != nil else {
            return .error("Homebrew is not installed. Install it from https://brew.sh")
        }

        let result = try await shellService.run(executable: "brew", arguments: ["search", query])
        if result.succeeded {
            let output = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            return output.isEmpty ? .success("No results found for '\(query)'.") : .success(output)
        }
        return .error("Search failed: \(result.stderr)")
    }
}
