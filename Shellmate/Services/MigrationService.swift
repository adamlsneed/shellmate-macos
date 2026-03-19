import Foundation
import os

/// Handles legacy ~/.openclaw/ → ~/.shellmate/ migration.
struct MigrationService: Sendable {
    private static let logger = Logger(subsystem: "com.shellmate.app", category: "migration")

    private var legacyDir: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".openclaw")
    }

    private var targetDir: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".shellmate")
    }

    /// Check if legacy OpenClaw installation exists.
    var needsMigration: Bool {
        FileManager.default.fileExists(atPath: legacyDir.path) && !FileManager.default.fileExists(atPath: targetDir.path)
    }

    /// Migrate ~/.openclaw/ to ~/.shellmate/.
    func migrate() throws {
        Self.logger.info("Starting migration from ~/.openclaw/ to ~/.shellmate/")

        guard needsMigration else {
            Self.logger.info("No migration needed")
            return
        }

        // Copy the entire directory
        try FileManager.default.copyItem(at: legacyDir, to: targetDir)

        // Rename openclaw.json → shellmate.json if it exists
        let oldConfig = targetDir.appendingPathComponent("openclaw.json")
        let newConfig = targetDir.appendingPathComponent("shellmate.json")
        if FileManager.default.fileExists(atPath: oldConfig.path) {
            try FileManager.default.moveItem(at: oldConfig, to: newConfig)
        }

        Self.logger.info("Migration complete")
    }
}
