import Foundation

/// Provides window management tools via the Accessibility API.
struct WindowProvider: ToolProvider {
    let category = ToolCategory.windows
    let displayName = "Window Management"
    let requiredPermissions: [SystemPermission] = [.accessibility]

    var tools: [AgentTool] {
        [
            WindowListTool(),
            WindowMoveTool(),
            WindowResizeTool(),
            WindowArrangeTool(),
            WindowFocusTool(),
        ]
    }
}
