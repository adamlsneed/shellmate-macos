import Testing
import Foundation
@testable import Shellmate

@Suite("AppsProvider Tools")
struct AppsToolTests {

    private let shellService = ShellService()

    // MARK: - AppsProvider

    @Test("provider has 7 tools")
    func providerToolCount() {
        let provider = AppsProvider(shellService: shellService)
        #expect(provider.tools.count == 7)
        #expect(provider.category == .apps)
        #expect(!provider.displayName.isEmpty)
    }

    // MARK: - AppSearchTool

    @Suite("AppSearchTool")
    struct AppSearchToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = AppSearchTool(shellService: ShellService())
            #expect(tool.identifier == "app_search")
            #expect(tool.category == .apps)
            #expect(tool.actionTier == .read)
            #expect(!tool.toolDescription.isEmpty)
        }

        @Test("returns error for missing query")
        func missingQuery() async throws {
            let tool = AppSearchTool(shellService: ShellService())
            let result = try await tool.execute(parameters: [:])
            #expect(result.isError)
            #expect(result.content.contains("query"))
        }
    }

    // MARK: - AppInstallTool

    @Suite("AppInstallTool")
    struct AppInstallToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = AppInstallTool(shellService: ShellService())
            #expect(tool.identifier == "app_install")
            #expect(tool.category == .apps)
            #expect(tool.actionTier == .write)
        }

        @Test("has non-empty confirmation description")
        func confirmationDescription() {
            let tool = AppInstallTool(shellService: ShellService())
            let desc = tool.confirmationDescription(parameters: ["name": "wget"])
            #expect(!desc.isEmpty)
            #expect(desc.contains("wget"))
        }

        @Test("returns error for missing name")
        func missingName() async throws {
            let tool = AppInstallTool(shellService: ShellService())
            let result = try await tool.execute(parameters: [:])
            #expect(result.isError)
            #expect(result.content.contains("name"))
        }
    }

    // MARK: - AppCheckInstalledTool

    @Suite("AppCheckInstalledTool")
    struct AppCheckInstalledToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = AppCheckInstalledTool(shellService: ShellService())
            #expect(tool.identifier == "app_check_installed")
            #expect(tool.category == .apps)
            #expect(tool.actionTier == .read)
        }

        @Test("returns error for missing name")
        func missingName() async throws {
            let tool = AppCheckInstalledTool(shellService: ShellService())
            let result = try await tool.execute(parameters: [:])
            #expect(result.isError)
        }
    }

    // MARK: - AppUpdateTool

    @Suite("AppUpdateTool")
    struct AppUpdateToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = AppUpdateTool(shellService: ShellService())
            #expect(tool.identifier == "app_update")
            #expect(tool.category == .apps)
            #expect(tool.actionTier == .write)
        }

        @Test("has non-empty confirmation description")
        func confirmationDescription() {
            let tool = AppUpdateTool(shellService: ShellService())
            let desc = tool.confirmationDescription(parameters: ["name": "wget"])
            #expect(!desc.isEmpty)
        }
    }

    // MARK: - AppUninstallTool

    @Suite("AppUninstallTool")
    struct AppUninstallToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = AppUninstallTool(shellService: ShellService())
            #expect(tool.identifier == "app_uninstall")
            #expect(tool.category == .apps)
            #expect(tool.actionTier == .destructive)
        }

        @Test("has non-empty confirmation description")
        func confirmationDescription() {
            let tool = AppUninstallTool(shellService: ShellService())
            let desc = tool.confirmationDescription(parameters: ["name": "wget"])
            #expect(!desc.isEmpty)
            #expect(desc.contains("wget"))
        }

        @Test("returns error for missing name")
        func missingName() async throws {
            let tool = AppUninstallTool(shellService: ShellService())
            let result = try await tool.execute(parameters: [:])
            #expect(result.isError)
        }
    }

    // MARK: - AppListInstalledTool

    @Suite("AppListInstalledTool")
    struct AppListInstalledToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = AppListInstalledTool(shellService: ShellService())
            #expect(tool.identifier == "app_list_installed")
            #expect(tool.category == .apps)
            #expect(tool.actionTier == .read)
        }
    }

    // MARK: - AppOutdatedTool

    @Suite("AppOutdatedTool")
    struct AppOutdatedToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = AppOutdatedTool(shellService: ShellService())
            #expect(tool.identifier == "app_outdated")
            #expect(tool.category == .apps)
            #expect(tool.actionTier == .read)
        }
    }
}
