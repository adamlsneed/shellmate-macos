import Foundation
import Testing
@testable import Shellmate

// MARK: - Stub Tool for permission check

private struct PermStub: AgentTool {
    let identifier = "perm_stub"
    let toolDescription = ""
    let category: ToolCategory
    let actionTier = ActionTier.read
    let parameterSchema = ToolInputSchema(type: "object", properties: [:], required: [])
    func execute(parameters: [String: Any]) async throws -> AgentToolResult { .success("ok") }

    init(category: ToolCategory = .system) {
        self.category = category
    }
}

// MARK: - Tests

@Suite("PermissionManager")
struct PermissionManagerTests {

    @Test("Initial status is .notRequested")
    func initialStatusNotRequested() async {
        let manager = PermissionManager()
        let status = await manager.status(for: .calendars)
        #expect(status == .notRequested)
    }

    @Test("updateStatus is reflected by status(for:)")
    func updateStatusReflected() async {
        let manager = PermissionManager()
        await manager.updateStatus(.microphone, to: .granted)
        let status = await manager.status(for: .microphone)
        #expect(status == .granted)
    }

    @Test("allStatuses covers all permissions")
    func allStatusesCoverage() async {
        let manager = PermissionManager()
        await manager.updateStatus(.contacts, to: .denied)
        let all = await manager.allStatuses()
        #expect(all.count == SystemPermission.allCases.count)
        #expect(all[.contacts] == .denied)
        #expect(all[.calendars] == .notRequested)
    }

    @Test("checkPermissions returns nil for non-permission categories")
    func checkPermissionsNonPermCategory() async {
        let manager = PermissionManager()
        let result = await manager.checkPermissions(for: PermStub(category: .system))
        #expect(result == nil)
    }

    @Test("checkPermissions returns nil for shell category")
    func checkPermissionsShellCategory() async {
        let manager = PermissionManager()
        let result = await manager.checkPermissions(for: PermStub(category: .shell))
        #expect(result == nil)
    }

    @Test("updateStatus overwrites previous value")
    func updateStatusOverwrites() async {
        let manager = PermissionManager()
        await manager.updateStatus(.accessibility, to: .granted)
        await manager.updateStatus(.accessibility, to: .restricted)
        let status = await manager.status(for: .accessibility)
        #expect(status == .restricted)
    }

    @Test("queryRealStatus returns a valid status for calendars")
    func queryRealStatusCalendars() async {
        let manager = PermissionManager()
        let status = await manager.queryRealStatus(for: .calendars)
        // In CI/test environments this will be either .notRequested or .denied
        #expect([.notRequested, .granted, .denied, .restricted].contains(status))
    }

    @Test("queryRealStatus returns a valid status for reminders")
    func queryRealStatusReminders() async {
        let manager = PermissionManager()
        let status = await manager.queryRealStatus(for: .reminders)
        #expect([.notRequested, .granted, .denied, .restricted].contains(status))
    }

    @Test("queryRealStatus returns a valid status for contacts")
    func queryRealStatusContacts() async {
        let manager = PermissionManager()
        let status = await manager.queryRealStatus(for: .contacts)
        #expect([.notRequested, .granted, .denied, .restricted].contains(status))
    }

    @Test("queryRealStatus falls back to cache for non-OS permissions")
    func queryRealStatusFallback() async {
        let manager = PermissionManager()
        await manager.updateStatus(.microphone, to: .granted)
        let status = await manager.queryRealStatus(for: .microphone)
        #expect(status == .granted)
    }
}
