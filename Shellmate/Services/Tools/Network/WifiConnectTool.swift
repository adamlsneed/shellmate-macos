import Foundation

/// Connects to a Wi-Fi network.
struct WifiConnectTool: AgentTool {
    let identifier = "wifi_connect"
    let toolDescription = "Connect to a Wi-Fi network by SSID."
    let category = ToolCategory.network
    let actionTier = ActionTier.write
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "ssid": ToolProperty(type: "string", description: "Wi-Fi network name (SSID) to connect to"),
            "password": ToolProperty(type: "string", description: "Wi-Fi password. Required for secured networks."),
        ],
        required: ["ssid"]
    )

    private let shellService: ShellService
    init(shellService: ShellService) { self.shellService = shellService }

    func confirmationDescription(parameters: [String: Any]) -> String {
        let ssid = parameters["ssid"] as? String ?? "unknown"
        return "Connect to Wi-Fi network '\(ssid)'"
    }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let ssid = parameters["ssid"] as? String, !ssid.isEmpty else {
            return .error("Missing required parameter: ssid")
        }

        // Find the Wi-Fi interface name
        let ifResult = try await shellService.runCommand(
            "networksetup -listallhardwareports | grep -A 1 'Wi-Fi' | grep 'Device' | awk '{print $2}'",
            timeout: 10
        )
        let iface = ifResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !iface.isEmpty else {
            return .error("Could not find Wi-Fi interface.")
        }

        var args = ["-setairportnetwork", iface, ssid]
        if let password = parameters["password"] as? String, !password.isEmpty {
            args.append(password)
        }

        let result = try await shellService.run(executable: "networksetup", arguments: args, timeout: 30)
        if result.succeeded {
            return .success("Connected to Wi-Fi network '\(ssid)'.")
        }
        return .error("Failed to connect to '\(ssid)': \(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines))")
    }
}
