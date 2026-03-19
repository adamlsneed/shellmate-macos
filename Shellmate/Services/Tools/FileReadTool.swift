import Foundation

/// Reads file contents with size limits and path security.
enum FileReadTool {
    private static let maxSize = 2 * 1024 * 1024 // 2MB

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
            if size > maxSize {
                return ToolExecutionResult(content: "File too large (\(size) bytes, max \(maxSize))", isError: true)
            }

            let content = try String(contentsOf: url, encoding: .utf8)
            return ToolExecutionResult(content: content, isError: false)
        } catch {
            return ToolExecutionResult(content: "Failed to read file: \(error.localizedDescription)", isError: true)
        }
    }
}
