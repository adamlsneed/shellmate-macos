import AppKit
import Foundation

// MARK: - ClipboardClearTool

/// Clears the system clipboard.
struct ClipboardClearTool: AgentTool {
    let identifier = "clipboard_clear"
    let toolDescription = "Clear all contents from the system clipboard."
    let category = ToolCategory.clipboard
    let actionTier = ActionTier.write
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [:],
        required: []
    )

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        return await MainActor.run {
            clearPasteboard()
        }
    }

    @MainActor
    private func clearPasteboard() -> AgentToolResult {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return .success("Clipboard cleared.")
    }

    func confirmationDescription(parameters: [String: Any]) -> String {
        "Clear all clipboard contents"
    }
}
