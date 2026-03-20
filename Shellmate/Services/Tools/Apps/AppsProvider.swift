import Foundation

/// Provides Homebrew-based application management and process control tools.
struct AppsProvider: ToolProvider {
    let category = ToolCategory.apps
    let displayName = "Apps & Processes"

    private let shellService: ShellService
    init(shellService: ShellService) { self.shellService = shellService }

    var tools: [AgentTool] {
        [
            // App management (Homebrew)
            AppSearchTool(shellService: shellService),
            AppInstallTool(shellService: shellService),
            AppCheckInstalledTool(shellService: shellService),
            AppUpdateTool(shellService: shellService),
            AppUninstallTool(shellService: shellService),
            AppListInstalledTool(shellService: shellService),
            AppOutdatedTool(shellService: shellService),
            // Process management
            ProcessListTool(shellService: shellService),
            ProcessKillTool(shellService: shellService),
            AppLaunchTool(shellService: shellService),
            AppQuitTool(shellService: shellService),
            AppRunningTool(shellService: shellService),
        ]
    }
}
