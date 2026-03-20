import Foundation

/// Provides Shortcuts, cron, and launchd automation tools.
struct AutomationProvider: ToolProvider {
    let category = ToolCategory.automation
    let displayName = "Automation"

    private let shellService: ShellService
    init(shellService: ShellService) { self.shellService = shellService }

    var tools: [AgentTool] {
        [
            ShortcutsListTool(shellService: shellService),
            ShortcutsRunTool(shellService: shellService),
            CronListTool(shellService: shellService),
            CronAddTool(shellService: shellService),
            CronRemoveTool(shellService: shellService),
            LaunchdListTool(shellService: shellService),
            LaunchdCreateTool(shellService: shellService),
        ]
    }
}
