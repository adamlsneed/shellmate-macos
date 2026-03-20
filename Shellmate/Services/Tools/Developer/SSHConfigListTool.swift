import Foundation

/// Lists SSH config hosts with key paths redacted.
struct SSHConfigListTool: AgentTool {
    let identifier = "ssh_config_list"
    let toolDescription = "List configured SSH hosts from ~/.ssh/config. Private key file paths are redacted for security."
    let category = ToolCategory.developer
    let actionTier = ActionTier.read
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [:],
        required: []
    )

    private let shellService: ShellService
    init(shellService: ShellService) { self.shellService = shellService }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        let configPath = NSString(string: "~/.ssh/config").expandingTildeInPath

        guard FileManager.default.fileExists(atPath: configPath) else {
            return .success("No SSH config file found at ~/.ssh/config")
        }

        guard let content = try? String(contentsOfFile: configPath, encoding: .utf8) else {
            return .error("Failed to read SSH config file.")
        }

        // Redact IdentityFile paths for security
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false)
        let redacted = lines.map { line -> String in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.lowercased().hasPrefix("identityfile") {
                return "    IdentityFile [REDACTED]"
            }
            return String(line)
        }

        return .success(redacted.joined(separator: "\n"))
    }
}
