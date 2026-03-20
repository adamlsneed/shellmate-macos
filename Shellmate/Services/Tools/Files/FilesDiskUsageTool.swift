import Foundation

/// Reports disk usage for a directory using du.
struct FilesDiskUsageTool: AgentTool {
    let identifier = "files_disk_usage"
    let toolDescription = "Show disk usage for a directory, listing sizes of subdirectories."
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
                "directory": ToolProperty(type: "string", description: "Directory to check (default: home directory)"),
                "depth": ToolProperty(type: "integer", description: "How many levels deep to report (default: 1)"),
            ],
            required: []
        )
    }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        let depth = parameters["depth"] as? Int ?? 1
        let resolvedPath: String

        if let directory = parameters["directory"] as? String, !directory.isEmpty {
            resolvedPath = URL(fileURLWithPath: directory).standardized.path
        } else {
            resolvedPath = FileManager.default.homeDirectoryForCurrentUser.path
        }

        guard FileManager.default.fileExists(atPath: resolvedPath) else {
            return .error("Directory not found: \(resolvedPath)")
        }

        // Use structured args to prevent shell injection
        let arguments = ["-hd", "\(depth)", resolvedPath]

        do {
            let result = try await shellService.run(
                executable: "/usr/bin/du",
                arguments: arguments,
                timeout: 60
            )

            if result.succeeded {
                let output = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
                return .success(output.isEmpty ? "No usage data available" : output)
            } else {
                // du often writes partial output + errors for permission-denied dirs
                let output = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
                if !output.isEmpty {
                    return .success(output + "\n(some directories may have been inaccessible)")
                }
                return .error("Disk usage check failed: \(result.stderr)")
            }
        } catch {
            return .error("Disk usage check failed: \(error.localizedDescription)")
        }
    }
}
