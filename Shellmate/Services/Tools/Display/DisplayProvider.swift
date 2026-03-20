import Foundation

/// Provides display-related tools to the agent tool registry.
struct DisplayProvider: ToolProvider {
    let category = ToolCategory.display
    let displayName = "Display"

    private let shellService: ShellService
    init(shellService: ShellService) { self.shellService = shellService }

    var tools: [AgentTool] {
        [
            DisplayInfoTool(),
            DisplayBrightnessTool(shellService: shellService),
            DisplayDarkModeTool(shellService: shellService),
        ]
    }
}
