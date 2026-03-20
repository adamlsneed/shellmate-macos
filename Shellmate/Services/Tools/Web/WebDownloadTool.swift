import Foundation

/// Downloads a file from a URL to disk using curl.
struct WebDownloadTool: AgentTool {
    let identifier = "web_download"
    let toolDescription = "Download a file from a URL to disk. Follows redirects. Saves to Downloads folder by default."
    let category = ToolCategory.web
    let actionTier = ActionTier.write
    let parameterSchema = ToolInputSchema(
        type: "object",
        properties: [
            "url": ToolProperty(type: "string", description: "URL of the file to download"),
            "destination": ToolProperty(type: "string", description: "Directory to save the file in. Defaults to ~/Downloads."),
            "filename": ToolProperty(type: "string", description: "Output filename. If omitted, derived from the URL."),
        ],
        required: ["url"]
    )

    private let shellService: ShellService
    init(shellService: ShellService) { self.shellService = shellService }

    func confirmationDescription(parameters: [String: Any]) -> String {
        let url = parameters["url"] as? String ?? "unknown"
        let filename = parameters["filename"] as? String ?? URL(string: url)?.lastPathComponent ?? "file"
        return "Download '\(filename)' from \(url)"
    }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let urlString = parameters["url"] as? String, !urlString.isEmpty else {
            return .error("Missing required parameter: url")
        }

        guard URL(string: urlString) != nil else {
            return .error("Invalid URL: \(urlString)")
        }

        let destination = (parameters["destination"] as? String) ?? "~/Downloads"
        let expandedDest = NSString(string: destination).expandingTildeInPath

        // Determine filename
        let filename: String
        if let fn = parameters["filename"] as? String, !fn.isEmpty {
            filename = fn
        } else {
            filename = URL(string: urlString)?.lastPathComponent ?? "download"
        }

        let outputPath = (expandedDest as NSString).appendingPathComponent(filename)

        // Ensure destination directory exists
        try FileManager.default.createDirectory(atPath: expandedDest, withIntermediateDirectories: true)

        let result = try await shellService.run(
            executable: "curl",
            arguments: ["-L", "-o", outputPath, "--progress-bar", "--fail", urlString],
            timeout: 300
        )

        if result.succeeded {
            // Check file size
            let attrs = try? FileManager.default.attributesOfItem(atPath: outputPath)
            let size = (attrs?[.size] as? Int64) ?? 0
            let sizeStr = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
            return .success("Downloaded '\(filename)' (\(sizeStr)) to \(outputPath)")
        }
        return .error("Download failed: \(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines))")
    }
}
