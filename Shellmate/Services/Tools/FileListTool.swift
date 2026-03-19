import Foundation

/// Lists files and directories with depth limiting.
enum FileListTool {
    private static let defaultDepth = 2
    private static let maxEntries = 500

    static func execute(input: [String: Any]) -> ToolExecutionResult {
        guard let path = input["path"] as? String else {
            return ToolExecutionResult(content: "Missing required 'path' parameter", isError: true)
        }

        if SecurityPolicy.isPathBlocked(path) {
            return ToolExecutionResult(content: "Access denied: path is restricted", isError: true)
        }

        let maxDepth = (input["depth"] as? Int) ?? defaultDepth
        let url = URL(fileURLWithPath: path).standardized

        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else {
            return ToolExecutionResult(content: "Not a directory: \(path)", isError: true)
        }

        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return ToolExecutionResult(content: "Failed to list directory", isError: true)
        }

        var entries: [String] = []
        let basePath = url.path

        while let itemURL = enumerator.nextObject() as? URL {
            // Check depth
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

        return ToolExecutionResult(
            content: entries.isEmpty ? "(empty directory)" : entries.joined(separator: "\n"),
            isError: false
        )
    }
}
