import Foundation

/// Provides file system tools: read, write, and list.
struct FilesProvider: ToolProvider {
    let category = ToolCategory.files
    let displayName = "Files & Storage"
    var tools: [AgentTool] { [FileReadTool(), FileWriteTool(), FileListTool()] }
}
