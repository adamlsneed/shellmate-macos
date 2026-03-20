import Foundation

/// Provides developer tools: Git, SSH, Docker, ports, and environment management.
struct DeveloperProvider: ToolProvider {
    let category = ToolCategory.developer
    let displayName = "Developer Tools"

    private let shellService: ShellService
    init(shellService: ShellService) { self.shellService = shellService }

    var tools: [AgentTool] {
        [
            // Git
            GitStatusTool(shellService: shellService),
            GitLogTool(shellService: shellService),
            GitDiffTool(shellService: shellService),
            GitCommitTool(shellService: shellService),
            GitBranchTool(shellService: shellService),
            GitPullTool(shellService: shellService),
            GitPushTool(shellService: shellService),
            GitCloneTool(shellService: shellService),
            // SSH
            SSHConnectTool(shellService: shellService),
            SSHConfigListTool(shellService: shellService),
            // Docker
            DockerPsTool(shellService: shellService),
            DockerLogsTool(shellService: shellService),
            DockerComposeTool(shellService: shellService),
            // Ports
            PortsListeningTool(shellService: shellService),
            PortKillTool(shellService: shellService),
            // Environment
            EnvListTool(shellService: shellService),
            EnvSetTool(shellService: shellService),
        ]
    }
}
