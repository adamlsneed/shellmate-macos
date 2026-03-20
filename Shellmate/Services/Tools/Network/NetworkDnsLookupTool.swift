import Foundation

/// Performs a DNS lookup for a hostname.
struct NetworkDnsLookupTool: AgentTool {
    let identifier = "network_dns_lookup"
    let toolDescription = "Perform a DNS lookup for a hostname, showing IP addresses and DNS records."
    let category = ToolCategory.network
    let actionTier = ActionTier.read
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "hostname": ToolProperty(type: "string", description: "Hostname to look up (e.g. 'example.com')"),
            "type": ToolProperty(type: "string", description: "DNS record type. Defaults to 'A'.", enumValues: ["A", "AAAA", "MX", "NS", "TXT", "CNAME", "SOA"]),
        ],
        required: ["hostname"]
    )

    private let shellService: ShellService
    init(shellService: ShellService) { self.shellService = shellService }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let hostname = parameters["hostname"] as? String, !hostname.isEmpty else {
            return .error("Missing required parameter: hostname")
        }

        let recordType = (parameters["type"] as? String) ?? "A"

        let result = try await shellService.run(
            executable: "dig", arguments: [hostname, recordType, "+short"],
            timeout: 15
        )
        if result.succeeded {
            let output = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            return .success(output.isEmpty ? "No \(recordType) records found for \(hostname)." : "\(recordType) records for \(hostname):\n\(output)")
        }
        return .error("DNS lookup failed: \(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines))")
    }
}
