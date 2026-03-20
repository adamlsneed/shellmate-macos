import Testing
import Foundation
@testable import Shellmate

@Suite("Process Tools")
struct ProcessToolTests {

    // MARK: - AppsProvider includes process tools

    @Test("provider has 12 tools (7 apps + 5 process)")
    func providerToolCount() {
        let provider = AppsProvider(shellService: ShellService())
        #expect(provider.tools.count == 12)
    }

    // MARK: - ProcessListTool

    @Suite("ProcessListTool")
    struct ProcessListToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = ProcessListTool(shellService: ShellService())
            #expect(tool.identifier == "process_list")
            #expect(tool.category == .apps)
            #expect(tool.actionTier == .read)
            #expect(!tool.toolDescription.isEmpty)
        }

        @Test("returns non-error result with processes")
        func executionReturnsList() async throws {
            let tool = ProcessListTool(shellService: ShellService())
            let result = try await tool.execute(parameters: [:])
            #expect(!result.isError)
            // Should contain at least some process info
            #expect(!result.content.isEmpty)
        }
    }

    // MARK: - ProcessKillTool

    @Suite("ProcessKillTool")
    struct ProcessKillToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = ProcessKillTool(shellService: ShellService())
            #expect(tool.identifier == "process_kill")
            #expect(tool.category == .apps)
            #expect(tool.actionTier == .destructive)
        }

        @Test("has non-empty confirmation description")
        func confirmationDescription() {
            let tool = ProcessKillTool(shellService: ShellService())
            let desc = tool.confirmationDescription(parameters: ["name": "Safari"])
            #expect(!desc.isEmpty)
            #expect(desc.contains("Safari"))
        }

        @Test("rejects protected process by name")
        func rejectsProtectedProcessByName() async throws {
            let tool = ProcessKillTool(shellService: ShellService())
            for name in ["kernel_task", "WindowServer", "loginwindow", "launchd", "SystemUIServer", "Dock", "Finder"] {
                let result = try await tool.execute(parameters: ["name": name])
                #expect(result.isError, "Should reject killing \(name)")
                #expect(result.content.contains("protected"))
            }
        }

        @Test("returns error when neither pid nor name given")
        func missingParams() async throws {
            let tool = ProcessKillTool(shellService: ShellService())
            let result = try await tool.execute(parameters: [:])
            #expect(result.isError)
        }
    }

    // MARK: - AppLaunchTool

    @Suite("AppLaunchTool")
    struct AppLaunchToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = AppLaunchTool(shellService: ShellService())
            #expect(tool.identifier == "app_launch")
            #expect(tool.category == .apps)
            #expect(tool.actionTier == .write)
        }

        @Test("has non-empty confirmation description")
        func confirmationDescription() {
            let tool = AppLaunchTool(shellService: ShellService())
            let desc = tool.confirmationDescription(parameters: ["name": "Safari"])
            #expect(!desc.isEmpty)
        }

        @Test("returns error for missing name")
        func missingName() async throws {
            let tool = AppLaunchTool(shellService: ShellService())
            let result = try await tool.execute(parameters: [:])
            #expect(result.isError)
        }
    }

    // MARK: - AppQuitTool

    @Suite("AppQuitTool")
    struct AppQuitToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = AppQuitTool(shellService: ShellService())
            #expect(tool.identifier == "app_quit")
            #expect(tool.category == .apps)
            #expect(tool.actionTier == .write)
        }

        @Test("has non-empty confirmation description")
        func confirmationDescription() {
            let tool = AppQuitTool(shellService: ShellService())
            let desc = tool.confirmationDescription(parameters: ["name": "Safari"])
            #expect(!desc.isEmpty)
        }

        @Test("returns error for missing name")
        func missingName() async throws {
            let tool = AppQuitTool(shellService: ShellService())
            let result = try await tool.execute(parameters: [:])
            #expect(result.isError)
        }
    }

    // MARK: - AppRunningTool

    @Suite("AppRunningTool")
    struct AppRunningToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = AppRunningTool(shellService: ShellService())
            #expect(tool.identifier == "app_running")
            #expect(tool.category == .apps)
            #expect(tool.actionTier == .read)
        }

        @Test("returns error for missing name")
        func missingName() async throws {
            let tool = AppRunningTool(shellService: ShellService())
            let result = try await tool.execute(parameters: [:])
            #expect(result.isError)
        }
    }
}
