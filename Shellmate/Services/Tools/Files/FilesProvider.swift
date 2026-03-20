import Foundation

/// Provides file system tools: read, write, list, search, move, copy, delete, compress, decompress, disk usage, open, and reveal.
struct FilesProvider: ToolProvider {
    let category = ToolCategory.files
    let displayName = "Files & Storage"
    private let shellService: ShellService

    init(shellService: ShellService = ShellService()) {
        self.shellService = shellService
    }

    var tools: [AgentTool] {
        [
            FileReadTool(), FileWriteTool(), FileListTool(),
            FilesSearchTool(shellService: shellService),
            FilesMoveTool(), FilesCopyTool(),
            FilesDeleteTool(),
            FilesCompressTool(shellService: shellService),
            FilesDecompressTool(shellService: shellService),
            FilesDiskUsageTool(shellService: shellService),
            FilesOpenTool(), FilesRevealInFinderTool(),
        ]
    }
}
