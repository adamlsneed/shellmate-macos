import Testing
import Foundation
@testable import Shellmate

// MARK: - Stubs

private struct StubTool: AgentTool {
    let identifier: String
    let toolDescription = "stub"
    let category: ToolCategory
    let actionTier: ActionTier = .read
    let parameterSchema = ToolInputSchema(type: "object", properties: [:], required: [])

    func execute(parameters: [String: Any]) async throws -> AgentToolResult {
        .success("stub result")
    }
}

private struct StubProvider: ToolProvider {
    let category: ToolCategory
    let displayName: String
    let tools: [AgentTool]
}

// MARK: - Tests

@Suite("ToolRegistry")
struct ToolRegistryTests {

    private func makeRegistry() -> ToolRegistry { ToolRegistry() }

    private func shellProvider() -> StubProvider {
        StubProvider(
            category: .shell,
            displayName: "Shell",
            tools: [StubTool(identifier: "shell_exec", category: .shell)]
        )
    }

    private func filesProvider() -> StubProvider {
        StubProvider(
            category: .files,
            displayName: "Files",
            tools: [
                StubTool(identifier: "file_read", category: .files),
                StubTool(identifier: "file_write", category: .files),
            ]
        )
    }

    @Test("register and lookup tool by name")
    func registerAndLookup() async {
        let registry = makeRegistry()
        await registry.register(shellProvider())
        let tool = await registry.tool(named: "shell_exec")
        #expect(tool != nil)
        #expect(tool?.identifier == "shell_exec")
    }

    @Test("lookup unknown tool returns nil")
    func unknownToolNil() async {
        let registry = makeRegistry()
        let tool = await registry.tool(named: "nonexistent")
        #expect(tool == nil)
    }

    @Test("unregister removes tools")
    func unregister() async {
        let registry = makeRegistry()
        await registry.register(shellProvider())
        await registry.unregister(.shell)
        let tool = await registry.tool(named: "shell_exec")
        #expect(tool == nil)
    }

    @Test("tools in category returns correct tools")
    func toolsInCategory() async {
        let registry = makeRegistry()
        await registry.register(filesProvider())
        let tools = await registry.tools(in: .files)
        #expect(tools.count == 2)
        let ids = Set(tools.map(\.identifier))
        #expect(ids.contains("file_read"))
        #expect(ids.contains("file_write"))
    }

    @Test("tools in unregistered category returns empty")
    func toolsInUnregisteredCategory() async {
        let registry = makeRegistry()
        let tools = await registry.tools(in: .calendar)
        #expect(tools.isEmpty)
    }

    @Test("toolSchemas filters by category set")
    func schemasFilteredByCategory() async {
        let registry = makeRegistry()
        await registry.register(shellProvider())
        await registry.register(filesProvider())

        let schemas = await registry.toolSchemas(for: [.shell], denyCategories: [])
        #expect(schemas.count == 1)
        #expect(schemas.first?.name == "shell_exec")
    }

    @Test("toolSchemas filters by deny categories")
    func schemasFilteredByDeny() async {
        let registry = makeRegistry()
        await registry.register(shellProvider())
        await registry.register(filesProvider())

        // .exec blocks "shell_exec", .read blocks "file_read" and "file_list"
        let schemas = await registry.toolSchemas(for: [.shell, .files], denyCategories: [.exec])
        let names = schemas.map(\.name)
        #expect(!names.contains("shell_exec"))
        #expect(names.contains("file_read"))
        #expect(names.contains("file_write"))
    }

    @Test("allToolSchemas returns everything")
    func allSchemas() async {
        let registry = makeRegistry()
        await registry.register(shellProvider())
        await registry.register(filesProvider())

        let schemas = await registry.allToolSchemas()
        #expect(schemas.count == 3)
    }

    @Test("execute routes to correct tool")
    func executeRoutes() async throws {
        let registry = makeRegistry()
        await registry.register(shellProvider())
        let result = try await registry.execute(toolName: "shell_exec", parameters: [:])
        #expect(result.content == "stub result")
        #expect(!result.isError)
    }

    @Test("execute unknown tool throws")
    func executeUnknownThrows() async {
        let registry = makeRegistry()
        await #expect(throws: ToolRegistryError.self) {
            try await registry.execute(toolName: "nonexistent", parameters: [:])
        }
    }

    @Test("enabled categories lists registered categories")
    func enabledCategories() async {
        let registry = makeRegistry()
        await registry.register(shellProvider())
        await registry.register(filesProvider())
        let categories = await registry.enabledCategories()
        #expect(Set(categories) == Set([.shell, .files]))
    }
}
