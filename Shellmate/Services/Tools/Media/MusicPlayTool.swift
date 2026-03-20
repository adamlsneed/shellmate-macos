import Foundation

/// Plays a track or playlist in Music.app.
struct MusicPlayTool: AgentTool {
    let identifier = "music_play"
    let toolDescription = "Play a song by name in Music.app, or resume playback."
    let category = ToolCategory.media
    let actionTier = ActionTier.write
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "track": ToolProperty(
                type: "string",
                description: "Name of the track to play. If omitted, resumes current playback."
            ),
        ],
        required: []
    )

    private let appleScriptService: AppleScriptService
    init(appleScriptService: AppleScriptService) { self.appleScriptService = appleScriptService }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        let script: String

        if let track = parameters["track"] as? String {
            let safeTrack = AppleScriptService.sanitize(track)
            script = """
            tell application "Music"
                set results to (every track whose name contains "\(safeTrack)")
                if (count of results) > 0 then
                    play item 1 of results
                    set t to item 1 of results
                    return "Now playing: " & name of t & " — " & artist of t
                else
                    return "No track found matching: \(safeTrack)"
                end if
            end tell
            """
        } else {
            script = """
            tell application "Music"
                play
                return "Playback resumed."
            end tell
            """
        }

        do {
            let result = try await appleScriptService.execute(script: script, timeout: 15)
            return .success(result)
        } catch {
            return .error("Failed to play music: \(error.localizedDescription)")
        }
    }

    func confirmationDescription(parameters: [String: Any]) -> String {
        if let track = parameters["track"] as? String {
            return "Play: \(track)"
        }
        return "Resume music playback"
    }
}
