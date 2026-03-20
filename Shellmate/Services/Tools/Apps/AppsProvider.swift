import Foundation

/// Provides Homebrew-based application management tools.
struct AppsProvider: ToolProvider {
    let category = ToolCategory.apps
    let displayName = "Apps & Packages"

    private let shellService: ShellService
    init(shellService: ShellService) { self.shellService = shellService }

    var tools: [AgentTool] {
        [
            AppSearchTool(shellService: shellService),
            AppInstallTool(shellService: shellService),
            AppCheckInstalledTool(shellService: shellService),
            AppUpdateTool(shellService: shellService),
            AppUninstallTool(shellService: shellService),
            AppListInstalledTool(shellService: shellService),
            AppOutdatedTool(shellService: shellService),
        ]
    }
}
