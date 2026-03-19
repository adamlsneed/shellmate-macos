import Foundation

/// Writes content to files with path security and parent directory creation.
struct FileWriteTool: AgentTool {
    let identifier = "file_write"
    let toolDescription = "Write content to a file on the user's Mac. Creates the file and parent directories if they don't exist."
    let category = ToolCategory.files
    let actionTier = ActionTier.write

    var parameterSchema: ToolInputSchema {
        ToolInputSchema(
            type: "object",
            properties: [
                "path": ToolProperty(type: "string", description: "Absolute path to the file to write"),
                "content": ToolProperty(type: "string", description: "Content to write to the file"),
            ],
            required: ["path", "content"]
        )
    }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let path = parameters["path"] as? String else {
            return .error("Missing required 'path' parameter")
        }
        guard let content = parameters["content"] as? String else {
            return .error("Missing required 'content' parameter")
        }

        if SecurityPolicy.isPathBlocked(path) {
            return .error("Access denied: path is restricted")
        }

        let url = URL(fileURLWithPath: path).standardized

        do {
            let parentDir = url.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)

            try content.write(to: url, atomically: true, encoding: .utf8)
            return .success("File written: \(path)")
        } catch {
            return .error("Failed to write file: \(error.localizedDescription)")
        }
    }

    func confirmationDescription(parameters: [String: Any]) -> String {
        let path = parameters["path"] as? String ?? "unknown"
        return "Write to file: \(path)"
    }
}