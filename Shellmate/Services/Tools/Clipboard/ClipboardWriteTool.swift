import AppKit
import Foundation

// MARK: - ClipboardWriteTool

/// Writes text content to the system clipboard.
struct ClipboardWriteTool: AgentTool {
    let identifier = "clipboard_write"
    let toolDescription = "Write text to the system clipboard, replacing any existing content."
    let category = ToolCategory.clipboard
    let actionTier = ActionTier.write
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "text": ToolProperty(
                type: "string",
                description: "The text to copy to the clipboard."
            ),
        ],
        required: ["text"]
    )

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let text = parameters["text"] as? String else {
            return .error("Missing required parameter: text")
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        return .success("Copied \(text.count) characters to clipboard.")
    }

    func confirmationDescription(parameters: [String: Any]) -> String {
        guard let text = parameters["text"] as? String else { return "Copy text to clipboard" }
        let preview = text.count > 80 ? String(text.prefix(80)) + "..." : text
        return "Copy to clipboard: \"\(preview)\""
    }
}
