import Foundation

/// Moves a file or directory to the Trash (never permanently deletes).
struct FilesDeleteTool: AgentTool {
    let identifier = "files_delete"
    let toolDescription = "Delete a file or directory by moving it to the Trash. This is safe — items can be recovered from the Trash."
    let category = ToolCategory.files
    let actionTier = ActionTier.destructive

    var parameterSchema: ToolInputSchema {
        ToolInputSchema(
            type: "object",
            properties: [
                "path": ToolProperty(type: "string", description: "Absolute path of the file or directory to delete"),
            ],
            required: ["path"]
        )
    }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let path = parameters["path"] as? String else {
            return .error("Missing required 'path' parameter")
        }

        if SecurityPolicy.isPathBlocked(path) {
            return .error("Access denied: path is restricted")
        }

        let url = URL(fileURLWithPath: path).standardized

        guard FileManager.default.fileExists(atPath: url.path) else {
            return .error("File not found: \(path)")
        }

        do {
            var resultURL: NSURL?
            try FileManager.default.trashItem(at: url, resultingItemURL: &resultURL)
            let trashPath = resultURL?.path ?? "Trash"
            return .success("Moved to Trash: \(path) (now at \(trashPath))")
        } catch {
            return .error("Failed to trash: \(error.localizedDescription)")
        }
    }

    func confirmationDescription(parameters: [String: Any]) -> String {
        let path = parameters["path"] as? String ?? "unknown"
        return "Move to Trash: \(path)"
    }
}
