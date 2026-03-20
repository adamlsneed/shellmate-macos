import Foundation

/// Provides email tools to the agent tool registry.
struct EmailProvider: ToolProvider {
    let category = ToolCategory.email
    let displayName = "Email"
    let requiredPermissions: [SystemPermission] = [.appleEvents]

    private let shellService: ShellService
    private let appleScriptService: AppleScriptService

    init(shellService: ShellService, appleScriptService: AppleScriptService) {
        self.shellService = shellService
        self.appleScriptService = appleScriptService
    }

    var tools: [AgentTool] {
        [
            EmailSearchTool(shellService: shellService),
            EmailReadTool(appleScriptService: appleScriptService),
            EmailComposeTool(appleScriptService: appleScriptService),
            EmailSummarizeUnreadTool(appleScriptService: appleScriptService),
        ]
    }
}
