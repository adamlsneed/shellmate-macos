import Foundation
import os

/// Executes shell commands via /bin/zsh with timeout enforcement.
enum ShellTool {
    private static let logger = Logger(subsystem: "com.shellmate.app", category: "shell")
    private static let maxOutputChars = 100_000
    private static let maxBufferBytes = 10 * 1024 * 1024 // 10MB
    private static let defaultTimeout: TimeInterval = 60

    static func execute(input: [String: Any]) async -> ToolExecutionResult {
        guard let command = input["command"] as? String else {
            return ToolExecutionResult(content: "Missing required 'command' parameter", isError: true)
        }

        let timeout = (input["timeout"] as? Double) ?? defaultTimeout

        logger.info("Executing shell command: \(command.prefix(100))")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]
        process.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            return ToolExecutionResult(content: "Failed to start process: \(error.localizedDescription)", isError: true)
        }

        // Run with timeout
        let result = await withTaskGroup(of: ToolExecutionResult?.self) { group in
            group.addTask {
                process.waitUntilExit()

                let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

                var stdout = String(data: stdoutData.prefix(maxBufferBytes), encoding: .utf8) ?? ""
                let stderr = String(data: stderrData.prefix(maxBufferBytes), encoding: .utf8) ?? ""

                if stdout.count > maxOutputChars {
                    stdout = String(stdout.prefix(maxOutputChars)) + "\n...[truncated]"
                }

                let exitCode = process.terminationStatus
                var output = stdout
                if !stderr.isEmpty {
                    output += (output.isEmpty ? "" : "\n") + "STDERR: \(stderr)"
                }
                if exitCode != 0 {
                    output += "\nExit code: \(exitCode)"
                }

                return ToolExecutionResult(content: output.isEmpty ? "(no output)" : output, isError: exitCode != 0)
            }

            group.addTask {
                try? await Task.sleep(for: .seconds(timeout))
                if process.isRunning {
                    process.terminate()
                    return ToolExecutionResult(content: "Command timed out after \(Int(timeout))s", isError: true)
                }
                return nil
            }

            // Return the first non-nil result
            for await result in group {
                if let result { return result }
            }
            return ToolExecutionResult(content: "Unknown error", isError: true)
        }

        return result
    }
}
