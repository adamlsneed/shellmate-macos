import Testing
import Foundation
@testable import Shellmate

@Suite("NetworkProvider Tools")
struct NetworkToolTests {

    private let shellService = ShellService()

    // MARK: - NetworkProvider

    @Test("provider has 9 tools")
    func providerToolCount() {
        let provider = NetworkProvider(shellService: shellService)
        #expect(provider.tools.count == 9)
        #expect(provider.category == .network)
        #expect(!provider.displayName.isEmpty)
    }

    // MARK: - NetworkStatusTool

    @Suite("NetworkStatusTool")
    struct NetworkStatusToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = NetworkStatusTool(shellService: ShellService())
            #expect(tool.identifier == "network_status")
            #expect(tool.category == .network)
            #expect(tool.actionTier == .read)
        }
    }

    // MARK: - WifiNetworksTool

    @Suite("WifiNetworksTool")
    struct WifiNetworksToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = WifiNetworksTool(shellService: ShellService())
            #expect(tool.identifier == "wifi_networks")
            #expect(tool.category == .network)
            #expect(tool.actionTier == .read)
        }
    }

    // MARK: - WifiConnectTool

    @Suite("WifiConnectTool")
    struct WifiConnectToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = WifiConnectTool(shellService: ShellService())
            #expect(tool.identifier == "wifi_connect")
            #expect(tool.category == .network)
            #expect(tool.actionTier == .write)
        }

        @Test("has non-empty confirmation description")
        func confirmationDescription() {
            let tool = WifiConnectTool(shellService: ShellService())
            let desc = tool.confirmationDescription(parameters: ["ssid": "MyNetwork"])
            #expect(!desc.isEmpty)
            #expect(desc.contains("MyNetwork"))
        }

        @Test("returns error for missing ssid")
        func missingSSID() async throws {
            let tool = WifiConnectTool(shellService: ShellService())
            let result = try await tool.execute(parameters: [:])
            #expect(result.isError)
        }
    }

    // MARK: - BluetoothStatusTool

    @Suite("BluetoothStatusTool")
    struct BluetoothStatusToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = BluetoothStatusTool(shellService: ShellService())
            #expect(tool.identifier == "bluetooth_status")
            #expect(tool.category == .network)
            #expect(tool.actionTier == .read)
        }
    }

    // MARK: - BluetoothToggleTool

    @Suite("BluetoothToggleTool")
    struct BluetoothToggleToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = BluetoothToggleTool(shellService: ShellService())
            #expect(tool.identifier == "bluetooth_toggle")
            #expect(tool.category == .network)
            #expect(tool.actionTier == .write)
        }

        @Test("has non-empty confirmation description")
        func confirmationDescription() {
            let tool = BluetoothToggleTool(shellService: ShellService())
            let desc = tool.confirmationDescription(parameters: ["enabled": true])
            #expect(!desc.isEmpty)
        }

        @Test("returns error for missing enabled param")
        func missingEnabled() async throws {
            let tool = BluetoothToggleTool(shellService: ShellService())
            let result = try await tool.execute(parameters: [:])
            #expect(result.isError)
        }
    }

    // MARK: - NetworkDnsLookupTool

    @Suite("NetworkDnsLookupTool")
    struct NetworkDnsLookupToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = NetworkDnsLookupTool(shellService: ShellService())
            #expect(tool.identifier == "network_dns_lookup")
            #expect(tool.category == .network)
            #expect(tool.actionTier == .read)
        }

        @Test("returns error for missing hostname")
        func missingHostname() async throws {
            let tool = NetworkDnsLookupTool(shellService: ShellService())
            let result = try await tool.execute(parameters: [:])
            #expect(result.isError)
        }

        @Test("resolves localhost")
        func resolvesLocalhost() async throws {
            let tool = NetworkDnsLookupTool(shellService: ShellService())
            let result = try await tool.execute(parameters: ["hostname": "localhost"])
            #expect(!result.isError)
        }
    }

    // MARK: - NetworkPingTool

    @Suite("NetworkPingTool")
    struct NetworkPingToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = NetworkPingTool(shellService: ShellService())
            #expect(tool.identifier == "network_ping")
            #expect(tool.category == .network)
            #expect(tool.actionTier == .read)
        }

        @Test("returns error for missing host")
        func missingHost() async throws {
            let tool = NetworkPingTool(shellService: ShellService())
            let result = try await tool.execute(parameters: [:])
            #expect(result.isError)
        }

        @Test("pings localhost successfully")
        func pingLocalhost() async throws {
            let tool = NetworkPingTool(shellService: ShellService())
            let result = try await tool.execute(parameters: ["host": "localhost", "count": "1"])
            #expect(!result.isError)
            #expect(result.content.contains("localhost") || result.content.contains("127.0.0.1"))
        }
    }

    // MARK: - NetworkPortCheckTool

    @Suite("NetworkPortCheckTool")
    struct NetworkPortCheckToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = NetworkPortCheckTool(shellService: ShellService())
            #expect(tool.identifier == "network_port_check")
            #expect(tool.category == .network)
            #expect(tool.actionTier == .read)
        }

        @Test("returns error for missing host")
        func missingHost() async throws {
            let tool = NetworkPortCheckTool(shellService: ShellService())
            let result = try await tool.execute(parameters: ["port": "80"])
            #expect(result.isError)
        }

        @Test("returns error for missing port")
        func missingPort() async throws {
            let tool = NetworkPortCheckTool(shellService: ShellService())
            let result = try await tool.execute(parameters: ["host": "localhost"])
            #expect(result.isError)
        }
    }

    // MARK: - VpnStatusTool

    @Suite("VpnStatusTool")
    struct VpnStatusToolTests {

        @Test("conforms to AgentTool with correct metadata")
        func conformance() {
            let tool = VpnStatusTool(shellService: ShellService())
            #expect(tool.identifier == "vpn_status")
            #expect(tool.category == .network)
            #expect(tool.actionTier == .read)
        }
    }
}
