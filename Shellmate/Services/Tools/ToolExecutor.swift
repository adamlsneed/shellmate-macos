import Foundation
import os

/// Result of a tool execution.
struct ToolExecutionResult: Sendable {
    let content: String
    let isError: Bool
}

/// Actor that routes tool calls to their implementations.
/// Actor isolation prevents concurrent shell command conflicts.
actor ToolExecutor {
    private static let logger = Logger(subsystem: "com.shellmate.app", category: "tools")

    /// Execute a tool by name with the given input as JSONValue dict.
    func execute(tool: String, input: [String: JSONValue]) async -> ToolExecutionResult {
        Self.logger.info("Executing tool: \(tool)")

        // Convert JSONValue dict to [String: Any] for tool implementations
        let anyInput = input.mapValues(\.anyValue)

        switch tool {
        case "shell_exec":
            return await ShellTool.execute(input: anyInput)
        case "file_read":
            return FileReadTool.execute(input: anyInput)
        case "file_write":
            return FileWriteTool.execute(input: anyInput)
        case "file_list":
            return FileListTool.execute(input: anyInput)
        case "web_search":
            return await WebSearchTool.execute(input: anyInput)
        case "web_fetch":
            return await WebFetchTool.execute(input: anyInput)
        default:
            return ToolExecutionResult(content: "Unknown tool: \(tool)", isError: true)
        }
    }
}
