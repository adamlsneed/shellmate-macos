import Foundation

/// Provides clipboard tools to the agent tool registry.
struct ClipboardProvider: ToolProvider {
    let category = ToolCategory.clipboard
    let displayName = "Clipboard"

    var tools: [AgentTool] {
        [
            ClipboardReadTool(),
            ClipboardWriteTool(),
            ClipboardClearTool(),
        ]
    }
}
