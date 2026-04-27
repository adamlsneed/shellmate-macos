import AppKit
import Foundation

// MARK: - ClipboardReadTool

/// Reads the current system clipboard contents.
struct ClipboardReadTool: AgentTool {
    let identifier = "clipboard_read"
    let toolDescription = "Read the current contents of the system clipboard. Returns text content, file URLs, or reports the content type if non-text."
    let category = ToolCategory.clipboard
    let actionTier = ActionTier.read
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [:],
        required: []
    )

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        return await MainActor.run {
            readPasteboard()
        }
    }

    @MainActor
    private func readPasteboard() -> AgentToolResult {
        let pasteboard = NSPasteboard.general

        // Try plain text first
        if let text = pasteboard.string(forType: .string), !text.isEmpty {
            return .success(text)
        }

        // Try file URLs
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL], !urls.isEmpty {
            let paths = urls.map(\.path).joined(separator: "\n")
            return .success("File URLs on clipboard:\n\(paths)")
        }

        // Check if there's anything at all
        guard let types = pasteboard.types, !types.isEmpty else {
            return .success("Clipboard is empty.")
        }

        // Non-text content
        let typeNames = types.map(\.rawValue).joined(separator: ", ")
        return .success("Clipboard contains non-text content. Types: \(typeNames)")
    }
}
