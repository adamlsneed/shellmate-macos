import AppKit
@preconcurrency import Contacts
@preconcurrency import EventKit
import Foundation

// MARK: - PermissionManager

/// Tracks macOS system-permission statuses for tools that need them.
/// Queries real OS authorization for calendars, reminders, and contacts.
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

    // MARK: - Real OS Queries

    /// Checks actual OS authorization for calendars, reminders, contacts.
    /// For other permissions, returns the cached value.
    func queryRealStatus(for permission: SystemPermission) -> PermissionStatus {
        let status: PermissionStatus
        switch permission {
        case .calendars:
            status = mapEventKitStatus(EKEventStore.authorizationStatus(for: .event))
        case .reminders:
            status = mapEventKitStatus(EKEventStore.authorizationStatus(for: .reminder))
        case .contacts:
            status = mapContactsStatus(CNContactStore.authorizationStatus(for: .contacts))
        default:
            return cache[permission, default: .notRequested]
        }
        cache[permission] = status
        return status
    }

    /// Requests permission from the OS and returns the resulting status.
    func requestPermission(_ permission: SystemPermission) async -> PermissionStatus {
        let status: PermissionStatus
        switch permission {
        case .calendars:
            let store = EKEventStore()
            do {
                try await store.requestFullAccessToEvents()
                status = .granted
            } catch {
                status = .denied
            }
        case .reminders:
            let store = EKEventStore()
            do {
                try await store.requestFullAccessToReminders()
                status = .granted
            } catch {
                status = .denied
            }
        case .contacts:
            let store = CNContactStore()
            do {
                try await store.requestAccess(for: .contacts)
                status = .granted
            } catch {
                status = .denied
            }
        default:
            return cache[permission, default: .notRequested]
        }
        cache[permission] = status
        return status
    }

    // MARK: - Tool Permission Check

    /// Checks if a tool's category requires a permission and whether that permission is denied.
    /// Returns `nil` when the tool can proceed, or a denial message string.
    func checkPermissions(for tool: AgentTool) -> String? {
        guard let permission = systemPermission(for: tool.category) else {
            return nil
        }
        let realStatus = queryRealStatus(for: permission)
        switch realStatus {
        case .notRequested:
            // Permission will be requested when the service tries to access data
            return nil
        case .granted:
            return nil
        case .denied, .restricted:
            return permission.deniedMessage
        }
    }

    /// Opens System Settings to the relevant privacy pane for a permission.
    @MainActor
    func openSettings(for permission: SystemPermission) {
        guard let url = URL(string: permission.settingsPaneURL) else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: - Private Helpers

    private func systemPermission(for category: ToolCategory) -> SystemPermission? {
        switch category {
        case .calendar:  .calendars
        case .reminders: .reminders
        case .contacts:  .contacts
        default:         nil
        }
    }

    private func mapEventKitStatus(_ ekStatus: EKAuthorizationStatus) -> PermissionStatus {
        switch ekStatus {
        case .notDetermined:             .notRequested
        case .fullAccess, .authorized:   .granted
        case .denied:                    .denied
        case .restricted:                .restricted
        case .writeOnly:                 .restricted
        @unknown default:                .denied
        }
    }

    private func mapContactsStatus(_ cnStatus: CNAuthorizationStatus) -> PermissionStatus {
        switch cnStatus {
        case .notDetermined:    .notRequested
        case .authorized:       .granted
        case .denied:           .denied
        case .restricted:       .restricted
        case .limited:          .restricted
        @unknown default:       .denied
        }
    }
}
