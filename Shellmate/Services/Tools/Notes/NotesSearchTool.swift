import Foundation

/// Searches for notes by name in Apple Notes.
struct NotesSearchTool: AgentTool {
    let identifier = "notes_search"
    let toolDescription = "Search for notes by name/title in Apple Notes."
    let category = ToolCategory.notes
    let actionTier = ActionTier.read
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "query": ToolProperty(
                type: "string",
                description: "The search query to match against note names."
            ),
        ],
        required: ["query"]
    )

    private let appleScriptService: AppleScriptService
    init(appleScriptService: AppleScriptService) { self.appleScriptService = appleScriptService }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let query = parameters["query"] as? String else {
            return .error("Missing required parameter: query")
        }

        let safeQuery = AppleScriptService.sanitize(query.lowercased())
        let script = """
        tell application "Notes"
            set matchingNotes to {}
            repeat with n in notes
                if (name of n) contains "\(safeQuery)" then
                    set end of matchingNotes to {name of n, id of n, modification date of n as string}
                end if
                if (count of matchingNotes) >= 20 then exit repeat
            end repeat
            set output to ""
            repeat with m in matchingNotes
                set output to output & item 1 of m & " | " & item 2 of m & " | " & item 3 of m & linefeed
            end repeat
            return output
        end tell
        """

        do {
            let result = try await appleScriptService.execute(script: script, timeout: 60)
            if result.isEmpty {
                return .success("No notes found matching: \(query)")
            }
            return .success(result)
        } catch {
            return .error("Failed to search notes: \(error.localizedDescription)")
        }
    }
}
