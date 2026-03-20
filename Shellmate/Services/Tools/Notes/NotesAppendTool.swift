import Foundation

/// Appends text to an existing note in Apple Notes.
struct NotesAppendTool: AgentTool {
    let identifier = "notes_append"
    let toolDescription = "Append text to the body of an existing note in Apple Notes."
    let category = ToolCategory.notes
    let actionTier = ActionTier.write
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "name": ToolProperty(
                type: "string",
                description: "The exact name/title of the note to append to."
            ),
            "text": ToolProperty(
                type: "string",
                description: "The text to append to the note body."
            ),
        ],
        required: ["name", "text"]
    )

    private let appleScriptService: AppleScriptService
    init(appleScriptService: AppleScriptService) { self.appleScriptService = appleScriptService }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let name = parameters["name"] as? String else {
            return .error("Missing required parameter: name")
        }
        guard let text = parameters["text"] as? String else {
            return .error("Missing required parameter: text")
        }

        let safeName = AppleScriptService.sanitize(name)
        let safeText = AppleScriptService.sanitize(text)
        let script = """
        tell application "Notes"
            set matchedNote to first note whose name is "\(safeName)"
            set currentBody to body of matchedNote
            set body of matchedNote to currentBody & "<br>" & "\(safeText)"
            return "Text appended to note: \(safeName)"
        end tell
        """

        do {
            let result = try await appleScriptService.execute(script: script, timeout: 30)
            return .success(result)
        } catch {
            return .error("Failed to append to note '\(name)': \(error.localizedDescription)")
        }
    }

    func confirmationDescription(parameters: [String: Any]) -> String {
        let name = parameters["name"] as? String ?? "unknown"
        return "Append text to note: \(name)"
    }
}
