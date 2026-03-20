import Testing; import Foundation; @testable import Shellmate

/// Mock UI handler for tests — always approves or denies based on init parameter.
struct TestConfirmationUIHandler: ConfirmationUIHandling {
    let alwaysApprove: Bool

    func requestConfirmation(toolIdentifier: String, description: String, tier: ActionTier) async -> Bool {
        alwaysApprove
    }
}

@Suite("ToolExecutor")
struct ToolExecutorTests {
    func makeExecutor(approve: Bool = true) async -> ToolExecutor {
        let registry = ToolRegistry()
        let shellService = ShellService()
        await registry.register(ShellProvider(shellService: shellService))
        await registry.register(FilesProvider())
        await registry.register(WebProvider())
        let uiHandler = TestConfirmationUIHandler(alwaysApprove: approve)
        let confirmation = ConfirmationService(uiHandler: uiHandler)
        let permissions = PermissionManager()
        return ToolExecutor(registry: registry, confirmationService: confirmation, permissionManager: permissions)
    }

    @Test("shell_exec") func shellExec() async {
        let executor = await makeExecutor()
        let r = await executor.execute(tool: "shell_exec", input: ["command": .string("echo hi")])
        #expect(!r.isError); #expect(r.content.contains("hi"))
    }

    @Test("file_read not found") func fileReadNotFound() async {
        let executor = await makeExecutor()
        let r = await executor.execute(tool: "file_read", input: ["path": .string("/tmp/ne_\(UUID())")])
        #expect(r.isError)
    }

    @Test("unknown tool") func unknownTool() async {
        let executor = await makeExecutor()
        let r = await executor.execute(tool: "nope", input: [:])
        #expect(r.isError); #expect(r.content.contains("Unknown"))
    }

    @Test("confirmation denied blocks write tool") func confirmationDenied() async {
        let executor = await makeExecutor(approve: false)
        let r = await executor.execute(tool: "shell_exec", input: ["command": .string("echo hi")])
        #expect(r.isError); #expect(r.content.contains("cancelled"))
    }

    @Test("read tool skips confirmation") func readToolSkipsConfirmation() async {
        // Even with deny-all confirmation, read tools should still work
        let executor = await makeExecutor(approve: false)
        let d = TestFixtures.makeTempDir(prefix: "te-read")
        defer { TestFixtures.cleanupTempDir(d) }
        let f = d.appendingPathComponent("test.txt")
        try! "hello".write(to: f, atomically: true, encoding: .utf8)
        let r = await executor.execute(tool: "file_read", input: ["path": .string(f.path)])
        #expect(!r.isError); #expect(r.content == "hello")
    }
}
