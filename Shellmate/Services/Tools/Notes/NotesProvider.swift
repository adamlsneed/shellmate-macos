import Foundation

/// Provides Apple Notes tools to the agent tool registry.
struct NotesProvider: ToolProvider {
    let category = ToolCategory.notes
    let displayName = "Notes"
    let requiredPermissions: [SystemPermission] = [.appleEvents]

    private let appleScriptService: AppleScriptService
    init(appleScriptService: AppleScriptService) { self.appleScriptService = appleScriptService }

    var tools: [AgentTool] {
        [
            NotesCreateTool(appleScriptService: appleScriptService),
            NotesSearchTool(appleScriptService: appleScriptService),
            NotesReadTool(appleScriptService: appleScriptService),
            NotesAppendTool(appleScriptService: appleScriptService),
            NotesListFoldersTool(appleScriptService: appleScriptService),
        ]
    }
}
