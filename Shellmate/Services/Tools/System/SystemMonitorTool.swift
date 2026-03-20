import Foundation

// MARK: - SystemMonitorTool

/// Returns live system metrics: CPU load averages, memory usage, and battery status.
struct SystemMonitorTool: AgentTool {
    let identifier = "system_monitor"
    let toolDescription = "Get live system metrics including CPU load averages, memory usage breakdown, and battery status."
    let category = ToolCategory.system
    let actionTier = ActionTier.read
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [:],
        required: []
    )

    private let shellService: ShellService
    init(shellService: ShellService) { self.shellService = shellService }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        var sections: [String] = []

        // CPU load
        let cpuResult = try await shellService.runCommand("top -l 1 -n 0 -s 0", timeout: 15)
        if cpuResult.succeeded {
            let cpuLines = cpuResult.stdout
                .split(separator: "\n")
                .filter { $0.contains("Load Avg") || $0.contains("CPU usage") }
                .map(String.init)
            if !cpuLines.isEmpty {
                sections.append("--- CPU ---\n" + cpuLines.joined(separator: "\n"))
            }
        }

        // Memory via vm_stat
        let vmResult = try await shellService.runCommand("vm_stat", timeout: 10)
        if vmResult.succeeded {
            sections.append("--- Memory ---\n" + vmResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        // Battery
        let battResult = try await shellService.runCommand("pmset -g batt", timeout: 10)
        if battResult.succeeded, !battResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            sections.append("--- Battery ---\n" + battResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        if sections.isEmpty {
            return .error("Failed to gather system metrics")
        }

        return .success(sections.joined(separator: "\n\n"))
    }
}
