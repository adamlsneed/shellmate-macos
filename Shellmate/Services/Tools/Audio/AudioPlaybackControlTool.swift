import Foundation

// MARK: - AudioPlaybackControlTool

/// Controls media playback (play, pause, next, previous) via Music.app or Spotify.
struct AudioPlaybackControlTool: AgentTool {
    let identifier = "audio_playback_control"
    let toolDescription = "Control media playback: play, pause, skip to next track, or go to previous track. Works with Music and Spotify."
    let category = ToolCategory.audio
    let actionTier = ActionTier.write
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "action": ToolProperty(
                type: "string",
                description: "The playback action: 'play', 'pause', 'next', or 'previous'.",
                enumValues: ["play", "pause", "next", "previous"]
            ),
        ],
        required: ["action"]
    )

    private let shellService: ShellService
    init(shellService: ShellService) { self.shellService = shellService }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let action = parameters["action"] as? String else {
            return .error("Missing required parameter: action")
        }

        let validActions = ["play", "pause", "next", "previous"]
        guard validActions.contains(action) else {
            return .error("Invalid action '\(action)'. Use 'play', 'pause', 'next', or 'previous'.")
        }

        // Map action to AppleScript commands
        // Music.app uses "playpause" for both play and pause
        let musicCommand: String
        let spotifyCommand: String

        switch action {
        case "play", "pause":
            musicCommand = "playpause"
            spotifyCommand = "playpause"
        case "next":
            musicCommand = "next track"
            spotifyCommand = "next track"
        case "previous":
            musicCommand = "previous track"
            spotifyCommand = "previous track"
        default:
            return .error("Invalid action '\(action)'.")
        }

        // Try Music.app first
        let musicResult = try await shellService.runCommand(
            """
            osascript -e '
            if application "Music" is running then
                tell application "Music" to \(musicCommand)
                return "Music.app: \(action) executed."
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
                tell application "Spotify" to \(spotifyCommand)
                return "Spotify: \(action) executed."
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

        return .success("No music player is currently running. Open Music or Spotify first.")
    }

    func confirmationDescription(parameters: [String: Any]) -> String {
        guard let action = parameters["action"] as? String else { return "" }
        switch action {
        case "play": return "Resume playback"
        case "pause": return "Pause playback"
        case "next": return "Skip to next track"
        case "previous": return "Go to previous track"
        default: return "Control playback"
        }
    }
}
