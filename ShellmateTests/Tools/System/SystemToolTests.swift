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
            let shell = FakeShellRunner()
            let tool = SystemMonitorTool(shellService: shell)
            let result = try await tool.execute(parameters: [:])
            #expect(!result.isError)
            #expect(result.content.contains("CPU"))
            #expect(result.content.contains("Memory"))
            #expect(result.content.contains("Battery"))
            #expect(await shell.runCommandCalls == [
                "top -l 1 -n 0 -s 0",
                "vm_stat",
                "pmset -g batt",
            ])
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
            let shell = FakeShellRunner()
            let tool = SystemStorageTool(shellService: shell)
            let result = try await tool.execute(parameters: [:])
            #expect(!result.isError)
            #expect(result.content.contains("Volume"))
            #expect(await shell.runCommandCalls == ["df -h"])
            #expect(await shell.runCalls.map(\.arguments) == [[
                "-h",
                "-d",
                "1",
                FileManager.default.homeDirectoryForCurrentUser.path,
            ]])
        }

        @Test("returns non-error result with explicit directory")
        func executionWithExplicitDirectory() async throws {
            let shell = FakeShellRunner()
            let tool = SystemStorageTool(shellService: shell)
            let result = try await tool.execute(parameters: ["directory": "/tmp", "depth": 2])
            #expect(!result.isError)
            #expect(result.content.contains("Volume") || result.content.contains("Directory"))
            #expect(await shell.runCalls.map(\.arguments) == [["-h", "-d", "2", "/tmp"]])
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
            let shell = FakeShellRunner()
            let tool = SystemNetworkInfoTool(shellService: shell)
            let result = try await tool.execute(parameters: [:])
            #expect(!result.isError)
            #expect(result.content.contains("Active Interfaces"))
            #expect(result.content.contains("Interface Details"))
            #expect(result.content.contains("Wi-Fi"))
            #expect(result.content.contains("DNS Servers"))
            #expect(await shell.runCommandCalls == [
                "ifconfig -lu",
                "ifconfig | grep -E '^[a-z]|inet ' | grep -v '127.0.0.1'",
                "/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I 2>/dev/null",
                "scutil --dns | grep 'nameserver\\[' | sort -u",
            ])
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

private actor FakeShellRunner: ShellCommandRunning {
    struct RunCall: Sendable {
        let executable: String
        let arguments: [String]
        let timeout: TimeInterval
    }

    private(set) var runCommandCalls: [String] = []
    private(set) var runCalls: [RunCall] = []

    func runCommand(
        _ command: String,
        workingDirectory: URL? = nil,
        timeout: TimeInterval = 60
    ) async throws -> ShellResult {
        runCommandCalls.append(command)
        let output = switch command {
        case "df -h":
            "Filesystem Size Used Avail Capacity Mounted on\n/dev/disk3s1 100G 40G 60G 40% /"
        case "top -l 1 -n 0 -s 0":
            "Load Avg: 1.23, 1.45, 1.67\nCPU usage: 10.00% user, 5.00% sys, 85.00% idle"
        case "vm_stat":
            "Mach Virtual Memory Statistics: (page size of 16384 bytes)\nPages free: 1000."
        case "pmset -g batt":
            "Now drawing from 'AC Power'\n -InternalBattery-0 100%; charged"
        case "ifconfig -lu":
            "lo0 en0"
        case "ifconfig | grep -E '^[a-z]|inet ' | grep -v '127.0.0.1'":
            "en0: flags=8863<UP,BROADCAST,SMART,RUNNING>\n\tinet 192.0.2.1 netmask 0xffffff00 broadcast 192.0.2.255"
        case "/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I 2>/dev/null":
            " SSID: TestNetwork"
        case "scutil --dns | grep 'nameserver\\[' | sort -u":
            "nameserver[0] : 1.1.1.1"
        default:
            ""
        }
        return ShellResult(
            exitCode: 0,
            stdout: output,
            stderr: "",
            duration: 0
        )
    }

    func run(
        executable: String,
        arguments: [String] = [],
        environment: [String: String]? = nil,
        workingDirectory: URL? = nil,
        timeout: TimeInterval = 300
    ) async throws -> ShellResult {
        runCalls.append(RunCall(executable: executable, arguments: arguments, timeout: timeout))
        return ShellResult(exitCode: 0, stdout: "4.0K\t\(arguments.last ?? "")", stderr: "", duration: 0)
    }
}
