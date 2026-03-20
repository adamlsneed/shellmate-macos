import Foundation

/// Compresses files or directories into a zip archive using ditto.
struct FilesCompressTool: AgentTool {
    let identifier = "files_compress"
    let toolDescription = "Compress files or directories into a zip archive."
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
                "paths": ToolProperty(type: "string", description: "Path to compress, or comma-separated paths for multiple items"),
                "output": ToolProperty(type: "string", description: "Output zip file path (optional — defaults to next to the first input file)"),
            ],
            required: ["paths"]
        )
    }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let pathsString = parameters["paths"] as? String, !pathsString.isEmpty else {
            return .error("Missing required 'paths' parameter")
        }

        let paths = pathsString.components(separatedBy: ",").map {
            $0.trimmingCharacters(in: .whitespaces)
        }

        guard let firstPath = paths.first else {
            return .error("No paths provided")
        }

        let firstURL = URL(fileURLWithPath: firstPath).standardized

        // Determine output path
        let outputPath: String
        if let output = parameters["output"] as? String, !output.isEmpty {
            outputPath = output
        } else {
            let baseName = firstURL.deletingPathExtension().lastPathComponent
            outputPath = firstURL.deletingLastPathComponent()
                .appendingPathComponent("\(baseName).zip").path
        }

        // Verify all input paths exist
        for path in paths {
            let url = URL(fileURLWithPath: path).standardized
            guard FileManager.default.fileExists(atPath: url.path) else {
                return .error("File not found: \(path)")
            }
        }

        // Use ditto with structured args for each input path
        // ditto -c -k --sequesterRsrc <src...> <dst>
        var arguments = ["-c", "-k", "--sequesterRsrc"]
        for path in paths {
            arguments.append(URL(fileURLWithPath: path).standardized.path)
        }
        arguments.append(outputPath)

        do {
            let result = try await shellService.run(
                executable: "/usr/bin/ditto",
                arguments: arguments,
                timeout: 120
            )

            if result.succeeded {
                return .success("Compressed to: \(outputPath)")
            } else {
                return .error("Compression failed: \(result.stderr)")
            }
        } catch {
            return .error("Compression failed: \(error.localizedDescription)")
        }
    }

    func confirmationDescription(parameters: [String: Any]) -> String {
        let paths = parameters["paths"] as? String ?? "unknown"
        let output = parameters["output"] as? String ?? "auto"
        return "Compress \(paths) into \(output)"
    }
}
