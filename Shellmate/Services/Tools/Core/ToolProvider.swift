import Foundation

// MARK: - ToolProvider

/// Groups related ``AgentTool``s under a capability category.
protocol ToolProvider: Sendable {
    /// The capability domain this provider covers.
    var category: ToolCategory { get }

    /// Human-readable name for settings UI.
    var displayName: String { get }

    /// The tools offered by this provider.
    var tools: [AgentTool] { get }

    /// macOS permissions required before any tools in this provider can run.
    var requiredPermissions: [SystemPermission] { get }

    /// Whether this provider is currently enabled by the user.
    var isEnabled: Bool { get }
}

extension ToolProvider {
    var requiredPermissions: [SystemPermission] { [] }
    var isEnabled: Bool { true }
}
