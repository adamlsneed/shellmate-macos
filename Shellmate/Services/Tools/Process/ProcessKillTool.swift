import Foundation

/// Kills a process by PID or name. Blocks protected system processes.
struct ProcessKillTool: AgentTool {
    let identifier = "process_kill"
    let toolDescription = "Kill a process by PID or name. Protected system processes (kernel_task, WindowServer, loginwindow, launchd, etc.) cannot be killed."
    let category = ToolCategory.apps
    let actionTier = ActionTier.destructive
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "pid": ToolProperty(type: "string", description: "Process ID to kill."),
            "name": ToolProperty(type: "string", description: "Process name to kill (uses killall)."),
            "signal": ToolProperty(type: "string", description: "Signal to send. Defaults to TERM.", enumValues: ["TERM", "KILL", "HUP", "INT"]),
        ],
        required: []
    )

    /// System processes that must never be killed.
    static let protectedProcesses: Set<String> = [
        "kernel_task", "WindowServer", "loginwindow", "launchd",
        "SystemUIServer", "Dock", "Finder",
    ]

    private let shellService: ShellService
    init(shellService: ShellService) { self.shellService = shellService }

    func confirmationDescription(parameters: [String: Any]) -> String {
        let signal = (parameters["signal"] as? String) ?? "TERM"
        if let pid = parameters["pid"] as? String {
            return "Send \(signal) to process PID \(pid)"
        } else if let name = parameters["name"] as? String {
            return "Send \(signal) to process '\(name)'"
        }
        return "Kill a process"
    }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        let signal = (parameters["signal"] as? String) ?? "TERM"

        if let name = parameters["name"] as? String, !name.isEmpty {
            // Check protected list
            if Self.protectedProcesses.contains(name) {
                return .error("Cannot kill protected system process '\(name)'. This process is essential for macOS stability.")
            }

            let result = try await shellService.run(executable: "killall", arguments: ["-\(signal)", name])
            if result.succeeded {
                return .success("Sent \(signal) to all processes named '\(name)'.")
            }
            return .error("Failed to kill '\(name)': \(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines))")
        }

        if let pidStr = parameters["pid"] as? String, let pid = Int(pidStr) {
            // Check if PID belongs to protected process
            let checkResult = try await shellService.runCommand("ps -p \(pid) -o comm=", timeout: 5)
            if checkResult.succeeded {
                let processName = checkResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
                    .split(separator: "/").last.map(String.init) ?? ""
                if Self.protectedProcesses.contains(processName) {
                    return .error("Cannot kill protected system process '\(processName)' (PID \(pid)). This process is essential for macOS stability.")
                }
            }

            let result = try await shellService.run(executable: "kill", arguments: ["-\(signal)", String(pid)])
            if result.succeeded {
                return .success("Sent \(signal) to PID \(pid).")
            }
            return .error("Failed to kill PID \(pid): \(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines))")
        }

        return .error("Provide either 'pid' or 'name' parameter to identify the process to kill.")
    }
}
