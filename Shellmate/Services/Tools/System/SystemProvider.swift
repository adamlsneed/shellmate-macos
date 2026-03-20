import Foundation

/// Provides system information tools to the agent tool registry.
struct SystemProvider: ToolProvider {
    let category = ToolCategory.system
    let displayName = "System Info"

    private let shellService: ShellService
    init(shellService: ShellService) { self.shellService = shellService }

    var tools: [AgentTool] {
        [
            SystemInfoTool(),
            SystemMonitorTool(shellService: shellService),
            SystemStorageTool(shellService: shellService),
            SystemNetworkInfoTool(shellService: shellService),
        ]
    }
}
