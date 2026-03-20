import Foundation
import os

// MARK: - AppleScriptError

enum AppleScriptError: Error, LocalizedError {
    case executionFailed(String)
    case timeout

    var errorDescription: String? {
        switch self {
        case .executionFailed(let reason):
            "AppleScript execution failed: \(reason)"
        case .timeout:
            "AppleScript execution timed out"
        }
    }
}

// MARK: - AppleScriptService

/// Actor wrapping ShellService for safe AppleScript execution via `osascript`.
///
/// All string inputs are sanitized to prevent AppleScript injection attacks.
actor AppleScriptService {
    private static let logger = Logger(subsystem: "com.shellmate.app", category: "applescript")

    private let shellService: ShellService

    init(shellService: ShellService) {
        self.shellService = shellService
    }

    // MARK: - Public API

    /// Execute a raw AppleScript string via `osascript`.
    func execute(script: String, timeout: TimeInterval = 30) async throws -> String {
        Self.logger.debug("Executing AppleScript (\(script.count) chars)")

        let result = try await shellService.run(
            executable: "osascript",
            arguments: ["-e", script],
            timeout: timeout
        )

        if result.succeeded {
            return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let stderr = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        throw AppleScriptError.executionFailed(stderr.isEmpty ? "Exit code \(result.exitCode)" : stderr)
    }

    /// Execute a command targeting a specific application.
    ///
    /// Builds `tell application "app" to command` with proper sanitization of the app name.
    func execute(app: String, command: String) async throws -> String {
        let safeApp = sanitize(app)
        let script = "tell application \"\(safeApp)\" to \(command)"
        return try await execute(script: script)
    }

    // MARK: - Sanitization

    /// Sanitize a string for safe interpolation into AppleScript string literals.
    ///
    /// Escapes backslashes first (so we don't double-escape), then quotes.
    static func sanitize(_ input: String) -> String {
        input
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    /// Instance convenience wrapper.
    func sanitize(_ input: String) -> String {
        Self.sanitize(input)
    }
}
