import Foundation

/// Provides text-to-speech tools.
struct TTSProvider: ToolProvider {
    let category = ToolCategory.tts
    let displayName = "Text to Speech"

    private let shellService: ShellService
    init(shellService: ShellService) { self.shellService = shellService }

    var tools: [AgentTool] {
        [
            TTSSpeakTool(shellService: shellService),
            TTSVoicesTool(shellService: shellService),
        ]
    }
}
