import Foundation

// MARK: - AudioNowPlayingTool

/// Reports the currently playing track from Music.app or Spotify.
struct AudioNowPlayingTool: AgentTool {
    let identifier = "audio_now_playing"
    let toolDescription = "Get information about the currently playing track from Music or Spotify."
    let category = ToolCategory.audio
    let actionTier = ActionTier.read
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [:],
        required: []
    )

    private let shellService: ShellService
    init(shellService: ShellService) { self.shellService = shellService }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        // Try Music.app first
        let musicResult = try await shellService.runCommand(
            """
            osascript -e '
            if application "Music" is running then
                tell application "Music"
                    if player state is playing then
                        set trackName to name of current track
                        set trackArtist to artist of current track
                        set trackAlbum to album of current track
                        return "Music.app: " & trackName & " by " & trackArtist & " (" & trackAlbum & ")"
                    else
                        return "Music.app is open but not playing."
                    end if
                end tell
            else
                return ""
            end if
            '
            """,
            timeout: 10
        )

        if musicResult.succeeded {
            let output = musicResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            if !output.isEmpty {
                return .success(output)
            }
        }

        // Try Spotify
        let spotifyResult = try await shellService.runCommand(
            """
            osascript -e '
            if application "Spotify" is running then
                tell application "Spotify"
                    if player state is playing then
                        set trackName to name of current track
                        set trackArtist to artist of current track
                        set trackAlbum to album of current track
                        return "Spotify: " & trackName & " by " & trackArtist & " (" & trackAlbum & ")"
                    else
                        return "Spotify is open but not playing."
                    end if
                end tell
            else
                return ""
            end if
            '
            """,
            timeout: 10
        )

        if spotifyResult.succeeded {
            let output = spotifyResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            if !output.isEmpty {
                return .success(output)
            }
        }

        return .success("Nothing is currently playing.")
    }
}
