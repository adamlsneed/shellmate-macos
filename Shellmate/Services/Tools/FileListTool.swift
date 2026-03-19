import Foundation

/// Lists files and directories with depth limiting.
struct FileListTool: AgentTool {
    let identifier = "file_list"
    let toolDescription = "List files and directories at a given path on the user's Mac."
    let category = ToolCategory.files
    let actionTier = ActionTier.read

    var parameterSchema: ToolInputSchema {
        ToolInputSchema(
            type: "object",
            properties: [
                "path": ToolProperty(type: "string", description: "Absolute path to the directory to list"),
                "depth": ToolProperty(type: "integer", description: "Maximum depth to recurse (default 2)"),
            ],
            required: ["path"]
        )
    }

    private let defaultDepth = 2
    private let maxEntries = 500

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let path = parameters["path"] as? String else {
            return .error("Missing required 'path' parameter")
        }

        if SecurityPolicy.isPathBlocked(path) {
            return .error("Access denied: path is restricted")
        }

        let maxDepth = (parameters["depth"] as? Int) ?? defaultDepth
        let url = URL(fileURLWithPath: path).standardized

        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else {
            return .error("Not a directory: \(path)")
        }

        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return .error("Failed to list directory")
        }

        var entries: [String] = []
        let basePath = url.path

        while let itemURL = enumerator.nextObject() as? URL {
            let relativePath = itemURL.path.replacingOccurrences(of: basePath + "/", with: "")
            let depth = relativePath.components(separatedBy: "/").count
            if depth > maxDepth {
                enumerator.skipDescendants()
                continue
            }

            let isDirectory = (try? itemURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            entries.append(relativePath + (isDirectory ? "/" : ""))

            if entries.count >= maxEntries {
                entries.append("... (truncated at \(maxEntries) entries)")
                break
            }
        }

        return .success(entries.isEmpty ? "(empty directory)" : entries.joined(separator: "\n"))
    }
}