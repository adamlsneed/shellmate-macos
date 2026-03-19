import Foundation
import os

enum ConfigError: LocalizedError {
    case notFound
    case readFailed(String)
    case writeFailed(String)
    case corrupted(String)
    case backupRestoreFailed(String)

    var errorDescription: String? {
        switch self {
        case .notFound: "Configuration file not found. Run setup to create one."
        case .readFailed(let detail): "Failed to read config: \(detail)"
        case .writeFailed(let detail): "Failed to write config: \(detail)"
        case .corrupted(let detail): "Config file is corrupted: \(detail)"
        case .backupRestoreFailed(let detail): "Failed to restore config from backup: \(detail)"
        }
    }
}

final class ConfigService: Sendable {
    private static let logger = Logger(subsystem: "com.shellmate.app", category: "config")
    let configDir: URL
    let configFile: URL
    let workspaceDir: URL

    init(configDir: URL? = nil) {
        let dir = configDir ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".shellmate")
        self.configDir = dir
        self.configFile = dir.appendingPathComponent("shellmate.json")
        self.workspaceDir = dir.appendingPathComponent("workspace")
    }

    var configDirectory: URL { configDir }
    var configFilePath: URL { configFile }
    var workspacePath: URL { workspaceDir }
    var configExists: Bool { FileManager.default.fileExists(atPath: configFile.path) }

    func isSetupComplete() -> Bool {
        guard let config = try? readConfig() else { return false }
        return config.setupComplete
    }

    func readConfig() throws -> ShellmateConfig {
        guard FileManager.default.fileExists(atPath: configFile.path) else { throw ConfigError.notFound }
        do {
            let data = try Data(contentsOf: configFile)
            return try JSONDecoder().decode(ShellmateConfig.self, from: data)
        } catch {
            Self.logger.warning("Config corrupted: \(error.localizedDescription)")
            if let restored = try? restoreFromBackup() { return restored }
            throw ConfigError.corrupted(error.localizedDescription)
        }
    }

    func writeConfig(_ config: ShellmateConfig) throws {
        try FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: configFile.path) { try backupConfig() }
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(config)
            try data.write(to: configFile, options: .atomic)
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: configFile.path)
        } catch { throw ConfigError.writeFailed(error.localizedDescription) }
    }

    func patchConfig(_ transform: (inout ShellmateConfig) -> Void) throws {
        var config = (try? readConfig()) ?? ShellmateConfig()
        transform(&config)
        try writeConfig(config)
    }

    func backupConfig() throws {
        guard FileManager.default.fileExists(atPath: configFile.path) else { return }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let backupFile = configDir.appendingPathComponent("shellmate.json.bak-\(formatter.string(from: Date()))")
        try FileManager.default.copyItem(at: configFile, to: backupFile)
    }

    func restoreFromBackup() throws -> ShellmateConfig {
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: configDir.path) else {
            throw ConfigError.backupRestoreFailed("Cannot list config directory")
        }
        for backup in contents.filter({ $0.contains(".bak") }).sorted().reversed() {
            if let data = try? Data(contentsOf: configDir.appendingPathComponent(backup)),
               let config = try? JSONDecoder().decode(ShellmateConfig.self, from: data) {
                let enc = JSONEncoder(); enc.outputFormatting = [.prettyPrinted, .sortedKeys]
                if let d = try? enc.encode(config) { try? d.write(to: configFile, options: .atomic) }
                return config
            }
        }
        throw ConfigError.backupRestoreFailed("No valid backup found")
    }

    func listBackups() -> [String] {
        (try? FileManager.default.contentsOfDirectory(atPath: configDir.path))?.filter { $0.contains(".bak") }.sorted() ?? []
    }

    func ensureWorkspace() throws {
        try FileManager.default.createDirectory(at: workspaceDir, withIntermediateDirectories: true)
    }

    func ensureConfigDirectory() throws {
        try FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
        try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: configDir.path)
    }
}

@MainActor
final class ConfigFileWatcher {
    private static let logger = Logger(subsystem: "com.shellmate.app", category: "config")
    private let configPath: String
    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1
    var onChange: (() -> Void)?
    init(configPath: String) { self.configPath = configPath }
    deinit { source?.cancel(); source = nil }
    func start() {
        stop()
        fileDescriptor = open(configPath, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fileDescriptor, eventMask: [.write, .rename, .delete], queue: .main)
        source.setEventHandler { [weak self] in self?.onChange?() }
        source.setCancelHandler { [weak self] in if let fd = self?.fileDescriptor, fd >= 0 { close(fd) }; self?.fileDescriptor = -1 }
        source.resume()
        self.source = source
    }
    func stop() { source?.cancel(); source = nil }
}
