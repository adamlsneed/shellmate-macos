import AppKit
import Foundation

/// Reveals a file or directory in Finder.
struct FilesRevealInFinderTool: AgentTool {
    let identifier = "files_reveal_in_finder"
    let toolDescription = "Reveal a file or directory in Finder, highlighting it."
    let category = ToolCategory.files
    let actionTier = ActionTier.read

    var parameterSchema: ToolInputSchema {
        ToolInputSchema(
            type: "object",
            properties: [
                "path": ToolProperty(type: "string", description: "Absolute path of the file or directory to reveal"),
            ],
            required: ["path"]
        )
    }

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        guard let path = parameters["path"] as? String else {
            return .error("Missing required 'path' parameter")
        }

        let url = URL(fileURLWithPath: path).standardized

        guard FileManager.default.fileExists(atPath: url.path) else {
            return .error("File not found: \(path)")
        }

        NSWorkspace.shared.activateFileViewerSelecting([url])
        return .success("Revealed in Finder: \(path)")
    }
}
