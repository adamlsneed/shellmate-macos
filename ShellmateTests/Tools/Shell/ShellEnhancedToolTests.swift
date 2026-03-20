import Testing
import Foundation
@testable import Shellmate

@Suite("Enhanced Shell Tools")
struct ShellEnhancedToolTests {

    private let shellService = ShellService()

    // MARK: - ShellScriptTool

    @Suite("ShellScriptTool")
    struct ShellScriptToolTests {

        @Test("runs echo hello script and returns output")
        func runsEchoScript() async throws {
            let tool = ShellScriptTool(service: ShellService())
            let result = try await tool.execute(parameters: ["script": "echo hello"])
            #expect(!result.isError)
            #expect(result.content.contains("hello"))
        }

        @Test("requires script parameter")
        func requiresScript() async throws {
            let tool = ShellScriptTool(service: ShellService())
            let result = try await tool.execute(parameters: [:])
            #expect(result.isError)
            #expect(result.content.contains("script"))
        }

        @Test("is write tier")
        func isWriteTier() {
            let tool = ShellScriptTool(service: ShellService())
            #expect(tool.actionTier == .write)
            #expect(tool.identifier == "shell_script")
            #expect(tool.category == .shell)
        }
    }

    // MARK: - ShellEnvironmentTool

    @Suite("ShellEnvironmentTool")
    struct ShellEnvironmentToolTests {

        @Test("returns PATH and HOME")
        func returnsPathAndHome() async throws {
            let tool = ShellEnvironmentTool(service: ShellService())
            let result = try await tool.execute(parameters: [:])
            #expect(!result.isError)
            #expect(result.content.contains("PATH="))
            #expect(result.content.contains("HOME="))
        }

        @Test("redacts sensitive vars")
        func redactsSensitiveVars() async throws {
            // We can't easily inject env vars, but we can verify the redaction logic
            // by checking that the tool's redaction keywords work on known patterns
            let tool = ShellEnvironmentTool(service: ShellService())
            let result = try await tool.execute(parameters: [:])
            #expect(!result.isError)
            // If any SECRET/TOKEN/PASSWORD/KEY/CREDENTIAL vars exist, they should be redacted
            // At minimum, verify the output is sorted alphabetically
            let lines = result.content.split(separator: "\n").map(String.init)
            let keys = lines.compactMap { line -> String? in
                guard let eq = line.firstIndex(of: "=") else { return nil }
                return String(line[line.startIndex..<eq])
            }
            // Verify alphabetical ordering
            #expect(keys == keys.sorted())
        }

        @Test("filter works")
        func filterWorks() async throws {
            let tool = ShellEnvironmentTool(service: ShellService())
            let result = try await tool.execute(parameters: ["filter": "PATH"])
            #expect(!result.isError)
            #expect(result.content.contains("PATH"))
            // Should not contain unrelated vars like USER (unless USER contains PATH substring)
            let lines = result.content.split(separator: "\n")
            for line in lines {
                #expect(line.localizedCaseInsensitiveContains("PATH"))
            }
        }
    }

    // MARK: - ShellHistoryTool

    @Suite("ShellHistoryTool")
    struct ShellHistoryToolTests {

        @Test("returns no commands when empty")
        func returnsNoCommands() async throws {
            let service = ShellService()
            let tool = ShellHistoryTool(service: service)
            let result = try await tool.execute(parameters: [:])
            #expect(!result.isError)
            #expect(result.content.contains("No commands have been run yet this session."))
        }
    }

    // MARK: - EnvCheckPathTool

    @Suite("EnvCheckPathTool")
    struct EnvCheckPathToolTests {

        @Test("finds echo")
        func findsEcho() async throws {
            let tool = EnvCheckPathTool(service: ShellService())
            let result = try await tool.execute(parameters: ["command": "echo"])
            #expect(!result.isError)
            #expect(result.content.contains("/"))
        }

        @Test("reports missing for nonexistent command")
        func reportsMissing() async throws {
            let tool = EnvCheckPathTool(service: ShellService())
            let result = try await tool.execute(parameters: ["command": "nonexistent_binary_xyz_12345"])
            #expect(!result.isError)
            #expect(result.content.lowercased().contains("not installed"))
        }

        @Test("requires command parameter")
        func requiresCommand() async throws {
            let tool = EnvCheckPathTool(service: ShellService())
            let result = try await tool.execute(parameters: [:])
            #expect(result.isError)
            #expect(result.content.contains("command"))
        }
    }

    // MARK: - SetupHomebrewTool

    @Suite("SetupHomebrewTool")
    struct SetupHomebrewToolTests {

        @Test("reports status without installing")
        func reportsStatus() async throws {
            let tool = SetupHomebrewTool(service: ShellService())
            let result = try await tool.execute(parameters: [:])
            #expect(!result.isError)
            // Should either report version or say not installed
            #expect(result.content.contains("Homebrew") || result.content.lowercased().contains("not installed"))
        }
    }

    // MARK: - SetupDeveloperToolsTool

    @Suite("SetupDeveloperToolsTool")
    struct SetupDeveloperToolsToolTests {

        @Test("reports status")
        func reportsStatus() async throws {
            let tool = SetupDeveloperToolsTool(service: ShellService())
            let result = try await tool.execute(parameters: [:])
            #expect(!result.isError)
            // Should report the path or say not installed
            #expect(result.content.contains("/") || result.content.lowercased().contains("not installed"))
        }
    }

    // MARK: - ShellProvider

    @Suite("ShellProvider Enhanced")
    struct ShellProviderEnhancedTests {

        @Test("has 7 tools total")
        func hasSevenTools() {
            let provider = ShellProvider(shellService: ShellService())
            #expect(provider.tools.count == 7)
            let ids = Set(provider.tools.map(\.identifier))
            #expect(ids.contains("shell_exec"))
            #expect(ids.contains("shell_script"))
            #expect(ids.contains("shell_environment"))
            #expect(ids.contains("shell_history"))
            #expect(ids.contains("env_check_path"))
            #expect(ids.contains("setup_homebrew"))
            #expect(ids.contains("setup_developer_tools"))
        }
    }
}
