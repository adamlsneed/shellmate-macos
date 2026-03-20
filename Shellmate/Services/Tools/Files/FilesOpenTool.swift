import AppKit
import Foundation

/// Opens a file with its default application using NSWorkspace.
struct FilesOpenTool: AgentTool {
    let identifier = "files_open"
    let toolDescription = "Open a file with its default application on the user's Mac."
    let category = ToolCategory.files
    let actionTier = ActionTier.write

    var parameterSchema: ToolInputSchema {
        ToolInputSchema(
            type: "object",
            properties: [
                "path": ToolProperty(type: "string", description: "Absolute path of the file to open"),
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

        let opened = NSWorkspace.shared.open(url)
        if opened {
            return .success("Opened: \(path)")
        } else {
            return .error("Failed to open: \(path) — no application found for this file type")
        }
    }

    func confirmationDescription(parameters: [String: Any]) -> String {
        let path = parameters["path"] as? String ?? "unknown"
        return "Open file: \(path)"
    }
}
