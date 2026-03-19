import Foundation

/// Writes content to files with path security and parent directory creation.
enum FileWriteTool {
    static func execute(input: [String: Any]) -> ToolExecutionResult {
        guard let path = input["path"] as? String else {
            return ToolExecutionResult(content: "Missing required 'path' parameter", isError: true)
        }
        guard let content = input["content"] as? String else {
            return ToolExecutionResult(content: "Missing required 'content' parameter", isError: true)
        }

        if SecurityPolicy.isPathBlocked(path) {
            return ToolExecutionResult(content: "Access denied: path is restricted", isError: true)
        }

        let url = URL(fileURLWithPath: path).standardized

        do {
            // Create parent directories if needed
            let parentDir = url.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)

            try content.write(to: url, atomically: true, encoding: .utf8)
            return ToolExecutionResult(content: "File written: \(path)", isError: false)
        } catch {
            return ToolExecutionResult(content: "Failed to write file: \(error.localizedDescription)", isError: true)
        }
    }
}
