import Foundation
import os

enum MigrationError: LocalizedError {
    case sourceNotFound
    case targetAlreadyExists
    case copyFailed(String)
    case configUpdateFailed(String)

    var errorDescription: String? {
        switch self {
        case .sourceNotFound: "Legacy ~/.openclaw/ directory not found."
        case .targetAlreadyExists: "~/.shellmate/ already exists."
        case .copyFailed(let detail): "Failed to copy: \(detail)"
        case .configUpdateFailed(let detail): "Config update failed: \(detail)"
        }
    }
}

struct MigrationService: Sendable {
    private static let logger = Logger(subsystem: "com.shellmate.app", category: "migration")
    private let legacyDirURL: URL
    private let targetDirURL: URL

    init(legacyDir: URL? = nil, targetDir: URL? = nil) {
        let home = FileManager.default.homeDirectoryForCurrentUser
        self.legacyDirURL = legacyDir ?? home.appendingPathComponent(".openclaw")
        self.targetDirURL = targetDir ?? home.appendingPathComponent(".shellmate")
    }

    var needsMigration: Bool {
        let fm = FileManager.default
        let legacyExists = fm.fileExists(atPath: legacyDirURL.appendingPathComponent("openclaw.json").path) || fm.fileExists(atPath: legacyDirURL.path)
        return legacyExists && !fm.fileExists(atPath: targetDirURL.path)
    }

    func migrate() throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: legacyDirURL.path) else { throw MigrationError.sourceNotFound }
        guard !fm.fileExists(atPath: targetDirURL.path) else { throw MigrationError.targetAlreadyExists }
        try fm.createDirectory(at: targetDirURL, withIntermediateDirectories: true)
        try migrateConfigFile()
        try migrateWorkspace()
        try migrateExtraFiles()
    }

    private func migrateConfigFile() throws {
        let fm = FileManager.default
        let legacyConfig = legacyDirURL.appendingPathComponent("openclaw.json")
        let newConfig = targetDirURL.appendingPathComponent("shellmate.json")
        guard fm.fileExists(atPath: legacyConfig.path) else { return }
        let data = try Data(contentsOf: legacyConfig)
        guard var json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            try fm.copyItem(at: legacyConfig, to: newConfig); return
        }
        if var agents = json["agents"] as? [String: Any] {
            if var defaults = agents["defaults"] as? [String: Any], let ws = defaults["workspace"] as? String {
                defaults["workspace"] = ws.replacingOccurrences(of: "/.openclaw/", with: "/.shellmate/")
                agents["defaults"] = defaults
            }
            if var list = agents["list"] as? [[String: Any]] {
                for i in 0..<list.count {
                    if let ws = list[i]["workspace"] as? String {
                        list[i]["workspace"] = ws.replacingOccurrences(of: "/.openclaw/", with: "/.shellmate/")
                    }
                }
                agents["list"] = list
            }
            json["agents"] = agents
        }
        try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]).write(to: newConfig, options: .atomic)
    }

    private func migrateWorkspace() throws {
        let fm = FileManager.default
        let legacyWS = legacyDirURL.appendingPathComponent("workspace")
        let newWS = targetDirURL.appendingPathComponent("workspace")
        guard fm.fileExists(atPath: legacyWS.path), !fm.fileExists(atPath: newWS.path) else { return }
        try copyDirectory(from: legacyWS, to: newWS)
    }

    private func migrateExtraFiles() throws {
        let fm = FileManager.default
        for dir in ["skills", "memory"] {
            let src = legacyDirURL.appendingPathComponent(dir)
            let dst = targetDirURL.appendingPathComponent(dir)
            if fm.fileExists(atPath: src.path), !fm.fileExists(atPath: dst.path) { try? copyDirectory(from: src, to: dst) }
        }
    }

    private func copyDirectory(from source: URL, to dest: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: dest, withIntermediateDirectories: true)
        for item in try fm.contentsOfDirectory(at: source, includingPropertiesForKeys: [.isDirectoryKey]) {
            let d = dest.appendingPathComponent(item.lastPathComponent)
            if (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                try copyDirectory(from: item, to: d)
            } else { try fm.copyItem(at: item, to: d) }
        }
    }
}
