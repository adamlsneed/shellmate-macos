import Foundation

/// Errors from config operations
enum ConfigError: LocalizedError {
    case notFound
    case readFailed(String)
    case writeFailed(String)

    var errorDescription: String? {
        switch self {
        case .notFound:
            "Configuration file not found. Run setup to create one."
        case .readFailed(let detail):
            "Failed to read config: \(detail)"
        case .writeFailed(let detail):
            "Failed to write config: \(detail)"
        }
    }
}

/// Reads, writes, and backs up ~/.shellmate/shellmate.json
struct ConfigService: Sendable {
    private let configDir: URL
    private let configFile: URL
    private let workspaceDir: URL

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        configDir = home.appendingPathComponent(".shellmate")
        configFile = configDir.appendingPathComponent("shellmate.json")
        workspaceDir = configDir.appendingPathComponent("workspace")
    }

    var configDirectory: URL { configDir }
    var configFilePath: URL { configFile }
    var workspacePath: URL { workspaceDir }

    /// Check if config file exists.
    var configExists: Bool {
        FileManager.default.fileExists(atPath: configFile.path)
    }

    /// Check if setup has been completed.
    func isSetupComplete() -> Bool {
        guard let config = try? readConfig() else { return false }
        return config.setupComplete
    }

    /// Read the config file.
    func readConfig() throws -> ShellmateConfig {
        guard FileManager.default.fileExists(atPath: configFile.path) else {
            throw ConfigError.notFound
        }
        do {
            let data = try Data(contentsOf: configFile)
            return try JSONDecoder().decode(ShellmateConfig.self, from: data)
        } catch let error as DecodingError {
            throw ConfigError.readFailed(error.localizedDescription)
        } catch {
            throw ConfigError.readFailed(error.localizedDescription)
        }
    }

    /// Write the config file with automatic backup.
    func writeConfig(_ config: ShellmateConfig) throws {
        // Ensure directory exists
        try FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)

        // Backup existing config before overwriting
        if FileManager.default.fileExists(atPath: configFile.path) {
            try backupConfig()
        }

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(config)
            try data.write(to: configFile, options: .atomic)
        } catch {
            throw ConfigError.writeFailed(error.localizedDescription)
        }
    }

    /// Create a timestamped backup of the current config.
    func backupConfig() throws {
        guard FileManager.default.fileExists(atPath: configFile.path) else { return }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let timestamp = formatter.string(from: Date())
        let backupFile = configDir.appendingPathComponent("shellmate-\(timestamp).json.bak")
        try FileManager.default.copyItem(at: configFile, to: backupFile)
    }

    /// Ensure the workspace directory exists.
    func ensureWorkspace() throws {
        try FileManager.default.createDirectory(at: workspaceDir, withIntermediateDirectories: true)
    }
}
