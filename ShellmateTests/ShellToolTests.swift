import Testing; import Foundation; @testable import Shellmate

/// Tests for ShellExecuteTool via the AgentTool instance API.
/// The old ShellTool compat enum has been removed; ShellServiceTests covers the service layer.
@Suite("ShellExecuteTool") struct ShellToolTests {
    private func makeTool() -> ShellExecuteTool {
        ShellExecuteTool(service: ShellService())
    }

    @Test("echo") func echo() async throws {
        let r = try await makeTool().execute(parameters: ["command": "echo hello"])
        #expect(!r.isError); #expect(r.content.contains("hello"))
    }

    @Test("pwd") func pwd() async throws {
        let r = try await makeTool().execute(parameters: ["command": "pwd"])
        #expect(!r.isError)
    }

    @Test("missing command") func missing() async throws {
        let r = try await makeTool().execute(parameters: [:])
        #expect(r.isError)
    }

    @Test("exit code") func exitCode() async throws {
        let r = try await makeTool().execute(parameters: ["command": "exit 42"])
        #expect(r.isError); #expect(r.content.contains("42"))
    }

    @Test("empty output") func emptyOutput() async throws {
        let r = try await makeTool().execute(parameters: ["command": "true"])
        #expect(r.content == "(no output)")
    }
}
