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

// MARK: - Backward Compatibility

// Temporary compat — removed when ToolExecutor is refactored in Task 8
extension FileReadTool {
    static func execute(input: [String: Any]) -> ToolExecutionResult {
        guard let path = input["path"] as? String else {
            return ToolExecutionResult(content: "Missing required 'path' parameter", isError: true)
        }

        if SecurityPolicy.isPathBlocked(path) {
            return ToolExecutionResult(content: "Access denied: path is restricted", isError: true)
        }

        let url = URL(fileURLWithPath: path).standardized

        guard FileManager.default.fileExists(atPath: url.path) else {
            return ToolExecutionResult(content: "File not found: \(path)", isError: true)
        }

        do {
            let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
            let size = attrs[.size] as? Int ?? 0
            if size > 2 * 1024 * 1024 {
                return ToolExecutionResult(content: "File too large (\(size) bytes, max \(2 * 1024 * 1024))", isError: true)
            }

            let content = try String(contentsOf: url, encoding: .utf8)
            return ToolExecutionResult(content: content, isError: false)
        } catch {
            return ToolExecutionResult(content: "Failed to read file: \(error.localizedDescription)", isError: true)
        }
    }
}
