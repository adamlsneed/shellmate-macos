import Testing
import Foundation
@testable import Shellmate

@Suite("AutomationProvider Tools")
struct AutomationToolTests {

    private static let shell = ShellService()

    // MARK: - ShortcutsListTool

    @Suite("ShortcutsListTool")
    struct ShortcutsListToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = ShortcutsListTool(shellService: shell)
            #expect(tool.identifier == "shortcuts_list")
            #expect(tool.category == .automation)
            #expect(tool.actionTier == .read)
        }
    }

    // MARK: - ShortcutsRunTool

    @Suite("ShortcutsRunTool")
    struct ShortcutsRunToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = ShortcutsRunTool(shellService: shell)
            #expect(tool.identifier == "shortcuts_run")
            #expect(tool.category == .automation)
            #expect(tool.actionTier == .write)
        }

        @Test("requires name parameter")
        func requiresName() async throws {
            let tool = ShortcutsRunTool(shellService: shell)
            let result = try await tool.execute(parameters: [:])
            #expect(result.isError)
            #expect(result.content.contains("name"))
        }

        @Test("provides confirmation description")
        func confirmationDescription() {
            let tool = ShortcutsRunTool(shellService: shell)
            let desc = tool.confirmationDescription(parameters: ["name": "My Shortcut"])
            #expect(desc.contains("My Shortcut"))
        }
    }

    // MARK: - CronListTool

    @Suite("CronListTool")
    struct CronListToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = CronListTool(shellService: shell)
            #expect(tool.identifier == "cron_list")
            #expect(tool.category == .automation)
            #expect(tool.actionTier == .read)
        }

        @Test("returns result without error")
        func returnsResult() async throws {
            let tool = CronListTool(shellService: shell)
            let result = try await tool.execute(parameters: [:])
            #expect(!result.isError)
        }
    }

    // MARK: - CronAddTool

    @Suite("CronAddTool")
    struct CronAddToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = CronAddTool(shellService: shell)
            #expect(tool.identifier == "cron_add")
            #expect(tool.category == .automation)
            #expect(tool.actionTier == .write)
        }

        @Test("requires schedule parameter")
        func requiresSchedule() async throws {
            let tool = CronAddTool(shellService: shell)
            let result = try await tool.execute(parameters: ["command": "echo hi"])
            #expect(result.isError)
            #expect(result.content.contains("schedule"))
        }

        @Test("requires command parameter")
        func requiresCommand() async throws {
            let tool = CronAddTool(shellService: shell)
            let result = try await tool.execute(parameters: ["schedule": "* * * * *"])
            #expect(result.isError)
            #expect(result.content.contains("command"))
        }

        @Test("provides confirmation description")
        func confirmationDescription() {
            let tool = CronAddTool(shellService: shell)
            let desc = tool.confirmationDescription(parameters: ["schedule": "0 9 * * *", "command": "echo hello"])
            #expect(desc.contains("0 9"))
        }
    }

    // MARK: - CronRemoveTool

    @Suite("CronRemoveTool")
    struct CronRemoveToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = CronRemoveTool(shellService: shell)
            #expect(tool.identifier == "cron_remove")
            #expect(tool.category == .automation)
            #expect(tool.actionTier == .destructive)
        }

        @Test("requires pattern parameter")
        func requiresPattern() async throws {
            let tool = CronRemoveTool(shellService: shell)
            let result = try await tool.execute(parameters: [:])
            #expect(result.isError)
            #expect(result.content.contains("pattern"))
        }

        @Test("provides confirmation description")
        func confirmationDescription() {
            let tool = CronRemoveTool(shellService: shell)
            let desc = tool.confirmationDescription(parameters: ["pattern": "echo hello"])
            #expect(desc.contains("echo hello"))
        }
    }

    // MARK: - LaunchdListTool

    @Suite("LaunchdListTool")
    struct LaunchdListToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = LaunchdListTool(shellService: shell)
            #expect(tool.identifier == "launchd_list")
            #expect(tool.category == .automation)
            #expect(tool.actionTier == .read)
        }

        @Test("returns result")
        func returnsResult() async throws {
            let tool = LaunchdListTool(shellService: shell)
            let result = try await tool.execute(parameters: [:])
            #expect(!result.isError)
            #expect(result.content.contains("Loaded Services") || result.content.contains("LaunchAgents"))
        }
    }

    // MARK: - LaunchdCreateTool

    @Suite("LaunchdCreateTool")
    struct LaunchdCreateToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = LaunchdCreateTool(shellService: shell)
            #expect(tool.identifier == "launchd_create")
            #expect(tool.category == .automation)
            #expect(tool.actionTier == .write)
        }

        @Test("requires label parameter")
        func requiresLabel() async throws {
            let tool = LaunchdCreateTool(shellService: shell)
            let result = try await tool.execute(parameters: ["program": "/bin/echo"])
            #expect(result.isError)
            #expect(result.content.contains("label"))
        }

        @Test("requires program parameter")
        func requiresProgram() async throws {
            let tool = LaunchdCreateTool(shellService: shell)
            let result = try await tool.execute(parameters: ["label": "com.test.agent"])
            #expect(result.isError)
            #expect(result.content.contains("program"))
        }

        @Test("rejects invalid label format")
        func rejectsInvalidLabel() async throws {
            let tool = LaunchdCreateTool(shellService: shell)
            let result = try await tool.execute(parameters: ["label": "invalid label with spaces!", "program": "/bin/echo"])
            #expect(result.isError)
            #expect(result.content.contains("Invalid label"))
        }

        @Test("provides confirmation description")
        func confirmationDescription() {
            let tool = LaunchdCreateTool(shellService: shell)
            let desc = tool.confirmationDescription(parameters: ["label": "com.test.agent"])
            #expect(desc.contains("com.test.agent"))
        }
    }

    // MARK: - AutomationProvider

    @Suite("AutomationProvider")
    struct AutomationProviderTests {

        @Test("provider has correct category and tool count")
        func providerMetadata() {
            let provider = AutomationProvider(shellService: shell)
            #expect(provider.category == .automation)
            #expect(provider.displayName == "Automation")
            #expect(provider.tools.count == 7)
        }

        @Test("provider contains all expected tool identifiers")
        func providerToolIdentifiers() {
            let provider = AutomationProvider(shellService: shell)
            let ids = Set(provider.tools.map(\.identifier))
            #expect(ids.contains("shortcuts_list"))
            #expect(ids.contains("shortcuts_run"))
            #expect(ids.contains("cron_list"))
            #expect(ids.contains("cron_add"))
            #expect(ids.contains("cron_remove"))
            #expect(ids.contains("launchd_list"))
            #expect(ids.contains("launchd_create"))
        }
    }
}
