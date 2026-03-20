import Foundation

/// Lists running processes with optional sorting, filtering, and limiting.
struct ProcessListTool: AgentTool {
    let identifier = "process_list"
    let toolDescription = "List running processes with optional sorting by CPU or memory usage, filtering by name, and result limiting."
    let category = ToolCategory.apps
    let actionTier = ActionTier.read
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "sort_by": ToolProperty(type: "string", description: "Sort by 'cpu' or 'memory'. Defaults to 'cpu'.", enumValues: ["cpu", "memory"]),
            "limit": ToolProperty(type: "string", description: "Maximum number of processes to return. Defaults to 20."),
            "filter": ToolProperty(type: "string", description: "Filter processes by name (case-insensitive)."),
        ],
        required: []
    )

    private let shellService: ShellService
    init(shellService: ShellService) { self.shellService = shellService }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        let sortBy = (parameters["sort_by"] as? String) ?? "cpu"
        let limitStr = parameters["limit"] as? String
        let limit = limitStr.flatMap(Int.init) ?? 20
        let filter = parameters["filter"] as? String

        let sortFlag = sortBy == "memory" ? "-m" : "-r"
        // Use ps with sort
        var command = "ps aux | head -1; ps aux | tail -n +2 | sort -k \(sortBy == "memory" ? "4" : "3") -rn"

        if let filter = filter, !filter.isEmpty {
            command += " | grep -i '\(filter.replacingOccurrences(of: "'", with: "'\\''"))' | grep -v 'grep -i'"
        }

        command += " | head -\(limit)"

        let result = try await shellService.runCommand(command, timeout: 15)
        if result.succeeded {
            let output = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            return output.isEmpty ? .success("No matching processes found.") : .success(output)
        }
        return .error("Failed to list processes: \(result.stderr)")
    }
}
