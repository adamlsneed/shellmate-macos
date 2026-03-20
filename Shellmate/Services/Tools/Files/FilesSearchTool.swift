import Foundation

/// Searches for files using macOS Spotlight (mdfind).
struct FilesSearchTool: AgentTool {
    let identifier = "files_search"
    let toolDescription = "Search for files on the user's Mac using Spotlight. Finds files by name, content, or metadata."
    let category = ToolCategory.files
    let actionTier = ActionTier.read

    private let shellService: ShellService

    init(shellService: ShellService) {
        self.shellService = shellService
    }

    var parameterSchema: ToolInputSchema {
        ToolInputSchema(
            type: "object",
            properties: [
                "query": ToolProperty(type: "string", description: "Search query (file name, content, or Spotlight metadata query)"),
                "directory": ToolProperty(type: "string", description: "Optional directory to limit the search to"),
                "limit": ToolProperty(type: "integer", description: "Maximum number of results to return (default 20)"),
            ],
            required: ["query"]
        )
    }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let query = parameters["query"] as? String, !query.isEmpty else {
            return .error("Missing required 'query' parameter")
        }

        let limit = parameters["limit"] as? Int ?? 20

        var arguments = ["-name", query]

        if let directory = parameters["directory"] as? String {
            arguments.append(contentsOf: ["-onlyin", directory])
        }

        do {
            let result = try await shellService.run(
                executable: "/usr/bin/mdfind",
                arguments: arguments,
                timeout: 30
            )

            let output = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            if output.isEmpty {
                return .success("No files found matching '\(query)'")
            }

            let lines = output.components(separatedBy: "\n")
            let limited = lines.prefix(limit)
            return .success(limited.joined(separator: "\n"))
        } catch {
            return .error("Search failed: \(error.localizedDescription)")
        }
    }
}
