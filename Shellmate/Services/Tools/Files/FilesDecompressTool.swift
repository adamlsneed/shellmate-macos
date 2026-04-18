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

        if SecurityPolicy.isPathBlocked(archiveURL.path) {
            return .error("Access denied: archive path is restricted")
        }

        // Determine destination
        let destinationPath: String
        if let dest = parameters["destination"] as? String, !dest.isEmpty {
            destinationPath = dest
        } else {
            destinationPath = archiveURL.deletingLastPathComponent().path
        }

        let destinationURL = URL(fileURLWithPath: destinationPath).standardized

        if SecurityPolicy.isPathBlocked(destinationURL.path) {
            return .error("Access denied: destination path is restricted")
        }

        // Pre-scan archive entries to defend against zip-slip and writes into blocked paths.
        // ditto resolves `..` and follows symlinks; we must validate before extracting.
        let listResult = try await shellService.run(
            executable: "/usr/bin/unzip",
            arguments: ["-Z1", archiveURL.path],
            timeout: 30
        )
        guard listResult.succeeded else {
            return .error("Failed to list archive contents: \(listResult.stderr)")
        }

        let entries = listResult.stdout
            .split(whereSeparator: \.isNewline)
            .map { String($0) }
            .filter { !$0.isEmpty }

        let destResolvedPrefix = destinationURL.resolvingSymlinksInPath().path
            .appending(destinationURL.path.hasSuffix("/") ? "" : "/")

        for entry in entries {
            // Reject absolute paths in entries
            if entry.hasPrefix("/") {
                return .error("Archive contains absolute path entry: \(entry)")
            }
            let entryURL = destinationURL.appendingPathComponent(entry).standardized
            let entryResolved = entryURL.resolvingSymlinksInPath().path
            if !(entryResolved + "/").hasPrefix(destResolvedPrefix) {
                return .error("Archive entry escapes destination: \(entry)")
            }
            if SecurityPolicy.isPathBlocked(entryResolved) {
                return .error("Archive entry resolves to a restricted path: \(entry)")
            }
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
