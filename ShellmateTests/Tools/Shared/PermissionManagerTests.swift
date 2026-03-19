import Foundation
import Testing
@testable import Shellmate

// MARK: - Stub Tool for permission check

private struct PermStub: AgentTool {
    let identifier = "perm_stub"
    let toolDescription = ""
    let category = ToolCategory.system
    let actionTier = ActionTier.read
    let parameterSchema = ToolInputSchema(type: "object", properties: [:], required: [])
    func execute(parameters: [String: Any]) async throws -> AgentToolResult { .success("ok") }
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

    @Test("checkPermissions returns nil in Phase 1")
    func checkPermissionsReturnsNil() async {
        let manager = PermissionManager()
        let result = await manager.checkPermissions(for: PermStub())
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
}
