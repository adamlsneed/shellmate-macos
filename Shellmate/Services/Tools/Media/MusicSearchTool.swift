import Foundation

/// Searches for tracks in Music.app library.
struct MusicSearchTool: AgentTool {
    let identifier = "music_search"
    let toolDescription = "Search for songs in the Music.app library by name, artist, or album."
    let category = ToolCategory.media
    let actionTier = ActionTier.read
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "query": ToolProperty(
                type: "string",
                description: "Search query to find tracks (searches name, artist, and album)."
            ),
            "limit": ToolProperty(
                type: "integer",
                description: "Maximum results to return. Defaults to 10."
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

        let limit: Int
        if let l = parameters["limit"] as? Int { limit = min(max(l, 1), 50) }
        else if let l = parameters["limit"] as? Double { limit = min(max(Int(l), 1), 50) }
        else { limit = 10 }

        let safeQuery = AppleScriptService.sanitize(query)

        let script = """
        tell application "Music"
            set results to (every track whose name contains "\(safeQuery)" or artist contains "\(safeQuery)" or album contains "\(safeQuery)")
            set output to ""
            set maxResults to \(limit)
            if (count of results) < maxResults then set maxResults to count of results
            repeat with i from 1 to maxResults
                set t to item i of results
                set output to output & name of t & " — " & artist of t & " (" & album of t & ", " & (duration of t div 60) & ":" & text -2 thru -1 of ("0" & (duration of t mod 60) as string) & ")" & linefeed
            end repeat
            if output is "" then return "No tracks found matching: \(safeQuery)"
            return output
        end tell
        """

        do {
            let result = try await appleScriptService.execute(script: script, timeout: 30)
            return .success(result)
        } catch {
            return .error("Failed to search Music library: \(error.localizedDescription)")
        }
    }
}
