import Testing
import Foundation
@testable import Shellmate

@Suite("ShellService")
struct ShellServiceTests {

    // MARK: - runCommand

    @Test("runCommand succeeds with simple echo")
    func runCommandEcho() async throws {
        let service = ShellService()
        let result = try await service.runCommand("echo hello")
        #expect(result.succeeded)
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("hello"))
        #expect(result.duration > 0)
    }

    @Test("runCommand reports exit code on failure")
    func runCommandExitCode() async throws {
        let service = ShellService()
        let result = try await service.runCommand("exit 42")
        #expect(!result.succeeded)
        #expect(result.exitCode == 42)
    }

    @Test("runCommand blocks dangerous commands")
    func runCommandBlocksDangerous() async throws {
        let service = ShellService()
        await #expect(throws: ShellServiceError.self) {
            _ = try await service.runCommand("sudo rm -rf /")
        }
    }

    @Test("runCommand respects timeout")
    func runCommandTimeout() async throws {
        let service = ShellService()
        let result = try await service.runCommand("sleep 10", timeout: 1)
        // Process should have been killed — non-zero exit
        #expect(!result.succeeded)
    }

    // MARK: - run (structured)

    @Test("run with structured arguments")
    func runStructured() async throws {
        let service = ShellService()
        let result = try await service.run(executable: "echo", arguments: ["structured", "args"])
        #expect(result.succeeded)
        #expect(result.stdout.contains("structured args"))
    }

    @Test("run throws commandNotFound for nonexistent executable")
    func runCommandNotFound() async throws {
        let service = ShellService()
        await #expect(throws: ShellServiceError.self) {
            _ = try await service.run(executable: "nonexistent_binary_xyz_12345")
        }
    }

    // MARK: - which

    @Test("which finds echo")
    func whichFindsEcho() async {
        let service = ShellService()
        let url = await service.which("echo")
        #expect(url != nil)
    }

    @Test("which returns nil for nonexistent command")
    func whichReturnsNil() async {
        let service = ShellService()
        let url = await service.which("nonexistent_binary_xyz_12345")
        #expect(url == nil)
    }

    // MARK: - History

    @Test("history tracks commands")
    func historyTracksCommands() async throws {
        let service = ShellService()
        _ = try await service.runCommand("echo one")
        _ = try await service.runCommand("echo two")
        let history = await service.recentHistory(limit: 10)
        #expect(history.count == 2)
        #expect(history[0].command.contains("echo"))
    }

    // MARK: - Output capping

    @Test("output is capped at 1MB")
    func outputCapped() async throws {
        let service = ShellService()
        // Generate ~2MB of output via python3
        let result = try await service.runCommand(
            "python3 -c \"print('A' * 2_097_152)\"",
            timeout: 30
        )
        #expect(result.succeeded)
        // stdout should be capped at ~1MB (1_048_576 bytes)
        #expect(result.stdout.count <= 1_048_576 + 100) // small margin for encoding
    }

    // MARK: - ShellExecuteTool compat shim

    @Test("ShellTool compat shim works")
    func compatShim() async {
        let result = await ShellTool.execute(input: ["command": "echo compat"])
        #expect(!result.isError)
        #expect(result.content.contains("compat"))
    }

    @Test("ShellTool compat shim handles missing command")
    func compatShimMissing() async {
        let result = await ShellTool.execute(input: [:])
        #expect(result.isError)
    }

    // MARK: - ShellExecuteTool

    @Test("ShellExecuteTool conforms to AgentTool")
    func toolConformance() {
        let service = ShellService()
        let tool = ShellExecuteTool(service: service)
        #expect(tool.identifier == "shell_exec")
        #expect(tool.category == .shell)
        #expect(tool.actionTier == .write)
        #expect(!tool.toolDescription.isEmpty)
    }

    @Test("ShellExecuteTool confirmationDescription truncates long commands")
    func toolConfirmationTruncates() {
        let service = ShellService()
        let tool = ShellExecuteTool(service: service)
        let longCmd = String(repeating: "x", count: 120)
        let desc = tool.confirmationDescription(parameters: ["command": longCmd])
        #expect(desc.contains("..."))
        #expect(desc.count < 120)
    }

    // MARK: - ShellProvider

    @Test("ShellProvider provides ShellExecuteTool")
    func providerTools() {
        let service = ShellService()
        let provider = ShellProvider(shellService: service)
        #expect(provider.category == .shell)
        #expect(provider.tools.count == 1)
        #expect(provider.tools[0].identifier == "shell_exec")
    }
}
