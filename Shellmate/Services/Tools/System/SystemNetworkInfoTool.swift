import Foundation

// MARK: - SystemNetworkInfoTool

/// Returns network configuration: active interfaces, Wi-Fi details, and DNS servers.
struct SystemNetworkInfoTool: AgentTool {
    let identifier = "system_network_info"
    let toolDescription = "Get network information including active interfaces, Wi-Fi details, and DNS servers."
    let category = ToolCategory.system
    let actionTier = ActionTier.read
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [:],
        required: []
    )

    private let shellService: any ShellCommandRunning
    init(shellService: any ShellCommandRunning) { self.shellService = shellService }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        var sections: [String] = []

        // Active network interfaces
        let ifResult = try await shellService.runCommand("ifconfig -lu", workingDirectory: nil, timeout: 10)
        if ifResult.succeeded {
            let interfaces = ifResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            sections.append("--- Active Interfaces ---\n\(interfaces)")
        }

        // Detailed interface info (IPv4 addresses)
        let inetResult = try await shellService.runCommand(
            "ifconfig | grep -E '^[a-z]|inet ' | grep -v '127.0.0.1'",
            workingDirectory: nil,
            timeout: 10
        )
        if inetResult.succeeded, !inetResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            sections.append("--- Interface Details ---\n" + inetResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        // Wi-Fi info via airport
        let wifiResult = try await shellService.runCommand(
            "/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I 2>/dev/null",
            workingDirectory: nil,
            timeout: 10
        )
        if wifiResult.succeeded, !wifiResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            sections.append("--- Wi-Fi ---\n" + wifiResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        // DNS servers
        let dnsResult = try await shellService.runCommand(
            "scutil --dns | grep 'nameserver\\[' | sort -u",
            workingDirectory: nil,
            timeout: 10
        )
        if dnsResult.succeeded, !dnsResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            sections.append("--- DNS Servers ---\n" + dnsResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        if sections.isEmpty {
            return .error("Failed to gather network information")
        }

        return .success(sections.joined(separator: "\n\n"))
    }
}
