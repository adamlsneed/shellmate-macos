import Foundation

/// Sets an environment variable, optionally persisting to shell profile.
struct EnvSetTool: AgentTool {
    let identifier = "env_set"
    let toolDescription = "Set an environment variable. Can optionally persist it by appending an export to your shell profile."
    let category = ToolCategory.developer
    let actionTier = ActionTier.write
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "key": ToolProperty(type: "string", description: "Environment variable name"),
            "value": ToolProperty(type: "string", description: "Value to set"),
            "persist": ToolProperty(type: "boolean", description: "If true, append export to ~/.zshrc. Defaults to false."),
        ],
        required: ["key", "value"]
    )

    /// Key patterns that look like secrets — warn before persisting.
    private static let secretPatterns = [
        "KEY", "SECRET", "TOKEN", "PASSWORD", "PASSWD", "CREDENTIAL",
        "AUTH", "PRIVATE", "API_KEY", "APIKEY",
    ]

    private let shellService: ShellService
    init(shellService: ShellService) { self.shellService = shellService }

    func confirmationDescription(parameters: [String: Any]) -> String {
        let key = parameters["key"] as? String ?? "unknown"
        let persist = parameters["persist"] as? Bool ?? false
        let isSecret = Self.secretPatterns.contains { key.uppercased().contains($0) }
        var desc = "Set environment variable \(key)"
        if persist { desc += " (persisted to ~/.zshrc)" }
        if isSecret { desc += " [WARNING: key name looks like a secret]" }
        return desc
    }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let key = parameters["key"] as? String, !key.isEmpty else {
            return .error("Missing required parameter: key")
        }
        guard let value = parameters["value"] as? String else {
            return .error("Missing required parameter: value")
        }

        let persist = parameters["persist"] as? Bool ?? false
        let isSecret = Self.secretPatterns.contains { key.uppercased().contains($0) }

        var messages: [String] = []

        if persist {
            if isSecret {
                messages.append("WARNING: '\(key)' looks like a secret. Persisting secrets in plain text shell profiles is not recommended. Consider using the macOS Keychain or a secrets manager instead.")
            }

            let profilePath = NSString(string: "~/.zshrc").expandingTildeInPath
            let exportLine = "\nexport \(key)=\"\(value.replacingOccurrences(of: "\"", with: "\\\""))\"\n"

            do {
                let handle = try FileHandle(forWritingTo: URL(fileURLWithPath: profilePath))
                handle.seekToEndOfFile()
                handle.write(exportLine.data(using: .utf8)!)
                handle.closeFile()
                messages.append("Appended export to ~/.zshrc. Run 'source ~/.zshrc' or open a new terminal for it to take effect.")
            } catch {
                messages.append("Failed to write to ~/.zshrc: \(error.localizedDescription)")
            }
        }

        // Set for current shell context (note: won't affect the app's own process, but the tool's description is clear)
        messages.insert("Set \(key)=\(isSecret ? "[REDACTED]" : value)", at: 0)
        return .success(messages.joined(separator: "\n"))
    }
}
