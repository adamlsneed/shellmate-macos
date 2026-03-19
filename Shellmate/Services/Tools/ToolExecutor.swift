import Foundation
import os

/// Result of a tool execution.
struct ToolExecutionResult: Sendable {
    let content: String
    let isError: Bool
}

/// Actor that routes tool calls to their implementations via the ToolRegistry.
/// Actor isolation prevents concurrent shell command conflicts.
actor ToolExecutor {
    private static let logger = Logger(subsystem: "com.shellmate.app", category: "tools")
    let registry: ToolRegistry
    private let confirmationService: ConfirmationService
    private let permissionManager: PermissionManager

    init(registry: ToolRegistry, confirmationService: ConfirmationService, permissionManager: PermissionManager) {
        self.registry = registry
        self.confirmationService = confirmationService
        self.permissionManager = permissionManager
    }

    /// Execute a tool by name with the given input as JSONValue dict.
    func execute(tool name: String, input: [String: JSONValue]) async -> ToolExecutionResult {
        Self.logger.info("Executing tool: \(name)")
        let anyInput = input.mapValues(\.anyValue)

        guard let tool = await registry.tool(named: name) else {
            return ToolExecutionResult(content: "Unknown tool: \(name)", isError: true)
        }

        // Permission check (no-op in Phase 1)
        if let denied = await permissionManager.checkPermissions(for: tool) {
            return ToolExecutionResult(content: denied, isError: true)
        }

        // Confirmation check
        if tool.actionTier != .read {
            nonisolated(unsafe) let params = anyInput
            let approved = await confirmationService.confirm(tool: tool, parameters: params)
            if !approved {
                return ToolExecutionResult(content: "Action cancelled by user.", isError: true)
            }
        }

        do {
            nonisolated(unsafe) let params = anyInput
            let result = try await tool.execute(parameters: params)
            return ToolExecutionResult(content: result.content, isError: result.isError)
        } catch {
            return ToolExecutionResult(content: error.localizedDescription, isError: true)
        }
    }
}
