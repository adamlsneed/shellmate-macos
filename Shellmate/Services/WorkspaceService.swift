import Foundation

/// Manages the agent workspace at ~/.shellmate/workspace/
struct WorkspaceService: Sendable {
    private let configService = ConfigService()

    var workspacePath: URL { configService.workspacePath }

    /// Check if workspace has been set up.
    var isSetUp: Bool {
        FileManager.default.fileExists(atPath: workspacePath.appendingPathComponent("SOUL.md").path)
    }

    /// Write a generated file to the workspace.
    func writeFile(name: String, content: String) throws {
        try configService.ensureWorkspace()
        let fileURL = workspacePath.appendingPathComponent(name)

        // Back up existing file if present
        if FileManager.default.fileExists(atPath: fileURL.path) {
            let backupURL = workspacePath.appendingPathComponent("\(name).bak")
            try? FileManager.default.removeItem(at: backupURL)
            try FileManager.default.copyItem(at: fileURL, to: backupURL)
        }

        try content.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    /// Check if a file already exists in the workspace.
    func fileExists(name: String) -> Bool {
        FileManager.default.fileExists(atPath: workspacePath.appendingPathComponent(name).path)
    }

    /// List all files in the workspace.
    func listFiles() -> [String] {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(atPath: workspacePath.path) else {
            return []
        }
        return contents.sorted()
    }
}
