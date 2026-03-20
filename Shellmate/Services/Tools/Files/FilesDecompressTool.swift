import Foundation

/// Extracts a zip archive using ditto.
struct FilesDecompressTool: AgentTool {
    let identifier = "files_decompress"
    let toolDescription = "Extract a zip archive to a directory."
    let category = ToolCategory.files
    let actionTier = ActionTier.write

    private let shellService: ShellService

    init(shellService: ShellService) {
        self.shellService = shellService
    }

    var parameterSchema: ToolInputSchema {
        ToolInputSchema(
            type: "object",
            properties: [
                "archive": ToolProperty(type: "string", description: "Path to the zip archive to extract"),
                "destination": ToolProperty(type: "string", description: "Directory to extract into (optional — defaults to next to the archive)"),
            ],
            required: ["archive"]
        )
    }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let archive = parameters["archive"] as? String, !archive.isEmpty else {
            return .error("Missing required 'archive' parameter")
        }

        let archiveURL = URL(fileURLWithPath: archive).standardized

        guard FileManager.default.fileExists(atPath: archiveURL.path) else {
            return .error("Archive not found: \(archive)")
        }

        // Determine destination
        let destinationPath: String
        if let dest = parameters["destination"] as? String, !dest.isEmpty {
            destinationPath = dest
        } else {
            destinationPath = archiveURL.deletingLastPathComponent().path
        }

        // Create destination directory if needed
        try? FileManager.default.createDirectory(
            atPath: destinationPath,
            withIntermediateDirectories: true
        )

        // ditto -x -k <archive> <destination>
        let arguments = ["-x", "-k", archiveURL.path, destinationPath]

        do {
            let result = try await shellService.run(
                executable: "/usr/bin/ditto",
                arguments: arguments,
                timeout: 120
            )

            if result.succeeded {
                return .success("Extracted to: \(destinationPath)")
            } else {
                return .error("Extraction failed: \(result.stderr)")
            }
        } catch {
            return .error("Extraction failed: \(error.localizedDescription)")
        }
    }

    func confirmationDescription(parameters: [String: Any]) -> String {
        let archive = parameters["archive"] as? String ?? "unknown"
        let destination = parameters["destination"] as? String ?? "auto"
        return "Extract \(archive) to \(destination)"
    }
}
