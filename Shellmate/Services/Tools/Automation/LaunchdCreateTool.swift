import Foundation

/// Creates a new launchd agent plist in ~/Library/LaunchAgents.
struct LaunchdCreateTool: AgentTool {
    let identifier = "launchd_create"
    let toolDescription = "Create a new launchd agent in ~/Library/LaunchAgents. Generates a plist file with the specified configuration."
    let category = ToolCategory.automation
    let actionTier = ActionTier.write
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "label": ToolProperty(
                type: "string",
                description: "The unique label for the agent (e.g., 'com.user.myscript')."
            ),
            "program": ToolProperty(
                type: "string",
                description: "The absolute path to the program to run."
            ),
            "arguments": ToolProperty(
                type: "string",
                description: "Space-separated arguments to pass to the program (optional)."
            ),
            "interval": ToolProperty(
                type: "integer",
                description: "Run interval in seconds (optional). If not set, runs at load."
            ),
            "run_at_load": ToolProperty(
                type: "string",
                description: "Whether to run the agent when loaded. 'true' or 'false'. Defaults to 'true'.",
                enumValues: ["true", "false"]
            ),
        ],
        required: ["label", "program"]
    )

    private let shellService: ShellService
    init(shellService: ShellService) { self.shellService = shellService }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let label = parameters["label"] as? String else {
            return .error("Missing required parameter: label")
        }
        guard let program = parameters["program"] as? String else {
            return .error("Missing required parameter: program")
        }

        // Validate label format
        guard label.range(of: #"^[a-zA-Z0-9._-]+$"#, options: .regularExpression) != nil else {
            return .error("Invalid label format. Use only letters, numbers, dots, hyphens, and underscores.")
        }

        // Build plist XML
        var programArgs = "<string>\(escapeXML(program))</string>"
        if let args = parameters["arguments"] as? String {
            let argParts = args.split(separator: " ").map { "<string>\(escapeXML(String($0)))</string>" }
            programArgs += "\n\t\t" + argParts.joined(separator: "\n\t\t")
        }

        let runAtLoad = (parameters["run_at_load"] as? String) != "false"

        var extraKeys = ""
        if let interval = parameters["interval"] as? Int {
            extraKeys += "\n\t<key>StartInterval</key>\n\t<integer>\(interval)</integer>"
        } else if let interval = parameters["interval"] as? Double {
            extraKeys += "\n\t<key>StartInterval</key>\n\t<integer>\(Int(interval))</integer>"
        }

        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
        \t<key>Label</key>
        \t<string>\(escapeXML(label))</string>
        \t<key>ProgramArguments</key>
        \t<array>
        \t\t\(programArgs)
        \t</array>
        \t<key>RunAtLoad</key>
        \t<\(runAtLoad)/>
        \(extraKeys)
        </dict>
        </plist>
        """

        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let agentsDir = "\(home)/Library/LaunchAgents"
        let plistPath = "\(agentsDir)/\(label).plist"

        // Ensure LaunchAgents directory exists
        let fm = FileManager.default
        if !fm.fileExists(atPath: agentsDir) {
            try fm.createDirectory(atPath: agentsDir, withIntermediateDirectories: true)
        }

        // Check if already exists
        if fm.fileExists(atPath: plistPath) {
            return .error("Agent '\(label)' already exists at \(plistPath). Remove it first if you want to replace it.")
        }

        // Write the plist
        do {
            try plist.write(toFile: plistPath, atomically: true, encoding: .utf8)
        } catch {
            return .error("Failed to write plist: \(error.localizedDescription)")
        }

        return .success("Launch agent created at: \(plistPath)\n\nTo load it now, run: launchctl load \(plistPath)\nTo unload: launchctl unload \(plistPath)")
    }

    func confirmationDescription(parameters: [String: Any]) -> String {
        let label = parameters["label"] as? String ?? "unknown"
        return "Create launch agent: \(label)"
    }

    private func escapeXML(_ str: String) -> String {
        str.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
