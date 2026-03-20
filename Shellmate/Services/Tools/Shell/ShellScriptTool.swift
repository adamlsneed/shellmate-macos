import Foundation

// MARK: - ShellScriptTool

/// Writes a multi-line script to a temp file and executes it.
struct ShellScriptTool: AgentTool {
    let identifier = "shell_script"
    let toolDescription = "Execute a multi-line shell script. Writes the script to a temporary file, makes it executable, runs it, and cleans up."
    let category = ToolCategory.shell
    let actionTier = ActionTier.write
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "script": ToolProperty(type: "string", description: "The shell script content to execute"),
            "interpreter": ToolProperty(type: "string", description: "The interpreter to use (default /bin/zsh)"),
        ],
        required: ["script"]
    )

    private let shellService: ShellService
    init(service: ShellService) { self.shellService = service }

    func confirmationDescription(parameters: [String: Any]) -> String {
        let script = parameters["script"] as? String ?? "unknown script"
        let preview = script.count > 200 ? String(script.prefix(200)) + "..." : script
        return "I'd like to run this script:\n\n```\n\(preview)\n```"
    }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let script = parameters["script"] as? String else {
            return .error("Missing required 'script' parameter")
        }

        let interpreter = parameters["interpreter"] as? String ?? "/bin/zsh"

        // Write script to temp file
        let tempDir = FileManager.default.temporaryDirectory
        let scriptFile = tempDir.appendingPathComponent("shellmate_script_\(UUID().uuidString).sh")

        do {
            try script.write(to: scriptFile, atomically: true, encoding: .utf8)
            // Set permissions to 0o700 (rwx------)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o700],
                ofItemAtPath: scriptFile.path
            )
        } catch {
            return .error("Failed to write script to temp file: \(error.localizedDescription)")
        }

        defer {
            try? FileManager.default.removeItem(at: scriptFile)
        }

        do {
            let result = try await shellService.run(
                executable: interpreter,
                arguments: [scriptFile.path]
            )

            var output = result.stdout
            if !result.stderr.isEmpty {
                output += (output.isEmpty ? "" : "\n") + "STDERR: \(result.stderr)"
            }
            if result.exitCode != 0 {
                output += "\nExit code: \(result.exitCode)"
            }

            let content = output.isEmpty ? "(no output)" : output
            return result.succeeded
                ? .success(content, metadata: ["exit_code": "0", "duration": String(format: "%.2f", result.duration)])
                : .error(content, metadata: ["exit_code": "\(result.exitCode)", "duration": String(format: "%.2f", result.duration)])
        } catch let error as ShellServiceError {
            return .error(error.localizedDescription)
        }
    }
}
