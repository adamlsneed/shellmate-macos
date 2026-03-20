import Testing
import Foundation
@testable import Shellmate

@Suite("DeveloperProvider Tools")
struct DeveloperToolTests {

    private let shellService = ShellService()

    // MARK: - DeveloperProvider

    @Test("provider has 17 tools")
    func providerToolCount() {
        let provider = DeveloperProvider(shellService: shellService)
        #expect(provider.tools.count == 17)
        #expect(provider.category == .developer)
        #expect(!provider.displayName.isEmpty)
    }

    // MARK: - Git tools conformance

    @Suite("GitStatusTool")
    struct GitStatusToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = GitStatusTool(shellService: ShellService())
            #expect(tool.identifier == "git_status")
            #expect(tool.category == .developer)
            #expect(tool.actionTier == .read)
        }

        @Test("returns non-error result in a git repo")
        func executionInRepo() async throws {
            let tool = GitStatusTool(shellService: ShellService())
            let repoDir = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
            let result = try await tool.execute(parameters: ["directory": repoDir.path])
            #expect(!result.isError)
            #expect(result.content.contains("branch") || result.content.contains("On branch"))
        }
    }

    @Suite("GitLogTool")
    struct GitLogToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = GitLogTool(shellService: ShellService())
            #expect(tool.identifier == "git_log")
            #expect(tool.category == .developer)
            #expect(tool.actionTier == .read)
        }

        @Test("returns non-error result in a git repo")
        func executionInRepo() async throws {
            let tool = GitLogTool(shellService: ShellService())
            let repoDir = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
            let result = try await tool.execute(parameters: ["directory": repoDir.path, "count": "5"])
            #expect(!result.isError)
            #expect(!result.content.isEmpty)
        }
    }

    @Suite("GitDiffTool")
    struct GitDiffToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = GitDiffTool(shellService: ShellService())
            #expect(tool.identifier == "git_diff")
            #expect(tool.category == .developer)
            #expect(tool.actionTier == .read)
        }
    }

    @Suite("GitCommitTool")
    struct GitCommitToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = GitCommitTool(shellService: ShellService())
            #expect(tool.identifier == "git_commit")
            #expect(tool.category == .developer)
            #expect(tool.actionTier == .write)
        }

        @Test("has non-empty confirmation description")
        func confirmationDescription() {
            let tool = GitCommitTool(shellService: ShellService())
            let desc = tool.confirmationDescription(parameters: ["message": "test"])
            #expect(!desc.isEmpty)
            #expect(desc.contains("test"))
        }

        @Test("returns error for missing message")
        func missingMessage() async throws {
            let tool = GitCommitTool(shellService: ShellService())
            let result = try await tool.execute(parameters: [:])
            #expect(result.isError)
        }
    }

    @Suite("GitBranchTool")
    struct GitBranchToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = GitBranchTool(shellService: ShellService())
            #expect(tool.identifier == "git_branch")
            #expect(tool.category == .developer)
            #expect(tool.actionTier == .write)
        }
    }

    @Suite("GitPullTool")
    struct GitPullToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = GitPullTool(shellService: ShellService())
            #expect(tool.identifier == "git_pull")
            #expect(tool.category == .developer)
            #expect(tool.actionTier == .write)
        }

        @Test("has non-empty confirmation description")
        func confirmationDescription() {
            let tool = GitPullTool(shellService: ShellService())
            let desc = tool.confirmationDescription(parameters: [:])
            #expect(!desc.isEmpty)
        }
    }

    @Suite("GitPushTool")
    struct GitPushToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = GitPushTool(shellService: ShellService())
            #expect(tool.identifier == "git_push")
            #expect(tool.category == .developer)
            #expect(tool.actionTier == .write)
        }
    }

    @Suite("GitCloneTool")
    struct GitCloneToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = GitCloneTool(shellService: ShellService())
            #expect(tool.identifier == "git_clone")
            #expect(tool.category == .developer)
            #expect(tool.actionTier == .write)
        }

        @Test("returns error for missing url")
        func missingUrl() async throws {
            let tool = GitCloneTool(shellService: ShellService())
            let result = try await tool.execute(parameters: [:])
            #expect(result.isError)
        }
    }

    // MARK: - SSH tools

    @Suite("SSHConnectTool")
    struct SSHConnectToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = SSHConnectTool(shellService: ShellService())
            #expect(tool.identifier == "ssh_connect")
            #expect(tool.category == .developer)
            #expect(tool.actionTier == .write)
        }

        @Test("returns error for missing params")
        func missingParams() async throws {
            let tool = SSHConnectTool(shellService: ShellService())
            let result = try await tool.execute(parameters: [:])
            #expect(result.isError)
        }
    }

    @Suite("SSHConfigListTool")
    struct SSHConfigListToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = SSHConfigListTool(shellService: ShellService())
            #expect(tool.identifier == "ssh_config_list")
            #expect(tool.category == .developer)
            #expect(tool.actionTier == .read)
        }
    }

    // MARK: - Docker tools

    @Suite("DockerPsTool")
    struct DockerPsToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = DockerPsTool(shellService: ShellService())
            #expect(tool.identifier == "docker_ps")
            #expect(tool.category == .developer)
            #expect(tool.actionTier == .read)
        }
    }

    @Suite("DockerLogsTool")
    struct DockerLogsToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = DockerLogsTool(shellService: ShellService())
            #expect(tool.identifier == "docker_logs")
            #expect(tool.category == .developer)
            #expect(tool.actionTier == .read)
        }

        @Test("returns error for missing container")
        func missingContainer() async throws {
            let tool = DockerLogsTool(shellService: ShellService())
            let result = try await tool.execute(parameters: [:])
            #expect(result.isError)
        }
    }

    @Suite("DockerComposeTool")
    struct DockerComposeToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = DockerComposeTool(shellService: ShellService())
            #expect(tool.identifier == "docker_compose")
            #expect(tool.category == .developer)
            #expect(tool.actionTier == .write)
        }

        @Test("returns error for missing subcommand")
        func missingSubcommand() async throws {
            let tool = DockerComposeTool(shellService: ShellService())
            let result = try await tool.execute(parameters: [:])
            #expect(result.isError)
        }
    }

    // MARK: - Port tools

    @Suite("PortsListeningTool")
    struct PortsListeningToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = PortsListeningTool(shellService: ShellService())
            #expect(tool.identifier == "ports_listening")
            #expect(tool.category == .developer)
            #expect(tool.actionTier == .read)
        }
    }

    @Suite("PortKillTool")
    struct PortKillToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = PortKillTool(shellService: ShellService())
            #expect(tool.identifier == "port_kill")
            #expect(tool.category == .developer)
            #expect(tool.actionTier == .destructive)
        }

        @Test("has non-empty confirmation description")
        func confirmationDescription() {
            let tool = PortKillTool(shellService: ShellService())
            let desc = tool.confirmationDescription(parameters: ["port": "8080"])
            #expect(!desc.isEmpty)
            #expect(desc.contains("8080"))
        }

        @Test("returns error for missing port")
        func missingPort() async throws {
            let tool = PortKillTool(shellService: ShellService())
            let result = try await tool.execute(parameters: [:])
            #expect(result.isError)
        }

        @Test("returns error for invalid port")
        func invalidPort() async throws {
            let tool = PortKillTool(shellService: ShellService())
            let result = try await tool.execute(parameters: ["port": "abc"])
            #expect(result.isError)
        }
    }

    // MARK: - Environment tools

    @Suite("EnvListTool")
    struct EnvListToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = EnvListTool(shellService: ShellService())
            #expect(tool.identifier == "env_list")
            #expect(tool.category == .developer)
            #expect(tool.actionTier == .read)
        }
    }

    @Suite("EnvSetTool")
    struct EnvSetToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = EnvSetTool(shellService: ShellService())
            #expect(tool.identifier == "env_set")
            #expect(tool.category == .developer)
            #expect(tool.actionTier == .write)
        }

        @Test("has non-empty confirmation description")
        func confirmationDescription() {
            let tool = EnvSetTool(shellService: ShellService())
            let desc = tool.confirmationDescription(parameters: ["key": "MY_VAR", "value": "test"])
            #expect(!desc.isEmpty)
        }

        @Test("warns when key looks like a secret")
        func warnsOnSecretKey() {
            let tool = EnvSetTool(shellService: ShellService())
            let desc = tool.confirmationDescription(parameters: ["key": "MY_API_KEY", "value": "abc", "persist": true])
            #expect(desc.contains("WARNING") || desc.contains("secret"))
        }

        @Test("returns error for missing key")
        func missingKey() async throws {
            let tool = EnvSetTool(shellService: ShellService())
            let result = try await tool.execute(parameters: ["value": "test"])
            #expect(result.isError)
        }

        @Test("returns error for missing value")
        func missingValue() async throws {
            let tool = EnvSetTool(shellService: ShellService())
            let result = try await tool.execute(parameters: ["key": "MY_VAR"])
            #expect(result.isError)
        }
    }
}
