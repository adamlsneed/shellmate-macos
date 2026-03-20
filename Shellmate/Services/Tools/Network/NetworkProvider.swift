import Foundation

/// Provides network diagnostic and connectivity tools.
struct NetworkProvider: ToolProvider {
    let category = ToolCategory.network
    let displayName = "Network & Connectivity"

    private let shellService: ShellService
    init(shellService: ShellService) { self.shellService = shellService }

    var tools: [AgentTool] {
        [
            NetworkStatusTool(shellService: shellService),
            WifiNetworksTool(shellService: shellService),
            WifiConnectTool(shellService: shellService),
            BluetoothStatusTool(shellService: shellService),
            BluetoothToggleTool(shellService: shellService),
            NetworkDnsLookupTool(shellService: shellService),
            NetworkPingTool(shellService: shellService),
            NetworkPortCheckTool(shellService: shellService),
            VpnStatusTool(shellService: shellService),
        ]
    }
}
