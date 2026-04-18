import Foundation
import AppKit
import ApplicationServices

/// Arranges a window using preset layouts (left half, right half, maximize, etc.).
struct WindowArrangeTool: AgentTool {
    let identifier = "window_arrange"
    let toolDescription = "Arrange an application window using preset layouts: left_half, right_half, top_half, bottom_half, maximize, or center."
    let category = ToolCategory.windows
    let actionTier = ActionTier.write
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "app": ToolProperty(
                type: "string",
                description: "Name of the application whose window to arrange."
            ),
            "preset": ToolProperty(
                type: "string",
                description: "Layout preset to apply.",
                enumValues: ["left_half", "right_half", "top_half", "bottom_half", "maximize", "center"]
            ),
        ],
        required: ["app", "preset"]
    )

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let app = parameters["app"] as? String else {
            return .error("Missing required parameter: app")
        }
        guard let preset = parameters["preset"] as? String else {
            return .error("Missing required parameter: preset")
        }

        let validPresets = ["left_half", "right_half", "top_half", "bottom_half", "maximize", "center"]
        guard validPresets.contains(preset) else {
            return .error("Invalid preset '\(preset)'. Use: \(validPresets.joined(separator: ", "))")
        }

        guard let screen = NSScreen.main else {
            return .error("No main screen found.")
        }

        let frame = screen.visibleFrame

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

        let axWindow = window as! AXUIElement

        // Calculate target position and size based on preset
        // Note: AX coordinates have origin at top-left, NSScreen.visibleFrame has origin at bottom-left
        let menuBarHeight = NSScreen.main!.frame.height - frame.height - frame.origin.y
        let targetPos: CGPoint
        let targetSize: CGSize

        switch preset {
        case "left_half":
            targetPos = CGPoint(x: frame.origin.x, y: menuBarHeight)
            targetSize = CGSize(width: frame.width / 2, height: frame.height)
        case "right_half":
            targetPos = CGPoint(x: frame.origin.x + frame.width / 2, y: menuBarHeight)
            targetSize = CGSize(width: frame.width / 2, height: frame.height)
        case "top_half":
            targetPos = CGPoint(x: frame.origin.x, y: menuBarHeight)
            targetSize = CGSize(width: frame.width, height: frame.height / 2)
        case "bottom_half":
            targetPos = CGPoint(x: frame.origin.x, y: menuBarHeight + frame.height / 2)
            targetSize = CGSize(width: frame.width, height: frame.height / 2)
        case "maximize":
            targetPos = CGPoint(x: frame.origin.x, y: menuBarHeight)
            targetSize = CGSize(width: frame.width, height: frame.height)
        case "center":
            let w = frame.width * 0.6
            let h = frame.height * 0.6
            targetPos = CGPoint(x: frame.origin.x + (frame.width - w) / 2, y: menuBarHeight + (frame.height - h) / 2)
            targetSize = CGSize(width: w, height: h)
        default:
            return .error("Unknown preset.")
        }

        // Set position — fail loudly if AX returns anything other than success
        // (most commonly happens when Accessibility permission isn't granted,
        // in which case we'd otherwise silently report "arranged" while the
        // window stayed put).
        var pos = targetPos
        guard let posValue = AXValueCreate(.cgPoint, &pos) else {
            return .error("Failed to create position value.")
        }
        let posResult = AXUIElementSetAttributeValue(axWindow, kAXPositionAttribute as CFString, posValue)
        guard posResult == .success else {
            return .error("Failed to position window (AX error \(posResult.rawValue)). Check Accessibility permission in System Settings → Privacy & Security → Accessibility.")
        }

        // Set size
        var size = targetSize
        guard let sizeValue = AXValueCreate(.cgSize, &size) else {
            return .error("Failed to create size value.")
        }
        let sizeResult = AXUIElementSetAttributeValue(axWindow, kAXSizeAttribute as CFString, sizeValue)
        guard sizeResult == .success else {
            return .error("Failed to size window (AX error \(sizeResult.rawValue)). Check Accessibility permission in System Settings → Privacy & Security → Accessibility.")
        }

        return .success("Arranged '\(app)' window to \(preset) (\(Int(targetSize.width))x\(Int(targetSize.height)) at \(Int(targetPos.x)),\(Int(targetPos.y))).")
    }

    func confirmationDescription(parameters: [String: Any]) -> String {
        let app = parameters["app"] as? String ?? "window"
        let preset = parameters["preset"] as? String ?? "unknown"
        return "Arrange \(app): \(preset)"
    }
}
