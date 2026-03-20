import Foundation
import AppKit
import CoreGraphics

/// Lists visible windows on screen.
struct WindowListTool: AgentTool {
    let identifier = "window_list"
    let toolDescription = "List all visible windows on screen with their app name, title, position, and size."
    let category = ToolCategory.windows
    let actionTier = ActionTier.read
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "app": ToolProperty(
                type: "string",
                description: "Filter by application name (optional)."
            ),
        ],
        required: []
    )

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        let filterApp = parameters["app"] as? String

        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return .error("Failed to get window list.")
        }

        var output = ""
        var count = 0

        for window in windowList {
            guard let ownerName = window[kCGWindowOwnerName as String] as? String,
                  let bounds = window[kCGWindowBounds as String] as? [String: Any],
                  let layer = window[kCGWindowLayer as String] as? Int,
                  layer == 0 else { // layer 0 = normal windows
                continue
            }

            if let filterApp, !ownerName.localizedCaseInsensitiveContains(filterApp) {
                continue
            }

            let title = window[kCGWindowName as String] as? String ?? "(untitled)"
            let x = bounds["X"] as? Int ?? 0
            let y = bounds["Y"] as? Int ?? 0
            let w = bounds["Width"] as? Int ?? 0
            let h = bounds["Height"] as? Int ?? 0
            let pid = window[kCGWindowOwnerPID as String] as? Int ?? 0

            output += "\(ownerName) | \(title) | pid:\(pid) | pos:(\(x),\(y)) size:\(w)x\(h)\n"
            count += 1
        }

        if output.isEmpty {
            return .success("No visible windows found\(filterApp.map { " for '\($0)'" } ?? "").")
        }

        return .success("\(count) windows:\n\(output)")
    }
}
