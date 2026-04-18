import Foundation

/// Converts an image between formats using `sips`.
struct ImageConvertTool: AgentTool {
    let identifier = "image_convert"
    let toolDescription = "Convert an image file to a different format (png, jpeg, tiff, gif, bmp)."
    let category = ToolCategory.media
    let actionTier = ActionTier.write
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "path": ToolProperty(
                type: "string",
                description: "Path to the source image file."
            ),
            "format": ToolProperty(
                type: "string",
                description: "Target format.",
                enumValues: ["png", "jpeg", "tiff", "gif", "bmp"]
            ),
            "output": ToolProperty(
                type: "string",
                description: "Output file path. If omitted, replaces the extension on the input file."
            ),
        ],
        required: ["path", "format"]
    )

    private let shellService: ShellService
    init(shellService: ShellService) { self.shellService = shellService }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let path = parameters["path"] as? String else {
            return .error("Missing required parameter: path")
        }
        guard let format = parameters["format"] as? String else {
            return .error("Missing required parameter: format")
        }

        if SecurityPolicy.isPathBlocked(path) {
            return .error("Access denied: input path is restricted")
        }

        guard FileManager.default.fileExists(atPath: path) else {
            return .error("File not found: \(path)")
        }

        let validFormats = ["png", "jpeg", "tiff", "gif", "bmp"]
        guard validFormats.contains(format) else {
            return .error("Invalid format '\(format)'. Supported: \(validFormats.joined(separator: ", "))")
        }

        let outputPath: String
        if let output = parameters["output"] as? String {
            outputPath = output
        } else {
            let ext = format == "jpeg" ? "jpg" : format
            let url = URL(fileURLWithPath: path)
            outputPath = url.deletingPathExtension().appendingPathExtension(ext).path
        }

        if SecurityPolicy.isPathBlocked(outputPath) {
            return .error("Access denied: output path is restricted")
        }

        let result = try await shellService.run(
            executable: "sips",
            arguments: ["-s", "format", format, path, "--out", outputPath],
            timeout: 30
        )

        if result.succeeded {
            return .success("Image converted to \(format): \(outputPath)")
        }

        return .error("Failed to convert image: \(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines))")
    }

    func confirmationDescription(parameters: [String: Any]) -> String {
        let path = parameters["path"] as? String ?? "image"
        let format = parameters["format"] as? String ?? "unknown"
        return "Convert \(path) to \(format)"
    }
}
