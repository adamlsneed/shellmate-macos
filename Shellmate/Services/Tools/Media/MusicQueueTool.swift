import Foundation

/// Shows the current Music.app queue/now playing info.
struct MusicQueueTool: AgentTool {
    let identifier = "music_queue"
    let toolDescription = "Get the currently playing track and upcoming queue from Music.app."
    let category = ToolCategory.media
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
        tell application "Music"
            if player state is playing or player state is paused then
                set t to current track
                set state to player state as string
                set output to "State: " & state & linefeed
                set output to output & "Track: " & name of t & linefeed
                set output to output & "Artist: " & artist of t & linefeed
                set output to output & "Album: " & album of t & linefeed
                set pos to player position
                set dur to duration of t
                set output to output & "Position: " & (pos div 60) & ":" & text -2 thru -1 of ("0" & (pos mod 60 as integer) as string) & " / " & (dur div 60) & ":" & text -2 thru -1 of ("0" & (dur mod 60 as integer) as string)
                return output
            else
                return "Music.app is not playing anything."
            end if
        end tell
        """

        do {
            let result = try await appleScriptService.execute(script: script, timeout: 15)
            return .success(result)
        } catch {
            return .error("Failed to get music queue: \(error.localizedDescription)")
        }
    }
}
