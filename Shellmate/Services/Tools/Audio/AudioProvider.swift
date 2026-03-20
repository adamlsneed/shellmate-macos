import Foundation

/// Provides audio and volume tools to the agent tool registry.
struct AudioProvider: ToolProvider {
    let category = ToolCategory.audio
    let displayName = "Audio & Volume"

    private let shellService: ShellService
    init(shellService: ShellService) { self.shellService = shellService }

    var tools: [AgentTool] {
        [
            AudioVolumeTool(shellService: shellService),
            AudioInputOutputTool(shellService: shellService),
            AudioNowPlayingTool(shellService: shellService),
            AudioPlaybackControlTool(shellService: shellService),
        ]
    }
}
