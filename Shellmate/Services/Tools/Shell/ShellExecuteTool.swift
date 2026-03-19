import Foundation

// MARK: - ShellExecuteTool

/// AgentTool wrapper around ShellService for LLM-driven shell execution.
struct ShellExecuteTool: AgentTool {
    let identifier = "shell_exec"
    let toolDescription = "Execute a shell command on the user's Mac. Use for running terminal commands, installing software, checking system info, etc."
    let category = ToolCategory.shell
    let actionTier = ActionTier.write
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "command": ToolProperty(type: "string", description: "The shell command to execute"),
            "timeout": ToolProperty(type: "integer", description: "Timeout in seconds (default 60)"),
        ],
        required: ["command"]
    )

    private let shellService: ShellService
    init(service: ShellService) { self.shellService = service }

    func confirmationDescription(parameters: [String: Any]) -> String {
        let command = parameters["command"] as? String ?? "unknown command"
        let display = command.count > 80 ? String(command.prefix(80)) + "..." : command
        return "I'd like to run this command: \(display)"
    }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let command = parameters["command"] as? String else {
            return .error("Missing required 'command' parameter")
        }

        let timeout = (parameters["timeout"] as? Double)
            ?? (parameters["timeout"] as? Int).map(Double.init)
            ?? 60.0

        do {
            let result = try await shellService.runCommand(command, timeout: timeout)

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

// MARK: - Compat shim for ToolExecutor (Task 8 will remove this)

/// Backward-compatible static interface matching the old ShellTool enum.
/// This shim allows ToolExecutor to continue working until it is refactored in Task 8.
enum ShellTool {
    static func execute(input: [String: Any]) async -> ToolExecutionResult {
        let service = ShellService()
        let tool = ShellExecuteTool(service: service)
        do {
            let result = try await tool.execute(parameters: input)
            return ToolExecutionResult(content: result.content, isError: result.isError)
        } catch {
            return ToolExecutionResult(content: error.localizedDescription, isError: true)
        }
    }
}
