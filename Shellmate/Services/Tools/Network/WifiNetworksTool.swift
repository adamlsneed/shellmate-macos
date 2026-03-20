import Foundation

/// Scans for available Wi-Fi networks.
struct WifiNetworksTool: AgentTool {
    let identifier = "wifi_networks"
    let toolDescription = "Scan for available Wi-Fi networks showing SSID, signal strength, and security type."
    let category = ToolCategory.network
    let actionTier = ActionTier.read
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [:],
        required: []
    )

    private let shellService: ShellService
    init(shellService: ShellService) { self.shellService = shellService }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        // Try the modern CoreWLAN-based approach via system_profiler
        let result = try await shellService.runCommand(
            "/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -s",
            timeout: 15
        )
        if result.succeeded {
            let output = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            return .success(output.isEmpty ? "No Wi-Fi networks found." : output)
        }

        // Fallback to networksetup
        let fallback = try await shellService.runCommand(
            "networksetup -listallhardwareports | grep -A 1 'Wi-Fi' | grep 'Device' | awk '{print $2}'",
            timeout: 10
        )
        if fallback.succeeded, !fallback.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .success("Wi-Fi interface detected but scan unavailable. Use System Settings to view networks.")
        }

        return .error("Unable to scan Wi-Fi networks. Airport utility may not be available.")
    }
}
