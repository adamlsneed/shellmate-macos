import Foundation

// MARK: - OneShotContinuation

/// Thread-safe wrapper around a `CheckedContinuation` that guarantees at-most-once resumption.
/// Prevents crashes from double-tapping confirmation buttons.
final class OneShotContinuation: @unchecked Sendable {
    private var continuation: CheckedContinuation<Bool, Never>?
    private let lock = NSLock()

    init(_ continuation: CheckedContinuation<Bool, Never>) {
        self.continuation = continuation
    }

    func resume(returning value: Bool) {
        lock.lock()
        let cont = continuation
        continuation = nil
        lock.unlock()
        cont?.resume(returning: value)
    }
}

// MARK: - ConfirmationUIHandling

/// Protocol for UI handler (allows mocking in tests).
protocol ConfirmationUIHandling: Sendable {
    func requestConfirmation(toolIdentifier: String, description: String, tier: ActionTier) async -> Bool
}

// MARK: - ConfirmationService

/// Manages tool-execution confirmations based on action tier and auto-approve settings.
actor ConfirmationService {
    private var autoApproveCategories: Set<ToolCategory> = []
    private let uiHandler: ConfirmationUIHandling

    init(uiHandler: ConfirmationUIHandling) {
        self.uiHandler = uiHandler
    }

    /// Decide whether a tool invocation should proceed.
    ///
    /// - Read tier: always approved automatically.
    /// - Write tier with auto-approve for the tool's category: approved automatically.
    /// - Destructive tier: **never** auto-approved, always delegates to the UI handler.
    /// - Otherwise: delegates to the UI handler.
    func confirm(tool: AgentTool, parameters: [String: Any]) async -> Bool {
        switch tool.actionTier {
        case .read:
            return true
        case .write:
            if autoApproveCategories.contains(tool.category) {
                return true
            }
            let desc = tool.confirmationDescription(parameters: parameters)
            return await uiHandler.requestConfirmation(
                toolIdentifier: tool.identifier,
                description: desc,
                tier: tool.actionTier
            )
        case .destructive:
            let desc = tool.confirmationDescription(parameters: parameters)
            return await uiHandler.requestConfirmation(
                toolIdentifier: tool.identifier,
                description: desc,
                tier: tool.actionTier
            )
        }
    }

    func setAutoApprove(for category: ToolCategory, enabled: Bool) {
        if enabled {
            autoApproveCategories.insert(category)
        } else {
            autoApproveCategories.remove(category)
        }
    }

    func isAutoApproved(_ category: ToolCategory) -> Bool {
        autoApproveCategories.contains(category)
    }
}

// MARK: - ConfirmationUIHandler

/// Real UI handler that posts a `ConfirmationRequest` to `ChatState` and waits for the
/// user's response via a checked continuation.
@MainActor
final class ConfirmationUIHandler: ConfirmationUIHandling {
    weak var chatState: ChatState?

    nonisolated func requestConfirmation(
        toolIdentifier: String,
        description: String,
        tier: ActionTier
    ) async -> Bool {
        await withCheckedContinuation { continuation in
            let request = ConfirmationRequest(
                id: UUID(),
                toolIdentifier: toolIdentifier,
                description: description,
                tier: tier,
                continuation: OneShotContinuation(continuation)
            )
            Task { @MainActor in
                self.chatState?.pendingConfirmation = request
            }
        }
    }
}
