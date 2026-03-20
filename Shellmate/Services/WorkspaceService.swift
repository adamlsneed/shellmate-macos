import Foundation
import os

struct WorkspaceWriteResult: Sendable {
    var written: [String] = []
    var skipped: [String] = []
    var errors: [(path: String, error: String)] = []
}

struct WorkspaceService: Sendable {
    private static let logger = Logger(subsystem: "com.shellmate.app", category: "workspace")
    private let configService: ConfigService

    init(configService: ConfigService = ConfigService()) {
        self.configService = configService
    }

    var workspacePath: URL { configService.workspacePath }

    var isSetUp: Bool {
        FileManager.default.fileExists(atPath: workspacePath.appendingPathComponent("SOUL.md").path)
    }

    func detectConflicts(files: [GeneratedFile]) -> [GeneratedFile] {
        files.map { file in
            var updated = file
            updated.existsOnDisk = fileExists(name: file.filename)
            return updated
        }
    }

    func writeFile(name: String, content: String, force: Bool = true) throws {
        try configService.ensureWorkspace()
        let fileURL = workspacePath.appendingPathComponent(name)
        let parentDir = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
        let resolvedPath = fileURL.standardized.path
        let workspaceBase = workspacePath.standardized.path
        guard resolvedPath.hasPrefix(workspaceBase) else {
            throw ConfigError.writeFailed("Path must be within workspace: \(name)")
        }
        if FileManager.default.fileExists(atPath: fileURL.path) {
            if !force { return }
            try backupWorkspaceFile(fileURL)
        }
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o600], ofItemAtPath: fileURL.path
        )
    }

    func writeFiles(_ files: [GeneratedFile], force: Bool = false) -> WorkspaceWriteResult {
        var result = WorkspaceWriteResult()
        for file in files {
            let fileURL = workspacePath.appendingPathComponent(file.filename)
            if FileManager.default.fileExists(atPath: fileURL.path) && !force {
                result.skipped.append(file.filename)
                continue
            }
            do {
                try writeFile(name: file.filename, content: file.content, force: force)
                result.written.append(file.filename)
            } catch { result.errors.append((path: file.filename, error: error.localizedDescription)) }
        }
        return result
    }

    func fileExists(name: String) -> Bool {
        FileManager.default.fileExists(atPath: workspacePath.appendingPathComponent(name).path)
    }

    func readFile(name: String) throws -> String {
        let fileURL = workspacePath.appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { throw ConfigError.notFound }
        return try String(contentsOf: fileURL, encoding: .utf8)
    }

    func readAllAsSystemPrompt() -> String {
        let filenames = ["SOUL.md", "IDENTITY.md", "AGENTS.md", "USER.md", "TOOLS.md", "MEMORY.md"]
        var sections: [String] = []
        for name in filenames {
            if let content = try? readFile(name: name), !content.isEmpty { sections.append(content) }
        }
        return sections.joined(separator: "\n\n---\n\n")
    }

    func listFiles() -> [String] {
        guard let enumerator = FileManager.default.enumerator(at: workspacePath, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) else { return [] }
        var files: [String] = []
        for case let fileURL as URL in enumerator {
            if let isFile = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile, isFile {
                files.append(fileURL.path.replacingOccurrences(of: workspacePath.path + "/", with: ""))
            }
        }
        return files.sorted()
    }

    private func backupWorkspaceFile(_ fileURL: URL) throws {
        let ext = fileURL.pathExtension
        let backupURL = fileURL.deletingPathExtension()
            .appendingPathExtension("\(ext).bak-\(BackupTimestamp.now)")
        try? FileManager.default.removeItem(at: backupURL)
        try FileManager.default.copyItem(at: fileURL, to: backupURL)
    }
}
