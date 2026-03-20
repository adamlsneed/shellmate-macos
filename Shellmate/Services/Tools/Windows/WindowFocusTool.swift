import Foundation
import AppKit
import ApplicationServices

/// Brings a window to the front and focuses its application.
struct WindowFocusTool: AgentTool {
    let identifier = "window_focus"
    let toolDescription = "Bring an application's window to the front and focus it."
    let category = ToolCategory.windows
    let actionTier = ActionTier.write
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "app": ToolProperty(
                type: "string",
                description: "Name of the application to focus."
            ),
        ],
        required: ["app"]
    )

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let app = parameters["app"] as? String else {
            return .error("Missing required parameter: app")
        }

        guard let runningApp = NSWorkspace.shared.runningApplications.first(where: {
            $0.localizedName?.localizedCaseInsensitiveContains(app) == true
        }) else {
            return .error("Application '\(app)' is not running.")
        }

        // Activate the app (brings it to front)
        let activated = runningApp.activate()

        // Also raise the focused window via Accessibility API
        let appElement = AXUIElementCreateApplication(runningApp.processIdentifier)
        var windowRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &windowRef) == .success,
           let window = windowRef {
            AXUIElementPerformAction(window as! AXUIElement, kAXRaiseAction as CFString)
        }

        if activated {
            return .success("Focused: \(runningApp.localizedName ?? app)")
        }

        return .error("Failed to focus '\(app)'. Check Accessibility permissions.")
    }

    func confirmationDescription(parameters: [String: Any]) -> String {
        let app = parameters["app"] as? String ?? "window"
        return "Focus: \(app)"
    }
}
