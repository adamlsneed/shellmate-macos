import Foundation

/// Kills the process listening on a specific TCP port.
struct PortKillTool: AgentTool {
    let identifier = "port_kill"
    let toolDescription = "Kill the process listening on a specific TCP port."
    let category = ToolCategory.developer
    let actionTier = ActionTier.destructive
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "port": ToolProperty(type: "string", description: "TCP port number to kill the listener on"),
        ],
        required: ["port"]
    )

    private let shellService: ShellService
    init(shellService: ShellService) { self.shellService = shellService }

    func confirmationDescription(parameters: [String: Any]) -> String {
        let port = parameters["port"] as? String ?? "unknown"
        return "Kill process listening on port \(port)"
    }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let port = parameters["port"] as? String, !port.isEmpty, Int(port) != nil else {
            return .error("Missing or invalid required parameter: port (must be a number)")
        }

        // Find the PID listening on this port
        let findResult = try await shellService.runCommand(
            "lsof -iTCP:\(port) -sTCP:LISTEN -t", timeout: 10
        )

        let pids = findResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: "\n")
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }

        if pids.isEmpty {
            return .error("No process found listening on port \(port).")
        }

        // Check if any PID belongs to a protected process
        for pid in pids {
            let checkResult = try await shellService.runCommand("ps -p \(pid) -o comm=", timeout: 5)
            if checkResult.succeeded {
                let processName = checkResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
                    .split(separator: "/").last.map(String.init) ?? ""
                if ProcessKillTool.protectedProcesses.contains(processName) {
                    return .error("Cannot kill protected system process '\(processName)' on port \(port).")
                }
            }
        }

        // Kill all PIDs
        for pid in pids {
            _ = try await shellService.run(executable: "kill", arguments: ["-TERM", String(pid)])
        }

        return .success("Sent TERM signal to \(pids.count) process(es) on port \(port): \(pids.map(String.init).joined(separator: ", "))")
    }
}
