import CoreGraphics
import Foundation

/// Captures a screenshot using the macOS `screencapture` CLI.
struct ScreenshotCaptureTool: AgentTool {
    let identifier = "screenshot_capture"
    let toolDescription = "Capture a screenshot of the screen, a window, or a selection area."
    let category = ToolCategory.media
    let actionTier = ActionTier.write
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "area": ToolProperty(
                type: "string",
                description: "What to capture: 'full' (entire screen), 'window' (front window), or 'selection' (user selects area).",
                enumValues: ["full", "window", "selection"]
            ),
            "save_path": ToolProperty(
                type: "string",
                description: "File path to save the screenshot. Defaults to ~/Desktop/screenshot-<timestamp>.png."
            ),
            "format": ToolProperty(
                type: "string",
                description: "Image format: 'png' or 'jpg'.",
                enumValues: ["png", "jpg"]
            ),
            "delay": ToolProperty(
                type: "integer",
                description: "Delay in seconds before capturing. Defaults to 0."
            ),
        ],
        required: []
    )

    private let shellService: ShellService
    init(shellService: ShellService) { self.shellService = shellService }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        // Inline preflight: this is the only MediaProvider tool that needs
        // Screen Recording. Without this, screencapture's denial signal is a
        // 0-byte file and the user has no idea why "Screenshot saved to:"
        // produced nothing. Trigger the OS prompt on first use.
        if !CGPreflightScreenCaptureAccess() {
            _ = CGRequestScreenCaptureAccess()
            return .error(SystemPermission.screenCapture.deniedMessage)
        }

        let area = (parameters["area"] as? String) ?? "full"
        let format = (parameters["format"] as? String) ?? "png"
        let delay: Int
        if let d = parameters["delay"] as? Int { delay = max(d, 0) }
        else if let d = parameters["delay"] as? Double { delay = max(Int(d), 0) }
        else { delay = 0 }

        let savePath: String
        if let path = parameters["save_path"] as? String {
            savePath = path
        } else {
            let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
            savePath = "\(FileManager.default.homeDirectoryForCurrentUser.path)/Desktop/screenshot-\(timestamp).\(format)"
        }

        var args: [String] = []

        // Format
        args += ["-t", format]

        // Area type
        switch area {
        case "window":
            args.append("-w")
        case "selection":
            args.append("-s")
        default:
            break // full screen is default
        }

        // Delay
        if delay > 0 {
            args += ["-T", String(delay)]
        }

        // Output path
        args.append(savePath)

        let result = try await shellService.run(
            executable: "screencapture",
            arguments: args,
            timeout: TimeInterval(delay + 30)
        )

        if result.succeeded {
            if FileManager.default.fileExists(atPath: savePath) {
                return .success("Screenshot saved to: \(savePath)")
            }
            return .success("Screenshot command completed. File may have been saved to: \(savePath)")
        }

        return .error("Failed to capture screenshot: \(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines))")
    }

    func confirmationDescription(parameters: [String: Any]) -> String {
        let area = (parameters["area"] as? String) ?? "full"
        return "Capture \(area) screenshot"
    }
}
