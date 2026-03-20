import Foundation

/// Resizes an image using the `sips` CLI.
struct ImageResizeTool: AgentTool {
    let identifier = "image_resize"
    let toolDescription = "Resize an image file by specifying width, height, or both. Uses macOS sips."
    let category = ToolCategory.media
    let actionTier = ActionTier.write
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "path": ToolProperty(
                type: "string",
                description: "Path to the image file to resize."
            ),
            "width": ToolProperty(
                type: "integer",
                description: "Target width in pixels."
            ),
            "height": ToolProperty(
                type: "integer",
                description: "Target height in pixels."
            ),
            "output": ToolProperty(
                type: "string",
                description: "Output file path. If omitted, the original file is modified in place."
            ),
        ],
        required: ["path"]
    )

    private let shellService: ShellService
    init(shellService: ShellService) { self.shellService = shellService }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let path = parameters["path"] as? String else {
            return .error("Missing required parameter: path")
        }

        guard FileManager.default.fileExists(atPath: path) else {
            return .error("File not found: \(path)")
        }

        let width = parameters["width"] as? Int ?? (parameters["width"] as? Double).map { Int($0) }
        let height = parameters["height"] as? Int ?? (parameters["height"] as? Double).map { Int($0) }

        guard width != nil || height != nil else {
            return .error("At least one of 'width' or 'height' must be specified.")
        }

        // If output path specified, copy first
        let workPath: String
        if let output = parameters["output"] as? String {
            try FileManager.default.copyItem(atPath: path, toPath: output)
            workPath = output
        } else {
            workPath = path
        }

        var args: [String] = []
        if let w = width {
            args += ["--resampleWidth", String(w)]
        }
        if let h = height {
            args += ["--resampleHeight", String(h)]
        }
        args.append(workPath)

        let result = try await shellService.run(
            executable: "sips",
            arguments: args,
            timeout: 30
        )

        if result.succeeded {
            return .success("Image resized: \(workPath)")
        }

        return .error("Failed to resize image: \(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines))")
    }

    func confirmationDescription(parameters: [String: Any]) -> String {
        let path = parameters["path"] as? String ?? "image"
        let w = parameters["width"] as? Int
        let h = parameters["height"] as? Int
        var dims = ""
        if let w { dims += "\(w)w" }
        if let h { dims += (dims.isEmpty ? "" : "x") + "\(h)h" }
        return "Resize \(path) to \(dims)"
    }
}
