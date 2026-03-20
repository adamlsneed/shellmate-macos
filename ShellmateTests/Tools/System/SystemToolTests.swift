import Testing
import Foundation
@testable import Shellmate

@Suite("SystemProvider Tools")
struct SystemToolTests {

    private let shellService = ShellService()

    // MARK: - SystemInfoTool

    @Suite("SystemInfoTool")
    struct SystemInfoToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = SystemInfoTool()
            #expect(tool.identifier == "system_info")
            #expect(tool.category == .system)
            #expect(tool.actionTier == .read)
            #expect(!tool.toolDescription.isEmpty)
        }

        @Test("returns non-error result with expected keywords")
        func executionReturnsSystemInfo() async throws {
            let tool = SystemInfoTool()
            let result = try await tool.execute(parameters: [:])
            #expect(!result.isError)
            #expect(result.content.contains("macOS"))
            #expect(result.content.contains("Hostname"))
            #expect(result.content.contains("Memory"))
        }
    }

    // MARK: - SystemMonitorTool

    @Suite("SystemMonitorTool")
    struct SystemMonitorToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = SystemMonitorTool(shellService: ShellService())
            #expect(tool.identifier == "system_monitor")
            #expect(tool.category == .system)
            #expect(tool.actionTier == .read)
        }

        @Test("returns non-error result with load info")
        func executionReturnsMonitorInfo() async throws {
            let tool = SystemMonitorTool(shellService: ShellService())
            let result = try await tool.execute(parameters: [:])
            #expect(!result.isError)
            // Should contain at least CPU or memory info
            #expect(result.content.contains("CPU") || result.content.contains("Memory") || result.content.contains("Load"))
        }
    }

    // MARK: - SystemStorageTool

    @Suite("SystemStorageTool")
    struct SystemStorageToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = SystemStorageTool(shellService: ShellService())
            #expect(tool.identifier == "system_storage")
            #expect(tool.category == .system)
            #expect(tool.actionTier == .read)
        }

        @Test("returns non-error result with default params")
        func executionWithDefaults() async throws {
            let tool = SystemStorageTool(shellService: ShellService())
            let result = try await tool.execute(parameters: [:])
            #expect(!result.isError)
            #expect(result.content.contains("Volume"))
        }

        @Test("returns non-error result with explicit directory")
        func executionWithExplicitDirectory() async throws {
            let tool = SystemStorageTool(shellService: ShellService())
            let result = try await tool.execute(parameters: ["directory": "/tmp", "depth": 1])
            #expect(!result.isError)
            #expect(result.content.contains("Volume") || result.content.contains("Directory"))
        }
    }

    // MARK: - SystemNetworkInfoTool

    @Suite("SystemNetworkInfoTool")
    struct SystemNetworkInfoToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = SystemNetworkInfoTool(shellService: ShellService())
            #expect(tool.identifier == "system_network_info")
            #expect(tool.category == .system)
            #expect(tool.actionTier == .read)
        }

        @Test("returns non-error result with network info")
        func executionReturnsNetworkInfo() async throws {
            let tool = SystemNetworkInfoTool(shellService: ShellService())
            let result = try await tool.execute(parameters: [:])
            #expect(!result.isError)
            #expect(result.content.contains("Interface") || result.content.contains("DNS") || result.content.contains("Network"))
        }
    }

    // MARK: - SystemProvider

    @Suite("SystemProvider")
    struct SystemProviderTests {

        @Test("provider has correct category and tool count")
        func providerMetadata() {
            let provider = SystemProvider(shellService: ShellService())
            #expect(provider.category == .system)
            #expect(provider.displayName == "System Info")
            #expect(provider.tools.count == 4)
        }

        @Test("provider contains all expected tool identifiers")
        func providerToolIdentifiers() {
            let provider = SystemProvider(shellService: ShellService())
            let ids = Set(provider.tools.map(\.identifier))
            #expect(ids.contains("system_info"))
            #expect(ids.contains("system_monitor"))
            #expect(ids.contains("system_storage"))
            #expect(ids.contains("system_network_info"))
        }
    }
}
