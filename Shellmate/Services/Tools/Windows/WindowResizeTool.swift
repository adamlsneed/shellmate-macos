import Foundation
import AppKit
import ApplicationServices

/// Resizes a window using the Accessibility API.
struct WindowResizeTool: AgentTool {
    let identifier = "window_resize"
    let toolDescription = "Resize an application window to a specific width and height."
    let category = ToolCategory.windows
    let actionTier = ActionTier.write
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "app": ToolProperty(
                type: "string",
                description: "Name of the application whose window to resize."
            ),
            "width": ToolProperty(
                type: "integer",
                description: "New width in pixels."
            ),
            "height": ToolProperty(
                type: "integer",
                description: "New height in pixels."
            ),
        ],
        required: ["app", "width", "height"]
    )

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let app = parameters["app"] as? String else {
            return .error("Missing required parameter: app")
        }

        let width: Int
        if let w = parameters["width"] as? Int { width = w }
        else if let w = parameters["width"] as? Double { width = Int(w) }
        else { return .error("Missing required parameter: width") }

        let height: Int
        if let h = parameters["height"] as? Int { height = h }
        else if let h = parameters["height"] as? Double { height = Int(h) }
        else { return .error("Missing required parameter: height") }

        guard width > 0, height > 0 else {
            return .error("Width and height must be positive values.")
        }

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

        var size = CGSize(width: CGFloat(width), height: CGFloat(height))
        guard let sizeValue = AXValueCreate(.cgSize, &size) else {
            return .error("Failed to create size value.")
        }

        let result = AXUIElementSetAttributeValue(window as! AXUIElement, kAXSizeAttribute as CFString, sizeValue)
        if result == .success {
            return .success("Resized '\(app)' window to \(width)x\(height).")
        }

        return .error("Failed to resize window (error: \(result.rawValue)). Check Accessibility permissions.")
    }

    func confirmationDescription(parameters: [String: Any]) -> String {
        let app = parameters["app"] as? String ?? "window"
        let w = parameters["width"] as? Int ?? 0
        let h = parameters["height"] as? Int ?? 0
        return "Resize \(app) to \(w)x\(h)"
    }
}
