import Foundation
import Testing
@testable import Shellmate

// MARK: - Mock UI Handler

private struct MockConfirmationUIHandler: ConfirmationUIHandling {
    let alwaysApprove: Bool

    func requestConfirmation(toolIdentifier: String, description: String, tier: ActionTier) async -> Bool {
        alwaysApprove
    }
}

// MARK: - Stub Tools

private struct ReadTierStub: AgentTool {
    let identifier = "read_stub"
    let toolDescription = ""
    let category = ToolCategory.files
    let actionTier = ActionTier.read
    let parameterSchema = ToolInputSchema(type: "object", properties: [:], required: [])
    func execute(parameters: [String: Any]) async throws -> AgentToolResult { .success("ok") }
}

private struct WriteTierStub: AgentTool {
    let identifier = "write_stub"
    let toolDescription = ""
    let category = ToolCategory.files
    let actionTier = ActionTier.write
    let parameterSchema = ToolInputSchema(type: "object", properties: [:], required: [])
    func execute(parameters: [String: Any]) async throws -> AgentToolResult { .success("ok") }
    func confirmationDescription(parameters: [String: Any]) -> String { "Write something" }
}

private struct DestructiveTierStub: AgentTool {
    let identifier = "destructive_stub"
    let toolDescription = ""
    let category = ToolCategory.files
    let actionTier = ActionTier.destructive
    let parameterSchema = ToolInputSchema(type: "object", properties: [:], required: [])
    func execute(parameters: [String: Any]) async throws -> AgentToolResult { .success("ok") }
    func confirmationDescription(parameters: [String: Any]) -> String { "Delete everything" }
}

// MARK: - Tests

@Suite("ConfirmationService")
struct ConfirmationServiceTests {

    @Test("Read tier auto-approves even when UI handler denies")
    func readTierAutoApproves() async {
        let service = ConfirmationService(uiHandler: MockConfirmationUIHandler(alwaysApprove: false))
        let result = await service.confirm(tool: ReadTierStub(), parameters: [:])
        #expect(result == true)
    }

    @Test("Write tier calls UI handler — approved")
    func writeTierApproved() async {
        let service = ConfirmationService(uiHandler: MockConfirmationUIHandler(alwaysApprove: true))
        let result = await service.confirm(tool: WriteTierStub(), parameters: [:])
        #expect(result == true)
    }

    @Test("Write tier calls UI handler — denied")
    func writeTierDenied() async {
        let service = ConfirmationService(uiHandler: MockConfirmationUIHandler(alwaysApprove: false))
        let result = await service.confirm(tool: WriteTierStub(), parameters: [:])
        #expect(result == false)
    }

    @Test("Auto-approve skips UI for write tier")
    func autoApproveSkipsUIForWrite() async {
        let service = ConfirmationService(uiHandler: MockConfirmationUIHandler(alwaysApprove: false))
        await service.setAutoApprove(for: .files, enabled: true)
        let result = await service.confirm(tool: WriteTierStub(), parameters: [:])
        #expect(result == true)
    }

    @Test("Destructive tier NEVER auto-approves")
    func destructiveNeverAutoApproves() async {
        let service = ConfirmationService(uiHandler: MockConfirmationUIHandler(alwaysApprove: false))
        await service.setAutoApprove(for: .files, enabled: true)
        let result = await service.confirm(tool: DestructiveTierStub(), parameters: [:])
        #expect(result == false)
    }

    @Test("isAutoApproved reflects setAutoApprove")
    func isAutoApprovedReflectsSet() async {
        let service = ConfirmationService(uiHandler: MockConfirmationUIHandler(alwaysApprove: true))
        let before = await service.isAutoApproved(.shell)
        #expect(before == false)
        await service.setAutoApprove(for: .shell, enabled: true)
        let after = await service.isAutoApproved(.shell)
        #expect(after == true)
        await service.setAutoApprove(for: .shell, enabled: false)
        let removed = await service.isAutoApproved(.shell)
        #expect(removed == false)
    }
}
