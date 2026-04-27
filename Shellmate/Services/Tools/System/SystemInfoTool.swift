import Foundation

// MARK: - SystemInfoTool

/// Returns static system information: macOS version, hardware model, chip, cores, memory, hostname, uptime.
/// Uses Foundation and sysctl only — no shell commands needed.
struct SystemInfoTool: AgentTool {
    let identifier = "system_info"
    let toolDescription = "Get system information including macOS version, hardware model, chip type, CPU cores, memory, hostname, and uptime."
    let category = ToolCategory.system
    let actionTier = ActionTier.read
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [:],
        required: []
    )

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        let info = ProcessInfo.processInfo
        let osVersion = info.operatingSystemVersion
        let versionString = "\(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)"

        let model = sysctlString("hw.model") ?? "Unknown"
        let chip = sysctlString("machdep.cpu.brand_string") ?? "Apple Silicon"
        let physicalCores = ProcessInfo.processInfo.processorCount
        let activeCores = ProcessInfo.processInfo.activeProcessorCount
        let memoryGB = String(format: "%.1f", Double(info.physicalMemory) / 1_073_741_824)
        let hostname = info.hostName
        let uptime = formatUptime(info.systemUptime)

        let output = """
        macOS Version: \(versionString)
        Hardware Model: \(model)
        Chip: \(chip)
        CPU Cores: \(physicalCores) (active: \(activeCores))
        Memory: \(memoryGB) GB
        Hostname: \(hostname)
        Uptime: \(uptime)
        """

        return .success(output)
    }

    // MARK: - Private helpers

    private func sysctlString(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
        let bytes = buffer.prefix { $0 != 0 }.map(UInt8.init(bitPattern:))
        return String(decoding: bytes, as: UTF8.self)
    }

    private func formatUptime(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let days = totalSeconds / 86400
        let hours = (totalSeconds % 86400) / 3600
        let minutes = (totalSeconds % 3600) / 60

        var parts: [String] = []
        if days > 0 { parts.append("\(days)d") }
        if hours > 0 { parts.append("\(hours)h") }
        parts.append("\(minutes)m")
        return parts.joined(separator: " ")
    }
}
