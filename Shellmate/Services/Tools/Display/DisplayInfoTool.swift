import CoreGraphics
import Foundation

// MARK: - DisplayInfoTool

/// Returns information about connected displays: count, resolution, and scale factor.
struct DisplayInfoTool: AgentTool {
    let identifier = "display_info"
    let toolDescription = "Get information about connected displays including count, resolution, and scale factor."
    let category = ToolCategory.display
    let actionTier = ActionTier.read
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [:],
        required: []
    )

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        var displayCount: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &displayCount) == .success, displayCount > 0 else {
            return .error("Failed to enumerate displays.")
        }

        var displayIDs = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
        guard CGGetActiveDisplayList(displayCount, &displayIDs, &displayCount) == .success else {
            return .error("Failed to get display list.")
        }

        var lines: [String] = ["Displays: \(displayCount)"]

        for (index, displayID) in displayIDs.prefix(Int(displayCount)).enumerated() {
            let bounds = CGDisplayBounds(displayID)
            let pixelsWide = CGDisplayPixelsWide(displayID)
            let pixelsHigh = CGDisplayPixelsHigh(displayID)

            // Scale factor: physical pixels / logical points
            let scaleFactor: Double
            if bounds.width > 0 {
                scaleFactor = Double(pixelsWide) / bounds.width
            } else {
                scaleFactor = 1.0
            }

            let isMain = CGDisplayIsMain(displayID) != 0
            let label = isMain ? "Display \(index + 1) (Main)" : "Display \(index + 1)"

            lines.append("""
            \(label):
              Resolution: \(pixelsWide) x \(pixelsHigh)
              Logical size: \(Int(bounds.width)) x \(Int(bounds.height)) points
              Scale factor: \(String(format: "%.1f", scaleFactor))x
            """)
        }

        return .success(lines.joined(separator: "\n"))
    }
}
