import Foundation

/// Provides shell execution tools to the agent tool registry.
struct ShellProvider: ToolProvider {
    let category = ToolCategory.shell
    let displayName = "Shell & Terminal"

    private let shellService: ShellService
    init(shellService: ShellService) { self.shellService = shellService }

    var tools: [AgentTool] { [ShellExecuteTool(service: shellService)] }
}
