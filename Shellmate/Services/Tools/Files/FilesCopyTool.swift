import Foundation

/// Copies a file or directory to a new location.
struct FilesCopyTool: AgentTool {
    let identifier = "files_copy"
    let toolDescription = "Copy a file or directory to a new location on the user's Mac."
    let category = ToolCategory.files
    let actionTier = ActionTier.write

    var parameterSchema: ToolInputSchema {
        ToolInputSchema(
            type: "object",
            properties: [
                "source": ToolProperty(type: "string", description: "Absolute path of the file or directory to copy"),
                "destination": ToolProperty(type: "string", description: "Absolute path of the destination"),
            ],
            required: ["source", "destination"]
        )
    }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let source = parameters["source"] as? String else {
            return .error("Missing required 'source' parameter")
        }
        guard let destination = parameters["destination"] as? String else {
            return .error("Missing required 'destination' parameter")
        }

        if SecurityPolicy.isPathBlocked(source) {
            return .error("Access denied: source path is restricted")
        }
        if SecurityPolicy.isPathBlocked(destination) {
            return .error("Access denied: destination path is restricted")
        }

        let fm = FileManager.default
        let srcURL = URL(fileURLWithPath: source).standardized

        guard fm.fileExists(atPath: srcURL.path) else {
            return .error("Source not found: \(source)")
        }

        var dstURL = URL(fileURLWithPath: destination).standardized

        // If destination is an existing directory, copy into it
        var isDir: ObjCBool = false
        if fm.fileExists(atPath: dstURL.path, isDirectory: &isDir), isDir.boolValue {
            dstURL = dstURL.appendingPathComponent(srcURL.lastPathComponent)
        }

        do {
            try fm.copyItem(at: srcURL, to: dstURL)
            return .success("Copied \(source) to \(dstURL.path)")
        } catch {
            return .error("Copy failed: \(error.localizedDescription)")
        }
    }

    func confirmationDescription(parameters: [String: Any]) -> String {
        let source = parameters["source"] as? String ?? "unknown"
        let destination = parameters["destination"] as? String ?? "unknown"
        return "Copy \(source) to \(destination)"
    }
}
