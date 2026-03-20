import Foundation

/// Reads file contents with size limits and path security.
struct FileReadTool: AgentTool {
    let identifier = "file_read"
    let toolDescription = "Read the contents of a file on the user's Mac."
    let category = ToolCategory.files
    let actionTier = ActionTier.read

    var parameterSchema: ToolInputSchema {
        ToolInputSchema(
            type: "object",
            properties: [
                "path": ToolProperty(type: "string", description: "Absolute path to the file to read"),
            ],
            required: ["path"]
        )
    }

    private let maxSize = 2 * 1024 * 1024 // 2MB

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let path = parameters["path"] as? String else {
            return .error("Missing required 'path' parameter")
        }

        if SecurityPolicy.isPathBlocked(path) {
            return .error("Access denied: path is restricted")
        }

        let url = URL(fileURLWithPath: path).standardized

        guard FileManager.default.fileExists(atPath: url.path) else {
            return .error("File not found: \(path)")
        }

        do {
            let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
            let size = attrs[.size] as? Int ?? 0
            if size > maxSize {
                return .error("File too large (\(size) bytes, max \(maxSize))")
            }

            let content = try String(contentsOf: url, encoding: .utf8)
            return .success(content)
        } catch {
            return .error("Failed to read file: \(error.localizedDescription)")
        }
    }
}