import Foundation
import os

/// Shared timestamp format for backup filenames.
enum BackupTimestamp {
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmmss"
        return f
    }()

    static var now: String { formatter.string(from: Date()) }
}

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

    // Aliases kept for compatibility — prefer configDir/configFile/workspaceDir directly
    var configDirectory: URL { configDir }
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
        let backupFile = nextBackupURL()
        try FileManager.default.copyItem(at: configFile, to: backupFile)
    }

    private func nextBackupURL() -> URL {
        let timestamp = BackupTimestamp.now
        let first = configDir.appendingPathComponent("shellmate.json.bak-\(timestamp)")
        guard FileManager.default.fileExists(atPath: first.path) else { return first }

        var suffix = 1
        while true {
            let candidate = configDir.appendingPathComponent("shellmate.json.bak-\(timestamp)-\(suffix)")
            if !FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
            suffix += 1
        }
    }

    func restoreFromBackup() throws -> ShellmateConfig {
        let contents: [String]
        do {
            contents = try FileManager.default.contentsOfDirectory(atPath: configDir.path)
        } catch {
            throw ConfigError.backupRestoreFailed("Cannot list config directory: \(error.localizedDescription)")
        }

        let backups = contents.filter { $0.contains(".bak") }.sorted().reversed()
        for backup in backups {
            let backupURL = configDir.appendingPathComponent(backup)
            do {
                let data = try Data(contentsOf: backupURL)
                let config = try JSONDecoder().decode(ShellmateConfig.self, from: data)
                // Restore this backup as the active config
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let encoded = try encoder.encode(config)
                try encoded.write(to: configFile, options: .atomic)
                try? FileManager.default.setAttributes(
                    [.posixPermissions: 0o600], ofItemAtPath: configFile.path
                )
                Self.logger.info("Restored config from backup: \(backup)")
                return config
            } catch {
                Self.logger.warning("Backup \(backup) unusable: \(error.localizedDescription)")
                continue
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

/// Watches the config file for changes using GCD DispatchSource.
/// GCD is used here because DispatchSource.makeFileSystemObjectSource has no
/// Swift Concurrency equivalent.
@MainActor
final class ConfigFileWatcher {
    private static let logger = Logger(subsystem: "com.shellmate.app", category: "config-watcher")
    private let configPath: String
    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1
    var onChange: (() -> Void)?

    init(configPath: String) {
        self.configPath = configPath
    }

    deinit {
        source?.cancel()
        source = nil
    }

    func start() {
        stop()
        fileDescriptor = open(configPath, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            Self.logger.warning("Failed to open config file for watching: \(self.configPath)")
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .rename, .delete],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            self?.onChange?()
        }
        source.setCancelHandler { [weak self] in
            guard let self, self.fileDescriptor >= 0 else { return }
            close(self.fileDescriptor)
            self.fileDescriptor = -1
        }
        source.resume()
        self.source = source
    }

    func stop() {
        source?.cancel()
        source = nil
    }
}
