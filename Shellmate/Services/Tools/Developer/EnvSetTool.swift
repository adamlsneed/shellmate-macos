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

        // Reject keys that aren't valid POSIX identifiers — prevents injection of
        // newlines or `=value\nrm -rf /` payloads into ~/.zshrc.
        guard key.range(of: #"^[A-Za-z_][A-Za-z0-9_]*$"#, options: .regularExpression) != nil else {
            return .error("Invalid variable name '\(key)'. Use letters, digits, and underscores; must not start with a digit.")
        }

        let persist = parameters["persist"] as? Bool ?? false
        let isSecret = Self.secretPatterns.contains { key.uppercased().contains($0) }

        var messages: [String] = []

        if persist {
            if isSecret {
                messages.append("WARNING: '\(key)' looks like a secret. Persisting secrets in plain text shell profiles is not recommended. Consider using the macOS Keychain or a secrets manager instead.")
            }

            let profilePath = NSString(string: "~/.zshrc").expandingTildeInPath
            // Single-quote the value so backslashes, double quotes, and dollar signs
            // are all literal. Embedded single quotes are escaped via the standard
            // '\'' trick (close quote, escaped quote, reopen quote).
            let escapedValue = value.replacingOccurrences(of: "'", with: "'\\''")
            let exportLine = "\nexport \(key)='\(escapedValue)'\n"

            do {
                let handle = try FileHandle(forWritingTo: URL(fileURLWithPath: profilePath))
                handle.seekToEndOfFile()
                handle.write(exportLine.data(using: .utf8)!)
                handle.closeFile()
                messages.insert("Appended export to ~/.zshrc. Run 'source ~/.zshrc' or open a new terminal for it to take effect.", at: 0)
            } catch {
                return .error("Failed to write to ~/.zshrc: \(error.localizedDescription)")
            }
        } else {
            // Without persist=true, this tool cannot actually export the variable into
            // the user's shell — the agent runs in Shellmate's own process. Be honest
            // about that rather than reporting a misleading "Set FOO=bar" success.
            messages.append("Note: \(key) was NOT exported to your shell. Pass persist=true to append an export to ~/.zshrc, or run `export \(key)=...` in your terminal directly.")
        }

        if isSecret && !persist {
            // Don't echo the value in the success message even when not persisting.
            messages.insert("Acknowledged \(key)=[REDACTED]", at: 0)
        } else if !persist {
            messages.insert("Acknowledged \(key)=\(value)", at: 0)
        }
        return .success(messages.joined(separator: "\n"))
    }
}
