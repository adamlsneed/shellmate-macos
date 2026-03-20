import Foundation

/// Creates a new note in Apple Notes.
struct NotesCreateTool: AgentTool {
    let identifier = "notes_create"
    let toolDescription = "Create a new note in Apple Notes with a title and body text."
    let category = ToolCategory.notes
    let actionTier = ActionTier.write
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "title": ToolProperty(
                type: "string",
                description: "The title of the note."
            ),
            "body": ToolProperty(
                type: "string",
                description: "The body content of the note."
            ),
            "folder": ToolProperty(
                type: "string",
                description: "The folder to create the note in. Defaults to the default folder if not specified."
            ),
        ],
        required: ["title", "body"]
    )

    private let appleScriptService: AppleScriptService
    init(appleScriptService: AppleScriptService) { self.appleScriptService = appleScriptService }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let title = parameters["title"] as? String else {
            return .error("Missing required parameter: title")
        }
        guard let body = parameters["body"] as? String else {
            return .error("Missing required parameter: body")
        }

        let safeTitle = AppleScriptService.sanitize(title)
        let safeBody = AppleScriptService.sanitize(body)

        let script: String
        if let folder = parameters["folder"] as? String {
            let safeFolder = AppleScriptService.sanitize(folder)
            script = """
            tell application "Notes"
                set targetFolder to folder "\(safeFolder)"
                make new note at targetFolder with properties {name:"\(safeTitle)", body:"\(safeBody)"}
                return "Note created in folder: \(safeFolder)"
            end tell
            """
        } else {
            script = """
            tell application "Notes"
                make new note with properties {name:"\(safeTitle)", body:"\(safeBody)"}
                return "Note created"
            end tell
            """
        }

        do {
            let result = try await appleScriptService.execute(script: script)
            return .success(result)
        } catch {
            return .error("Failed to create note: \(error.localizedDescription)")
        }
    }

    func confirmationDescription(parameters: [String: Any]) -> String {
        let title = parameters["title"] as? String ?? "Untitled"
        return "Create note: \(title)"
    }
}
