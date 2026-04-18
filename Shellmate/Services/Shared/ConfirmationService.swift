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
    ///
    /// The tool's async `confirmationDescription` is preferred over the sync one
    /// — this lets search-then-act tools (calendar/reminders delete) resolve the
    /// actual target before prompting, so the user sees what will be touched.
    func confirm(tool: AgentTool, parameters: [String: Any]) async -> Bool {
        switch tool.actionTier {
        case .read:
            return true
        case .write:
            if autoApproveCategories.contains(tool.category) {
                return true
            }
            let desc = await resolveDescription(tool: tool, parameters: parameters)
            return await uiHandler.requestConfirmation(
                toolIdentifier: tool.identifier,
                description: desc,
                tier: tool.actionTier
            )
        case .destructive:
            let desc = await resolveDescription(tool: tool, parameters: parameters)
            return await uiHandler.requestConfirmation(
                toolIdentifier: tool.identifier,
                description: desc,
                tier: tool.actionTier
            )
        }
    }

    private func resolveDescription(tool: AgentTool, parameters: [String: Any]) async -> String {
        // [String: Any] is not Sendable; copy into a nonisolated(unsafe) local
        // before crossing the actor boundary. Safe because we only read from it.
        nonisolated(unsafe) let paramsCopy = parameters
        if let async = await tool.confirmationDescription(parameters: paramsCopy) {
            return async
        }
        return tool.confirmationDescription(parameters: parameters)
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

// MARK: - ContinuationBox

/// Thread-safe holder shared between `withCheckedContinuation` and a
/// `withTaskCancellationHandler` onCancel closure. Lets the cancel path
/// resume the stored continuation without racing on assignment.
private final class ContinuationBox: @unchecked Sendable {
    private var inner: OneShotContinuation?
    private let lock = NSLock()
    func set(_ v: OneShotContinuation) { lock.lock(); inner = v; lock.unlock() }
    func get() -> OneShotContinuation? { lock.lock(); defer { lock.unlock() }; return inner }
}

// MARK: - ConfirmationUIHandler

/// Real UI handler that posts a `ConfirmationRequest` to `ChatState` and waits for the
/// user's response via a checked continuation. Honors task cancellation by resuming
/// any pending continuation with `false` (deny), preventing the executor from hanging
/// when the user clicks "stop" mid-confirmation.
@MainActor
final class ConfirmationUIHandler: ConfirmationUIHandling {
    weak var chatState: ChatState?

    nonisolated func requestConfirmation(
        toolIdentifier: String,
        description: String,
        tier: ActionTier
    ) async -> Bool {
        let box = ContinuationBox()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
                let oneShot = OneShotContinuation(continuation)
                box.set(oneShot)
                let request = ConfirmationRequest(
                    id: UUID(),
                    toolIdentifier: toolIdentifier,
                    description: description,
                    tier: tier,
                    continuation: oneShot
                )
                Task { @MainActor in
                    // If a prior confirmation is still pending (shouldn't happen now that
                    // sendMessage gates on this, but defensive), deny it before showing the new one.
                    self.chatState?.cancelPendingConfirmation()
                    self.chatState?.pendingConfirmation = request
                }
            }
        } onCancel: {
            box.get()?.resume(returning: false)
        }
    }
}
