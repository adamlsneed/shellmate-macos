import Foundation

/// Lists all folders in Apple Notes with note counts.
struct NotesListFoldersTool: AgentTool {
    let identifier = "notes_list_folders"
    let toolDescription = "List all folders in Apple Notes with note counts."
    let category = ToolCategory.notes
    let actionTier = ActionTier.read
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [:],
        required: []
    )

    private let appleScriptService: AppleScriptService
    init(appleScriptService: AppleScriptService) { self.appleScriptService = appleScriptService }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        let script = """
        tell application "Notes"
            set output to ""
            repeat with f in folders
                set folderName to name of f
                set noteCount to count of notes of f
                set output to output & folderName & " (" & noteCount & " notes)" & linefeed
            end repeat
            return output
        end tell
        """

        do {
            let result = try await appleScriptService.execute(script: script, timeout: 30)
            if result.isEmpty {
                return .success("No folders found in Notes.")
            }
            return .success(result)
        } catch {
            return .error("Failed to list Notes folders: \(error.localizedDescription)")
        }
    }
}
