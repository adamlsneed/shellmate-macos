import Foundation
import AppKit
import ApplicationServices

/// Moves a window to a specific position using the Accessibility API.
struct WindowMoveTool: AgentTool {
    let identifier = "window_move"
    let toolDescription = "Move an application window to a specific screen position (x, y coordinates)."
    let category = ToolCategory.windows
    let actionTier = ActionTier.write
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "app": ToolProperty(
                type: "string",
                description: "Name of the application whose window to move."
            ),
            "x": ToolProperty(
                type: "integer",
                description: "X coordinate (pixels from left)."
            ),
            "y": ToolProperty(
                type: "integer",
                description: "Y coordinate (pixels from top)."
            ),
        ],
        required: ["app", "x", "y"]
    )

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let app = parameters["app"] as? String else {
            return .error("Missing required parameter: app")
        }

        let x: Int
        if let xi = parameters["x"] as? Int { x = xi }
        else if let xd = parameters["x"] as? Double { x = Int(xd) }
        else { return .error("Missing required parameter: x") }

        let y: Int
        if let yi = parameters["y"] as? Int { y = yi }
        else if let yd = parameters["y"] as? Double { y = Int(yd) }
        else { return .error("Missing required parameter: y") }

        guard let runningApp = NSWorkspace.shared.runningApplications.first(where: {
            $0.localizedName?.localizedCaseInsensitiveContains(app) == true
        }) else {
            return .error("Application '\(app)' is not running.")
        }

        let appElement = AXUIElementCreateApplication(runningApp.processIdentifier)
        var windowRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &windowRef) == .success,
              let window = windowRef else {
            return .error("Could not access window for '\(app)'. Ensure Accessibility permission is granted.")
        }

        var position = CGPoint(x: CGFloat(x), y: CGFloat(y))
        guard let positionValue = AXValueCreate(.cgPoint, &position) else {
            return .error("Failed to create position value.")
        }

        let result = AXUIElementSetAttributeValue(window as! AXUIElement, kAXPositionAttribute as CFString, positionValue)
        if result == .success {
            return .success("Moved '\(app)' window to (\(x), \(y)).")
        }

        return .error("Failed to move window (error: \(result.rawValue)). Check Accessibility permissions.")
    }

    func confirmationDescription(parameters: [String: Any]) -> String {
        let app = parameters["app"] as? String ?? "window"
        let x = parameters["x"] as? Int ?? 0
        let y = parameters["y"] as? Int ?? 0
        return "Move \(app) to (\(x), \(y))"
    }
}
