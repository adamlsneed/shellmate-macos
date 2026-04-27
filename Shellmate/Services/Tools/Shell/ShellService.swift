import Foundation
import os

// MARK: - ShellResult

struct ShellResult: Sendable {
    let exitCode: Int32
    let stdout: String
    let stderr: String
    let duration: TimeInterval
    var succeeded: Bool { exitCode == 0 }
}

// MARK: - ShellCommandRunning

protocol ShellCommandRunning: Sendable {
    func run(
        executable: String,
        arguments: [String],
        environment: [String: String]?,
        workingDirectory: URL?,
        timeout: TimeInterval
    ) async throws -> ShellResult

    func runCommand(
        _ command: String,
        workingDirectory: URL?,
        timeout: TimeInterval
    ) async throws -> ShellResult
}

// MARK: - ShellHistoryEntry

struct ShellHistoryEntry: Sendable, Identifiable {
    let id: UUID
    let command: String
    let exitCode: Int32
    let timestamp: Date
    let duration: TimeInterval
}

// MARK: - ShellServiceError

enum ShellServiceError: Error, LocalizedError {
    case commandNotFound(String)
    case commandBlocked(String)
    case processStartFailed(String)

    var errorDescription: String? {
        switch self {
        case .commandNotFound(let cmd):
            "Command not found: \(cmd)"
        case .commandBlocked(let reason):
            "Access denied: \(reason)"
        case .processStartFailed(let reason):
            "Failed to start process: \(reason)"
        }
    }
}

// MARK: - ShellService

/// Actor that manages shell command execution with safety guardrails.
actor ShellService {
    private static let logger = Logger(subsystem: "com.shellmate.app", category: "shell")
    private static let maxOutputBytes = 1_048_576 // 1MB per stream
    private static let maxHistorySize = 100
    private static let killGracePeriod: TimeInterval = 5

    private var history: [ShellHistoryEntry] = []
    private var environmentCache: [String: String]?

    // MARK: - Structured execution

    /// Execute an executable with an arguments array (no shell injection risk).
    /// Resolves the executable to an absolute path via `which()` before execution.
    func run(
        executable: String,
        arguments: [String] = [],
        environment: [String: String]? = nil,
        workingDirectory: URL? = nil,
        timeout: TimeInterval = 300
    ) async throws -> ShellResult {
        guard let execURL = await which(executable) else {
            throw ShellServiceError.commandNotFound(executable)
        }

        let commandText = ([executable] + arguments).joined(separator: " ")
        let start = ContinuousClock.now

        let process = Process()
        process.executableURL = execURL
        process.arguments = arguments
        if let env = environment {
            process.environment = env
        }
        process.currentDirectoryURL = workingDirectory ?? FileManager.default.homeDirectoryForCurrentUser

        let result = try await executeProcess(process, timeout: timeout)
        let duration = start.duration(to: .now)
        let elapsed = Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18

        let shellResult = ShellResult(
            exitCode: result.exitCode,
            stdout: result.stdout,
            stderr: result.stderr,
            duration: elapsed
        )

        appendHistory(command: commandText, exitCode: result.exitCode, duration: elapsed)
        return shellResult
    }

    // MARK: - String command execution

    /// Execute a shell command string via /bin/zsh. Gated by SecurityPolicy.
    func runCommand(
        _ command: String,
        workingDirectory: URL? = nil,
        timeout: TimeInterval = 60
    ) async throws -> ShellResult {
        // Security check
        if let blocked = SecurityPolicy.checkShellCommand(command) {
            throw ShellServiceError.commandBlocked(blocked)
        }

        Self.logger.info("Executing shell command (\(command.count) chars, timeout: \(Int(timeout))s)")

        let start = ContinuousClock.now

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]
        process.currentDirectoryURL = workingDirectory ?? FileManager.default.homeDirectoryForCurrentUser

        let result = try await executeProcess(process, timeout: timeout)
        let duration = start.duration(to: .now)
        let elapsed = Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18

        let shellResult = ShellResult(
            exitCode: result.exitCode,
            stdout: result.stdout,
            stderr: result.stderr,
            duration: elapsed
        )

        appendHistory(command: command, exitCode: result.exitCode, duration: elapsed)
        return shellResult
    }

    // MARK: - which

    /// Resolve an executable name to its absolute path.
    nonisolated func which(_ command: String) async -> URL? {
        // Fast path for absolute paths
        if command.hasPrefix("/") {
            let url = URL(fileURLWithPath: command)
            return FileManager.default.isExecutableFile(atPath: url.path) ? url : nil
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [command]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !path.isEmpty else { return nil }
            return URL(fileURLWithPath: path)
        } catch {
            return nil
        }
    }

    // MARK: - Environment

    /// Return the cached shell environment (populated on first call).
    ///
    /// Runs `/bin/zsh -ilc env` so PATH additions from the user's `~/.zshrc`,
    /// `~/.zprofile`, etc. are included. Without this, `which("brew")` fails on
    /// most user Macs even when Homebrew is installed.
    func environment() async -> [String: String] {
        if let cached = environmentCache { return cached }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-ilc", "env"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            var env: [String: String] = [:]
            for line in output.split(separator: "\n") {
                if let eqIndex = line.firstIndex(of: "=") {
                    let key = String(line[line.startIndex..<eqIndex])
                    let value = String(line[line.index(after: eqIndex)...])
                    env[key] = value
                }
            }
            environmentCache = env
            return env
        } catch {
            return ProcessInfo.processInfo.environment
        }
    }

    // MARK: - History

    /// Return recent command history entries (most recent first).
    func recentHistory(limit: Int = 20) -> [ShellHistoryEntry] {
        Array(history.suffix(min(limit, history.count)))
    }

    // MARK: - Private

    private struct ProcessOutput {
        let exitCode: Int32
        let stdout: String
        let stderr: String
    }

    private func executeProcess(_ process: Process, timeout: TimeInterval) async throws -> ProcessOutput {
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            throw ShellServiceError.processStartFailed(error.localizedDescription)
        }

        let maxOut = Self.maxOutputBytes

        // Read pipe data on dedicated threads to avoid pipe buffer deadlock.
        // If the child writes more than the OS pipe buffer (~64KB), it blocks
        // until the reader drains. Reading must happen concurrently with waitUntilExit.
        let stdoutRead = Task.detached { () -> Data in
            stdoutPipe.fileHandleForReading.readDataToEndOfFile().prefix(maxOut)
        }
        let stderrRead = Task.detached { () -> Data in
            stderrPipe.fileHandleForReading.readDataToEndOfFile().prefix(maxOut)
        }

        return await withTaskGroup(of: ProcessOutput?.self) { group in
            // Task 1: wait for process completion then collect output
            group.addTask {
                process.waitUntilExit()

                let stdoutData = await stdoutRead.value
                let stderrData = await stderrRead.value

                let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
                let stderr = String(data: stderrData, encoding: .utf8) ?? ""

                return ProcessOutput(exitCode: process.terminationStatus, stdout: stdout, stderr: stderr)
            }

            // Task 2: timeout — SIGTERM then SIGKILL
            group.addTask {
                try? await Task.sleep(for: .seconds(timeout))
                if process.isRunning {
                    Self.logger.warning("Process timed out after \(Int(timeout))s — sending SIGTERM")
                    process.terminate() // SIGTERM

                    // Grace period, then SIGKILL
                    try? await Task.sleep(for: .seconds(Self.killGracePeriod))
                    if process.isRunning {
                        Self.logger.warning("Process still running — sending SIGKILL")
                        kill(process.processIdentifier, SIGKILL)
                    }
                }
                return nil
            }

            // Return first non-nil result
            for await result in group {
                if let result {
                    group.cancelAll()
                    return result
                }
            }

            return ProcessOutput(exitCode: -1, stdout: "", stderr: "Unknown error")
        }
    }

    private func appendHistory(command: String, exitCode: Int32, duration: TimeInterval) {
        let entry = ShellHistoryEntry(
            id: UUID(),
            command: command,
            exitCode: exitCode,
            timestamp: Date(),
            duration: duration
        )
        history.append(entry)
        if history.count > Self.maxHistorySize {
            history.removeFirst(history.count - Self.maxHistorySize)
        }
    }
}

extension ShellService: ShellCommandRunning {}
