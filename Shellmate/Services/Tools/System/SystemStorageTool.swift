import Foundation

// MARK: - SystemStorageTool

/// Returns disk volume overview and directory size breakdown.
/// Uses structured `ShellService.run(executable:arguments:)` for `du` to prevent shell injection.
struct SystemStorageTool: AgentTool {
    let identifier = "system_storage"
    let toolDescription = "Get disk storage overview and directory size breakdown. Optionally specify a target directory and depth."
    let category = ToolCategory.system
    let actionTier = ActionTier.read
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "directory": ToolProperty(type: "string", description: "Directory to analyze (default: home directory)"),
            "depth": ToolProperty(type: "integer", description: "Depth for directory breakdown (default: 1)"),
        ],
        required: []
    )

    private let shellService: ShellService
    init(shellService: ShellService) { self.shellService = shellService }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        let directory = (parameters["directory"] as? String)
            ?? FileManager.default.homeDirectoryForCurrentUser.path
        let depth = (parameters["depth"] as? Int)
            ?? (parameters["depth"] as? Double).map(Int.init)
            ?? 1

        var sections: [String] = []

        // Volume overview via df -h
        let dfResult = try await shellService.runCommand("df -h", timeout: 10)
        if dfResult.succeeded {
            sections.append("--- Volume Overview ---\n" + dfResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        // Directory breakdown via du — use structured arguments to avoid injection
        let duResult = try await shellService.run(
            executable: "du",
            arguments: ["-h", "-d", "\(depth)", directory],
            timeout: 30
        )
        if duResult.succeeded {
            sections.append("--- Directory Breakdown: \(directory) (depth \(depth)) ---\n" + duResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines))
        } else if !duResult.stderr.isEmpty {
            // du may partially fail on permission-denied dirs; include what we got
            var output = duResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            if !output.isEmpty {
                sections.append("--- Directory Breakdown (partial): \(directory) ---\n" + output)
            }
        }

        if sections.isEmpty {
            return .error("Failed to gather storage information")
        }

        return .success(sections.joined(separator: "\n\n"))
    }
}
