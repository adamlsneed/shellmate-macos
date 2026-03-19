import AppKit
import Foundation

// MARK: - PermissionManager

/// Tracks macOS system-permission statuses for tools that need them.
/// Phase 1 stub: caches statuses locally but does not query the OS.
actor PermissionManager {

    enum PermissionStatus: String, Sendable, Equatable {
        case notRequested
        case granted
        case denied
        case restricted
    }

    private var cache: [SystemPermission: PermissionStatus] = [:]

    /// Returns the cached status for a permission, defaulting to `.notRequested`.
    func status(for permission: SystemPermission) -> PermissionStatus {
        cache[permission, default: .notRequested]
    }

    /// Manually update the cached status (will be driven by OS queries in a later phase).
    func updateStatus(_ permission: SystemPermission, to status: PermissionStatus) {
        cache[permission] = status
    }

    /// Snapshot of all permission statuses, filling in `.notRequested` for any not yet cached.
    func allStatuses() -> [SystemPermission: PermissionStatus] {
        var result: [SystemPermission: PermissionStatus] = [:]
        for perm in SystemPermission.allCases {
            result[perm] = cache[perm, default: .notRequested]
        }
        return result
    }

    /// Phase 1 stub: always returns `nil` (no blocking permission issues).
    func checkPermissions(for tool: AgentTool) -> String? {
        nil
    }

    /// Opens System Settings to the relevant privacy pane for a permission.
    @MainActor
    func openSettings(for permission: SystemPermission) {
        guard let url = URL(string: permission.settingsPaneURL) else { return }
        NSWorkspace.shared.open(url)
    }
}
