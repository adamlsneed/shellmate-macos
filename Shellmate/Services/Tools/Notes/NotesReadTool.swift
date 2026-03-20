import Foundation

/// Reads the body of a specific note from Apple Notes.
struct NotesReadTool: AgentTool {
    let identifier = "notes_read"
    let toolDescription = "Read the full body content of a note from Apple Notes by its name."
    let category = ToolCategory.notes
    let actionTier = ActionTier.read
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "name": ToolProperty(
                type: "string",
                description: "The exact name/title of the note to read."
            ),
        ],
        required: ["name"]
    )

    private let appleScriptService: AppleScriptService
    init(appleScriptService: AppleScriptService) { self.appleScriptService = appleScriptService }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let name = parameters["name"] as? String else {
            return .error("Missing required parameter: name")
        }

        let safeName = AppleScriptService.sanitize(name)
        let script = """
        tell application "Notes"
            set matchedNote to first note whose name is "\(safeName)"
            return plaintext of matchedNote
        end tell
        """

        do {
            let result = try await appleScriptService.execute(script: script, timeout: 30)
            return .success(result)
        } catch {
            return .error("Failed to read note '\(name)': \(error.localizedDescription)")
        }
    }
}
