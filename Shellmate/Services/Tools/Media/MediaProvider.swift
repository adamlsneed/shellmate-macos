import Foundation

/// Provides music, screenshot, image, and PDF tools.
struct MediaProvider: ToolProvider {
    let category = ToolCategory.media
    let displayName = "Media"
    let requiredPermissions: [SystemPermission] = [.appleEvents, .screenCapture]

    private let shellService: ShellService
    private let appleScriptService: AppleScriptService

    init(shellService: ShellService, appleScriptService: AppleScriptService) {
        self.shellService = shellService
        self.appleScriptService = appleScriptService
    }

    var tools: [AgentTool] {
        [
            // Music
            MusicSearchTool(appleScriptService: appleScriptService),
            MusicPlayTool(appleScriptService: appleScriptService),
            MusicQueueTool(appleScriptService: appleScriptService),
            // Screenshot
            ScreenshotCaptureTool(shellService: shellService),
            // Image
            ImageResizeTool(shellService: shellService),
            ImageConvertTool(shellService: shellService),
            ImageOCRTool(),
            // PDF
            PDFReadTool(),
            PDFMergeTool(),
            PDFSplitTool(),
        ]
    }
}
